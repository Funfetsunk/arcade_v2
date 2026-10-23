class_name Sim
extends RefCounted
## Day resolution: the economic core of the game, ported line-for-line from the
## original `sim/advanceDay.ts`. Pure data in, pure data out. Everything the
## view needs to show goes out through the signals, and randomness comes from
## the injected Rng, so a fixed seed reproduces the original exactly.

enum LogKind { MONEY, GOOD, BAD, INFO }

signal logged(message: String, kind: LogKind)
signal toast_requested(message: String, kind: LogKind)
signal customers_reset
signal coin_spawned(machine_id: int, value: int)
signal repair_worker_spawned(machine_id: int, is_senior: bool)
signal day_finished

const EVENT_LOG_KIND := {
	RandomEventDef.Kind.MONEY: LogKind.MONEY,
	RandomEventDef.Kind.GOOD: LogKind.GOOD,
	RandomEventDef.Kind.BAD: LogKind.BAD,
	RandomEventDef.Kind.INFO: LogKind.INFO,
}

var data: GameData
var rng: Rng


func _init(game_data: GameData, random: Rng) -> void:
	data = game_data
	rng = random


func run_day(state: GameState) -> void:
	var balance := data.balance
	customers_reset.emit()

	# Day 0 -> 1: setup is over and the doors open. No visitors, earnings or costs.
	if state.day == 0:
		state.day = 1
		state.last_day_customers = Economy.base_footfall(state)
		logged.emit("SETUP COMPLETE — doors open! Welcome customers. 🎉", LogKind.GOOD)
		toast_requested.emit("Arcade open! Day 1 begins.", LogKind.GOOD)
		day_finished.emit()
		return

	var visitors := Economy.base_footfall(state)
	for mul: float in [state.day_rhythm_mul, state.diff_foot_mul, state.promo_foot_mul, state.weather_foot_mul,
			state.buzz_foot_mul, state.rival_foot_mul, state.research_foot_mul]:
		if mul != 0.0:
			visitors = GameMath.js_round(visitors * mul)
	var buff := state.next_day_buff
	state.next_day_buff = null
	if buff and buff.foot_mul != 0.0:
		visitors = GameMath.js_round(visitors * buff.foot_mul)

	# Pick tonight's event, skipping ones whose prerequisites are missing.
	var ev: RandomEventDef
	while true:
		ev = data.random_events[floori(rng.next_float() * data.random_events.size())]
		if ev.needs_upgrade and not state.has_upgrade(ev.needs_upgrade.id):
			continue
		if ev.needs_machine and not state.machines.any(func(m: MachineInstance) -> bool: return m.def == ev.needs_machine):
			continue
		break

	var jammed_id := -1
	var jam_frac := 0.0
	if ev.id == &"vandalism":
		var raw_damage := GameMath.js_round((10.0 + rng.next_float() * 110.0) / 5.0) * 5
		var damage := raw_damage
		var has_security := state.staff_level(StaffDef.Skill.SECURITY) >= 1
		if has_security:
			var reduction := 0.60 + rng.next_float() * 0.20
			damage = GameMath.js_round(raw_damage * (1.0 - reduction))
		state.cash -= damage
		if has_security:
			logged.emit("Vandalism attempt! 🛡️ Security limited damage to %s (down from %s)." % [GameMath.money(damage), GameMath.money(raw_damage)], LogKind.BAD)
		else:
			logged.emit("Vandalism overnight. 🤬 %s damage." % GameMath.money(damage), LogKind.BAD)
	elif ev.id == &"coin_mech":
		var working := state.machines.filter(func(m: MachineInstance) -> bool: return m.hp > 0.0)
		if working.is_empty():
			logged.emit("Coin mech fault — but no machines running to affect.", LogKind.INFO)
		else:
			var target: MachineInstance = working[floori(rng.next_float() * working.size())]
			jammed_id = target.id
			jam_frac = 0.25 + rng.next_float() * 0.50
	elif ev.cash != 0:
		state.cash += ev.cash
		logged.emit(ev.message, EVENT_LOG_KIND[ev.kind])
	else:
		logged.emit(ev.message, EVENT_LOG_KIND[ev.kind])
	if ev.rep != 0:
		state.rep = maxf(0.0, state.rep + ev.rep)
	if ev.customers != 0:
		visitors += ev.customers

	var machine_earnings := 0.0
	var new_broken: PackedStringArray = []
	var is_power_surge := ev.id == &"power_surge"
	for m in state.machines:
		var cat := m.def
		# An installed machine counts the day even when broken.
		m.days_active += 1
		if m.hp <= 0.0:
			continue

		var utilisation := minf(1.0, visitors / (cat.popularity * 4.0))
		var plays_today := GameMath.js_round(cat.popularity * utilisation)

		var earn := 0.0
		var vend_uses := 0.0
		var sells_stock := cat.type == MachineDef.Type.VENDING or cat.type == MachineDef.Type.FOOD
		if sells_stock:
			var has_attendant := state.staff_level(StaffDef.Skill.ATTENDANT) >= 1
			var food_yield := 0.5 if cat.type == MachineDef.Type.FOOD and not has_attendant else 1.0
			var sold_out := 0
			for slot in m.stock:
				if not slot.active:
					continue
				var item := slot.item
				var price_ratio := slot.price / item.default_price
				# Demand falls as price rises above default (elasticity ~0.6).
				var demand_mul := maxf(0.1, pow(1.0 / price_ratio, 0.6))
				var demand := item.base_pop * (visitors / 10.0) * demand_mul
				# You can only sell what's on the shelf; unlimited slots never run out.
				var sold := demand
				if slot.is_limited():
					sold = minf(demand, slot.qty)
					slot.qty = maxf(0.0, slot.qty - sold)
					if demand - sold > 0.5:
						sold_out += 1
					if item.perish != 0.0:
						slot.qty = floorf(slot.qty * (1.0 - item.perish))
				earn += sold * slot.price * food_yield
				vend_uses += sold
			if sold_out > 0:
				logged.emit("%s %s sold out of %d item%s — restock to capture lost sales." % [cat.emoji, cat.display_name, sold_out, "s" if sold_out > 1 else ""], LogKind.BAD)
		else:
			var price_ratio := 1.0
			if cat.default_price > 0.0:
				var price := m.price_per_play if m.price_per_play != 0.0 else cat.default_price
				price_ratio = price / cat.default_price
			earn = cat.base_earn * utilisation * price_ratio * Economy.price_demand_mul(price_ratio)
			if state.has_upgrade(&"token_system"):
				earn *= 1.10
			if state.staff_level(StaffDef.Skill.MANAGER) >= 1:
				earn *= 1.20
			if state.staff_level(StaffDef.Skill.CASHIER) >= 1:
				earn *= 1.10
		earn *= 1.0 + 0.15 * m.tune_up_level
		earn *= m.zone_mul if m.zone_mul != 0.0 else 1.0
		var dip := m.dip_multipliers()
		if cat.type == MachineDef.Type.ARCADE:
			earn *= dip.earn_mul

		if m.id == jammed_id:
			var full_earn := earn
			var lost := full_earn * jam_frac
			earn = full_earn * (1.0 - jam_frac)
			var avg_earn := GameMath.js_round(m.total_earned / (m.days_active - 1)) if m.days_active > 1 else GameMath.js_round(full_earn)
			logged.emit("Coin mech jammed on %s! 🪙 Down %d%% of the day — %s lost (avg daily: %s)." % [cat.display_name, GameMath.js_round(jam_frac * 100.0), GameMath.money(GameMath.js_round(lost)), GameMath.money(avg_earn)], LogKind.BAD)

		m.total_earned += earn
		m.record_day(state.day, GameMath.js_round(earn), GameMath.js_round(vend_uses) if sells_stock else plays_today)

		machine_earnings += earn
		state.rep += cat.rep_gain * 0.08 * dip.rep_mul
		if rng.next_float() < 0.35:
			coin_spawned.emit(m.id, GameMath.js_round(earn * 0.22))
		# A UPS stops all wear on surge days; surge protectors halve it.
		var ups_blocked := state.has_upgrade(&"ups_device") and is_power_surge
		if not ups_blocked and not (buff and buff.protect):
			var deg := 1.2 + rng.next_float() * 0.6
			if state.has_upgrade(&"ac_unit"):
				deg *= 0.70
			if is_power_surge and state.has_upgrade(&"surge_prot"):
				deg *= 0.50
			deg *= 1.0 - 0.25 * m.reinforce_level
			m.hp = maxf(0.0, m.hp - deg)
		if m.hp <= 0.0 and not state.pending_repairs.has(m.id):
			m.hp = 0.0
			state.pending_repairs.append(m.id)
			new_broken.append(cat.display_name)
	if not new_broken.is_empty():
		logged.emit("BREAKDOWN: %s 🔨" % ", ".join(new_broken), LogKind.BAD)
		toast_requested.emit("Machine broke down!", LogKind.BAD)
	if is_power_surge and state.has_upgrade(&"ups_device"):
		logged.emit("UPS protected all machines from the surge! 🔋", LogKind.GOOD)
	elif is_power_surge and state.has_upgrade(&"surge_prot"):
		logged.emit("Surge protectors halved the machine damage! ⚡", LogKind.GOOD)

	# Broken machines on show drain reputation a little each day.
	var broken_count := state.machines.filter(func(m: MachineInstance) -> bool: return m.hp <= 0.0).size()
	if broken_count > 0:
		state.rep = maxf(0.0, state.rep - broken_count * 0.3)

	var day_repair_cost := 0.0
	var repair_level := state.staff_level(StaffDef.Skill.REPAIR)
	if repair_level >= 1 and not state.pending_repairs.is_empty():
		var is_senior := repair_level >= 2
		var speed := 2 if is_senior else 1
		var batch := state.pending_repairs.slice(0, speed)
		state.pending_repairs = state.pending_repairs.slice(speed)
		for machine_id in batch:
			var m := state.machine_by_id(machine_id)
			if m == null:
				continue
			var cost := balance.repair_cost_with_bench if state.has_upgrade(&"repair_bench") else balance.repair_cost
			state.cash -= cost
			m.hp = 100.0
			state.total_repairs += 1
			day_repair_cost += cost
			state.total_repair_cost += cost
			logged.emit("Tech repaired %s for %s." % [m.def.display_name, GameMath.money(cost)], LogKind.INFO)
			repair_worker_spawned.emit(m.id, is_senior)

	var passive := 0.0
	if state.has_upgrade(&"snack_bar"):
		passive += 30.0
	if state.has_upgrade(&"party_room"):
		passive += 80.0
	machine_earnings += passive
	for mul: float in [state.prestige_mul, state.promo_earn_mul, state.research_earn_mul]:
		if mul != 0.0 and mul != 1.0:
			machine_earnings = GameMath.js_round(machine_earnings * mul)

	var research_elec := state.research_elec_mul if state.research_elec_mul != 0.0 else 1.0
	var elec := GameMath.js_round(Economy.daily_elec(state, balance) * research_elec)
	var wages := Economy.daily_wages(state)
	var rent := Economy.daily_rent(state, balance)
	var loan_payment := 0.0
	if state.loan:
		loan_payment = minf(state.loan.daily_payment, state.loan.days_left * state.loan.daily_payment)
		state.loan.days_left -= 1
		if state.loan.days_left <= 0:
			logged.emit("Loan fully repaid. Final payment: %s." % GameMath.money(loan_payment), LogKind.GOOD)
			state.loan = null
		else:
			logged.emit("Loan repayment: %s (%d days left)." % [GameMath.money(loan_payment), state.loan.days_left], LogKind.INFO)

	var total_cost := elec + wages + rent + loan_payment + day_repair_cost
	state.cash += machine_earnings - total_cost
	state.total_customers += visitors
	state.total_earned += machine_earnings
	state.total_spent += total_cost
	state.last_day_earned = machine_earnings
	state.last_day_cost = total_cost
	state.last_day_customers = visitors
	state.last_day_rent = rent
	state.last_day_elec = elec
	state.last_day_wages = wages
	state.last_day_loan = loan_payment
	state.last_day_repair = day_repair_cost
	var profit := machine_earnings - total_cost
	state.days_run += 1
	if not state.has_biggest_day or profit > state.biggest_day:
		state.biggest_day = profit
		state.has_biggest_day = true
	state.rep = minf(100.0, state.rep)
	state.day += 1
	logged.emit("Revenue %s | Costs %s | Net %s | %d visitors" % [GameMath.money(machine_earnings), GameMath.money(-total_cost), GameMath.money(profit), visitors], LogKind.MONEY if profit >= 0.0 else LogKind.BAD)
	day_finished.emit()

class_name DayCycle
extends GameSystem
## Everything that happens around the sim when a day is run: the original
## `runDayNow()` and the update/tick functions it called in main.ts, ported in
## the same order with the same formulas.

signal goal_completed(goal: GoalDef)
signal empire_completed
signal achievement_unlocked(achievement: AchievementDef)
signal scenario_won(scenario: ScenarioDef, stars: int)
signal daily_finished(score: int, best: int, new_best: bool)
signal jackpot_hit(machine_id: int, amount: int)
signal machine_broke
signal contract_resolved(contract: ContractDef, delivered: bool)
signal tournament_resolved(tournament: TournamentDef, success: bool)

## Chance per eligible day (day 3+) of offering a decision event.
const DECISION_CHANCE := 0.33
const RIVAL_NEWS_CHANCE := 0.18

var sim: Sim


func _init(game_data: GameData, meta_progress: MetaProgress, random: Rng, day_sim: Sim) -> void:
	super(game_data, meta_progress, random)
	sim = day_sim


## A decision to offer before the next day, or null.
func pick_decision(state: GameState) -> DecisionEventDef:
	if state.day < 3 or rng.next_float() > DECISION_CHANCE:
		return null
	var pool := data.decision_events.filter(func(e: DecisionEventDef) -> bool: return _condition_holds(e, state))
	if pool.is_empty():
		return null
	return pool[floori(rng.next_float() * pool.size())]


## Applies the chosen option. Returns false (and leaves the state alone) if it
## can't be afforded; the day should only run on true.
func choose_decision(state: GameState, event: DecisionEventDef, option_index: int) -> bool:
	var o := event.options[option_index]
	if o.cost > 0 and state.cash < o.cost:
		return _refuse("Not enough cash!")
	state.cash -= o.cost
	state.cash += o.gain_cash
	if o.rep_add != 0:
		state.rep = clampf(state.rep + o.rep_add, 0.0, 100.0)
	if o.repair_all:
		for m in state.machines:
			m.hp = 100.0
		state.pending_repairs.clear()
	var buff := DayBuff.new()
	buff.foot_mul = o.foot_mul if o.foot_mul != 0.0 else 1.0
	buff.protect = o.protect
	state.next_day_buff = buff
	if not o.log_message.is_empty():
		_log(o.log_message, Sim.LogKind.BAD if o.rep_add < 0 else Sim.LogKind.GOOD)
	return true


## Runs one day: pre-day multipliers, the sim, then every post-day system.
func run(state: GameState) -> void:
	# The day about to be resolved is state.day + 1 (the sim increments first).
	state.day_rhythm_mul = data.weekday_foot_mul(state.day + 1)
	apply_promos(state)
	apply_weather(state)
	apply_rival(state)
	var broken_before := _broken_count(state)
	sim.run_day(state)
	check_goals(state)
	check_achievements(state)
	update_tickets(state)
	update_facilities(state)
	update_franchises(state)
	update_specials(state)
	update_aging(state)
	update_research(state)
	update_staff(state)
	update_satisfaction(state)
	check_scenario(state)
	if _broken_count(state) > broken_before:
		machine_broke.emit()
	tick_campaign(state)
	tick_tournament(state)
	roll_next_weather(state)
	tick_daily(state)
	tick_rival(state)
	tick_contract(state)


# ── Pre-day multipliers ──

func apply_promos(state: GameState) -> void:
	var foot := 1.0
	var earn := 1.0
	if state.campaign and state.campaign.days_left > 0:
		foot *= state.campaign.def.foot_mul
	if state.discount_on:
		foot *= data.balance.discount_foot_mul
		earn *= data.balance.discount_earn_mul
	# A tournament on the day about to run spikes footfall.
	if state.tournament and state.tournament.days_until == 1:
		foot *= state.tournament.def.foot_mul
	state.promo_foot_mul = foot
	state.promo_earn_mul = earn


func apply_weather(state: GameState) -> void:
	if state.weather == null:
		state.weather = data.weather(data.roll_weather(rng.next_float()))
	var w := state.weather
	var mul := w.foot_mul * data.season_of(state.day + 1).foot_mul
	if w.id == &"heat" and not state.has_upgrade(&"ac_unit"):
		mul *= 0.8
	state.weather_foot_mul = mul


func apply_rival(state: GameState) -> void:
	state.rival_foot_mul = GameData.rival_foot_mul(player_strength(state), state.rival.strength) if state.rival else 1.0


# ── Goals and achievements ──

func check_goals(state: GameState) -> void:
	var changed := false
	for goal in data.goals:
		if state.goals_done.has(goal.id) or not goal.requirement.is_met(state):
			continue
		state.goals_done.append(goal.id)
		changed = true
		var reward_text: String
		if goal.reward_kind == GoalDef.RewardKind.CASH:
			state.cash += goal.reward
			reward_text = GameMath.money(goal.reward)
		else:
			state.rep = minf(100.0, state.rep + goal.reward)
			reward_text = "+%d rep" % goal.reward
		_log("🎯 Goal complete: %s — %s!" % [goal.label, reward_text], Sim.LogKind.GOOD)
		_toast("🎯 %s!  %s" % [goal.label, reward_text], Sim.LogKind.MONEY)
		goal_completed.emit(goal)
	if changed and state.goals_done.size() >= data.goals.size() and not state.empire_won:
		state.empire_won = true
		_log("🏆 ALL GOALS DONE — you built an ARCADE EMPIRE!", Sim.LogKind.GOOD)
		_toast("🏆 ARCADE EMPIRE COMPLETE!", Sim.LogKind.MONEY)
		record_score(state, &"empire")
		empire_completed.emit()


func check_achievements(state: GameState) -> void:
	for a in data.achievements:
		if meta.achievements.has(a.id) or not a.requirement.is_met(state):
			continue
		meta.achievements.append(a.id)
		_log("🏅 Achievement unlocked: %s!" % a.title, Sim.LogKind.MONEY)
		_toast("🏅 %s" % a.title, Sim.LogKind.MONEY)
		achievement_unlocked.emit(a)


# ── Post-day systems ──

## Prize-genre machines hand out tickets; players redeem them at prize booths.
func update_tickets(state: GameState) -> void:
	var balance := data.balance
	var dispensed := 0
	var ticket_machines := 0
	for m in state.machines:
		if m.def.genre == null or m.def.genre.id != &"prize" or m.hp <= 0.0:
			continue
		ticket_machines += 1
		dispensed += (m.day_stats[-1].z if not m.day_stats.is_empty() else 0) * balance.tickets_per_play
	state.ticket_machines = ticket_machines
	state.last_day_tickets = dispensed
	state.total_tickets += dispensed
	# About one prize per tickets_per_prize tickets, split across tiers by weight.
	var to_give := floori(dispensed / float(balance.tickets_per_prize))
	var redeemed := 0.0
	var booths := state.machines.filter(func(m: MachineInstance) -> bool:
		return m.def.type == MachineDef.Type.PRIZES and m.hp > 0.0)
	if to_give > 0:
		for booth: MachineInstance in booths:
			for slot in booth.stock:
				if not slot.active:
					continue
				var on_hand := maxf(0.0, slot.qty)
				var want := GameMath.js_round(to_give * slot.item.redeem_weight / booths.size())
				var take := minf(on_hand, want)
				slot.qty = maxf(0.0, on_hand - take)
				redeemed += take
	state.last_day_redeemed = int(redeemed)


## An installed ATM skims a small fee per visitor.
func update_facilities(state: GameState) -> void:
	if state.has_facility(&"atm"):
		var fee := GameMath.js_round(state.last_day_customers * data.balance.atm_fee)
		if fee > 0:
			state.cash += fee
			_log("🏧 ATM fees: +%s." % GameMath.money(fee), Sim.LogKind.MONEY)


func franchise_daily_total(state: GameState) -> int:
	var total := 0
	for f in state.franchises:
		total += f.town.daily_income(f.level)
	return total


func update_franchises(state: GameState) -> void:
	var income := franchise_daily_total(state)
	if income > 0:
		state.cash += income
		_log("🏬 Franchise income: +%s." % GameMath.money(income), Sim.LogKind.MONEY)


## Progressive jackpots and social buzz.
func update_specials(state: GameState) -> void:
	var fresh_buzz := 0.0
	for m in state.machines:
		if m.hp <= 0.0:
			continue
		var last := m.day_stats[-1] if not m.day_stats.is_empty() else Vector3i.ZERO
		var earn := last.y
		var plays := last.z
		if m.def.special == MachineDef.Special.JACKPOT:
			m.jackpot_pot += GameMath.js_round(earn * 0.12)
			var hit_chance := minf(0.22, plays * 0.008)
			if m.jackpot_pot > 80.0 and rng.next_float() < hit_chance:
				var pot := GameMath.js_round(m.jackpot_pot)
				state.cash -= pot
				state.rep = minf(100.0, state.rep + 3.0)
				m.jackpot_pot = 50.0
				_log("🎰 JACKPOT on %s! A player scooped %s — the place goes wild (+3 rep)." % [m.def.display_name, GameMath.money(pot)], Sim.LogKind.GOOD)
				_toast("🎰 JACKPOT! %s!" % GameMath.money(pot), Sim.LogKind.MONEY)
				jackpot_hit.emit(m.id, pot)
		if m.def.special == MachineDef.Special.BUZZ:
			fresh_buzz += plays * 0.4
	state.buzz = GameMath.js_round(state.buzz * 0.5 + fresh_buzz)
	state.buzz_foot_mul = 1.0 + minf(0.30, state.buzz / 200.0)


## Old cabinets slowly lose max condition until refurbished.
func update_aging(state: GameState) -> void:
	var balance := data.balance
	for m in state.machines:
		if m.days_active > balance.aging_starts_day:
			m.max_hp = maxf(balance.aging_floor, m.max_hp - balance.aging_per_day)
		if m.hp > m.max_hp:
			m.hp = m.max_hp


## Auto-Stockers research tops shelves up 30% of capacity for free each day.
func update_research(state: GameState) -> void:
	if not state.has_research(&"stock"):
		return
	var cap := float(data.balance.stock_cap)
	for m in state.machines:
		if m.def.type == MachineDef.Type.ARCADE:
			continue
		for slot in m.stock:
			if slot.active and slot.is_limited() and slot.qty < cap:
				slot.qty = minf(cap, slot.qty + cap * 0.3)


## Morale drifts toward the arcade's mood; rock-bottom morale makes staff quit.
func update_staff(state: GameState) -> void:
	for i in range(state.staff.size() - 1, -1, -1):
		var s := state.staff[i]
		var target := clampf(50.0 + (state.satisfaction - 60.0) * 0.6 + (15.0 if s.trained else 0.0), 10.0, 100.0)
		s.morale = GameMath.js_round(s.morale + (target - s.morale) * 0.34)
		if s.morale < 8.0 and rng.next_float() < 0.4:
			state.staff.remove_at(i)
			_log("😞 %s quit — morale hit rock bottom. Keep the crew happy!" % s.def.display_name, Sim.LogKind.BAD)
			_toast("%s %s quit!" % [s.def.emoji, s.def.display_name], Sim.LogKind.BAD)


## Satisfaction eases halfway toward a target built from the day's conditions,
## and nudges rep by word of mouth.
func update_satisfaction(state: GameState) -> void:
	if state.machines.is_empty():
		state.satisfaction = 70.0
		return
	var target := 72.0
	var gripes: Array[Dictionary] = []
	var broken := _broken_count(state)
	if broken > 0:
		target -= broken * 14
		gripes.append({ label = "a broken machine" if broken == 1 else "%d broken machines" % broken, d = broken * 14.0 })
	var working := maxi(1, state.machines.size() - broken)
	var per_machine := state.last_day_customers / float(working)
	if per_machine > 8.0:
		var d := minf(26.0, (per_machine - 8.0) * 3.0)
		target -= d
		gripes.append({ label = "overcrowding (too few machines for the crowd)", d = d })
	var price_sum := 0.0
	var priced := 0
	for m in state.machines:
		if m.def.default_price != 0.0:
			price_sum += m.price_per_play / m.def.default_price
			priced += 1
	var avg_price := price_sum / priced if priced > 0 else 1.0
	if avg_price > 1.15:
		var d := minf(20.0, (avg_price - 1.15) * 40.0)
		target -= d
		gripes.append({ label = "prices too high", d = d })
	var covered := Economy.audiences_covered(state)
	target += 8.0 if covered >= 3 else 3.0 if covered == 2 else 0.0
	if state.has_upgrade(&"wifi"):
		target += 4.0
	if state.has_upgrade(&"ac_unit"):
		target += 3.0
	if state.has_upgrade(&"snack_bar"):
		target += 3.0
	var decor_points := 0
	for p in state.decor:
		decor_points += p.satisfaction
	if decor_points > 0:
		target += mini(10, decor_points)
	for f in data.facilities:
		if state.facilities.has(f):
			target += 2.0
		elif state.last_day_customers > f.need_at:
			target -= f.penalty
			gripes.append({ label = "no %s" % f.display_name.to_lower(), d = float(f.penalty) })
	target += meta.perk_effect(data, &"crowd")
	if not state.staff.is_empty():
		var morale_sum := 0.0
		for s in state.staff:
			morale_sum += s.morale
		var d := (morale_sum / state.staff.size() - 60.0) / 8.0
		target += d
		if d < -1.0:
			gripes.append({ label = "low staff morale", d = -d })
	if state.ticket_machines > 0:
		var booths := state.machines.filter(func(m: MachineInstance) -> bool:
			return m.def.type == MachineDef.Type.PRIZES and m.hp > 0.0)
		var prize_stock := 0.0
		for b: MachineInstance in booths:
			for slot in b.stock:
				prize_stock += maxf(0.0, slot.qty)
		if booths.is_empty():
			target -= 10.0
			gripes.append({ label = "no prize booth for tickets", d = 10.0 })
		elif prize_stock < 12.0:
			target -= 8.0
			gripes.append({ label = "empty prize shelves", d = 8.0 })
		else:
			target += 5.0
	target = clampf(target, 5.0, 100.0)
	state.satisfaction = GameMath.js_round(state.satisfaction + (target - state.satisfaction) * 0.5)
	var rep_delta := clampi(GameMath.js_round((state.satisfaction - 60.0) / 20.0), -2, 2)
	if rep_delta != 0:
		state.rep = clampf(state.rep + rep_delta, 0.0, 100.0)
	if state.satisfaction < 40.0:
		gripes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.d > b.d)
		var top := " and ".join(gripes.slice(0, 2).map(func(g: Dictionary) -> String: return g.label))
		if top.is_empty():
			_log("😟 Customers still unhappy — recovering slowly from an earlier bad day. Rep %d." % rep_delta, Sim.LogKind.BAD)
		else:
			_log("😟 Customers unhappy — %s. Rep %d." % [top, rep_delta], Sim.LogKind.BAD)
	elif state.satisfaction >= 85.0:
		_log("😄 Customers love it here! Word spreads (rep +%d)." % rep_delta, Sim.LogKind.GOOD)


func check_scenario(state: GameState) -> void:
	var sc := data.scenario(state.scenario)
	if sc.id == &"free" or state.scenario_won or not sc.is_won(state):
		return
	state.scenario_won = true
	record_score(state, &"scenario")
	var stars := 3
	if sc.par_days > 0 and state.day > sc.par_days:
		stars = 2 if state.day <= GameMath.js_round(sc.par_days * 1.5) else 1
	_log("🏆 Scenario complete: %s — %d days, %s%s" % [sc.display_name, state.day, "★".repeat(stars), "☆".repeat(3 - stars)], Sim.LogKind.GOOD)
	scenario_won.emit(sc, stars)


# ── Countdowns ──

func tick_campaign(state: GameState) -> void:
	if state.campaign and state.campaign.days_left > 0:
		state.campaign.days_left -= 1
		if state.campaign.days_left <= 0:
			_log("%s %s campaign ended." % [state.campaign.def.emoji, state.campaign.def.display_name], Sim.LogKind.INFO)
			state.campaign = null


func tick_tournament(state: GameState) -> void:
	if state.tournament == null:
		return
	state.tournament.days_until -= 1
	if state.tournament.days_until <= 0:
		_resolve_tournament(state)
	else:
		_log("%s %s in %d day(s)…" % [state.tournament.def.emoji, state.tournament.def.display_name, state.tournament.days_until], Sim.LogKind.INFO)


func _resolve_tournament(state: GameState) -> void:
	var t := state.tournament.def
	state.tournament = null
	var ok := state.rep >= t.rep_req
	var entrants := maxi(2, GameMath.js_round(t.entrants * (1.0 if ok else 0.4) * (0.7 + minf(100.0, state.rep) / 150.0)))
	var fees := entrants * t.entry_fee
	var payout := GameMath.js_round(t.prize * (1.0 if ok else 0.6))
	var rep_gain := t.rep_gain if ok else maxi(-3, GameMath.js_round(t.rep_gain * 0.25) - 4)
	state.cash += fees - payout
	state.rep = clampf(state.rep + rep_gain, 0.0, 100.0)
	if ok:
		_log("%s %s packed the house! %d entrants · %s fees in · %s prize out · +%d rep." % [t.emoji, t.display_name, entrants, GameMath.money(fees), GameMath.money(payout), rep_gain], Sim.LogKind.GOOD)
		_toast("%s %s — a hit!" % [t.emoji, t.display_name], Sim.LogKind.MONEY)
	else:
		_log("%s %s underwhelmed — rep too low. %d showed · net %s · %s%d rep." % [t.emoji, t.display_name, entrants, GameMath.money(fees - payout), "+" if rep_gain >= 0 else "", rep_gain], Sim.LogKind.BAD)
		_toast("%s flopped" % t.display_name, Sim.LogKind.BAD)
	tournament_resolved.emit(t, ok)


## Logs the weather that just happened and rolls the forecast for the next day.
func roll_next_weather(state: GameState) -> void:
	var today := state.weather if state.weather else data.weather(&"")
	var summer := data.season_of(state.day).id == &"summer"
	var kind := Sim.LogKind.GOOD if today.foot_mul >= 1.1 else Sim.LogKind.BAD if today.foot_mul < 0.9 else Sim.LogKind.INFO
	_log("%s %s%s — %s" % [today.emoji, today.display_name, " · summer holidays" if summer else "", today.blurb], kind)
	state.weather = data.weather(data.roll_weather(rng.next_float()))


func tick_daily(state: GameState) -> void:
	if state.scenario != &"daily" or state.daily_days_left < 0:
		return
	state.daily_days_left -= 1
	if state.daily_days_left <= 0:
		var score := GameMath.js_round(state.total_earned)
		var previous: int = meta.daily_bests.get(state.daily_key, 0)
		meta.daily_bests[state.daily_key] = maxi(previous, score)
		state.scenario = &"free"
		state.daily_days_left = -1
		daily_finished.emit(score, maxi(previous, score), score > previous)
	elif state.daily_days_left <= 3:
		_log("📅 Daily: %d day(s) left — push those takings!" % state.daily_days_left, Sim.LogKind.INFO)


func tick_rival(state: GameState) -> void:
	var balance := data.balance
	if state.rival == null:
		if state.day >= balance.rival_appear_day and state.scenario != &"daily":
			var rival := RivalState.new()
			rival.display_name = balance.rival_names[floori(rng.next_float() * balance.rival_names.size())]
			rival.strength = maxi(12, player_strength(state))
			state.rival = rival
			_log("📰 A rival arcade, \"%s\", just opened across town! Keep growing or lose footfall." % rival.display_name, Sim.LogKind.BAD)
			_toast("📰 Rival opened: %s" % rival.display_name, Sim.LogKind.BAD)
		return
	state.rival.strength += balance.rival_growth + state.day * 0.05
	if rng.next_float() < RIVAL_NEWS_CHANCE:
		var news := balance.rival_news[floori(rng.next_float() * balance.rival_news.size())]
		_log("📰 %s %s." % [state.rival.display_name, news], Sim.LogKind.INFO)


func tick_contract(state: GameState) -> void:
	if state.contract == null:
		return
	state.contract.days_left -= 1
	if state.contract.days_left > 0:
		return
	var c := state.contract.def
	state.contract = null
	var delivered := contract_met(state, c.id)
	if delivered:
		state.cash += c.cash
		state.rep = clampf(state.rep + c.rep, 0.0, 100.0)
		_log("📋 %s delivered! +%s%s." % [c.display_name, GameMath.money(c.cash), " +%d rep" % c.rep if c.rep else ""], Sim.LogKind.GOOD)
		_toast("📋 %s complete!" % c.display_name, Sim.LogKind.MONEY)
	else:
		_log("📋 %s fell through — requirement not met by the deadline." % c.display_name, Sim.LogKind.BAD)
		_toast("%s missed" % c.display_name, Sim.LogKind.BAD)
	contract_resolved.emit(c, delivered)


## Whether a contract's requirement is met right now.
func contract_met(state: GameState, id: StringName) -> bool:
	match id:
		&"party":
			return state.machines.size() >= 4 and state.machines.any(func(m: MachineInstance) -> bool: return m.def.type != MachineDef.Type.ARCADE)
		&"sponsor":
			return state.satisfaction >= 60.0
		&"film":
			return state.machines.size() >= 6
		&"influencer":
			return state.has_machine(&"social_hub")
		&"charity":
			return state.has_machine_type(MachineDef.Type.PRIZES)
	return false


func _condition_holds(event: DecisionEventDef, state: GameState) -> bool:
	match event.condition:
		DecisionEventDef.Condition.ANY_MACHINE_DAMAGED:
			return state.machines.any(func(m: MachineInstance) -> bool: return m.hp < 90.0)
	return true


func _broken_count(state: GameState) -> int:
	return state.machines.filter(func(m: MachineInstance) -> bool: return m.hp <= 0.0).size()

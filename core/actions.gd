class_name Actions
extends GameSystem
## Everything the player can do to a run, ported from the action handlers in
## main.ts. Each returns true on success; on refusal it shows a toast (as the
## original did) and leaves the state untouched.

## A machine was added, removed or moved; the floor recomputes zones and paths.
signal machines_changed
signal staff_changed

var day_cycle: DayCycle


func _init(game_data: GameData, meta_progress: MetaProgress, random: Rng, cycle: DayCycle) -> void:
	super(game_data, meta_progress, random)
	day_cycle = cycle


# ── Machines ──

func can_buy_machine(state: GameState, def: MachineDef) -> bool:
	if state.rep < def.rep_req:
		return _refuse("Rep too low!")
	if state.cash < def.cost:
		return _refuse("Not enough cash!")
	return true


## Buys a machine at a placement the floor has already validated.
func buy_machine(state: GameState, def: MachineDef, tile: Vector2i, facing: MachineInstance.Facing) -> MachineInstance:
	if state.cash < def.cost:
		_refuse("Not enough cash!")
		return null
	state.cash -= def.cost
	state.total_spent += def.cost
	var m := Economy.make_machine(def, state, data)
	m.tile = tile
	m.facing = facing
	state.machines.append(m)
	_log("Bought %s for %s." % [def.display_name, GameMath.money(def.cost)], Sim.LogKind.MONEY)
	_toast("%s %s placed!" % [def.emoji, def.display_name])
	machines_changed.emit()
	day_cycle.check_goals(state)
	return m


func move_machine(m: MachineInstance, tile: Vector2i, facing: MachineInstance.Facing) -> void:
	m.tile = tile
	m.facing = facing
	_log("Moved %s." % m.def.display_name, Sim.LogKind.INFO)
	_toast("Moved! ✅")
	machines_changed.emit()


## Resale value, plus a collector premium for old, unrefurbished cabinets.
func sell_value(m: MachineInstance) -> int:
	var value := m.def.cost * 0.4 * (m.hp / 100.0)
	if m.days_active > 60:
		value += m.def.cost * 0.3 * minf(1.0, (m.days_active - 60) / 120.0)
	return GameMath.js_round(value)


func sell_machine(state: GameState, m: MachineInstance) -> bool:
	var value := sell_value(m)
	state.cash += value
	state.machines.erase(m)
	state.pending_repairs.erase(m.id)
	_log("Sold %s for %s." % [m.def.display_name, GameMath.money(value)], Sim.LogKind.MONEY)
	_toast("Sold for %s 💰" % GameMath.money(value))
	machines_changed.emit()
	return true


func repair_cost(state: GameState) -> int:
	var cost := data.balance.repair_cost_with_bench if state.has_upgrade(&"repair_bench") else data.balance.repair_cost
	cost = GameMath.js_round(cost * (1.0 - meta.perk_effect(data, &"crew")))
	if state.has_research(&"bots"):
		cost = GameMath.js_round(cost * 0.6)
	return cost


func repair_machine(state: GameState, m: MachineInstance) -> bool:
	var cost := repair_cost(state)
	if state.cash < cost:
		return _refuse("Not enough cash!")
	state.cash -= cost
	m.hp = m.max_hp
	state.pending_repairs.erase(m.id)
	state.total_repairs += 1
	state.total_repair_cost += cost
	_log("Repaired %s for %s." % [m.def.display_name, GameMath.money(cost)], Sim.LogKind.INFO)
	_toast("Repaired! 🔧")
	return true


func refurbish_cost(m: MachineInstance) -> int:
	return GameMath.js_round(m.def.cost * data.balance.refurbish_cost_rate)


func refurbish_machine(state: GameState, m: MachineInstance) -> bool:
	if m.max_hp >= 100.0:
		_toast("Already in mint condition.")
		return false
	var cost := refurbish_cost(m)
	if state.cash < cost:
		return _refuse("Not enough cash to refurbish!")
	state.cash -= cost
	state.total_spent += cost
	m.max_hp = 100.0
	m.hp = maxf(m.hp, 60.0)
	_log("🔧 Refurbished %s — back to mint condition." % m.def.display_name, Sim.LogKind.GOOD)
	_toast("✨ Refurbished!")
	return true


## Price per play steps in $0.25, between $0.25 and $10.
func set_machine_price(m: MachineInstance, delta: float) -> void:
	m.price_per_play = roundf(clampf(m.price_per_play + delta, 0.25, 10.0) * 100.0) / 100.0


func set_machine_dip(m: MachineInstance, switch_id: StringName, option_index: int) -> void:
	m.dips[switch_id] = option_index


func tune_up_cost(m: MachineInstance) -> int:
	return GameMath.js_round(m.def.cost * data.balance.tune_up_cost_rate * (m.tune_up_level + 1))


func reinforce_cost(m: MachineInstance) -> int:
	return GameMath.js_round(m.def.cost * data.balance.reinforce_cost_rate * (m.reinforce_level + 1))


## Tune-Up: +15% earnings per level.
func tune_up_machine(state: GameState, m: MachineInstance) -> bool:
	if m.tune_up_level >= data.balance.tune_up_max:
		_toast("Maxed out!", Sim.LogKind.MONEY)
		return false
	if not _pay(state, tune_up_cost(m)):
		return false
	m.tune_up_level += 1
	_log("%s: Tune-Up → Lv%d." % [m.def.display_name, m.tune_up_level], Sim.LogKind.GOOD)
	_toast("⚡ Tune-Up Lv%d!" % m.tune_up_level)
	return true


## Reinforce: -25% wear per level.
func reinforce_machine(state: GameState, m: MachineInstance) -> bool:
	if m.reinforce_level >= data.balance.reinforce_max:
		_toast("Maxed out!", Sim.LogKind.MONEY)
		return false
	if not _pay(state, reinforce_cost(m)):
		return false
	m.reinforce_level += 1
	_log("%s: Reinforce → Lv%d." % [m.def.display_name, m.reinforce_level], Sim.LogKind.GOOD)
	_toast("🛡️ Reinforce Lv%d!" % m.reinforce_level)
	return true


# ── Stock ──

func toggle_stock_item(slot: StockSlot) -> void:
	slot.active = not slot.active


## Stock prices step in $0.25, between $0.25 and $20.
func adjust_stock_price(slot: StockSlot, delta: float) -> void:
	slot.price = roundf(clampf(slot.price + delta, 0.25, 20.0) * 100.0) / 100.0


## Cost to top every active slot back up to capacity.
func restock_cost(m: MachineInstance) -> int:
	var cap := float(data.balance.stock_cap)
	var cost := 0.0
	for slot in m.stock:
		if slot.active:
			var on_hand := slot.qty if slot.is_limited() else cap
			cost += maxf(0.0, cap - on_hand) * slot.item.unit_cost(data.balance.restock_cost_rate)
	return GameMath.js_round(cost)


func restock_machine(state: GameState, m: MachineInstance) -> bool:
	var cost := restock_cost(m)
	if cost <= 0:
		_toast("Already fully stocked!")
		return false
	if state.cash < cost:
		return _refuse("Not enough cash to restock!")
	state.cash -= cost
	state.total_spent += cost
	for slot in m.stock:
		if slot.active:
			slot.qty = data.balance.stock_cap
	_log("Restocked %s for %s." % [m.def.display_name, GameMath.money(cost)], Sim.LogKind.MONEY)
	_toast("📦 Restocked — %s" % GameMath.money(cost))
	return true


# ── Arcade ──

func expansions_bought(state: GameState) -> int:
	var step := float(data.balance.expand_step)
	var start := data.balance.start_room
	return GameMath.js_round((state.room.x - start.x) / step) + GameMath.js_round((state.room.y - start.y) / step)


func expand_cost(state: GameState) -> int:
	var b := data.balance
	return GameMath.js_round(b.expand_base_cost * pow(b.expand_cost_growth, expansions_bought(state)))


## Grows the room by one step along an axis (Vector2i.RIGHT = wider, DOWN = deeper).
func expand_room(state: GameState, axis: Vector2i) -> bool:
	var cost := expand_cost(state)
	var max_room := data.balance.max_room
	if (axis == Vector2i.RIGHT and state.room.x >= max_room.x) or (axis == Vector2i.DOWN and state.room.y >= max_room.y):
		_toast("Room is at its max in that direction.", Sim.LogKind.MONEY)
		return false
	if not _pay(state, cost):
		return false
	state.room += axis * data.balance.expand_step
	_log("🏗️ Expanded the room (+%d %s) for %s." % [data.balance.expand_step, "wide" if axis == Vector2i.RIGHT else "deep", GameMath.money(cost)], Sim.LogKind.GOOD)
	_toast("🏗️ Room expanded!")
	day_cycle.check_achievements(state)
	return true


func buy_upgrade(state: GameState, upgrade: UpgradeDef) -> bool:
	if state.upgrades.has(upgrade):
		return false
	if state.cash < upgrade.cost:
		return _refuse("Not enough cash!")
	if state.rep < upgrade.rep_req:
		return _refuse("Rep too low!")
	state.cash -= upgrade.cost
	state.total_spent += upgrade.cost
	state.upgrades.append(upgrade)
	_log("Upgrade: %s installed." % upgrade.display_name, Sim.LogKind.GOOD)
	_toast("%s %s!" % [upgrade.emoji, upgrade.display_name])
	return true


func buy_facility(state: GameState, facility: FacilityDef) -> bool:
	if state.facilities.has(facility):
		_toast("Already installed.")
		return false
	if not _pay(state, facility.cost):
		return false
	state.facilities.append(facility)
	_log("%s Installed %s." % [facility.emoji, facility.display_name], Sim.LogKind.GOOD)
	_toast("%s %s installed!" % [facility.emoji, facility.display_name])
	return true


func buy_decor(state: GameState, prop: DecorPropDef) -> bool:
	if state.decor.size() >= data.balance.max_decor:
		_toast("No room for more decor!", Sim.LogKind.MONEY)
		return false
	if not _pay(state, prop.cost):
		return false
	state.decor.append(prop)
	_log("%s Placed %s." % [prop.emoji, prop.display_name], Sim.LogKind.MONEY)
	_toast("%s %s placed!" % [prop.emoji, prop.display_name])
	return true


## Removes the most recent prop for a 40% refund.
func remove_last_decor(state: GameState) -> bool:
	if state.decor.is_empty():
		return false
	var prop: DecorPropDef = state.decor.pop_back()
	state.cash += GameMath.js_round(prop.cost * 0.4)
	return true


func set_arcade_name(state: GameState, new_name: String) -> void:
	var trimmed := new_name.left(20)
	state.arcade_name = trimmed if not trimmed.is_empty() else data.balance.arcade_name


func set_theme(state: GameState, theme: ThemeDef) -> void:
	state.theme = theme.id


# ── Staff ──

func senior_tech_unlocked(state: GameState) -> bool:
	return state.senior_tech_unlocked or state.staff.any(func(s: StaffInstance) -> bool: return s.def.id == &"tech_junior")


## Hiring needs a three-day wage deposit on hand (it isn't spent).
func hire_staff(state: GameState, role: StaffDef) -> StaffInstance:
	if state.cash < role.wage * 3:
		_refuse("Need 3-day deposit!")
		return null
	if state.rep < role.rep_req:
		_refuse("Rep too low!")
		return null
	if role.id == &"tech_senior" and not senior_tech_unlocked(state):
		_refuse("Hire a Junior Tech first!")
		return null
	var s := StaffInstance.new()
	s.def = role
	s.id = state.new_instance_id()
	s.morale = data.balance.staff_start_morale
	state.staff.append(s)
	if role.id == &"tech_junior":
		state.senior_tech_unlocked = true
	_log("Hired %s — %s/day." % [role.display_name, GameMath.money(role.wage)], Sim.LogKind.INFO)
	_toast("%s %s hired!" % [role.emoji, role.display_name])
	staff_changed.emit()
	return s


func fire_staff(state: GameState, s: StaffInstance) -> void:
	state.staff.erase(s)
	_log("Fired %s." % s.def.display_name, Sim.LogKind.BAD)
	_toast("%s let go." % s.def.display_name, Sim.LogKind.MONEY)
	staff_changed.emit()


func train_cost(s: StaffInstance) -> int:
	return GameMath.js_round(s.def.wage * 4)


func train_staff(state: GameState, s: StaffInstance) -> bool:
	if not _pay(state, train_cost(s)):
		return false
	s.trained = true
	s.morale = 100.0
	_log("🎓 Trained %s — morale maxed, more reliable." % s.def.display_name, Sim.LogKind.GOOD)
	_toast("🎓 Trained!")
	return true


# ── Money ──

func take_loan(state: GameState, tier: LoanTierDef) -> bool:
	if state.loan:
		return _refuse("Already have an outstanding loan!")
	var loan := LoanState.new()
	loan.amount = tier.amount
	loan.total_owed = GameMath.js_round(tier.amount * (1.0 + tier.rate))
	loan.daily_payment = ceilf(loan.total_owed / tier.days)
	loan.days_left = tier.days
	loan.days_total = tier.days
	state.loan = loan
	state.cash += tier.amount
	_log("Loan taken: %s received. %s/day for %d days." % [GameMath.money(tier.amount), GameMath.money(loan.daily_payment), tier.days], Sim.LogKind.MONEY)
	_toast("%s loan approved! 💵" % GameMath.money(tier.amount))
	return true


func repay_loan_early(state: GameState) -> bool:
	if state.loan == null:
		return false
	var remaining := state.loan.daily_payment * state.loan.days_left
	if state.cash < remaining:
		return _refuse("Need %s to repay in full." % GameMath.money(remaining))
	state.cash -= remaining
	state.loan = null
	_log("Loan fully repaid early. %s paid off." % GameMath.money(remaining), Sim.LogKind.GOOD)
	_toast("Loan cleared! 🎉", Sim.LogKind.GOOD)
	return true


# ── Marketing and events ──

func start_campaign(state: GameState, campaign: CampaignDef) -> bool:
	if state.campaign:
		_toast("A campaign is already running.", Sim.LogKind.MONEY)
		return false
	if not _pay(state, campaign.cost):
		return false
	var running := CampaignState.new()
	running.def = campaign
	running.days_left = campaign.days
	state.campaign = running
	_log("%s Launched %s — +%d%% footfall for %d days." % [campaign.emoji, campaign.display_name, GameMath.js_round((campaign.foot_mul - 1.0) * 100.0), campaign.days], Sim.LogKind.GOOD)
	_toast("%s %s live!" % [campaign.emoji, campaign.display_name], Sim.LogKind.MONEY)
	return true


func toggle_discount(state: GameState) -> void:
	var b := data.balance
	state.discount_on = not state.discount_on
	if state.discount_on:
		_log("🏷️ Happy hour ON — +%d%% footfall, %d%% off takings." % [GameMath.js_round((b.discount_foot_mul - 1.0) * 100.0), GameMath.js_round((1.0 - b.discount_earn_mul) * 100.0)], Sim.LogKind.INFO)
	else:
		_log("🏷️ Happy hour off.", Sim.LogKind.INFO)


func schedule_tournament(state: GameState, tournament: TournamentDef) -> bool:
	if state.tournament:
		_toast("A tournament is already booked.", Sim.LogKind.MONEY)
		return false
	if not _pay(state, tournament.cost, "Not enough cash to book it!"):
		return false
	var booking := TournamentBooking.new()
	booking.def = tournament
	booking.days_until = tournament.lead_days
	state.tournament = booking
	var risk := "⚠ rep %d/%d — may flop." % [GameMath.js_round(state.rep), tournament.rep_req] if state.rep < tournament.rep_req else "Rep looks good!"
	_log("%s Booked %s — in %d days. %s" % [tournament.emoji, tournament.display_name, tournament.lead_days, risk], Sim.LogKind.MONEY)
	_toast("%s %s booked!" % [tournament.emoji, tournament.display_name], Sim.LogKind.MONEY)
	return true


func undercut_rival(state: GameState) -> bool:
	if state.rival == null:
		_toast("No rival to undercut yet.")
		return false
	if not _pay(state, data.balance.undercut_cost, "Not enough cash for a price war!"):
		return false
	state.rival.strength = maxf(5.0, state.rival.strength - data.balance.undercut_hit)
	_log("💢 Price war! %s lost ground." % state.rival.display_name, Sim.LogKind.GOOD)
	_toast("💢 Rival undercut!", Sim.LogKind.MONEY)
	day_cycle.apply_rival(state)
	return true


func can_accept_contract(state: GameState, contract: ContractDef) -> bool:
	return contract.id != &"charity" or state.has_machine_type(MachineDef.Type.PRIZES)


func accept_contract(state: GameState, contract: ContractDef) -> bool:
	if state.contract:
		_toast("Finish your current contract first.", Sim.LogKind.MONEY)
		return false
	if not can_accept_contract(state, contract):
		return _refuse("You need a Prize Booth first.")
	var booking := ContractBooking.new()
	booking.def = contract
	booking.days_left = contract.days
	state.contract = booking
	_log("📋 Accepted: %s — deliver in %d day(s) for %s%s." % [contract.display_name, contract.days, GameMath.money(contract.cash), " +%d rep" % contract.rep if contract.rep else ""], Sim.LogKind.MONEY)
	_toast("📋 %s accepted!" % contract.display_name, Sim.LogKind.MONEY)
	return true


# ── Growth ──

func research_locked(state: GameState, project: ResearchDef) -> bool:
	return project.requires.any(func(r: ResearchDef) -> bool: return not state.research.has(r))


func do_research(state: GameState, project: ResearchDef) -> bool:
	if state.research.has(project):
		_toast("Already researched.")
		return false
	if research_locked(state, project):
		_toast("Research the prerequisite first.", Sim.LogKind.MONEY)
		return false
	if not _pay(state, project.cost, "Not enough cash for Research & Development!"):
		return false
	state.research.append(project)
	apply_research(state)
	_log("🔬 Researched %s — %s" % [project.display_name, project.description], Sim.LogKind.GOOD)
	_toast("🔬 %s!" % project.display_name, Sim.LogKind.MONEY)
	return true


func open_franchise(state: GameState, town: TownDef) -> bool:
	if state.rep < data.balance.franchise_rep_req:
		_toast("Need %d rep to franchise." % data.balance.franchise_rep_req, Sim.LogKind.MONEY)
		return false
	if state.franchise_in(town):
		_toast("Already open there.")
		return false
	if not _pay(state, town.cost, "Not enough cash to open!"):
		return false
	var f := FranchiseState.new()
	f.town = town
	state.franchises.append(f)
	_log("🏬 Opened a franchise in %s! +%s/day." % [town.display_name, GameMath.money(town.daily_income(1))], Sim.LogKind.GOOD)
	_toast("%s %s franchise open!" % [town.emoji, town.display_name], Sim.LogKind.MONEY)
	return true


func upgrade_franchise(state: GameState, town: TownDef) -> bool:
	var f := state.franchise_in(town)
	if f == null:
		return false
	if not _pay(state, town.upgrade_cost(f.level), "Not enough cash to invest!"):
		return false
	f.level += 1
	_log("🏬 Invested in %s — now level %d (+%s/day)." % [town.display_name, f.level, GameMath.money(town.daily_income(f.level))], Sim.LogKind.GOOD)
	_toast("%s %s upgraded!" % [town.emoji, town.display_name])
	return true


# ── Meta ──

func buy_perk(state: GameState, perk: PerkDef) -> bool:
	if meta.perk_rank(perk.id) >= perk.max_rank:
		_toast("Perk maxed out.", Sim.LogKind.MONEY)
		return false
	if meta.perk_points() <= 0:
		_toast("No prestige points to spend!", Sim.LogKind.MONEY)
		return false
	meta.perk_ranks[perk.id] = meta.perk_rank(perk.id) + 1
	apply_meta(state)
	_log("%s Perk: %s → rank %d." % [perk.emoji, perk.display_name, meta.perk_rank(perk.id)], Sim.LogKind.GOOD)
	return true


func set_difficulty(state: GameState, difficulty: DifficultyDef) -> void:
	state.difficulty = difficulty.id
	apply_meta(state)


## Spends cash with the standard refusal; also counts it as spending.
func _pay(state: GameState, cost: int, refusal := "Not enough cash!") -> bool:
	if state.cash < cost:
		return _refuse(refusal)
	state.cash -= cost
	state.total_spent += cost
	return true

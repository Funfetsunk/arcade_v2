extends Node
## Autoload "Game": owns the current run, the cross-run meta progress and the
## systems that change them, and relays their signals to EventBus.

const META_PATH := "user://meta.tres"

var state: GameState
var meta: MetaProgress
## The sim's own seeded stream; the daily challenge reseeds it.
var sim_rng := Rng.new()
## Everything else random (weather, decisions, jackpots, ...).
var world_rng := Rng.new()
var sim: Sim
var day_cycle: DayCycle
var actions: Actions
## A decision offered for the coming day, waiting for the player's choice.
var pending_decision: DecisionEventDef
## Where the run and meta progress are saved (tests point these elsewhere).
var save_path := SaveSystem.SAVE_PATH
var meta_path := META_PATH


func _ready() -> void:
	sim_rng.set_seed(randi())
	world_rng.set_seed(randi())
	meta = _load_meta()
	sim = Sim.new(Data.db, sim_rng)
	day_cycle = DayCycle.new(Data.db, meta, world_rng, sim)
	actions = Actions.new(Data.db, meta, world_rng, day_cycle)
	for system: Object in [sim, day_cycle, actions]:
		system.logged.connect(EventBus.logged.emit)
		system.toast_requested.connect(EventBus.toast_requested.emit)
	for system: GameSystem in [day_cycle, actions]:
		system.purchased.connect(EventBus.purchased.emit)
		system.refused.connect(EventBus.refused.emit)
		system.celebrated.connect(EventBus.celebrated.emit)
	sim.customers_reset.connect(EventBus.customers_reset.emit)
	sim.coin_spawned.connect(EventBus.coin_spawned.emit)
	sim.repair_worker_spawned.connect(EventBus.repair_worker_spawned.emit)
	day_cycle.goal_completed.connect(EventBus.goal_completed.emit)
	day_cycle.empire_completed.connect(EventBus.empire_completed.emit)
	day_cycle.achievement_unlocked.connect(_on_achievement_unlocked)
	day_cycle.scenario_won.connect(EventBus.scenario_won.emit)
	day_cycle.daily_finished.connect(EventBus.daily_finished.emit)
	day_cycle.jackpot_hit.connect(EventBus.jackpot_hit.emit)
	day_cycle.machine_broke.connect(EventBus.machine_broke.emit)
	day_cycle.contract_resolved.connect(EventBus.contract_resolved.emit)
	day_cycle.tournament_resolved.connect(EventBus.tournament_resolved.emit)
	actions.machines_changed.connect(EventBus.machines_changed.emit)
	actions.staff_changed.connect(EventBus.staff_changed.emit)


func _notification(what: int) -> void:
	# Browsers can close a tab at any moment; save whenever we lose focus.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if state:
			save_game()


# ── Runs ──

## Fresh run from a scenario, keeping the chosen difficulty and applying perks.
func new_game(scenario_id: StringName = &"free") -> void:
	var difficulty := state.difficulty if state else &"normal"
	state = new_state(Data.db, Data.db.scenario(scenario_id))
	state.difficulty = difficulty
	_start_run()
	var sc := Data.db.scenario(scenario_id)
	EventBus.logged.emit("%s Scenario: %s" % [sc.emoji, sc.display_name], Sim.LogKind.MONEY)
	if sc.id != &"free":
		var par := " (par: %d days)" % sc.par_days if sc.par_days else ""
		EventBus.logged.emit("🎯 Objective: %s%s" % [sc.goal_label, par], Sim.LogKind.MONEY)


## Today's date-seeded daily challenge (date as "YYYY-MM-DD").
func start_daily(date: String = Time.get_date_string_from_system()) -> void:
	var db := Data.db
	var variant := db.daily_variant(date)
	sim_rng.set_seed(db.daily_seed(date))
	state = GameState.new()
	state.scenario = &"daily"
	state.cash = variant.cash
	state.rep = variant.rep
	state.room = db.balance.start_room
	for def in variant.machines:
		state.machines.append(Economy.make_machine(def, state, db))
	state.difficulty = variant.difficulty.id
	state.daily_key = date
	state.daily_days_left = db.balance.daily_challenge_days
	_start_run()
	EventBus.logged.emit("📅 Daily Challenge: %s Earn the most in %d days!" % [variant.blurb, state.daily_days_left], Sim.LogKind.MONEY)


## Gives up the current run (logged to the leaderboard after day 5) and starts Free Play.
func restart() -> void:
	if state and state.day >= 5:
		day_cycle.record_score(state, &"restart")
	new_game(&"free")


func can_prestige() -> bool:
	return state != null and state.empire_won


## Starts over with one more prestige point to spend on perks.
func prestige() -> bool:
	if not can_prestige():
		return false
	day_cycle.record_score(state, &"prestige")
	meta.prestige_level += 1
	save_meta()
	new_game(&"free")
	EventBus.logged.emit("⭐ Prestiged to level %d — spend your new perk point!" % meta.prestige_level, Sim.LogKind.GOOD)
	EventBus.celebrated.emit()
	return true


func load_game() -> bool:
	var loaded := SaveSystem.load_save(save_path)
	if loaded == null:
		return false
	state = loaded
	FloorGrid.recompute_zones(state, Data.db.balance)
	day_cycle.apply_meta(state)
	day_cycle.apply_research(state)
	EventBus.game_loaded.emit()
	EventBus.state_changed.emit()
	return true


func save_game() -> void:
	SaveSystem.save(state, save_path)
	save_meta()


func save_meta() -> void:
	ResourceSaver.save(meta, meta_path)


# ── Days ──

## The "next day" button. Offers a decision first when one comes up; the day
## then runs from choose_decision().
func next_day() -> void:
	pending_decision = day_cycle.pick_decision(state)
	if pending_decision:
		EventBus.decision_offered.emit(pending_decision)
	else:
		_run_day()


func choose_decision(option_index: int) -> bool:
	if pending_decision == null or not day_cycle.choose_decision(state, pending_decision, option_index):
		return false
	pending_decision = null
	_run_day()
	return true


func _run_day() -> void:
	day_cycle.run(state)
	save_game()
	EventBus.day_ended.emit()
	EventBus.state_changed.emit()


func _start_run() -> void:
	FloorGrid.auto_layout(state)
	FloorGrid.recompute_zones(state, Data.db.balance)
	day_cycle.apply_meta(state)
	day_cycle.apply_research(state)
	state.cash += meta.perk_effect(Data.db, &"nest")
	if state.weather == null:
		state.weather = Data.db.weather(Data.db.roll_weather(world_rng.next_float()))
	pending_decision = null
	save_game()
	EventBus.game_started.emit()
	EventBus.state_changed.emit()


func _on_achievement_unlocked(achievement: AchievementDef) -> void:
	save_meta()
	EventBus.achievement_unlocked.emit(achievement)


func _load_meta() -> MetaProgress:
	if ResourceLoader.exists(META_PATH):
		var loaded := ResourceLoader.load(META_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as MetaProgress
		if loaded:
			return loaded
	return MetaProgress.new()


## Builds the starting state for a scenario. Static so tests can use it.
static func new_state(data: GameData, scenario: ScenarioDef) -> GameState:
	var s := GameState.new()
	var balance := data.balance
	s.room = balance.start_room
	s.satisfaction = balance.start_satisfaction
	s.arcade_name = balance.arcade_name
	s.scenario = scenario.id
	s.cash = scenario.start_cash
	s.rep = scenario.start_rep
	s.day = scenario.start_day
	for def in scenario.start_machines:
		s.machines.append(Economy.make_machine(def, s, data))
	for idx in scenario.broken_machines:
		s.machines[idx].hp = 0.0
		s.pending_repairs.append(s.machines[idx].id)
	if scenario.loan_amount > 0:
		var loan := LoanState.new()
		loan.amount = scenario.loan_amount
		loan.total_owed = scenario.loan_total_owed
		loan.daily_payment = scenario.loan_daily_payment
		loan.days_left = scenario.loan_days
		loan.days_total = scenario.loan_days
		s.loan = loan
	return s

extends Node
## Autoload "Game": owns the current run's state, the RNG and the sim, and
## advances days. The pre/post-day systems (weather, rival, campaigns, ...)
## join here in phase 1b.

var state: GameState
var rng := Rng.new()
var sim: Sim


func _ready() -> void:
	rng.set_seed(randi())
	sim = Sim.new(Data.db, rng)
	sim.logged.connect(EventBus.logged.emit)
	sim.toast_requested.connect(EventBus.toast_requested.emit)
	sim.customers_reset.connect(EventBus.customers_reset.emit)
	sim.coin_spawned.connect(EventBus.coin_spawned.emit)
	sim.repair_worker_spawned.connect(EventBus.repair_worker_spawned.emit)
	sim.day_finished.connect(EventBus.state_changed.emit)


## Fresh run from a scenario's starting setup.
func new_game(scenario_id: StringName = &"free") -> void:
	state = new_state(Data.db, Data.db.scenario(scenario_id))
	EventBus.game_started.emit()
	EventBus.state_changed.emit()


func load_game() -> bool:
	var loaded := SaveSystem.load_save()
	if loaded == null:
		return false
	state = loaded
	EventBus.game_loaded.emit()
	EventBus.state_changed.emit()
	return true


func save_game() -> void:
	SaveSystem.save(state)


func advance_day() -> void:
	sim.run_day(state)
	save_game()


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

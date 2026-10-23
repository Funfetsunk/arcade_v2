class_name SimTestHelper
extends RefCounted
## Shared setup for sim tests: a bare state like the original tests' resetG().

const DATA: GameData = preload("res://data/catalogs/game_data.tres")


static func make_state(overrides := {}) -> GameState:
	var s := GameState.new()
	s.cash = 2000.0
	s.rep = 5.0
	s.day = 1
	for key: String in overrides:
		s.set(key, overrides[key])
	return s


static func machine(state: GameState, id: StringName) -> MachineInstance:
	return Economy.make_machine(DATA.machine(id), state, DATA)


static func hire(state: GameState, id: StringName) -> StaffInstance:
	var s := StaffInstance.new()
	s.def = DATA.staff_role(id)
	s.id = state.new_instance_id()
	state.staff.append(s)
	return s


static func sim(seed_value: int) -> Sim:
	return Sim.new(DATA, Rng.new(seed_value))

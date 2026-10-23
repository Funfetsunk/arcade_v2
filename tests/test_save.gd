extends GutTest
## Save/load round-trips a mid-run state.

const H := preload("res://tests/sim_test_helper.gd")
const PATH := "user://test_save.tres"


func after_each() -> void:
	SaveSystem.delete(PATH)


func test_round_trip_keeps_the_run() -> void:
	var s := Game.new_state(H.DATA, H.DATA.scenario(&"rescue"))
	s.machines.append(H.machine(s, &"vending"))
	H.hire(s, &"tech_junior")
	s.upgrades.append(H.DATA.upgrade(&"wifi"))
	var sim := H.sim(5)
	for i in 3:
		sim.run_day(s)
	assert_eq(SaveSystem.save(s, PATH), OK)

	var loaded := SaveSystem.load_save(PATH)
	assert_not_null(loaded)
	assert_eq(loaded.day, s.day)
	assert_almost_eq(loaded.cash, s.cash, 1e-9)
	assert_eq(loaded.machines.size(), s.machines.size())
	assert_eq(loaded.machines[0].def, H.DATA.machine(&"claw"), "catalog references survive")
	assert_eq(loaded.machines[-1].stock.size(), 5)
	assert_eq(loaded.machines[0].day_stats, s.machines[0].day_stats)
	assert_eq(loaded.pending_repairs, s.pending_repairs)
	assert_eq(loaded.loan.days_left, s.loan.days_left)
	assert_true(loaded.has_upgrade(&"wifi"))
	assert_eq(loaded.staff_level(StaffDef.Skill.REPAIR), 1)

	# The loaded run keeps going exactly like the original.
	var rng_a := Rng.new(9)
	var rng_b := Rng.new(9)
	Sim.new(H.DATA, rng_a).run_day(s)
	Sim.new(H.DATA, rng_b).run_day(loaded)
	assert_almost_eq(loaded.cash, s.cash, 1e-9)


func test_incompatible_version_is_ignored() -> void:
	var s := H.make_state()
	s.save_version = GameState.SAVE_VERSION - 1
	ResourceSaver.save(s, PATH)
	assert_null(SaveSystem.load_save(PATH))


func test_missing_save_returns_null() -> void:
	assert_null(SaveSystem.load_save("user://does_not_exist.tres"))

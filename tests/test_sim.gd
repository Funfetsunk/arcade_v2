extends GutTest
## Port of the original tests/sim.test.ts: invariants of the day resolution.

const H := preload("res://tests/sim_test_helper.gd")


func _state_with(ids: Array[StringName], overrides := {}) -> GameState:
	var s := H.make_state(overrides)
	for id in ids:
		s.machines.append(H.machine(s, id))
	return s


func test_setup_day_opens_doors_without_charging() -> void:
	var s := _state_with([&"claw"], { day = 0 })
	H.sim(12345).run_day(s)
	assert_eq(s.day, 1)
	assert_eq(s.cash, 2000.0, "setup day is free")
	assert_gt(s.last_day_customers, 0, "footfall seeded for the floor")


func test_normal_day_advances_by_one() -> void:
	var s := _state_with([&"claw"])
	H.sim(12345).run_day(s)
	assert_eq(s.day, 2)


func test_broken_machine_earns_nothing() -> void:
	var s := _state_with([&"claw"])
	s.machines[0].hp = 0.0
	H.sim(12345).run_day(s)
	assert_eq(s.last_day_earned, 0.0)


func test_free_play_earns_nothing() -> void:
	var s := _state_with([&"pong"])
	s.machines[0].dips[&"freePlay"] = 1
	H.sim(12345).run_day(s)
	assert_eq(s.last_day_earned, 0.0)


func test_working_machine_earns() -> void:
	var s := _state_with([&"claw"])
	H.sim(7).run_day(s)
	assert_gt(s.last_day_earned, 0.0)


func test_price_has_a_sweet_spot() -> void:
	var earn_at := func(ratio: float) -> float:
		var s := _state_with([&"claw"])
		s.machines[0].price_per_play = s.machines[0].def.default_price * ratio
		H.sim(7).run_day(s)
		return s.last_day_earned
	var def: float = earn_at.call(1.0)
	var sweet: float = earn_at.call(1.9)
	var over: float = earn_at.call(4.0)
	assert_gt(sweet, def, "nudging toward the sweet spot helps")
	assert_lt(over, sweet, "overpricing loses revenue")


func test_wider_audience_draws_more() -> void:
	var narrow := Economy.base_footfall(_state_with([&"claw", &"skee"]))
	var broad := Economy.base_footfall(_state_with([&"claw", &"pinball"]))
	assert_gt(broad, narrow)


func test_cost_is_sum_of_components() -> void:
	var s := _state_with([&"claw", &"pinball"])
	H.sim(12345).run_day(s)
	assert_eq(s.last_day_cost, s.last_day_elec + s.last_day_wages + s.last_day_rent + s.last_day_loan + s.last_day_repair)


func test_rep_clamped_to_100() -> void:
	var s := _state_with([&"vr"], { rep = 99.9 })
	var sim := H.sim(12345)
	for i in 5:
		sim.run_day(s)
	assert_lte(s.rep, 100.0)


func test_working_machine_degrades() -> void:
	var s := _state_with([&"claw"])
	H.sim(12345).run_day(s)
	assert_lt(s.machines[0].hp, 100.0)


func test_footfall_buff_applies_protects_and_clears() -> void:
	var s := _state_with([&"claw"])
	var base_visitors := Economy.base_footfall(s)
	var buff := DayBuff.new()
	buff.foot_mul = 2.0
	buff.protect = true
	s.next_day_buff = buff
	H.sim(7).run_day(s)
	assert_gt(s.last_day_customers, base_visitors + 5)
	assert_eq(s.machines[0].hp, 100.0, "protect stopped wear")
	assert_null(s.next_day_buff, "buff cleared after the day")


func test_tune_up_raises_earnings_and_reinforce_slows_wear() -> void:
	var plain := _state_with([&"claw"])
	H.sim(7).run_day(plain)
	var tuned := _state_with([&"claw"])
	tuned.machines[0].tune_up_level = 3
	H.sim(7).run_day(tuned)
	assert_gt(tuned.last_day_earned, plain.last_day_earned)

	var reinforced := _state_with([&"claw"])
	reinforced.machines[0].reinforce_level = 2
	H.sim(7).run_day(reinforced)
	assert_lt(100.0 - reinforced.machines[0].hp, 100.0 - plain.machines[0].hp)


func test_golden_trajectory() -> void:
	var s := _state_with([&"claw", &"pinball"])
	var sim := H.sim(99)
	var trail := []
	for i in 8:
		sim.run_day(s)
		trail.append([s.day, GameMath.js_round(s.cash), GameMath.js_round(s.rep)])
	assert_eq(trail, [[2, 1928, 5], [3, 1906, 5], [4, 1883, 10], [5, 1812, 10],
		[6, 1775, 11], [7, 1713, 11], [8, 1692, 11], [9, 1681, 11]])


func test_signals_report_the_day() -> void:
	var s := _state_with([&"claw"])
	var sim := H.sim(12345)
	watch_signals(sim)
	sim.run_day(s)
	assert_signal_emitted(sim, "customers_reset")
	assert_signal_emitted(sim, "day_finished")
	assert_signal_emitted(sim, "logged")

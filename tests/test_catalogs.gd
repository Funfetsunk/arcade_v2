extends GutTest
## Port of the original data tests (goals, scenarios, calendar, daily, decor,
## facilities, perks, prizes, specials, rival, tournaments, weather), plus a
## sanity check that every catalog loaded with unique ids.

const H := preload("res://tests/sim_test_helper.gd")

var d: GameData = H.DATA


func test_every_catalog_has_unique_ids() -> void:
	for catalog: String in ["machines", "staff", "upgrades", "decision_events", "genres", "goals", "achievements",
			"scenarios", "contracts", "campaigns", "difficulties", "perks", "research", "tournaments", "towns",
			"weathers", "seasons", "themes", "decor_props", "facilities", "daily_variants"]:
		var list: Array = d.get(catalog)
		assert_gt(list.size(), 0, catalog)
		var ids := {}
		for def: Resource in list:
			ids[def.get(&"id")] = true
		assert_eq(ids.size(), list.size(), catalog + " ids unique")
	assert_eq(d.machines.size(), 28)
	assert_eq(d.random_events.size(), 13)


func test_goal_values_read_the_state() -> void:
	var s := H.make_state({ rep = 30.0, total_earned = 6000.0, day = 12, biggest_day = 500.0, has_biggest_day = true })
	for i in 5:
		s.machines.append(H.machine(s, &"claw"))
	var met: Array = d.goals.filter(func(g: GoalDef) -> bool: return g.requirement.is_met(s)).map(func(g: GoalDef) -> StringName: return g.id)
	for id: StringName in [&"earn5k", &"mach4", &"rep25", &"day10"]:
		assert_has(met, id)
	for id: StringName in [&"rep50", &"day30", &"mach9", &"bigday1k"]:
		assert_does_not_have(met, id)


func test_fresh_state_meets_no_goals() -> void:
	var s := H.make_state({ day = 0 })
	assert_true(d.goals.all(func(g: GoalDef) -> bool: return not g.requirement.is_met(s)))


func test_scenarios_build_valid_starts() -> void:
	for sc in d.scenarios:
		var s := Game.new_state(d, sc)
		assert_eq(s.machines.size(), sc.start_machines.size(), sc.id)
		assert_false(sc.goal.is_empty(), sc.id)


func test_rescue_starts_broke_with_loan_and_two_broken() -> void:
	var s := Game.new_state(d, d.scenario(&"rescue"))
	assert_lt(s.cash, 500.0)
	assert_not_null(s.loan)
	assert_eq(s.machines.filter(func(m: MachineInstance) -> bool: return m.is_broken()).size(), 2)
	assert_eq(s.pending_repairs.size(), 2)


func test_scenario_goals() -> void:
	var rescue := d.scenario(&"rescue")
	assert_false(rescue.is_won(H.make_state({ cash = 100.0 })))
	assert_true(rescue.is_won(H.make_state({ cash = 6000.0 })))
	var opening := d.scenario(&"opening")
	var s := H.make_state({ rep = 30.0 })
	for i in 6:
		s.machines.append(H.machine(s, &"claw"))
	assert_true(opening.is_won(s))
	s.rep = 29.0
	assert_false(opening.is_won(s))


func test_retro_counts_only_classics() -> void:
	var retro := d.scenario(&"retro")
	var s := H.make_state({ rep = 25.0 })
	for id: StringName in [&"pong", &"pinball", &"pac", &"breakout", &"space_inv"]:
		s.machines.append(H.machine(s, id))
	assert_true(retro.is_won(s))
	s.rep = 24.0
	assert_false(retro.is_won(s))
	var clawed := H.make_state({ rep = 99.0 })
	clawed.machines.append(H.machine(clawed, &"claw"))
	assert_false(retro.is_won(clawed))


func test_unknown_scenario_falls_back_to_free_play() -> void:
	assert_eq(d.scenario(&"nope").id, &"free")


func test_calendar() -> void:
	assert_eq(d.weekday_name(1), "Mon")
	assert_eq(d.weekday_name(7), "Sun")
	assert_eq(d.weekday_name(8), "Mon")
	assert_gt(d.weekday_foot_mul(6), d.weekday_foot_mul(2))
	assert_gt(d.weekday_foot_mul(7), d.weekday_foot_mul(3))
	var avg := 0.0
	for f in d.balance.weekday_foot:
		avg += f / 7.0
	assert_between(avg, 0.95, 1.05)
	assert_typeof(d.weekday_foot_mul(0), TYPE_FLOAT)


func test_daily_challenge_matches_original_hash() -> void:
	assert_eq(d.daily_seed("2026-06-05"), 504235175)
	assert_eq(d.daily_variant("2026-06-05").id, &"standard")
	assert_eq(d.daily_seed("2026-01-01"), 3141301772)
	assert_eq(d.daily_variant("2026-01-01").id, &"startup")
	assert_eq(d.daily_variant("2026-10-23").id, &"premium")


func test_decor_and_facilities() -> void:
	for p in d.decor_props:
		assert_gt(p.cost, 0)
		assert_gt(p.satisfaction, 0)
	assert_gte(d.balance.max_decor, 8)
	assert_not_null(d.decor_prop(&"plant"))
	assert_null(d.decor_prop(&"nope"))
	for f in d.facilities:
		assert_gt(f.cost, 0)
		assert_gt(f.need_at, 0)
		assert_gt(f.penalty, 0)
	assert_gt(d.balance.atm_fee, 0.0)
	assert_not_null(d.facility(&"atm"))


func test_perks() -> void:
	for p in d.perks:
		assert_gt(p.max_rank, 0)
		assert_gt(p.per_rank, 0.0)
	assert_eq(d.perk(&"coins").kind, PerkDef.Kind.EARN)
	assert_eq(d.perk(&"word").kind, PerkDef.Kind.FOOT)
	assert_eq(d.perk(&"nest").kind, PerkDef.Kind.CASH)
	assert_null(d.perk(&"nope"))


func test_prize_booth() -> void:
	var booth := d.machine(&"prize_counter")
	assert_eq(booth.type, MachineDef.Type.PRIZES)
	assert_eq(booth.base_earn, 0.0)
	var m := H.machine(H.make_state(), &"prize_counter")
	assert_eq(m.stock.size(), d.prize_stock.size())
	assert_true(m.stock.all(func(s: StockSlot) -> bool: return s.qty == d.balance.stock_cap))
	for p in d.prize_stock:
		assert_gt(p.ticket_cost, 0)
		assert_gt(p.wholesale_cost, 0.0)
	var rate := d.balance.restock_cost_rate
	assert_eq(d.stock_item(&"plush").unit_cost(rate), d.stock_item(&"plush").wholesale_cost)
	assert_almost_eq(d.stock_item(&"cola").unit_cost(rate), 0.7, 1e-9)
	assert_lt(d.stock_item(&"sticker").ticket_cost, d.stock_item(&"jackpot").ticket_cost)


func test_special_machines() -> void:
	assert_eq(d.machine(&"jackpot_machine").special, MachineDef.Special.JACKPOT)
	assert_gt(H.machine(H.make_state(), &"jackpot_machine").jackpot_pot, 0.0)
	assert_eq(d.machine(&"social_hub").special, MachineDef.Special.BUZZ)
	assert_eq(d.machine(&"claw").special, MachineDef.Special.NONE)
	assert_eq(H.machine(H.make_state(), &"claw").jackpot_pot, 0.0)


func test_rival_curve() -> void:
	assert_gt(GameData.rival_foot_mul(100, 50), 1.0)
	assert_lt(GameData.rival_foot_mul(50, 100), 1.0)
	assert_eq(GameData.rival_foot_mul(60, 60), 1.0)
	assert_eq(GameData.rival_foot_mul(1000, 0), 1.3)
	assert_eq(GameData.rival_foot_mul(0, 1000), 0.7)
	assert_gt(d.balance.rival_appear_day, 1)


func test_tournaments_scale() -> void:
	var a := d.tournaments[0]
	var c := d.tournaments[-1]
	assert_gt(c.cost, a.cost)
	assert_gt(c.foot_mul, a.foot_mul)
	assert_gt(c.rep_req, a.rep_req)
	assert_gt(c.entrants, a.entrants)
	assert_null(d.tournament(&"nope"))


func test_weather_and_seasons() -> void:
	for r: float in [0.0, 0.25, 0.5, 0.75, 0.999]:
		assert_not_null(d.weather(d.roll_weather(r)))
	assert_gt(d.weather(&"rain").foot_mul, 1.0)
	assert_lt(d.weather(&"heat").foot_mul, 1.0)
	assert_eq(d.weather(&"nope").id, &"cloudy")
	var season_len := d.balance.season_length
	assert_eq(d.season_of(1).id, &"spring")
	assert_eq(d.season_of(1 + season_len).id, &"summer")
	assert_eq(d.season_of(1 + 4 * season_len).id, &"spring")


func test_research_prerequisites_resolved() -> void:
	var hype := d.research_project(&"hype")
	assert_eq(hype.requires.map(func(r: ResearchDef) -> StringName: return r.id), [&"buzz", &"pricing"])

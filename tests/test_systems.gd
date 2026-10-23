extends GutTest
## Day-cycle and action paths the parity scripts don't reach, plus the Game
## autoload's run flow (decisions, prestige, daily challenge).

const H := preload("res://tests/sim_test_helper.gd")

var d: GameData = H.DATA
var meta: MetaProgress
var cycle: DayCycle
var actions: Actions


func before_each() -> void:
	meta = MetaProgress.new()
	cycle = DayCycle.new(d, meta, Rng.new(1), H.sim(1))
	actions = Actions.new(d, meta, cycle.rng, cycle)


func test_rock_bottom_morale_can_make_staff_quit() -> void:
	var s := H.make_state({ satisfaction = 5.0 })
	for i in 20:
		H.hire(s, &"cashier").morale = 0.0
	cycle.update_staff(s)
	assert_lt(s.staff.size(), 20, "some quit")
	assert_gt(s.staff.size(), 0, "not all quit (40% chance each)")


func test_training_lifts_morale_target() -> void:
	var s := H.make_state({ satisfaction = 60.0 })
	var trained := H.hire(s, &"cashier")
	trained.trained = true
	var plain := H.hire(s, &"cashier")
	trained.morale = 50.0
	plain.morale = 50.0
	cycle.update_staff(s)
	assert_gt(trained.morale, plain.morale)


func test_senior_tech_needs_a_junior_first_then_stays_unlocked() -> void:
	var s := H.make_state({ cash = 10000.0, rep = 50.0 })
	assert_null(actions.hire_staff(s, d.staff_role(&"tech_senior")))
	var junior := actions.hire_staff(s, d.staff_role(&"tech_junior"))
	actions.fire_staff(s, junior)
	assert_not_null(actions.hire_staff(s, d.staff_role(&"tech_senior")), "unlock is sticky")


func test_vintage_cabinets_gain_resale_value() -> void:
	var s := H.make_state()
	var m := H.machine(s, &"pinball")
	var fresh := actions.sell_value(m)
	m.days_active = 180
	assert_gt(actions.sell_value(m), fresh)


func test_room_expansion_cost_grows_and_caps() -> void:
	var s := H.make_state({ cash = 1e9 })
	var first := actions.expand_cost(s)
	assert_true(actions.expand_room(s, Vector2i.RIGHT))
	assert_gt(actions.expand_cost(s), first)
	while actions.expand_room(s, Vector2i.RIGHT):
		pass
	assert_eq(s.room.x, d.balance.max_room.x)


func test_loan_terms_and_one_at_a_time() -> void:
	var s := H.make_state()
	var tier: LoanTierDef = d.loan_tiers[0]
	assert_true(actions.take_loan(s, tier))
	assert_eq(s.loan.total_owed, 550.0)
	assert_eq(s.loan.daily_payment, 55.0)
	assert_false(actions.take_loan(s, tier))


func test_research_needs_prerequisites() -> void:
	var s := H.make_state({ cash = 1e6 })
	assert_false(actions.do_research(s, d.research_project(&"hype")))
	for id: StringName in [&"power", &"pricing", &"buzz", &"hype"]:
		assert_true(actions.do_research(s, d.research_project(id)), id)
	assert_almost_eq(s.research_foot_mul, 1.10 * 1.15, 1e-9)
	assert_eq(s.research_elec_mul, 0.8)


func test_perks_need_points_and_respect_max_rank() -> void:
	var s := H.make_state()
	var coins := d.perk(&"coins")
	assert_false(actions.buy_perk(s, coins), "no prestige points yet")
	meta.prestige_level = 10
	for i in coins.max_rank:
		assert_true(actions.buy_perk(s, coins))
	assert_false(actions.buy_perk(s, coins), "maxed")
	assert_almost_eq(s.prestige_mul, 1.0 + coins.per_rank * coins.max_rank, 1e-9)


func test_contract_requirements() -> void:
	var s := H.make_state()
	assert_false(actions.accept_contract(s, d.contract(&"charity")), "needs a prize booth")
	s.machines.append(H.machine(s, &"prize_counter"))
	assert_true(actions.accept_contract(s, d.contract(&"charity")))
	assert_true(cycle.contract_met(s, &"charity"))


func test_decision_offered_only_from_day_three() -> void:
	var s := H.make_state({ day = 2 })
	for i in 50:
		assert_null(cycle.pick_decision(s))
	s.day = 3
	var offered := 0
	for i in 200:
		if cycle.pick_decision(s):
			offered += 1
	assert_between(offered, 40, 100, "about a third of days")


func test_technician_offer_needs_a_worn_machine() -> void:
	var tech := d.decision_events.filter(func(e: DecisionEventDef) -> bool: return e.id == &"techguy")[0] as DecisionEventDef
	var s := H.make_state({ day = 5 })
	s.machines.append(H.machine(s, &"claw"))
	assert_false(cycle._condition_holds(tech, s))
	s.machines[0].hp = 80.0
	assert_true(cycle._condition_holds(tech, s))


func test_game_runs_a_day_through_a_decision() -> void:
	Game.new_game(&"free")
	Game.state.day = 5
	watch_signals(EventBus)
	# Keep asking until a decision comes up, then answer it.
	for i in 30:
		Game.next_day()
		if Game.pending_decision:
			break
	assert_not_null(Game.pending_decision, "a decision was offered within 30 days")
	assert_signal_emitted(EventBus, "decision_offered")
	var day_before := Game.state.day
	var last := Game.pending_decision.options.size() - 1
	assert_true(Game.choose_decision(last))
	assert_eq(Game.state.day, day_before + 1)
	assert_null(Game.pending_decision)
	assert_signal_emitted(EventBus, "day_ended")


func test_prestige_requires_the_empire() -> void:
	Game.new_game(&"free")
	assert_false(Game.prestige())
	var level := Game.meta.prestige_level
	Game.state.empire_won = true
	assert_true(Game.prestige())
	assert_eq(Game.meta.prestige_level, level + 1)
	assert_false(Game.state.empire_won, "fresh run")
	Game.meta.prestige_level = level


func test_daily_challenge_start() -> void:
	Game.start_daily("2026-10-23")
	var variant := d.daily_variant("2026-10-23")
	assert_eq(Game.state.scenario, &"daily")
	assert_eq(Game.state.daily_days_left, d.balance.daily_challenge_days)
	assert_eq(Game.state.machines.size(), variant.machines.size())
	assert_eq(Game.state.difficulty, variant.difficulty.id)
	Game.new_game(&"free")

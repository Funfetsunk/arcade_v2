extends GutTest
## Replays scripted games through DayCycle + Actions and checks every day (state
## and every log line) against the original game. fixtures/day_parity.json was
## produced by running the original main.ts day loop and action handlers in Node,
## with Math.random driven by a second seeded mulberry32 stream (see "config").

const H := preload("res://tests/sim_test_helper.gd")
const FIXTURE := "res://tests/fixtures/day_parity.json"
const EPS := 1e-6

var runs: Array = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
var d: GameData = H.DATA


func test_all_runs_match_the_original() -> void:
	assert_eq(runs.size(), 5)
	for run: Dictionary in runs:
		_check_run(run)
		if is_failing():
			return


func _check_run(run: Dictionary) -> void:
	var c: Dictionary = run.config
	var meta := MetaProgress.new()
	meta.prestige_level = int(c.get("prestige", 0))
	for id: String in c.get("perks", {}):
		meta.perk_ranks[StringName(id)] = int(c.perks[id])

	var state: GameState
	if c.scenario == "daily":
		state = GameState.new()
		state.scenario = &"daily"
		state.cash = c.cash
		state.rep = c.rep
		for id: String in c.machines:
			state.machines.append(H.machine(state, StringName(id)))
		state.daily_key = "2026-10-23"
		state.daily_days_left = int(c.dailyDays)
	else:
		state = Game.new_state(d, d.scenario(StringName(c.scenario)))
	state.difficulty = StringName(c.get("difficulty", "normal"))

	var sim := Sim.new(d, Rng.new(int(c.seed)))
	var cycle := DayCycle.new(d, meta, Rng.new(int(c.world)), sim)
	var actions := Actions.new(d, meta, cycle.rng, cycle)
	var logs: Array[String] = []
	for system: Object in [sim, cycle, actions]:
		system.logged.connect(func(message: String, _kind: Sim.LogKind) -> void: logs.append(message))
	cycle.apply_meta(state)
	cycle.apply_research(state)
	for key: String in c.get("set", {}):
		state.set(key, c.set[key])
	for id: String in c.get("staff", []):
		var s := StaffInstance.new()
		s.def = d.staff_role(StringName(id))
		s.morale = c.get("staffMorale", 78.0)
		state.staff.append(s)

	for i in run.days.size():
		for a: Dictionary in c.get("actions", []):
			if int(a.at) == i:
				_act(a, state, actions)
		var event := cycle.pick_decision(state)
		var chose := -1
		if event:
			var first := event.options[0]
			chose = 0 if first.cost == 0 or state.cash >= first.cost else event.options.size() - 1
			assert_true(cycle.choose_decision(state, event, chose))
		cycle.run(state)
		_check_day("%s day index %d" % [c.name, i], run.days[i], state, event, chose, logs)
		logs.clear()
		if is_failing():
			return
	assert_eq(meta.achievements, Array(run.meta.ach.map(func(x: String) -> StringName: return StringName(x)), TYPE_STRING_NAME, &"", null), c.name + " achievements")
	for key: String in run.meta.daily:
		assert_eq(meta.daily_bests.get(key, -1), int(run.meta.daily[key]), c.name + " daily best")


func _act(a: Dictionary, state: GameState, actions: Actions) -> void:
	var m := func(i: int) -> MachineInstance: return state.machines[i]
	match a.do:
		"buy":
			var def := d.machine(StringName(a.id))
			if state.rep >= def.rep_req and state.cash >= def.cost:
				actions.buy_machine(state, def, Vector2i.ZERO, MachineInstance.Facing.S)
		"hire": actions.hire_staff(state, d.staff_role(StringName(a.id)))
		"campaign": actions.start_campaign(state, d.campaign(StringName(a.id)))
		"upgrade": actions.buy_upgrade(state, d.upgrade(StringName(a.id)))
		"loan": actions.take_loan(state, d.loan_tiers.filter(func(t: LoanTierDef) -> bool: return t.id == StringName(a.id))[0])
		"contract": actions.accept_contract(state, d.contract(StringName(a.id)))
		"tournament": actions.schedule_tournament(state, d.tournament(StringName(a.id)))
		"facility": actions.buy_facility(state, d.facility(StringName(a.id)))
		"decor": actions.buy_decor(state, d.decor_prop(StringName(a.id)))
		"research": actions.do_research(state, d.research_project(StringName(a.id)))
		"restock": actions.restock_machine(state, m.call(int(a.i)))
		"discount": actions.toggle_discount(state)
		"train": actions.train_staff(state, state.staff[int(a.i)])
		"tune": actions.tune_up_machine(state, m.call(int(a.i)))
		"reinforce": actions.reinforce_machine(state, m.call(int(a.i)))
		"expand": actions.expand_room(state, Vector2i.RIGHT if a.dim == "w" else Vector2i.DOWN)
		"undercut": actions.undercut_rival(state)
		"franchise": actions.open_franchise(state, d.town(StringName(a.id)))
		"franchiseUp": actions.upgrade_franchise(state, d.town(StringName(a.id)))
		"sell": actions.sell_machine(state, m.call(int(a.i)))
		"repairBroken":
			for machine in state.machines:
				if machine.hp <= 0.0:
					actions.repair_machine(state, machine)
					break
		"refurb": actions.refurbish_machine(state, m.call(int(a.i)))
		"price": actions.set_machine_price(m.call(int(a.i)), a.delta)
		"fire": actions.fire_staff(state, state.staff[int(a.i)])
		"repay": actions.repay_loan_early(state)
		_: fail_test("unknown action " + str(a.do))


func _check_day(at: String, e: Dictionary, s: GameState, event: DecisionEventDef, chose: int, logs: Array[String]) -> void:
	assert_eq(event.id if event else &"", StringName(e.decision) if e.decision else &"", at + " decision")
	if event:
		assert_eq(chose, int(e.chose), at + " decision option")
	assert_eq(logs, Array(e.log, TYPE_STRING, &"", null), at + " log")
	assert_eq(s.day, int(e.day), at + " day")
	assert_almost_eq(s.cash, float(e.cash), EPS, at + " cash")
	assert_almost_eq(s.rep, float(e.rep), EPS, at + " rep")
	assert_almost_eq(s.satisfaction, float(e.sat), EPS, at + " satisfaction")
	assert_almost_eq(s.buzz, float(e.buzz), EPS, at + " buzz")
	assert_eq(s.last_day_customers, int(e.customers), at + " customers")
	assert_almost_eq(s.last_day_earned, float(e.earned), EPS, at + " earned")
	assert_almost_eq(s.total_spent, float(e.spent), EPS, at + " spent")
	assert_eq(s.total_tickets, int(e.tickets), at + " tickets")
	assert_eq(s.last_day_redeemed, int(e.redeemed), at + " redeemed")
	assert_eq(s.weather.id if s.weather else &"", StringName(e.weather) if e.weather else &"", at + " weather")
	if e.rival:
		assert_not_null(s.rival, at + " rival")
		if s.rival:
			assert_eq(s.rival.display_name, e.rival.name, at + " rival name")
			assert_almost_eq(s.rival.strength, float(e.rival.strength), EPS, at + " rival strength")
	else:
		assert_null(s.rival, at + " no rival")
	assert_eq(s.campaign.days_left if s.campaign else -1, int(e.campaign), at + " campaign")
	assert_eq(s.tournament.days_until if s.tournament else -1, int(e.tournament), at + " tournament")
	assert_eq(s.contract.days_left if s.contract else -1, int(e.contract), at + " contract")
	assert_eq(s.loan.days_left if s.loan else -1, int(e.loan), at + " loan")
	assert_eq(s.scenario, StringName(e.scenario), at + " scenario")
	assert_eq(s.daily_days_left, int(e.daily_left), at + " daily days")
	assert_eq(s.goals_done, Array(e.goals.map(func(x: String) -> StringName: return StringName(x)), TYPE_STRING_NAME, &"", null), at + " goals")
	assert_eq(s.empire_won, bool(e.empire), at + " empire")
	assert_eq(s.scenario_won, bool(e.won), at + " scenario won")
	assert_eq(s.room, Vector2i(int(e.room[0]), int(e.room[1])), at + " room")
	assert_eq(s.staff.size(), e.staff.size(), at + " staff count")
	for i in mini(s.staff.size(), e.staff.size()):
		assert_eq(s.staff[i].def.id, StringName(e.staff[i][0]), at + " staff %d" % i)
		assert_almost_eq(s.staff[i].morale, float(e.staff[i][1]), EPS, at + " staff %d morale" % i)
		assert_eq(s.staff[i].trained, bool(e.staff[i][2]), at + " staff %d trained" % i)
	assert_eq(s.machines.size(), e.machines.size(), at + " machine count")
	for i in mini(s.machines.size(), e.machines.size()):
		var m := s.machines[i]
		var em: Dictionary = e.machines[i]
		var where := "%s machine %d (%s)" % [at, i, em.id]
		assert_eq(m.def.id, StringName(em.id), where)
		assert_almost_eq(m.hp, float(em.hp), EPS, where + " hp")
		assert_almost_eq(m.max_hp, float(em.max), EPS, where + " max hp")
		assert_almost_eq(m.jackpot_pot, float(em.pot), EPS, where + " jackpot")
		assert_eq(m.tune_up_level, int(em.tune), where + " tune-up")
		assert_eq(m.stock.size(), em.qty.size(), where + " stock lines")
		for j in mini(m.stock.size(), em.qty.size()):
			assert_almost_eq(m.stock[j].qty, float(em.qty[j]), EPS, where + " stock %d" % j)

extends GutTest
## Replays setups through the Godot sim and checks every day against the
## original TypeScript sim. fixtures/sim_parity.json was produced by running the
## original `runDay` in Node on the same configs (see each run's "config").

const H := preload("res://tests/sim_test_helper.gd")
const FIXTURE := "res://tests/fixtures/sim_parity.json"
const EPS := 1e-6

const MUL_FIELDS := {
	dayRhythmMul = "day_rhythm_mul", diffFootMul = "diff_foot_mul", promoFootMul = "promo_foot_mul",
	weatherFootMul = "weather_foot_mul", buzzFootMul = "buzz_foot_mul", rivalFootMul = "rival_foot_mul",
	researchFootMul = "research_foot_mul", prestigeMul = "prestige_mul", promoEarnMul = "promo_earn_mul",
	researchEarnMul = "research_earn_mul", researchElecMul = "research_elec_mul",
}

var runs: Array = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))


func test_all_runs_match_the_original() -> void:
	assert_eq(runs.size(), 4)
	for run: Dictionary in runs:
		_check_run(run)


func _check_run(run: Dictionary) -> void:
	var c: Dictionary = run.config
	var name: String = c.name
	var state := H.make_state({ cash = c.cash, rep = c.rep, day = int(c.day) })
	for spec: Dictionary in c.machines:
		var m := H.machine(state, StringName(spec.id))
		if spec.has("hp"):
			m.hp = spec.hp
		if spec.has("dips"):
			for k: String in spec.dips:
				m.dips[StringName(k)] = int(spec.dips[k])
		if spec.has("mods"):
			m.tune_up_level = int(spec.mods.get("earn", 0))
			m.reinforce_level = int(spec.mods.get("dura", 0))
		if spec.has("price"):
			m.price_per_play = spec.price
		if spec.has("zoneMul"):
			m.zone_mul = spec.zoneMul
		state.machines.append(m)
	for id: String in c.staff:
		H.hire(state, StringName(id))
	for id: String in c.upgrades:
		state.upgrades.append(H.DATA.upgrade(StringName(id)))
	if c.has("loan"):
		state.loan = LoanState.new()
		state.loan.amount = c.loan.amount
		state.loan.total_owed = c.loan.totalOwed
		state.loan.daily_payment = c.loan.dailyPayment
		state.loan.days_left = int(c.loan.daysLeft)
		state.loan.days_total = int(c.loan.daysTotal)
	for key: String in c.get("muls", {}):
		state.set(MUL_FIELDS[key], c.muls[key])

	var sim := H.sim(int(c.seed))
	for expected: Dictionary in run.days:
		sim.run_day(state)
		var at := "%s day %d" % [name, expected.day]
		assert_eq(state.day, int(expected.day), at)
		assert_almost_eq(state.cash, float(expected.cash), EPS, at + " cash")
		assert_almost_eq(state.rep, float(expected.rep), EPS, at + " rep")
		assert_eq(state.last_day_customers, int(expected.customers), at + " customers")
		assert_almost_eq(state.last_day_earned, float(expected.earned), EPS, at + " earned")
		assert_almost_eq(state.last_day_cost, float(expected.cost), EPS, at + " cost")
		assert_eq(state.total_repairs, int(expected.repairs), at + " repairs")
		assert_eq(state.loan.days_left if state.loan else -1, int(expected.loan_days), at + " loan")
		var pending := state.pending_repairs.map(func(id: int) -> int: return state.machines.find(state.machine_by_id(id)))
		assert_eq(pending, expected.pending.map(func(i: float) -> int: return int(i)), at + " pending repairs")
		for i in state.machines.size():
			var m := state.machines[i]
			var em: Dictionary = expected.machines[i]
			assert_almost_eq(m.hp, float(em.hp), EPS, "%s machine %d hp" % [at, i])
			assert_almost_eq(m.total_earned, float(em.total), EPS, "%s machine %d earned" % [at, i])
			for j in m.stock.size():
				assert_almost_eq(m.stock[j].qty, float(em.qty[j]), EPS, "%s machine %d stock %d" % [at, i, j])
		if is_failing():
			return

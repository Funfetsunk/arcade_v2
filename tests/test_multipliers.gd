extends GutTest
## Port of tests/marketing.test.ts and tests/meta.test.ts: the neutral-default
## multipliers take effect when set.

const H := preload("res://tests/sim_test_helper.gd")


func _day(machine_id: StringName, seed_value: int, overrides: Dictionary) -> GameState:
	var s := H.make_state(overrides.merged({ cash = 5000.0, rep = 30.0 }))
	s.machines.append(H.machine(s, machine_id))
	H.sim(seed_value).run_day(s)
	return s


func test_campaigns_scale() -> void:
	var c := H.DATA.campaigns
	assert_lt(c[0].foot_mul, c[-1].foot_mul)
	assert_lt(c[0].cost, c[-1].cost)


func test_campaign_raises_visitors() -> void:
	assert_gt(_day(&"claw", 7, { promo_foot_mul = 1.5 }).last_day_customers,
		_day(&"claw", 7, {}).last_day_customers)


func test_discount_cuts_takings() -> void:
	var cut := _day(&"pinball", 7, { promo_earn_mul = H.DATA.balance.discount_earn_mul })
	assert_lt(cut.last_day_earned, _day(&"pinball", 7, {}).last_day_earned)


func test_difficulty_order_and_fallback() -> void:
	var d := H.DATA
	assert_gt(d.difficulty(&"easy").foot_mul, d.difficulty(&"normal").foot_mul)
	assert_gt(d.difficulty(&"normal").foot_mul, d.difficulty(&"hard").foot_mul)
	assert_eq(d.difficulty(&"???").id, &"normal")


func test_prestige_multiplier() -> void:
	assert_eq(H.DATA.prestige_mul(0), 1.0)
	assert_almost_eq(H.DATA.prestige_mul(5), 1.15, 1e-9)


func test_casual_draws_more_than_tycoon() -> void:
	var easy := _day(&"claw", 42, { diff_foot_mul = H.DATA.difficulty(&"easy").foot_mul })
	var hard := _day(&"claw", 42, { diff_foot_mul = H.DATA.difficulty(&"hard").foot_mul })
	assert_gt(easy.last_day_customers, hard.last_day_customers)


func test_prestige_raises_earnings() -> void:
	assert_gt(_day(&"pinball", 42, { prestige_mul = 1.3 }).last_day_earned,
		_day(&"pinball", 42, {}).last_day_earned)

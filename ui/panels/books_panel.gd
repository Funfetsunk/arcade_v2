extends VBoxContainer
## The books: yesterday's takings and costs, running totals, and loans.

var title := "BOOKS"
var ui: GameUI


func refresh() -> void:
	UiKit.clear(self)
	var s := Game.state
	add_child(UiKit.section("YESTERDAY"))
	add_child(UiKit.stat_row("Revenue", GameMath.money(s.last_day_earned), Color("ffd866")))
	add_child(UiKit.stat_row("Rent", GameMath.money(-s.last_day_rent)))
	add_child(UiKit.stat_row("Electricity", GameMath.money(-s.last_day_elec)))
	add_child(UiKit.stat_row("Wages", GameMath.money(-s.last_day_wages)))
	if s.last_day_loan > 0.0:
		add_child(UiKit.stat_row("Loan repayment", GameMath.money(-s.last_day_loan)))
	if s.last_day_repair > 0.0:
		add_child(UiKit.stat_row("Repairs", GameMath.money(-s.last_day_repair)))
	var net := s.last_day_earned - s.last_day_cost
	add_child(UiKit.stat_row("Net", GameMath.money(net), Color("7cff6b") if net >= 0.0 else Color("ff4f7b")))
	add_child(UiKit.section("RUNNING COSTS (per day, before takings)"))
	var b := Data.db.balance
	add_child(UiKit.stat_row("Rent / Electricity / Wages", "%s / %s / %s" % [GameMath.money(Economy.daily_rent(s, b)), GameMath.money(Economy.daily_elec(s, b)), GameMath.money(Economy.daily_wages(s))]))
	add_child(UiKit.section("ALL TIME"))
	add_child(UiKit.stat_row("Total earned", GameMath.money(s.total_earned)))
	add_child(UiKit.stat_row("Total spent", GameMath.money(s.total_spent)))
	add_child(UiKit.stat_row("Visitors", str(s.total_customers)))
	add_child(UiKit.stat_row("Best day", GameMath.money(s.biggest_day) if s.has_biggest_day else "—"))
	add_child(UiKit.stat_row("Repairs", "%d (%s)" % [s.total_repairs, GameMath.money(s.total_repair_cost)]))
	_loans()


func _loans() -> void:
	var s := Game.state
	add_child(UiKit.section("LOANS"))
	if s.loan:
		var remaining := s.loan.daily_payment * s.loan.days_left
		add_child(UiKit.label("%s/day for %d more days (%s left to pay)." % [GameMath.money(s.loan.daily_payment), s.loan.days_left, GameMath.money(remaining)], &"", true))
		add_child(UiKit.button("Repay early %s" % GameMath.money(remaining), func() -> void:
			if Game.actions.repay_loan_early(Game.state):
				EventBus.state_changed.emit(), &"PrimaryButton", s.cash >= remaining))
		return
	for tier in Data.db.loan_tiers:
		var owed := GameMath.js_round(tier.amount * (1.0 + tier.rate))
		var daily := ceili(owed / float(tier.days))
		var take := UiKit.button("Take", func() -> void:
			if Game.actions.take_loan(Game.state, tier):
				EventBus.state_changed.emit())
		add_child(UiKit.card(tier.emoji, "%s  %s" % [tier.label, GameMath.money(tier.amount)],
			"Repay %s/day for %d days (%d%% interest)." % [GameMath.money(daily), tier.days, GameMath.js_round(tier.rate * 100.0)], take))

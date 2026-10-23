extends VBoxContainer
## The books: goals, the daily snapshot, loans, reputation, metrics and the
## machine charts (top earners or most-played, with rank movement).

enum Period { ALL, WEEK, YESTERDAY }
enum Metric { EARNED, PLAYS }

var title := "BOOKS"
var ui: GameUI
var _period := Period.ALL
var _metric := Metric.EARNED


func refresh() -> void:
	UiKit.clear(self)
	var s := Game.state
	_goals(s)
	_snapshot(s)
	_loans(s)
	add_child(UiKit.section("REPUTATION"))
	var rep_bar := UiKit.bar(minf(100.0, s.rep), 100.0, Color("ffb703"))
	rep_bar.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(UiKit.hbox([UiKit.label(_rep_tier(s.rep)), rep_bar, UiKit.label("%d/100" % floori(s.rep))]))
	add_child(UiKit.section("METRICS"))
	var b := Data.db.balance
	var today := Economy.daily_rent(s, b) + Economy.daily_elec(s, b) + Economy.daily_wages(s) + (s.loan.daily_payment if s.loan else 0.0)
	add_child(UiKit.stat_row("Total earned", GameMath.money(s.total_earned)))
	add_child(UiKit.stat_row("Machines", str(s.machines.size())))
	add_child(UiKit.stat_row("All visitors", str(s.total_customers)))
	add_child(UiKit.stat_row("Best day", GameMath.money(s.biggest_day) if s.has_biggest_day else "—"))
	add_child(UiKit.stat_row("Repair cost", GameMath.money(s.total_repair_cost)))
	add_child(UiKit.stat_row("Today's costs", GameMath.money(today)))
	_charts(s)


func _goals(s: GameState) -> void:
	add_child(UiKit.section("🎯 GOALS"))
	for goal in Data.db.goals:
		var done := s.goals_done.has(goal.id)
		var current := minf(goal.requirement.current(s), goal.requirement.target)
		var reward := GameMath.money(goal.reward) if goal.reward_kind == GoalDef.RewardKind.CASH else "+%d rep" % goal.reward
		var row := UiKit.hbox([UiKit.label(("✓ " if done else "") + goal.label, &"DimLabel" if done else &""), UiKit.spacer(), UiKit.label("DONE" if done else reward)])
		add_child(row)
		if not done:
			var progress := UiKit.bar(current, goal.requirement.target, Color("4fd8ff"))
			progress.size_flags_horizontal = SIZE_EXPAND_FILL
			add_child(progress)


func _snapshot(s: GameState) -> void:
	var b := Data.db.balance
	var ran := s.days_run > 0
	add_child(UiKit.section("DAILY SNAPSHOT"))
	add_child(UiKit.stat_row("Machine revenue", GameMath.money(s.last_day_earned) if ran else "—", Color("ffd866")))
	add_child(UiKit.stat_row("Daily rent", GameMath.money(-(s.last_day_rent if ran else float(Economy.daily_rent(s, b))))))
	add_child(UiKit.stat_row("Electricity", GameMath.money(-(s.last_day_elec if ran else float(Economy.daily_elec(s, b))))))
	add_child(UiKit.stat_row("Staff wages", GameMath.money(-(s.last_day_wages if ran else float(Economy.daily_wages(s))))))
	var loan := s.last_day_loan if ran else (s.loan.daily_payment if s.loan else 0.0)
	if loan > 0.0:
		add_child(UiKit.stat_row("Loan repayment", GameMath.money(-loan)))
	if ran and s.last_day_repair > 0.0:
		add_child(UiKit.stat_row("Repairs", GameMath.money(-s.last_day_repair)))
	var net := s.last_day_earned - s.last_day_cost
	add_child(UiKit.stat_row("NET LAST DAY" if ran else "PROJECTED NET", GameMath.money(net) if ran else "—", Color("7cff6b") if net >= 0.0 else Color("ff4f7b")))


func _loans(s: GameState) -> void:
	if s.loan:
		var remaining := s.loan.daily_payment * s.loan.days_left
		add_child(UiKit.section("ACTIVE LOAN"))
		add_child(UiKit.stat_row("Remaining", GameMath.money(remaining)))
		add_child(UiKit.stat_row("Daily payment", GameMath.money(s.loan.daily_payment)))
		add_child(UiKit.stat_row("Days left", "%d / %d" % [s.loan.days_left, s.loan.days_total]))
		add_child(UiKit.button("💰 REPAY IN FULL (%s)" % GameMath.money(remaining), func() -> void:
			if Game.actions.repay_loan_early(Game.state):
				EventBus.state_changed.emit(), &"PrimaryButton", s.cash >= remaining))
		return
	add_child(UiKit.section("TAKE A LOAN"))
	add_child(UiKit.label("One loan at a time. Repaid in daily instalments.", &"DimLabel", true))
	for tier in Data.db.loan_tiers:
		var owed := GameMath.js_round(tier.amount * (1.0 + tier.rate))
		var daily := ceili(owed / float(tier.days))
		add_child(UiKit.card(tier.emoji, tier.label, "%s received · %s total · %s/day × %d days · %d%% interest" % [GameMath.money(tier.amount), GameMath.money(owed), GameMath.money(daily), tier.days, GameMath.js_round(tier.rate * 100.0)],
			UiKit.button("TAKE", func() -> void:
				if Game.actions.take_loan(Game.state, tier):
					EventBus.state_changed.emit())))


func _charts(s: GameState) -> void:
	add_child(UiKit.section("MACHINE CHARTS"))
	add_child(_toggle_row(["ALL TIME", "LAST 7D", "YESTERDAY"], _period, func(i: int) -> void: _period = i as Period))
	add_child(_toggle_row(["$ EARNED", "USES"], _metric, func(i: int) -> void: _metric = i as Metric))
	add_child(UiKit.label("▲ up  ▼ down  — same  ★ new", &"DimLabel"))
	if s.machines.is_empty():
		add_child(UiKit.label("No machines yet.", &"DimLabel"))
		return
	var ranked := _rank(s, _window)
	var previous := {}
	var prev_ranked := _rank(s, _previous_window)
	for i in prev_ranked.size():
		previous[prev_ranked[i].m] = i + 1
	if ranked.all(func(r: Dictionary) -> bool: return r.days == 0):
		add_child(UiKit.label("No data yet — run a day first.", &"DimLabel"))
		return
	for i in mini(10, ranked.size()):
		var r: Dictionary = ranked[i]
		var m: MachineInstance = r.m
		var arrow := "★"
		if previous.has(m) and prev_ranked[previous[m] - 1].days > 0:
			var before: int = previous[m]
			arrow = "▲" if before > i + 1 else "▼" if before < i + 1 else "—"
		var value := str(r.plays) if _metric == Metric.PLAYS else GameMath.money(r.earn)
		add_child(UiKit.hbox([UiKit.label("%d" % (i + 1), &"DimLabel"), UiKit.label(m.def.emoji), UiKit.label(m.def.display_name), UiKit.spacer(), UiKit.label(arrow, &"DimLabel"), UiKit.label(value)]))


## Machines sorted by the chosen metric over a window of their day history.
func _rank(s: GameState, window: Callable) -> Array:
	var rows := []
	for m in s.machines:
		var earn := 0
		var plays := 0
		var days: Array = window.call(m.day_stats)
		for d: Vector3i in days:
			earn += d.y
			plays += d.z
		rows.append({ m = m, earn = earn, plays = plays, days = days.size() })
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a.plays > b.plays) if _metric == Metric.PLAYS else (a.earn > b.earn))
	return rows


func _window(stats: Array[Vector3i]) -> Array:
	match _period:
		Period.YESTERDAY:
			return stats.slice(-1)
		Period.WEEK:
			return stats.slice(-7)
	return stats


## The window before the current one, for the rank arrows.
func _previous_window(stats: Array[Vector3i]) -> Array:
	match _period:
		Period.YESTERDAY:
			return stats.slice(-2, -1) if stats.size() >= 2 else []
		Period.WEEK:
			return stats.slice(-14, -7)
	return stats.slice(0, -1) if stats.size() > 1 else stats


func _toggle_row(labels: Array, selected: int, on_pick: Callable) -> HBoxContainer:
	var row := UiKit.hbox([], 3)
	var group := ButtonGroup.new()
	for i in labels.size():
		var b := UiKit.button(labels[i], func() -> void:
			on_pick.call(i)
			refresh(), &"TabButton")
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == selected
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.add_theme_font_size_override(&"font_size", 9)
		row.add_child(b)
	return row


static func _rep_tier(rep: float) -> String:
	if rep < 20.0:
		return "Local Curiosity"
	if rep < 40.0:
		return "Community Fave"
	if rep < 60.0:
		return "Regional Hot Spot"
	if rep < 80.0:
		return "City Legend"
	return "🏆 Arcade Empire"

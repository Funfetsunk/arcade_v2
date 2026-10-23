extends VBoxContainer
## Today's date-seeded challenge and the best scores of recent days.

var title := "DAILY CHALLENGE"
var ui: GameUI


func refresh() -> void:
	UiKit.clear(self)
	var date := Time.get_date_string_from_system()
	var variant := Data.db.daily_variant(date)
	var best: int = Game.meta.daily_bests.get(date, 0)
	add_child(UiKit.section(date))
	add_child(UiKit.label(variant.blurb, &"", true))
	add_child(UiKit.stat_row("Goal", "Most earned in %d days" % Data.db.balance.daily_challenge_days))
	add_child(UiKit.stat_row("Your best today", GameMath.money(best) if best else "—"))
	add_child(UiKit.button("🔁 BEAT YOUR BEST" if best else "▶ START CHALLENGE", func() -> void:
		ui.modal.confirm("📅 START DAILY CHALLENGE?", "\"%s\"\n\nEarn the most over %d days. Replaces your current game." % [variant.blurb, Data.db.balance.daily_challenge_days], "📅 START", func() -> void:
			ui.close_sheet()
			Game.start_daily(date)), &"PrimaryButton"))
	var days := Game.meta.daily_bests.keys()
	days.sort()
	days.reverse()
	if not days.is_empty():
		add_child(UiKit.section("RECENT DAYS"))
		for day: String in days.slice(0, 6):
			add_child(UiKit.stat_row(day, GameMath.money(Game.meta.daily_bests[day])))

extends VBoxContainer
## Difficulty, prestige and the perk tree.

var title := "PROGRESS"
var ui: GameUI


func refresh() -> void:
	UiKit.clear(self)
	var s := Game.state
	var meta := Game.meta
	add_child(UiKit.section("DIFFICULTY"))
	for d in Data.db.difficulties:
		var on := Data.db.difficulty(s.difficulty) == d
		add_child(UiKit.card(d.emoji, "%s  %d%% footfall" % [d.display_name, GameMath.js_round(d.foot_mul * 100.0)], d.blurb,
			UiKit.button("✓" if on else "PICK", func() -> void:
				Game.actions.set_difficulty(Game.state, d)
				EventBus.state_changed.emit(), &"PrimaryButton" if on else &"", not on)))
	add_child(UiKit.section("PRESTIGE"))
	add_child(UiKit.stat_row("Prestige level", "⭐ %d" % meta.prestige_level))
	add_child(UiKit.stat_row("Points to spend", str(meta.perk_points())))
	add_child(UiKit.label("Prestige resets your arcade and grants 1 point to spend on perks below. Unlocks once you complete every goal.", &"DimLabel", true))
	add_child(UiKit.button("⭐ PRESTIGE (+1 point)" if Game.can_prestige() else "WIN THE EMPIRE TO PRESTIGE", func() -> void:
		ui.modal.confirm("⭐ PRESTIGE?", "Start a brand-new arcade with one more perk point to spend.", "⭐ PRESTIGE", func() -> void:
			ui.close_sheet()
			Game.prestige()), &"PrimaryButton", Game.can_prestige()))
	add_child(UiKit.section("PERKS — %d pt%s" % [meta.perk_points(), "" if meta.perk_points() == 1 else "s"]))
	for p in Data.db.perks:
		var rank := meta.perk_rank(p.id)
		var maxed := rank >= p.max_rank
		add_child(UiKit.card(p.emoji, "%s  %s" % [p.display_name, "●".repeat(rank) + "○".repeat(p.max_rank - rank)], p.description,
			UiKit.button("MAXED" if maxed else "+1", func() -> void:
				if Game.actions.buy_perk(Game.state, p):
					Game.save_meta()
					EventBus.state_changed.emit(), &"", not maxed and meta.perk_points() > 0)))

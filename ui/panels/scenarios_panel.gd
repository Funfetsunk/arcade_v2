extends VBoxContainer
## Pick a scenario. Starting one replaces the current game.

var title := "SCENARIOS"
var ui: GameUI


func refresh() -> void:
	UiKit.clear(self)
	add_child(UiKit.button("📅 DAILY CHALLENGE", ui.open_screen.bind(&"daily"), &"PrimaryButton"))
	add_child(UiKit.label("Pick a challenge. Starting one resets your current game.", &"DimLabel", true))
	var current := Game.state.scenario
	for sc in Data.db.scenarios:
		var playing := sc.id == current
		var goal := "" if sc.id == &"free" else "\n🎯 %s%s" % [sc.goal_label, " · par %dd" % sc.par_days if sc.par_days else ""]
		var start := UiKit.button("ACTIVE" if playing else "START", func() -> void:
			if playing and not Game.state.scenario_won:
				EventBus.toast_requested.emit("Already playing this scenario.", Sim.LogKind.INFO)
				return
			ui.modal.confirm("START \"%s\"?" % sc.display_name.to_upper(), "Your current game will be replaced.", "🎯 START", func() -> void:
				ui.close_sheet()
				Game.new_game(sc.id)
				Sfx.buy()), &"" if playing else &"PrimaryButton")
		add_child(UiKit.card(sc.emoji, sc.display_name + ("  • PLAYING" if playing else ""), sc.blurb + goal, start))

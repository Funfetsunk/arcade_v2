extends VBoxContainer
## The game menu: every secondary screen, plus restart.

var title := "MENU"
var ui: GameUI

const ENTRIES := [
	["❓ HOW TO PLAY", &"tutorial"],
	["🎯 SCENARIOS", &"scenarios"],
	["📅 DAILY CHALLENGE", &"daily"],
	["📣 MARKETING", &"marketing"],
	["📋 CONTRACTS", &"contracts"],
	["🔬 RESEARCH & DEVELOPMENT", &"research"],
	["🏬 FRANCHISES", &"franchises"],
	["🎨 DECOR", &"decor"],
	["📈 PROGRESS", &"progress"],
	["🏅 ACHIEVEMENTS", &"achievements"],
	["🏆 LEADERBOARD", &"leaderboard"],
	["🎬 CREDITS", &"credits"],
]


func refresh() -> void:
	UiKit.clear(self)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 6)
	grid.add_theme_constant_override(&"v_separation", 6)
	for entry: Array in ENTRIES:
		var b := UiKit.button(entry[0], ui.open_screen.bind(entry[1]))
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(b)
	add_child(grid)
	add_child(HSeparator.new())
	add_child(UiKit.button("🔄 RESTART GAME", func() -> void:
		ui.modal.confirm("🔄 RESTART?", "All progress in this arcade will be lost.", "Restart", func() -> void:
			ui.close_sheet()
			Game.restart(), true), &"DangerButton"))

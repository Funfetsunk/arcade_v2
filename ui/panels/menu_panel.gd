extends VBoxContainer
## The game menu: every secondary screen, plus restart.

var title := "MENU"
var ui: GameUI

## Label, screen id, icon.
const ENTRIES := [
	["HOW TO PLAY", &"tutorial", &"help"],
	["SCENARIOS", &"scenarios", &"scenarios"],
	["DAILY CHALLENGE", &"daily", &"daily"],
	["MARKETING", &"marketing", &"marketing"],
	["CONTRACTS", &"contracts", &"contracts"],
	["RESEARCH & DEVELOPMENT", &"research", &"research"],
	["FRANCHISES", &"franchises", &"franchises"],
	["DECOR", &"decor", &"decor"],
	["PROGRESS", &"progress", &"progress"],
	["ACHIEVEMENTS", &"achievements", &"achievements"],
	["LEADERBOARD", &"leaderboard", &"leaderboard"],
	["CREDITS", &"credits", &"credits"],
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
		b.icon = Icons.named(entry[2])
		grid.add_child(b)
	add_child(grid)
	add_child(HSeparator.new())
	var restart := UiKit.button("RESTART GAME", func() -> void:
		ui.modal.confirm("🔄 RESTART?", "All progress in this arcade will be lost.", "Restart", func() -> void:
			ui.close_sheet()
			Game.restart(), true), &"DangerButton")
	restart.icon = Icons.named(&"restart")
	add_child(restart)

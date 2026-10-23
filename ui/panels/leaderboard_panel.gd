extends VBoxContainer
## The best runs recorded on this device.

var title := "LEADERBOARD"
var ui: GameUI


func refresh() -> void:
	UiKit.clear(self)
	var board := Game.meta.leaderboard
	if board.is_empty():
		add_child(UiKit.label("No runs recorded yet.\nWin a scenario or complete the empire to make the board!", &"DimLabel", true))
		return
	for i in board.size():
		var e := board[i]
		var medal: String = ["🥇", "🥈", "🥉"][i] if i < 3 else "#%d" % (i + 1)
		var detail := "%s earned · %d machines · rep %d · %dd · %s%s" % [GameMath.money(e.earned), e.machines, e.rep, e.day, e.scenario_name, " · ⭐%d" % e.prestige if e.prestige else ""]
		add_child(UiKit.card(medal, e.arcade_name + ("  ✓ WON" if e.won else ""), detail))

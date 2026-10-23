extends VBoxContainer
## The arcade at a glance: every machine (tap to manage it) and room expansion.

var title := "FLOOR"
var ui: GameUI


func refresh() -> void:
	UiKit.clear(self)
	var s := Game.state
	var actions := Game.actions
	var cost := actions.expand_cost(s)
	var max_room := Data.db.balance.max_room
	add_child(UiKit.section("ROOM  %d × %d tiles · rent %s/day" % [s.room.x, s.room.y, GameMath.money(Economy.daily_rent(s, Data.db.balance))]))
	var wider := UiKit.button("↔ Wider +%d%s" % [Data.db.balance.expand_step, " (max)" if s.room.x >= max_room.x else ""], _expand.bind(Vector2i.RIGHT), &"", s.room.x < max_room.x and s.cash >= cost)
	var deeper := UiKit.button("↕ Deeper +%d%s" % [Data.db.balance.expand_step, " (max)" if s.room.y >= max_room.y else ""], _expand.bind(Vector2i.DOWN), &"", s.room.y < max_room.y and s.cash >= cost)
	add_child(UiKit.hbox([wider, deeper, UiKit.spacer(), UiKit.label(GameMath.money(cost))]))
	add_child(UiKit.section("MACHINES (%d)" % s.machines.size()))
	if s.machines.is_empty():
		add_child(UiKit.label("Empty floor — visit the shop to buy your first machine.", &"DimLabel", true))
	for m in s.machines:
		var status := "⛔ broken" if m.is_broken() else "%d%%" % GameMath.js_round(m.hp)
		var last := m.day_stats[-1].y if not m.day_stats.is_empty() else 0
		var open := UiKit.button("Manage", func() -> void:
			ui.arcade_floor.select(m.id))
		add_child(UiKit.card(m.def.emoji, m.def.display_name, "Condition %s · yesterday %s" % [status, GameMath.money(last)], open))


func _expand(axis: Vector2i) -> void:
	if Game.actions.expand_room(Game.state, axis):
		EventBus.state_changed.emit()

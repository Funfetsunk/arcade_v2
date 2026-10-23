extends VBoxContainer
## Badges that survive across runs.

var title := "ACHIEVEMENTS"
var ui: GameUI


func refresh() -> void:
	UiKit.clear(self)
	var unlocked := Game.meta.achievements
	add_child(UiKit.label("%d / %d unlocked" % [unlocked.size(), Data.db.achievements.size()], &"DimLabel"))
	for a in Data.db.achievements:
		var on := unlocked.has(a.id)
		var card := UiKit.card(a.emoji if on else "🔒", a.title + ("  ✓" if on else ""), a.description)
		if not on:
			card.modulate = Color(1, 1, 1, 0.6)
		add_child(card)

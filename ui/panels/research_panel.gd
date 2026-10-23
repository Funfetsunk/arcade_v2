extends VBoxContainer
## R&D projects: permanent bonuses for this run, some with prerequisites.

var title := "RESEARCH & DEVELOPMENT"
var ui: GameUI


func refresh() -> void:
	UiKit.clear(self)
	var s := Game.state
	add_child(UiKit.label("Invest in research for permanent bonuses this run. Some need a prerequisite.", &"DimLabel", true))
	for r in Data.db.research:
		var done := s.research.has(r)
		var locked := Game.actions.research_locked(s, r)
		var detail := r.description
		if locked and not done:
			detail += "\nNeeds %s" % ", ".join(r.requires.map(func(q: ResearchDef) -> String: return q.display_name))
		add_child(UiKit.card(r.emoji, r.display_name + ("  ✓ done" if done else ""), detail,
			UiKit.button("✓" if done else GameMath.money(r.cost), func() -> void:
				if Game.actions.do_research(Game.state, r):
					EventBus.state_changed.emit(), &"", not done and not locked and s.cash >= r.cost)))

extends VBoxContainer
## Franchises in other towns: passive daily income you can invest in.

var title := "FRANCHISES"
var ui: GameUI


func refresh() -> void:
	UiKit.clear(self)
	var s := Game.state
	var req := Data.db.balance.franchise_rep_req
	var locked := s.rep < req
	if not s.franchises.is_empty():
		add_child(UiKit.stat_row("Locations / income", "%d · %s/day" % [s.franchises.size(), GameMath.money(Game.day_cycle.franchise_daily_total(s))]))
		for f in s.franchises:
			var cost := f.town.upgrade_cost(f.level)
			add_child(UiKit.card(f.town.emoji, "%s  Lv %d" % [f.town.display_name, f.level], "Earning %s/day" % GameMath.money(f.town.daily_income(f.level)),
				UiKit.button("⬆ %s" % GameMath.money(cost), func() -> void:
					if Game.actions.upgrade_franchise(Game.state, f.town):
						EventBus.state_changed.emit(), &"", s.cash >= cost)))
	add_child(UiKit.section("OPEN A LOCATION"))
	if locked:
		add_child(UiKit.label("Reach %d rep to start franchising (you're at %d)." % [req, GameMath.js_round(s.rep)], &"DimLabel", true))
	for t in Data.db.towns:
		var owned := s.franchise_in(t) != null
		add_child(UiKit.card(t.emoji, t.display_name + ("  ✓ open" if owned else ""), "%s → %s/day" % [t.blurb, GameMath.money(t.income)],
			UiKit.button("✓" if owned else GameMath.money(t.cost), func() -> void:
				if Game.actions.open_franchise(Game.state, t):
					EventBus.state_changed.emit(), &"", not owned and not locked and s.cash >= t.cost)))

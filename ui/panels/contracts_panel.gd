extends VBoxContainer
## Bookings with a deadline: meet the requirement to collect.

var title := "CONTRACTS"
var ui: GameUI


func refresh() -> void:
	UiKit.clear(self)
	var s := Game.state
	if s.contract:
		var c := s.contract.def
		add_child(UiKit.section("ACTIVE  %s %s" % [c.emoji, c.display_name]))
		add_child(UiKit.stat_row("Days left", str(s.contract.days_left)))
		var met := Game.day_cycle.contract_met(s, c.id)
		add_child(UiKit.stat_row("Status", "✓ requirement met" if met else "not yet met", Color("7cff6b") if met else Color("ffb703")))
		add_child(UiKit.stat_row("Reward", GameMath.money(c.cash) + (" · +%d rep" % c.rep if c.rep else "")))
	else:
		add_child(UiKit.label("Accept a booking and meet its requirement by the deadline to collect.", &"DimLabel", true))
	add_child(UiKit.section("AVAILABLE"))
	for c in Data.db.contracts:
		var active := s.contract != null and s.contract.def == c
		var locked := not Game.actions.can_accept_contract(s, c)
		var detail := "%s Needs %s. → %s%s" % [c.blurb, c.need, GameMath.money(c.cash), " +%d rep" % c.rep if c.rep else ""]
		if locked:
			detail += "\n🔒 Build a Prize Booth to take this."
		add_child(UiKit.card(c.emoji, "%s  %dd" % [c.display_name, c.days], detail,
			UiKit.button("ACTIVE" if active else "TAKE", func() -> void:
				if Game.actions.accept_contract(Game.state, c):
					EventBus.state_changed.emit(), &"", s.contract == null and not locked)))

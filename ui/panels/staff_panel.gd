extends VBoxContainer
## The crew: who's hired (morale, train, fire) and who can be hired.

var title := "STAFF"
var ui: GameUI


func refresh() -> void:
	UiKit.clear(self)
	var s := Game.state
	add_child(UiKit.section("YOUR CREW"))
	if s.staff.is_empty():
		add_child(UiKit.label("Nobody hired yet.", &"DimLabel"))
	for member in s.staff:
		var morale := UiKit.hbox([UiKit.label("Morale", &"DimLabel"), UiKit.bar(member.morale, 100.0, UiKit.condition_color(member.morale))])
		morale.get_child(1).size_flags_horizontal = SIZE_EXPAND_FILL
		var train := UiKit.button("Trained" if member.trained else "Train %s" % GameMath.money(Game.actions.train_cost(member)), func() -> void:
			if Game.actions.train_staff(Game.state, member):
				EventBus.state_changed.emit(), &"", not member.trained)
		var fire := UiKit.button("Fire", func() -> void:
			ui.modal.confirm("Fire %s?" % member.def.display_name, "They'll leave right away.", "Fire", func() -> void:
				Game.actions.fire_staff(Game.state, member)
				EventBus.state_changed.emit(), true), &"DangerButton")
		var info := UiKit.vbox([
			UiKit.label("%s — %s/day" % [member.def.display_name, GameMath.money(member.def.wage)]),
			UiKit.label(member.def.role, &"DimLabel", true), morale, UiKit.hbox([train, fire])], 2)
		info.size_flags_horizontal = SIZE_EXPAND_FILL
		var card := PanelContainer.new()
		card.theme_type_variation = &"CardPanel"
		var icon := UiKit.label(member.def.emoji)
		icon.add_theme_font_size_override(&"font_size", 18)
		card.add_child(UiKit.hbox([icon, info]))
		add_child(card)

	add_child(UiKit.section("HIRE  (needs a 3-day wage deposit on hand)"))
	for role in Data.db.staff:
		var reason := ""
		if s.rep < role.rep_req:
			reason = "REP %d" % role.rep_req
		elif role.id == &"tech_senior" and not Game.actions.senior_tech_unlocked(s):
			reason = "JUNIOR 1ST"
		var affordable := s.cash >= role.wage * 3
		var action := UiKit.button(reason if reason else "HIRE", func() -> void:
			if Game.actions.hire_staff(Game.state, role):
				EventBus.state_changed.emit(), &"PrimaryButton" if reason.is_empty() and affordable else &"", reason.is_empty() and affordable)
		add_child(UiKit.card(role.emoji, "%s — %s/day" % [role.display_name, GameMath.money(role.wage)], role.role, action))

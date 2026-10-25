extends VBoxContainer
## The arcade's name, its theme, decor props and customer facilities.

var title := "DECOR"
var ui: GameUI


func refresh() -> void:
	UiKit.clear(self)
	var s := Game.state
	var actions := Game.actions
	add_child(UiKit.section("ARCADE NAME"))
	var name_edit := LineEdit.new()
	name_edit.text = s.arcade_name
	name_edit.max_length = 20
	name_edit.text_changed.connect(func(text: String) -> void:
		actions.set_arcade_name(Game.state, text)
		EventBus.arcade_renamed.emit())
	name_edit.focus_exited.connect(Game.save_game)
	add_child(name_edit)
	add_child(UiKit.label("Shown on the neon sign over your back wall.", &"DimLabel", true))

	add_child(UiKit.section("🎵 JUKEBOX"))
	var tracks := HFlowContainer.new()
	tracks.add_theme_constant_override(&"h_separation", 6)
	tracks.add_theme_constant_override(&"v_separation", 6)
	for t in Sfx.TRACKS:
		var on: bool = t.id == Sfx.track()
		tracks.add_child(UiKit.button(("▶ " if on else "") + t.name, func() -> void:
			Sfx.set_track(t.id)
			EventBus.state_changed.emit(), &"PrimaryButton" if on else &""))
	add_child(tracks)

	add_child(UiKit.section("THEME"))
	for t in Data.db.themes:
		var on := t.id == s.theme
		add_child(UiKit.card(t.emoji, t.display_name + ("  • active" if on else ""), "",
			UiKit.button("✓" if on else "USE", func() -> void:
				actions.set_theme(Game.state, t)
				Sfx.click()
				EventBus.state_changed.emit(), &"PrimaryButton" if on else &"", not on)))

	var max_decor := Data.db.balance.max_decor
	var header := UiKit.hbox([UiKit.section("PROPS  %d/%d" % [s.decor.size(), max_decor]), UiKit.spacer()])
	if not s.decor.is_empty():
		header.add_child(UiKit.button("↩ REMOVE LAST", func() -> void:
			if actions.remove_last_decor(Game.state):
				EventBus.state_changed.emit()))
	add_child(header)
	for p in Data.db.decor_props:
		var owned := s.decor.count(p)
		add_child(UiKit.card(p.emoji, p.display_name + ("  ×%d" % owned if owned else ""), "%s +%d mood" % [p.blurb, p.satisfaction],
			UiKit.button(GameMath.money(p.cost), _do.bind(actions.buy_decor.bind(s, p)), &"", s.decor.size() < max_decor and s.cash >= p.cost)))

	add_child(UiKit.section("FACILITIES"))
	for f in Data.db.facilities:
		var owned := s.facilities.has(f)
		var needed := not owned and s.last_day_customers > f.need_at
		add_child(UiKit.card(f.emoji, f.display_name + ("  ✓ installed" if owned else "  ⚠ needed" if needed else ""), f.blurb,
			UiKit.button("✓" if owned else GameMath.money(f.cost), _do.bind(actions.buy_facility.bind(s, f)), &"", not owned and s.cash >= f.cost)))


func _do(action: Callable) -> void:
	if action.call():
		EventBus.state_changed.emit()

extends VBoxContainer
## Buy machines (placed on the floor after picking a spot) and arcade upgrades.

enum Tab { MACHINES, UPGRADES }

var title := "SHOP"
var ui: GameUI
var _tab := Tab.MACHINES


func refresh() -> void:
	UiKit.clear(self)
	var tabs := ButtonGroup.new()
	var row := UiKit.hbox([])
	for t: Tab in [Tab.MACHINES, Tab.UPGRADES]:
		var b := UiKit.button(["MACHINES", "UPGRADES"][t], func() -> void:
			_tab = t
			refresh(), &"TabButton")
		b.toggle_mode = true
		b.button_group = tabs
		b.button_pressed = t == _tab
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(b)
	add_child(row)
	if _tab == Tab.MACHINES:
		_machines()
	else:
		_upgrades()


func _machines() -> void:
	var s := Game.state
	add_child(UiKit.label("Pick a machine, then drag it to a spot on the floor.", &"DimLabel", true))
	for def in Data.db.machines:
		var locked := s.rep < def.rep_req
		var detail := def.description
		if def.type == MachineDef.Type.ARCADE:
			detail += "\nEarns up to %s/day · ⚡%d/day · ⭐%d" % [GameMath.money(def.base_earn), GameMath.js_round(def.electricity * Data.db.balance.electricity_rate), def.popularity]
		var action: Button
		if locked:
			action = UiKit.button("REP %d" % def.rep_req, func() -> void: pass, &"", false)
		else:
			action = UiKit.button(GameMath.money(def.cost), _buy.bind(def), &"PrimaryButton" if s.cash >= def.cost else &"", s.cash >= def.cost)
			action.add_theme_font_size_override(&"font_size", 11)
		var card := UiKit.card(Icons.machine(def) if def.sprite_for(MachineInstance.Facing.S) else def.emoji, def.display_name, detail, action)
		if locked:
			card.modulate = Color(1, 1, 1, 0.6)
		add_child(card)


func _upgrades() -> void:
	var s := Game.state
	for upgrade in Data.db.upgrades:
		var action: Button
		if s.upgrades.has(upgrade):
			action = UiKit.button("OWNED", func() -> void: pass, &"", false)
		elif s.rep < upgrade.rep_req:
			action = UiKit.button("REP %d" % upgrade.rep_req, func() -> void: pass, &"", false)
		else:
			action = UiKit.button(GameMath.money(upgrade.cost), func() -> void:
				if Game.actions.buy_upgrade(Game.state, upgrade):
					EventBus.state_changed.emit(), &"PrimaryButton" if s.cash >= upgrade.cost else &"", s.cash >= upgrade.cost)
		add_child(UiKit.card(upgrade.emoji, upgrade.display_name, upgrade.description, action))


func _buy(def: MachineDef) -> void:
	ui.close_sheet()
	ui.arcade_floor.start_placing(def)

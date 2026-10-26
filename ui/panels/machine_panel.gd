extends VBoxContainer
## Everything about one machine: status, pricing, upgrades, stock, DIP switches,
## and move / repair / refurbish / sell.

var title := ""
var ui: GameUI
var machine: MachineInstance


func show_machine(m: MachineInstance) -> void:
	machine = m
	title = m.def.display_name


func refresh() -> void:
	UiKit.clear(self)
	var s := Game.state
	if machine == null or not s.machines.has(machine):
		ui.close_sheet()
		return
	var m := machine
	var def := m.def
	var actions := Game.actions
	title = def.display_name
	if def.minigame:
		var play := UiKit.button("🎮 PLAY", func() -> void: ui.play_minigame(m), &"PrimaryButton")
		play.size_flags_horizontal = SIZE_EXPAND_FILL
		add_child(play)
	add_child(UiKit.stat_row("Status", "⛔ NOT WORKING" if m.is_broken() else "✅ WORKING", Color("ff4f7b") if m.is_broken() else Color("7cff6b")))
	var condition := UiKit.hbox([UiKit.label("Condition", &"DimLabel"), UiKit.bar(m.hp, 100.0, UiKit.condition_color(m.hp)),
		UiKit.label("%d%%%s" % [GameMath.js_round(m.hp), " / max %d%%" % GameMath.js_round(m.max_hp) if m.max_hp < 99.0 else ""])])
	condition.get_child(1).size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(condition)
	if m.max_hp < 99.0:
		add_child(UiKit.button("🔧 Refurbish %s → mint" % GameMath.money(actions.refurbish_cost(m)), _do.bind(actions.refurbish_machine.bind(s, m))))
	add_child(UiKit.stat_row("Avg daily earn", GameMath.money(m.total_earned / m.days_active) if m.days_active > 0 else "—"))
	add_child(UiKit.stat_row("Popularity", "⭐ %d" % def.popularity))
	add_child(UiKit.stat_row("Sell value", GameMath.money(actions.sell_value(m)) + (" 📈 vintage" if m.days_active > 60 else "")))
	if def.genre:
		var n := FloorGrid.same_genre_nearby(s.machines, m, Data.db.balance.zone_radius)
		add_child(UiKit.stat_row("Zone", "%s %s %s" % [def.genre.emoji, def.genre.label, "+%d%%" % FloorGrid.zone_pct(n, Data.db.balance) if n > 0 else "(cluster same type)"]))
	if def.special == MachineDef.Special.JACKPOT:
		add_child(UiKit.stat_row("🎰 Jackpot pot", GameMath.money(m.jackpot_pot)))
	elif def.special == MachineDef.Special.BUZZ:
		add_child(UiKit.stat_row("📸 Buzz", "%d → +%d%% crowd" % [GameMath.js_round(s.buzz), GameMath.js_round((s.buzz_foot_mul - 1.0) * 100.0)]))

	if def.type == MachineDef.Type.ARCADE:
		_pricing(m)
	_upgrades(m)
	if def.type != MachineDef.Type.ARCADE:
		_stock(m)
	if not def.dip_switches.is_empty():
		_dips(m)

	add_child(HSeparator.new())
	var row := UiKit.hbox([UiKit.button("✥ Move", func() -> void:
		ui.close_sheet()
		ui.arcade_floor.start_moving(m))])
	if m.is_broken():
		row.add_child(UiKit.button("🔧 Repair %s" % GameMath.money(actions.repair_cost(s)), _do.bind(actions.repair_machine.bind(s, m)), &"PrimaryButton"))
	row.add_child(UiKit.spacer())
	row.add_child(UiKit.button("Sell %s" % GameMath.money(actions.sell_value(m)), func() -> void:
		ui.modal.confirm("Sell %s?" % def.display_name, "You'll get %s back." % GameMath.money(actions.sell_value(m)), "Sell", func() -> void:
			actions.sell_machine(Game.state, m)
			ui.close_sheet()
			EventBus.state_changed.emit(), true), &"DangerButton"))
	add_child(row)


func _pricing(m: MachineInstance) -> void:
	var def := m.def
	add_child(UiKit.section("PRICE PER PLAY"))
	var price := m.price_per_play if m.price_per_play != 0.0 else def.default_price
	var ratio := price / def.default_price if def.default_price > 0.0 else 1.0
	var demand := Economy.price_demand_mul(ratio)
	var revenue := GameMath.js_round((ratio * demand - 1.0) * 100.0)
	var price_label := UiKit.label("$%.2f per play" % price)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(UiKit.hbox([
		UiKit.button("−", _set_price.bind(m, -0.25)), price_label, UiKit.button("+", _set_price.bind(m, 0.25))]))
	add_child(UiKit.stat_row("Plays / Revenue", "%d%% / %s%d%%" % [GameMath.js_round(demand * 100.0), "+" if revenue >= 0 else "", revenue]))
	var hint := "👍 Sweet spot — great pricing!" if revenue >= 25 else "⚠ Overpriced — players walk away" if ratio > 2.31 else "↑ Raise price toward the sweet spot"
	add_child(UiKit.label(hint, &"DimLabel", true))
	if m.dips.get(&"freePlay", 0) == 1 and def.dip_switches.any(func(d: DipSwitchDef) -> bool: return d.id == &"freePlay"):
		add_child(UiKit.label("🆓 FREE PLAY ON — machine earns no revenue", &"", true))


func _upgrades(m: MachineInstance) -> void:
	var actions := Game.actions
	var b := Data.db.balance
	add_child(UiKit.section("MACHINE UPGRADES"))
	var tune_max := m.tune_up_level >= b.tune_up_max
	add_child(UiKit.card("⚡", "Tune-Up  %s" % _dots(m.tune_up_level, b.tune_up_max), "+15% earnings per level",
		UiKit.button("MAXED" if tune_max else GameMath.money(actions.tune_up_cost(m)), _do.bind(actions.tune_up_machine.bind(Game.state, m)), &"", not tune_max)))
	var dura_max := m.reinforce_level >= b.reinforce_max
	add_child(UiKit.card("🛡️", "Reinforce  %s" % _dots(m.reinforce_level, b.reinforce_max), "−25% wear per level",
		UiKit.button("MAXED" if dura_max else GameMath.money(actions.reinforce_cost(m)), _do.bind(actions.reinforce_machine.bind(Game.state, m)), &"", not dura_max)))


func _stock(m: MachineInstance) -> void:
	var s := Game.state
	var actions := Game.actions
	var cap := Data.db.balance.stock_cap
	var prizes := m.def.type == MachineDef.Type.PRIZES
	var restock := actions.restock_cost(m)
	add_child(UiKit.hbox([UiKit.section("PRIZE STOCK" if prizes else "STOCK"), UiKit.spacer(),
		UiKit.button("📦 Restock %s" % GameMath.money(restock) if restock > 0 else "📦 Full", _do.bind(actions.restock_machine.bind(s, m)), &"PrimaryButton" if restock > 0 else &"", restock > 0)]))
	if prizes:
		add_child(UiKit.label("🎟️ %d tickets yesterday · %d prizes claimed · %d all-time." % [s.last_day_tickets, s.last_day_redeemed, s.total_tickets], &"DimLabel", true))
	elif m.def.type == MachineDef.Type.FOOD:
		add_child(UiKit.label("Fresh food spoils daily — stock to demand.", &"DimLabel", true))
	for slot in m.stock:
		var qty := slot.qty if slot.is_limited() else float(cap)
		var toggle := UiKit.button("IN" if slot.active else "OUT", func() -> void:
			actions.toggle_stock_item(slot)
			refresh())
		toggle.custom_minimum_size.x = 40
		var row := UiKit.hbox([UiKit.label(slot.item.emoji), UiKit.label(slot.item.display_name), UiKit.spacer()])
		if prizes:
			row.add_child(UiKit.label("🎟️ %d" % slot.item.ticket_cost, &"DimLabel"))
		else:
			row.add_child(UiKit.button("−", _set_stock_price.bind(slot, -0.25)))
			row.add_child(UiKit.label("$%.2f" % slot.price))
			row.add_child(UiKit.button("+", _set_stock_price.bind(slot, 0.25)))
		var level := UiKit.bar(qty, cap, Color("ff4f7b") if qty <= 0.0 else Color("ffb703") if qty < cap * 0.2 else Color("4fd8ff"))
		level.custom_minimum_size.x = 36
		row.add_child(level)
		row.add_child(toggle)
		add_child(row)


func _dips(m: MachineInstance) -> void:
	add_child(UiKit.section("DIP SWITCHES"))
	add_child(UiKit.label("Operator settings. Affect daily earnings and rep gain.", &"DimLabel", true))
	for switch in m.def.dip_switches:
		var current: int = m.dips.get(switch.id, switch.default_index())
		var row := UiKit.hbox([UiKit.label(switch.label, &"DimLabel"), UiKit.spacer()], 3)
		var group := ButtonGroup.new()
		for i in switch.options.size():
			var b := UiKit.button(switch.options[i].label, func() -> void:
				Game.actions.set_machine_dip(m, switch.id, i)
				refresh(), &"TabButton")
			b.toggle_mode = true
			b.button_group = group
			b.button_pressed = i == current
			b.add_theme_font_size_override(&"font_size", 13)
			b.custom_minimum_size.x = 0
			row.add_child(b)
		add_child(row)
	var mul := m.dip_multipliers()
	var pct := func(x: float) -> String:
		var n := GameMath.js_round((x - 1.0) * 100.0)
		return ("+" if n > 0 else "") + str(n) + "%"
	add_child(UiKit.stat_row("Net effect", "Earn %s · Rep %s" % [pct.call(mul.earn_mul), pct.call(mul.rep_mul)]))


func _set_price(m: MachineInstance, delta: float) -> void:
	Game.actions.set_machine_price(m, delta)
	refresh()


func _set_stock_price(slot: StockSlot, delta: float) -> void:
	Game.actions.adjust_stock_price(slot, delta)
	refresh()


## Runs an action and redraws everything if it went through.
func _do(action: Callable) -> void:
	if action.call():
		EventBus.state_changed.emit()


static func _dots(level: int, max_level: int) -> String:
	return "●".repeat(level) + "○".repeat(max_level - level)

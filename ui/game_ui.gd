class_name GameUI
extends CanvasLayer
## The in-game interface: top bar of stats, the action bar (floor, shop, staff,
## books, next day), the bottom sheet that hosts those panels, toasts, the event
## log, the repairs button and modal dialogs (decisions, confirmations, wins).

const PANEL_SCRIPTS := {
	&"floor": preload("res://ui/panels/floor_panel.gd"),
	&"shop": preload("res://ui/panels/shop_panel.gd"),
	&"staff": preload("res://ui/panels/staff_panel.gd"),
	&"books": preload("res://ui/panels/books_panel.gd"),
	&"machine": preload("res://ui/panels/machine_panel.gd"),
}

@export var arcade_floor: ArcadeFloor

var panels: Dictionary[StringName, Control] = {}

@onready var sheet: BottomSheet = %Sheet
@onready var modal: Modal = %Modal
@onready var _action_bar: Control = %ActionBar
@onready var _next_day: Button = %NextDay
@onready var _repairs: Button = %Repairs


func _ready() -> void:
	# The pixel font only has basic ASCII; anything else (emoji, £, ...) falls
	# back to the default font.
	var pixel_font: FontFile = load("res://assets/fonts/arcade_empire_pixel.ttf")
	if not pixel_font.fallbacks.has(ThemeDB.fallback_font):
		pixel_font.fallbacks = [ThemeDB.fallback_font]
	for id: StringName in PANEL_SCRIPTS:
		var panel := VBoxContainer.new()
		panel.set_script(PANEL_SCRIPTS[id])
		panel.name = String(id).capitalize() + "Panel"
		panel.set(&"ui", self)
		panel.add_theme_constant_override(&"separation", 5)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sheet.add_panel(panel)
		panels[id] = panel
	for id: StringName in [&"floor", &"shop", &"staff", &"books"]:
		var b: Button = get_node("%" + String(id).capitalize() + "Button")
		b.pressed.connect(toggle_panel.bind(id))
	_next_day.pressed.connect(_on_next_day)
	_repairs.pressed.connect(_show_repairs)
	%MenuButton.pressed.connect(_show_menu)
	sheet.closed.connect(_on_sheet_closed)
	arcade_floor.placing_changed.connect(_on_placing_changed)
	EventBus.state_changed.connect(_refresh)
	EventBus.machine_selected.connect(_on_machine_selected)
	EventBus.decision_offered.connect(_show_decision)
	EventBus.empire_completed.connect(_show_victory)
	EventBus.scenario_won.connect(_show_scenario_win)
	EventBus.daily_finished.connect(_show_daily_finished)
	_refresh()


func toggle_panel(id: StringName) -> void:
	if sheet.is_showing(panels[id]):
		sheet.close()
	else:
		open_panel(id)


func open_panel(id: StringName) -> void:
	sheet.open(panels[id])
	_sync_tabs(id)


func close_sheet() -> void:
	sheet.close()


func _refresh() -> void:
	var s := Game.state
	if s == null:
		return
	%Cash.text = GameMath.money(s.cash)
	%Cash.add_theme_color_override(&"font_color", Color("ff4f7b") if s.cash < 0.0 else Color("ffd866"))
	%Rep.text = str(GameMath.js_round(s.rep))
	%Visitors.text = str(s.last_day_customers)
	%Mood.text = UiKit.mood_face(s.satisfaction)
	%Day.text = "%d %s" % [s.day, Data.db.weekday_name(maxi(1, s.day)).to_upper()]
	_next_day.text = "OPEN ARCADE" if s.day == 0 else "NEXT DAY"
	_next_day.disabled = Game.pending_decision != null
	var broken := s.machines.filter(func(m: MachineInstance) -> bool: return m.is_broken()).size()
	_repairs.visible = broken > 0
	_repairs.text = "🔧 %d REPAIR%s NEEDED" % [broken, "S" if broken > 1 else ""]


func _on_next_day() -> void:
	sheet.close()
	Game.next_day()


func _on_machine_selected(machine_id: int) -> void:
	if arcade_floor.is_placing():
		return
	var m := Game.state.machine_by_id(machine_id) if Game.state else null
	if m:
		panels[&"machine"].call(&"show_machine", m)
		open_panel(&"machine")
	elif sheet.visible:
		sheet.close()


func _on_sheet_closed() -> void:
	_sync_tabs(&"")
	if arcade_floor.selected_id != -1:
		arcade_floor.select(-1)


func _on_placing_changed(active: bool) -> void:
	_action_bar.visible = not active
	if active:
		sheet.close()


func _sync_tabs(id: StringName) -> void:
	for tab: StringName in [&"floor", &"shop", &"staff", &"books"]:
		(get_node("%" + String(tab).capitalize() + "Button") as Button).set_pressed_no_signal(tab == id)


func _show_repairs() -> void:
	var s := Game.state
	var rows := []
	for m in s.machines:
		if m.is_broken():
			rows.append(UiKit.card(m.def.emoji, m.def.display_name, "Repair cost: %s" % GameMath.money(Game.actions.repair_cost(s)),
				UiKit.button("🔧 FIX", func() -> void:
					if Game.actions.repair_machine(Game.state, m):
						EventBus.state_changed.emit()
						_show_repairs(), &"PrimaryButton")))
	if rows.is_empty():
		modal.close()
		return
	modal.present("BROKEN MACHINES", rows)


func _show_decision(event: DecisionEventDef) -> void:
	_refresh()
	var body := [UiKit.label(event.description, &"", true)]
	for i in event.options.size():
		var o := event.options[i]
		var extra := " — %s" % GameMath.money(o.cost) if o.cost else " — +%s" % GameMath.money(o.gain_cash) if o.gain_cash else ""
		var b := UiKit.button(o.label + extra, func() -> void:
			if Game.choose_decision(i):
				modal.close(), &"PrimaryButton" if i == 0 else &"", o.cost == 0 or Game.state.cash >= o.cost)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.append(b)
	modal.present("%s %s" % [event.emoji, event.title], body, false)


func _show_victory() -> void:
	modal.present("🏆 ARCADE EMPIRE!", [
		UiKit.label("Every milestone goal cleared in %d days. Prestige to start fresh with a perk point to spend — or keep building this one." % Game.state.day, &"", true),
		UiKit.button("⭐ PRESTIGE", func() -> void:
			modal.close()
			Game.prestige(), &"PrimaryButton"),
		UiKit.button("▶ KEEP PLAYING", modal.close)])


func _show_scenario_win(scenario: ScenarioDef, stars: int) -> void:
	modal.present("%s SCENARIO COMPLETE" % scenario.emoji, [
		UiKit.label("%s — %s%s in %d days." % [scenario.display_name, "★".repeat(stars), "☆".repeat(3 - stars), Game.state.day], &"", true),
		UiKit.button("▶ KEEP PLAYING", modal.close, &"PrimaryButton")])


func _show_daily_finished(score: int, best: int, new_best: bool) -> void:
	modal.present("📅 DAILY COMPLETE", [
		UiKit.label("%s takings. %s" % [GameMath.money(score), "New personal best for today!" if new_best else "Today's best: %s" % GameMath.money(best)], &"", true),
		UiKit.button("🔁 RETRY TODAY", func() -> void:
			modal.close()
			Game.start_daily(), &"PrimaryButton"),
		UiKit.button("▶ FREE PLAY", modal.close)])


## The game menu. More screens (marketing, research, ...) join in the next pass.
func _show_menu() -> void:
	modal.present("ARCADE EMPIRE", [
		UiKit.button("🔄 RESTART GAME", func() -> void:
			modal.confirm("🔄 RESTART?", "All progress in this arcade will be lost.", "Restart", Game.restart, true), &"DangerButton")])

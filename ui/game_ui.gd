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
	&"menu": preload("res://ui/panels/menu_panel.gd"),
	&"scenarios": preload("res://ui/panels/scenarios_panel.gd"),
	&"daily": preload("res://ui/panels/daily_panel.gd"),
	&"progress": preload("res://ui/panels/progress_panel.gd"),
	&"leaderboard": preload("res://ui/panels/leaderboard_panel.gd"),
	&"achievements": preload("res://ui/panels/achievements_panel.gd"),
	&"marketing": preload("res://ui/panels/marketing_panel.gd"),
	&"contracts": preload("res://ui/panels/contracts_panel.gd"),
	&"research": preload("res://ui/panels/research_panel.gd"),
	&"franchises": preload("res://ui/panels/franchises_panel.gd"),
	&"decor": preload("res://ui/panels/decor_panel.gd"),
}

const TUTORIAL := [
	["🎮", "Welcome, Tycoon!", "Build the ultimate arcade: buy machines, price them well, keep all ages happy, and expand your room to grow. Tap OPEN ARCADE to run each day."],
	["🛒", "Buy & Place", "Open SHOP to buy cabinets — each has a cost, an audience and popularity. Tap any machine on the floor to manage it. More machines earn more (but raise the rent!)."],
	["💰", "Price = Profit", "In a machine's panel, raise its PRICE PER PLAY. Charge more and fewer people play — there's a sweet spot near ~1.9× the default. Watch the Plays / Revenue readout."],
	["🎯", "Mix Your Audience", "Machines target Kids, Teens or Adults. Cover all three for a footfall bonus — a one-note arcade draws a smaller crowd."],
	["⚙️", "Events & Upgrades", "Some days a CHOICE pops up — host a tournament, dodge a storm. Each machine can buy Tune-Up (+earn) and Reinforce (−wear). Hit GOALS (in BOOKS) for cash & rep!"],
	["🏗️", "Grow Your Room", "Fill the floor, then expand the room (FLOOR panel) — go WIDER or DEEPER to fit more cabinets. Cost rises with each expansion. You've got this — open those doors!"],
]

const CREDITS := [
	["PRODUCER", "Graham Harbour"],
	["DEVELOPMENT", "Graham Harbour · Tom Evans"],
	["ART", "Graham Harbour"],
	["TECHNICAL ASSISTANCE & PUBLISHING", "Alex Rogers"],
	["SPECIAL THANKS", "Hadeed Khalid · Maiju Peltola"],
]

## Action-bar tabs: panel id (also its icon), label.
const TABS := [[&"floor", "FLOOR"], [&"shop", "SHOP"], [&"staff", "STAFF"], [&"books", "BOOKS"]]
## Action-bar button heights: icon beside the label, or stacked above it.
const BAR_ROW := 34.0
const BAR_STACKED := 44.0
## Below this logical width the action bar switches to its compact layout.
const COMPACT_WIDTH := 480.0

## Seconds between visitor popup text refreshes.
const VISITOR_REFRESH := 0.1

@export var arcade_floor: ArcadeFloor

var panels: Dictionary[StringName, Control] = {}
var _visitor: Customer
var _visitor_timer := 0.0
var _next_day_label := ""

@onready var sheet: BottomSheet = %Sheet
@onready var modal: Modal = %Modal
@onready var _action_bar: Control = %ActionBar
@onready var _next_day: Button = %NextDay
@onready var _repairs: Button = %Repairs
@onready var _visitor_popup: PanelContainer = %VisitorPopup
@onready var _visitor_text: Label = %VisitorText


func _ready() -> void:
	# The pixel fonts only have basic ASCII; anything else falls back to the
	# default font, and emoji to a bundled emoji font (browsers give Godot no
	# system fallback, so without it emoji would show as boxes on the web).
	var emoji_font: FontFile = load("res://assets/fonts/noto_color_emoji_subset.ttf")
	var default_font := ThemeDB.fallback_font
	if not default_font.fallbacks.has(emoji_font):
		default_font.fallbacks = default_font.fallbacks + [emoji_font]
	for path: String in ["res://assets/fonts/arcade_empire_pixel.ttf", "res://assets/fonts/jersey10.ttf"]:
		var pixel_font: FontFile = load(path)
		if not pixel_font.fallbacks.has(default_font):
			pixel_font.fallbacks = [default_font, emoji_font]
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
	get_viewport().size_changed.connect(_fit_action_bar)
	_action_bar.resized.connect(_on_action_bar_resized)
	_fit_action_bar()
	_next_day.pressed.connect(_on_next_day)
	_repairs.pressed.connect(_show_repairs)
	_repairs.icon = Icons.named(&"repairs")
	%LogToggle.icon = Icons.named(&"event_log")
	%MenuButton.pressed.connect(toggle_panel.bind(&"menu"))
	_add_sound_button()
	# Confetti over the floor, behind every panel.
	var confetti := Confetti.new()
	$Root.add_child(confetti)
	$Root.move_child(confetti, 0)
	_visitor_popup.hide()
	EventBus.visitor_selected.connect(_on_visitor_selected)
	EventBus.customers_reset.connect(_on_visitor_selected.bind(null))
	sheet.closed.connect(_on_sheet_closed)
	sheet.touch_scroll.blocker = modal
	arcade_floor.placing_changed.connect(_on_placing_changed)
	EventBus.state_changed.connect(_refresh)
	EventBus.machine_selected.connect(_on_machine_selected)
	EventBus.decision_offered.connect(_show_decision)
	EventBus.empire_completed.connect(_show_victory)
	EventBus.scenario_won.connect(_show_scenario_win)
	EventBus.daily_finished.connect(_show_daily_finished)
	_refresh()


## The sound on / off toggle at the right of the top bar.
func _add_sound_button() -> void:
	var menu: Button = %MenuButton
	var sound := Button.new()
	sound.name = "SoundButton"
	sound.custom_minimum_size = menu.custom_minimum_size
	sound.tooltip_text = "Toggle sound"
	sound.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sound.icon = Icons.named(&"sound_off" if Sfx.muted else &"sound_on")
	sound.pressed.connect(func() -> void: sound.icon = Icons.named(&"sound_off" if Sfx.toggle_mute() else &"sound_on"))
	menu.get_parent().add_child(sound)


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


## Opens a machine's minigame over everything; playing pays a small bonus.
func play_minigame(m: MachineInstance) -> void:
	if m.def.minigame == null or get_node_or_null(^"Root/MiniGame"):
		return
	sheet.close()
	var game := m.def.minigame.instantiate() as MiniGame
	game.name = "MiniGame"
	var key := StringName(m.def.minigame.resource_path.get_file().get_basename())
	game.best = Game.meta.minigame_bests.get(key, 0)
	game.best_stars = Game.meta.minigame_stars.get(key, 0)
	game.plays_left = Game.actions.minigame_plays_left(Game.state, m)
	var paid := [false]
	game.round_started.connect(func() -> void:
		paid[0] = Game.actions.start_minigame_play(Game.state, m)
		game.practice = not paid[0])
	game.finished.connect(func(score: int) -> void:
		var result := Game.actions.finish_minigame(Game.state, m, key, game.game_name, score, game.stars_earned, paid[0])
		game.bonus = result.bonus
		game.star_bonus = result.star_bonus
		Game.save_game()
		EventBus.machines_changed.emit()
		EventBus.state_changed.emit())
	# The arcade holds still while you play: the crowd and floor animations pause.
	arcade_floor.process_mode = Node.PROCESS_MODE_DISABLED
	Sfx.set_crowd(0)
	game.tree_exited.connect(func() -> void: arcade_floor.process_mode = Node.PROCESS_MODE_INHERIT)
	$Root.add_child(game)


## Opens a menu screen: a sheet panel, or the how-to-play / credits dialogs.
func open_screen(id: StringName) -> void:
	match id:
		&"tutorial":
			show_tutorial()
		&"credits":
			_show_credits()
		_:
			open_panel(id)


func show_tutorial(page := 0) -> void:
	var entry: Array = TUTORIAL[page]
	var last := page == TUTORIAL.size() - 1
	var finish := func() -> void:
		Sfx.click()
		modal.close()
		Game.meta.tutorial_done = true
		Game.save_meta()
	var next := UiKit.button("LET'S GO!" if last else "NEXT", finish if last else func() -> void:
		Sfx.click()
		show_tutorial(page + 1), &"PrimaryButton")
	var skip := UiKit.button("SKIP", finish)
	var icon := UiKit.label(entry[0])
	icon.add_theme_font_size_override(&"font_size", 28)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal.present("%s  (%d/%d)" % [entry[1], page + 1, TUTORIAL.size()], [
		icon, UiKit.label(entry[2], &"", true), UiKit.hbox([skip, UiKit.spacer(), next])], false)


func _show_credits() -> void:
	var body := []
	for row: Array in CREDITS:
		body.append(UiKit.section(row[0]))
		body.append(UiKit.label(row[1]))
	body.append(UiKit.label("This game has been developed using AI.", &"DimLabel", true))
	modal.present("🎬 CREDITS", body)


func _on_visitor_selected(visitor: Node2D) -> void:
	_visitor = visitor as Customer
	_visitor_popup.visible = _visitor != null
	_visitor_timer = 0.0
	if _visitor:
		Sfx.click()
		_update_visitor_popup()


func _process(delta: float) -> void:
	if _visitor == null:
		return
	if not is_instance_valid(_visitor) or _visitor.is_queued_for_deletion():
		_on_visitor_selected(null)
		return
	_visitor_timer -= delta
	if _visitor_timer <= 0.0:
		_visitor_timer = VISITOR_REFRESH
		_update_visitor_popup()
	# Follow the visitor: above their head, kept on screen.
	var head := arcade_floor.get_canvas_transform() * (_visitor.position - Vector2(0, 34) * _visitor.scale.y)
	var view := get_viewport().get_visible_rect().size
	var size := _visitor_popup.size
	_visitor_popup.position = Vector2(clampf(head.x - size.x / 2.0, 4.0, view.x - size.x - 4.0), clampf(head.y - size.y - 4.0, 38.0, view.y - size.y - 46.0))


func _update_visitor_popup() -> void:
	var c := _visitor
	var s := Game.state
	var mood: Dictionary = c.mood(s)
	var persona := ""
	match c.persona:
		Customer.Persona.VIP:
			persona = " · 🎩 VIP"
		Customer.Persona.STAR:
			persona = " · ⭐ STAR"
		Customer.Persona.FAMILY:
			persona = " · 👪"
	var genre := Data.db.genre(c.favourite_genre)
	_visitor_text.text = "%s%s%s
%s %s
%s
Loves %s · %s" % [c.display_name(), " (KID)" if c.kid else "", persona, mood.emoji, mood.label,
		c.activity(s), "%s %s" % [genre.emoji, genre.label] if genre else "🎲 Anything", c.audience]
	if c.is_emoting():
		_visitor_text.text += "\n💭 Thinking: %s" % c.emote


func _refresh() -> void:
	var s := Game.state
	if s == null:
		return
	%Cash.text = GameMath.money(s.cash)
	%Cash.add_theme_color_override(&"font_color", Color("ff4f7b") if s.cash < 0.0 else Color("ffd866"))
	%Rep.text = str(GameMath.js_round(s.rep))
	%Visitors.text = str(s.last_day_customers)
	%Mood.texture = Icons.mood(s.satisfaction)
	%Day.text = "%d %s" % [s.day, Data.db.weekday_name(maxi(1, s.day)).to_upper()]
	var label := "OPEN ARCADE" if s.day == 0 else "NEXT DAY"
	if label != _next_day_label:
		_next_day_label = label
		UiKit.icon_label(_next_day, Icons.named(&"next_day"), label, _compact())
	_next_day.disabled = Game.pending_decision != null
	var broken := s.machines.filter(func(m: MachineInstance) -> bool: return m.is_broken()).size()
	_repairs.visible = broken > 0
	_repairs.text = "%d REPAIR%s NEEDED" % [broken, "S" if broken > 1 else ""]


## Each tab shows its icon beside its label, centred. On narrow (portrait phone)
## screens the icon sits above a smaller label so all five buttons fit.
func _fit_action_bar() -> void:
	var compact := _compact()
	for tab: Array in TABS:
		var b: Button = get_node("%" + String(tab[0]).capitalize() + "Button")
		b.add_theme_font_size_override(&"font_size", 13 if compact else 16)
		b.custom_minimum_size.y = BAR_STACKED if compact else BAR_ROW
		UiKit.icon_label(b, Icons.named(tab[0]), tab[1], compact)
	_next_day.custom_minimum_size.y = BAR_STACKED if compact else BAR_ROW
	_next_day.add_theme_font_size_override(&"font_size", 12 if compact else 16)
	_next_day_label = ""      # rebuilt at the new size by _refresh
	_refresh()


## Keeps the sheet and the floor's camera clear of the action bar, whose height
## changes with the layout.
func _on_action_bar_resized() -> void:
	var clearance := _action_bar.size.y + 2.0
	sheet.offset_bottom = -clearance
	arcade_floor.camera.hud_bottom = clearance


func _compact() -> bool:
	return get_viewport().get_visible_rect().size.x < COMPACT_WIDTH


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
				# Options that spend, pay out or help the day chime; the rest click.
				if o.cost or o.gain_cash or o.repair_all or o.foot_mul > 1:
					Sfx.buy()
				else:
					Sfx.click()
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
		UiKit.button("📸 SHARE CARD", ShareCard.save.bind(self)),
		UiKit.button("▶ KEEP PLAYING", modal.close)])


func _show_scenario_win(scenario: ScenarioDef, stars: int) -> void:
	modal.present("%s SCENARIO COMPLETE" % scenario.emoji, [
		UiKit.label("%s — %s%s in %d days." % [scenario.display_name, "★".repeat(stars), "☆".repeat(3 - stars), Game.state.day], &"", true),
		UiKit.button("▶ KEEP PLAYING", modal.close, &"PrimaryButton"),
		UiKit.button("📸 SHARE CARD", ShareCard.save.bind(self))])


func _show_daily_finished(score: int, best: int, new_best: bool) -> void:
	modal.present("📅 DAILY COMPLETE", [
		UiKit.label("%s takings. %s" % [GameMath.money(score), "New personal best for today!" if new_best else "Today's best: %s" % GameMath.money(best)], &"", true),
		UiKit.button("🔁 RETRY TODAY", func() -> void:
			modal.close()
			Game.start_daily(), &"PrimaryButton"),
		UiKit.button("▶ FREE PLAY", modal.close)])

class_name ArcadeFloor
extends Node2D
@warning_ignore_start("integer_division")
## The arcade floor: carpet, walls, cabinets and the crowd, plus pan/zoom,
## tapping machines, and placement mode (drag a ghost, rotate, place or cancel).
## Works the same with touch and mouse; nothing relies on hover or right-click.

signal placing_changed(active: bool)

const CABINET_SCENE := preload("res://floor/cabinet.tscn")
const TILE := FloorGeometry.TILE
## Pointer travel (screen px) before a press counts as a drag rather than a tap.
const DRAG_THRESHOLD := 8.0
const VALID_TINT := Color(0.5, 1.0, 0.6, 0.75)
const INVALID_TINT := Color(1.0, 0.4, 0.45, 0.75)

var walk_grid := WalkGrid.new()
var cabinets: Dictionary[int, Cabinet] = {}
var selected_id := -1

## Placement mode: what is being placed and where. `moving` is null for a new purchase.
var placing_def: MachineDef
var moving: MachineInstance
var ghost_tile := Vector2i.ZERO
var ghost_facing := MachineInstance.Facing.S

var _room_shown := Vector2i(-1, -1)
var _prop_key := ""
## Floor tiles taken by standing props, which people walk round.
var _prop_blocked: Array[Vector2i] = []
var _touches: Dictionary[int, Vector2] = {}
var _press_pos := Vector2.ZERO
var _dragged := false

@onready var camera: FloorCamera = $Camera
@onready var carpet: TileMapLayer = $Carpet
@onready var room: Room = $Room
@onready var entities: Node2D = $Entities
@onready var crowd: Crowd = $Crowd
@onready var props: PropLayer = $Props
@onready var ghost: Cabinet = $Ghost
@onready var pops: Node2D = $Pops


func _ready() -> void:
	crowd.walk_grid = walk_grid
	ghost.hide()
	EventBus.game_started.connect(rebuild)
	EventBus.game_loaded.connect(rebuild)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.machines_changed.connect(_sync_machines)
	EventBus.arcade_renamed.connect(_sync_props)
	EventBus.coin_spawned.connect(_on_coin_spawned)
	EventBus.tip_received.connect(func(at: Vector2, amount: int) -> void: pop_text(at, "+$%d" % amount))
	get_viewport().size_changed.connect(_fit_camera)
	if Game.state:
		rebuild()


## Redraws everything for a new or loaded run.
func rebuild() -> void:
	_room_shown = Vector2i(-1, -1)
	_prop_key = ""
	cancel_placing()
	select(-1)
	crowd.clear_customers()
	_on_state_changed()
	_sync_machines()
	crowd.sync_staff()


func is_placing() -> bool:
	return placing_def != null


# ── Placement mode ──

## Starts placing a new machine (bought when placed).
func start_placing(def: MachineDef) -> void:
	if not Game.actions.can_buy_machine(Game.state, def):
		return
	moving = null
	_begin_placing(def, MachineInstance.Facing.S, FloorGrid.first_free_tile(Game.state, def.footprint, MachineInstance.Facing.S))


func start_moving(m: MachineInstance) -> void:
	moving = m
	_begin_placing(m.def, m.facing, m.tile)


## Turns the ghost a quarter: +1 clockwise, -1 anticlockwise.
func rotate_ghost(direction := 1) -> void:
	if not is_placing():
		return
	ghost_facing = posmod(ghost_facing + direction, 4) as MachineInstance.Facing
	_set_ghost_tile(ghost_tile)
	Sfx.click()


func ghost_valid() -> bool:
	return FloorGrid.can_place(ghost_tile, placing_def.footprint, ghost_facing, Game.state.room, Game.state.machines, moving)


func commit_placing() -> bool:
	if not is_placing():
		return false
	if not ghost_valid():
		Sfx.error()
		EventBus.toast_requested.emit("Can't place there — blocked or out of bounds.", Sim.LogKind.BAD)
		return false
	var placed_id: int
	if moving:
		Game.actions.move_machine(Game.state, moving, ghost_tile, ghost_facing)
		placed_id = moving.id
	else:
		var bought := Game.actions.buy_machine(Game.state, placing_def, ghost_tile, ghost_facing)
		if bought == null:
			cancel_placing()
			return false
		placed_id = bought.id
		var neighbours := FloorGrid.same_genre_nearby(Game.state.machines, bought, Data.db.balance.zone_radius)
		if neighbours > 0 and bought.def.genre:
			EventBus.toast_requested.emit("%s %s +%d%% zone bonus!" % [bought.def.genre.emoji, bought.def.genre.label, FloorGrid.zone_pct(neighbours, Data.db.balance)], Sim.LogKind.MONEY)
	_end_placing()
	select(placed_id)
	EventBus.state_changed.emit()
	return true


func cancel_placing() -> void:
	if is_placing():
		_end_placing()
		Sfx.click()


func _begin_placing(def: MachineDef, facing: MachineInstance.Facing, tile: Vector2i) -> void:
	placing_def = def
	ghost_facing = facing
	if tile == FloorGrid.NO_TILE:
		tile = Game.state.room / 2
	ghost.show_as(def, facing)
	ghost.show()
	if moving and cabinets.has(moving.id):
		cabinets[moving.id].hide()
	# Show the whole room so every tile can be reached while dragging.
	_fit_camera()
	_set_ghost_tile(tile)
	placing_changed.emit(true)


func _end_placing() -> void:
	if moving and cabinets.has(moving.id):
		cabinets[moving.id].show()
	placing_def = null
	moving = null
	ghost.hide()
	queue_redraw()
	placing_changed.emit(false)


## Moves the ghost, keeping its base on the floor (the body may overhang the back wall).
func _set_ghost_tile(tile: Vector2i) -> void:
	var size := placing_def.footprint
	var r := Game.state.room
	ghost_tile = Vector2i(clampi(tile.x, 0, r.x - size.x), clampi(tile.y, -(size.y - 1), r.y - size.y))
	ghost.show_as(placing_def, ghost_facing)
	ghost.position = Vector2((ghost_tile.x + size.x / 2.0) * TILE, (ghost_tile.y + size.y) * TILE)
	ghost.modulate = VALID_TINT if ghost_valid() else INVALID_TINT
	queue_redraw()


func _ghost_follow(screen_point: Vector2) -> void:
	var size := placing_def.footprint
	var t := WalkGrid.tile_of(camera.screen_to_floor(screen_point))
	_set_ghost_tile(t - Vector2i(size.x / 2, size.y / 2))


# ── Selection ──

func select(machine_id: int) -> void:
	if cabinets.has(selected_id):
		cabinets[selected_id].selected = false
	selected_id = machine_id
	if cabinets.has(selected_id):
		cabinets[selected_id].selected = true
	EventBus.machine_selected.emit(machine_id)


func machine_at(floor_point: Vector2) -> MachineInstance:
	var t := WalkGrid.tile_of(floor_point)
	for m in Game.state.machines:
		if FloorGrid.footprint_tiles(m.tile, m.def.footprint).has(t):
			return m
	return null


## The customer whose body covers a floor point (nearest wins in a queue).
func customer_at(floor_point: Vector2) -> Customer:
	var best: Customer = null
	var best_distance := INF
	for c in crowd.customers:
		var half_width := 7.0 * c.scale.x
		var height := 30.0 * c.scale.y
		if absf(floor_point.x - c.position.x) > half_width or floor_point.y < c.position.y - height or floor_point.y > c.position.y + 4.0:
			continue
		var d := floor_point.distance_to(c.position - Vector2(0, height / 2.0))
		if d < best_distance:
			best_distance = d
			best = c
	return best


# ── Input: one pointer pans (or drags the ghost), two pinch-zoom, wheel zooms ──

func _unhandled_input(event: InputEvent) -> void:
	if Game.state == null:
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return   # touches are handled directly below
	if event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion:
		if event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_RIGHT):
			_on_drag(event.position, event.relative)
	elif event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_screen_drag(event)


func _on_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				camera.zoom_at(1.1, event.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				camera.zoom_at(1.0 / 1.1, event.position)
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_on_press(event.position)
			else:
				_on_release(event.position)
	get_viewport().set_input_as_handled()


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_on_press(event.position)
		else:
			_dragged = true   # a second finger turns this into a pinch, never a tap
	else:
		_touches.erase(event.index)
		if _touches.is_empty():
			_on_release(event.position)
	get_viewport().set_input_as_handled()


func _on_screen_drag(event: InputEventScreenDrag) -> void:
	if _touches.size() >= 2 and _touches.has(event.index):
		var other := _touches.keys().filter(func(i: int) -> bool: return i != event.index)[0] as int
		var anchor := _touches[other]
		var before := _touches[event.index].distance_to(anchor)
		_touches[event.index] = event.position
		var after := event.position.distance_to(anchor)
		if before > 0.0:
			camera.zoom_at(after / before, (event.position + anchor) / 2.0)
		camera.pan_by(event.relative / 2.0)
	else:
		_touches[event.index] = event.position
		_on_drag(event.position, event.relative)
	get_viewport().set_input_as_handled()


func _on_press(screen_point: Vector2) -> void:
	_press_pos = screen_point
	_dragged = false
	if is_placing():
		_ghost_follow(screen_point)


func _on_drag(screen_point: Vector2, relative: Vector2) -> void:
	if not _dragged and screen_point.distance_to(_press_pos) > DRAG_THRESHOLD:
		_dragged = true
	if is_placing():
		_ghost_follow(screen_point)
	elif _dragged:
		camera.pan_by(relative)


func _on_release(screen_point: Vector2) -> void:
	if _dragged or is_placing():
		return
	var at := camera.screen_to_floor(screen_point)
	# People standing in front of a cabinet win the tap.
	var visitor := customer_at(at)
	if visitor:
		EventBus.visitor_selected.emit(visitor)
		return
	EventBus.visitor_selected.emit(null)
	var m := machine_at(at)
	select(m.id if m else -1)


# ── Keeping the view in step with the state ──

func _on_state_changed() -> void:
	var state := Game.state
	if state == null:
		return
	var props_moved := _sync_props()
	if state.room != _room_shown:
		_room_shown = state.room
		_build_carpet(state.room)
		walk_grid.rebuild(state.room, state.machines, _prop_blocked)
		_fit_camera()
	elif props_moved:
		walk_grid.rebuild(state.room, state.machines, _prop_blocked)
		crowd.reroute()
	room.show_room(state.room, Data.db.theme(state.theme))
	for c: Cabinet in cabinets.values():
		c.refresh()


func _sync_machines() -> void:
	var state := Game.state
	var live := {}
	for m in state.machines:
		live[m.id] = true
		if not cabinets.has(m.id):
			var c: Cabinet = CABINET_SCENE.instantiate()
			entities.add_child(c)
			cabinets[m.id] = c
			c.show_machine(m)
		else:
			cabinets[m.id].show_machine(m)
	for id: int in cabinets.keys():
		if not live.has(id):
			cabinets[id].queue_free()
			cabinets.erase(id)
	if not live.has(selected_id):
		select(-1)
	_sync_props()
	walk_grid.rebuild(state.room, state.machines, _prop_blocked)
	crowd.reroute()


## Lays out decor and facilities again; true when anything moved.
func _sync_props() -> bool:
	var spots := PropLayout.layout(Game.state)
	var theme := Data.db.theme(Game.state.theme)
	var key := "%s|%s|%s|%s" % [Game.state.room, Game.state.arcade_name, theme.id, PropLayer.key_of(spots)]
	if key == _prop_key:
		return false
	_prop_key = key
	_prop_blocked = PropLayout.blocked_tiles(spots)
	props.show_spots(spots, Game.state.arcade_name, theme.sign_color)
	return true


func _build_carpet(size: Vector2i) -> void:
	carpet.clear()
	for y in size.y:
		for x in size.x:
			var cell := FloorGeometry.carpet_cell(Vector2i(x, y))
			carpet.set_cell(Vector2i(x, y), cell.x, Vector2i(cell.y, 0))


func _fit_camera() -> void:
	if Game.state:
		# Include the walls, plus room below the door for people walking in.
		var r := FloorGeometry.room_rect(Game.state.room).grow_individual(TILE, FloorGeometry.WALL_H, TILE, TILE)
		camera.fit(r)


func _on_coin_spawned(machine_id: int, value: int) -> void:
	if cabinets.has(machine_id) and value > 0:
		pop_text(cabinets[machine_id].position + Vector2(0, -TILE * 1.6), "+$%d" % value)


## A floating "+$n" that drifts up and fades.
func pop_text(at: Vector2, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 10)
	label.add_theme_color_override(&"font_color", Color("ffd866"))
	label.add_theme_color_override(&"font_outline_color", Color("0f1321"))
	label.add_theme_constant_override(&"outline_size", 3)
	label.position = at - Vector2(12, 8)
	pops.add_child(label)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 18.0, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tween.chain().tween_callback(label.queue_free)


func _draw() -> void:
	if not is_placing():
		return
	# Footprint outline and the stand tile, green when placeable.
	var tint := VALID_TINT if ghost_valid() else INVALID_TINT
	var size := placing_def.footprint
	for t in FloorGrid.base_tiles(ghost_tile, size, ghost_facing):
		draw_rect(FloorGeometry.tile_rect(t), Color(tint, 0.35))
	var foot := FloorGeometry.tile_rect(ghost_tile, size)
	draw_rect(foot, Color(tint, 0.9), false, 1.0)
	var stand := FloorGeometry.tile_rect(FloorGrid.stand_tile(ghost_tile, size, ghost_facing))
	draw_rect(stand.grow(-6.0), Color(tint, 0.55))

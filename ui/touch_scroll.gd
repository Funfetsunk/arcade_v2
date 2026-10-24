class_name TouchScroll
extends Node
## Drag-to-scroll for its parent ScrollContainer, wherever the drag starts.
## Godot only drag-scrolls when the drag reaches the ScrollContainer itself, and
## the cards and buttons filling a panel stop it first, so on a phone most drags
## did nothing. This watches drags over the container before the GUI sees them:
## once a finger (or mouse) moves past THRESHOLD it scrolls, cancels the press it
## started on, and flings on release. A tap is still a tap.

const THRESHOLD := 8.0
## How quickly a fling slows down (per second), and the speed it stops at.
const FRICTION := 5.0
const MIN_FLING := 20.0

## While this control is showing (e.g. a modal over the panel), drags are left alone.
var blocker: Control

var _scroll: ScrollContainer
var _start := Vector2.INF
var _start_scroll := 0.0
var _dragging := false
var _cancelling := false
var _velocity := 0.0
var _fling := 0.0
var _last_y := 0.0
var _last_time := 0


func _ready() -> void:
	_scroll = get_parent() as ScrollContainer
	# The built-in touch drag would scroll as well; this replaces it.
	_scroll.scroll_deadzone = 100000


func _input(event: InputEvent) -> void:
	if _cancelling or not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	if not _scroll.is_visible_in_tree() or (blocker and blocker.visible):
		_start = Vector2.INF
		return
	var at: Vector2 = event.position
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _scroll.get_global_rect().has_point(at):
				_start = at
				_start_scroll = _scroll.scroll_vertical
				_dragging = false
				_fling = 0.0
				_velocity = 0.0
				_track(at.y)
		elif _start != Vector2.INF:
			if _dragging:
				get_viewport().set_input_as_handled()
				if absf(_velocity) > MIN_FLING:
					_fling = _velocity
			_start = Vector2.INF
			_dragging = false
	elif event is InputEventMouseMotion and _start != Vector2.INF:
		if not _dragging and absf(at.y - _start.y) > THRESHOLD:
			_dragging = true
			_cancel_press()
		if _dragging:
			_scroll.scroll_vertical = int(_start_scroll + _start.y - at.y)
			_track(at.y)
			get_viewport().set_input_as_handled()


## Remembers the finger's speed for the fling, smoothed over recent moves.
func _track(y: float) -> void:
	var now := Time.get_ticks_msec()
	var dt := (now - _last_time) / 1000.0
	if dt > 0.0 and dt < 0.1:
		_velocity = lerpf(_velocity, (_last_y - y) / dt, 0.5)
	_last_y = y
	_last_time = now


## Lets go of the button (or card) the drag started on, off to one side, so it
## doesn't fire or stay held down when the finger lifts.
func _cancel_press() -> void:
	const AWAY := Vector2(-10000, -10000)
	# Move off the button first: it fires on release if it still thinks the
	# pointer is over it.
	var away := InputEventMouseMotion.new()
	away.position = AWAY
	away.global_position = AWAY
	away.button_mask = MOUSE_BUTTON_MASK_LEFT
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = AWAY
	release.global_position = AWAY
	_cancelling = true
	get_viewport().push_input(away, true)
	get_viewport().push_input(release, true)
	_cancelling = false


func _process(delta: float) -> void:
	if _fling == 0.0:
		return
	if _start != Vector2.INF or not _scroll.is_visible_in_tree():
		_fling = 0.0
		return
	var before := _scroll.scroll_vertical
	_scroll.scroll_vertical = int(before + _fling * delta)
	_fling *= exp(-FRICTION * delta)
	# Stop at the ends, or once it has slowed right down.
	if absf(_fling) < MIN_FLING or _scroll.scroll_vertical == before:
		_fling = 0.0

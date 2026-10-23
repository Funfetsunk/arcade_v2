class_name MiniGame
extends Control
## Base for the playable cabinets. A game draws on a fixed 360×460 board (scaled
## to fit the screen) and runs its logic in `_tick()` 60 times a second, matching
## the original's per-frame timings. Pointer input arrives in board coordinates;
## touch and mouse are the same. Emits `finished(score)` once when a round ends.

signal finished(score: int)
signal closed

const BOARD := Vector2(360, 460)
const BG := Color("0a0a16")
const GOLD := Color("ffb703")
const CREAM := Color("f2e4c4")
const DIM := Color("9a8a6a")
const PIXEL_FONT: Font = preload("res://assets/fonts/arcade_empire_pixel.ttf")

## Shown above the board.
@export var game_name := "Minigame"
@export var title_icon := "🎮"
@export_multiline var hint := ""

var score := 0
var over := false
## Bonus cash the round earned, shown on the results screen.
var bonus := 0

var _result_label := ""
var _result_good := true
var _awarded := false
var _pops: Array[Dictionary] = []

@onready var board: Control = %Board
@onready var _title: Label = %Title
@onready var _hud: Label = %Hud
@onready var _hint: Label = %Hint
@onready var _quit: Button = %Quit


func _ready() -> void:
	_title.text = "%s %s" % [title_icon, game_name.to_upper()]
	_hint.text = hint
	_quit.pressed.connect(close)
	board.draw.connect(_on_board_draw)
	board.gui_input.connect(_on_board_input)
	board.resized.connect(_fit_board)
	%BoardFrame.resized.connect(_fit_board)
	_setup()
	_update_hud()


## Called once before the first tick.
func _setup() -> void:
	pass


## One frame of game logic (60 per second).
func _tick() -> void:
	pass


## Draw the board, in board coordinates.
func _draw_board() -> void:
	pass


func _hud_text() -> String:
	return "SCORE %d" % score


func _pointer_pressed(_at: Vector2) -> void:
	pass


func _pointer_moved(_at: Vector2) -> void:
	pass


func _key(_event: InputEventKey) -> void:
	pass


## Ends the round with a headline for the results screen.
func end_round(label: String, good := true) -> void:
	if over:
		return
	over = true
	_result_label = label
	_result_good = good
	if not _awarded:
		_awarded = true
		finished.emit(score)
	_quit.text = "✓ DONE"
	board.queue_redraw()


func close() -> void:
	closed.emit()
	queue_free()


func _physics_process(_delta: float) -> void:
	if over:
		return
	_tick()
	_update_hud()
	board.queue_redraw()


func _update_hud() -> void:
	_hud.text = _hud_text()


func _on_board_draw() -> void:
	board.draw_rect(Rect2(Vector2.ZERO, BOARD), BG)
	_draw_board()
	if over:
		board.draw_rect(Rect2(Vector2.ZERO, BOARD), Color(0, 0, 0, 0.72))
		text(_result_label, Vector2(BOARD.x / 2, BOARD.y / 2 - 30), 28, Color("06d6a0") if _result_good else Color("ff006e"))
		text("SCORE %d" % score, Vector2(BOARD.x / 2, BOARD.y / 2 + 6), 20, GOLD)
		if bonus > 0:
			text("+$%d BONUS" % bonus, Vector2(BOARD.x / 2, BOARD.y / 2 + 38), 18, CREAM)


func _on_board_input(event: InputEvent) -> void:
	if over:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_pointer_pressed(event.position)
		_pointer_moved(event.position)
		accept_event()
	elif event is InputEventMouseMotion:
		_pointer_moved(event.position)
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if not over:
		_key(event as InputEventKey)


## Scales the board to fit its frame, keeping the 360×460 shape.
func _fit_board() -> void:
	var frame: Control = %BoardFrame
	var s := minf(frame.size.x / BOARD.x, frame.size.y / BOARD.y)
	board.scale = Vector2(s, s)
	board.position = (frame.size - BOARD * s) / 2.0


# ── Drawing helpers for games ──

## Centred text with its baseline at `at`, like the original's canvas fillText.
func text(value: String, at: Vector2, font_size: int, color: Color, font: Font = PIXEL_FONT) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	board.draw_string(font, at - Vector2(width / 2.0, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## An emoji (or any glyph) centred on a point.
func glyph(value: String, at: Vector2, font_size: int) -> void:
	var font := ThemeDB.fallback_font
	var size := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	board.draw_string(font, at + Vector2(-size.x / 2.0, font.get_ascent(font_size) - size.y / 2.0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)


## Floating "+10" style pops: call add_pop() while playing, draw_pops() each frame.
func add_pop(at: Vector2, value: String, frames := 30, color := Color("ffd166")) -> void:
	_pops.append({ at = at, text = value, t = frames, life = frames, color = color })


func draw_pops(rise := 0.4, font_size := 10) -> void:
	for p in _pops.duplicate():
		p.t -= 1
		if p.t <= 0:
			_pops.erase(p)
			continue
		var c: Color = p.color
		c.a = clampf(float(p.t) / p.life, 0.0, 1.0)
		text(p.text, p.at - Vector2(0, (p.life - p.t) * rise), font_size, c)


func ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	board.draw_colored_polygon(points, color)


## The top half of a disc (a mole's head, a dome).
func half_disc(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	board.draw_colored_polygon(points, color)

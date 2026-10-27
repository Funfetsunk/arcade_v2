class_name MiniGame
extends Control
## Base for the playable cabinets. A game draws on a fixed 360×460 board (scaled
## to fit the screen) and runs its logic in `_tick()` 60 times a second, matching
## the original's per-frame timings. Pointer input arrives in board coordinates;
## touch and mouse are the same. Emits `finished(score)` once when a round ends.
##
## Every game runs the same shell: a ready screen (tap to start, your best and the
## star targets), a 3-2-1 countdown, play, then a results screen with stars, a
## new-best flash and the payout counting up.

signal finished(score: int)
## The countdown began: the round is committed (it uses up a play).
signal round_started
signal closed

const BOARD := Vector2(360, 460)
const BG := Color("0a0a16")
const GOLD := Color("ffb703")
const CREAM := Color("f2e4c4")
const DIM := Color("9a8a6a")
const PIXEL_FONT: Font = preload("res://assets/fonts/arcade_empire_pixel.ttf")
const STAR: Texture2D = preload("res://assets/sprites/minigames/prize_star.png")
const GREEN := Color("06d6a0")
const PINK := Color("ff006e")

enum Stage { READY, COUNTDOWN, PLAYING, OVER }

## Frames each countdown number shows for, and how long "GO!" lingers over play.
const COUNT_STEP := 40
const GO_FRAMES := 30
## Results timings (frames after the round ends): when each star lands, and when
## the payout starts and finishes counting up.
const STAR_AT := [24, 42, 60]
const PAY_FROM := 80
const PAY_FRAMES := 40

## Shown above the board.
@export var game_name := "Minigame"
@export var title_icon := "🎮"
@export_multiline var hint := ""
## The machine it's played in; none draws the bare board under a title.
@export var housing: MinigameHousing
## Blip on every score gain; games with their own scoring sounds turn it off.
@export var score_blip := true
## Scores for one, two and three stars.
@export var star_scores := PackedInt32Array([100, 200, 300])

var score := 0
var over := false
## Bonus cash the round earned, shown on the results screen.
var bonus := 0
var stage := Stage.READY
## Your previous best and its stars, set by whoever opens the game.
var best := 0
var best_stars := 0
## Stars this round earned (0-3), set when it ends.
var stars_earned := 0
## Paid plays left today on this cabinet (-1: not limited, as in the editor).
var plays_left := -1
## Set when the round starts on a cabinet with no plays left: no payout.
var practice := false
## The one-off bonus for a game's first three stars, shown on the results.
var star_bonus := 0

var _count := 0
var _go := 0
var _results_t := 0

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
	if housing:
		%Housing.texture = housing.texture
		%Housing.show()
		if housing.board_on_top:
			%BoardFrame.move_child(board, %Housing.get_index())
		if housing.title_rect.has_area():
			# The name moves onto the machine's marquee.
			_title.hide()
			%Marquee.text = game_name.to_upper()
			%Marquee.add_theme_color_override(&"font_color", housing.title_color)
			%Marquee.show()
		if housing.score_rect.has_area():
			%Score.add_theme_color_override(&"font_color", housing.score_color)
			%Score.show()
		if housing.side_art:
			%SideLeft.texture = housing.side_art
			%SideRight.texture = housing.side_art
	_hint.text = hint
	_quit.pressed.connect(close)
	board.draw.connect(_on_board_draw)
	board.gui_input.connect(_on_board_input)
	board.mouse_exited.connect(func() -> void:
		if stage == Stage.PLAYING and not over:
			_pointer_released(board.get_local_mouse_position()))
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


## Extra drawing on top of the results screen (a photo strip, a final tally).
func _draw_results() -> void:
	pass


func _hud_text() -> String:
	return "SCORE %d" % score


func _pointer_pressed(_at: Vector2) -> void:
	pass


func _pointer_moved(_at: Vector2) -> void:
	pass


## The press ended (released, or the pointer left the board).
func _pointer_released(_at: Vector2) -> void:
	pass


func _key(_event: InputEventKey) -> void:
	pass


## Ends the round with a headline for the results screen.
func end_round(label: String, good := true) -> void:
	if over:
		return
	over = true
	stage = Stage.OVER
	_result_label = label
	_result_good = good
	stars_earned = stars_for(score)
	Sfx.play(&"mg_win" if good else &"mg_lose")
	if not _awarded:
		_awarded = true
		finished.emit(score)
	_quit.text = "✓ DONE"
	board.queue_redraw()


func close() -> void:
	closed.emit()
	queue_free()


## How many stars a score earns.
func stars_for(value: int) -> int:
	var earned := 0
	for target in star_scores:
		if value >= target:
			earned += 1
	return earned


## True when this round beat the previous best (the results screen flashes it).
func is_new_best() -> bool:
	return over and score > best and score > 0


func _physics_process(_delta: float) -> void:
	match stage:
		Stage.READY:
			board.queue_redraw()
		Stage.COUNTDOWN:
			_count -= 1
			if _count <= 0:
				stage = Stage.PLAYING
				_go = GO_FRAMES
				Sfx.play(&"mg_go")
			elif _count % COUNT_STEP == 0:
				Sfx.play(&"mg_count")
			board.queue_redraw()
		Stage.PLAYING:
			var before := score
			_tick()
			if _go > 0:
				_go -= 1
			# Any score gain gets a blip, so every game has some feedback for free.
			if score_blip and score > before and not over:
				Sfx.play(&"mg_score")
			_update_hud()
			board.queue_redraw()
		Stage.OVER:
			_results_t += 1
			for i in STAR_AT.size():
				if _results_t == STAR_AT[i] and i < stars_earned:
					Sfx.play(&"mg_star")
			if _results_t == STAR_AT[-1] + 12 and is_new_best():
				Sfx.play(&"mg_best")
			if bonus > 0 and _results_t > PAY_FROM and _results_t <= PAY_FROM + PAY_FRAMES and _results_t % 4 == 0:
				Sfx.coin()
			if star_bonus > 0 and _results_t == PAY_FROM + PAY_FRAMES + 1:
				Sfx.play(&"mg_best")
			board.queue_redraw()


func _start_countdown() -> void:
	stage = Stage.COUNTDOWN
	_count = COUNT_STEP * 3
	Sfx.play(&"mg_count")
	round_started.emit()


func _update_hud() -> void:
	_hud.text = _hud_text()
	if housing and housing.score_rect.has_area():
		%Score.text = str(score)


func _on_board_draw() -> void:
	# On a table or lane the machine's own surface is the background.
	if housing == null or not housing.board_on_top:
		board.draw_rect(Rect2(Vector2.ZERO, BOARD), BG)
	_draw_board()
	match stage:
		Stage.READY:
			_draw_ready()
		Stage.COUNTDOWN:
			board.draw_rect(Rect2(Vector2.ZERO, BOARD), Color(0, 0, 0, 0.45))
			var n := ceili(float(_count) / COUNT_STEP)
			var t := float(_count % COUNT_STEP) / COUNT_STEP
			text(str(n), Vector2(BOARD.x / 2, BOARD.y / 2 + 24), int(48 + 24 * t), GOLD)
		Stage.PLAYING:
			if _go > 0:
				var c := GREEN
				c.a = float(_go) / GO_FRAMES
				text("GO!", Vector2(BOARD.x / 2, BOARD.y / 2 + 20), 52, c)
		Stage.OVER:
			_draw_over()


## The attract screen: tap to start, your best, and what each star needs.
func _draw_ready() -> void:
	board.draw_rect(Rect2(Vector2.ZERO, BOARD), Color(0, 0, 0, 0.8))
	text(game_name.to_upper(), Vector2(BOARD.x / 2, 112), 26, GOLD)
	if best > 0:
		text("YOUR BEST %d" % best, Vector2(BOARD.x / 2, 156), 18, CREAM)
		_draw_stars(Vector2(BOARD.x / 2, 184), best_stars)
	else:
		text("NO BEST YET", Vector2(BOARD.x / 2, 156), 18, DIM)
	# The targets: stars right-aligned left of centre, the score to the right.
	for i in star_scores.size():
		var y := 234.0 + i * 30
		for k in i + 1:
			sprite(STAR, Vector2(BOARD.x / 2 - 18 - k * 20, y - 6), 0.8)
		text(str(star_scores[i]), Vector2(BOARD.x / 2 + 30, y), 18, CREAM)
	if plays_left == 0:
		text("PRACTICE - NO PAYOUT TODAY", Vector2(BOARD.x / 2, 334), 14, PINK)
	elif plays_left > 0:
		text("%d PAID PLAY%s LEFT TODAY" % [plays_left, "" if plays_left == 1 else "S"], Vector2(BOARD.x / 2, 334), 14, DIM)
	# Blinks about twice a second.
	if Time.get_ticks_msec() % 1000 < 650:
		text("TAP TO START", Vector2(BOARD.x / 2, 370), 22, GREEN)


## The results: headline, score, stars landing one by one, best, payout.
func _draw_over() -> void:
	board.draw_rect(Rect2(Vector2.ZERO, BOARD), Color(0, 0, 0, 0.72))
	text(_result_label, Vector2(BOARD.x / 2, 104), 26, GREEN if _result_good else PINK)
	text("SCORE %d" % score, Vector2(BOARD.x / 2, 140), 20, GOLD)
	for i in 3:
		var at := Vector2(BOARD.x / 2 + (i - 1) * 44, 182)
		if i < stars_earned and _results_t >= STAR_AT[i]:
			# Lands big and settles.
			var k := clampf((_results_t - STAR_AT[i]) / 8.0, 0.0, 1.0)
			sprite(STAR, at, lerpf(2.6, 1.6, k))
		else:
			sprite(STAR, at, 1.6, 0.0, false, Color(0.2, 0.18, 0.3))
	if _results_t >= STAR_AT[-1] + 12:
		if is_new_best():
			text("NEW BEST!", Vector2(BOARD.x / 2, 232), 18, GOLD if int(_results_t / 8.0) % 2 == 0 else CREAM)
		elif best > 0:
			text("BEST %d" % best, Vector2(BOARD.x / 2, 232), 14, DIM)
	if bonus > 0 and _results_t > PAY_FROM:
		var shown := roundi(bonus * minf(1.0, (_results_t - PAY_FROM) / float(PAY_FRAMES)))
		text("+$%d" % shown, Vector2(BOARD.x / 2, 262), 18, CREAM)
	elif practice and _results_t > PAY_FROM:
		text("PRACTICE - NO PAYOUT", Vector2(BOARD.x / 2, 262), 14, DIM)
	if star_bonus > 0 and _results_t > PAY_FROM + PAY_FRAMES:
		text("FIRST 3 STARS! +$%d" % star_bonus, Vector2(BOARD.x / 2, 290), 16, GOLD)
	_draw_results()


## A row of three stars, the first `count` lit.
func _draw_stars(at: Vector2, count: int) -> void:
	for i in 3:
		sprite(STAR, at + Vector2((i - 1) * 22, 0), 1.0, 0.0, false, Color.WHITE if i < count else Color(0.2, 0.18, 0.3))


func _on_board_input(event: InputEvent) -> void:
	if stage == Stage.READY:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_start_countdown()
			accept_event()
		return
	if stage == Stage.COUNTDOWN:
		# Let games line up (a paddle under your finger) but not act yet.
		if event is InputEventMouseMotion:
			_pointer_moved(event.position)
		return
	if over:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pointer_pressed(event.position)
			_pointer_moved(event.position)
		else:
			_pointer_released(event.position)
		accept_event()
	elif event is InputEventMouseMotion:
		_pointer_moved(event.position)
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if stage == Stage.READY:
		if key.pressed and key.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_start_countdown()
	elif stage == Stage.PLAYING and not over:
		_key(key)


## Scales the board to fit its frame, keeping the 360×460 shape.
func _fit_board() -> void:
	var frame: Control = %BoardFrame
	if housing == null:
		var fit := minf(frame.size.x / BOARD.x, frame.size.y / BOARD.y)
		board.scale = Vector2(fit, fit)
		board.position = (frame.size - BOARD * fit) / 2.0
		return
	# The whole machine fits the frame; the board sits in its screen.
	var art := Vector2(housing.texture.get_size())
	var s := minf(frame.size.x / art.x, frame.size.y / art.y)
	var origin := (frame.size - art * s) / 2.0
	%Housing.position = origin
	%Housing.size = art * s
	board.scale = Vector2(s, s)
	board.position = origin + Vector2(housing.screen.position) * s
	for pair: Array in [[%Marquee, housing.title_rect], [%Score, housing.score_rect]]:
		var label: Label = pair[0]
		var rect: Rect2i = pair[1]
		label.position = origin + Vector2(rect.position) * s
		label.size = Vector2(rect.size)
		label.scale = Vector2(s, s)
	# Side art in the margins, when they're wide enough to read as panels.
	var margin := origin.x - 8
	var show_sides := housing.side_art != null and margin >= 24
	for side: TextureRect in [%SideLeft, %SideRight]:
		side.visible = show_sides
		side.size = Vector2(minf(margin, art.y * s * 0.27), art.y * s)
		side.position.y = origin.y
	%SideLeft.position.x = origin.x - 8 - %SideLeft.size.x
	%SideRight.position.x = origin.x + art.x * s + 8


# ── Drawing helpers for games ──

## Centred text with its baseline at `at`, like the original's canvas fillText.
func text(value: String, at: Vector2, font_size: int, color: Color, font: Font = PIXEL_FONT) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	board.draw_string(font, at - Vector2(width / 2.0, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## An emoji (or any glyph) centred on a point; `color` tints it (alpha fades it).
func glyph(value: String, at: Vector2, font_size: int, color := Color.WHITE) -> void:
	var font := ThemeDB.fallback_font
	var extent := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	board.draw_string(font, at + Vector2(-extent.x / 2.0, font.get_ascent(font_size) - extent.y / 2.0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## A sprite centred on a point, optionally scaled, turned (radians) and mirrored.
## Resets the board's transform afterwards, so call it outside a game's own
## draw_set_transform blocks.
func sprite(texture: Texture2D, at: Vector2, zoom := 1.0, angle := 0.0, flip := false, color := Color.WHITE) -> void:
	board.draw_set_transform(at, angle, Vector2(-zoom if flip else zoom, zoom))
	board.draw_texture(texture, -texture.get_size() / 2.0, color)
	board.draw_set_transform(Vector2.ZERO)


## A sliced sprite (paddles, bricks) stretched to fill a rect: its end caps keep
## their size and only the middle stretches. Tinted by color.
func stretched(box: StyleBoxTexture, rect: Rect2, color := Color.WHITE) -> void:
	box.modulate_color = color
	board.draw_style_box(box, rect)


## A grey "MISS" pop with the miss sound.
func miss(at: Vector2, frames := 30) -> void:
	add_pop(at, "MISS", frames, Color("888888"))
	play_miss()


## The miss sound alone: a lost life, a conceded goal, a crash.
func play_miss() -> void:
	Sfx.play(&"mg_miss")


## A short knock for bounces that don't score (a paddle, a mallet).
func play_hit() -> void:
	Sfx.play(&"mg_hit")


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

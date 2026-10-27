extends MiniGame
## Pinball, on one of several real tables picked at random each game: pull back
## the plunger (hold, release) to launch, then tap the left or right half (or
## ← →) to flip. Pop bumpers, posts, a bank of drop targets and rollover lights;
## lighting every light raises the multiplier (up to x5). A ball that drains
## soon after launch is saved. Three balls.
##
## The flippers and launcher are the same on every table; the rest of each
## table's layout is a PinballTable resource that follows its painted art.

const TABLES: Array[PinballTable] = [preload("res://minigames/pinball/table_stars.tres"),
	preload("res://minigames/pinball/table_planets.tres")]
const FLIPPER: Texture2D = preload("res://assets/sprites/minigames/pinball_flipper.png")
const DROP: Texture2D = preload("res://assets/sprites/minigames/pinball_drop.png")
const LIGHT_OFF: Texture2D = preload("res://assets/sprites/minigames/pinball_light_off.png")
const LIGHT_ON: Texture2D = preload("res://assets/sprites/minigames/pinball_light_on.png")
const PLUNGER: Texture2D = preload("res://assets/sprites/minigames/pinball_plunger.png")
const POST: Texture2D = preload("res://assets/sprites/minigames/pinball_post.png")
const BALL: Texture2D = preload("res://assets/sprites/minigames/pinball_ball.png")
const BUMPERS: Array[Texture2D] = [preload("res://assets/sprites/minigames/pinball_bumper_red.png"),
	preload("res://assets/sprites/minigames/pinball_bumper_blue.png"),
	preload("res://assets/sprites/minigames/pinball_bumper_yellow.png")]

const GRAVITY := 0.15
const MAX_SPEED := 11.0
const BALL_R := 7.0
const BALLS := 3
## Frames after a launch that a drained ball comes back.
const SAVE_FRAMES := 6 * 60

## Long enough that the gap between the tips is about two balls wide.
const FLIPPER_LEN := 66.0
## Frames a tap holds the flipper up, and how fast it swings (radians a frame).
const FLIP_FRAMES := 10
const FLIP_UP_SPEED := 0.3
const FLIP_DOWN_SPEED := 0.15
const LEFT_PIVOT := Vector2(108, 382)
const RIGHT_PIVOT := Vector2(252, 382)
## The flipper art's own pivot (the round end, in art pixels), angle and length.
const FLIPPER_ART_PIVOT := Vector2(7, 23)
const FLIPPER_ART_ANGLE := -0.738
const FLIPPER_ART_LEN := 29.7
## Resting and fully raised angles of the left flipper (the right mirrors it).
const FLIP_REST := 0.42
const FLIP_UP := -0.55
const PLUNGER_AT := Vector2(340, 392)

const POST_R := 6.0
## A ball that sits dead still this long (no flipper held) gets a nudge, as a
## player would shove the cabinet.
const STILL_FRAMES := 90
## How far below the launch turn the one-way gate reaches (the lane's mouth).
const GATE_DEPTH := 36.0
const DROP_SIZE := Vector2(14, 16)
const LANE_R := 12.0

enum State { READY, CHARGING, PLAY }

var table: PinballTable
var balls_left := BALLS
var state := State.READY
var ball := PLUNGER_AT
var ball_v := Vector2.ZERO
var mult := 1
var drops: Array[bool] = []
var lanes: Array[bool] = []
var _charge := 0.0
var _left_flip := 0
var _right_flip := 0
## Each flipper's angle (in the left flipper's terms; the right mirrors it) and
## how fast it's swinging up this step.
var _left_angle := FLIP_REST
var _right_angle := FLIP_REST
var _left_swing := 0.0
var _right_swing := 0.0
var _save := 0
var _bumper_glow: Array[int] = []
var _lane_cooldown: Array[int] = []
var _still := 0


func _setup() -> void:
	use_table(TABLES.pick_random())


## Sets up a table: its drop targets standing, its lights off.
func use_table(t: PinballTable) -> void:
	table = t
	drops.clear()
	lanes.clear()
	_lane_cooldown.clear()
	_bumper_glow.clear()
	for i in table.drops.size():
		drops.append(true)
	for i in table.lanes.size():
		lanes.append(false)
		_lane_cooldown.append(0)
	for i in table.bumpers.size():
		_bumper_glow.append(0)


func _pointer_pressed(at: Vector2) -> void:
	if state == State.READY:
		state = State.CHARGING
		_charge = 0.0
		return
	if state == State.PLAY:
		_flip(at.x < BOARD.x / 2)


func _pointer_released(_at: Vector2) -> void:
	if state == State.CHARGING:
		_launch()


func _key(event: InputEventKey) -> void:
	if event.echo:
		return
	match event.keycode:
		KEY_LEFT:
			if event.pressed and state == State.PLAY:
				_flip(true)
		KEY_RIGHT:
			if event.pressed and state == State.PLAY:
				_flip(false)
		KEY_SPACE, KEY_DOWN:
			if event.pressed and state == State.READY:
				state = State.CHARGING
				_charge = 0.0
			elif not event.pressed and state == State.CHARGING:
				_launch()


func _flip(left: bool) -> void:
	if left:
		_left_flip = FLIP_FRAMES
	else:
		_right_flip = FLIP_FRAMES
	Sfx.play(&"pb_flip")


## Every launch reaches the top of the lane; a fuller pull carries it further.
func _launch() -> void:
	ball_v = Vector2(0, -(10.3 + _charge * 0.7))
	state = State.PLAY
	_save = SAVE_FRAMES
	Sfx.play(&"pb_launch")


func _tick() -> void:
	match state:
		State.CHARGING:
			_charge = minf(1.0, _charge + 0.025)
			return
		State.READY:
			return
	ball_v.y += GRAVITY
	# Substeps so a fast ball can't tunnel through the rails, and the flippers
	# sweep through the ball rather than jumping past it.
	var steps := maxi(4, ceili(ball_v.length() / 2.5))
	for s in steps:
		_left_swing = _swing_step(true, steps)
		_right_swing = _swing_step(false, steps)
		ball += ball_v / steps
		_collide()
	ball_v = ball_v.limit_length(MAX_SPEED)
	_still = _still + 1 if ball_v.length() < 0.3 and _left_flip == 0 and _right_flip == 0 else 0
	if _still > STILL_FRAMES:
		_still = 0
		ball_v = Vector2(randf_range(-2.0, 2.0), -2.5)
	_left_flip = maxi(0, _left_flip - 1)
	_right_flip = maxi(0, _right_flip - 1)
	_save = maxi(0, _save - 1)
	for i in _bumper_glow.size():
		_bumper_glow[i] = maxi(0, _bumper_glow[i] - 1)
	for i in _lane_cooldown.size():
		_lane_cooldown[i] = maxi(0, _lane_cooldown[i] - 1)
	if ball.y - BALL_R > BOARD.y:
		_drain()


func _collide() -> void:
	var b := table.bounds
	if ball.x - BALL_R < b.position.x:
		ball.x = b.position.x + BALL_R
		ball_v.x = absf(ball_v.x) * 0.7
	if ball.x + BALL_R > b.end.x:
		ball.x = b.end.x - BALL_R
		ball_v.x = -absf(ball_v.x) * 0.7
	if ball.y - BALL_R < b.position.y:
		ball.y = b.position.y + BALL_R
		ball_v.y = absf(ball_v.y) * 0.7
	for wall in table.walls:
		for i in wall.size() - 1:
			_hit_segment(wall[i], wall[i + 1], 0.45)
	# The launched ball is turned into play at the top of its lane, keeping its
	# speed; one coming back down is turned out of it again (a one-way gate).
	if ball_v.y < 0 and table.deflector.has_point(ball):
		ball_v = table.deflect_dir.normalized() * maxf(ball_v.length(), 6.0)
	elif ball_v.y >= 0 and table.deflector.grow_individual(0, 0, 0, GATE_DEPTH).has_point(ball):
		ball_v = Vector2(-maxf(absf(ball_v.x), 3.0), ball_v.y * 0.5)
	for i in table.bumpers.size():
		var at := table.bumpers[i]
		var d := ball.distance_to(at)
		if d < table.bumper_r + BALL_R and d > 0:
			var n := (ball - at) / d
			ball = at + n * (table.bumper_r + BALL_R)
			ball_v = n * 7.0
			_bumper_glow[i] = 10
			_add(10)
			Sfx.play(&"pb_bump")
	for at in table.posts:
		var d := ball.distance_to(at)
		if d < POST_R + BALL_R and d > 0:
			var n := (ball - at) / d
			ball = at + n * (POST_R + BALL_R)
			ball_v = ball_v.bounce(n) * 0.8
	for i in table.drops.size():
		if drops[i] and Rect2(table.drops[i] - DROP_SIZE / 2, DROP_SIZE).grow(BALL_R).has_point(ball):
			drops[i] = false
			ball_v.y = absf(ball_v.y) * 0.7
			_add(25)
			Sfx.play(&"pb_drop")
			if not drops.has(true):
				_add(100)
				add_pop(table.drops[1] + Vector2(0, 30), "TARGETS CLEARED!", 50, GOLD)
				drops.fill(true)
	for i in table.lanes.size():
		if not lanes[i] and _lane_cooldown[i] == 0 and ball.distance_to(table.lanes[i]) < LANE_R:
			lanes[i] = true
			_lane_cooldown[i] = 20
			_add(15)
			Sfx.play(&"pb_lane")
			if not lanes.has(false):
				mult = mini(5, mult + 1)
				add_pop(Vector2(180, 100), "MULTIPLIER x%d!" % mult, 50, GOLD)
				Sfx.play(&"mg_star")
				lanes.fill(false)
	_kick(LEFT_PIVOT, true, _left_swing)
	_kick(RIGHT_PIVOT, false, _right_swing)


func _add(points: int) -> void:
	score += points * mult


func _drain() -> void:
	if _save > 0:
		add_pop(Vector2(180, 300), "BALL SAVED!", 50, Color("06d6a0"))
	else:
		balls_left -= 1
		Sfx.play(&"pb_drain")
		if balls_left <= 0:
			end_round("GAME OVER", score >= star_scores[0])
			return
		mult = 1
	ball = PLUNGER_AT
	ball_v = Vector2.ZERO
	state = State.READY


## Ball against a segment (`pad` widens it, e.g. a flipper's thickness): pushes
## the ball out and reflects it. Returns the contact normal, or ZERO for no hit.
func _hit_segment(a: Vector2, b: Vector2, bounce: float, pad := 0.0) -> Vector2:
	var reach := BALL_R + pad
	var closest := Geometry2D.get_closest_point_to_segment(ball, a, b)
	var d := ball.distance_to(closest)
	if d >= reach or d == 0.0:
		return Vector2.ZERO
	var n := (ball - closest) / d
	ball = closest + n * reach
	var dot := ball_v.dot(n)
	if dot < 0:
		ball_v -= (1 + bounce) * dot * n
	return n


## Moves a flipper one substep toward up (while held) or rest; returns how fast
## it's swinging up, in radians a frame (0 when it isn't).
func _swing_step(left: bool, steps: int) -> float:
	var held := (_left_flip if left else _right_flip) > 0
	var angle := _left_angle if left else _right_angle
	var target := FLIP_UP if held else FLIP_REST
	var moved := clampf(target - angle, -FLIP_UP_SPEED / steps, FLIP_DOWN_SPEED / steps)
	if left:
		_left_angle += moved
	else:
		_right_angle += moved
	return -moved * steps if moved < 0 else 0.0


func _flipper_angle(left: bool) -> float:
	return _left_angle if left else PI - _right_angle


func _flipper_tip(pivot: Vector2, left: bool) -> Vector2:
	return pivot + Vector2.from_angle(_flipper_angle(left)) * FLIPPER_LEN


## A flipper bounces the ball; swinging up it throws it, faster further out.
func _kick(pivot: Vector2, left: bool, swing: float) -> void:
	var n := _hit_segment(pivot, _flipper_tip(pivot, left), 0.3, 5.0)
	if n != Vector2.ZERO and swing > 0.0:
		var reach := ball.distance_to(pivot)
		ball_v += n * swing * reach * 0.6


func _draw_board() -> void:
	board.draw_texture_rect(table.playfield, Rect2(Vector2.ZERO, BOARD), false)
	for i in table.lanes.size():
		sprite(LIGHT_ON if lanes[i] else LIGHT_OFF, table.lanes[i])
	for at in table.posts:
		sprite(POST, at)
	for i in table.drops.size():
		if drops[i]:
			sprite(DROP, table.drops[i])
		else:
			sprite(DROP, table.drops[i] + Vector2(0, 4), 1.0, 0.0, false, Color(0.25, 0.25, 0.35, 0.6))
	for i in table.bumpers.size():
		# Flashes bright when hit.
		var lit := Color(1.7, 1.7, 1.7) if _bumper_glow[i] > 0 else Color.WHITE
		sprite(BUMPERS[i % BUMPERS.size()], table.bumpers[i], 1.0, 0.0, false, lit)
	_draw_flipper(LEFT_PIVOT, true)
	_draw_flipper(RIGHT_PIVOT, false)
	# The plunger, pulled down as it charges; knob at the bottom.
	sprite(PLUNGER, PLUNGER_AT + Vector2(0, 22 + _charge * 10), 1.0, -PI / 2)
	sprite(BALL, ball)
	draw_pops(0.4, 11)


## The flipper art turned to the flipper's angle, round end on the pivot.
func _draw_flipper(pivot: Vector2, left: bool) -> void:
	var angle := _flipper_angle(left)
	var art_angle := FLIPPER_ART_ANGLE if left else PI - FLIPPER_ART_ANGLE
	var zoom := FLIPPER_LEN / FLIPPER_ART_LEN
	board.draw_set_transform(pivot, angle - art_angle, Vector2(zoom if left else -zoom, zoom))
	board.draw_texture(FLIPPER, -FLIPPER_ART_PIVOT)
	board.draw_set_transform(Vector2.ZERO)


func _hud_text() -> String:
	return "SCORE %d    BALLS %d    x%d" % [score, maxi(0, balls_left), mult]

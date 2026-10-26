extends MiniGame
## Skee Roll: swipe up the lane to roll the ball. It slows as it rolls, hops the
## ramp if it's moving fast enough, and drops into a ring: 10 to 50 from the edge
## in, or 100 in a corner pocket. A faster swipe flies further. Nine balls.

const TARGET: Texture2D = preload("res://assets/sprites/minigames/skee_target.png")
const RAMP: Texture2D = preload("res://assets/sprites/minigames/skee_ramp.png")
const BALL: Texture2D = preload("res://assets/sprites/minigames/skee_ball.png")
const ARROW: Texture2D = preload("res://assets/sprites/minigames/arrow.png")

const BALLS := 9
## The target art is drawn at 2x with its bullseye here; ring edges and pockets
## are the art's, in board pixels (art pixels x 2).
const ZOOM := 2.0
const CENTRE := Vector2(BOARD.x / 2, 150)
const ART_CENTRE := Vector2(100, 77)
## Ring edges from the bullseye out, and what landing inside each scores.
const RINGS := [[18.0, 50], [44.0, 40], [68.0, 30], [94.0, 20], [116.0, 10]]
const POCKET_R := 14.0
const POCKETS := [Vector2(70, 50), Vector2(290, 50)]
## The ramp's lip, where the ball takes off; the slope runs down from it.
const RAMP_Y := 296.0
const RAMP_DEPTH := 88.0
## Extra slowing while climbing the slope.
const UPHILL := 0.985
const HOME := Vector2(BOARD.x / 2, 420)
const LANE_X := Vector2(26, BOARD.x - 26)
## Roll speed below this (px/frame) at the ramp doesn't clear it.
const HOP_MIN := 4.0
## Flight distance per unit of speed above HOP_MIN, plus a base hop.
const HOP_PER_SPEED := 22.0
const HOP_BASE := 40.0
const FLIGHT_FRAMES := 26
const SINK_FRAMES := 24
const MAX_SPEED := 14.0
const FRICTION := 0.992

enum State { AIM, ROLL, FLY, SINK, BACK }

var balls_left := BALLS
var state := State.AIM
var ball := HOME
var vel := Vector2.ZERO
var _press := Vector2.ZERO
var _press_frame := 0
var _drag := Vector2.ZERO
var _dragging := false
var _frame := 0
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _t := 0


func _pointer_pressed(at: Vector2) -> void:
	if state != State.AIM:
		return
	_dragging = true
	_press = at
	_drag = at
	_press_frame = _frame


func _pointer_moved(at: Vector2) -> void:
	if _dragging:
		_drag = at


## A swipe's speed is its length over how long it took, so a quick flick rolls fast.
func _pointer_released(at: Vector2) -> void:
	if not _dragging:
		return
	_dragging = false
	var swipe := at - _press
	if swipe.y > -20:
		return
	var frames := maxi(4, _frame - _press_frame)
	vel = swipe / frames * 0.5
	if vel.length() > MAX_SPEED:
		vel = vel.normalized() * MAX_SPEED
	state = State.ROLL
	play_hit()


func _tick() -> void:
	_frame += 1
	match state:
		State.ROLL:
			ball += vel
			vel *= FRICTION
			if ball.y < RAMP_Y + RAMP_DEPTH:
				vel *= UPHILL
			if ball.x < LANE_X.x or ball.x > LANE_X.y:
				ball.x = clampf(ball.x, LANE_X.x, LANE_X.y)
				vel.x *= -0.6
			if ball.y <= RAMP_Y:
				_hop()
		State.FLY:
			_t += 1
			ball = _from.lerp(_to, float(_t) / FLIGHT_FRAMES)
			if _t >= FLIGHT_FRAMES:
				_land()
		State.SINK:
			_t += 1
			if _t >= SINK_FRAMES:
				_next_ball()
		State.BACK:
			# Too slow for the ramp: it rolls back to you.
			ball += vel
			if ball.y >= HOME.y:
				_next_ball()


func _hop() -> void:
	var speed := vel.length()
	if speed < HOP_MIN:
		add_pop(Vector2(ball.x, RAMP_Y - 20), "TOO SOFT", 30, Color("888888"))
		play_miss()
		vel = Vector2(0, 3)
		state = State.BACK
		return
	_from = ball
	_to = ball + vel.normalized() * ((speed - HOP_MIN) * HOP_PER_SPEED + HOP_BASE)
	# Too strong bounces back off the top of the machine.
	if _to.y < 12:
		_to.y = 12 + (12 - _to.y) * 0.4
	_to.x = clampf(_to.x, LANE_X.x, LANE_X.y)
	_t = 0
	state = State.FLY


func _land() -> void:
	var points := points_at(ball)
	if points > 0:
		score += points
		add_pop(ball - Vector2(0, 18), "+%d" % points, 40, GOLD if points >= 50 else Color("ffd166"))
	else:
		miss(ball - Vector2(0, 18))
	_t = 0
	state = State.SINK


## What a ball landing at `at` scores: a pocket, else the ring it's in.
func points_at(at: Vector2) -> int:
	for pocket: Vector2 in POCKETS:
		if at.distance_to(pocket) <= POCKET_R:
			return 100
	var distance := at.distance_to(CENTRE)
	for ring: Array in RINGS:
		if distance <= ring[0]:
			return ring[1]
	return 0


func _next_ball() -> void:
	balls_left -= 1
	if balls_left <= 0:
		end_round("FINISHED!", true)
		return
	ball = HOME
	vel = Vector2.ZERO
	state = State.AIM


func _draw_board() -> void:
	sprite(TARGET, CENTRE + (Vector2(TARGET.get_size()) / 2.0 - ART_CENTRE) * ZOOM, ZOOM)
	# Each ring's value just below the bullseye, and on the pockets.
	for i in RINGS.size():
		var inner: float = 0.0 if i == 0 else RINGS[i - 1][0]
		text(str(RINGS[i][1]), CENTRE + Vector2(0, (inner + RINGS[i][0]) / 2.0 + 4), 9, CREAM)
	for pocket: Vector2 in POCKETS:
		text("100", pocket + Vector2(0, 26), 9, GOLD)
	sprite(RAMP, Vector2(BOARD.x / 2, RAMP_Y + RAMP_DEPTH / 2), ZOOM)
	match state:
		State.AIM:
			if _dragging and _drag.y < _press.y - 8:
				# Arrows up from the ball show the swipe's direction.
				var dir := (_drag - _press).normalized()
				for i in 3:
					var c := Color(1, 1, 1, 0.9 - i * 0.25)
					sprite(ARROW, ball + dir * (30 + i * 22), 0.8, dir.angle() + PI / 2, false, c)
			sprite(BALL, ball)
		State.FLY:
			# A hop: the ball grows as it rises and its shadow stays on the lane.
			var lift := sin(PI * _t / FLIGHT_FRAMES)
			sprite(BALL, ball + Vector2(0, 6), 1.0, 0.0, false, Color(0, 0, 0, 0.35))
			sprite(BALL, ball - Vector2(0, lift * 24), 1.0 + lift * 0.6)
		State.SINK:
			sprite(BALL, ball, 1.0 - float(_t) / SINK_FRAMES)
		_:
			sprite(BALL, ball)
	draw_pops(0.5, 12)


func _hud_text() -> String:
	return "SCORE %d    BALLS %d" % [score, maxi(0, balls_left)]

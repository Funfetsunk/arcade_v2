extends MiniGame
## Pinball: a gravity ball, two flippers, bumpers and top targets. Tap the left
## or right half of the board (or ← →) to flip. Three balls.

const GRAVITY := 0.14
const FLIPPER_LEN := 56.0
const FLIP_FRAMES := 12
const LEFT_PIVOT := Vector2(104, 414)
const RIGHT_PIVOT := Vector2(256, 414)
const BALL_R := 6.0
## Side funnels sealed right up to the flipper pivots.
const WALLS := [[Vector2(0, 320), LEFT_PIVOT], [Vector2(BOARD.x, 320), RIGHT_PIVOT]]

var balls := 3
var ball := Vector2.ZERO
var ball_v := Vector2.ZERO
var bumpers: Array[Dictionary] = []
var targets: Array[Dictionary] = []
## Frames of upward swing left on each flipper.
var _left_flip := 0
var _right_flip := 0


func _setup() -> void:
	for at in [Vector2(92, 150), Vector2(268, 150), Vector2(180, 218)]:
		bumpers.append({ at = at, r = 20.0, glow = 0 })
	for at in [Vector2(110, 66), Vector2(180, 56), Vector2(250, 66)]:
		targets.append({ at = at, r = 9.0, cooldown = 0 })
	_new_ball()


func _new_ball() -> void:
	ball = Vector2(60 + randf() * 240, 50)
	ball_v = Vector2((randf() - 0.5) * 2, 0)


func _pointer_pressed(at: Vector2) -> void:
	_flip(at.x < BOARD.x / 2)


func _key(event: InputEventKey) -> void:
	if event.pressed and event.keycode == KEY_LEFT:
		_flip(true)
	elif event.pressed and event.keycode == KEY_RIGHT:
		_flip(false)


func _flip(left: bool) -> void:
	if left:
		_left_flip = FLIP_FRAMES
	else:
		_right_flip = FLIP_FRAMES


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


func _flipper_tip(pivot: Vector2, left: bool, flip: int) -> Vector2:
	const REST := 0.5
	const UP := -0.62
	var a := UP + (REST - UP) * (1 - flip / float(FLIP_FRAMES)) if flip > 0 else REST
	return pivot + Vector2.from_angle(a if left else PI - a) * FLIPPER_LEN


func _tick() -> void:
	ball_v.y += GRAVITY
	# Substep so a fast ball can't tunnel through the flippers.
	var steps := maxi(1, ceili(ball_v.length() / 3))
	for s in steps:
		ball += ball_v / steps
		if ball.x - BALL_R < 0:
			ball.x = BALL_R
			ball_v.x *= -0.85
		if ball.x + BALL_R > BOARD.x:
			ball.x = BOARD.x - BALL_R
			ball_v.x *= -0.85
		if ball.y - BALL_R < 0:
			ball.y = BALL_R
			ball_v.y *= -0.85
		for b in bumpers:
			var d := ball.distance_to(b.at)
			if d < b.r + BALL_R and d > 0:
				var n: Vector2 = (ball - b.at) / d
				ball = b.at + n * (b.r + BALL_R)
				ball_v = n * 5
				score += 15
				b.glow = 10
		for t in targets:
			if t.cooldown <= 0 and ball.distance_to(t.at) < t.r + BALL_R:
				score += 10
				t.cooldown = 40
				ball_v.y = absf(ball_v.y) * 0.6 + 1
		for wall in WALLS:
			_hit_segment(wall[0], wall[1], 0.5)
		_kick(LEFT_PIVOT, true, _left_flip)
		_kick(RIGHT_PIVOT, false, _right_flip)
	for b in bumpers:
		b.glow = maxi(0, b.glow - 1)
	for t in targets:
		t.cooldown = maxi(0, t.cooldown - 1)
	_left_flip = maxi(0, _left_flip - 1)
	_right_flip = maxi(0, _right_flip - 1)
	ball_v = ball_v.limit_length(9)
	if ball.y - BALL_R > BOARD.y:
		balls -= 1
		if balls <= 0:
			end_round("DRAINED!", score >= 150)
		else:
			_new_ball()


## A flipper bounces the ball; mid-swing it kicks it as well.
func _kick(pivot: Vector2, left: bool, flip: int) -> void:
	var n := _hit_segment(pivot, _flipper_tip(pivot, left, flip), 0.4, 4.5)
	if n != Vector2.ZERO and flip > 4:
		ball_v += n * 6 - Vector2(0, 2)


func _draw_board() -> void:
	for t in targets:
		board.draw_circle(t.at, t.r, Color("3a2a55") if t.cooldown > 0 else Color("06d6a0"))
	for b in bumpers:
		var lit := Color("ffd166") if b.glow > 0 else Color("ff006e")
		board.draw_circle(b.at, b.r, lit)
		board.draw_circle(b.at, b.r - 6, BG)
		board.draw_circle(b.at, 5, lit)
	for wall in WALLS:
		board.draw_line(wall[0], wall[1], Color("6b4a23"), 4.0)
	for flipper in [[LEFT_PIVOT, true, _left_flip], [RIGHT_PIVOT, false, _right_flip]]:
		var tip := _flipper_tip(flipper[0], flipper[1], flipper[2])
		board.draw_line(flipper[0], tip, GOLD, 9.0)
		board.draw_circle(flipper[0], 4.5, GOLD)
		board.draw_circle(tip, 4.5, GOLD)
	board.draw_circle(ball, BALL_R, Color.WHITE)


func _hud_text() -> String:
	return "SCORE %d    BALLS %s" % [score, "●".repeat(maxi(0, balls))]

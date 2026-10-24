extends MiniGame
## Grand Prix: a top-down loop circuit. Hold the left or right half of the board
## (or ← →) to steer. Off the track is slow; every lap scores big. 30 s.

const CENTER := Vector2(BOARD.x / 2, 240)
const R_OUT := 150.0
const R_IN := 78.0
const R_MID := (R_OUT + R_IN) / 2

## Starts at the top of the loop heading clockwise.
var car := CENTER - Vector2(0, R_MID)
var heading := 0.0
var speed := 0.0
var laps := 0
var time := 30 * 60
var skids: Array[Dictionary] = []
var _steer := 0
var _left := false
var _right := false
var _progress := 0.0
var _prev_angle := 0.0
var _on_track_frames := 0


func _setup() -> void:
	_prev_angle = (car - CENTER).angle()


func _pointer_pressed(at: Vector2) -> void:
	_steer = -1 if at.x < BOARD.x / 2 else 1


func _pointer_released(_at: Vector2) -> void:
	_steer = 0


func _key(event: InputEventKey) -> void:
	match event.keycode:
		KEY_LEFT:
			_left = event.pressed
		KEY_RIGHT:
			_right = event.pressed


func _tick() -> void:
	time -= 1
	if time <= 0:
		end_round("PODIUM!" if laps >= 3 else "CHEQUERED FLAG", laps >= 3)
		return
	var steer := _steer if _steer != 0 else (-1 if _left else 0) + (1 if _right else 0)
	var d := car.distance_to(CENTER)
	var on_track := d <= R_OUT - 8 and d >= R_IN + 8
	speed += ((3.0 if on_track else 1.4) - speed) * 0.08
	heading += steer * 0.055
	car += Vector2(cos(heading), sin(heading)) * speed
	car = car.clamp(Vector2(10, 60), Vector2(BOARD.x - 10, BOARD.y - 10))
	if not on_track and (time & 3) == 0:
		skids.append({ at = car, t = 50 })
	if on_track:
		_on_track_frames += 1
		if _on_track_frames % 20 == 0:
			score += 1
	# Laps: add up the angle swept round the centre (clockwise is positive).
	var angle := (car - CENTER).angle()
	var swept := wrapf(angle - _prev_angle, -PI, PI)
	_prev_angle = angle
	_progress += swept
	if _progress >= TAU:
		_progress -= TAU
		laps += 1
		score += 60
		add_pop(Vector2(CENTER.x, 40), "LAP %d! +60" % laps, 50)
	if _progress < -TAU:
		_progress += TAU
	for s in skids.duplicate():
		s.t -= 1
		if s.t <= 0:
			skids.erase(s)


func _draw_board() -> void:
	board.draw_rect(Rect2(Vector2.ZERO, BOARD), Color("10240f"))
	board.draw_circle(CENTER, R_OUT, Color("22262a"))
	board.draw_circle(CENTER, R_IN, Color("10240f"))
	# Kerbs.
	for r in [R_OUT, R_IN]:
		for i in ceili(TAU / 0.22):
			var a := i * 0.22
			board.draw_circle(CENTER + Vector2(cos(a), sin(a)) * r, 3.5, Color("c93a3a") if i % 2 else Color("e8e0d0"))
	# Centre dashes: 10 px on, 14 px off.
	var step := 24.0 / R_MID
	var a0 := 0.0
	while a0 < TAU:
		board.draw_arc(CENTER, R_MID, a0, a0 + 10.0 / R_MID, 4, DIM, 2.0)
		a0 += step
	# Start / finish line at the top.
	var line := CENTER - Vector2(0, R_MID)
	for i in 6:
		for j in 2:
			if (i + j) % 2 == 0:
				board.draw_rect(Rect2(line + Vector2(-6 + j * 6, -36 + i * 12), Vector2(6, 12)), Color.WHITE)
	for s in skids:
		board.draw_rect(Rect2(s.at - Vector2(2, 2), Vector2(4, 4)), Color(40 / 255.0, 30 / 255.0, 16 / 255.0, 0.5))
	# The car.
	board.draw_set_transform(car, heading)
	var tyre := Color("16161e")
	for at in [Vector2(-10, -8), Vector2(-10, 4), Vector2(5, -8), Vector2(5, 4)]:
		board.draw_rect(Rect2(at, Vector2(6, 4)), tyre)
	board.draw_rect(Rect2(-12, -5, 24, 10), GOLD)
	board.draw_rect(Rect2(2, -4, 7, 8), Color("1c1430"))
	board.draw_set_transform(Vector2.ZERO)
	draw_pops(0.0, 13)


func _hud_text() -> String:
	return "SCORE %d    LAPS %d    TIME %d" % [score, laps, ceili(maxi(0, time) / 60.0)]

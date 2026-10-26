extends MiniGame
## Motion Sim: the track bends ahead; drag left and right to lean the pod into
## the bends and stay in the sweet band. Three strikes ends the ride. 30 s.

const ROUND := 30 * 60
const HORIZON := 110.0
const BOTTOM := 400.0
const REACH := BOARD.x * 0.36

const POD: Texture2D = preload("res://assets/sprites/minigames/sim_pod.png")

var lean := 0.0
var strikes := 0
var time := ROUND
var _t := 0.0
var _out := 0
var _shake := 0.0
var _score_tick := 0


## How far the track bends at a point along it, -1 (left) to 1 (right).
func _curve(at: float) -> float:
	return clampf(0.7 * sin(at * 0.9) + 0.45 * sin(at * 1.7 + 2), -1, 1)


func _pointer_moved(at: Vector2) -> void:
	lean = clampf((at.x - BOARD.x / 2) / REACH, -1, 1)


func _tick() -> void:
	time -= 1
	if time <= 0:
		end_round("RIDE OVER!")
		return
	var target := _curve(_t)
	_t += 0.012 + (1.0 - float(time) / ROUND) * 0.012
	var err := absf(lean - target)
	_score_tick += 1
	if _score_tick >= 10:
		_score_tick = 0
		if err < 0.12:
			score += 4
		elif err < 0.28:
			score += 2
	if err >= 0.28:
		_out += 1
		_shake = minf(8, _shake + 0.5)
		if _out > 50:
			_out = 0
			strikes += 1
			play_miss()
			add_pop(Vector2(BOARD.x / 2, 200), "STRIKE!", 40, Color("ff006e"))
			if strikes >= 3:
				end_round("EJECTED!", false)
	else:
		_out = maxi(0, _out - 2)
		_shake = maxf(0, _shake - 0.4)


func _draw_board() -> void:
	var shake := Vector2.ZERO
	if _shake > 0.5 and not over:
		shake = Vector2(randf() - 0.5, randf() - 0.5) * _shake
	board.draw_set_transform(shake)
	# The track ribbon, bending less the further away it is.
	var y := HORIZON
	while y < BOTTOM:
		var f := (y - HORIZON) / (BOTTOM - HORIZON)
		var cx := BOARD.x / 2 - _curve(_t + (1 - f) * 2.2) * 90 * (1 - f)
		var half := 22 + f * 105
		board.draw_rect(Rect2(cx - half, y, half * 2, 6), Color("1c1430") if int(y / 6) % 2 else Color("241a3a"))
		board.draw_rect(Rect2(cx - half - 4, y, 4, 6), GOLD)
		board.draw_rect(Rect2(cx + half, y, 4, 6), GOLD)
		y += 6
	# The sweet band and the pod.
	var target_x := BOARD.x / 2 + _curve(_t) * REACH
	board.draw_rect(Rect2(target_x - REACH * 0.28, 408, REACH * 0.56, 30), Color(6 / 255.0, 214 / 255.0, 160 / 255.0, 0.22))
	board.draw_rect(Rect2(target_x - 2, 408, 4, 30), Color("06d6a0"))
	board.draw_set_transform(Vector2.ZERO)
	sprite(POD, shake + Vector2(BOARD.x / 2 + lean * REACH, 424), 2.0, lean * 0.5)
	draw_pops(0.0, 13)


func _hud_text() -> String:
	return "SCORE %d    STRIKES %d/3    TIME %d" % [score, strikes, ceili(maxi(0, time) / 60.0)]

extends MiniGame
## Tunnel Rush: a pseudo-3D tunnel where rings rush outward. Drag the pod round
## its orbit to pass through each ring's gap. Three hits ends the run. 30 s.

const CENTER := Vector2(BOARD.x / 2, 220)
const ORBIT := 120.0
const GAP := 1.15
## The depth at which a ring reaches the pod's orbit.
const Z_POD := (ORBIT - 10) / 160
const ROUND := 30 * 60

const POD: Texture2D = preload("res://assets/sprites/minigames/vr_pod.png")

var theta := PI / 2
var rings: Array[Dictionary] = []
var hits := 0
var time := ROUND
var _spawn := 0.0
var _z_speed := 0.008
var _hurt := 0
var _frame := 0


func _pointer_moved(at: Vector2) -> void:
	theta = (at - CENTER).angle()


func _tick() -> void:
	time -= 1
	if time <= 0:
		end_round("RUN COMPLETE")
		return
	_frame += 1
	if _frame % 6 == 0:
		score += 1
	if _hurt > 0:
		_hurt -= 1
	var ramp := 1.0 - float(time) / ROUND
	_z_speed = 0.008 + ramp * 0.006
	_spawn -= 1
	if _spawn <= 0:
		_spawn = 52 - ramp * 20
		rings.append({ z = 0.0, gap = randf() * TAU, done = false })
	for r in rings:
		var before: float = r.z
		r.z += _z_speed
		if not r.done and before < Z_POD and r.z >= Z_POD:
			r.done = true
			if absf(angle_difference(r.gap, theta)) < GAP / 2:
				score += 10
				add_pop(CENTER - Vector2(0, 30), "+10", 24)
			else:
				hits += 1
				_hurt = 18
				play_miss()
				add_pop(CENTER - Vector2(0, 30), "HIT!", 30, Color("ff006e"))
	rings = rings.filter(func(r: Dictionary) -> bool: return r.z < 1.3)
	if hits >= 3:
		end_round("POD DOWN!", false)


func _draw_board() -> void:
	# A soft radial glow, in rings from the outside in.
	for i in range(20, 0, -1):
		board.draw_circle(CENTER, 6 + 194 * i / 20.0, Color("1c1430").lerp(BG, i / 20.0))
	var sorted := rings.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.z < b.z)
	for r in sorted:
		var color := Color("3a3a55") if r.done else Color("06d6a0")
		color.a = minf(1.0, r.z * 2 + 0.15)
		board.draw_arc(CENTER, 10 + r.z * 160, r.gap + GAP / 2, r.gap - GAP / 2 + TAU, 48, color, 3 + r.z * 5)
	var pod := CENTER + Vector2.from_angle(theta) * ORBIT
	sprite(POD, pod, 1.0, 0.0, false, Color("ff006e") if _hurt > 0 and (_hurt & 4) != 0 else Color.WHITE)
	if _hurt > 12:
		board.draw_rect(Rect2(Vector2.ZERO, BOARD), Color(1, 0, 110 / 255.0, (_hurt - 12) * 0.05))
	draw_pops(0.0, 12)


func _hud_text() -> String:
	return "SCORE %d    SHIELD %s    TIME %d" % [score, "●".repeat(maxi(0, 3 - hits)), ceili(maxi(0, time) / 60.0)]

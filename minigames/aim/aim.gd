extends MiniGame
## Roll & Score: a sight drifts over a ringed target; tap to fire. Six balls,
## closer to the bullseye scores more.

const CENTRE := Vector2(BOARD.x / 2, 150)
## Rings from the bullseye out: radius, points, colour.
const RINGS := [[14.0, 50, Color("ff006e")], [30.0, 30, Color("ffb703")], [48.0, 20, Color("06d6a0")], [68.0, 10, Color("3a86ff")]]

var balls := 6
var _t := 0.0


func _sight() -> Vector2:
	return CENTRE + Vector2(cos(_t * 1.7) * 60, sin(_t * 2.3) * 46)


func _pointer_pressed(_at: Vector2) -> void:
	var at := _sight()
	var distance := at.distance_to(CENTRE)
	var points := 0
	for ring: Array in RINGS:
		if distance <= ring[0]:
			points = ring[1]
			break
	score += points
	add_pop(at, "+%d" % points if points else "MISS", 30, Color("ffd166") if points else Color("888888"))
	balls -= 1
	if balls <= 0:
		end_round("FINISHED!", true)


func _tick() -> void:
	_t += 0.045


func _draw_board() -> void:
	for i in range(RINGS.size() - 1, -1, -1):
		board.draw_circle(CENTRE, RINGS[i][0], RINGS[i][2])
	board.draw_circle(CENTRE, 4, Color.WHITE)
	draw_pops(0.6, 12)
	if not over:
		var g := _sight()
		board.draw_arc(g, 7, 0, TAU, 20, Color.WHITE, 2.0)
		board.draw_line(g - Vector2(11, 0), g + Vector2(11, 0), Color.WHITE, 2.0)
		board.draw_line(g - Vector2(0, 11), g + Vector2(0, 11), Color.WHITE, 2.0)


func _hud_text() -> String:
	return "SCORE %d    BALLS %s" % [score, "●".repeat(maxi(0, balls))]

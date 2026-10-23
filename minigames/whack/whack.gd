extends MiniGame
## Whack-It: critters pop up from a 3×3 grid; tap them before they duck. 20 s.

const COLS := 3
const ROWS := 3
const SPACING := 70.0
const GRID_TOP := 150.0

var holes: Array[Dictionary] = []
var time := 20 * 60
var _spawn := 0.0


func _setup() -> void:
	var left := (BOARD.x - COLS * SPACING) / 2 + SPACING / 2
	for r in ROWS:
		for c in COLS:
			holes.append({ at = Vector2(left + c * SPACING, GRID_TOP + r * SPACING), up = 0.0, hit = false, pop = 0 })


func _pointer_pressed(at: Vector2) -> void:
	for h in holes:
		if h.up > 0 and not h.hit and at.distance_to(h.at) < 28:
			h.hit = true
			h.pop = 12
			score += 10
			break


func _tick() -> void:
	time -= 1
	if time <= 0:
		end_round("TIME!", true)
		return
	_spawn -= 1
	if _spawn <= 0:
		_spawn = 22 + randf() * 26
		var free := holes.filter(func(h: Dictionary) -> bool: return h.up <= 0)
		if not free.is_empty():
			var h: Dictionary = free.pick_random()
			h.up = 40 + randf() * 35
			h.hit = false
	for h in holes:
		if h.up > 0:
			h.up -= 1
		if h.pop > 0:
			h.pop -= 1


func _draw_board() -> void:
	for h in holes:
		var at: Vector2 = h.at
		ellipse(at + Vector2(0, 14), Vector2(26, 11), Color("1c1430"))
		var rise := 0.0
		if h.up > 0:
			rise = minf(1.0, h.up / 30.0) * 18.0
			var body := Color("ff6b6b") if h.hit else Color("a0d468")
			half_disc(at + Vector2(0, 14 - rise), 16, body)
			board.draw_rect(Rect2(at.x - 16, at.y + 14 - rise, 32, rise), body)
			board.draw_rect(Rect2(at.x - 7, at.y + 8 - rise, 3, 3), Color("102018"))
			board.draw_rect(Rect2(at.x + 4, at.y + 8 - rise, 3, 3), Color("102018"))
		if h.pop > 0:
			text("+10", Vector2(at.x, at.y - (6 + (12 - h.pop))), 18, Color(Color("ffd166"), h.pop / 12.0))


func _hud_text() -> String:
	return "SCORE %d    TIME %d" % [score, ceili(maxi(0, time) / 60.0)]

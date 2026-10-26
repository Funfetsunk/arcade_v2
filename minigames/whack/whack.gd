extends MiniGame
## Whack-It: critters pop up from a 3×3 grid; tap them before they duck. 20 s.

const COLS := 3
const ROWS := 3
const SPACING := 70.0
const GRID_TOP := 150.0
## Two moles; each pop picks one at random.
const MOLES: Array[Texture2D] = [preload("res://assets/sprites/minigames/mole_a.png"), preload("res://assets/sprites/minigames/mole_b.png")]
const MOLE_SCALE := 1.5
## Sprite rows down to the bottom of the mole's mound.
const MOLE_ROWS := 22

var holes: Array[Dictionary] = []
var time := 20 * 60
var _spawn := 0.0


func _setup() -> void:
	var left := (BOARD.x - COLS * SPACING) / 2 + SPACING / 2
	for r in ROWS:
		for c in COLS:
			holes.append({ at = Vector2(left + c * SPACING, GRID_TOP + r * SPACING), up = 0.0, hit = false, pop = 0, mole = 0 })


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
			h.mole = randi() % MOLES.size()
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
			# Only the part above the hole shows, so the mole rises out of it.
			rise = minf(1.0, h.up / 30.0)
			var tex: Texture2D = MOLES[h.mole]
			var rows := ceilf(MOLE_ROWS * rise)
			var shown := Vector2(tex.get_width(), rows) * MOLE_SCALE
			board.draw_texture_rect_region(tex, Rect2(at + Vector2(-shown.x / 2, 16 - shown.y), shown),
				Rect2(0, 0, tex.get_width(), rows), Color(1, 0.55, 0.55) if h.hit else Color.WHITE)
		if h.pop > 0:
			text("+10", Vector2(at.x, at.y - (6 + (12 - h.pop))), 18, Color(Color("ffd166"), h.pop / 12.0))


func _hud_text() -> String:
	return "SCORE %d    TIME %d" % [score, ceili(maxi(0, time) / 60.0)]

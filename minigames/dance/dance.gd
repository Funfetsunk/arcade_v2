extends MiniGame
## Dance Mat: arrows scroll up four lanes; tap a lane (or press its arrow key) as
## its arrow crosses the receptor at the top. A 25 s pattern that gets denser.

const LANES := 4
const LW := BOARD.x / LANES
const HIT_Y := 80.0
const GLYPHS := ["←", "↓", "↑", "→"]
const COLORS := [Color("ff006e"), Color("3a86ff"), Color("06d6a0"), Color("ffb703")]
const KEYS := { KEY_LEFT: 0, KEY_DOWN: 1, KEY_UP: 2, KEY_RIGHT: 3 }
const ROUND := 25 * 60

var arrows: Array[Dictionary] = []
var combo := 0
var best_combo := 0
var time := ROUND
var _spawn := 30.0
var _glow: Array[int] = [0, 0, 0, 0]


func _pointer_pressed(at: Vector2) -> void:
	_tap(mini(LANES - 1, int(at.x / LW)))


func _key(event: InputEventKey) -> void:
	if event.pressed and not event.echo and KEYS.has(event.keycode):
		_tap(KEYS[event.keycode])


func _lane_x(lane: int) -> float:
	return lane * LW + LW / 2


func _tap(lane: int) -> void:
	_glow[lane] = 8
	var best: Dictionary = {}
	var best_d := INF
	for a in arrows:
		if a.lane == lane and not a.hit and absf(a.y - HIT_Y) < best_d:
			best_d = absf(a.y - HIT_Y)
			best = a
	if not best.is_empty() and best_d < 12:
		best.hit = true
		combo += 1
		score += 15
		add_pop(Vector2(_lane_x(lane), HIT_Y + 44), "PERFECT", 26, Color("06d6a0"))
	elif not best.is_empty() and best_d < 26:
		best.hit = true
		combo += 1
		score += 8
		add_pop(Vector2(_lane_x(lane), HIT_Y + 44), "GOOD", 26, GOLD)
	else:
		combo = 0
		add_pop(Vector2(_lane_x(lane), HIT_Y + 44), "MISS", 20, Color("888888"))
	best_combo = maxi(best_combo, combo)


func _tick() -> void:
	time -= 1
	if time <= 0:
		end_round("ENCORE!", best_combo >= 8)
		return
	_spawn -= 1
	if _spawn <= 0:
		_spawn = 46 - (1.0 - float(time) / ROUND) * 20 + randf() * 10
		arrows.append({ lane = randi() % LANES, y = BOARD.y + 20, hit = false })
	for a in arrows:
		a.y -= 2.6
		if not a.hit and a.y < HIT_Y - 28:
			a.hit = true
			combo = 0
			add_pop(Vector2(_lane_x(a.lane), HIT_Y + 44), "MISS", 20, Color("888888"))
	arrows = arrows.filter(func(a: Dictionary) -> bool: return a.y > 40)
	for i in LANES:
		_glow[i] = maxi(0, _glow[i] - 1)


func _draw_board() -> void:
	for i in LANES:
		var lane := Rect2(i * LW, 0, LW, BOARD.y)
		board.draw_rect(lane, Color("11101f") if i % 2 else Color("16142a"))
		if _glow[i] > 0:
			board.draw_rect(lane, Color(1, 183 / 255.0, 3 / 255.0, _glow[i] * 0.04))
		board.draw_rect(Rect2(i * LW + 8, HIT_Y - 22, LW - 16, 44), DIM, false, 2.0)
		text(GLYPHS[i], Vector2(_lane_x(i), HIT_Y + 10), 22, Color("3a3a55"))
	for a in arrows:
		if not a.hit:
			text(GLYPHS[a.lane], Vector2(_lane_x(a.lane), a.y + 8), 22, COLORS[a.lane])
	if combo >= 3:
		text("%d COMBO" % combo, Vector2(BOARD.x / 2, 410), 12, Color("ffd166"))
	draw_pops(0.0, 9)


func _hud_text() -> String:
	return "SCORE %d    COMBO %d    TIME %d" % [score, combo, ceili(maxi(0, time) / 60.0)]

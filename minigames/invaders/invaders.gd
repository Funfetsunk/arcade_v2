extends MiniGame
## Space Defend: the alien grid marches and descends. Drag to fly; the cannon
## autofires. Clear waves before they land. 35 s.

const COLS := 6
const ROWS := 4
const AW := 36.0
const AH := 30.0
const SHIP_Y := BOARD.y - 36

var aliens: Array[Dictionary] = []
var direction := 1.0
var march_speed := 0.0
var ship_x := BOARD.x / 2
var bullets: Array[Vector2] = []
var wave := 0
var time := 35 * 60
var _fire := 0
var _stars: Array[Vector3] = []


func _setup() -> void:
	for i in 40:
		_stars.append(Vector3(randf() * BOARD.x, randf() * BOARD.y, randf() * 1.4 + 0.4))
	_new_wave()


func _new_wave() -> void:
	aliens.clear()
	for r in ROWS:
		for c in COLS:
			aliens.append({ at = Vector2(60 + c * AW, 70 + r * AH), alive = true })
	direction = 1.0
	march_speed = 0.55 + wave * 0.2
	wave += 1


func _pointer_moved(at: Vector2) -> void:
	ship_x = clampf(at.x, 14, BOARD.x - 14)


func _tick() -> void:
	time -= 1
	if time <= 0:
		end_round("EARTH SAFE!", true)
		return
	_fire -= 1
	if _fire <= 0:
		_fire = 16
		bullets.append(Vector2(ship_x, SHIP_Y - 12))
	var live := aliens.filter(func(a: Dictionary) -> bool: return a.alive)
	var edge := false
	for a: Dictionary in live:
		a.at = a.at + Vector2(direction * march_speed, 0)
		if a.at.x < 26 or a.at.x > BOARD.x - 26:
			edge = true
	if edge:
		direction *= -1
		for a: Dictionary in live:
			a.at = a.at + Vector2(direction * march_speed * 2, 12)
	for a: Dictionary in live:
		if a.at.y > SHIP_Y - 26:
			end_round("INVADED!", false)
			return
	var kept: Array[Vector2] = []
	for b in bullets:
		b.y -= 7
		if b.y < -10:
			continue
		var hit := false
		for a in aliens:
			if a.alive and absf(b.x - a.at.x) < 14 and absf(b.y - a.at.y) < 12:
				a.alive = false
				score += 10
				add_pop(a.at, "+10", 24)
				hit = true
				break
		if not hit:
			kept.append(b)
	bullets = kept
	if not aliens.any(func(a: Dictionary) -> bool: return a.alive):
		score += 50
		add_pop(Vector2(BOARD.x / 2, 200), "WAVE +50", 50)
		_new_wave()


func _draw_board() -> void:
	for s in _stars:
		board.draw_rect(Rect2(s.x, s.y, s.z, s.z), Color("39395a"))
	for a in aliens:
		if a.alive:
			glyph("👾", a.at, 20)
	var ship := PackedVector2Array([Vector2(ship_x, SHIP_Y - 12), Vector2(ship_x - 13, SHIP_Y + 8), Vector2(ship_x + 13, SHIP_Y + 8)])
	board.draw_colored_polygon(ship, Color("06d6a0"))
	for b in bullets:
		board.draw_rect(Rect2(b.x - 1.5, b.y - 6, 3, 10), Color("ffd166"))
	draw_pops()


func _hud_text() -> String:
	return "SCORE %d    WAVE %d    TIME %d" % [score, wave, ceili(maxi(0, time) / 60.0)]

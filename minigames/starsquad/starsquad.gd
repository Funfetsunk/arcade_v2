extends MiniGame
## Star Squad (unlike Space Defend's marching rows): enemies dive in curving
## waves. Drag to fly, the ship fires on its own; get clipped and it's over. 30 s.

const SHIP_Y := BOARD.y - 36
const SAUCER: Texture2D = preload("res://assets/sprites/minigames/saucer.png")
const FIGHTER: Texture2D = preload("res://assets/sprites/minigames/fighter.png")

var ship_x := BOARD.x / 2
var enemies: Array[Dictionary] = []
var bullets: Array[Vector2] = []
var stars: Array[Dictionary] = []
var wave := 0
var time := 30 * 60
var lost := false
var _wave_kills := 0
var _wave_size := 0
var _spawn := 30
var _fire := 0


func _setup() -> void:
	for i in 40:
		stars.append({ x = randf() * BOARD.x, y = randf() * BOARD.y, s = randf() * 1.4 + 0.4, v = 0.6 + randf() })


func _pointer_moved(at: Vector2) -> void:
	ship_x = clampf(at.x, 14, BOARD.x - 14)


func _spawn_wave() -> void:
	wave += 1
	_wave_kills = 0
	_wave_size = 4 + mini(3, wave)
	var cx := 60 + randf() * (BOARD.x - 120)
	var amp := 60 + randf() * 60
	var k := 0.02 + randf() * 0.015
	var phase := randf() * 6
	var vy := 1.6 + wave * 0.15
	for i in _wave_size:
		enemies.append({ t = -i * 26.0, cx = cx, amp = amp, k = k, phase = phase, vy = vy, alive = true, x = 0.0, y = -20.0 })


func _tick() -> void:
	time -= 1
	if time <= 0:
		end_round("MISSION DONE")
		return
	for s in stars:
		s.y += s.v
		if s.y > BOARD.y:
			s.y = 0.0
			s.x = randf() * BOARD.x
	_fire -= 1
	if _fire <= 0:
		_fire = 14
		bullets.append(Vector2(ship_x, SHIP_Y - 12))
	if enemies.is_empty():
		_spawn -= 1
		if _spawn <= 0:
			_spawn_wave()
			_spawn = 50
	for e in enemies:
		e.t += e.vy
		e.y = e.t
		e.x = e.cx + sin(e.t * e.k * PI + e.phase) * e.amp
		if e.alive and Vector2(e.x - ship_x, e.y - SHIP_Y).length() < 17:
			lost = true
	enemies = enemies.filter(func(e: Dictionary) -> bool: return e.alive and e.y < BOARD.y + 30)
	var kept: Array[Vector2] = []
	for b in bullets:
		b.y -= 7.5
		if b.y < -10 or _hit(b):
			continue
		kept.append(b)
	bullets = kept
	if lost:
		end_round("SHOT DOWN!", false)


## True if the bullet took out an enemy.
func _hit(b: Vector2) -> bool:
	for e in enemies:
		if e.alive and e.y > -10 and absf(b.x - e.x) < 13 and absf(b.y - e.y) < 13:
			e.alive = false
			score += 15
			_wave_kills += 1
			add_pop(Vector2(e.x, e.y), "+15", 24)
			if _wave_kills == _wave_size:
				score += 40
				add_pop(Vector2(BOARD.x / 2, 180), "SQUAD +40", 50)
			return true
	return false


func _draw_board() -> void:
	for s in stars:
		board.draw_rect(Rect2(s.x, s.y, s.s, s.s), Color("39395a"))
	for e in enemies:
		if e.alive:
			sprite(SAUCER, Vector2(e.x, e.y))
	sprite(FIGHTER, Vector2(ship_x, SHIP_Y - 2))
	for b in bullets:
		board.draw_rect(Rect2(b.x - 1.5, b.y - 6, 3, 10), Color("ffd166"))
	draw_pops(0.4, 10)


func _hud_text() -> String:
	return "SCORE %d    WAVE %d    TIME %d" % [score, wave, ceili(maxi(0, time) / 60.0)]

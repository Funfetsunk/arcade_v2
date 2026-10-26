extends MiniGame
## Barrel Hop: run up three sloped girders and tap (or Space / ↑) to jump the
## barrels the gorilla rolls down. Reaching the top is a rescue bonus. Three
## lives, 40 s.

const LX := 30.0
const RX := BOARD.x - 30
## Girder ends; each slopes down toward where its barrels roll (the player runs
## the other way): g0 runs right, g1 left, g2 right.
const GIRDERS := [Vector2(398, 386), Vector2(296, 308), Vector2(218, 206)]
const TOP_Y := 128.0
const LADDER_FRAMES := 34
const JUMP_CLEAR := -22.0
const GORILLA: Texture2D = preload("res://assets/sprites/minigames/gorilla.png")
const FRIEND: Texture2D = preload("res://assets/sprites/minigames/princess.png")
const RUNNER: Texture2D = preload("res://assets/sprites/minigames/runner.png")
const BARREL: Texture2D = preload("res://assets/sprites/minigames/barrel.png")

var lives := 3
var rescues := 0
var time := 40 * 60
var barrels: Array[Dictionary] = []
## Which girder the runner is on (3 = climbing to the top), x, jump height
## (negative is up), and frames left on the ladder.
var girder := 0
var runner_x := LX + 6
var jump_y := 0.0
var _jump_v := 0.0
var _airborne := false
var _climb := 0
var _invincible := 0
var _spawn := 70.0
var _run_speed := 1.6
var _barrel_speed := 1.9
var _throw := 0


## The girder's surface height at x.
func _gy(g: int, x: float) -> float:
	var ends: Vector2 = GIRDERS[g]
	return ends.x + (ends.y - ends.x) * ((x - LX) / (RX - LX))


func _run_dir(g: int) -> int:
	return 1 if g % 2 == 0 else -1


func _pointer_pressed(_at: Vector2) -> void:
	_jump()


func _key(event: InputEventKey) -> void:
	if event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_UP):
		_jump()


func _jump() -> void:
	if not _airborne and _climb <= 0:
		_airborne = true
		_jump_v = -5.6


func _respawn() -> void:
	girder = 0
	runner_x = LX + 6
	jump_y = 0.0
	_jump_v = 0.0
	_airborne = false
	_climb = 0
	_invincible = 100


func _tick() -> void:
	time -= 1
	if time <= 0:
		end_round("HERO!" if rescues > 0 else "TIME!")
		return
	if _invincible > 0:
		_invincible -= 1
	if _throw > 0:
		_throw -= 1
	_move_runner()
	_move_barrels()
	if lives <= 0:
		end_round("BONKED!", false)


## Run, climb the ladder at each girder's end, and rescue at the top.
func _move_runner() -> void:
	if _climb > 0:
		_climb -= 1
		if _climb == 0 and girder >= 3:
			rescues += 1
			score += 60
			add_pop(Vector2(BOARD.x / 2, TOP_Y - 20), "RESCUE! +60", 56)
			_barrel_speed = minf(3.4, _barrel_speed + 0.3)
			_run_speed = minf(2.5, _run_speed + 0.15)
			_respawn()
			_invincible = 40
		return
	var dir := _run_dir(girder)
	runner_x += dir * _run_speed
	if (dir > 0 and runner_x >= RX - 6) or (dir < 0 and runner_x <= LX + 6):
		girder += 1
		_climb = LADDER_FRAMES
		_airborne = false
		jump_y = 0.0
	if _airborne:
		_jump_v += 0.32
		jump_y += _jump_v
		if jump_y >= 0:
			jump_y = 0.0
			_jump_v = 0.0
			_airborne = false


## The gorilla rolls barrels from the top, down all three girders.
func _move_barrels() -> void:
	_spawn -= 1
	if _spawn <= 0:
		_spawn = 100 - mini(45, rescues * 9) + randf() * 55
		barrels.append({ g = 2, x = BOARD.x / 2 + 40, rot = 0.0, hopped = false })
		_throw = 20
	for b in barrels:
		# Barrels roll against the runner.
		var dir := -_run_dir(b.g)
		b.x += dir * _barrel_speed
		b.rot += dir * _barrel_speed * 0.13
		if (dir < 0 and b.x <= LX + 4) or (dir > 0 and b.x >= RX - 4):
			b.g -= 1
			b.hopped = false
		if b.g != girder or _climb > 0 or lives <= 0:
			continue
		var dx := absf(b.x - runner_x)
		if dx < 12 and jump_y > JUMP_CLEAR and _invincible <= 0:
			lives -= 1
			add_pop(Vector2(runner_x, _gy(girder, runner_x) - 56), "OUCH!", 44, Color("ff006e"))
			if lives > 0:
				_respawn()
		elif dx < 10 and jump_y <= JUMP_CLEAR and not b.hopped:
			b.hopped = true
			score += 15
			add_pop(Vector2(runner_x, _gy(girder, runner_x) - 60), "+15", 32)
	barrels = barrels.filter(func(b: Dictionary) -> bool: return b.g >= 0)


func _draw_board() -> void:
	# Girders: sloped beams with rivets.
	for g in 3:
		board.draw_line(Vector2(LX - 12, _gy(g, LX - 12)), Vector2(RX + 12, _gy(g, RX + 12)), Color("b3324f"), 8.0)
		var x := LX
		while x <= RX:
			board.draw_line(Vector2(x, _gy(g, x) - 3), Vector2(x, _gy(g, x) + 3), Color("7a1f36"), 2.0)
			x += 24
	# The top platform and its cast; the gorilla bobs as it throws.
	board.draw_line(Vector2(BOARD.x / 2 - 70, TOP_Y), Vector2(BOARD.x / 2 + 90, TOP_Y), Color("b3324f"), 8.0)
	sprite(GORILLA, Vector2(BOARD.x / 2 + 36, TOP_Y - 17 - (3 if _throw > 10 else 0)), 1.25)
	sprite(FRIEND, Vector2(BOARD.x / 2 - 44, TOP_Y - 15))
	# Ladders at the climbing ends.
	var ladder := Color("3ea0c9")
	for g in 3:
		var x := RX if _run_dir(g) > 0 else LX
		var bottom := _gy(g, x)
		var top := _gy(g + 1, x) if g < 2 else TOP_Y
		board.draw_line(Vector2(x - 7, bottom), Vector2(x - 7, top), ladder, 3.0)
		board.draw_line(Vector2(x + 7, bottom), Vector2(x + 7, top), ladder, 3.0)
		var y := top + 8
		while y < bottom - 4:
			board.draw_line(Vector2(x - 7, y), Vector2(x + 7, y), ladder, 3.0)
			y += 9
	# Barrels: rolling slatted drums.
	for b in barrels:
		sprite(BARREL, Vector2(b.x, _gy(b.g, b.x) - 11), 1.0, b.rot)
	if not (_invincible > 0 and (_invincible & 4) != 0):
		_draw_runner()
	draw_pops(0.4, 10)


## The runner: faces the way it runs, bobs as it goes, and shuffles side to
## side on a ladder.
func _draw_runner() -> void:
	var climbing := _climb > 0
	var at := Vector2(runner_x, _gy(girder, runner_x) + jump_y) if girder < 3 or not climbing else Vector2.ZERO
	if climbing:
		var x := RX if _run_dir(girder - 1) > 0 else LX
		var from := _gy(girder - 1, x)
		var to := TOP_Y if girder >= 3 else _gy(girder, x)
		at = Vector2(x, from + (to - from) * (1 - float(_climb) / LADDER_FRAMES))
	var flip := int(_climb / 6.0) % 2 == 1 if climbing else _run_dir(girder) < 0
	var bob := 0.0 if _airborne or climbing else absf(sin(runner_x * 0.45)) * 1.5
	sprite(RUNNER, at - Vector2(0, 11 + bob), 1.0, 0.0, flip)


func _hud_text() -> String:
	return "SCORE %d    LIVES %s    TIME %d" % [score, "●".repeat(maxi(0, lives)), ceili(maxi(0, time) / 60.0)]

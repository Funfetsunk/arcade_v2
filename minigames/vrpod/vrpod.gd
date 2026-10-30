extends MiniGame
## Tunnel Rush, in the VR pod: you're flying down a hyperspace tunnel. Drag left
## and right to roll round its wall (the whole tunnel turns around you, as in
## the headset). Waves rush at you: rings of mines with a gap to slip through,
## tumbling asteroids and laser beams sweeping across the tunnel. Grab the
## crystals for points and the odd star or shield. Three crashes and you're
## out; survive the 40 s run for a bonus.

const TUNNEL: Texture2D = preload("res://assets/sprites/minigames/vr_tunnel.png")
const SHIP: Texture2D = preload("res://assets/sprites/minigames/vr_ship_pink.png")
const EMITTER: Texture2D = preload("res://assets/sprites/minigames/vr_emitter.png")
const LASER: Texture2D = preload("res://assets/sprites/minigames/vr_laser.png")
const EXPLOSION: Texture2D = preload("res://assets/sprites/minigames/vr_explosion.png")
const SPARK: Texture2D = preload("res://assets/sprites/minigames/vr_spark.png")
const SHIELD: Texture2D = preload("res://assets/sprites/minigames/vr_shield.png")

## What can come down the tunnel: its art, how wide it is (radians at your
## ring), and what touching it does.
const THINGS := {
	&"mine": { art = preload("res://assets/sprites/minigames/vr_mine.png"), width = 0.2, bad = true },
	&"rock": { art = preload("res://assets/sprites/minigames/vr_asteroid.png"), width = 0.24, bad = true },
	&"crystal": { art = preload("res://assets/sprites/minigames/vr_crystal.png"), width = 0.2, pays = 10 },
	&"star": { art = preload("res://assets/sprites/minigames/vr_star.png"), width = 0.2, pays = 50 },
	&"shield": { art = preload("res://assets/sprites/minigames/vr_shield.png"), width = 0.2, pays = 0 },
}

const RUN := 40 * 60
const SHIELDS := 3
const FINISH_BONUS := 100
## The vanishing point, and the ring your ship flies round.
const CENTER := Vector2(BOARD.x / 2, 228)
const ORBIT := 150.0
## Your ship is always drawn at the bottom of the ring; the tunnel rolls.
const SHIP_AT := CENTER + Vector2(0, ORBIT)
const SHIP_WIDTH := 0.12
const ROLL := 0.013
const KEY_ROLL := 0.07
## A laser blocks this far either side of its line.
const LASER_WIDTH := 0.13

## Each thing: kind, its angle round the tunnel, how near it is (0 at the
## vanishing point, 1 at your ring) and whether it's been passed. A laser has
## an angle for its line and a spin.
var things: Array[Dictionary] = []
var lasers: Array[Dictionary] = []
var roll := PI / 2
var shields := SHIELDS
var time := RUN
var streak := 0
var _speed := 0.011
var _wave := 50
var _drag_x := -1.0
var _hurt := 0
var _t := 0.0
var _effects: Array[Dictionary] = []


## The point on screen for an angle round the tunnel at a depth.
func at_depth(angle: float, z: float) -> Vector2:
	return CENTER + Vector2.from_angle(angle - roll + PI / 2) * radius(z)


func radius(z: float) -> float:
	return 6.0 + (ORBIT - 6.0) * z * z


func _pointer_pressed(at: Vector2) -> void:
	_drag_x = at.x


func _pointer_moved(at: Vector2) -> void:
	if _drag_x >= 0:
		roll -= (at.x - _drag_x) * ROLL
		_drag_x = at.x


func _pointer_released(_at: Vector2) -> void:
	_drag_x = -1.0


func _key(event: InputEventKey) -> void:
	if event.pressed and event.keycode == KEY_LEFT:
		roll += KEY_ROLL * 3
	elif event.pressed and event.keycode == KEY_RIGHT:
		roll -= KEY_ROLL * 3


func _tick() -> void:
	time -= 1
	if time <= 0:
		score += FINISH_BONUS
		add_pop(CENTER, "RUN COMPLETE +%d" % FINISH_BONUS, 60, GOLD)
		end_round("RUN COMPLETE", true)
		return
	var pace := 1.0 - float(time) / RUN
	_speed = lerpf(0.011, 0.018, pace)
	_t += _speed
	_hurt = maxi(0, _hurt - 1)
	# A point for every bit of tunnel flown.
	if posmod(time, 10) == 0:
		score += 1
	if Input.is_key_pressed(KEY_LEFT):
		roll += KEY_ROLL * 0.3
	if Input.is_key_pressed(KEY_RIGHT):
		roll -= KEY_ROLL * 0.3
	_wave -= 1
	if _wave <= 0:
		_wave = int(lerpf(70, 40, pace))
		_spawn_wave(pace)
	for th in things.duplicate():
		var was: float = th.z
		th.z += _speed * (0.6 + th.z)
		if was < 1.0 and th.z >= 1.0:
			_reach(th)
		if th.z > 1.6 or th.get("gone", false):
			things.erase(th)
	for laser in lasers.duplicate():
		var was: float = laser.z
		laser.z += _speed * (0.6 + laser.z)
		laser.angle += laser.spin
		if was < 1.0 and laser.z >= 1.0:
			if _off(laser.angle) < LASER_WIDTH or _off(laser.angle + PI) < LASER_WIDTH:
				_crash()
			else:
				Sfx.play(&"vr_whoosh")
		if laser.z > 1.6:
			lasers.erase(laser)
	for e in _effects.duplicate():
		e.t -= 1
		if e.t <= 0:
			_effects.erase(e)


## How far an angle round the tunnel is from your ship.
func _off(angle: float) -> float:
	return absf(angle_difference(angle, roll))


func _spawn_wave(pace: float) -> void:
	var pick := randf()
	if pick < 0.4:
		# A ring of mines with a gap, a crystal waiting in it.
		var n := 8 + int(pace * 3)
		var gap := randi() % n
		var start := randf() * TAU
		for i in n:
			var a := start + TAU * i / n
			if i == gap or (pace > 0.5 and i == (gap + 1) % n and randf() < 0.3):
				continue
			things.append({ kind = &"mine", angle = a, z = 0.0 })
		things.append({ kind = &"crystal", angle = start + TAU * gap / n, z = 0.0 })
	elif pick < 0.62:
		for i in 3 + int(pace * 3):
			things.append({ kind = &"rock", angle = randf() * TAU, z = -randf() * 0.15 })
	elif pick < 0.82:
		lasers.append({ angle = randf() * TAU, z = 0.0, spin = randf_range(-0.012, 0.012) * (1.0 + pace) })
	else:
		# A spiral of crystals to follow round.
		var a := randf() * TAU
		var turn := 0.25 if randf() < 0.5 else -0.25
		for i in 6:
			things.append({ kind = &"crystal", angle = a + turn * i, z = -i * 0.06 })
	if randf() < 0.12:
		things.append({ kind = &"star", angle = randf() * TAU, z = -0.3 })
	elif shields < SHIELDS and randf() < 0.06:
		things.append({ kind = &"shield", angle = randf() * TAU, z = -0.3 })


func _reach(th: Dictionary) -> void:
	var info: Dictionary = THINGS[th.kind]
	if _off(th.angle) > info.width + SHIP_WIDTH:
		if info.get("bad", false):
			Sfx.play(&"vr_whoosh")
		return
	if info.get("bad", false):
		_crash()
		th.gone = true
		return
	th.gone = true
	_effects.append({ art = SPARK, at = SHIP_AT - Vector2(0, 20), t = 14 })
	match th.kind:
		&"shield":
			shields = mini(SHIELDS, shields + 1)
			Sfx.play(&"vr_shield")
			add_pop(SHIP_AT - Vector2(0, 50), "SHIELD +1", 40, GREEN)
		&"star":
			score += info.pays
			Sfx.play(&"vr_star")
			add_pop(SHIP_AT - Vector2(0, 50), "+%d" % info.pays, 40, GOLD)
		_:
			streak += 1
			var points: int = info.pays * mini(1 + floori(streak / 5.0), 4)
			score += points
			Sfx.play(&"vr_crystal")
			add_pop(SHIP_AT - Vector2(0, 50), "+%d" % points, 30, CREAM)


func _crash() -> void:
	if _hurt > 0:
		return
	shields -= 1
	streak = 0
	_hurt = 60
	Sfx.play(&"vr_crash")
	_effects.append({ art = EXPLOSION, at = SHIP_AT, t = 24 })
	if shields <= 0:
		end_round("POD DOWN!", score >= star_scores[0])


func _draw_board() -> void:
	_draw_tunnel()
	var order: Array = things.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.z < b.z)
	for laser in lasers:
		if laser.z > 0:
			_draw_laser(laser)
	for th: Dictionary in order:
		if th.z <= 0 or th.get("gone", false):
			continue
		var info: Dictionary = THINGS[th.kind]
		var zoom: float = 0.15 + 1.25 * th.z * th.z
		sprite(info.art, at_depth(th.angle, th.z), zoom, _t * 3.0 if th.kind == &"rock" else 0.0, false, Color(1, 1, 1, clampf(th.z * 4.0, 0, 1)))
	if not (over and shields <= 0):
		var blink := _hurt > 0 and posmod(_hurt, 8) < 4
		sprite(SHIP, SHIP_AT, 1.4, 0.0, false, Color(1, 0.4, 0.5, 0.6) if blink else Color.WHITE)
	for e in _effects:
		sprite(e.art, e.at, 1.6 * (1.2 - e.t / 40.0), 0.0, false, Color(1, 1, 1, clampf(e.t / 8.0, 0, 1)))
	for i in SHIELDS:
		sprite(SHIELD, Vector2(22 + i * 26, 22), 0.55, 0.0, false, Color.WHITE if i < shields else Color(1, 1, 1, 0.2))
	draw_pops(0.5, 16)


## The tunnel, rolled to match you and rushing past: two copies zooming out
## from the vanishing point, one fading in as the other fades out.
func _draw_tunnel() -> void:
	board.draw_rect(Rect2(Vector2.ZERO, BOARD), BG)
	for layer in 2:
		var k := fposmod(_t * 0.6 + layer * 0.5, 1.0)
		var zoom := 2.0 * (1.7 + 1.7 * k)
		var fade := sin(k * PI)
		board.draw_set_transform(CENTER, -roll + PI / 2, Vector2(zoom, zoom))
		board.draw_texture(TUNNEL, -Vector2(90, 116), Color(1, 1, 1, fade))
	board.draw_set_transform(Vector2.ZERO)


## A laser beam right across the tunnel, an emitter at each end.
func _draw_laser(laser: Dictionary) -> void:
	var r := radius(laser.z)
	var turn: float = laser.angle - roll + PI / 2
	var zoom: float = 0.15 + 1.25 * laser.z * laser.z
	board.draw_set_transform(CENTER, turn, Vector2.ONE)
	board.draw_texture_rect(LASER, Rect2(-r, -LASER.get_height() * zoom / 2.0, 2 * r, LASER.get_height() * zoom), false, Color(1, 1, 1, clampf(laser.z * 4.0, 0, 1)))
	board.draw_set_transform(Vector2.ZERO)
	for side in [0.0, PI]:
		sprite(EMITTER, CENTER + Vector2.from_angle(turn + side) * r, zoom, turn + side + PI / 2)


func _hud_text() -> String:
	return "SCORE %d    TIME %d" % [score, ceili(maxi(0, time) / 60.0)]

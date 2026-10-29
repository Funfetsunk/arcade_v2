extends MiniGame
## Pro Hoops, a real arcade basketball cage: grab the ball and flick it up at
## the hoop. How fast you flick sets how far it flies, and which way you flick
## aims it. Balls bounce off the rim and the backboard, drop through the net and
## roll back down the ramp to you. Three in a row and you're ON FIRE, every
## fifth ball is a gold money ball, the hoop starts moving after 15 seconds and
## the last 10 seconds score double. 45 s.
##
## The cage is simulated in 3D (x across, y up, z away from you) and drawn in
## perspective; world units are board pixels at your end of the cage.

const BACKDROP: Texture2D = preload("res://assets/sprites/minigames/hoop_backdrop.png")
const BACKBOARD: Texture2D = preload("res://assets/sprites/minigames/hoop_board.png")
## The net and the front of the rim alone, drawn over a ball dropping through.
const NET: Texture2D = preload("res://assets/sprites/minigames/hoop_net.png")
const BALL: Texture2D = preload("res://assets/sprites/minigames/hoop_ball.png")
const BALL_FIRE: Texture2D = preload("res://assets/sprites/minigames/hoop_ball_fire.png")
const BALL_GOLD: Texture2D = preload("res://assets/sprites/minigames/hoop_ball_gold.png")

const TIME := 45 * 60
const MOVING_AFTER := 15 * 60
const DOUBLE_LAST := 10 * 60
## Perspective: how quickly things shrink with distance, where the far end
## vanishes and how high your eye is.
const FOCAL := 300.0
const VP_Y := 177.0
const EYE := 223.0
const FLOOR := -60.0
const GRAVITY := 0.42
const BALL_R := 40.0
const RIM_Z := 300.0
const RIM_H := 277.0
const RIM_R := 84.0
## Thickness of the rim's metal.
const RIM_TUBE := 4.0
const BACK_Z := RIM_Z + RIM_R + 20.0
const SIDE := 200.0
## How far the hoop slides either way once it starts moving.
const SLIDE := 90.0
const LAUNCH_ANGLE := deg_to_rad(72.0)
## A flick this fast (board pixels a frame) is the right power.
const FLICK := 16.0
## How much of the power and the aim is nudged towards a perfect shot.
const POWER_HELP := 0.45
const AIM_HELP := 0.3
const HAND := Vector2(BOARD.x / 2, 400)
const GRAB_R := 70.0
const BALLS := 4
const RELOAD := 12
const BALL_ART := 36.0
## Where the rim sits in the backboard art, from its centre, at 2x.
const RIM_IN_ART := Vector2(0, 19)
const RACK_AT := [Vector2(40, 436), Vector2(320, 436), Vector2(76, 444), Vector2(284, 444)]

enum Where { RACK, HAND, AIR }

## Each ball: where it is, its speed, whether it's gone in or touched the rim
## or board on this shot, and whether it's a fire or money ball.
var balls: Array[Dictionary] = []
var time := TIME
var streak := 0
var shots := 0
var hoop_x := 0.0
var _slide := 0.0
var _reload := 0
var _grab := false
## Where the finger is, and where the held ball is drawn (kept near the bottom).
var _finger := HAND
var _held_at := HAND
var _trail: Array[Vector2] = []
var _swish_t := 0
var _clank_t := 0


func _setup() -> void:
	for i in BALLS:
		balls.append({ where = Where.RACK, p = Vector3.ZERO, v = Vector3.ZERO, scored = false, touched = false, landed = false, kind = &"" })
	balls[0].where = Where.HAND


func held() -> Dictionary:
	for b in balls:
		if b.where == Where.HAND:
			return b
	return {}


func to_screen(p: Vector3) -> Vector2:
	var s := scale_at(p.z)
	return Vector2(BOARD.x / 2 + p.x * s, VP_Y + (EYE - p.y) * s)


func scale_at(z: float) -> float:
	return FOCAL / (FOCAL + maxf(z, -FOCAL * 0.5))


func rim() -> Vector3:
	return Vector3(hoop_x, RIM_H, RIM_Z)


func _pointer_pressed(at: Vector2) -> void:
	if not held().is_empty() and at.distance_to(HAND) < GRAB_R:
		_grab = true
		_finger = at
		_held_at = at
		_trail = [at]


func _pointer_moved(at: Vector2) -> void:
	if _grab:
		_finger = at
		_held_at = Vector2(clampf(at.x, 40, BOARD.x - 40), clampf(at.y, 330, 430))


func _pointer_released(_at: Vector2) -> void:
	if not _grab:
		return
	_grab = false
	var b := held()
	if b.is_empty() or _trail.size() < 2:
		return
	var span := mini(5, _trail.size() - 1)
	var flick := (_trail[-1] - _trail[-1 - span]) / span
	if -flick.y < 3.0:
		return
	shoot(b, _held_at, -flick.y / FLICK, flick.x / -flick.y)


## Throws a ball from a point on screen: power 1 is a perfect flick, aim is
## sideways over up (0 is straight up the cage).
func shoot(b: Dictionary, from: Vector2, power: float, aim: float) -> void:
	var start := Vector3(from.x - BOARD.x / 2, EYE - (from.y - VP_Y), 0)
	var ideal := _ideal_speed(RIM_H - start.y, RIM_Z)
	var speed := lerpf(ideal * clampf(power, 0.2, 2.5), ideal, POWER_HELP)
	var forward := speed * cos(LAUNCH_ANGLE)
	var flight := RIM_Z / forward
	var across := lerpf(aim * forward, (hoop_x - start.x) / flight, AIM_HELP)
	shots += 1
	b.where = Where.AIR
	b.p = start
	b.v = Vector3(across, speed * sin(LAUNCH_ANGLE), forward)
	b.scored = false
	b.touched = false
	b.landed = false
	b.kind = &"gold" if shots % 5 == 0 else (&"fire" if streak >= 3 else &"")
	_reload = RELOAD


## The launch speed that drops a ball through the rim, from below it by
## height h and short of it by distance d.
func _ideal_speed(h: float, d: float) -> float:
	var c := cos(LAUNCH_ANGLE)
	return sqrt(GRAVITY * d * d / (2.0 * c * c * (d * tan(LAUNCH_ANGLE) - h)))


func _tick() -> void:
	time -= 1
	if time <= 0:
		Sfx.play(&"hp_buzzer")
		end_round("BUZZER!", score >= star_scores[0])
		return
	if TIME - time > MOVING_AFTER:
		_slide += 0.012 + 0.012 * float(TIME - time - MOVING_AFTER) / (TIME - MOVING_AFTER)
		hoop_x = sin(_slide) * SLIDE
	if _grab:
		_trail.append(_finger)
		if _trail.size() > 8:
			_trail.pop_front()
	_swish_t = maxi(0, _swish_t - 1)
	_clank_t = maxi(0, _clank_t - 1)
	_reload = maxi(0, _reload - 1)
	if held().is_empty() and _reload == 0:
		for b in balls:
			if b.where == Where.RACK:
				b.where = Where.HAND
				break
	for b in balls:
		if b.where == Where.AIR:
			for step in 2:
				_move(b, 0.5)


func _move(b: Dictionary, dt: float) -> void:
	var was: Vector3 = b.p
	b.v.y -= GRAVITY * dt
	b.p += b.v * dt
	var c := rim()
	var flat := Vector2(b.p.x - c.x, b.p.z - c.z)
	# Through the hoop: the ball's centre falls past the rim inside it.
	if not b.scored and was.y > RIM_H and b.p.y <= RIM_H and flat.length() < RIM_R:
		_score(b)
	# The rim is a ring: bounce off its nearest point.
	if flat.length() > 0.01:
		var ring := c + Vector3(flat.normalized().x * RIM_R, 0, flat.normalized().y * RIM_R)
		var off: Vector3 = b.p - ring
		if off.length() < BALL_R + RIM_TUBE:
			var n := off.normalized()
			b.p = ring + n * (BALL_R + RIM_TUBE)
			var into: float = b.v.dot(n)
			if into < 0:
				b.v -= 1.55 * into * n
				b.v *= 0.9
				b.touched = true
				if _clank_t == 0 and -into > 1.0:
					Sfx.play(&"hp_rim")
					_clank_t = 8
	# The net slows a ball that's gone in and steers it down the middle.
	if b.scored and b.p.y > RIM_H - 100 and b.p.y < RIM_H:
		b.v.x = lerpf(b.v.x, (c.x - b.p.x) * 0.1, 0.2)
		b.v.z = lerpf(b.v.z, (c.z - b.p.z) * 0.1, 0.2)
		b.v.y = maxf(b.v.y, -4.0)
	if b.p.z > BACK_Z - BALL_R and b.v.z > 0:
		b.p.z = BACK_Z - BALL_R
		b.v.z *= -0.45
		b.v.x *= 0.8
		b.touched = true
		Sfx.play(&"hp_board")
	if absf(b.p.x) > SIDE - BALL_R:
		b.p.x = signf(b.p.x) * (SIDE - BALL_R)
		b.v.x *= -0.6
	if b.p.y < FLOOR + BALL_R:
		b.p.y = FLOOR + BALL_R
		if b.v.y < -2.0:
			Sfx.play(&"hp_bounce")
		b.v.y = -b.v.y * 0.45 if b.v.y < -1.5 else 0.0
		b.v.x *= 0.96
		if not b.landed:
			b.landed = true
			if not b.scored:
				streak = 0
				miss(to_screen(Vector3(b.p.x, RIM_H - 60, RIM_Z)), 24)
	# The ramp slopes down to you, so balls on the floor roll back.
	if b.landed:
		b.v.z = maxf(b.v.z - 0.18 * dt, -9.0)
	if b.p.z < -30:
		b.where = Where.RACK


func _score(b: Dictionary) -> void:
	b.scored = true
	streak += 1
	var points := 3 if b.kind == &"fire" else 2
	if not b.touched:
		points += 1
	if b.kind == &"gold":
		points *= 2
	if time <= DOUBLE_LAST:
		points *= 2
	score += points
	_swish_t = 24
	var at := to_screen(rim())
	Sfx.play(&"hp_swish")
	if streak == 3:
		Sfx.play(&"hp_fire")
		add_pop(at + Vector2(0, 150), "ON FIRE!", 50, Color("ff7b00"))
	# Below the net, where the crowd is dark enough to read it.
	add_pop(at + Vector2(0, 120), ("SWISH! +%d" if not b.touched else "+%d") % points, 36)


func _draw_board() -> void:
	board.draw_texture_rect(BACKDROP, Rect2(Vector2.ZERO, BOARD), false)
	var hoop := to_screen(rim())
	sprite(BACKBOARD, hoop - RIM_IN_ART, 2.0)
	var order := balls.filter(func(b: Dictionary) -> bool: return b.where == Where.AIR)
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.p.z > b.p.z)
	# Balls past the front of the rim go behind the net.
	for b: Dictionary in order:
		if b.p.z >= RIM_Z - RIM_R * 0.6:
			_draw_ball(b)
	var stretch := 1.0 + 0.18 * sin(_swish_t * 0.5) * _swish_t / 24.0
	# Stretched down from the rim when a ball swishes through.
	board.draw_set_transform(hoop, 0.0, Vector2(2.0, 2.0 * stretch))
	board.draw_texture(NET, -NET.get_size() / 2.0 - RIM_IN_ART / 2.0)
	board.draw_set_transform(Vector2.ZERO)
	for b: Dictionary in order:
		if b.p.z < RIM_Z - RIM_R * 0.6:
			_draw_ball(b)
	for i in balls.filter(func(b: Dictionary) -> bool: return b.where == Where.RACK).size():
		sprite(BALL, RACK_AT[i], 1.0)
	var next_ball := held()
	if not next_ball.is_empty() and not over:
		var at := _held_at if _grab else HAND
		_draw_ball_at(next_ball, at, 2.0 * BALL_R / BALL_ART)
		if not _grab and stage == Stage.PLAYING and shots == 0:
			text("flick the ball up!", Vector2(BOARD.x / 2, 452), 10, CREAM)
	if time <= DOUBLE_LAST and not over and posmod(time, 30) < 15:
		text("DOUBLE POINTS!", Vector2(BOARD.x / 2, 300), 16, GOLD)
	draw_pops(0.5, 16)


func _draw_ball(b: Dictionary) -> void:
	_draw_ball_at(b, to_screen(b.p), 2.0 * BALL_R * scale_at(b.p.z) / BALL_ART)


func _draw_ball_at(b: Dictionary, at: Vector2, zoom: float) -> void:
	if b.kind == &"fire" or (b.where == Where.HAND and streak >= 3 and (shots + 1) % 5 != 0):
		sprite(BALL_FIRE, at + Vector2(0, -2 * zoom), zoom)
	elif b.kind == &"gold" or (b.where == Where.HAND and (shots + 1) % 5 == 0):
		sprite(BALL_GOLD, at, zoom)
	else:
		sprite(BALL, at, zoom)


func _hud_text() -> String:
	return "SCORE %d    STREAK %d    TIME %d" % [score, streak, ceili(maxi(0, time) / 60.0)]

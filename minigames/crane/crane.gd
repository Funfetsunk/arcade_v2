extends MiniGame
## Prize Crane, a UFO catcher: two moves, once each, as on the real thing. Hold
## to send the crane right and let go to stop it; hold again to send it back
## into the machine and let go, and the claw drops. It closes on whatever's
## under it, lifts, and carries it home to the prize chute (if it doesn't slip
## out on the way). A missed grab still nudges the prizes about, and anything
## pushed into the chute is yours. Five goes.
##
## The prize pit is drawn in perspective: x across, d from the back wall (0)
## to the front glass (DEPTH).

const BACKDROP: Texture2D = preload("res://assets/sprites/minigames/ufo_backdrop.png")
const CLAW_OPEN: Texture2D = preload("res://assets/sprites/minigames/ufo_claw_open.png")
const CLAW_SHUT: Texture2D = preload("res://assets/sprites/minigames/ufo_claw_closed.png")
const CARRIAGE: Texture2D = preload("res://assets/sprites/minigames/ufo_carriage.png")
const CHAIN: Texture2D = preload("res://assets/sprites/minigames/claw_chain.png")
const CHUTE: Texture2D = preload("res://assets/sprites/minigames/ufo_chute.png")
const SHADOW: Texture2D = preload("res://assets/sprites/minigames/ufo_shadow.png")
const BTN_RIGHT: Texture2D = preload("res://assets/sprites/minigames/ufo_btn_right.png")
const BTN_BACK: Texture2D = preload("res://assets/sprites/minigames/ufo_btn_up.png")

## The prizes: art, size on the pit floor, how well the claw holds them and
## what they're worth.
const PRIZES := {
	&"red": { art = preload("res://assets/sprites/minigames/ufo_cap_red.png"), r = 20.0, grip = 0.85, pays = 30 },
	&"blue": { art = preload("res://assets/sprites/minigames/ufo_cap_blue.png"), r = 20.0, grip = 0.85, pays = 30 },
	&"green": { art = preload("res://assets/sprites/minigames/ufo_cap_green.png"), r = 20.0, grip = 0.85, pays = 30 },
	&"purple": { art = preload("res://assets/sprites/minigames/ufo_cap_purple.png"), r = 20.0, grip = 0.85, pays = 30 },
	&"rainbow": { art = preload("res://assets/sprites/minigames/ufo_cap_rainbow.png"), r = 20.0, grip = 0.7, pays = 60 },
	&"gold": { art = preload("res://assets/sprites/minigames/ufo_cap_gold.png"), r = 20.0, grip = 0.55, pays = 100, zoom = 0.82 },
	&"robot": { art = preload("res://assets/sprites/minigames/ufo_box_robot.png"), r = 24.0, grip = 0.5, pays = 80 },
	&"whale": { art = preload("res://assets/sprites/minigames/ufo_whale.png"), r = 32.0, grip = 0.4, pays = 150 },
}
const LINEUP: Array[StringName] = [&"red", &"red", &"blue", &"blue", &"green", &"green", &"purple", &"purple", &"rainbow", &"gold", &"robot", &"whale"]

const SIDE := 165.0
const DEPTH := 200.0
## Where the pit floor and the ceiling rail sit on screen at the back and the
## front, and how much smaller things are at the back.
const FLOOR_Y := Vector2(300, 440)
const CEILING_Y := Vector2(105, 18)
const FAR := 0.65
## The prize chute, in the front left corner.
const CHUTE_AREA := Rect2(-SIDE, 150, 70, 50)
const HOME := Vector2(-130, 175)
const MOVE_X := 2.0
const MOVE_D := 1.5
const RETURN_SPEED := 2.6
## How close the claw must close to a prize to take it.
const REACH := 30.0
const DROP_FRAMES := 40
const RISE_FRAMES := 36
const GOES := 5
## Dark enough to read over the pink machine.
const INK := Color(0.22, 0.04, 0.3)

enum Phase { MOVE_X, MOVE_D, DROP, GRAB, RISE, RETURN, RELEASE }

var prizes: Array[Dictionary] = []
var phase := Phase.MOVE_X
var claw := HOME
## 0 hanging up at the rail, 1 down on the floor.
var lower := 0.0
var goes := GOES
var held: Dictionary = {}
var _hold := false
var _moved := false
var _t := 0
var _motor_t := 0
var _slip_at := 2.0
var _trip := 0.0
var _won: Array[Dictionary] = []


func _setup() -> void:
	# Biggest first, so there's always room for them.
	var lineup := LINEUP.duplicate()
	lineup.sort_custom(func(a: StringName, b: StringName) -> bool: return PRIZES[a].r > PRIZES[b].r)
	for kind: StringName in lineup:
		var r: float = PRIZES[kind].r
		for attempt in 40:
			var at := Vector2(randf_range(-SIDE + r, SIDE - r), randf_range(r + 10, DEPTH - r))
			if CHUTE_AREA.grow(r + 12).has_point(at):
				continue
			if prizes.all(func(p: Dictionary) -> bool: return p.at.distance_to(at) > p.r + r):
				prizes.append({ kind = kind, at = at, r = r, h = 0.0, vh = 0.0 })
				break


func scale_at(d: float) -> float:
	return lerpf(FAR, 1.0, d / DEPTH)


func floor_point(at: Vector2, h := 0.0) -> Vector2:
	var k := d_frac(at.y)
	return Vector2(BOARD.x / 2 + at.x * scale_at(at.y), lerpf(FLOOR_Y.x, FLOOR_Y.y, k) - h * scale_at(at.y))


func d_frac(d: float) -> float:
	return clampf(d / DEPTH, 0.0, 1.0)


func _pointer_pressed(_at: Vector2) -> void:
	if phase == Phase.MOVE_X or phase == Phase.MOVE_D:
		_hold = true


func _pointer_released(_at: Vector2) -> void:
	if not _hold:
		return
	_hold = false
	if phase == Phase.MOVE_X and _moved:
		phase = Phase.MOVE_D
		_moved = false
	elif phase == Phase.MOVE_D and _moved:
		phase = Phase.DROP
		_t = 0
		Sfx.play(&"cr_drop")


func _tick() -> void:
	_motor_t = maxi(0, _motor_t - 1)
	match phase:
		Phase.MOVE_X when _hold:
			_drive(Vector2(MOVE_X, 0))
		Phase.MOVE_D when _hold:
			_drive(Vector2(0, -MOVE_D))
		Phase.DROP:
			_t += 1
			lower = float(_t) / DROP_FRAMES
			if _t >= DROP_FRAMES:
				phase = Phase.GRAB
				_t = 0
		Phase.GRAB:
			_t += 1
			if _t == 8:
				_grab()
			if _t >= 16:
				phase = Phase.RISE
				_t = 0
		Phase.RISE:
			_t += 1
			lower = 1.0 - float(_t) / RISE_FRAMES
			if _t >= RISE_FRAMES:
				lower = 0.0
				phase = Phase.RETURN
				_trip = claw.distance_to(HOME)
		Phase.RETURN:
			claw = claw.move_toward(HOME, RETURN_SPEED)
			if _motor_t == 0:
				Sfx.play(&"cr_motor")
				_motor_t = 8
			if not held.is_empty() and _trip > 0 and 1.0 - claw.distance_to(HOME) / _trip >= _slip_at:
				_drop_held()
			if claw == HOME:
				phase = Phase.RELEASE
				_t = 0
				_drop_held()
		Phase.RELEASE:
			_t += 1
			if _t >= 30:
				_next_go()
	_settle()
	for w in _won.duplicate():
		w.t -= 1
		if w.t <= 0:
			_won.erase(w)


func _drive(step: Vector2) -> void:
	var to := Vector2(clampf(claw.x + step.x, -SIDE + 20, SIDE - 20), clampf(claw.y + step.y, 20, DEPTH - 20))
	if to != claw:
		_moved = true
		claw = to
		if _motor_t == 0:
			Sfx.play(&"cr_motor")
			_motor_t = 8


## The claw closes: it takes the nearest prize it's over, or knocks the ones
## around it aside.
func _grab() -> void:
	Sfx.play(&"cr_clack")
	var target: Dictionary = {}
	var near := INF
	for p in prizes:
		var d: float = p.at.distance_to(claw)
		if d < maxf(REACH, p.r) and d < near:
			near = d
			target = p
	if not target.is_empty():
		var info: Dictionary = PRIZES[target.kind]
		var centred: float = 1.0 - near / (REACH + target.r * 0.5)
		if randf() < info.grip * sqrt(clampf(centred, 0.0, 1.0)):
			held = target
			prizes.erase(target)
			# Whether (and where) it slips out on the way home is settled now.
			var slip_chance: float = (1.0 - info.grip) * 0.6 + (1.0 - centred) * 0.3
			_slip_at = randf() if randf() < slip_chance else 2.0
			return
	for p in prizes:
		var off: Vector2 = p.at - claw
		var room: float = REACH + p.r + 6
		if off.length() < room:
			p.at += (off.normalized() if off.length() > 0.1 else Vector2.RIGHT.rotated(randf() * TAU)) * (room - off.length()) * 0.8


func _drop_held() -> void:
	if held.is_empty():
		return
	held.at = claw
	held.h = _claw_height()
	held.vh = 0.0
	prizes.append(held)
	held = {}


## How high the bottom of the claw is above the pit floor (world units).
func _claw_height() -> float:
	var top := (lerpf(FLOOR_Y.x, FLOOR_Y.y, d_frac(claw.y)) - lerpf(CEILING_Y.x, CEILING_Y.y, d_frac(claw.y))) / scale_at(claw.y)
	return (top - 70.0) * (1.0 - lower)


## Prizes fall, push each other apart, stay inside the glass, and drop into
## the chute.
func _settle() -> void:
	for p in prizes:
		if p.h > 0:
			p.vh -= 0.6
			p.h = maxf(0.0, p.h + p.vh)
	for pass_i in 3:
		for i in prizes.size():
			for j in range(i + 1, prizes.size()):
				var a := prizes[i]
				var b := prizes[j]
				if a.h > 0 or b.h > 0:
					continue
				var off: Vector2 = b.at - a.at
				var room: float = a.r + b.r
				if off.length() < room:
					var push := (off.normalized() if off.length() > 0.1 else Vector2.RIGHT) * (room - off.length()) * 0.5
					a.at -= push
					b.at += push
		for p in prizes:
			p.at = Vector2(clampf(p.at.x, -SIDE + p.r, SIDE - p.r), clampf(p.at.y, p.r, DEPTH - p.r * 0.5))
	for p in prizes.duplicate():
		if p.h <= 0 and CHUTE_AREA.has_point(p.at):
			prizes.erase(p)
			var pays: int = PRIZES[p.kind].pays
			score += pays
			Sfx.play(&"cr_prize")
			add_pop(floor_point(p.at) - Vector2(0, 60), "+%d" % pays, 50, GOLD)
			_won.append({ kind = p.kind, at = p.at, t = 20 })


func _next_go() -> void:
	goes -= 1
	if goes <= 0 or prizes.is_empty():
		end_round("PRIZES WON!" if score > 0 else "NO LUCK", score >= star_scores[0])
		return
	phase = Phase.MOVE_X
	_moved = false


func _draw_board() -> void:
	board.draw_texture_rect(BACKDROP, Rect2(Vector2.ZERO, BOARD), false)
	_flat(CHUTE, Vector2(CHUTE_AREA.get_center().x, CHUTE_AREA.get_center().y), CHUTE_AREA.size.x / CHUTE.get_width())
	if phase != Phase.RELEASE:
		_flat(SHADOW, claw, 36.0 / SHADOW.get_width(), Color(1, 1, 1, 0.35))
	for w in _won:
		var info: Dictionary = PRIZES[w.kind]
		# Sinking into the chute.
		var k: float = w.t / 20.0
		_draw_prize_at(info, floor_point(w.at, -(1.0 - k) * 30.0), k)
	# Back to front, the claw among the prizes at its depth.
	var order: Array = prizes.duplicate()
	order.append({ claw = true, at = claw })
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.at.y < b.at.y)
	for item: Dictionary in order:
		if item.has("claw"):
			_draw_claw()
		else:
			_draw_prize_at(PRIZES[item.kind], floor_point(item.at, item.h), 1.0, scale_at(item.at.y))
	_draw_buttons()
	draw_pops(0.5, 16)


## A flat thing lying on the pit floor, squashed by the perspective.
func _flat(art: Texture2D, at: Vector2, zoom: float, color := Color.WHITE) -> void:
	var k := scale_at(at.y) * zoom
	board.draw_set_transform(floor_point(at), 0.0, Vector2(k, k * 0.45))
	board.draw_texture(art, -art.get_size() / 2.0, color)
	board.draw_set_transform(Vector2.ZERO)


## A prize standing on the floor at a screen point (its bottom there).
func _draw_prize_at(info: Dictionary, base: Vector2, fade := 1.0, depth_scale := 1.0) -> void:
	var art: Texture2D = info.art
	var zoom: float = 2.0 * info.r / art.get_width() * info.get("zoom", 1.0) * 1.25 * depth_scale
	sprite(art, base - Vector2(0, art.get_height() * zoom / 2.0), zoom, 0.0, false, Color(1, 1, 1, fade))


func _draw_claw() -> void:
	var s := scale_at(claw.y)
	var rail := Vector2(floor_point(claw).x, lerpf(CEILING_Y.x, CEILING_Y.y, d_frac(claw.y)))
	var zoom := 1.4 * s
	var tips := floor_point(claw, _claw_height())
	var centre := tips - Vector2(0, CLAW_OPEN.get_height() * zoom / 2.0)
	# The cable, link by link, from the carriage down to the claw's rope.
	var top := centre.y - CLAW_OPEN.get_height() * zoom / 2.0
	var link := CHAIN.get_height() * s
	var y := rail.y + 10
	while y < top:
		sprite(CHAIN, Vector2(rail.x, y), s)
		y += link
	if not held.is_empty():
		_draw_prize_at(PRIZES[held.kind], tips + Vector2(0, PRIZES[held.kind].r * 0.6 * s), 1.0, s)
	var open := phase == Phase.DROP or phase == Phase.RELEASE or (phase == Phase.GRAB and _t < 8) or phase < Phase.DROP
	sprite(CLAW_OPEN if open else CLAW_SHUT, centre, zoom)
	sprite(CARRIAGE, rail, 0.9 * s)


func _draw_buttons() -> void:
	if over:
		return
	# The control panel, in front of the glass.
	for i in 2:
		var active := (phase == Phase.MOVE_X and i == 0) or (phase == Phase.MOVE_D and i == 1)
		var pressed := active and _hold
		var at := Vector2(BOARD.x - 88 + i * 52, 428)
		var glow := Color.WHITE if active else Color(0.45, 0.45, 0.5)
		sprite(BTN_RIGHT if i == 0 else BTN_BACK, at + (Vector2(0, 2) if pressed else Vector2.ZERO), 0.75 if pressed else 0.85, 0.0, false, glow)
	if phase == Phase.MOVE_X and not _hold and goes == GOES:
		text("hold to move right", Vector2(BOARD.x / 2, 250), 16, INK)
	elif phase == Phase.MOVE_D and not _hold:
		text("now hold to move back", Vector2(BOARD.x / 2, 250), 16, INK)


func _hud_text() -> String:
	return "SCORE %d    GOES %d" % [score, maxi(0, goes)]

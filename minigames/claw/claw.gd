extends MiniGame
## Claw Grab, played like the real machine: drag to steer the claw along its
## rail (it swings on its cable as you move), let go to drop it. It closes on
## whatever's under it; a well-centred grab on a light prize holds, but a prize
## can slip out on the way up and tumble back into the pile. Carry it to the
## chute in the front corner to win it. Three goes.

const CASE: Texture2D = preload("res://assets/sprites/minigames/claw_case.png")
const CLAW_OPEN: Texture2D = preload("res://assets/sprites/minigames/claw_open.png")
const CLAW_SHUT: Texture2D = preload("res://assets/sprites/minigames/claw_closed.png")
const CHAIN: Texture2D = preload("res://assets/sprites/minigames/claw_chain.png")
const TROLLEY: Texture2D = preload("res://assets/sprites/minigames/claw_trolley.png")
const CHUTE: Texture2D = preload("res://assets/sprites/minigames/claw_chute.png")

## Each prize: its art, value, and grip (how well the claw holds it, 0-1).
const KINDS := {
	"teddy": { art = preload("res://assets/sprites/minigames/prize_teddy.png"), value = 20, grip = 0.9 },
	"lollipop": { art = preload("res://assets/sprites/minigames/prize_lollipop.png"), value = 20, grip = 0.85 },
	"bow": { art = preload("res://assets/sprites/minigames/prize_bow.png"), value = 20, grip = 0.8 },
	"toycar": { art = preload("res://assets/sprites/minigames/prize_toycar.png"), value = 30, grip = 0.75 },
	"gift": { art = preload("res://assets/sprites/minigames/prize_gift.png"), value = 30, grip = 0.7 },
	"bear": { art = preload("res://assets/sprites/minigames/prize_bear.png"), value = 40, grip = 0.7 },
	"bunny": { art = preload("res://assets/sprites/minigames/prize_bunny.png"), value = 40, grip = 0.7 },
	"unicorn": { art = preload("res://assets/sprites/minigames/prize_unicorn.png"), value = 60, grip = 0.55 },
	"star": { art = preload("res://assets/sprites/minigames/prize_star.png"), value = 100, grip = 0.35 },
	# The plushies' art is drawn bigger, so it's shown a little smaller.
	"cat": { art = preload("res://assets/sprites/minigames/prize_cat.png"), value = 30, grip = 0.8, zoom = 1.6 },
	"frog": { art = preload("res://assets/sprites/minigames/prize_frog.png"), value = 30, grip = 0.8, zoom = 1.6 },
	"dino": { art = preload("res://assets/sprites/minigames/prize_dino.png"), value = 50, grip = 0.6, zoom = 1.6 },
}
## The pile's mix (the star is rare).
const PILE := ["teddy", "teddy", "lollipop", "lollipop", "bow", "toycar", "gift", "bear",
	"bunny", "unicorn", "unicorn", "cat", "cat", "frog", "frog", "dino", "star"]

const DROPS := 3
const PRIZE_ZOOM := 2.0
const PRIZE_R := 19.0
const CLAW_ZOOM := 2.0
## The claw art hangs below the cable's end: its centre, its prongs' tips, and
## where a held prize sits.
const CLAW_MID := 32.0
const CLAW_TIPS := 60.0
const HOLD_AT := 54.0
## Chain links are drawn this far apart down the cable.
const LINK := 30.0
## How far the swing moves the claw sideways, at most.
const SWING_ARM := 40.0
const RAIL_Y := 44.0
const RAIL_X := Vector2(40, 330)
const CABLE_REST := 30.0
const FLOOR := 430.0
## The chute's centre, and the top of its opening (a prize falling past that
## line, over the chute, drops in).
const CHUTE_AT := Vector2(52, 392)
const CHUTE_TOP := 376.0
## How far the claw's prongs reach either side of its centre when closing.
const REACH := 28.0
const MOVE_SPEED := 2.6
const DROP_SPEED := 3.4
const RISE_SPEED := 2.4
## Frames to aim before the claw drops on its own.
const AIM_FRAMES := 8 * 60

enum Phase { AIM, DROP, CLOSE, RISE, CARRY, RELEASE }

var prizes: Array[Dictionary] = []
var phase := Phase.AIM
var drops_left := DROPS
var trolley_x := BOARD.x / 2
var cable := CABLE_REST
## The claw's swing on its cable (radians) and its swing speed.
var sway := 0.0
var sway_v := 0.0
var holding := {}
var grip := 0.0
## Frames into the lift and carry when the held prize slips out (-1: it won't).
var _slip_at := -1
var _held_t := 0
var falling: Array[Dictionary] = []
var _target_x := BOARD.x / 2
var _dragging := false
var _aim_t := 0
var _t := 0
var _keys := 0


func _setup() -> void:
	# Three loose rows heaped against each other, each a little higher.
	var kinds := PILE.duplicate()
	kinds.shuffle()
	for i in kinds.size():
		var row := i % 3
		var x := 112.0 + int(i / 3.0) * 40.0 + randf_range(-5, 5) + row * 14
		prizes.append({ kind = kinds[i], pos = Vector2(minf(x, 332), FLOOR - PRIZE_R - row * 16 - randf() * 6) })
	_sort()


func _sort() -> void:
	prizes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.y < b.pos.y)


func _pointer_pressed(at: Vector2) -> void:
	if phase == Phase.AIM:
		_dragging = true
		_target_x = at.x


func _pointer_moved(at: Vector2) -> void:
	if _dragging:
		_target_x = at.x


func _pointer_released(_at: Vector2) -> void:
	if _dragging and phase == Phase.AIM:
		_dragging = false
		_drop()


func _key(event: InputEventKey) -> void:
	if phase != Phase.AIM:
		return
	match event.keycode:
		KEY_LEFT:
			_keys = -1 if event.pressed else 0
		KEY_RIGHT:
			_keys = 1 if event.pressed else 0
		KEY_SPACE, KEY_DOWN:
			if event.pressed:
				_drop()


func _drop() -> void:
	phase = Phase.DROP
	_keys = 0
	play_hit()


## Where the cable ends: straight under the trolley, shifted by the swing (a
## short arm, so a long drop doesn't throw the claw wide).
func claw_pos() -> Vector2:
	return Vector2(trolley_x + sin(sway) * SWING_ARM, RAIL_Y + cable)


func _tick() -> void:
	_t += 1
	var before := trolley_x
	match phase:
		Phase.AIM:
			_aim_t += 1
			if _keys != 0:
				_target_x = trolley_x + _keys * 40
			if _dragging or _keys != 0:
				trolley_x += clampf(_target_x - trolley_x, -MOVE_SPEED, MOVE_SPEED)
			trolley_x = clampf(trolley_x, RAIL_X.x, RAIL_X.y)
			if _aim_t > AIM_FRAMES:
				_dragging = false
				_drop()
		Phase.DROP:
			cable += DROP_SPEED
			var tips := claw_pos().y + CLAW_TIPS
			if tips >= FLOOR - 4 or _prize_under(claw_pos(), 6) != -1:
				phase = Phase.CLOSE
				_t = 0
		Phase.CLOSE:
			if _t == 12:
				_grab()
			if _t >= 20:
				phase = Phase.RISE
		Phase.RISE:
			cable -= RISE_SPEED
			_maybe_slip()
			if cable <= CABLE_REST:
				cable = CABLE_REST
				phase = Phase.CARRY
		Phase.CARRY:
			trolley_x += clampf(CHUTE_AT.x - trolley_x, -MOVE_SPEED, MOVE_SPEED)
			_maybe_slip()
			if absf(trolley_x - CHUTE_AT.x) < 1 and absf(sway) < 0.08:
				phase = Phase.RELEASE
				_t = 0
		Phase.RELEASE:
			if _t == 10:
				if not holding.is_empty():
					_fall(holding, claw_pos() + Vector2(0, HOLD_AT))
					holding = {}
			if _t >= 40:
				_next_go()
	# The claw swings on its cable as the trolley speeds up and slows down.
	var accel := trolley_x - before
	sway_v += -accel * 0.012 - sway * 0.04
	# It swings while steered; once it's dropping it settles straight down.
	sway_v *= 0.94 if phase in [Phase.AIM, Phase.CARRY] else 0.8
	sway += sway_v
	_update_falling()


## Index of the topmost prize under a point, within `slack` of touching.
func _prize_under(at: Vector2, slack: float) -> int:
	var best_i := -1
	for i in prizes.size():
		var p: Dictionary = prizes[i]
		if absf(p.pos.x - at.x) < PRIZE_R and at.y + CLAW_TIPS >= p.pos.y - PRIZE_R - slack:
			if best_i == -1 or p.pos.y < prizes[best_i].pos.y:
				best_i = i
	return best_i


## The claw closes: it holds the nearest prize between its prongs, better the
## more centred it is and the lighter the prize.
func _grab() -> void:
	var at := claw_pos()
	var pick := -1
	var pick_d := REACH
	for i in prizes.size():
		var d := absf(prizes[i].pos.x - at.x)
		if d < pick_d and absf(prizes[i].pos.y - (at.y + CLAW_TIPS)) < PRIZE_R + 12:
			pick_d = d
			pick = i
	if pick == -1:
		miss(at + Vector2(0, CLAW_TIPS))
		return
	var prize: Dictionary = prizes[pick]
	var centred := 1.0 - pick_d / REACH
	grip = clampf(KINDS[prize.kind].grip * (0.45 + 0.55 * centred), 0.0, 1.0)
	if randf() > 0.35 + grip * 0.65:
		add_pop(at + Vector2(0, CLAW_TIPS), "SLIPPED!", 36, Color("888888"))
		play_miss()
		return
	holding = prize
	prizes.remove_at(pick)
	# Decided now, as the claw closes: a weak grip lets go somewhere on the way.
	_held_t = 0
	_slip_at = randi_range(20, 220) if randf() < (1.0 - grip) * 0.9 else -1


## A held prize slips out if this grab was going to (see _grab).
func _maybe_slip() -> void:
	if holding.is_empty():
		return
	_held_t += 1
	if _held_t != _slip_at:
		return
	add_pop(claw_pos() + Vector2(0, HOLD_AT), "DROPPED IT!", 40, Color("888888"))
	play_miss()
	_fall(holding, claw_pos() + Vector2(0, HOLD_AT))
	holding = {}


## A prize falling from the claw: into the chute (a win) or back onto the pile.
func _fall(prize: Dictionary, from: Vector2) -> void:
	prize.pos = from
	prize.vy = 0.0
	falling.append(prize)


func _update_falling() -> void:
	for prize in falling.duplicate():
		prize.vy += 0.35
		prize.pos.y += prize.vy
		var in_chute: bool = absf(prize.pos.x - CHUTE_AT.x) < 26 and prize.pos.y > CHUTE_TOP
		if in_chute and prize.pos.y > CHUTE_AT.y + 16:
			falling.erase(prize)
			var value: int = KINDS[prize.kind].value
			score += value
			add_pop(Vector2(CHUTE_AT.x + 30, CHUTE_TOP - 30), "WON! +%d" % value, 50, GOLD)
			Sfx.play(&"mg_star")
			continue
		var landing := _pile_height(prize.pos.x)
		if not in_chute and prize.pos.y >= landing:
			prize.pos.y = landing
			falling.erase(prize)
			prizes.append(prize)
			_sort()


## Where a prize dropped at x comes to rest: on the floor or on top of the pile.
func _pile_height(x: float) -> float:
	var y := FLOOR - PRIZE_R
	for p in prizes:
		if absf(p.pos.x - x) < PRIZE_R * 1.4:
			y = minf(y, p.pos.y - PRIZE_R * 0.9)
	return y


func _next_go() -> void:
	drops_left -= 1
	if drops_left <= 0 and falling.is_empty():
		end_round("NICE GRABS!" if score > 0 else "EMPTY CLAW", score > 0)
		return
	phase = Phase.AIM
	_aim_t = 0


func _draw_board() -> void:
	board.draw_texture_rect(CASE, Rect2(Vector2.ZERO, BOARD), false)
	for p in prizes:
		_draw_prize(p, p.pos)
	# A prize dropping into the chute goes behind its front panel.
	for prize in falling:
		if _into_chute(prize):
			_draw_prize(prize, prize.pos)
	sprite(CHUTE, CHUTE_AT, 2.0)
	# The cable: chain links from the trolley down to the claw.
	var top := Vector2(trolley_x, RAIL_Y)
	var claw := claw_pos()
	var down := (claw - top).normalized()
	var links := ceili(top.distance_to(claw) / LINK)
	for i in links:
		sprite(CHAIN, top + down * (i * LINK + LINK / 2), 1.0, sway)
	sprite(TROLLEY, top, CLAW_ZOOM)
	if not holding.is_empty():
		_draw_prize(holding, claw + down * HOLD_AT, sway)
	var shut := phase in [Phase.RISE, Phase.CARRY] or (phase == Phase.CLOSE and _t > 6) or (phase == Phase.RELEASE and _t < 10)
	sprite(CLAW_SHUT if shut else CLAW_OPEN, claw + down * CLAW_MID, CLAW_ZOOM, sway)
	for prize in falling:
		if not _into_chute(prize):
			_draw_prize(prize, prize.pos)
	if phase == Phase.AIM and not _dragging:
		text("DRAG TO AIM - LET GO TO DROP", Vector2(BOARD.x / 2, 150), 12, CREAM)
	draw_pops(0.4, 11)


func _into_chute(prize: Dictionary) -> bool:
	return absf(prize.pos.x - CHUTE_AT.x) < 26 and prize.pos.y > CHUTE_TOP - PRIZE_R


func _draw_prize(prize: Dictionary, at: Vector2, angle := 0.0) -> void:
	var kind: Dictionary = KINDS[prize.kind]
	sprite(kind.art, at, kind.get("zoom", PRIZE_ZOOM), angle)


func _hud_text() -> String:
	return "SCORE %d    GOES %d" % [score, maxi(0, drops_left)]

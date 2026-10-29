extends MiniGame
## Whack-It, a real whack-a-mole: moles pop up out of nine holes on the lawn and
## you bonk them with the mallet before they duck. Hits in a row build a combo
## multiplier; a whiff or a mole that gets away breaks it. Golden moles pay big,
## hard-hat moles take two bonks, and don't bonk the bunnies! They come faster
## as the clock runs down, and the last five seconds are a frenzy. 30 s.

const BACKDROP: Texture2D = preload("res://assets/sprites/minigames/whack_backdrop.png")
const HOLE: Texture2D = preload("res://assets/sprites/minigames/whack_hole.png")
## The dirt in front of the hole, drawn over a mole so it rises out of it.
const HOLE_FRONT: Texture2D = preload("res://assets/sprites/minigames/whack_hole_front.png")
const MALLET: Texture2D = preload("res://assets/sprites/minigames/whack_mallet.png")
const BURST: Texture2D = preload("res://assets/sprites/minigames/whack_burst.png")
const DUST: Texture2D = preload("res://assets/sprites/minigames/whack_dust.png")
const STARS: Texture2D = preload("res://assets/sprites/minigames/whack_stars.png")
const HAT: Texture2D = preload("res://assets/sprites/minigames/whack_hat.png")
const DIZZY: Texture2D = preload("res://assets/sprites/minigames/whack_mole_dizzy.png")
const LAUGH: Texture2D = preload("res://assets/sprites/minigames/whack_mole_laugh.png")
const GOLD_MOLE: Texture2D = preload("res://assets/sprites/minigames/whack_mole_gold.png")
const HARDHAT: Texture2D = preload("res://assets/sprites/minigames/whack_mole_hardhat.png")
const BUNNY: Texture2D = preload("res://assets/sprites/minigames/whack_mole_bunny.png")
## Everyday moles, in their hats and get-ups.
const MOLES: Array[Texture2D] = [
	preload("res://assets/sprites/minigames/whack_mole_plain.png"),
	preload("res://assets/sprites/minigames/whack_mole_plain.png"),
	preload("res://assets/sprites/minigames/whack_mole_glasses.png"),
	preload("res://assets/sprites/minigames/whack_mole_pirate.png"),
	preload("res://assets/sprites/minigames/whack_mole_chef.png"),
	preload("res://assets/sprites/minigames/whack_mole_king.png"),
	preload("res://assets/sprites/minigames/whack_mole_detective.png"),
	preload("res://assets/sprites/minigames/whack_mole_wizard.png"),
	preload("res://assets/sprites/minigames/whack_mole_baby.png"),
]

const TIME := 30 * 60
const FRENZY := 5 * 60
## The three rows of holes, back to front: how far down the lawn, how far
## apart, and how big (further away is smaller).
const ROWS := [
	{ y = 238.0, gap = 86.0, zoom = 0.8 },
	{ y = 318.0, gap = 104.0, zoom = 0.92 },
	{ y = 408.0, gap = 120.0, zoom = 1.05 },
]
const HOLE_ZOOM := 2.4
const MOLE_ZOOM := 1.45
## The hole art's middle row, and how many rows of the mole art show above it
## (the rest is the mole's own mound, hidden in the hole).
const HOLE_MID := 23.0
const MOLE_ROWS := 52.0
const RISE := 8
const HIT_SHOW := 24
## A bonked mole starts ducking this many frames before it's gone.
const HIT_DUCK := 12
const POINTS := 10
const GOLD_POINTS := 50
const HAT_POINTS := 20
const BUNNY_PENALTY := 30

enum Kind { MOLE, GOLD, HARDHAT, BUNNY }

## Each hole: where it is and its size, and what's in it: the kind of mole,
## how far up it is (0-1), how long it stays, and whether it's been bonked.
var holes: Array[Dictionary] = []
var time := TIME
var combo := 0
var best_combo := 0
var _spawn := 30
var _mallet := Vector2(BOARD.x * 0.7, 380)
var _swing := 0
var _effects: Array[Dictionary] = []


func _setup() -> void:
	for row: Dictionary in ROWS:
		for c in 3:
			holes.append({ at = Vector2(BOARD.x / 2 + (c - 1) * row.gap, row.y), zoom = row.zoom,
				kind = -1, art = null, up = 0.0, stay = 0, hit = 0, hat = false, rising = true })


func multiplier() -> int:
	return 1 + mini(floori(combo / 5.0), 3)


func _pointer_pressed(at: Vector2) -> void:
	_mallet = at
	_swing = 10
	for h in _front_first():
		if h.kind >= 0 and h.hit == 0 and h.up > 0.35 and _mole_rect(h).has_point(at):
			_bonk(h)
			return
	combo = 0
	Sfx.play(&"wk_whiff")
	_effects.append({ art = DUST, at = at, t = 14, zoom = 1.0 })


func _front_first() -> Array[Dictionary]:
	var order := holes.duplicate()
	order.reverse()
	return order


## The part of a mole above its hole, as it stands now (with a little slack).
func _mole_rect(h: Dictionary) -> Rect2:
	var k: float = h.zoom * MOLE_ZOOM
	var top: float = _anchor(h).y - MOLE_ROWS * k * h.up
	return Rect2(h.at.x - 32 * k, top - 8, 64 * k, _anchor(h).y - top + 16)


func _anchor(h: Dictionary) -> Vector2:
	return h.at + Vector2(0, (HOLE_MID - HOLE.get_height() / 2.0) * HOLE_ZOOM * h.zoom)


func _bonk(h: Dictionary) -> void:
	var at: Vector2 = _anchor(h) - Vector2(0, 30 * h.zoom)
	_effects.append({ art = BURST, at = at, t = 10, zoom = 1.4 * h.zoom })
	match h.kind:
		Kind.BUNNY:
			score = maxi(0, score - BUNNY_PENALTY)
			combo = 0
			h.hit = HIT_SHOW
			Sfx.play(&"wk_squeak")
			add_pop(at - Vector2(0, 48), "-%d" % BUNNY_PENALTY, 30, PINK)
			return
		Kind.HARDHAT when h.hat:
			# The first bonk only knocks its hat off.
			h.hat = false
			h.stay = maxi(h.stay, 30)
			Sfx.play(&"wk_clang")
			_effects.append({ art = HAT, at = at - Vector2(0, 10), t = 24, zoom = h.zoom * 1.2, v = Vector2(randf_range(-2, 2), -4), spin = 0.0 })
			return
	combo += 1
	best_combo = maxi(best_combo, combo)
	var base := GOLD_POINTS if h.kind == Kind.GOLD else (HAT_POINTS if h.kind == Kind.HARDHAT else POINTS)
	var points := base * multiplier()
	score += points
	h.hit = HIT_SHOW
	Sfx.play(&"wk_gold" if h.kind == Kind.GOLD else &"wk_bonk")
	add_pop(at - Vector2(0, 48), "+%d" % points, 30, GOLD if points >= 30 else CREAM)


func _tick() -> void:
	time -= 1
	if time <= 0:
		end_round("TIME!", score >= star_scores[0])
		return
	_swing = maxi(0, _swing - 1)
	# Faster as time runs out: from a mole every ~0.9 s to one every ~0.3 s.
	var pace := 1.0 - float(time) / TIME
	_spawn -= 2 if time <= FRENZY else 1
	if _spawn <= 0:
		_spawn = int(lerpf(52, 20, pace) * randf_range(0.7, 1.3))
		_pop_up(pace)
	for h in holes:
		if h.kind < 0:
			continue
		if h.hit > 0:
			h.hit -= 1
			if h.hit < HIT_DUCK:
				h.up = maxf(0, h.up - 1.0 / RISE)
			if h.hit == 0:
				h.kind = -1
		elif h.rising:
			h.up = minf(1, h.up + 1.0 / RISE)
			if h.up >= 1:
				h.rising = false
		elif h.stay > 0:
			h.stay -= 1
		else:
			h.up = maxf(0, h.up - 1.0 / RISE)
			if h.up <= 0:
				# Got away: a laugh, and the combo's gone (bunnies are meant to).
				if h.kind != Kind.BUNNY:
					combo = 0
				h.kind = -1
	for e in _effects.duplicate():
		e.t -= 1
		if e.has("v"):
			e.at += e.v
			e.v.y += 0.4
			e.spin += 0.3
		if e.t <= 0:
			_effects.erase(e)


func _pop_up(pace: float) -> void:
	var free := holes.filter(func(hole: Dictionary) -> bool: return hole.kind < 0)
	if free.is_empty():
		return
	var h: Dictionary = free.pick_random()
	var roll := randf()
	h.kind = Kind.GOLD if roll < 0.05 else (Kind.BUNNY if roll < 0.17 else (Kind.HARDHAT if roll < 0.32 else Kind.MOLE))
	h.art = MOLES.pick_random()
	h.hat = h.kind == Kind.HARDHAT
	h.up = 0.0
	h.rising = true
	h.hit = 0
	# Up for ~1.2 s at first, ~0.55 s at the end; golden moles are quicker.
	h.stay = int(lerpf(62, 26, pace) * (0.6 if h.kind == Kind.GOLD else 1.0))
	Sfx.play(&"wk_pop")


func _draw_board() -> void:
	board.draw_texture_rect(BACKDROP, Rect2(Vector2.ZERO, BOARD), false)
	for h in holes:
		var z: float = HOLE_ZOOM * h.zoom
		sprite(HOLE, h.at, z)
		if h.kind >= 0 and h.up > 0:
			_draw_mole(h)
		sprite(HOLE_FRONT, h.at, z)
	for e in _effects:
		var fade := clampf(e.t / 6.0, 0.0, 1.0)
		sprite(e.art, e.at, e.zoom, e.get("spin", 0.0), false, Color(1, 1, 1, fade))
	_draw_mallet()
	if time <= FRENZY and not over and posmod(time, 20) < 12:
		text("FRENZY!", Vector2(BOARD.x / 2, 170), 24, PINK)
	if combo >= 5 and not over:
		text("COMBO x%d" % multiplier(), Vector2(BOARD.x / 2, 198), 16, GOLD)
	draw_pops(0.6, 16)


func _draw_mole(h: Dictionary) -> void:
	var art: Texture2D = _art(h)
	var k: float = h.zoom * MOLE_ZOOM
	var rows: float = ceilf(MOLE_ROWS * h.up)
	var anchor := _anchor(h)
	var shown := Vector2(art.get_width(), rows) * k
	board.draw_texture_rect_region(art, Rect2(anchor + Vector2(-shown.x / 2, -shown.y), shown), Rect2(0, 0, art.get_width(), rows))
	if h.hit > 0 and h.kind != Kind.BUNNY:
		sprite(STARS, anchor - Vector2(0, MOLE_ROWS * k * h.up + 2), 0.9 * h.zoom, h.hit * 0.3)


func _art(h: Dictionary) -> Texture2D:
	if h.hit > 0:
		return BUNNY if h.kind == Kind.BUNNY else DIZZY
	if not h.rising and h.stay == 0 and h.kind != Kind.BUNNY:
		return LAUGH
	match h.kind:
		Kind.GOLD:
			return GOLD_MOLE
		Kind.HARDHAT:
			return HARDHAT if h.hat else h.art
		Kind.BUNNY:
			return BUNNY
	return h.art


## The mallet hangs raised where you last tapped. Each tap slams its head down
## on the spot, then it lifts back up.
func _draw_mallet() -> void:
	if over:
		return
	var lift := 1.0 - float(_swing) / 10.0
	var angle := lerpf(-0.6, 0.35, lift * lift)
	var pivot := _mallet + Vector2(34, 58)
	board.draw_set_transform(pivot, angle, Vector2(1.6, 1.6))
	board.draw_texture(MALLET, Vector2(-MALLET.get_width() / 2.0, -MALLET.get_height()))
	board.draw_set_transform(Vector2.ZERO)


func _hud_text() -> String:
	return "SCORE %d    COMBO %d    TIME %d" % [score, combo, ceili(maxi(0, time) / 60.0)]

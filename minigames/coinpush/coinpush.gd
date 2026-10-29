extends MiniGame
## Coin Cascade, a real two-tier coin pusher: drag along the top to aim the
## coin chute and let go to drop a coin onto the sliding shelf. The shelf slides
## in and out; its back wall shoves its coins off its front onto the table
## below, and its front face pushes the table's coins towards the edge. Coins,
## gems and prizes shoved over the edge are won. Land a coin in the moving
## BONUS pocket for a shower of coins. A bucket of coins per game; quitting
## early banks what you've won.

const BACKDROP: Texture2D = preload("res://assets/sprites/minigames/push_backdrop.png")
const SHELF: Texture2D = preload("res://assets/sprites/minigames/push_shelf.png")
const CHUTE: Texture2D = preload("res://assets/sprites/minigames/push_chute.png")
const POCKET: Texture2D = preload("res://assets/sprites/minigames/push_pocket.png")
const LAMP: Texture2D = preload("res://assets/sprites/minigames/push_lamp.png")

## Everything that sits on the table: its art, size and what it's worth.
const ITEMS := {
	&"silver": { art = preload("res://assets/sprites/minigames/push_silver.png"), r = 11.0, pays = 10 },
	&"gold": { art = preload("res://assets/sprites/minigames/push_gold.png"), r = 11.0, pays = 25 },
	&"jackpot": { art = preload("res://assets/sprites/minigames/push_jackpot.png"), r = 13.0, pays = 100 },
	&"ruby": { art = preload("res://assets/sprites/minigames/push_ruby.png"), r = 11.0, pays = 50 },
	&"sapphire": { art = preload("res://assets/sprites/minigames/push_sapphire.png"), r = 11.0, pays = 50 },
	&"emerald": { art = preload("res://assets/sprites/minigames/push_emerald.png"), r = 11.0, pays = 50 },
	&"gift": { art = preload("res://assets/sprites/minigames/push_gift.png"), r = 14.0, pays = 150 },
}
const GEMS: Array[StringName] = [&"ruby", &"sapphire", &"emerald"]

## The playfield, in board pixels (the backdrop art is drawn at 2x).
const WALL_Y := 68.0
const LEFT := 32.0
const RIGHT := 328.0
const LEDGE := 408.0
## The shelf's front edge, fully in, and how far it slides out.
const SHELF_FRONT := 168.0
const SHELF_REACH := 56.0
const SHELF_PERIOD := 210.0
## The shelf art is drawn this tall, its bottom on the shelf's front edge.
const SHELF_H := 158.0
const CHUTE_Y := 38.0
## Where a dropped coin lands on the shelf (from its front edge), and how long
## it falls.
const LAND := 62.0
const FALL := 16
const POCKET_R := 9.0
## After a bonus the pocket closes for a while.
const POCKET_SHUT := 240
const BUCKET := 40
## The tray below the edge, and the chute in its middle that won coins slide
## into.
const TRAY_Y := 424.0
const CHUTE_IN := Vector2(BOARD.x / 2, 440)
const SETTLE := 300
const PASSES := 2

## The two tiers: coins on the sliding shelf, and coins on the table below.
var shelf: Array[Dictionary] = []
var table: Array[Dictionary] = []
var bucket := BUCKET
var aim := BOARD.x / 2
var dropped := 0
var shift := 0.0
var _t := 0.0
var _pocket_t := 0.0
var _dropping: Array[Dictionary] = []
var _won: Array[Dictionary] = []
var _cooldown := 0
var _settle := SETTLE
var _bonus_t := 0
var _spill_t := 0


func _setup() -> void:
	# A table heaped right up to the edge, a few prizes among them: tip in
	# more coins than fit and let the pusher settle it (whatever it pushes off
	# now doesn't count).
	for i in 150:
		_place(table, &"gold" if randf() < 0.08 else &"silver", Rect2(LEFT, SHELF_FRONT + 20, RIGHT - LEFT, LEDGE - SHELF_FRONT - 40))
	for i in 40:
		_place(shelf, &"silver", Rect2(LEFT, WALL_Y, RIGHT - LEFT, SHELF_FRONT - WALL_Y - 12))
	for kind: StringName in [&"jackpot", &"gift", GEMS.pick_random(), GEMS.pick_random()]:
		_place(table, kind, Rect2(LEFT + 30, SHELF_FRONT + 60, RIGHT - LEFT - 60, 100))
	for i in 600:
		var was := shift
		shift = SHELF_REACH * (0.5 - 0.5 * cos(i * TAU / 100.0))
		for c in shelf:
			c.p.y += shift - was
		_solve()
		table.assign(table.filter(func(c: Dictionary) -> bool: return c.p.y <= LEDGE))
		shelf.assign(shelf.filter(func(c: Dictionary) -> bool: return c.p.y <= front()))
	shift = 0.0


func _place(tier: Array[Dictionary], kind: StringName, area: Rect2) -> void:
	var r: float = ITEMS[kind].r
	var at := Vector2(randf_range(area.position.x + r, area.end.x - r), randf_range(area.position.y + r, area.end.y - r))
	tier.append({ kind = kind, p = at, r = r, spin = randf() * TAU })


func front() -> float:
	return SHELF_FRONT + shift


func pocket_at() -> Vector2:
	return Vector2(BOARD.x / 2 + sin(_pocket_t) * (RIGHT - LEFT - 70) / 2.0, front() - LAND)


func _pointer_pressed(at: Vector2) -> void:
	_aim(at)


func _pointer_moved(at: Vector2) -> void:
	_aim(at)


func _pointer_released(_at: Vector2) -> void:
	drop()


func _aim(at: Vector2) -> void:
	aim = clampf(at.x, LEFT + 10, RIGHT - 10)


func drop() -> void:
	if bucket <= 0 or _cooldown > 0 or over:
		return
	bucket -= 1
	dropped += 1
	_cooldown = 10
	_dropping.append({ x = aim + randf_range(-3, 3), t = FALL, kind = &"gold" if dropped % 10 == 0 else &"silver" })


## Quitting is the way to bank early, so it ends the round.
func close() -> void:
	if stage == Stage.PLAYING:
		end_round("CASHED OUT", score > 0)
	super()


func _tick() -> void:
	_cooldown = maxi(0, _cooldown - 1)
	_bonus_t = maxi(0, _bonus_t - 1)
	_spill_t = maxi(0, _spill_t - 1)
	_t += 1
	_pocket_t += 0.035
	var was := shift
	shift = SHELF_REACH * (0.5 - 0.5 * cos(_t * TAU / SHELF_PERIOD))
	# Coins ride the shelf.
	for c in shelf:
		c.p.y += shift - was
	for d in _dropping.duplicate():
		d.t -= 1
		if d.t <= 0:
			_dropping.erase(d)
			_land(d)
	_solve()
	_spill()
	# Won coins drop into the tray, slide along it to the chute and fall in.
	for w in _won.duplicate():
		if w.p.y < TRAY_Y:
			w.p.y = minf(w.p.y + 3, TRAY_Y)
		elif w.p.distance_to(CHUTE_IN) > 3:
			w.p = w.p.move_toward(CHUTE_IN, 1.8 + 0.02 * w.p.distance_to(CHUTE_IN))
			w.spin += 0.2
		else:
			w.t -= 1
			if w.t <= 0:
				_won.erase(w)
	if bucket == 0 and _dropping.is_empty():
		_settle -= 1
		if _settle <= 0:
			end_round("CASHED OUT", score >= star_scores[0])


func _land(d: Dictionary) -> void:
	var at := Vector2(d.x, front() - LAND)
	Sfx.play(&"cp_clink")
	if _bonus_t == 0 and at.distance_to(pocket_at()) < POCKET_R:
		_bonus()
		return
	shelf.append({ kind = d.kind, p = at, r = ITEMS[d.kind].r, spin = randf() * TAU })


## A coin in the pocket: a shower of coins (and sometimes a gem) onto the table.
func _bonus() -> void:
	Sfx.play(&"cp_bonus")
	_bonus_t = POCKET_SHUT
	for i in 6:
		_place(table, &"silver", Rect2(LEFT, front() + 10, RIGHT - LEFT, 80))
	_place(table, GEMS.pick_random() if randf() < 0.5 else &"gold", Rect2(LEFT + 40, front() + 10, RIGHT - LEFT - 80, 60))


## Pushes overlapping coins apart, then holds each tier inside its walls. The
## coins are swept back to front and only the front coin of a pair moves, so a
## push carries right through the heap in one pass, as a real pile does.
func _solve() -> void:
	for tier: Array[Dictionary] in [shelf, table]:
		tier.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.p.y < b.p.y)
	for pass_i in PASSES:
		for tier: Array[Dictionary] in [shelf, table]:
			for i in tier.size():
				var a := tier[i]
				for j in range(i + 1, tier.size()):
					var b := tier[j]
					var reach: float = a.r + b.r
					if b.p.y - a.p.y >= reach:
						break
					var gap: Vector2 = b.p - a.p
					var dist := gap.length()
					if dist < reach:
						var n := gap / dist if dist > 0.01 else Vector2.DOWN
						b.p += n * (reach - dist)
		var f := front()
		for c in shelf:
			c.p.x = clampf(c.p.x, LEFT + c.r, RIGHT - c.r)
			c.p.y = maxf(c.p.y, WALL_Y + c.r)
		for c in table:
			c.p.x = clampf(c.p.x, LEFT + c.r, RIGHT - c.r)
			c.p.y = maxf(c.p.y, f + c.r)


## Coins off the shelf's front drop to the table; coins off the table's edge
## are won.
func _spill() -> void:
	var f := front()
	for c in shelf.duplicate():
		if c.p.y > f:
			shelf.erase(c)
			c.p.y = f + c.r + 1
			table.append(c)
	for c in table.duplicate():
		if c.p.y > LEDGE:
			table.erase(c)
			var pays: int = ITEMS[c.kind].pays
			score += pays
			_won.append({ kind = c.kind, p = c.p, t = 8, spin = c.spin })
			add_pop(Vector2(c.p.x, LEDGE + 22), "+%d" % pays, 30, GOLD if pays > 10 else CREAM)
			if pays >= 50:
				Sfx.play(&"cp_prize")
			elif _spill_t == 0:
				Sfx.play(&"cp_spill")
				_spill_t = 6


func _draw_board() -> void:
	board.draw_texture_rect(BACKDROP, Rect2(Vector2.ZERO, BOARD), false)
	for c in table:
		_draw_item(c)
	var f := front()
	board.draw_texture_rect(SHELF, Rect2(LEFT - 8, f - SHELF_H, RIGHT - LEFT + 16, SHELF_H), false)
	for c in shelf:
		_draw_item(c)
	# The pocket rides the shelf, raised above its coins so you can see it.
	if _bonus_t == 0:
		sprite(POCKET, pocket_at(), 2.0 * (POCKET_R + 9) / POCKET.get_width())
	# The back wall hides the shelf as it slides in under it.
	board.draw_texture_rect_region(BACKDROP, Rect2(0, 0, BOARD.x, WALL_Y), Rect2(0, 0, BACKDROP.get_width(), WALL_Y / 2.0))
	if _bonus_t > POCKET_SHUT - 90 and posmod(_bonus_t, 12) < 6:
		sprite(LAMP, Vector2(40, 34), 1.2)
		sprite(LAMP, Vector2(BOARD.x - 40, 34), 1.2)
		text("BONUS!", Vector2(BOARD.x / 2, 300), 28, GOLD)
	for w in _won:
		var item: Dictionary = ITEMS[w.kind]
		# Shrinks as it drops into the chute.
		sprite(item.art, w.p, 2.0 * item.r / item.art.get_width() * (0.2 + 0.8 * w.t / 8.0), w.spin)
	for d in _dropping:
		# Falling towards the shelf, so it starts big and shrinks as it lands.
		var k := float(d.t) / FALL
		sprite(ITEMS[d.kind].art, Vector2(d.x, lerpf(f - LAND, CHUTE_Y + 14, k)), 0.5 + 0.5 * k)
	if bucket > 0 and not over:
		sprite(CHUTE, Vector2(aim, CHUTE_Y), 1.3)
	if stage == Stage.PLAYING and dropped == 0:
		text("drag to aim, let go to drop", Vector2(BOARD.x / 2, 300), 14, GOLD)
	elif bucket == 0 and not over:
		text("LAST PUSHES...", Vector2(BOARD.x / 2, 300), 18, GOLD)
	draw_pops(0.4, 13)


func _draw_item(c: Dictionary) -> void:
	var item: Dictionary = ITEMS[c.kind]
	sprite(item.art, c.p, 2.0 * c.r / item.art.get_width(), c.spin if c.kind in [&"silver", &"gold", &"jackpot"] else 0.0)


func _hud_text() -> String:
	return "SCORE %d    COINS %d" % [score, bucket]

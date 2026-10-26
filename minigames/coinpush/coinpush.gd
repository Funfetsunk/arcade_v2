extends MiniGame
## Coin Cascade: the dropper drifts side to side and the pusher bar sweeps; tap to
## drop a coin, and coins shoved off the ledge score. Endless, so quitting banks the
## score (the timed games award when the round ends instead).

const TL := 30.0
const TR := BOARD.x - 30
const LEDGE := 330.0
const PUSH_MIN := 150.0
const PUSH_MAX := 215.0
const CR := 8.0

const COIN_GOLD: Texture2D = preload("res://assets/sprites/minigames/coin_gold.png")
const COIN_SILVER: Texture2D = preload("res://assets/sprites/minigames/coin_silver.png")
const DROPPER: Texture2D = preload("res://assets/sprites/minigames/dropper.png")

var coins: Array[Dictionary] = []
var falling: Array[Dictionary] = []
var drop_x := BOARD.x / 2
var _drop_cooldown := 0
var _t := 0.0
var _push_t := 0.0


func _setup() -> void:
	# A well-stacked table: lots of coins already sitting near the ledge.
	for i in 30:
		coins.append({ x = TL + 14 + randf() * (TR - TL - 28), y = PUSH_MAX + 8 + randf() * (LEDGE - PUSH_MAX - 18),
			gold = randf() < 0.15, dropping = false })


func _pointer_pressed(_at: Vector2) -> void:
	if _drop_cooldown > 0:
		return
	_drop_cooldown = 12
	coins.append({ x = drop_x + (randf() - 0.5) * 10, y = -20.0, gold = randf() < 0.2, dropping = true })


## Quitting is the normal way out of this endless game, so it banks the score.
func close() -> void:
	if stage == Stage.PLAYING:
		end_round("CASHED OUT", score > 0)
	super()


## The pusher's front edge.
func _front() -> float:
	return PUSH_MIN + (sin(_push_t * 6) * 0.5 + 0.5) * (PUSH_MAX - PUSH_MIN)


func _tick() -> void:
	_t += 0.022
	_push_t += 0.014
	drop_x = BOARD.x / 2 + sin(_t * 1.6) * (BOARD.x / 2 - 50)
	if _drop_cooldown > 0:
		_drop_cooldown -= 1
	var front := _front()
	for c in coins:
		if c.dropping:
			c.y += 5
			if c.y >= front + CR + 2:
				c.y = front + CR + 2
				c.dropping = false
		elif front + CR > c.y:
			c.y = front + CR
	# Coin-on-coin shove: back to front, push overlapping coins forward.
	coins.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.y < b.y)
	for i in coins.size():
		for j in range(i + 1, coins.size()):
			var a := coins[i]
			var b := coins[j]
			if a.dropping or b.dropping:
				continue
			if absf(a.x - b.x) < CR * 1.7 and b.y - a.y < CR * 1.8:
				b.y = a.y + CR * 1.8
	# Over the ledge: cash in.
	for c in coins.duplicate():
		if not c.dropping and c.y > LEDGE:
			var points := 30 if c.gold else 10
			score += points
			falling.append({ x = c.x, y = c.y, gold = c.gold, t = 30 })
			add_pop(Vector2(c.x, LEDGE + 16), "+%d" % points, 36)
			coins.erase(c)
	for f in falling.duplicate():
		f.y += 4
		f.t -= 1
		if f.t <= 0:
			falling.erase(f)


func _draw_board() -> void:
	var front := _front()
	board.draw_rect(Rect2(TL - 14, 90, TR - TL + 28, LEDGE - 70), Color("241a0e"))
	board.draw_rect(Rect2(TL, 110, TR - TL, LEDGE - 110), Color("3a2c16"))
	board.draw_rect(Rect2(TL, 110, TR - TL, front - 110), Color("6b4a23"))
	board.draw_rect(Rect2(TL, front - 4, TR - TL, 4), GOLD)
	board.draw_rect(Rect2(TL - 14, LEDGE, TR - TL + 28, 8), BG)
	for c in coins + falling:
		sprite(COIN_GOLD if c.gold else COIN_SILVER, Vector2(c.x, c.y))
	# The dropper.
	sprite(DROPPER, Vector2(drop_x, 66), 2.0)
	draw_pops(-0.5, 11)


func _hud_text() -> String:
	return "SCORE %d    ON TABLE %d" % [score, coins.size()]

extends MiniGame
## Mega Jackpot, a proper fruit machine: pull the lever (drag it down) or tap
## SPIN, and the three reels stop one by one - or tap a reel's STOP button to
## stop it early. The middle line pays. After a losing spin you may HOLD up to
## two reels for the next spin, and sometimes you're given NUDGES to knock a
## reel down one symbol. Five spins.

const BACKDROP: Texture2D = preload("res://assets/sprites/minigames/slot_backdrop.png")
const REEL: Texture2D = preload("res://assets/sprites/minigames/slot_reel.png")
const LEVER_UP: Texture2D = preload("res://assets/sprites/minigames/slot_lever_up.png")
const LEVER_DOWN: Texture2D = preload("res://assets/sprites/minigames/slot_lever_down.png")
const BTN_RED: Texture2D = preload("res://assets/sprites/minigames/slot_btn_red.png")
const BTN_YELLOW: Texture2D = preload("res://assets/sprites/minigames/slot_btn_yellow.png")
const BTN_GREEN: Texture2D = preload("res://assets/sprites/minigames/slot_btn_green.png")
const BTN_SPIN: Texture2D = preload("res://assets/sprites/minigames/slot_btn_spin.png")
const BTN_HOLD: Texture2D = preload("res://assets/sprites/minigames/slot_btn_hold.png")
const BULB_OFF: Texture2D = preload("res://assets/sprites/minigames/slot_bulb_off.png")
const BULB_ON: Texture2D = preload("res://assets/sprites/minigames/slot_bulb_on.png")
const COIN: Texture2D = preload("res://assets/sprites/minigames/coin_gold.png")

## Each symbol: its art, how many sit on each reel strip, and what three of
## them on the line pays.
const SYMBOLS := {
	"cherry": { art = preload("res://assets/sprites/minigames/slot_cherry.png"), count = 4, pays = 40 },
	"lemon": { art = preload("res://assets/sprites/minigames/slot_lemon.png"), count = 4, pays = 50 },
	# The newer symbols' art is drawn bigger, so it's shown a little smaller.
	"grapes": { art = preload("res://assets/sprites/minigames/slot_grapes.png"), count = 3, pays = 60, zoom = 1.7 },
	"bell": { art = preload("res://assets/sprites/minigames/slot_bell.png"), count = 2, pays = 100 },
	"star": { art = preload("res://assets/sprites/minigames/prize_star.png"), count = 2, pays = 150 },
	"bar": { art = preload("res://assets/sprites/minigames/slot_bar.png"), count = 1, pays = 200, zoom = 1.7 },
	"seven": { art = preload("res://assets/sprites/minigames/slot_seven.png"), count = 1, pays = 300, zoom = 1.7 },
	"money": { art = preload("res://assets/sprites/minigames/slot_money.png"), count = 1, pays = 500 },
}
## Smaller wins: any pair on the line pays a fifth of that symbol's three, and
## a cherry on the first reel pays a little.
const PAIR_SHARE := 0.2
const ONE_CHERRY := 5

const SPINS := 5
const REEL_X := [70.0, 180.0, 290.0]
const REEL_Y := 168.0
## Distance between symbols on a reel, and how many show (three rows).
const STEP := 80.0
const SYMBOL_ZOOM := 2.0
const SPIN_SPEED := 0.32
## Frames before each reel stops on its own.
const AUTO_STOP := [50, 72, 94]
const BUTTON_Y := 362.0
const SPIN_AT := Vector2(140, 424)
const LEVER_AT := Vector2(300, 406)
const LABEL := Color(0.05, 0.03, 0.09)
const BULBS := 11

enum State { IDLE, SPINNING, NUDGING }

var strips: Array = []
## Each reel's position along its strip (in symbols), whether it's spinning,
## held, and its stop animation.
var reels: Array[Dictionary] = []
var state := State.IDLE
var spins_left := SPINS
var nudges := 0
var held_last := false
var msg := ""
var _frame := 0
var _spin_t := 0
var _win_t := 0
var _coins: Array[Dictionary] = []
var _lever_from := -1.0
var _lever_pull := 0.0


func _setup() -> void:
	for r in 3:
		var strip: Array[String] = []
		for symbol: String in SYMBOLS:
			for k in SYMBOLS[symbol].count:
				strip.append(symbol)
		strip.shuffle()
		strips.append(strip)
		reels.append({ pos = float(randi() % strip.size()), spinning = false, held = false, bounce = 0.0 })


## The symbol on a reel's line (or `row` rows below it).
func symbol_at(r: int, row := 0) -> String:
	var strip: Array = strips[r]
	return strip[posmod(roundi(reels[r].pos) + row, strip.size())]


func _pointer_pressed(at: Vector2) -> void:
	if at.distance_to(LEVER_AT + Vector2(0, -30)) < 40 and state == State.IDLE:
		_lever_from = at.y
		return
	if at.distance_to(SPIN_AT) < 40:
		_spin()
		return
	for r in 3:
		var button := Rect2(REEL_X[r] - 34, BUTTON_Y - 26, 68, 52)
		var window := Rect2(REEL_X[r] - 48, REEL_Y - 128, 96, 256)
		if button.has_point(at) or (state == State.SPINNING and window.has_point(at)):
			_reel_button(r)
			return


func _pointer_moved(at: Vector2) -> void:
	if _lever_from >= 0:
		_lever_pull = clampf((at.y - _lever_from) / 50.0, 0.0, 1.0)
		if _lever_pull >= 1.0:
			_lever_from = -1
			_spin()


func _pointer_released(_at: Vector2) -> void:
	_lever_from = -1
	_lever_pull = 0.0


func _key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE, KEY_ENTER:
			if state == State.SPINNING:
				for r in 3:
					if reels[r].spinning:
						_reel_button(r)
						break
			else:
				_spin()
		KEY_1, KEY_2, KEY_3:
			_reel_button(event.keycode - KEY_1)


## A reel's button: STOP while spinning, NUDGE when nudges are on offer,
## otherwise HOLD.
func _reel_button(r: int) -> void:
	match state:
		State.SPINNING:
			if reels[r].spinning and _spin_t > 12:
				_stop(r)
		State.NUDGING:
			reels[r].pos += 1
			reels[r].bounce = 0.4
			nudges -= 1
			Sfx.play(&"sl_stop")
			if _pay() > 0 or nudges <= 0:
				_spin_over()
		State.IDLE:
			if not held_last and spins_left < SPINS:
				var held := reels.filter(func(x: Dictionary) -> bool: return x.held).size()
				if reels[r].held or held < 2:
					reels[r].held = not reels[r].held
					play_hit()


func _spin() -> void:
	if state != State.IDLE or spins_left <= 0:
		return
	spins_left -= 1
	state = State.SPINNING
	_spin_t = 0
	held_last = reels.any(func(x: Dictionary) -> bool: return x.held)
	msg = ""
	_win_t = 0
	for reel in reels:
		reel.spinning = not reel.held
	_lever_pull = 1.0
	Sfx.play(&"sl_pull")


func _stop(r: int) -> void:
	var reel: Dictionary = reels[r]
	reel.spinning = false
	reel.pos = ceilf(reel.pos)
	reel.bounce = 0.5
	Sfx.play(&"sl_stop")
	if not reels.any(func(x: Dictionary) -> bool: return x.spinning):
		_spin_over()


## The reels have stopped: pay the line, maybe offer nudges, then free the holds.
func _spin_over() -> void:
	var points := _pay()
	if points > 0:
		score += points
		msg = _win_name() + "  +%d" % points
		_win_t = 120 if points >= 300 else 70
		_shower(12 if points < 300 else 40)
		Sfx.play(&"sl_jackpot" if points >= 300 else &"sl_win")
		nudges = 0
	elif state == State.SPINNING and spins_left > 0 and randf() < 0.3:
		# Sometimes the machine offers nudges after a losing spin.
		nudges = randi_range(1, 3)
		msg = "%d NUDGE%s!" % [nudges, "" if nudges == 1 else "S"]
		state = State.NUDGING
		Sfx.play(&"sl_nudge")
		return
	else:
		msg = "NO LUCK" if state == State.SPINNING else "OUT OF NUDGES"
	nudges = 0
	state = State.IDLE
	for reel in reels:
		reel.held = false
	if spins_left <= 0:
		end_round("BIG WINNER!" if score >= star_scores[1] else "ALL SPUN!", score > 0)


## What the line pays right now.
func _pay() -> int:
	var line := [symbol_at(0), symbol_at(1), symbol_at(2)]
	if line[0] == line[1] and line[1] == line[2]:
		return SYMBOLS[line[0]].pays
	for symbol: String in SYMBOLS:
		if line.count(symbol) == 2:
			return roundi(SYMBOLS[symbol].pays * PAIR_SHARE)
	if line[0] == "cherry":
		return ONE_CHERRY
	return 0


func _win_name() -> String:
	var line := [symbol_at(0), symbol_at(1), symbol_at(2)]
	if line[0] == line[1] and line[1] == line[2]:
		return "JACKPOT!" if line[0] == "money" else "THREE %sS" % line[0].to_upper()
	for symbol: String in SYMBOLS:
		if line.count(symbol) == 2:
			return "PAIR OF %sS" % symbol.to_upper()
	return "CHERRY"


func _shower(count: int) -> void:
	for i in count:
		_coins.append({ at = Vector2(randf_range(30, 330), randf_range(-60, 0)), v = Vector2(randf_range(-1.2, 1.2), randf_range(0, 2)), spin = randf() * TAU })


func _tick() -> void:
	_frame += 1
	if state == State.SPINNING:
		_spin_t += 1
		for r in 3:
			if reels[r].spinning:
				reels[r].pos += SPIN_SPEED
				if _spin_t >= AUTO_STOP[r] and (r == 0 or not reels[r - 1].spinning):
					_stop(r)
		if _spin_t % 5 == 0 and state == State.SPINNING:
			Sfx.play(&"sl_tick")
	for reel in reels:
		reel.bounce = move_toward(reel.bounce, 0.0, 0.06)
	_lever_pull = move_toward(_lever_pull, 0.0, 0.05) if _lever_from < 0 else _lever_pull
	_win_t = maxi(0, _win_t - 1)
	for coin in _coins.duplicate():
		coin.v.y += 0.25
		coin.at += coin.v
		coin.spin += 0.2
		if coin.at.y > BOARD.y + 20:
			_coins.erase(coin)


func _draw_board() -> void:
	board.draw_texture_rect(BACKDROP, Rect2(Vector2.ZERO, BOARD), false)
	# Bulbs above and below the reels; they chase faster while you're winning.
	var chase := int(_frame / (3.0 if _win_t > 0 else 10.0))
	for i in BULBS:
		var x := 22.0 + i * (BOARD.x - 44) / (BULBS - 1)
		for y in [24.0, 306.0]:
			var lit := (i + chase) % 3 == 0 or (_win_t > 0 and (i + chase) % 2 == 0)
			sprite(BULB_ON if lit else BULB_OFF, Vector2(x, y), 0.75)
	for r in 3:
		_draw_reel(r)
	# The pay line.
	sprite(BULB_ON, Vector2(8, REEL_Y), 0.6)
	sprite(BULB_ON, Vector2(BOARD.x - 8, REEL_Y), 0.6)
	if msg:
		text(msg, Vector2(BOARD.x / 2, 334), 16, GOLD if _win_t > 0 else CREAM)
	for r in 3:
		# STOP while spinning, NUDGE when offered, otherwise HOLD (its art says so).
		var label := "STOP"
		var art := BTN_RED
		if state == State.NUDGING:
			label = "NUDGE"
			art = BTN_GREEN
		elif state == State.IDLE:
			label = "HELD" if reels[r].held else ""
			art = BTN_YELLOW if reels[r].held else BTN_HOLD
		var dim: bool = state == State.IDLE and (held_last or spins_left == SPINS) and not reels[r].held
		sprite(art, Vector2(REEL_X[r], BUTTON_Y), 2.0, 0.0, false, Color(0.5, 0.5, 0.55) if dim else Color.WHITE)
		if label:
			text(label, Vector2(REEL_X[r], BUTTON_Y + 5), 11, LABEL)
	sprite(BTN_SPIN, SPIN_AT, 2.5, 0.0, false, Color.WHITE if state == State.IDLE else Color(0.5, 0.5, 0.55))
	sprite(LEVER_DOWN if _lever_pull > 0.5 else LEVER_UP, LEVER_AT + Vector2(0, _lever_pull * 8), 2.5)
	for coin in _coins:
		sprite(COIN, coin.at, 1.0, coin.spin)
	draw_pops(0.4, 11)


func _draw_reel(r: int) -> void:
	var x: float = REEL_X[r]
	board.draw_texture_rect(REEL, Rect2(x - 48, REEL_Y - 128, 96, 256), false)
	var reel: Dictionary = reels[r]
	var pos: float = reel.pos + sin(reel.bounce * PI * 2.0) * reel.bounce * 0.3
	var frac := pos - floorf(pos)
	# Only whole symbols inside the window are drawn (no clipping on a canvas).
	for k in range(-2, 3):
		var y := REEL_Y + (k - frac) * STEP
		if absf(y - REEL_Y) <= STEP * 1.5 - 8:
			var symbol: String = strips[r][posmod(floori(pos) + k, strips[r].size())]
			var c := Color.WHITE if absf(y - REEL_Y) < STEP / 2 else Color(0.75, 0.75, 0.8)
			sprite(SYMBOLS[symbol].art, Vector2(x, y), SYMBOLS[symbol].get("zoom", SYMBOL_ZOOM), 0.0, false, c)
	if reel.held:
		text("HELD", Vector2(x, REEL_Y - 108), 10, GOLD)


func _hud_text() -> String:
	return "SCORE %d    SPINS %d%s" % [score, maxi(0, spins_left), "    NUDGES %d" % nudges if nudges > 0 else ""]

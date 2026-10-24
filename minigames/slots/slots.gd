extends MiniGame
## Mega Jackpot: three spinning reels; tap to stop each in turn. A pair is +40,
## three of a kind +150, triple 7s +300. Three spins.

const SYMS := ["🍒", "🍋", "🔔", "⭐", "7"]
const STRIP := 12
const RW := 86.0
const RH := 64.0
const RY := 210.0
const RX := [BOARD.x / 2 - RW - 10, BOARD.x / 2, BOARD.x / 2 + RW + 10]

var reels: Array[Dictionary] = []
var stopping := 0
var spins := 3
var msg := ""
var _eval := 0


func _setup() -> void:
	_new_spin()


func _new_spin() -> void:
	reels.clear()
	for i in 3:
		var strip: Array[String] = []
		for k in STRIP:
			strip.append(SYMS[4 if randf() < 0.12 else randi() % 4])
		reels.append({ strip = strip, off = randf() * STRIP, speed = 0.22 + randf() * 0.05, stopped = false })
	stopping = 0
	msg = ""


func _symbol(reel: Dictionary, k := 0) -> String:
	return reel.strip[posmod(floori(reel.off) + k, STRIP)]


func _pointer_pressed(_at: Vector2) -> void:
	if _eval > 0 or stopping >= 3:
		return
	var reel := reels[stopping]
	reel.stopped = true
	reel.off = float(GameMath.js_round(reel.off) % STRIP)
	reel.speed = 0.0
	stopping += 1
	if stopping < 3:
		return
	var row := reels.map(func(r: Dictionary) -> String: return _symbol(r))
	var points := 0
	if row[0] == row[1] and row[1] == row[2]:
		points = 300 if row[0] == "7" else 150
	elif row[0] == row[1] or row[1] == row[2] or row[0] == row[2]:
		points = 40
	score += points
	msg = "💰 JACKPOT! +300" if points >= 300 else "TRIPLE! +150" if points >= 150 else "PAIR! +40" if points > 0 else "NO LUCK"
	_eval = 80
	spins -= 1


func _tick() -> void:
	for reel in reels:
		if not reel.stopped:
			reel.off += reel.speed
	if _eval > 0:
		_eval -= 1
		if _eval == 0:
			if spins <= 0:
				end_round("BIG WINNER!" if score >= 150 else "ALL SPUN!", score > 0)
			else:
				_new_spin()


func _draw_board() -> void:
	board.draw_rect(Rect2(20, 110, BOARD.x - 40, 240), Color("241a0e"))
	text("MEGA JACKPOT", Vector2(BOARD.x / 2, 138), 10, GOLD)
	for i in 3:
		var reel := reels[i]
		var x: float = RX[i]
		var window := Rect2(x - RW / 2, RY - RH * 1.5, RW, RH * 3)
		board.draw_rect(window, CREAM)
		# No clipping on a canvas, so only symbols wholly inside the window are drawn.
		var frac: float = reel.off - floorf(reel.off)
		for k in range(-2, 3):
			var y := RY + (k - frac) * RH
			if absf(y - RY) <= RH * 1.5 - 17:
				var symbol := _symbol(reel, k)
				if symbol == "7":
					text(symbol, Vector2(x, y + 12), 34, Color("222222"), ThemeDB.fallback_font)
				else:
					# Emoji sit a little low at this size; lift them onto the payline.
					glyph(symbol, Vector2(x, y - 7), 34)
		board.draw_rect(window, Color("06d6a0") if reel.stopped else Color("6b4a23"), false, 3.0)
	board.draw_line(Vector2(28, RY), Vector2(BOARD.x - 28, RY), Color("ff006e"), 2.0)
	if msg:
		text(msg, Vector2(BOARD.x / 2, 388), 12, DIM if msg.contains("NO") else Color("ffd166"))


func _hud_text() -> String:
	return "SCORE %d    SPINS %s" % [score, "●".repeat(maxi(0, spins))]

extends MiniGame
## Claw Grab: the claw swings; tap to drop it on the prize pile. Grip depends on
## how centred you are, and gold stars are slippery. Three drops.

enum Phase { SWING, DROP, RISE, CARRY }

const TOP := 70.0
const FLOOR := 380.0
const CHUTE := 36.0

const PRIZE_ART := {"🧸": preload("res://assets/sprites/minigames/prize_teddy.png"), "🐻": preload("res://assets/sprites/minigames/prize_bear.png"), "🐰": preload("res://assets/sprites/minigames/prize_bunny.png"), "⭐": preload("res://assets/sprites/minigames/prize_star.png")}

var prizes: Array[Dictionary] = []
var claw := Vector2(BOARD.x / 2, TOP)
var claw_open := 1.0
var holding := {}
var phase := Phase.SWING
var drops := 3
var _t := 0.0


func _setup() -> void:
	for i in 5:
		prizes.append({ x = 80 + i * 50 + (randf() - 0.5) * 16, value = 20, r = 12, emoji = "🧸" })
	prizes.append({ x = 120 + randf() * 60, value = 40, r = 14, emoji = "🐻" })
	prizes.append({ x = 210 + randf() * 60, value = 40, r = 14, emoji = "🐰" })
	prizes.append({ x = 90 + randf() * 180, value = 80, r = 10, emoji = "⭐" })
	_t = randf() * 6


func _pointer_pressed(_at: Vector2) -> void:
	if phase == Phase.SWING:
		phase = Phase.DROP


func _tick() -> void:
	match phase:
		Phase.SWING:
			_t += 0.03
			claw.x = BOARD.x / 2 + sin(_t) * 130
		Phase.DROP:
			claw.y += 3.4
			if claw.y >= FLOOR - 26:
				_grab()
				phase = Phase.RISE
				claw_open = 0.0
		Phase.RISE:
			claw.y -= 3
			if claw.y <= TOP:
				claw.y = TOP
				phase = Phase.CARRY
		Phase.CARRY:
			claw.x -= 3
			if claw.x <= CHUTE + 6:
				if not holding.is_empty():
					score += holding.value
					add_pop(Vector2(CHUTE + 20, 140), "+%d" % holding.value, 40)
					holding = {}
				claw_open = 1.0
				drops -= 1
				if drops <= 0:
					end_round("NICE GRABS!" if score > 0 else "EMPTY CLAW", score > 0)
				else:
					phase = Phase.SWING
					_t = randf() * 6


## Grab roll on the nearest prize: centred-ness × grip (gold is slippery).
func _grab() -> void:
	var nearest := {}
	var nearest_d := 1e9
	for p in prizes:
		var d := absf(claw.x - p.x)
		if d < 20 and d < nearest_d:
			nearest_d = d
			nearest = p
	if not nearest.is_empty() and randf() < (1 - nearest_d / 22) * (0.5 if nearest.value >= 80 else 0.9):
		holding = nearest
		prizes.erase(nearest)
	elif not nearest.is_empty():
		add_pop(Vector2(claw.x, FLOOR - 40), "SLIPPED!", 36, Color("888888"))
	else:
		miss(Vector2(claw.x, FLOOR - 40))


func _draw_board() -> void:
	board.draw_rect(Rect2(10, 40, BOARD.x - 20, FLOOR - 24), Color("1c1430"))
	board.draw_rect(Rect2(10, FLOOR, BOARD.x - 20, 30), Color("3a2c16"))
	board.draw_rect(Rect2(10, FLOOR - 24, CHUTE, 54), BG)
	text("WIN", Vector2(10 + CHUTE / 2, FLOOR + 20), 8, DIM)
	for p in prizes:
		sprite(PRIZE_ART[p.emoji], Vector2(p.x, FLOOR - p.r), p.r / 10.0)
	board.draw_line(Vector2(claw.x, 44), claw, Color("888888"), 2.0)
	var spread := 6 + claw_open * 8
	board.draw_line(claw, claw + Vector2(-spread, 16), GOLD, 4.0)
	board.draw_line(claw, claw + Vector2(spread, 16), GOLD, 4.0)
	if not holding.is_empty():
		sprite(PRIZE_ART[holding.emoji], claw + Vector2(0, 22), holding.r / 10.0)
	draw_pops(0.4, 11)


func _hud_text() -> String:
	return "SCORE %d    DROPS %s" % [score, "●".repeat(maxi(0, drops))]

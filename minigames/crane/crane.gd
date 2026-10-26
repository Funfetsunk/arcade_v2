extends MiniGame
## Prize Crane (overhead, unlike the side-view claw): tap to stop the X sweep, tap
## again to stop the Y sweep, and the crane drops on that cell. A direct hit is
## +40, next to a prize +10. Four drops.

enum Phase { SWEEP_X, SWEEP_Y, DROP }

const N := 4
const CELL := 64.0
const GRID := Vector2((BOARD.x - N * CELL) / 2, 110)
const PRIZE_EMOJI := ["🧸", "🎁", "🚗", "🦄", "🎀", "🍭"]

const PRIZE_ART := {"🧸": preload("res://assets/sprites/minigames/prize_teddy.png"), "🎁": preload("res://assets/sprites/minigames/prize_gift.png"), "🚗": preload("res://assets/sprites/minigames/prize_toycar.png"), "🦄": preload("res://assets/sprites/minigames/prize_unicorn.png"), "🎀": preload("res://assets/sprites/minigames/prize_bow.png"), "🍭": preload("res://assets/sprites/minigames/prize_lollipop.png")}

var prizes: Array[Dictionary] = []
var phase := Phase.SWEEP_X
var crane := GRID
var drops := 4
var _t := 0.0
var _drop_timer := 0


func _setup() -> void:
	while prizes.size() < 6:
		var cell := Vector2i(randi() % N, randi() % N)
		if not prizes.any(func(p: Dictionary) -> bool: return p.cell == cell):
			prizes.append({ cell = cell, emoji = PRIZE_EMOJI[prizes.size()] })
	_t = randf() * 6


func _pointer_pressed(_at: Vector2) -> void:
	if phase == Phase.SWEEP_X:
		phase = Phase.SWEEP_Y
		_t = randf() * 6
	elif phase == Phase.SWEEP_Y:
		phase = Phase.DROP
		_drop_timer = 30


func _cell_of(at: Vector2) -> Vector2i:
	return Vector2i(clampi(int((at.x - GRID.x) / CELL), 0, N - 1), clampi(int((at.y - GRID.y) / CELL), 0, N - 1))


func _tick() -> void:
	_t += 0.035
	var half := N * CELL / 2
	match phase:
		Phase.SWEEP_X:
			crane.x = GRID.x + half + sin(_t) * (half - 8)
		Phase.SWEEP_Y:
			crane.y = GRID.y + half + sin(_t) * (half - 8)
		Phase.DROP:
			_drop_timer -= 1
			if _drop_timer <= 0:
				_land()


func _land() -> void:
	var cell := _cell_of(crane)
	var hit := prizes.filter(func(p: Dictionary) -> bool: return p.cell == cell)
	var adjacent := prizes.filter(func(p: Dictionary) -> bool:
		return absi(p.cell.x - cell.x) + absi(p.cell.y - cell.y) == 1)
	if not hit.is_empty():
		score += 40
		prizes.erase(hit[0])
		add_pop(crane, "+40", 40)
	elif not adjacent.is_empty():
		score += 10
		add_pop(crane, "+10", 36)
	else:
		add_pop(crane, "MISS", 30, Color("888888"))
	drops -= 1
	if drops <= 0 or prizes.is_empty():
		end_round("PRIZES WON!" if score > 0 else "NO LUCK", score > 0)
	else:
		phase = Phase.SWEEP_X
		_t = randf() * 6
		crane.y = GRID.y


func _draw_board() -> void:
	var span := N * CELL
	board.draw_rect(Rect2(GRID - Vector2(8, 8), Vector2(span + 16, span + 16)), Color("1c1430"))
	for i in N + 1:
		board.draw_line(GRID + Vector2(i * CELL, 0), GRID + Vector2(i * CELL, span), Color("2a2a44"), 1.0)
		board.draw_line(GRID + Vector2(0, i * CELL), GRID + Vector2(span, i * CELL), Color("2a2a44"), 1.0)
	for p in prizes:
		sprite(PRIZE_ART[p.emoji], GRID + (Vector2(p.cell) + Vector2(0.5, 0.5)) * CELL, 1.3)
	board.draw_line(Vector2(crane.x, GRID.y - 18), Vector2(crane.x, GRID.y + span + 18), Color("6b4a23"), 3.0)
	if phase != Phase.SWEEP_X:
		board.draw_line(Vector2(GRID.x - 18, crane.y), Vector2(GRID.x + span + 18, crane.y), Color("6b4a23"), 3.0)
	var at := Vector2(crane.x, GRID.y - 18 if phase == Phase.SWEEP_X else crane.y)
	var s := 1.0 + _drop_timer / 30.0 if phase == Phase.DROP else 1.0
	board.draw_arc(at, 12 * s, 0, TAU, 24, GOLD, 2.0)
	board.draw_line(at - Vector2(16 * s, 0), at + Vector2(16 * s, 0), GOLD, 2.0)
	board.draw_line(at - Vector2(0, 16 * s), at + Vector2(0, 16 * s), GOLD, 2.0)
	draw_pops(0.4, 11)


func _hud_text() -> String:
	return "SCORE %d    DROPS %s" % [score, "●".repeat(maxi(0, drops))]

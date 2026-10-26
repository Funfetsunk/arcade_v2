extends MiniGame
## Light Gun: targets pop up in three ranks of a fairground gallery; tap them
## before they duck. Bystanders (the people) cost points. 25 s, getting faster.

## Ranks from the back: y, points, radius.
const RANKS := [[150.0, 20, 14.0], [220.0, 15, 17.0], [290.0, 10, 20.0]]
const SLOTS := [70.0, 150.0, 230.0, 310.0]
const ROUND := 25 * 60

const TARGET: Texture2D = preload("res://assets/sprites/minigames/target.png")
const CIVILIAN: Texture2D = preload("res://assets/sprites/minigames/civilian.png")

var targets: Array[Dictionary] = []
var time := ROUND
var _spawn := 0.0
var _flash := 0


func _pointer_pressed(at: Vector2) -> void:
	_flash = 4
	for t in targets:
		if t.hit or t.up <= 0:
			continue
		if at.distance_to(t.at) < t.r + 8:
			t.hit = true
			t.up = minf(t.up, 10)
			var points: int = -15 if t.civilian else t.points
			score = maxi(0, score + points)
			add_pop(t.at, ("+" if points > 0 else "") + str(points), 30, Color("ff006e") if t.civilian else Color("ffd166"))
			return
	miss(at, 18)


func _tick() -> void:
	time -= 1
	if time <= 0:
		end_round("CEASE FIRE!", score >= 120)
		return
	var ramp := 1.0 - float(time) / ROUND
	_spawn -= 1
	if _spawn <= 0:
		_spawn = 34 - ramp * 16 + randf() * 14
		var rank: Array = RANKS[randi() % 3]
		var slot: float = SLOTS.pick_random()
		var at := Vector2(slot, rank[0])
		if not targets.any(func(t: Dictionary) -> bool: return t.up > 0 and t.at == at):
			targets.append({ at = at, r = rank[2], points = rank[1], civilian = randf() < 0.12 + ramp * 0.1,
				up = 55 - ramp * 22 + randf() * 20, hit = false })
	for t in targets:
		if t.up > 0:
			t.up -= 1
	targets = targets.filter(func(t: Dictionary) -> bool: return t.up > 0)
	if _flash > 0:
		_flash -= 1


func _draw_board() -> void:
	board.draw_rect(Rect2(14, 100, BOARD.x - 28, 240), Color("241a0e"))
	for rank: Array in RANKS:
		board.draw_rect(Rect2(20, rank[0] + 10, BOARD.x - 40, 14), Color("3a2c16"))
	for t in targets:
		var rise := minf(1.0, t.up / 14.0)
		var at: Vector2 = t.at + Vector2(0, (1 - rise) * 18)
		var alpha := minf(1.0, rise + 0.3)
		var tint := Color(0.45, 0.45, 0.5, alpha) if t.hit else Color(1, 1, 1, alpha)
		sprite(CIVILIAN if t.civilian else TARGET, at, t.r / 10.0, 0.0, false, tint)
	if _flash > 0:
		board.draw_rect(Rect2(Vector2.ZERO, BOARD), Color(1, 1, 0.78, _flash * 0.04))
	draw_pops(0.5, 11)


func _hud_text() -> String:
	return "SCORE %d    TIME %d" % [score, ceili(maxi(0, time) / 60.0)]

extends MiniGame
## Car Crusher, the classic fighter bonus stage: mash-tap to wreck the car.
## Finishing one is a bonus, and a tougher one rolls in. 20 s.

const PAINTS := [Color("3a86ff"), Color("ff006e"), Color("06d6a0"), Color("ffb703"), Color("9a5aff")]
const CENTER := Vector2(BOARD.x / 2, 250)
const SLIDE := 55
const BODY := [Vector2(-120, 26), Vector2(-120, -8), Vector2(-70, -14), Vector2(-44, -44),
	Vector2(52, -44), Vector2(78, -14), Vector2(120, -8), Vector2(120, 26)]
const STEEL := Color("9aa0a8")

var wrecks := 0
var time := 20 * 60
var car := {}
var parts: Array[Dictionary] = []
var _slide := 0
var _shake := 0.0
var _fist := {}


func _setup() -> void:
	_new_car()


func _new_car() -> void:
	var hp := 120 + wrecks * 30
	car = { hp = hp, max = hp, paint = PAINTS[wrecks % PAINTS.size()], dents = [] }


func _pointer_pressed(at: Vector2) -> void:
	if _slide > 0:
		return
	car.hp -= 3
	score += 3
	_shake = 6.0
	var offset := Vector2(clampf(at.x - CENTER.x, -110, 110), clampf(at.y - CENTER.y, -40, 28))
	_fist = { at = CENTER + offset, t = 8 }
	if car.dents.size() < 24:
		car.dents.append({ at = offset, r = 4 + randf() * 5 })
	if car.hp <= 0:
		wrecks += 1
		score += 60
		_slide = SLIDE
		add_pop(Vector2(CENTER.x, 150), "WRECKED! +60", 56)
		# Wheels and bits fly off.
		for i in 8:
			parts.append({ at = CENTER + Vector2((randf() - 0.5) * 200, (randf() - 0.5) * 50),
				v = Vector2((randf() - 0.5) * 6, -3 - randf() * 4), wheel = i < 2, t = 60 })


func _tick() -> void:
	time -= 1
	if time <= 0:
		end_round("DEMOLISHED!" if wrecks > 0 else "TIME!", wrecks > 0)
		return
	if _shake > 0:
		_shake -= 0.6
	if not _fist.is_empty():
		_fist.t -= 1
		if _fist.t <= 0:
			_fist = {}
	if _slide > 0:
		_slide -= 1
		if _slide == 0:
			_new_car()
	for p in parts.duplicate():
		p.v += Vector2(0, 0.3)
		p.at += p.v
		p.t -= 1
		if p.t <= 0:
			parts.erase(p)


func _draw_board() -> void:
	var f: float = float(car.hp) / car.max
	board.draw_rect(Rect2(0, 300, BOARD.x, 40), Color("241a0e"))
	board.draw_rect(Rect2(0, 340, BOARD.x, BOARD.y - 340), Color("181208"))
	# The car: the wreck slides out and the next one in.
	var at := CENTER + Vector2(-float(_slide) / SLIDE * BOARD.x, 0)
	if _shake > 0:
		at += Vector2((randf() - 0.5) * _shake * 2, (randf() - 0.5) * _shake)
	board.draw_set_transform(at, (1 - f) * 0.06)
	board.draw_colored_polygon(PackedVector2Array(BODY), car.paint)
	# Windows crack below half health.
	var glass := Color("bfe3ef") if f > 0.5 else Color("8aa7b3")
	board.draw_colored_polygon(PackedVector2Array([Vector2(-38, -40), Vector2(0, -40), Vector2(0, -16), Vector2(-58, -16)]), glass)
	board.draw_colored_polygon(PackedVector2Array([Vector2(8, -40), Vector2(46, -40), Vector2(64, -16), Vector2(8, -16)]), glass)
	if f <= 0.5:
		var crack := Color("2a3a44")
		for seg in [[Vector2(-30, -38), Vector2(-16, -22)], [Vector2(-16, -22), Vector2(-28, -18)], [Vector2(-16, -22), Vector2(-6, -30)],
				[Vector2(30, -36), Vector2(22, -20)], [Vector2(22, -20), Vector2(36, -18)]]:
			board.draw_line(seg[0], seg[1], crack, 1.5)
	# The front bumper sags below 30%.
	if f <= 0.3:
		var sag := Transform2D(0.35, Vector2(96, 22))
		board.draw_colored_polygon(sag * PackedVector2Array([Vector2.ZERO, Vector2(34, 0), Vector2(34, 7), Vector2(0, 7)]), STEEL)
	else:
		board.draw_rect(Rect2(96, 20, 28, 7), STEEL)
	board.draw_rect(Rect2(-124, 20, 28, 7), STEEL)
	for d in car.dents:
		board.draw_circle(d.at, d.r, Color(0, 0, 0, 0.3))
	# Wheels, gone once it's wrecked.
	if _slide == 0 or car.hp > 0:
		for x in [-70, 70]:
			board.draw_circle(Vector2(x, 30), 18, Color("16161e"))
			board.draw_circle(Vector2(x, 30), 8, Color("55555f"))
	board.draw_set_transform(Vector2.ZERO)
	for p in parts:
		if p.wheel:
			board.draw_circle(p.at, 12, Color("16161e"))
		else:
			board.draw_rect(Rect2(p.at - Vector2(5, 3), Vector2(10, 6)), STEEL)
	if not _fist.is_empty():
		glyph("💥" if _fist.t > 4 else "👊", _fist.at, 34)
	# The car's health bar.
	board.draw_rect(Rect2(50, 60, BOARD.x - 100, 14), Color("241a0e"))
	var fill := Color("06d6a0") if f > 0.5 else GOLD if f > 0.25 else Color("ff006e")
	board.draw_rect(Rect2(50, 60, (BOARD.x - 100) * maxf(0, f), 14), fill)
	text("CAR", Vector2(BOARD.x / 2, 88), 8, DIM)
	draw_pops(0.4, 13)


func _hud_text() -> String:
	return "SCORE %d    WRECKS %d    TIME %d" % [score, wrecks, ceili(maxi(0, time) / 60.0)]

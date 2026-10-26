extends MiniGame
## Car Crusher, the classic fighter bonus stage: mash-tap to wreck the car.
## Finishing one is a bonus, and a tougher one rolls in. 20 s.

const CENTER := Vector2(BOARD.x / 2, 250)
const SLIDE := 55
const STEEL := Color("9aa0a8")

## The car as it takes damage: intact, dented, smashed, wrecked.
const CAR_STATES: Array[Texture2D] = [preload("res://assets/sprites/minigames/smash_car_1.png"),
	preload("res://assets/sprites/minigames/smash_car_2.png"), preload("res://assets/sprites/minigames/smash_car_3.png"),
	preload("res://assets/sprites/minigames/smash_car_4.png")]

const FIST: Texture2D = preload("res://assets/sprites/minigames/fist.png")
const BOOM: Texture2D = preload("res://assets/sprites/minigames/boom.png")

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
	car = { hp = hp, max = hp }


func _pointer_pressed(at: Vector2) -> void:
	if _slide > 0:
		return
	car.hp -= 3
	score += 3
	_shake = 6.0
	var offset := Vector2(clampf(at.x - CENTER.x, -110, 110), clampf(at.y - CENTER.y, -40, 28))
	_fist = { at = CENTER + offset, t = 8 }
	if car.hp <= 0:
		wrecks += 1
		score += 60
		_slide = SLIDE
		add_pop(Vector2(CENTER.x, 150), "WRECKED! +60", 56)
		# Bits fly off.
		for _i in 8:
			parts.append({ at = CENTER + Vector2((randf() - 0.5) * 200, (randf() - 0.5) * 50),
				v = Vector2((randf() - 0.5) * 6, -3 - randf() * 4), t = 60 })


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
	# The car: the wreck sits a moment, then slides out and the next one appears.
	var gone := maxf(0, 1 - float(_slide) / SLIDE - 0.4) / 0.6 if _slide > 0 else 0.0
	var at := CENTER + Vector2(gone * BOARD.x, 0)
	if _shake > 0:
		at += Vector2((randf() - 0.5) * _shake * 2, (randf() - 0.5) * _shake)
	var state := 3 if car.hp <= 0 else 2 if f <= 0.35 else 1 if f <= 0.7 else 0
	# Nudged down so the tyres sit on the ground.
	sprite(CAR_STATES[state], at + Vector2(0, 7), 2.0, (1 - f) * 0.06)
	for p in parts:
		board.draw_rect(Rect2(p.at - Vector2(5, 3), Vector2(10, 6)), STEEL)
	if not _fist.is_empty():
		sprite(BOOM if _fist.t > 4 else FIST, _fist.at, 1.5)
	# The car's health bar.
	board.draw_rect(Rect2(50, 60, BOARD.x - 100, 14), Color("241a0e"))
	var fill := Color("06d6a0") if f > 0.5 else GOLD if f > 0.25 else Color("ff006e")
	board.draw_rect(Rect2(50, 60, (BOARD.x - 100) * maxf(0, f), 14), fill)
	text("CAR", Vector2(BOARD.x / 2, 88), 8, DIM)
	draw_pops(0.4, 13)


func _hud_text() -> String:
	return "SCORE %d    WRECKS %d    TIME %d" % [score, wrecks, ceili(maxi(0, time) / 60.0)]

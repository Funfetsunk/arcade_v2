extends MiniGame
## Snap Booth: the subject wobbles in and out of focus; tap at peak sharpness.
## Five shots, then a photo strip.

const FACES := ["😀", "😜", "🤩", "😎", "🥳"]
const SHOTS := 5

var shot := 0
var results: Array[Dictionary] = []
var msg := ""
var _speed := 0.045
var _t := 0.0
var _flash := 0


func _setup() -> void:
	_t = randf() * 6


func _sharpness() -> float:
	return (sin(_t) + 1) / 2


func _pointer_pressed(_at: Vector2) -> void:
	if _flash > 0:
		return
	var s := _sharpness()
	var points := 50 if s > 0.95 else 35 if s > 0.85 else 20 if s > 0.7 else maxi(5, GameMath.js_round(s * 15))
	score += points
	results.append({ face = FACES[shot], points = points })
	msg = "PERFECT! +50" if points >= 50 else "GREAT! +35" if points >= 35 else "GOOD +20" if points >= 20 else "BLURRY +%d" % points
	_flash = 50
	shot += 1
	_speed += 0.012


func _tick() -> void:
	_t += _speed
	if _flash > 0:
		_flash -= 1
		if _flash == 0:
			if shot >= SHOTS:
				end_round("STRIP PRINTED!", score >= 120)
			else:
				_t = randf() * 6
				msg = ""


func _draw_board() -> void:
	var s := _sharpness()
	board.draw_rect(Rect2(50, 80, BOARD.x - 100, 240), Color("1c1430"))
	# The subject: faint ghost copies are the blur.
	var face: String = FACES[mini(shot, SHOTS - 1)]
	var blur := (1 - s) * 16
	for i in 5:
		var offset := Vector2.ZERO if i == 0 else Vector2(cos(i * 1.7 + _t * 3), sin(i * 2.3 + _t * 3)) * blur
		glyph(face, Vector2(BOARD.x / 2, 200) + offset, 80, Color(1, 1, 1, 1.0 if i == 0 else 0.22))
	# Focus meter, with the sweet spot boxed.
	var meter := Rect2(50, 340, BOARD.x - 100, 16)
	board.draw_rect(meter, Color("241a0e"))
	var fill := Color("06d6a0") if s > 0.85 else GOLD if s > 0.6 else Color("ff006e")
	board.draw_rect(Rect2(meter.position, Vector2(meter.size.x * s, meter.size.y)), fill)
	board.draw_rect(Rect2(50 + meter.size.x * 0.85, 338, meter.size.x * 0.15, 20), Color.WHITE, false, 1.0)
	text("FOCUS", Vector2(BOARD.x / 2, 372), 8, DIM)
	if _flash > 40:
		board.draw_rect(Rect2(Vector2.ZERO, BOARD), Color(1, 1, 1, (_flash - 40) / 10.0 * 0.8))
	if msg:
		text(msg, Vector2(BOARD.x / 2, 408), 11, Color("ffd166"))


## The photo strip under the score.
func _draw_results() -> void:
	const SW := 50.0
	var x := BOARD.x / 2 - (SHOTS * SW + 16) / 2
	var y := BOARD.y / 2 + 52
	board.draw_rect(Rect2(x, y, SHOTS * SW + 16, 64), CREAM)
	for i in results.size():
		var frame := Rect2(x + 8 + i * SW, y + 8, SW - 6, 48)
		board.draw_rect(frame, Color("cfe8d8") if results[i].points >= 35 else Color("d8cdb8"))
		glyph(results[i].face, frame.get_center(), 24)


func _hud_text() -> String:
	return "SCORE %d    SHOT %d/%d" % [score, mini(shot + 1, SHOTS), SHOTS]

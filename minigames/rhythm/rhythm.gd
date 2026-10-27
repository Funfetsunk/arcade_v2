extends MiniGame
## Riff Master (unlike the dance mat): two wide tracks with tap notes and hold
## notes. Tap a note on the line; press and ride a long note's tail for bonus
## ticks. 25 s.

const HIT_Y := 380.0
const TRACKS := 2
const TW := BOARD.x / TRACKS
const ROUND := 25 * 60
const NOTES := [330.0, 440.0]

const GEMS: Array[Texture2D] = [preload("res://assets/sprites/minigames/note_gem_blue.png"),
	preload("res://assets/sprites/minigames/note_gem.png")]

var notes: Array[Dictionary] = []
var combo := 0
var time := ROUND
var _holding: Array = [null, null]
var _glow: Array[int] = [0, 0]
var _spawn := 40.0


func _track_at(at: Vector2) -> int:
	return clampi(int(at.x / TW), 0, TRACKS - 1)


func _pointer_pressed(at: Vector2) -> void:
	var track := _track_at(at)
	_glow[track] = 8
	var nearest: Dictionary = {}
	var nearest_d := INF
	for n in notes:
		if n.track == track and not n.hit and absf(n.y - HIT_Y) < nearest_d:
			nearest_d = absf(n.y - HIT_Y)
			nearest = n
	var x := track * TW + TW / 2
	if not nearest.is_empty() and nearest_d < 16:
		nearest.hit = true
		combo += 1
		score += 12
		Sfx.beep(NOTES[track] * (1.5 if combo >= 6 else 1.0))
		add_pop(Vector2(x, HIT_Y + 34), "+12", 26, Color("06d6a0"))
		if nearest.tail > 0:
			_holding[track] = nearest
			nearest.hold_ticks = 0
	else:
		combo = 0
		miss(Vector2(x, HIT_Y + 34), 20)


func _pointer_released(at: Vector2) -> void:
	_holding[_track_at(at)] = null


func _tick() -> void:
	time -= 1
	if time <= 0:
		end_round("GIG OVER!", score >= 120)
		return
	_spawn -= 1
	if _spawn <= 0:
		_spawn = 42 - (1.0 - float(time) / ROUND) * 16 + randf() * 12
		notes.append({ track = randi() % TRACKS, y = BOARD.y + 20, hit = false,
			tail = 50 + randf() * 50 if randf() < 0.3 else 0.0, hold_ticks = 0 })
	for n in notes:
		n.y -= 3
		if not n.hit and n.y < HIT_Y - 30:
			n.hit = true
			combo = 0
	for track in TRACKS:
		var held: Variant = _holding[track]
		if held != null:
			# Ride the tail while it's still crossing the line.
			if held.y + held.tail > HIT_Y:
				held.hold_ticks += 1
				if held.hold_ticks % 6 == 0:
					score += 2
					if held.hold_ticks % 18 == 0:
						Sfx.beep(NOTES[track] * 2)
			else:
				_holding[track] = null
		_glow[track] = maxi(0, _glow[track] - 1)
	notes = notes.filter(func(n: Dictionary) -> bool: return n.y + n.tail > 30)


func _draw_board() -> void:
	for i in TRACKS:
		var lane := Rect2(i * TW, 0, TW, BOARD.y)
		board.draw_rect(lane, Color("161028") if i else Color("1a1430"))
		if _glow[i] > 0:
			board.draw_rect(lane, Color(1, 183 / 255.0, 3 / 255.0, _glow[i] * 0.045))
	board.draw_line(Vector2(12, HIT_Y), Vector2(BOARD.x - 12, HIT_Y), CREAM, 3.0)
	for n in notes:
		var x: float = n.track * TW + TW / 2
		var color := Color("ff006e") if n.track else Color("3a86ff")
		var held := is_same(_holding[n.track], n)
		if n.tail > 0:
			var tail := Color("ffd166") if n.hit and held else color
			tail.a = 0.5
			board.draw_rect(Rect2(x - 7, n.y, 14, n.tail), tail)
		if not n.hit or (n.tail > 0 and held):
			sprite(GEMS[n.track], Vector2(x, n.y))
	if combo >= 3:
		text("%d COMBO" % combo, Vector2(BOARD.x / 2, 60), 12, Color("ffd166"))
	draw_pops(0.0, 9)


func _hud_text() -> String:
	return "SCORE %d    COMBO %d    TIME %d" % [score, combo, ceili(maxi(0, time) / 60.0)]

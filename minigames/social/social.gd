extends MiniGame
## Trend Match: watch the trend flash up, then repeat it on the emoji pad.
## Trends grow from 3 to 6; one slip ends the run.

enum Phase { SHOW, INPUT, PAUSE }

const EMOJI := ["😀", "🔥", "💃", "👍", "😎", "💜"]
const COLS := 3
const PAD := Vector2(100, 84)
const GRID := Vector2((BOARD.x - COLS * 100) / 2, 250)
const ROUNDS := 4
## Frames allowed per step of the trend when repeating it.
const STEP_TIME := 150

const TREND_ART := {"😀": preload("res://assets/sprites/minigames/face_grin.png"), "🔥": preload("res://assets/sprites/minigames/social_fire.png"), "💃": preload("res://assets/sprites/minigames/social_dancer.png"), "👍": preload("res://assets/sprites/minigames/social_like.png"), "😎": preload("res://assets/sprites/minigames/face_cool.png"), "💜": preload("res://assets/sprites/minigames/social_heart.png")}

var trend_round := 0
var sequence: Array[int] = []
var phase := Phase.SHOW
var won := false
var msg := ""
var _show_index := 0
var _show_t := 0
var _input_index := 0
var _input_t := 0
var _flash := -1
var _flash_t := 0
var _wrong := -1


func _setup() -> void:
	_new_round()


func _new_round() -> void:
	trend_round += 1
	sequence.clear()
	for i in 2 + trend_round:
		sequence.append(randi() % EMOJI.size())
	phase = Phase.SHOW
	_show_index = 0
	_show_t = 40
	_input_index = 0
	msg = "TREND %d / %d" % [trend_round, ROUNDS]


func _pad_rect(i: int) -> Rect2:
	return Rect2(GRID + Vector2(i % COLS, floori(float(i) / COLS)) * PAD, PAD)


func _pointer_pressed(at: Vector2) -> void:
	if phase != Phase.INPUT:
		return
	var pad := -1
	for i in EMOJI.size():
		if _pad_rect(i).has_point(at):
			pad = i
	if pad < 0:
		return
	_flash = pad
	_flash_t = 8
	if pad != sequence[_input_index]:
		_wrong = pad
		end_round("FLOPPED!", false)
		return
	_input_index += 1
	if _input_index < sequence.size():
		return
	var points := 20
	if _input_t < sequence.size() * 45:
		points += 5 * sequence.size()
	score += points
	msg = "+%d VIRAL!" % points
	if trend_round >= ROUNDS:
		score += 50
		won = true
		end_round("GONE VIRAL!")
	else:
		phase = Phase.PAUSE
		_show_t = 50


func _tick() -> void:
	if _flash_t > 0:
		_flash_t -= 1
		if _flash_t == 0:
			_flash = -1
	match phase:
		Phase.SHOW:
			_show_t -= 1
			if _show_t <= 0:
				_show_index += 1
				if _show_index >= sequence.size():
					phase = Phase.INPUT
					_input_t = 0
				else:
					_show_t = 40
		Phase.INPUT:
			_input_t += 1
			if _input_t > sequence.size() * STEP_TIME:
				end_round("FLOPPED!", false)
		Phase.PAUSE:
			_show_t -= 1
			if _show_t <= 0:
				_new_round()


func _draw_board() -> void:
	var feed := Rect2(GRID.x, 60, COLS * PAD.x, 150)
	board.draw_rect(feed, Color("1c1430"))
	var mid := BOARD.x / 2
	match phase:
		Phase.SHOW:
			if _show_index < sequence.size():
				sprite(TREND_ART[EMOJI[sequence[_show_index]]], Vector2(mid, 135), 3.2)
				text("%d / %d" % [_show_index + 1, sequence.size()], Vector2(mid, 199), 8, DIM)
		Phase.INPUT:
			text("YOUR TURN!", Vector2(mid, 124), 11, Color("06d6a0"))
			text("%d / %d" % [_input_index, sequence.size()], Vector2(mid, 153), 9, DIM)
			var left := 1.0 - float(_input_t) / (sequence.size() * STEP_TIME)
			var bar := Rect2(feed.position.x + 20, 180, feed.size.x - 40, 8)
			board.draw_rect(bar, Color("241a0e"))
			board.draw_rect(Rect2(bar.position, Vector2(bar.size.x * maxf(0, left), bar.size.y)), Color("06d6a0") if left > 0.3 else Color("ff006e"))
		Phase.PAUSE:
			text(msg, Vector2(mid, 139), 12, Color("ffd166"))
	for i in EMOJI.size():
		var rect := _pad_rect(i).grow(-4)
		board.draw_rect(rect, Color("b3324f") if i == _wrong else Color("3a3a6e") if i == _flash else Color("241a3a"))
		board.draw_rect(rect, Color("3a3a55"), false, 1.0)
		sprite(TREND_ART[EMOJI[i]], rect.get_center(), 1.7)


func _hud_text() -> String:
	return "SCORE %d    TREND %d/%d" % [score, trend_round, ROUNDS]

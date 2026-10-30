extends MiniGame
## Snap Booth, a real photo booth: five customers step in one after another and
## won't keep still. They sway about, blink, sneeze, look away, pull faces and
## now and then strike their best pose. Tap to take the photo when they're
## centred and at their best, before the booth's countdown takes it for you.
## A pet sometimes photobombs (which is a bonus). Every shot prints on the
## photo strip.

const BACKDROP: Texture2D = preload("res://assets/sprites/minigames/snap_backdrop.png")
const VIEWFINDER: Texture2D = preload("res://assets/sprites/minigames/snap_corner.png")
const FLASH: Texture2D = preload("res://assets/sprites/minigames/snap_flash.png")
const FRAME: Texture2D = preload("res://assets/sprites/minigames/snap_frame.png")
## The polaroid's photo window, from the frame's centre.
const WINDOW := Rect2(-21.5, -23.5, 42, 38)

## Each customer's poses. "best" is the one to catch.
const CUSTOMERS: Array[Dictionary] = [
	{ smile = preload("res://assets/sprites/minigames/snap_girl_smile.png"), blink = preload("res://assets/sprites/minigames/snap_girl_blink.png"),
		best = preload("res://assets/sprites/minigames/snap_girl_peace.png"), silly = preload("res://assets/sprites/minigames/snap_girl_tongue.png"),
		sneeze = preload("res://assets/sprites/minigames/snap_girl_sneeze.png"), away = preload("res://assets/sprites/minigames/snap_girl_away.png") },
	{ smile = preload("res://assets/sprites/minigames/snap_boy_smile.png"), blink = preload("res://assets/sprites/minigames/snap_boy_blink.png"),
		best = preload("res://assets/sprites/minigames/snap_boy_thumbs.png"), silly = preload("res://assets/sprites/minigames/snap_boy_silly.png"),
		sneeze = preload("res://assets/sprites/minigames/snap_boy_sneeze.png"), away = preload("res://assets/sprites/minigames/snap_boy_away.png") },
	{ smile = preload("res://assets/sprites/minigames/snap_grandpa_smile.png"), blink = preload("res://assets/sprites/minigames/snap_grandpa_blink.png"),
		best = preload("res://assets/sprites/minigames/snap_grandpa_wave.png"), silly = preload("res://assets/sprites/minigames/snap_grandpa_silly.png"),
		sneeze = preload("res://assets/sprites/minigames/snap_grandpa_sneeze.png"), away = preload("res://assets/sprites/minigames/snap_grandpa_away.png") },
	{ smile = preload("res://assets/sprites/minigames/snap_punk_smile.png"), blink = preload("res://assets/sprites/minigames/snap_punk_blink.png"),
		best = preload("res://assets/sprites/minigames/snap_punk_rock.png"), silly = preload("res://assets/sprites/minigames/snap_punk_silly.png"),
		sneeze = preload("res://assets/sprites/minigames/snap_punk_sneeze.png"), away = preload("res://assets/sprites/minigames/snap_punk_away.png") },
]
const PETS: Array[Texture2D] = [
	preload("res://assets/sprites/minigames/snap_dog.png"),
	preload("res://assets/sprites/minigames/snap_cat.png"),
	preload("res://assets/sprites/minigames/snap_pigeon.png"),
]
## What a photo of each pose is worth, and its caption.
const POSES := {
	&"best": { pays = 50, says = "BEST POSE!" },
	&"silly": { pays = 30, says = "FUNNY FACE!" },
	&"smile": { pays = 20, says = "NICE" },
	&"away": { pays = 5, says = "LOOKING AWAY" },
	&"blink": { pays = 0, says = "EYES SHUT!" },
	&"sneeze": { pays = 0, says = "ACHOO!" },
}
const SHOTS := 5
## Frames the booth counts down before it takes the photo itself.
const COUNTDOWN := 4 * 60
const STEP_IN := 30
const SHOW := 70
const PHOTOBOMB := 25
## The viewfinder, and where the customer stands in it.
const VIEW := Rect2(20, 14, 320, 326)
const STAND := Vector2(BOARD.x / 2, 340)
const ZOOM := 4.2
## How far off centre still counts as centred.
const CENTRED := 70.0

var shot := 0
## The photos so far: pose art, how far off centre, pet, points.
var photos: Array[Dictionary] = []
var who: Dictionary = {}
var pose := &"smile"
var _pose_t := 0
var _clock := 0
var _sway := 0.0
var _sway_speed := 0.03
var _step := 0
var _show := 0
var _pet: Texture2D = null
var _pet_t := 0
var _pet_left := false
var _order: Array[int] = []


func _setup() -> void:
	for i in SHOTS:
		var pick := randi() % CUSTOMERS.size()
		while not _order.is_empty() and pick == _order[-1]:
			pick = randi() % CUSTOMERS.size()
		_order.append(pick)
	_next_customer()


func _next_customer() -> void:
	who = CUSTOMERS[_order[shot]]
	pose = &"smile"
	_pose_t = 40
	_clock = COUNTDOWN
	_step = STEP_IN
	_sway = randf() * TAU
	_sway_speed = 0.025 + shot * 0.006
	_pet = null


## How far the customer is from the middle of the frame right now.
func off_centre() -> float:
	return sin(_sway) * 60 + sin(_sway * 2.3 + 1.0) * 25


func _pointer_pressed(_at: Vector2) -> void:
	if _show == 0 and _step == 0 and not over:
		_snap()


## Takes the photo. If the booth's countdown took it (you were too slow), it
## only counts for half, and a photobomb earns nothing.
func _snap(timed_out := false) -> void:
	var info: Dictionary = POSES[pose]
	var off := absf(off_centre())
	var centred := clampf(1.0 - off / (CENTRED * 2.0), 0.0, 1.0)
	var points := int(round(info.pays * (0.4 + 0.6 * centred) * (0.5 if timed_out else 1.0)))
	var bombed := _pet != null and _pet_t > 10
	if bombed and not timed_out:
		points += PHOTOBOMB
	score += points
	var says: String = info.says
	if pose == &"best" and off < CENTRED * 0.5:
		says = "PERFECT!"
	photos.append({ art = who[pose], off = off_centre(), pet = _pet if bombed else null, pet_left = _pet_left, points = points })
	if timed_out:
		says = "TOO SLOW! " + says
	add_pop(Vector2(BOARD.x / 2, 64), "%s +%d" % [says, points] if points > 0 else says, SHOW, GOLD if points >= 40 else CREAM)
	if bombed and not timed_out:
		add_pop(Vector2(BOARD.x / 2, 90), "PHOTOBOMB! +%d" % PHOTOBOMB, SHOW, PINK)
	_show = SHOW
	Sfx.play(&"sn_shutter")


func _tick() -> void:
	if _show > 0:
		_show -= 1
		if _show == SHOW - 20:
			Sfx.play(&"sn_print")
		if _show == 0:
			shot += 1
			if shot >= SHOTS:
				end_round("STRIP PRINTED!", score >= star_scores[0])
				return
			_next_customer()
		return
	if _step > 0:
		_step -= 1
		return
	_sway += _sway_speed
	_clock -= 1
	if _clock % 60 == 0 and _clock > 0 and _clock <= 180:
		Sfx.play(&"sn_beep")
	if _clock <= 0:
		_snap(true)
		return
	_pose_t -= 1
	if _pose_t <= 0:
		_pick_pose()
	if _pet != null:
		_pet_t -= 1
		if _pet_t <= 0:
			_pet = null
	elif randf() < 0.0025:
		_pet = PETS.pick_random()
		_pet_t = 70
		_pet_left = randf() < 0.5
		Sfx.play(&"sn_pop")


## The customer's next pose, and for how long: their best pose is brief, and
## briefer for later customers.
func _pick_pose() -> void:
	var roll := randf()
	if pose != &"smile":
		pose = &"smile"
		_pose_t = randi_range(20, 50)
	elif roll < 0.3:
		pose = &"best"
		_pose_t = randi_range(32, 48) - shot * 4
	elif roll < 0.5:
		pose = &"blink"
		_pose_t = 9
	elif roll < 0.65:
		pose = &"silly"
		_pose_t = randi_range(25, 40)
	elif roll < 0.82:
		pose = &"away"
		_pose_t = randi_range(25, 45)
	else:
		pose = &"sneeze"
		_pose_t = 30


func _draw_board() -> void:
	board.draw_texture_rect(BACKDROP, Rect2(Vector2.ZERO, BOARD), false)
	if not over:
		var slide := float(_step) / STEP_IN
		var at := STAND + Vector2(off_centre() + slide * 260.0, 0)
		var art: Texture2D = who[pose]
		_draw_subject(art, at, ZOOM)
		if _pet != null:
			var peek := clampf(minf(70 - _pet_t, _pet_t) / 12.0, 0.0, 1.0)
			var side := -1.0 if _pet_left else 1.0
			sprite(_pet, Vector2(BOARD.x / 2 + side * (210 - peek * 80), 300), 2.6, 0.0, _pet_left)
		sprite(VIEWFINDER, VIEW.get_center(), VIEW.size.x / 58.0)
		if _step == 0 and _show == 0 and _clock <= 180:
			text(str(ceili(_clock / 60.0)), Vector2(BOARD.x - 44, 44), 28, PINK)
		if _show > SHOW - 14:
			var k := float(_show - (SHOW - 14)) / 14.0
			sprite(FLASH, VIEW.get_center(), 9.0 * k, 0.0, false, Color(1, 1, 1, k))
		_draw_strip(Vector2(BOARD.x / 2, 404), 1.1)
		draw_pops(0.3, 16)


## The customer, standing at the bottom of the frame.
func _draw_subject(art: Texture2D, at: Vector2, zoom: float) -> void:
	sprite(art, at - Vector2(0, art.get_height() * zoom / 2.0), zoom)


## The photo strip: a polaroid per shot, each with its photo printed in it.
func _draw_strip(centre: Vector2, zoom: float) -> void:
	var gap := 62.0 * zoom
	for i in SHOTS:
		var at := centre + Vector2((i - (SHOTS - 1) / 2.0) * gap, 0)
		sprite(FRAME, at, zoom)
		if i >= photos.size():
			continue
		var photo := photos[i]
		# The newest photo develops: it fades in as it prints.
		var dev := 1.0 if i < photos.size() - 1 or _show == 0 else clampf(1.0 - (_show - 20) / 40.0, 0.0, 1.0)
		var tint := Color(1, 1, 1, dev)
		var window := Rect2(at + WINDOW.position * zoom, WINDOW.size * zoom)
		board.draw_texture_rect_region(BACKDROP, window, Rect2(40, 60, 100, 90), tint)
		var art: Texture2D = photo.art
		var k := window.size.y / art.get_height()
		var shift := clampf(photo.off * 0.12 * zoom, -window.size.x * 0.2, window.size.x * 0.2)
		sprite(art, Vector2(window.get_center().x + shift, window.end.y - art.get_height() * k / 2.0), k, 0.0, false, tint)
		if photo.pet != null:
			var side := -1.0 if photo.pet_left else 1.0
			sprite(photo.pet, Vector2(window.get_center().x + side * window.size.x * 0.32, window.end.y - 8 * zoom), k * 0.6, 0.0, photo.pet_left, tint)


## The strip, big, on the results screen.
func _draw_results() -> void:
	_draw_strip(Vector2(BOARD.x / 2, BOARD.y / 2 + 120), 1.1)


func _hud_text() -> String:
	return "SCORE %d    PHOTO %d/%d" % [score, mini(shot + 1, SHOTS), SHOTS]

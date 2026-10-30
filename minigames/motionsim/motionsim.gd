extends MiniGame
## Motion Sim, a rollercoaster ride in the motion pod, seen from the front seat.
## Slide your finger left and right to lean into the banked turns; leaning the
## wrong way fills your queasy meter. Slide it up to throw your hands in the air
## on the big drops for thrills (but hands up in a turn makes you queasy too),
## and lean to grab the golden tickets along the way. Too queasy and the ride
## stops early. 45 s.

const SKY: Texture2D = preload("res://assets/sprites/minigames/coaster_sky.png")
const SLEEPER: Texture2D = preload("res://assets/sprites/minigames/coaster_sleeper.png")
const RAIL: Texture2D = preload("res://assets/sprites/minigames/coaster_rail.png")
const PILLAR: Texture2D = preload("res://assets/sprites/minigames/coaster_pillar.png")
const HANDS_BAR: Texture2D = preload("res://assets/sprites/minigames/coaster_hands_bar.png")
const HANDS_UP: Texture2D = preload("res://assets/sprites/minigames/coaster_hands_up.png")
const TICKET: Texture2D = preload("res://assets/sprites/minigames/coaster_ticket.png")
const STAR_ITEM: Texture2D = preload("res://assets/sprites/minigames/coaster_star.png")
const QUEASY: Texture2D = preload("res://assets/sprites/minigames/coaster_queasy.png")
const HAPPY: Texture2D = preload("res://assets/sprites/minigames/coaster_scream.png")
## Things standing beside the track.
const SCENERY: Array[Texture2D] = [
	preload("res://assets/sprites/minigames/coaster_tree.png"),
	preload("res://assets/sprites/minigames/coaster_tree.png"),
	preload("res://assets/sprites/minigames/coaster_tent.png"),
	preload("res://assets/sprites/minigames/coaster_flag.png"),
	preload("res://assets/sprites/minigames/coaster_balloon.png"),
]

const RIDE := 45 * 60
const FINISH_BONUS := 100
const TICKET_PAYS := 30
const STAR_PAYS := 50
## Projection: the middle of the view, the horizon, the focal length, and
## how many track segments ahead are drawn.
const CENTER := Vector2(BOARD.x / 2, 230)
const HORIZON := 190.0
const FOCAL := 230.0
const SEG := 10.0
const AHEAD := 60
## How sharply curves turn, the rider's eye height above the track, the track's
## half width, how far a full lean moves you across it, and the rails' offset.
const CURVE_K := 0.9
const EYE := 9.0
const LANE := 3.6
const RAIL_AT := 4.0
const GROUND := -20.0

## The track, one entry per segment: how it bends, and its height.
var curve: PackedFloat32Array = []
var height: PackedFloat32Array = []
## Tickets and stars to grab: segment, lane offset, kind.
var items: Array[Dictionary] = []
var pos := 0.0
var speed := 0.3
var lean := 0.0
var hands_up := false
var queasy := 0.0
var time := RIDE
var _aim := 0.0
var _roll := 0.0
var _tick_n := 0
var _clank := 0
var _was_drop := false


func _setup() -> void:
	curve.append(0.0)
	height.append(10.0)
	_add(30, 0.0, 0.0)
	while curve.size() < AHEAD + 20:
		_extend()


## Adds a stretch of track: how many segments, how it bends, and how much it
## climbs per segment.
func _add(count: int, bend: float, climb: float) -> void:
	for i in count:
		curve.append(bend)
		height.append(maxf(4.0, height[-1] + climb))


func _extend() -> void:
	var start := curve.size()
	var roll := randf()
	if roll < 0.3:
		var bend := randf_range(0.5, 1.0) * (1.0 if randf() < 0.5 else -1.0)
		_add(10, bend * 0.5, 0.0)
		_add(20, bend, 0.0)
		_add(10, bend * 0.5, 0.0)
	elif roll < 0.55:
		# The lift hill and the big drop.
		_add(30, 0.0, 2.2)
		_add(18, 0.0, -4.2)
		_add(10, 0.0, 0.6)
		items.append({ seg = start + 44, lane = 0.0, kind = &"star" })
	elif roll < 0.8:
		for i in 3:
			_add(8, 0.0, 1.6)
			_add(8, 0.0, -1.6)
	else:
		_add(20, 0.0, 0.0)
	# Tickets along the new stretch, off to one side so you lean for them: on a
	# bend they hang on the side it banks to.
	for k in 2:
		var seg := start + 8 + k * 12
		if seg < curve.size():
			var side := signf(curve[seg]) if absf(curve[seg]) > 0.3 else (1.0 if randf() < 0.5 else -1.0)
			items.append({ seg = seg, lane = side * LANE, kind = &"ticket" })


func slope_at(i: int) -> float:
	return height[mini(i + 1, height.size() - 1)] - height[i]


func _pointer_pressed(at: Vector2) -> void:
	_pointer_moved(at)


func _pointer_moved(at: Vector2) -> void:
	_aim = clampf((at.x - BOARD.x / 2) / 120.0, -1.0, 1.0)
	hands_up = at.y < 230


func _pointer_released(_at: Vector2) -> void:
	_aim = 0.0
	hands_up = false


func _tick() -> void:
	time -= 1
	if time <= 0:
		score += FINISH_BONUS
		end_round("WHAT A RIDE!", true)
		return
	lean = move_toward(lean, _aim, 0.08)
	var i := int(pos)
	var slope := slope_at(i)
	# Gravity: faster down the drops, slower up the lift hill.
	speed = clampf(speed - slope * 0.004 - (speed - 0.3) * 0.01, 0.15, 0.9)
	pos += speed
	while curve.size() < int(pos) + AHEAD + 20:
		_extend()
	var bank := curve[i]
	_roll = lerpf(_roll, -bank * 0.3 + lean * 0.08, 0.1)
	if slope > 1.0:
		_clank -= 1
		if _clank <= 0:
			_clank = 10
			Sfx.play(&"ms_clank")
	var dropping := slope < -2.0
	if dropping and not _was_drop:
		Sfx.play(&"ms_rush")
	_was_drop = dropping
	# Leaning with the bank scores; against it makes you queasy.
	var off := absf(lean - bank)
	_tick_n += 1
	if _tick_n >= 10:
		_tick_n = 0
		if absf(bank) > 0.2:
			score += 2 if off < 0.25 else (1 if off < 0.45 else 0)
	var sick := maxf(0.0, off - 0.5) * 0.8
	if hands_up and absf(bank) > 0.4:
		sick += 0.7
	if hands_up and dropping:
		score += 1
	queasy = clampf(queasy + sick - (0.35 if sick == 0.0 else 0.0), 0.0, 100.0)
	if queasy >= 100.0:
		Sfx.play(&"ms_queasy")
		end_round("FELT SICK!", false)
		return
	for it in items.duplicate():
		if it.seg <= pos:
			items.erase(it)
			if absf(it.lane - lean * LANE) < 2.6:
				var pays := STAR_PAYS if it.kind == &"star" else TICKET_PAYS
				score += pays
				Sfx.play(&"ms_ticket")
				add_pop(Vector2(BOARD.x / 2, 300), "+%d" % pays, 30, GOLD)


func _draw_board() -> void:
	var i0 := int(pos)
	var frac := pos - i0
	var cam_y := lerpf(height[i0], height[i0 + 1], frac) + EYE
	var pitch := slope_at(i0) / SEG * 0.5
	var roll := Transform2D(_roll, CENTER) * Transform2D(0.0, -CENTER)
	board.draw_set_transform_matrix(roll * Transform2D(0.0, Vector2(2.6, 2.6), 0.0, CENTER + Vector2(0, -20 + pitch * 160)))
	board.draw_texture(SKY, -SKY.get_size() / 2.0)
	# The track ahead, relative to the camera: bends accumulate as it goes.
	var pts: Array[Dictionary] = []
	var x := -lean * LANE * 0.6
	var dx := 0.0
	# From the next segment on, so nothing is ever behind the camera.
	for k in range(1, AHEAD):
		var j := i0 + k
		dx += curve[j] * CURVE_K
		x += dx
		var z := (k - frac) * SEG + 4.0
		var s := FOCAL / z
		var y: float = height[j] - cam_y - pitch * z
		pts.append({ j = j, x = x, s = s, y = y, z = z })
	for k in range(pts.size() - 1, 0, -1):
		var p: Dictionary = pts[k]
		var q: Dictionary = pts[k - 1]
		var j: int = p.j
		if j % 7 == 0:
			# Scenery on the ground either side, its base on the ground.
			var ground_y: float = GROUND - cam_y - pitch * p.z
			for side in [-1.0, 1.0]:
				var art: Texture2D = SCENERY[posmod(floori(j / 7.0) + int(side), SCENERY.size())]
				_world(art, _project(p, p.x + side * 26.0, ground_y + art.get_height() * 0.07), p.s * 0.14)
		if j % 4 == 0:
			_draw_pillar(p, cam_y, pitch)
		for side in [-RAIL_AT, RAIL_AT]:
			_draw_rail(_project(p, p.x + side, p.y), _project(q, q.x + side, q.y), p.s)
		_world(SLEEPER, _project(p, p.x, p.y), p.s * RAIL_AT * 2.6 / SLEEPER.get_width())
		for it in items:
			if it.seg == j:
				_world(STAR_ITEM if it.kind == &"star" else TICKET, _project(p, p.x + it.lane, p.y + 4.5), p.s * 0.1)
	board.draw_set_transform(Vector2.ZERO)
	_draw_rider()
	draw_pops(0.5, 18)


## A point in the camera's world to the screen, at a track point's distance.
func _project(p: Dictionary, wx: float, wy: float) -> Vector2:
	return Vector2(CENTER.x + wx * p.s, HORIZON - wy * p.s)


## Draws art centred on a screen point inside the rolled world.
func _world(art: Texture2D, at: Vector2, zoom: float) -> void:
	var roll := Transform2D(_roll, CENTER) * Transform2D(0.0, -CENTER)
	board.draw_set_transform_matrix(roll * Transform2D(0.0, Vector2(zoom, zoom), 0.0, at))
	board.draw_texture(art, -art.get_size() / 2.0)


## A rail from one track point to the next, the rail art stretched along it.
func _draw_rail(a: Vector2, b: Vector2, s: float) -> void:
	var along := b - a
	var roll := Transform2D(_roll, CENTER) * Transform2D(0.0, -CENTER)
	var width := maxf(1.0, s * 0.5)
	board.draw_set_transform_matrix(roll * Transform2D(along.angle() - PI / 2, Vector2(width / RAIL.get_width(), along.length() / RAIL.get_height()), 0.0, a))
	board.draw_texture(RAIL, Vector2(-RAIL.get_width() / 2.0, 0))


## A support from the track down to the ground.
func _draw_pillar(p: Dictionary, cam_y: float, pitch: float) -> void:
	var top := _project(p, p.x, p.y - 0.5)
	var ground_y: float = GROUND - cam_y - pitch * p.z
	var bottom := _project(p, p.x, ground_y)
	if bottom.y <= top.y:
		return
	var roll := Transform2D(_roll, CENTER) * Transform2D(0.0, -CENTER)
	var w: float = p.s * RAIL_AT * 1.6
	board.draw_set_transform_matrix(roll)
	board.draw_texture_rect(PILLAR, Rect2(top.x - w / 2.0, top.y, w, bottom.y - top.y), false)


## Your hands (on the lap bar or in the air) and how you're feeling.
func _draw_rider() -> void:
	if over:
		return
	var sway := Vector2(lean * 18.0, 0)
	if hands_up:
		sprite(HANDS_UP, Vector2(BOARD.x / 2, 404) + sway, 2.4)
	else:
		sprite(HANDS_BAR, Vector2(BOARD.x / 2, 438) + sway, 3.0)
	var face := QUEASY if queasy > 50.0 else HAPPY
	sprite(face, Vector2(30, 30), 0.8, 0.0, false, Color(1, 1, 1, 1))
	text("QUEASY %d%%" % int(queasy), Vector2(104, 30), 16, PINK if queasy > 50.0 else CREAM)
	if _was_drop:
		text("HANDS UP!" if not hands_up else "WHEEEE!", Vector2(BOARD.x / 2, 84), 24, PINK)


func _hud_text() -> String:
	return "SCORE %d    TIME %d" % [score, ceili(maxi(0, time) / 60.0)]

extends MiniGame
## Dot Maze: swipe (or use the arrow keys) to steer and eat every dot while
## dodging the ghost; the corner pellets turn the tables for a few seconds. 40 s.

const LAYOUT := [
	"#############",
	"#o....#....o#",
	"#.##..#..##.#",
	"#.....#.....#",
	"#.##.###.##.#",
	"#...........#",
	"#.##.###.##.#",
	"#.....#.....#",
	"#.##..#..##.#",
	"#o....#....o#",
	"#############",
]
const TS := 26.0
const ORIGIN := Vector2((BOARD.x - 13 * TS) / 2, 90)
const DIRS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
const KEYS := { KEY_RIGHT: 0, KEY_LEFT: 1, KEY_DOWN: 2, KEY_UP: 3 }
const GHOST_HOME := Vector2i(11, 5)
const SWIPE_MIN := 14.0

var grid: Array[Array] = []
var dots_left := 0
var time := 40 * 60
var won := false
var caught := false
## Each mover: tile, pixel offset from that tile's centre, and heading.
var player := { tile = Vector2i(6, 5), offset = Vector2.ZERO, dir = Vector2i.ZERO, want = Vector2i.ZERO }
var ghost := {}
var _fright := 0
var _swipe_from := Vector2.INF
var _mouth := 0.0


func _setup() -> void:
	for row: String in LAYOUT:
		grid.append(Array(row.split("")))
		dots_left += row.count(".") + row.count("o")
	_reset_ghost()


func _reset_ghost() -> void:
	ghost = { tile = GHOST_HOME, offset = Vector2.ZERO, dir = Vector2i.LEFT }


func _wall(tile: Vector2i) -> bool:
	return tile.y < 0 or tile.y >= grid.size() or tile.x < 0 or tile.x >= grid[tile.y].size() or grid[tile.y][tile.x] == "#"


func _pointer_pressed(at: Vector2) -> void:
	_swipe_from = at


func _pointer_released(at: Vector2) -> void:
	if _swipe_from == Vector2.INF:
		return
	var d := at - _swipe_from
	_swipe_from = Vector2.INF
	if absf(d.x) < SWIPE_MIN and absf(d.y) < SWIPE_MIN:
		return
	player.want = DIRS[0 if d.x > 0 else 1] if absf(d.x) > absf(d.y) else DIRS[2 if d.y > 0 else 3]


func _key(event: InputEventKey) -> void:
	if event.pressed and KEYS.has(event.keycode):
		player.want = DIRS[KEYS[event.keycode]]


## Moves a mover along its heading; true when it arrives at a new tile centre.
## Speeds divide TS exactly, so the offset lands back on zero.
func _step(mover: Dictionary, speed: float) -> bool:
	if mover.dir == Vector2i.ZERO:
		return false
	mover.offset += Vector2(mover.dir) * speed
	if absf(mover.offset.x) >= TS or absf(mover.offset.y) >= TS:
		mover.tile += mover.dir
		mover.offset -= Vector2(mover.dir) * TS
		return true
	return false


func _screen(mover: Dictionary) -> Vector2:
	return ORIGIN + (Vector2(mover.tile) + Vector2(0.5, 0.5)) * TS + mover.offset


func _tick() -> void:
	time -= 1
	if time <= 0:
		end_round("TIME!")
		return
	if _fright > 0:
		_fright -= 1
	_mouth += 0.25
	_move_player()
	if won:
		end_round("MAZE CLEAR!")
		return
	_move_ghost()
	if _screen(player).distance_to(_screen(ghost)) < 16:
		if _fright > 0:
			score += 30
			add_pop(_screen(ghost), "+30", 36)
			_reset_ghost()
		else:
			caught = true
			end_round("CAUGHT!", false)


## Turns at tile centres, stops at walls, eats what it lands on.
func _move_player() -> void:
	if player.offset == Vector2.ZERO:
		if player.want != Vector2i.ZERO and not _wall(player.tile + player.want):
			player.dir = player.want
		if player.dir != Vector2i.ZERO and _wall(player.tile + player.dir):
			player.dir = Vector2i.ZERO
	# 2 px × 13 frames = one tile.
	if _step(player, 2.0):
		var tile: Vector2i = player.tile
		var ch: String = grid[tile.y][tile.x]
		if ch == "." or ch == "o":
			grid[tile.y][tile.x] = " "
			dots_left -= 1
			score += 5 if ch == "." else 20
			if ch == "o":
				_fright = 180
		if dots_left <= 0:
			score += 100
			won = true


## Greedy chase (or flight while frightened), never reversing unless cornered.
func _move_ghost() -> void:
	if ghost.offset == Vector2.ZERO:
		var open := DIRS.filter(func(d: Vector2i) -> bool: return not _wall(ghost.tile + d))
		var ahead := open.filter(func(d: Vector2i) -> bool: return d != -ghost.dir)
		var pool := ahead if not ahead.is_empty() else open
		pool.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var da := Vector2(ghost.tile + a - player.tile).length()
			var db := Vector2(ghost.tile + b - player.tile).length()
			return da > db if _fright > 0 else da < db)
		# A small wobble so it isn't perfectly relentless.
		ghost.dir = pool[0] if randf() < 0.85 else pool[randi() % pool.size()]
	# Both speeds divide TS exactly.
	_step(ghost, 1.0 if _fright > 0 else 1.625)


func _draw_board() -> void:
	for r in grid.size():
		for c in grid[r].size():
			var cell := ORIGIN + Vector2(c, r) * TS
			match grid[r][c]:
				"#":
					board.draw_rect(Rect2(cell + Vector2.ONE, Vector2(TS - 2, TS - 2)), Color("1c2a55"))
				".":
					board.draw_rect(Rect2(cell + Vector2(TS / 2 - 2, TS / 2 - 2), Vector2(4, 4)), CREAM)
				"o":
					board.draw_circle(cell + Vector2(TS, TS) / 2, 6, Color("ffd166"))
	# The muncher: a chomping wedge.
	var p := _screen(player)
	var facing := Vector2(player.dir).angle() if player.dir != Vector2i.ZERO else 0.0
	var mouth := (sin(_mouth) * 0.5 + 0.5) * 0.7 + 0.05
	var wedge := PackedVector2Array([p])
	for i in 21:
		wedge.append(p + Vector2.from_angle(facing + mouth + (TAU - 2 * mouth) * i / 20.0) * 11)
	board.draw_colored_polygon(wedge, Color("ffd166"))
	# The ghost: blue while frightened, flashing as that wears off.
	var g := _screen(ghost)
	var color := Color("ff006e")
	if _fright > 0:
		color = CREAM if _fright < 60 and (_fright & 8) != 0 else Color("3a86ff")
	half_disc(g - Vector2(0, 2), 10, color)
	board.draw_rect(Rect2(g + Vector2(-10, -2), Vector2(20, 10)), color)
	board.draw_rect(Rect2(g + Vector2(-6, -6), Vector2(4, 4)), Color.WHITE)
	board.draw_rect(Rect2(g + Vector2(2, -6), Vector2(4, 4)), Color.WHITE)
	draw_pops(0.4, 10)


func _hud_text() -> String:
	return "SCORE %d    DOTS %d    TIME %d" % [score, dots_left, ceili(maxi(0, time) / 60.0)]

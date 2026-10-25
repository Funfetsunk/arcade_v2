class_name WalkGrid
extends RefCounted
## Walking routes around the cabinets. AStarGrid2D finds a tile path (4-way, like
## the original's BFS); the path is then string-pulled into straight any-angle
## legs wherever there's a clear line, so people cut corners naturally.
## Points are in floor pixels; interior tile (0, 0) has its top-left at (0, 0).

const TILE := 32.0

var _astar := AStarGrid2D.new()


func _init() -> void:
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.cell_size = Vector2(TILE, TILE)
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN


## Every tile of every machine's full footprint is solid (customers walk round
## the whole body, unlike placement which only cares about bases). `blocked`
## adds more solid tiles (floor props).
func rebuild(room: Vector2i, machines: Array[MachineInstance], blocked: Array[Vector2i] = []) -> void:
	_astar.region = Rect2i(Vector2i.ZERO, room)
	_astar.update()
	var solid := blocked.duplicate()
	for m in machines:
		solid.append_array(FloorGrid.footprint_tiles(m.tile, m.def.footprint))
	for t in solid:
		if _astar.region.has_point(t):
			_astar.set_point_solid(t)


static func tile_of(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / TILE), floori(point.y / TILE))


static func tile_centre(tile: Vector2i) -> Vector2:
	return (Vector2(tile) + Vector2(0.5, 0.5)) * TILE


func is_blocked(tile: Vector2i) -> bool:
	return _astar.region.has_point(tile) and _astar.is_point_solid(tile)


## Waypoints from `from` to `to` (excluding `from`). Falls back to a straight
## line when no route exists, so nobody is ever stranded.
func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := _clamp(tile_of(from))
	var goal := _clamp(tile_of(to))
	if start == goal:
		return PackedVector2Array([to])
	# The start and goal are always walkable, even if a cabinet covers them.
	var start_solid := _astar.is_point_solid(start)
	var goal_solid := _astar.is_point_solid(goal)
	_astar.set_point_solid(start, false)
	_astar.set_point_solid(goal, false)
	var tiles := _astar.get_id_path(start, goal)
	_astar.set_point_solid(start, start_solid)
	_astar.set_point_solid(goal, goal_solid)
	if tiles.is_empty():
		return PackedVector2Array([to])
	var points := PackedVector2Array([from])
	for i in range(1, tiles.size() - 1):
		points.append(tile_centre(tiles[i]))
	points.append(to)
	return _simplify(points).slice(1)


## Keeps only the waypoints needed for clear straight lines between them.
func _simplify(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() <= 2:
		return points
	var out := PackedVector2Array([points[0]])
	var i := 0
	while i < points.size() - 1:
		var j := points.size() - 1
		while j > i + 1 and not segment_clear(points[i], points[j]):
			j -= 1
		out.append(points[j])
		i = j
	return out


## Walks every tile the segment passes through (grid DDA, so it can't skip a
## tile clipped near a corner); grazing a blocked corner exactly counts as blocked.
func segment_clear(a: Vector2, b: Vector2) -> bool:
	var tile := tile_of(a)
	var end := tile_of(b)
	var d := b - a
	var step := Vector2i(signi(int(signf(d.x))), signi(int(signf(d.y))))
	var t_max := Vector2(INF, INF)
	var t_delta := Vector2(INF, INF)
	if step.x != 0:
		t_max.x = ((tile.x + (1 if step.x > 0 else 0)) * TILE - a.x) / d.x
		t_delta.x = TILE / absf(d.x)
	if step.y != 0:
		t_max.y = ((tile.y + (1 if step.y > 0 else 0)) * TILE - a.y) / d.y
		t_delta.y = TILE / absf(d.y)
	for guard in 4096:
		if is_blocked(tile):
			return false
		if tile == end:
			return true
		if t_max.x < t_max.y:
			tile.x += step.x
			t_max.x += t_delta.x
		elif t_max.y < t_max.x:
			tile.y += step.y
			t_max.y += t_delta.y
		else:
			if is_blocked(tile + Vector2i(0, step.y)) or is_blocked(tile + Vector2i(step.x, 0)):
				return false
			tile += step
			t_max += t_delta
		if t_max.x > 1.0 and t_max.y > 1.0 and tile != end:
			return true
	return true


func _clamp(tile: Vector2i) -> Vector2i:
	var r := _astar.region
	return Vector2i(clampi(tile.x, r.position.x, r.end.x - 1), clampi(tile.y, r.position.y, r.end.y - 1))

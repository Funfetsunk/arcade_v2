extends GutTest
## Walking routes go around cabinets, never through them.

const H := preload("res://tests/sim_test_helper.gd")

var state := H.make_state()
var grid := WalkGrid.new()


func before_each() -> void:
	state.machines.clear()
	# A wall of cabinets across row 4-5, with a gap at x = 7.
	for x in 16:
		if x != 7:
			var m := H.machine(state, &"space_inv")
			m.tile = Vector2i(x, 4)
			state.machines.append(m)
	grid.rebuild(Vector2i(16, 10), state.machines)


func test_route_avoids_cabinets() -> void:
	var from := WalkGrid.tile_centre(Vector2i(1, 8))
	var to := WalkGrid.tile_centre(Vector2i(14, 1))
	var route := grid.route(from, to)
	assert_eq(route[-1], to)
	var previous := from
	for point in route:
		assert_true(grid.segment_clear(previous, point), "leg %s -> %s is clear" % [previous, point])
		previous = point
	assert_true(route.size() >= 2, "had to detour through the gap")


func test_straight_line_when_clear() -> void:
	var route := grid.route(WalkGrid.tile_centre(Vector2i(1, 8)), WalkGrid.tile_centre(Vector2i(14, 8)))
	assert_eq(route.size(), 1)


func test_blocked_line_detected() -> void:
	assert_false(grid.segment_clear(WalkGrid.tile_centre(Vector2i(2, 8)), WalkGrid.tile_centre(Vector2i(2, 1))))


func test_unreachable_falls_back_to_straight_line() -> void:
	var m := H.machine(state, &"space_inv")
	m.tile = Vector2i(7, 4)
	state.machines.append(m)
	grid.rebuild(Vector2i(16, 10), state.machines)
	var to := WalkGrid.tile_centre(Vector2i(3, 1))
	assert_eq(grid.route(WalkGrid.tile_centre(Vector2i(3, 8)), to), PackedVector2Array([to]))

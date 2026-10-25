extends GutTest
## Where decor and facilities land on the floor and the back wall.

const H := preload("res://tests/sim_test_helper.gd")
const ROOM := Vector2i(16, 10)

var state: GameState


func before_each() -> void:
	state = H.make_state({"room": ROOM})


func _cab(x: int, y: int, facing := MachineInstance.Facing.S) -> MachineInstance:
	var m := H.machine(state, &"space_inv")
	m.tile = Vector2i(x, y)
	m.facing = facing
	state.machines.append(m)
	return m


func _spot(id: StringName) -> PropLayout.Spot:
	for s in PropLayout.layout(state):
		if s.def.id == id:
			return s
	return null


func test_every_prop_has_art() -> void:
	for p in H.DATA.decor_props:
		assert_not_null(p.sprite, "%s has a sprite" % p.id)
	for f in H.DATA.facilities:
		assert_not_null(f.sprite, "%s has a sprite" % f.id)


func test_first_floor_prop_takes_the_back_corner() -> void:
	state.decor.append(H.DATA.decor_prop(&"plant"))
	assert_eq(_spot(&"plant").tile, Vector2i(0, 0))


func test_facilities_go_before_decor() -> void:
	state.decor.append(H.DATA.decor_prop(&"plant"))
	state.facilities.append(H.DATA.facility(&"atm"))
	var spots := PropLayout.layout(state)
	assert_eq(spots[0].def.id, &"atm")
	assert_eq(spots[0].tile, Vector2i(0, 0))
	assert_eq(spots[1].tile, Vector2i(15, 0))


func test_props_make_way_for_machines_and_their_players() -> void:
	_cab(0, 0)   # footprint (0,0)-(0,1), player stands on (0,2)
	state.decor.append(H.DATA.decor_prop(&"plant"))
	state.decor.append(H.DATA.decor_prop(&"plant"))
	state.decor.append(H.DATA.decor_prop(&"plant"))
	var tiles := PropLayout.layout(state).map(func(s: PropLayout.Spot) -> Vector2i: return s.tile)
	for t in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]:
		assert_false(tiles.has(t), "%s stays clear" % t)


func test_wide_props_fit_inside_the_room() -> void:
	state.decor.append(H.DATA.decor_prop(&"bench"))
	state.decor.append(H.DATA.decor_prop(&"bench"))
	var spots := PropLayout.layout(state)
	assert_eq(spots[0].tile, Vector2i(0, 0))
	assert_eq(spots[1].tile, Vector2i(14, 0))


func test_props_never_cut_off_a_machine() -> void:
	# A cabinet in the back corner facing east is played from (1, 1); a prop on
	# (0, 2) and (1, 2) would leave that tile unreachable.
	_cab(0, 0, MachineInstance.Facing.E)
	_cab(2, 0)
	for i in 8:
		state.decor.append(H.DATA.decor_prop(&"plant"))
	var tiles := PropLayout.layout(state).map(func(s: PropLayout.Spot) -> Vector2i: return s.tile)
	assert_false(tiles.has(Vector2i(1, 2)) and tiles.has(Vector2i(0, 2)))


func test_the_door_lane_stays_open() -> void:
	for i in 12:
		state.decor.append(H.DATA.decor_prop(&"plant"))
	var blocked := PropLayout.blocked_tiles(PropLayout.layout(state))
	assert_false(blocked.has(Vector2i(7, 9)))
	assert_false(blocked.has(Vector2i(8, 9)))


func test_rug_lies_inside_the_door_without_blocking() -> void:
	state.decor.append(H.DATA.decor_prop(&"rug"))
	var spots := PropLayout.layout(state)
	assert_eq(spots[0].tile, Vector2i(7, 9))
	assert_true(PropLayout.blocked_tiles(spots).is_empty())


func test_wall_props_hang_on_the_back_wall() -> void:
	state.decor.append(H.DATA.decor_prop(&"poster"))
	state.decor.append(H.DATA.decor_prop(&"poster"))
	var spots := PropLayout.layout(state)
	assert_eq(spots[0].tile, Vector2i(1, -1))
	assert_eq(spots[1].tile, Vector2i(14, -1))
	assert_true(PropLayout.blocked_tiles(spots).is_empty())


func test_first_neon_lights_the_name_and_more_hang_as_play_signs() -> void:
	state.decor.append(H.DATA.decor_prop(&"neon"))
	state.decor.append(H.DATA.decor_prop(&"neon"))
	var spots := PropLayout.layout(state)
	assert_eq(spots.size(), 2)
	assert_true(spots[0].name_sign)
	assert_eq(spots[0].tile, Vector2i(8, -1))
	assert_false(spots[1].name_sign)
	assert_eq(spots[1].tile, Vector2i(1, -1))


func test_wall_props_keep_clear_of_the_name_sign() -> void:
	state.arcade_name = "WWWWWWWWWWWWWWWWWWWW"
	state.decor.append(H.DATA.decor_prop(&"neon"))
	for i in 11:
		state.decor.append(H.DATA.decor_prop(&"poster"))
	var covered := PropLayout.sign_tiles(ROOM, state.arcade_name)
	for s in PropLayout.layout(state):
		if not s.name_sign:
			assert_false(covered.has(s.tile.x), "poster at %s clear of the sign" % s.tile)


func test_props_keep_off_the_cashiers_desk() -> void:
	for i in 12:
		state.decor.append(H.DATA.decor_prop(&"plant"))
	var desk := FloorGrid.desk_tiles(ROOM)
	for s in PropLayout.layout(state):
		for t in s.tiles():
			assert_false(desk.has(t), "plant at %s clear of the desk" % t)

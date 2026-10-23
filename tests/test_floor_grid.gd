extends GutTest
## Port of the original tests/layout.test.ts, placement.test.ts and
## zones.test.ts (the tile rules; pixel geometry lives in the floor scene).

const H := preload("res://tests/sim_test_helper.gd")
const CAB := Vector2i(1, 2)
const ROOM := Vector2i(16, 10)
const N := MachineInstance.Facing.N
const E := MachineInstance.Facing.E
const S := MachineInstance.Facing.S
const W := MachineInstance.Facing.W

var state := H.make_state()


## A placed space_inv cabinet (1x2 footprint) for the "objects" lists.
func _cab(x: int, y: int, facing := S) -> MachineInstance:
	var m := H.machine(state, &"space_inv")
	m.tile = Vector2i(x, y)
	m.facing = facing
	return m


func _ok(x: int, y: int, facing: MachineInstance.Facing, others: Array[MachineInstance], ignore: MachineInstance = null) -> bool:
	return FloorGrid.can_place(Vector2i(x, y), CAB, facing, ROOM, others, ignore)


func test_footprint_is_the_same_box_every_facing() -> void:
	assert_eq(FloorGrid.footprint_tiles(Vector2i(4, 4), CAB), [Vector2i(4, 4), Vector2i(4, 5)] as Array[Vector2i])


func test_base_tiles_are_the_bottom_tile_for_a_cabinet() -> void:
	for facing: MachineInstance.Facing in [S, N, E, W]:
		assert_eq(FloorGrid.base_tiles(Vector2i(4, 4), CAB, facing), [Vector2i(4, 5)] as Array[Vector2i])
	assert_eq(FloorGrid.base_tiles(Vector2i(3, 3), Vector2i.ONE, S), [Vector2i(3, 3)] as Array[Vector2i])


func test_stand_tile_per_facing() -> void:
	var t := Vector2i(5, 5)
	assert_eq(FloorGrid.stand_tile(t, CAB, S), Vector2i(5, 7))
	assert_eq(FloorGrid.stand_tile(t, CAB, N), Vector2i(5, 5))
	assert_eq(FloorGrid.stand_tile(t, CAB, E), Vector2i(6, 6))
	assert_eq(FloorGrid.stand_tile(t, CAB, W), Vector2i(4, 6))
	assert_eq(FloorGrid.stand_tile(Vector2i(5, -1), CAB, N), Vector2i(5, -1))


func test_in_bounds() -> void:
	assert_true(FloorGrid.in_bounds([Vector2i(0, 0), Vector2i(15, 9)] as Array[Vector2i], ROOM))
	assert_false(FloorGrid.in_bounds([Vector2i(16, 0)] as Array[Vector2i], ROOM))
	assert_false(FloorGrid.in_bounds([Vector2i(0, 10)] as Array[Vector2i], ROOM))
	assert_false(FloorGrid.in_bounds([Vector2i(-1, 0)] as Array[Vector2i], ROOM))


func test_occupied_tiles_are_bases_only() -> void:
	var a := _cab(2, 2)
	var b := _cab(5, 5)
	var occ := FloorGrid.occupied_tiles([a, b])
	assert_true(occ.has(Vector2i(2, 3)))
	assert_false(occ.has(Vector2i(2, 2)), "upper body is visual height")
	assert_true(occ.has(Vector2i(5, 6)))
	var skip := FloorGrid.occupied_tiles([a, b], a)
	assert_false(skip.has(Vector2i(2, 3)))
	assert_true(skip.has(Vector2i(5, 6)))


func test_can_place_basics() -> void:
	assert_true(_ok(3, 3, S, []))
	assert_false(_ok(15, 9, S, []), "body would spill past the bottom")
	assert_false(_ok(16, 0, S, []))
	assert_false(_ok(-1, 0, S, []))
	assert_false(_ok(4, 4, S, [_cab(4, 4)]), "base on base")
	assert_false(_ok(2, 8, S, []), "stand tile out of bounds")


func test_back_to_back_is_allowed() -> void:
	assert_true(_ok(5, 4, N, [_cab(5, 5, S)]))


func test_stand_tile_blocked_by_a_base_not_by_an_upper_body() -> void:
	assert_false(_ok(4, 2, S, [_cab(4, 3, S)]))
	assert_true(_ok(4, 2, S, [_cab(4, 4, S)]))


func test_moving_ignores_the_machine_itself() -> void:
	var m := _cab(6, 6)
	assert_true(_ok(6, 6, S, [m], m))
	assert_false(_ok(6, 6, S, [m]))
	var east := _cab(3, 3, E)
	assert_false(_ok(3, 3, E, [east]))
	assert_true(_ok(3, 3, E, [east], east))


func test_side_facing_cabinets_can_stack_vertically() -> void:
	var a := _cab(3, 3, E)
	assert_true(_ok(3, 4, E, [a]))
	assert_true(_ok(3, 2, E, [a]))
	assert_false(_ok(3, 3, E, [a]))


func test_stand_tiles_cannot_collide() -> void:
	assert_false(_ok(5, 4, S, [_cab(5, 3, S)]), "base on a stand tile")
	assert_false(_ok(4, 3, N, [_cab(4, 1, S)]), "stand on a stand tile")


func test_opposite_facing_on_the_same_tile_is_rejected() -> void:
	var existing := _cab(5, 5, S)
	assert_false(_ok(5, 5, N, [existing]))


func test_flush_against_back_wall() -> void:
	for facing: MachineInstance.Facing in [S, W, E]:
		assert_true(_ok(5, -1, facing, []), "facing %d may overhang the wall" % facing)
	assert_false(_ok(5, -1, N, []), "north-facing would face into the wall")
	assert_false(_ok(5, -2, S, []), "base itself out of bounds")


func test_auto_layout_spreads_scenario_machines() -> void:
	var s := Game.new_state(H.DATA, H.DATA.scenario(&"weekend"))
	FloorGrid.auto_layout(s)
	var seen := {}
	for m in s.machines:
		assert_false(seen.has(m.tile), "distinct spots")
		seen[m.tile] = true
		assert_true(FloorGrid.can_place(m.tile, m.def.footprint, m.facing, s.room, s.machines, m))


func test_zones_count_same_genre_within_radius() -> void:
	var b := H.DATA.balance
	var a := _cab(2, 2)
	var near := _cab(2, 4)
	var far := _cab(2, 8)
	var other := H.machine(state, &"fighter")
	other.tile = Vector2i(3, 2)
	var all: Array[MachineInstance] = [a, near, far, other]
	assert_eq(FloorGrid.same_genre_nearby(all, a, b.zone_radius), 1)
	assert_eq(FloorGrid.same_genre_nearby([a, far] as Array[MachineInstance], a, 6.0), 1)
	assert_eq(FloorGrid.same_genre_nearby([a, far] as Array[MachineInstance], a, 5.0), 0)


func test_genreless_machines_never_zone() -> void:
	var v1 := H.machine(state, &"vending")
	var v2 := H.machine(state, &"vending")
	v2.tile = Vector2i(0, 2)
	assert_eq(FloorGrid.same_genre_nearby([v1, v2] as Array[MachineInstance], v1, 2.0), 0)


func test_zone_multiplier_caps() -> void:
	var b := H.DATA.balance
	assert_eq(FloorGrid.zone_mul(0, b), 1.0)
	assert_almost_eq(FloorGrid.zone_mul(2, b), 1.12, 1e-9)
	assert_almost_eq(FloorGrid.zone_mul(8, b), 1.18, 1e-9)
	assert_eq(FloorGrid.zone_pct(8, b), 18)


func test_genre_data() -> void:
	var d := H.DATA
	assert_ne(d.machine(&"claw").genre, d.machine(&"pinball").genre)
	assert_null(d.machine(&"vending").genre)
	assert_null(d.machine(&"food_counter").genre)


func test_buying_next_to_a_same_genre_cabinet_sets_zone_bonus() -> void:
	var s := H.make_state({ cash = 10000.0 })
	var cycle := DayCycle.new(H.DATA, MetaProgress.new(), Rng.new(1), H.sim(1))
	var actions := Actions.new(H.DATA, cycle.meta, cycle.rng, cycle)
	var first := actions.buy_machine(s, H.DATA.machine(&"space_inv"), Vector2i(2, 2), S)
	var second := actions.buy_machine(s, H.DATA.machine(&"pac"), Vector2i(3, 2), S)
	assert_almost_eq(first.zone_mul, 1.06, 1e-9)
	assert_almost_eq(second.zone_mul, 1.06, 1e-9)

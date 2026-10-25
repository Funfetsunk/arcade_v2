class_name FloorGrid
extends RefCounted
@warning_ignore_start("integer_division")
## Tile rules for the arcade floor, ported from the original scene/layout.ts,
## placement.ts and zones.ts. Pure tile math: interior tile (0, 0) is the
## top-left floor tile just inside the walls.
##
## A machine's footprint is the same box for every facing. Only its base (the
## bottom row) sits on the floor and blocks placement; the rest is visual height,
## so cabinets can stand back to back. The stand tile is where a customer plays.

## Facing -> unit step out of the machine's front.
const FACING_STEP := {
	MachineInstance.Facing.N: Vector2i.UP,
	MachineInstance.Facing.E: Vector2i.RIGHT,
	MachineInstance.Facing.S: Vector2i.DOWN,
	MachineInstance.Facing.W: Vector2i.LEFT,
}


static func footprint_tiles(tile: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			out.append(tile + Vector2i(x, y))
	return out


## Floor-contact tiles: the box's bottom row for N/S, the front tile at the
## stand row for E/W.
static func base_tiles(tile: Vector2i, size: Vector2i, facing: MachineInstance.Facing) -> Array[Vector2i]:
	match facing:
		MachineInstance.Facing.E:
			return [tile + Vector2i(size.x - 1, size.y / 2)]
		MachineInstance.Facing.W:
			return [tile + Vector2i(0, size.y / 2)]
	var out: Array[Vector2i] = []
	for x in size.x:
		out.append(tile + Vector2i(x, size.y - 1))
	return out


## Where a customer stands to play. A north-facing cabinet's customer tucks into
## the box's own top tile rather than a tile beyond it.
static func stand_tile(tile: Vector2i, size: Vector2i, facing: MachineInstance.Facing) -> Vector2i:
	match facing:
		MachineInstance.Facing.S:
			return tile + Vector2i(size.x / 2, size.y)
		MachineInstance.Facing.N:
			return tile + Vector2i(size.x / 2, 0)
		MachineInstance.Facing.E:
			return tile + Vector2i(size.x, size.y / 2)
	return tile + Vector2i(-1, size.y / 2)


static func centre(tile: Vector2i, size: Vector2i) -> Vector2:
	return Vector2(tile) + Vector2(size) / 2.0


static func in_bounds(tiles: Array[Vector2i], room: Vector2i) -> bool:
	return tiles.all(func(t: Vector2i) -> bool: return t.x >= 0 and t.y >= 0 and t.x < room.x and t.y < room.y)


## Tiles covered by other machines' bases (optionally skipping one machine).
static func occupied_tiles(machines: Array[MachineInstance], ignore: MachineInstance = null) -> Dictionary:
	var tiles := {}
	for m in machines:
		if m != ignore:
			for t in base_tiles(m.tile, m.def.footprint, m.facing):
				tiles[t] = true
	return tiles


## The cashier's desk in the front-left corner (two tiles) and the row behind it
## where the cashier stands, as in the original. Nothing else goes there.
static func desk_tiles(room: Vector2i) -> Array[Vector2i]:
	return [Vector2i(0, room.y - 1), Vector2i(1, room.y - 1), Vector2i(0, room.y - 2), Vector2i(1, room.y - 2)]


## Other machines' stand tiles, which must stay clear.
static func reserved_stand_tiles(machines: Array[MachineInstance], ignore: MachineInstance = null) -> Dictionary:
	var tiles := {}
	for m in machines:
		if m != ignore:
			tiles[stand_tile(m.tile, m.def.footprint, m.facing)] = true
	return tiles


## Whether a machine of `size` can sit at `tile` facing `facing`. `ignore` is the
## machine being moved, so its current spot doesn't block itself.
static func can_place(tile: Vector2i, size: Vector2i, facing: MachineInstance.Facing, room: Vector2i,
		machines: Array[MachineInstance], ignore: MachineInstance = null) -> bool:
	var bases := base_tiles(tile, size, facing)
	# Only the base must be on real floor; a back-wall overhang is fine.
	if not in_bounds(bases, room):
		return false
	var occupied := occupied_tiles(machines, ignore)
	var stands := reserved_stand_tiles(machines, ignore)
	var desk := desk_tiles(room)
	for t in bases:
		if occupied.has(t) or stands.has(t) or desk.has(t):
			return false
	var stand := stand_tile(tile, size, facing)
	if not in_bounds([stand], room) or occupied.has(stand) or stands.has(stand) or desk.has(stand):
		return false
	# Two boxes whose bases each land inside the other's footprint are the same
	# physical space (e.g. opposite facings dropped on one tile).
	var mine := footprint_tiles(tile, size)
	for m in machines:
		if m == ignore:
			continue
		var theirs := footprint_tiles(m.tile, m.def.footprint)
		if not bases.any(func(t: Vector2i) -> bool: return theirs.has(t)):
			continue
		if base_tiles(m.tile, m.def.footprint, m.facing).any(func(t: Vector2i) -> bool: return mine.has(t)):
			return false
	return true


## Scans top-left first for a valid spot; returns Vector2i(-1000, -1000) if full.
static func first_free_tile(state: GameState, size: Vector2i, facing: MachineInstance.Facing,
		ignore: MachineInstance = null) -> Vector2i:
	for y in state.room.y:
		for x in state.room.x:
			if can_place(Vector2i(x, y), size, facing, state.room, state.machines, ignore):
				return Vector2i(x, y)
	return NO_TILE


const NO_TILE := Vector2i(-1000, -1000)


## Lays machines created at (0, 0) (scenario starts) into tidy free spots.
static func auto_layout(state: GameState) -> void:
	var placed: Array[MachineInstance] = []
	for m in state.machines:
		var chosen := NO_TILE
		for y in state.room.y:
			for x in state.room.x:
				if chosen == NO_TILE and can_place(Vector2i(x, y), m.def.footprint, m.facing, state.room, placed):
					chosen = Vector2i(x, y)
		m.tile = chosen if chosen != NO_TILE else Vector2i.ZERO
		placed.append(m)


## Same-genre machines whose centre is within `radius` tiles (Manhattan) of m's.
static func same_genre_nearby(machines: Array[MachineInstance], m: MachineInstance, radius: float) -> int:
	if m.def.genre == null:
		return 0
	var c := centre(m.tile, m.def.footprint)
	var n := 0
	for other in machines:
		if other == m or other.def.genre != m.def.genre:
			continue
		var oc := centre(other.tile, other.def.footprint)
		if absf(oc.x - c.x) + absf(oc.y - c.y) <= radius:
			n += 1
	return n


static func zone_mul(neighbours: int, balance: GameBalance) -> float:
	return 1.0 + balance.zone_rate * mini(neighbours, balance.zone_cap)


static func zone_pct(neighbours: int, balance: GameBalance) -> int:
	return GameMath.js_round(balance.zone_rate * mini(neighbours, balance.zone_cap) * 100.0)


## Writes each machine's themed-zone multiplier, which the sim reads.
static func recompute_zones(state: GameState, balance: GameBalance) -> void:
	for m in state.machines:
		m.zone_mul = zone_mul(same_genre_nearby(state.machines, m, balance.zone_radius), balance)

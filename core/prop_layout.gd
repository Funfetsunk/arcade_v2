class_name PropLayout
extends RefCounted
@warning_ignore_start("integer_division")
## Where bought decor and facilities sit. Nothing is stored: every prop is laid
## out again from the machines, so props make way when a machine is placed on
## their spot. Facilities go first (in purchase order), then decor.
##
## Floor props hug the walls: the back row first (from the corners inward), then
## the side columns, then the front row either side of the door. A spot must not
## touch a machine's footprint or stand tile, the door lane, or another prop, and
## must not cut anyone off from a machine they could reach before. Rugs lie inside
## the door and never block. Wall props hang along the back wall, either side of
## the arcade's name: the first Neon Sign lights that name in the middle of the
## wall (as in the original); any more hang as PLAY signs.

## Rough width of one letter of the sign, and the board's padding, in pixels.
const SIGN_LETTER := 13.0
const SIGN_PADDING := 12.0


class Spot:
	var def: FloorPropDef
	## The leftmost tile it covers; y is -1 for the back wall.
	var tile: Vector2i
	## The arcade name sign, centred on the wall rather than at `tile`.
	var name_sign := false

	func _init(d: FloorPropDef, t: Vector2i) -> void:
		def = d
		tile = t

	func tiles() -> Array[Vector2i]:
		var out: Array[Vector2i] = []
		for x in def.width:
			out.append(tile + Vector2i(x, 0))
		return out


static func layout(state: GameState) -> Array[Spot]:
	var room := state.room
	var props: Array[FloorPropDef] = []
	props.append_array(state.facilities)
	props.append_array(state.decor)
	var machine_tiles := {}
	for m in state.machines:
		for t in FloorGrid.footprint_tiles(m.tile, m.def.footprint):
			machine_tiles[t] = true
	var stands := FloorGrid.reserved_stand_tiles(state.machines)
	for t in FloorGrid.desk_tiles(room):
		machine_tiles[t] = true
	var lane := door_lane(room)
	var solid := machine_tiles.duplicate()
	var taken := {}        # floor tiles used by any prop, rugs included
	var wall_taken := {}
	var reachable := _reached_stands(room, solid, stands, lane)
	var spots: Array[Spot] = []
	var signed := false
	for def in props:
		if def.id == &"neon" and not signed:
			signed = true
			var name_spot := Spot.new(def, Vector2i(room.x / 2, -1))
			name_spot.name_sign = true
			for x in sign_tiles(room, state.arcade_name):
				wall_taken[x] = true
			spots.append(name_spot)
	var sign_placed := false
	for def in props:
		if def.id == &"neon" and not sign_placed:
			sign_placed = true   # this one is the name sign, already placed
			continue
		var spot: Spot = null
		if def.on_wall:
			spot = _wall_spot(def, room, wall_taken)
			if spot:
				for t in spot.tiles():
					wall_taken[t.x] = true
		else:
			for tile in floor_candidates(room, def.width, def.flat):
				var cand := Spot.new(def, tile)
				if not _fits(cand.tiles(), room, machine_tiles, stands, taken, lane if not def.flat else {}):
					continue
				if not def.flat:
					var trial := solid.duplicate()
					for t in cand.tiles():
						trial[t] = true
					if _reached_stands(room, trial, stands, lane) < reachable:
						continue
				spot = cand
				break
			if spot:
				for t in spot.tiles():
					taken[t] = true
					if not def.flat:
						solid[t] = true
		if spot:
			spots.append(spot)
	return spots


## Back-wall tile columns the name sign covers.
static func sign_tiles(room: Vector2i, arcade_name: String) -> Array[int]:
	var half := ceili((mini(arcade_name.length(), 20) * SIGN_LETTER + SIGN_PADDING) / 2.0 / FloorGeometry.TILE)
	var out: Array[int] = []
	for x in range(room.x / 2 - half, room.x / 2 + half):
		out.append(x)
	return out


## Floor tiles people can't walk through.
static func blocked_tiles(spots: Array[Spot]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for s in spots:
		if not s.def.on_wall and not s.def.flat:
			out.append_array(s.tiles())
	return out


## The two front-row tiles either side of the door gap.
static func door_lane(room: Vector2i) -> Dictionary:
	var x := room.x / 2
	return {Vector2i(x - 1, room.y - 1): true, Vector2i(x, room.y - 1): true}


## Leftmost tiles to try, best first, for a prop `width` tiles wide.
static func floor_candidates(room: Vector2i, width: int, flat: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if flat:
		out.append(Vector2i(room.x / 2 - 1, room.y - 1))   # just inside the door
	var right := room.x - width
	for i in (room.x + 1) / 2:
		out.append(Vector2i(i, 0))
		out.append(Vector2i(right - i, 0))
	for y in range(1, room.y - 1):
		out.append(Vector2i(0, y))
		out.append(Vector2i(right, y))
	for i in (room.x + 1) / 2:
		out.append(Vector2i(i, room.y - 1))
		out.append(Vector2i(right - i, room.y - 1))
	var seen := {}
	var unique: Array[Vector2i] = []
	for t in out:
		if not seen.has(t) and t.x >= 0:
			seen[t] = true
			unique.append(t)
	return unique


static func _fits(tiles: Array[Vector2i], room: Vector2i, machine_tiles: Dictionary, stands: Dictionary,
		taken: Dictionary, lane: Dictionary) -> bool:
	for t in tiles:
		if t.x < 0 or t.y < 0 or t.x >= room.x or t.y >= room.y:
			return false
		if machine_tiles.has(t) or stands.has(t) or taken.has(t) or lane.has(t):
			return false
	return true


## Back-wall slots from the corners inward, skipping the corner tile itself.
static func _wall_spot(def: FloorPropDef, room: Vector2i, wall_taken: Dictionary) -> Spot:
	var right := room.x - 1 - def.width
	for i in range(1, room.x / 2 + 1):
		for x in [i, right - i + 1]:
			if x < 1 or x + def.width > room.x - 1:
				continue
			var free := true
			for dx in def.width:
				free = free and not wall_taken.has(x + dx)
			if free:
				return Spot.new(def, Vector2i(x, -1))
	return null


## How many stand tiles people can reach from the door (a stand tile counts when
## it or a tile beside it is reachable, as routes walk into the goal regardless).
static func _reached_stands(room: Vector2i, solid: Dictionary, stands: Dictionary, lane: Dictionary) -> int:
	var seen := {}
	var queue: Array[Vector2i] = []
	for t: Vector2i in lane:
		if not solid.has(t):
			seen[t] = true
			queue.append(t)
	while not queue.is_empty():
		var t: Vector2i = queue.pop_back()
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := t + step
			if n.x < 0 or n.y < 0 or n.x >= room.x or n.y >= room.y or seen.has(n) or solid.has(n):
				continue
			seen[n] = true
			queue.append(n)
	var count := 0
	for s: Vector2i in stands:
		if seen.has(s) or [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN].any(func(d: Vector2i) -> bool: return seen.has(s + d)):
			count += 1
	return count

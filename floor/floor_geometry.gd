class_name FloorGeometry
extends RefCounted
## Tiles to floor pixels. Interior tile (0, 0) has its top-left at (0, 0); the
## walls sit one tile outside the interior. Art is drawn at 32 px per tile.

const TILE := 32.0
## The back wall's height above the floor's top edge (tall enough for posters).
const WALL_H := 48.0
## Carpet variants in the floor TileSet's second atlas (tools/carpet_atlas.py):
## the plain ones first, then accents and wear.
const CARPET_PLAIN := 5
const CARPET_ACCENTS := 4


static func tile_rect(tile: Vector2i, size := Vector2i.ONE) -> Rect2:
	return Rect2(Vector2(tile) * TILE, Vector2(size) * TILE)


## Where a machine's sprite stands: centred on its footprint, at its bottom edge.
static func machine_anchor(m: MachineInstance) -> Vector2:
	var size := m.def.footprint
	return Vector2((m.tile.x + size.x / 2.0) * TILE, (m.tile.y + size.y) * TILE)


## The centre of the tile a customer stands on to play.
static func stand_point(m: MachineInstance) -> Vector2:
	return WalkGrid.tile_centre(FloorGrid.stand_tile(m.tile, m.def.footprint, m.facing))


## The door gap, centred in the bottom wall.
static func door_x(room: Vector2i) -> float:
	return room.x * TILE / 2.0


## Just outside the door, where people appear and disappear.
static func outside_door(room: Vector2i) -> Vector2:
	return Vector2(door_x(room), room.y * TILE + TILE * 0.75)


## The open strip just inside the bottom wall.
static func front_y(room: Vector2i) -> float:
	return room.y * TILE - 8.0


static func room_rect(room: Vector2i) -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(room) * TILE)


## Which carpet a floor tile shows, as (TileSet source, atlas column): about half
## the tiles are a plain variant and 1 in 25 an accent, fixed per tile so the
## floor never reshuffles. Same hash as tools/carpet_sheet.py.
static func carpet_cell(tile: Vector2i) -> Vector2i:
	var h := ((tile.x * 73856093) ^ (tile.y * 19349663)) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = (h ^ (h >> 16)) & 0xFFFF
	var roll := h % 100
	if roll >= 96:
		return Vector2i(1, CARPET_PLAIN + (h >> 7) % CARPET_ACCENTS)
	if roll < 50:
		return Vector2i(1, (h >> 7) % CARPET_PLAIN)
	return Vector2i(0, 0)

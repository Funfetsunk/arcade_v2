class_name Room
extends Node2D
## The trim, door mat and theme floor tint around and over the floor. The wall
## art itself is the WallFace child, drawn behind this.

const TILE := FloorGeometry.TILE
const TRIM := Color("aa6622")
const TRIM_DARK := Color("5c3d1e")
const DOOR_MAT := Color("20243b")

var room := Vector2i(16, 10)
var theme_def: ThemeDef


func show_room(size: Vector2i, theme: ThemeDef) -> void:
	room = size
	theme_def = theme
	$WallFace.show_walls(size, theme)
	queue_redraw()


func _draw() -> void:
	var w := room.x * TILE
	var h := room.y * TILE
	# Floor tint over the carpet.
	if theme_def and theme_def.floor_tint.a > 0.0:
		draw_rect(Rect2(0, 0, w, h), theme_def.floor_tint)
	# Back wall: a dark crown along the top, and wood trim where it meets the floor.
	draw_rect(Rect2(-TILE, -FloorGeometry.WALL_H, w + 2 * TILE, 4), Color("0c0916"))
	draw_rect(Rect2(-TILE, -4, w + 2 * TILE, 4), TRIM)
	draw_rect(Rect2(-TILE, -1, w + 2 * TILE, 1), TRIM_DARK)
	# Trim along the side walls.
	draw_rect(Rect2(-4, 0, 4, h), TRIM)
	draw_rect(Rect2(w, 0, 4, h), TRIM)
	# The door gap in the front wall.
	var door_x := FloorGeometry.door_x(room)
	var gap := TILE * 1.25
	draw_rect(Rect2(door_x - gap / 2.0, h, gap, TILE * 0.5), DOOR_MAT)
	draw_rect(Rect2(-TILE, h, w + 2 * TILE, 2), TRIM)

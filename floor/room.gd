class_name Room
extends Node2D
## The walls around the floor, in the arcade theme's wall colour, plus the
## theme's floor tint. Placeholder drawing until the wall tileset art exists.

const TILE := FloorGeometry.TILE
const TRIM := Color("aa6622")
const TRIM_DARK := Color("5c3d1e")
const DOOR_MAT := Color("20243b")

var room := Vector2i(16, 10)
var theme_def: ThemeDef


func show_room(size: Vector2i, theme: ThemeDef) -> void:
	room = size
	theme_def = theme
	queue_redraw()


func _draw() -> void:
	var wall := theme_def.wall if theme_def else Color("452e47")
	var w := room.x * TILE
	var h := room.y * TILE
	# Floor tint over the carpet.
	if theme_def and theme_def.floor_tint.a > 0.0:
		draw_rect(Rect2(0, 0, w, h), theme_def.floor_tint)
	# Back wall: brick face with a wood trim where it meets the floor.
	draw_rect(Rect2(-TILE, -TILE, w + 2 * TILE, TILE), wall)
	draw_rect(Rect2(-TILE, -TILE, w + 2 * TILE, 4), wall.darkened(0.35))
	for row in 3:
		var y := -TILE + 6 + row * 8
		var shift := 8.0 if row % 2 else 0.0
		var x := -TILE + shift
		while x < w + TILE:
			draw_line(Vector2(x, y), Vector2(x, y + 7), wall.darkened(0.2), 1.0)
			x += 16.0
		draw_line(Vector2(-TILE, y + 7), Vector2(w + TILE, y + 7), wall.darkened(0.2), 1.0)
	draw_rect(Rect2(-TILE, -4, w + 2 * TILE, 4), TRIM)
	draw_rect(Rect2(-TILE, -1, w + 2 * TILE, 1), TRIM_DARK)
	# Side walls.
	draw_rect(Rect2(-TILE, 0, TILE, h + TILE * 0.5), wall.darkened(0.15))
	draw_rect(Rect2(w, 0, TILE, h + TILE * 0.5), wall.darkened(0.15))
	draw_rect(Rect2(-4, 0, 4, h), TRIM)
	draw_rect(Rect2(w, 0, 4, h), TRIM)
	# Front wall with the door gap.
	var door_x := FloorGeometry.door_x(room)
	var gap := TILE * 1.25
	draw_rect(Rect2(-TILE, h, door_x - gap / 2.0 + TILE, TILE * 0.5), wall.darkened(0.3))
	draw_rect(Rect2(door_x + gap / 2.0, h, w - door_x - gap / 2.0 + TILE, TILE * 0.5), wall.darkened(0.3))
	draw_rect(Rect2(door_x - gap / 2.0, h, gap, TILE * 0.5), DOOR_MAT)
	draw_rect(Rect2(-TILE, h, w + 2 * TILE, 2), TRIM)

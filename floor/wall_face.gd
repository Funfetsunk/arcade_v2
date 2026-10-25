class_name WallFace
extends Node2D
## The walls' art: the back wall as bands of seamless textures (purple brick, a
## neon rail, more brick, wood wainscot) and the side and front walls' tops in
## darkened navy brick. Drawn behind the Room, which adds the trim and door mat.
## A shader tones the whole lot toward the theme's wall colour.

const TILE := FloorGeometry.TILE
const BRICK := preload("res://assets/tiles/walls/brick_purple.png")
const NEON_RAIL := preload("res://assets/tiles/walls/neon_rail.png")
const WAINSCOT := preload("res://assets/tiles/walls/wainscot_band.png")
const CAP := preload("res://assets/tiles/walls/brick_navy.png")
const CAP_SHADE := Color(0.6, 0.6, 0.6)
## Back wall, top to bottom: texture and band height. The bottom 4 px are trim.
const BANDS: Array = [[BRICK, 12.0], [NEON_RAIL, 9.0], [BRICK, 7.0], [WAINSCOT, 16.0]]

var room := Vector2i(16, 10)


func show_walls(size: Vector2i, theme: ThemeDef) -> void:
	room = size
	var shader := material as ShaderMaterial
	var strength := theme.wall_tint_strength if theme else 0.0
	var hue := theme.wall if theme else Color.WHITE
	var peak := maxf(hue.r, maxf(hue.g, hue.b))
	shader.set_shader_parameter(&"tint", Vector3(hue.r, hue.g, hue.b) / maxf(peak, 0.001))
	shader.set_shader_parameter(&"strength", strength)
	queue_redraw()


func _draw() -> void:
	var w := room.x * TILE
	var h := room.y * TILE
	var y := -FloorGeometry.WALL_H
	for band: Array in BANDS:
		draw_texture_rect(band[0], Rect2(-TILE, y, w + 2 * TILE, band[1]), true)
		y += band[1]
	# Side walls and the front wall either side of the door gap.
	var front := TILE * 0.5
	draw_texture_rect(CAP, Rect2(-TILE, 0, TILE, h + front), true, CAP_SHADE)
	draw_texture_rect(CAP, Rect2(w, 0, TILE, h + front), true, CAP_SHADE)
	var door_x := FloorGeometry.door_x(room)
	var gap := TILE * 1.25
	draw_texture_rect(CAP, Rect2(0, h, door_x - gap / 2.0, front), true, CAP_SHADE)
	draw_texture_rect(CAP, Rect2(door_x + gap / 2.0, h, w - door_x - gap / 2.0, front), true, CAP_SHADE)

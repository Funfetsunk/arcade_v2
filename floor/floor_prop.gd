class_name FloorProp
extends Node2D
## A bought decor prop or facility: its sprite stood bottom-centre on its spot,
## with a soft shadow when it stands on the floor.

const TILE := FloorGeometry.TILE
## How far above the back wall's trim wall props hang.
const WALL_HANG := 8.0

## Texture -> the rect its pixels use, so each sprite stands on its own feet.
static var _used: Dictionary[Texture2D, Rect2i] = {}

var def: FloorPropDef

@onready var sprite: Sprite2D = $Sprite


func show_spot(spot: PropLayout.Spot) -> void:
	def = spot.def
	sprite.texture = def.sprite
	if def.sprite:
		var used := used_rect(def.sprite)
		var size := def.sprite.get_size()
		sprite.offset = Vector2(size.x / 2.0 - (used.position.x + used.size.x / 2.0), size.y / 2.0 - used.end.y)
	var x := (spot.tile.x + def.width / 2.0) * TILE
	if def.on_wall:
		position = Vector2(x, -WALL_HANG)
	elif def.flat:
		# Rugs are centred on their tiles rather than standing at the back of them.
		position = Vector2(x, (spot.tile.y + 1) * TILE - 4.0)
	else:
		position = Vector2(x, (spot.tile.y + 1) * TILE - 3.0)
	queue_redraw()


static func used_rect(texture: Texture2D) -> Rect2i:
	if not _used.has(texture):
		_used[texture] = texture.get_image().get_used_rect()
	return _used[texture]


func _draw() -> void:
	if def == null or def.on_wall or def.flat:
		return
	draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, TILE * def.width * 0.4, Color(0, 0, 0, 0.3))

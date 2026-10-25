class_name CashierDesk
extends Node2D
## The ticket desk in the front-left corner (FloorGrid.desk_tiles), always there
## as in the original; a hired cashier stands behind it. It is drawn with the
## walls' shader, so the whole desk takes the theme's colour like the walls.

const TILE := FloorGeometry.TILE

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	sprite.material = get_node("../../Room/WallFace").material
	var used := FloorProp.used_rect(sprite.texture)
	var size := sprite.texture.get_size()
	sprite.offset = Vector2(size.x / 2.0 - (used.position.x + used.size.x / 2.0), size.y / 2.0 - used.end.y)


func show_desk(room: Vector2i) -> void:
	position = Vector2(TILE, room.y * TILE - 3.0)


## Where the cashier stands: behind the desk, so the desk hides their legs.
func cashier_spot() -> Vector2:
	return position + Vector2(0, -14)

class_name Walker
extends Node2D
## Someone on the floor who walks a list of waypoints, playing the matching
## 4-direction walk/idle animation.

signal arrived

## Pixels per second.
@export var speed := 40.0

var waypoints := PackedVector2Array()
var facing := &"south"

@onready var sprite: AnimatedSprite2D = $Sprite


func walk(points: PackedVector2Array) -> void:
	waypoints = points


## Tints the sprite (placeholder looks for staff without their own art yet).
func sprite_modulate(color: Color) -> void:
	$Sprite.modulate = color


func is_moving() -> bool:
	return not waypoints.is_empty()


## Faces a direction without moving (e.g. towards a cabinet while playing).
func face(direction: Vector2) -> void:
	facing = _facing_for(direction)
	sprite.play(&"idle_" + facing)


func _process(delta: float) -> void:
	if waypoints.is_empty():
		return
	var target := waypoints[0]
	var to_target := target - position
	var step := speed * delta
	if to_target.length() <= step:
		position = target
		waypoints.remove_at(0)
		if waypoints.is_empty():
			sprite.play(&"idle_" + facing)
			arrived.emit()
		return
	facing = _facing_for(to_target)
	sprite.play(&"walk_" + facing)
	position += to_target / to_target.length() * step


static func _facing_for(direction: Vector2) -> StringName:
	if absf(direction.x) > absf(direction.y):
		return &"east" if direction.x > 0.0 else &"west"
	return &"south" if direction.y > 0.0 else &"north"

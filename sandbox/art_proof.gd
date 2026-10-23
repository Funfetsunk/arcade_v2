extends Node2D
## Throwaway preview of the locked art set: carpet floor, the space_inv cabinet in
## all four facings, and a customer idling at each one while another walks a loop.

const ROOM_TILES := Vector2i(20, 12)

@onready var floor_layer: TileMapLayer = $Floor
@onready var walker: AnimatedSprite2D = $Walker


func _ready() -> void:
	for x in ROOM_TILES.x:
		for y in ROOM_TILES.y:
			floor_layer.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	_walk_loop()


func _walk_loop() -> void:
	var points: Array[Vector2] = [Vector2(48, 248), Vector2(592, 248), Vector2(592, 336), Vector2(48, 336)]
	walker.position = points[0]
	var tween := create_tween().set_loops()
	for i in points.size():
		var target := points[(i + 1) % points.size()]
		var from := points[i]
		tween.tween_callback(walker.play.bind(_walk_anim(target - from)))
		tween.tween_property(walker, "position", target, from.distance_to(target) / 40.0)


func _walk_anim(delta: Vector2) -> StringName:
	if absf(delta.x) > absf(delta.y):
		return &"walk_east" if delta.x > 0 else &"walk_west"
	return &"walk_south" if delta.y > 0 else &"walk_north"

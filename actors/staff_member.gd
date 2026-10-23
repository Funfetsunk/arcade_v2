class_name StaffMember
extends Walker
## A hired techie, guard or manager pacing the open strip at the front of the floor.

## The strip they pace, in floor pixels.
var roam_area := Rect2()
var _pause := 0.0


func _ready() -> void:
	_pause = randf_range(0.5, 1.5)


func _process(delta: float) -> void:
	super(delta)
	if is_moving():
		return
	_pause -= delta
	if _pause <= 0.0:
		var target := roam_area.position + Vector2(randf(), randf()) * roam_area.size
		walk(PackedVector2Array([target]))
		_pause = randf_range(0.7, 2.8)

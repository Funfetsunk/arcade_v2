extends CanvasLayer
## Rotate / place / cancel buttons shown while placing a machine, so placement
## works by touch as well as mouse (R rotates and Enter/Escape place/cancel too).

@export var arcade_floor: ArcadeFloor


func _ready() -> void:
	hide()
	arcade_floor.placing_changed.connect(func(active: bool) -> void: visible = active)
	%RotateLeft.pressed.connect(arcade_floor.rotate_ghost.bind(-1))
	%RotateRight.pressed.connect(arcade_floor.rotate_ghost.bind(1))
	%Place.pressed.connect(arcade_floor.commit_placing)
	%Cancel.pressed.connect(arcade_floor.cancel_placing)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed():
		return
	match (event as InputEventKey).keycode:
		KEY_R:
			arcade_floor.rotate_ghost(1)
		KEY_ENTER, KEY_KP_ENTER:
			arcade_floor.commit_placing()
		KEY_ESCAPE:
			arcade_floor.cancel_placing()

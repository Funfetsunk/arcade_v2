class_name Cabinet
extends Node2D
## A machine on the floor: its sprite for the current facing, dimmed when broken.

## Machines without art yet borrow this one's sprites, tinted by genre.
const PLACEHOLDER: MachineDef = preload("res://data/catalogs/machines/space_inv.tres")
const BROKEN_TINT := Color(0.55, 0.4, 0.45)

var machine: MachineInstance
var selected := false:
	set(value):
		selected = value
		queue_redraw()

@onready var sprite: Sprite2D = $Sprite


func show_machine(m: MachineInstance) -> void:
	machine = m
	refresh()


## Re-reads position, facing and condition from the machine.
func refresh() -> void:
	show_as(machine.def, machine.facing)
	position = FloorGeometry.machine_anchor(machine)
	if machine.is_broken():
		sprite.modulate = BROKEN_TINT


## Shows a machine type at a facing (also used by the placement ghost).
func show_as(def: MachineDef, facing: MachineInstance.Facing) -> void:
	var texture := def.sprite_for(facing)
	sprite.modulate = Color.WHITE
	if texture == null:
		texture = PLACEHOLDER.sprite_for(facing)
		if def.genre:
			sprite.modulate = Color.WHITE.lerp(def.genre.color, 0.45)
		else:
			sprite.modulate = Color(0.85, 0.75, 0.6)
	sprite.texture = texture
	queue_redraw()


func _draw() -> void:
	# A soft shadow under the base, and a highlight ring when selected.
	var width := FloorGeometry.TILE * (machine.def.footprint.x if machine else 1)
	draw_set_transform(Vector2(0, -3), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, width * 0.5, Color(0, 0, 0, 0.35))
	if selected:
		draw_arc(Vector2.ZERO, width * 0.62, 0.0, TAU, 32, Color("ffb703"), 3.0)

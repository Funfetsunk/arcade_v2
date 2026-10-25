class_name ThemeDef
extends Resource
## A cosmetic interior skin.

@export var id: StringName
@export var display_name: String
@export var emoji: String
## The wall art is toned toward this hue (only its hue counts, not how dark it is).
@export var wall: Color
## How strongly the wall art takes the hue: 0 keeps the art as drawn.
@export_range(0.0, 1.0) var wall_tint_strength := 0.0
@export var floor_tint: Color
@export var sign_color: Color

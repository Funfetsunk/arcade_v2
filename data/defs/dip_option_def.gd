class_name DipOptionDef
extends Resource
## One setting of a DIP switch and its effect on earnings and reputation.

@export var value: StringName
@export var label: String
@export var earn_mul: float = 1.0
@export var rep_mul: float = 1.0

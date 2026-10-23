class_name DipSwitchDef
extends Resource
## A DIP switch an arcade cabinet exposes (difficulty, free play, lives, ...).

@export var id: StringName
@export var label: String
@export var options: Array[DipOptionDef] = []


## The factory setting: OFF for two-way switches, the middle option otherwise.
func default_index() -> int:
	return 0 if options.size() == 2 else 1

class_name FacilityDef
extends Resource
## A customer-needs facility. Without it, satisfaction suffers once daily
## visitors pass need_at.

@export var id: StringName
@export var display_name: String
@export var emoji: String
@export var cost: int
@export var need_at: int
@export var penalty: int
@export var blurb: String

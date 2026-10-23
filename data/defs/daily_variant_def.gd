class_name DailyVariantDef
extends Resource
## A starting setup for the date-seeded daily challenge.

@export var id: StringName
@export var machines: Array[MachineDef] = []
@export var cash: int
@export var rep: int
@export var difficulty: DifficultyDef
@export var blurb: String

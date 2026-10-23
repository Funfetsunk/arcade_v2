class_name ResearchDef
extends Resource
## An R&D project with prerequisites.

@export var id: StringName
@export var display_name: String
@export var emoji: String
@export var cost: int
@export var requires: Array[ResearchDef] = []
@export var description: String

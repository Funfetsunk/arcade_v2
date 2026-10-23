class_name DecisionEventDef
extends Resource
## A pre-day choice. Option 0 is the "do it" choice; the last one declines.

enum Condition { ALWAYS, ANY_MACHINE_DAMAGED }

@export var id: StringName
@export var emoji: String
@export var title: String
@export_multiline var description: String
@export var options: Array[DecisionOptionDef] = []
## Only offered while this holds.
@export var condition: Condition = Condition.ALWAYS

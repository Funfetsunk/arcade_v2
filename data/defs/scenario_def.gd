class_name ScenarioDef
extends Resource
## A campaign scenario: a starting situation plus a win condition.

@export var id: StringName
@export var display_name: String
@export var emoji: String
@export_multiline var blurb: String
@export_group("Start")
@export var start_cash: int = 2000
@export var start_rep: int = 5
@export var start_day: int
@export var start_machines: Array[MachineDef] = []
## Indices into start_machines that start broken and queued for repair.
@export var broken_machines: PackedInt32Array
## Starting loan; an amount of 0 means none.
@export var loan_amount: int
@export var loan_total_owed: int
@export var loan_daily_payment: int
@export var loan_days: int
@export_group("Goal")
@export var goal_label: String
## All must be met to win.
@export var goal: Array[StatRequirement] = []
## Target day count for a 3-star finish; 0 means none.
@export var par_days: int


func is_won(state: GameState) -> bool:
	return goal.all(func(r: StatRequirement) -> bool: return r.is_met(state))

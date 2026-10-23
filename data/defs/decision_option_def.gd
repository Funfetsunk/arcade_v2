class_name DecisionOptionDef
extends Resource
## One choice in a pre-day decision event.

@export var label: String
## Paid now.
@export var cost: int
## Received now.
@export var gain_cash: int
@export var rep_add: int
## Footfall multiplier for the upcoming day.
@export var foot_mul: float = 1.0
## No machine wear the upcoming day.
@export var protect: bool
## Repair every machine to 100% now.
@export var repair_all: bool
@export var log_message: String

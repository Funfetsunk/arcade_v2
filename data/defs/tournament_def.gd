class_name TournamentDef
extends Resource
## A tournament tier you can book a few days ahead.

@export var id: StringName
@export var display_name: String
@export var emoji: String
@export var cost: int
@export var lead_days: int
@export var foot_mul: float = 1.0
@export var entrants: int
@export var entry_fee: int
@export var prize: int
@export var rep_gain: int
@export var rep_req: int
@export var blurb: String

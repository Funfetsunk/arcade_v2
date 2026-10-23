class_name CampaignDef
extends Resource
## A paid ad campaign: a footfall boost lasting a number of days.

@export var id: StringName
@export var display_name: String
@export var emoji: String
@export var cost: int
@export var foot_mul: float = 1.0
@export var days: int
@export var blurb: String

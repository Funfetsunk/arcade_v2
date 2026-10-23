class_name PerkDef
extends Resource
## A prestige perk bought with prestige points; persists across runs.

enum Kind { EARN, FOOT, SATIS, REPAIR, CASH }

@export var id: StringName
@export var display_name: String
@export var emoji: String
@export var max_rank: int
@export var per_rank: float
@export var kind: Kind
@export var description: String

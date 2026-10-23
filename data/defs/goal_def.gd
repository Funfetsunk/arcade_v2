class_name GoalDef
extends Resource
## An in-run milestone that pays a one-time cash or rep reward.

enum RewardKind { CASH, REP }

@export var id: StringName
@export var label: String
@export var reward: int
@export var reward_kind: RewardKind
@export var requirement: StatRequirement

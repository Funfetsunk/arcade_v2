class_name StaffDef
extends Resource
## A hireable staff role.

enum Skill { REPAIR, CASHIER, SECURITY, MANAGER, ATTENDANT }

@export var id: StringName
@export var display_name: String
@export var emoji: String
@export var wage: int
@export var role: String
@export var skill: Skill
@export var level: int = 1
@export var rep_req: int

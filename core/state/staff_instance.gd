class_name StaffInstance
extends Resource
## A hired staff member.

@export var def: StaffDef
@export var id: int
## 0-100; low morale makes staff quit.
@export var morale: float = 78.0
@export var trained: bool

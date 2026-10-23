class_name RandomEventDef
extends Resource
## A passive overnight event, rolled once per day inside the sim.

enum Kind { MONEY, GOOD, BAD, INFO }

## Only events with special handling in the sim need an id.
@export var id: StringName
@export var message: String
@export var cash: int
@export var rep: int
@export var customers: int
@export var kind: Kind = Kind.INFO
## Skipped unless this upgrade is owned.
@export var needs_upgrade: UpgradeDef
## Skipped unless a machine of this type is on the floor.
@export var needs_machine: MachineDef

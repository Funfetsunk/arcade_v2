class_name TownDef
extends Resource
## A town where you can open a franchise.

@export var id: StringName
@export var display_name: String
@export var emoji: String
@export var cost: int
## Daily income at level 1.
@export var income: int
@export var blurb: String


func daily_income(level: int) -> int:
	return GameMath.js_round(income * level)


func upgrade_cost(level: int) -> int:
	return GameMath.js_round(cost * 0.4 * level)

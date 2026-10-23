class_name StockItemDef
extends Resource
## An item sold from a vending machine or food counter, or redeemed at the prize booth.

@export var id: StringName
@export var display_name: String
@export var emoji: String
@export var base_pop: float
@export var default_price: float
@export var description: String
## Daily spoilage fraction of unsold units (0 = packaged goods).
@export var perish: float
## Prize booth only: tickets needed to redeem one.
@export var ticket_cost: int
## Explicit wholesale cost per unit; negative means derive it from the sale price.
@export var wholesale_cost: float = -1.0


func unit_cost(restock_rate: float) -> float:
	if wholesale_cost >= 0.0:
		return wholesale_cost
	return maxf(0.05, snappedf(default_price * restock_rate, 0.01))

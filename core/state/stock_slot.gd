class_name StockSlot
extends Resource
## One item line on a vending machine, food counter or prize booth.

@export var item: StockItemDef
## Sale price (vending/food) or ticket cost (prize booth).
@export var price: float
@export var active: bool = true
## Units on hand. Can be fractional, as in the original. Negative means unlimited.
@export var qty: float = -1.0


func is_limited() -> bool:
	return qty >= 0.0

class_name GameBalance
extends Resource
## Global tuning numbers that aren't part of any one catalog entry.

@export_group("New game")
@export var start_cash: int = 2000
@export var start_rep: int = 5
@export var start_room := Vector2i(16, 10)
@export var start_satisfaction: int = 70
@export var arcade_name := "ARCADE EMPIRE"

@export_group("Running costs")
## Rent for the starting room; scales with floor area.
@export var base_rent: int = 51
@export var electricity_rate: float = 1.5
@export var repair_cost: int = 80
@export var repair_cost_with_bench: int = 40

@export_group("Stock")
@export var stock_cap: int = 40
## Wholesale restock cost as a fraction of the sale price.
@export var restock_cost_rate: float = 0.35

@export_group("Calendar")
@export var weekday_names: PackedStringArray
@export var weekday_long_names: PackedStringArray
## Footfall multiplier per weekday, Monday first.
@export var weekday_foot: PackedFloat64Array
@export var season_length: int = 14

@export_group("Meta")
@export var prestige_rate: float = 0.03
@export var atm_fee: float = 0.4
@export var max_decor: int = 12
@export var jackpot_seed_pot: int = 250
@export var staff_start_morale: int = 78
@export var discount_foot_mul: float = 1.25
@export var discount_earn_mul: float = 0.8
@export var daily_challenge_days: int = 12
@export var franchise_rep_req: int = 40

@export_group("Rival")
@export var rival_names: PackedStringArray
@export var rival_news: PackedStringArray
@export var rival_appear_day: int = 8
@export var rival_growth: float = 2.5
@export var undercut_cost: int = 800
@export var undercut_hit: int = 25

class_name GameData
extends Resource
## Every catalog in the game, plus id lookups. One instance lives at
## res://data/catalogs/game_data.tres and is exposed by the Data autoload.

@export var balance: GameBalance
@export var machines: Array[MachineDef] = []
@export var staff: Array[StaffDef] = []
@export var upgrades: Array[UpgradeDef] = []
@export var random_events: Array[RandomEventDef] = []
@export var decision_events: Array[DecisionEventDef] = []
@export var dip_switches: Array[DipSwitchDef] = []
@export var genres: Array[GenreDef] = []
@export var vending_stock: Array[StockItemDef] = []
@export var counter_stock: Array[StockItemDef] = []
@export var prize_stock: Array[StockItemDef] = []
@export var loan_tiers: Array[LoanTierDef] = []
@export var goals: Array[GoalDef] = []
@export var achievements: Array[AchievementDef] = []
@export var scenarios: Array[ScenarioDef] = []
@export var contracts: Array[ContractDef] = []
@export var campaigns: Array[CampaignDef] = []
@export var difficulties: Array[DifficultyDef] = []
@export var perks: Array[PerkDef] = []
@export var research: Array[ResearchDef] = []
@export var tournaments: Array[TournamentDef] = []
@export var towns: Array[TownDef] = []
@export var weathers: Array[WeatherDef] = []
@export var seasons: Array[SeasonDef] = []
@export var themes: Array[ThemeDef] = []
@export var decor_props: Array[DecorPropDef] = []
@export var facilities: Array[FacilityDef] = []
@export var daily_variants: Array[DailyVariantDef] = []

## catalog property name -> { id -> def }, built on first lookup.
var _index: Dictionary = {}


func machine(id: StringName) -> MachineDef:
	return _find(&"machines", id)


func staff_role(id: StringName) -> StaffDef:
	return _find(&"staff", id)


func upgrade(id: StringName) -> UpgradeDef:
	return _find(&"upgrades", id)


func genre(id: StringName) -> GenreDef:
	return _find(&"genres", id)


func scenario(id: StringName) -> ScenarioDef:
	var found: ScenarioDef = _find(&"scenarios", id)
	return found if found else scenarios[0]


func difficulty(id: StringName) -> DifficultyDef:
	var found: DifficultyDef = _find(&"difficulties", id)
	return found if found else _find(&"difficulties", &"normal")


func weather(id: StringName) -> WeatherDef:
	var found: WeatherDef = _find(&"weathers", id)
	return found if found else _find(&"weathers", &"cloudy")


func theme(id: StringName) -> ThemeDef:
	var found: ThemeDef = _find(&"themes", id)
	return found if found else themes[0]


func contract(id: StringName) -> ContractDef:
	return _find(&"contracts", id)


func campaign(id: StringName) -> CampaignDef:
	return _find(&"campaigns", id)


func perk(id: StringName) -> PerkDef:
	return _find(&"perks", id)


func research_project(id: StringName) -> ResearchDef:
	return _find(&"research", id)


func tournament(id: StringName) -> TournamentDef:
	return _find(&"tournaments", id)


func town(id: StringName) -> TownDef:
	return _find(&"towns", id)


func decor_prop(id: StringName) -> DecorPropDef:
	return _find(&"decor_props", id)


func facility(id: StringName) -> FacilityDef:
	return _find(&"facilities", id)


func stock_catalog(type: MachineDef.Type) -> Array[StockItemDef]:
	match type:
		MachineDef.Type.VENDING:
			return vending_stock
		MachineDef.Type.FOOD:
			return counter_stock
		MachineDef.Type.PRIZES:
			return prize_stock
	return []


func stock_item(id: StringName) -> StockItemDef:
	for list: Array[StockItemDef] in [vending_stock, counter_stock, prize_stock]:
		for item in list:
			if item.id == id:
				return item
	return null


## Season for a day number; day 1 is the first day of spring.
func season_of(day: int) -> SeasonDef:
	var idx := floori((maxi(1, day) - 1) / float(balance.season_length)) % seasons.size()
	return seasons[idx]


## Weather id for a 0..1 roll, picked by weight.
func roll_weather(roll: float) -> StringName:
	var total := 0
	for w in weathers:
		total += w.weight
	var r := clampf(roll, 0.0, 1.0) * total
	for w in weathers:
		r -= w.weight
		if r <= 0.0:
			return w.id
	return weathers[-1].id


func weekday_index(day: int) -> int:
	return posmod(day - 1, 7)


func weekday_name(day: int) -> String:
	return balance.weekday_names[weekday_index(day)]


func weekday_foot_mul(day: int) -> float:
	return balance.weekday_foot[weekday_index(day)]


## Seed for the daily challenge on a date ("YYYY-MM-DD"); same all day.
func daily_seed(date: String) -> int:
	return GameMath.hash_string("ae-daily-" + date)


func daily_variant(date: String) -> DailyVariantDef:
	return daily_variants[daily_seed(date) % daily_variants.size()]


func prestige_mul(level: int) -> float:
	return 1.0 + balance.prestige_rate * maxi(0, level)


## Footfall multiplier from the strength gap with the rival (ahead = bonus).
static func rival_foot_mul(player_strength: float, rival_strength: float) -> float:
	return clampf(1.0 + (player_strength - rival_strength) * 0.01, 0.7, 1.3)


func _find(catalog: StringName, id: StringName) -> Resource:
	if not _index.has(catalog):
		var by_id := {}
		for def: Resource in get(catalog):
			by_id[def.get(&"id")] = def
		_index[catalog] = by_id
	return _index[catalog].get(id)

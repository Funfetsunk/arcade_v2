class_name GameState
extends Resource
## Everything about one run of the game. Saved and loaded as a whole.
## Ported from the original `G` object (state.ts / types.ts).

## Bumped when the save format changes incompatibly; older saves are discarded.
const SAVE_VERSION := 1

@export var save_version: int = SAVE_VERSION

@export_group("Money and progress")
@export var cash: float = 2000.0
@export var rep: float = 5.0
## 0 = setup day (doors closed); 1+ = paying days.
@export var day: int
@export var total_customers: int
@export var total_earned: float
@export var total_spent: float

@export_group("Arcade")
@export var arcade_name := "ARCADE EMPIRE"
@export var theme: StringName = &"classic"
## Interior size in tiles.
@export var room := Vector2i(16, 10)
@export var machines: Array[MachineInstance] = []
@export var staff: Array[StaffInstance] = []
@export var upgrades: Array[UpgradeDef] = []
## Machine ids broken and waiting for a technician, oldest first.
@export var pending_repairs: Array[int] = []
@export var next_instance_id: int = 1
@export var satisfaction: float = 70.0

@export_group("Last day")
@export var last_day_earned: float
@export var last_day_cost: float
@export var last_day_customers: int
@export var last_day_rent: float
@export var last_day_elec: float
@export var last_day_wages: float
@export var last_day_loan: float
@export var last_day_repair: float

@export_group("Metrics")
@export var days_run: int
## Best single-day profit; only meaningful once has_biggest_day is set.
@export var biggest_day: float
@export var has_biggest_day: bool
@export var total_repairs: int
@export var total_repair_cost: float

@export_group("Run")
@export var loan: LoanState
@export var next_day_buff: DayBuff
@export var goals_done: Array[StringName] = []
@export var empire_won: bool
@export var scenario: StringName = &"free"
@export var scenario_won: bool
@export var difficulty: StringName = &"normal"

@export_group("Systems")
## Sticky once a junior tech has ever been hired.
@export var senior_tech_unlocked: bool
@export var total_tickets: int
@export var last_day_tickets: int
@export var last_day_redeemed: int
@export var ticket_machines: int
@export var campaign: CampaignState
## Happy-hour discount: more visitors, thinner takings.
@export var discount_on: bool
@export var tournament: TournamentBooking
@export var decor: Array[DecorPropDef] = []
@export var facilities: Array[FacilityDef] = []
## Forecast for the next day to run; null until first rolled.
@export var weather: WeatherDef
@export var buzz: float
@export var daily_key: String
## Days left in the daily challenge; -1 when not playing one.
@export var daily_days_left: int = -1
@export var rival: RivalState
@export var contract: ContractBooking
@export var research: Array[ResearchDef] = []
@export var franchises: Array[FranchiseState] = []

@export_group("Sim multipliers")
## Each is neutral at 1.0. The day-orchestration systems set them before a day runs.
@export var day_rhythm_mul: float = 1.0
@export var diff_foot_mul: float = 1.0
@export var promo_foot_mul: float = 1.0
@export var weather_foot_mul: float = 1.0
@export var buzz_foot_mul: float = 1.0
@export var rival_foot_mul: float = 1.0
@export var research_foot_mul: float = 1.0
@export var prestige_mul: float = 1.0
@export var promo_earn_mul: float = 1.0
@export var research_earn_mul: float = 1.0
@export var research_elec_mul: float = 1.0


func new_instance_id() -> int:
	next_instance_id += 1
	return next_instance_id - 1


func machine_by_id(id: int) -> MachineInstance:
	for m in machines:
		if m.id == id:
			return m
	return null


func has_upgrade(id: StringName) -> bool:
	return upgrades.any(func(u: UpgradeDef) -> bool: return u.id == id)


func has_research(id: StringName) -> bool:
	return research.any(func(r: ResearchDef) -> bool: return r.id == id)


func has_facility(id: StringName) -> bool:
	return facilities.any(func(f: FacilityDef) -> bool: return f.id == id)


func has_machine_type(type: MachineDef.Type) -> bool:
	return machines.any(func(m: MachineInstance) -> bool: return m.def.type == type)


func has_machine(id: StringName) -> bool:
	return machines.any(func(m: MachineInstance) -> bool: return m.def.id == id)


func franchise_in(town: TownDef) -> FranchiseState:
	for f in franchises:
		if f.town == town:
			return f
	return null


## Highest staff level hired for a skill; 0 if nobody has it.
func staff_level(skill: StaffDef.Skill) -> int:
	var best := 0
	for s in staff:
		if s.def.skill == skill:
			best = maxi(best, s.def.level)
	return best


func stat_value(stat: StatRequirement.Stat) -> float:
	match stat:
		StatRequirement.Stat.DAY:
			return day
		StatRequirement.Stat.CASH:
			return cash
		StatRequirement.Stat.REP:
			return rep
		StatRequirement.Stat.TOTAL_EARNED:
			return total_earned
		StatRequirement.Stat.BIGGEST_DAY:
			return biggest_day if has_biggest_day else 0.0
		StatRequirement.Stat.MACHINE_COUNT:
			return machines.size()
		StatRequirement.Stat.DISTINCT_MACHINE_TYPES:
			var types := {}
			for m in machines:
				types[m.def] = true
			return types.size()
		StatRequirement.Stat.CLASSIC_MACHINE_COUNT:
			return machines.filter(func(m: MachineInstance) -> bool:
				return m.def.genre != null and m.def.genre.id == &"classic").size()
		StatRequirement.Stat.MAX_TUNE_UP:
			var best := 0
			for m in machines:
				best = maxi(best, m.tune_up_level)
			return best
		StatRequirement.Stat.TOTAL_REPAIRS:
			return total_repairs
		StatRequirement.Stat.FLOOR_AREA:
			return room.x * room.y
		StatRequirement.Stat.EMPIRE_WON:
			return 1.0 if empire_won else 0.0
	return 0.0

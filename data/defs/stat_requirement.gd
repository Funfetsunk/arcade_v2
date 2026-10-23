class_name StatRequirement
extends Resource
## "Stat >= target": the building block for goals, achievements and scenario wins.

enum Stat {
	DAY, CASH, REP, TOTAL_EARNED, BIGGEST_DAY, MACHINE_COUNT, DISTINCT_MACHINE_TYPES,
	CLASSIC_MACHINE_COUNT, MAX_TUNE_UP, TOTAL_REPAIRS, FLOOR_AREA, EMPIRE_WON,
}

@export var stat: Stat
@export var target: float


func current(state: GameState) -> float:
	return state.stat_value(stat)


func is_met(state: GameState) -> bool:
	return current(state) >= target

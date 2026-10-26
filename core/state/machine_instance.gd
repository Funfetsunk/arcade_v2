class_name MachineInstance
extends Resource
## A machine placed on the floor.

enum Facing { N, E, S, W }

const MAX_DAY_STATS := 60

@export var def: MachineDef
## Unique per run; repairs and floor visuals address machines by this.
@export var id: int
@export var hp: float = 100.0
## Drops as the cabinet ages; refurbishing restores it.
@export var max_hp: float = 100.0
@export var tile: Vector2i
@export var facing: Facing = Facing.S
@export var price_per_play: float
@export var total_earned: float
@export var days_active: int
## DIP switch id -> selected option index.
@export var dips: Dictionary[StringName, int] = {}
@export var stock: Array[StockSlot] = []
## Last MAX_DAY_STATS days as (day, rounded earnings, plays).
@export var day_stats: Array[Vector3i] = []
## Tune-Up: +15% earnings per level.
@export var tune_up_level: int
## Reinforce: -25% wear per level.
@export var reinforce_level: int
## Themed-zone earnings multiplier, set by the floor on placement.
@export var zone_mul: float = 1.0
## Progressive jackpot pot (jackpot machines only).
@export var jackpot_pot: float
## Your best minigame score on this cabinet this run, and its stars; shown above
## the cabinet, and the stars make it more popular.
@export var best_score: int
@export var best_stars: int
## Paid minigame plays used, and the day they were used on.
@export var plays_used: int
@export var plays_day: int = -1


func is_broken() -> bool:
	return hp <= 0.0


## Paid minigame plays left today, out of `free_plays`.
func plays_left(day: int, free_plays: int) -> int:
	return maxi(0, free_plays - (plays_used if plays_day == day else 0))


func use_play(day: int) -> void:
	if plays_day != day:
		plays_day = day
		plays_used = 0
	plays_used += 1


func record_day(day: int, earn: int, plays: int) -> void:
	day_stats.append(Vector3i(day, earn, plays))
	if day_stats.size() > MAX_DAY_STATS:
		day_stats.pop_front()


## Combined DIP switch effect, as { earn_mul, rep_mul }.
func dip_multipliers() -> Dictionary:
	var earn_mul := 1.0
	var rep_mul := 1.0
	for switch in def.dip_switches:
		var idx: int = dips.get(switch.id, switch.default_index())
		var option: DipOptionDef = switch.options[idx] if idx < switch.options.size() else switch.options[switch.default_index()]
		earn_mul *= option.earn_mul
		rep_mul *= option.rep_mul
	return { earn_mul = earn_mul, rep_mul = rep_mul }

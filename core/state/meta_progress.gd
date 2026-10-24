class_name MetaProgress
extends Resource
## Progress that survives across runs: prestige, perks, achievements, the
## leaderboard and daily-challenge bests. Saved separately from the run.

const MAX_LEADERBOARD := 25

@export var prestige_level: int
@export var perk_ranks: Dictionary[StringName, int] = {}
@export var achievements: Array[StringName] = []
## Best runs by total takings, highest first.
@export var leaderboard: Array[ScoreEntry] = []
## Daily challenge date ("YYYY-MM-DD") -> best takings that day.
@export var daily_bests: Dictionary[String, int] = {}
@export var tutorial_done: bool
## Sound settings (the original kept these in localStorage).
@export var sound_muted: bool
@export var jukebox_track: StringName = &"arcade"


func perk_rank(id: StringName) -> int:
	return perk_ranks.get(id, 0)


func perk_points() -> int:
	var spent := 0
	for rank: int in perk_ranks.values():
		spent += rank
	return maxi(0, prestige_level - spent)


## Effect of a perk at its current rank (rank x per-rank value).
func perk_effect(data: GameData, id: StringName) -> float:
	return data.perk(id).per_rank * perk_rank(id)


func add_score(entry: ScoreEntry) -> void:
	leaderboard.append(entry)
	leaderboard.sort_custom(func(a: ScoreEntry, b: ScoreEntry) -> bool: return a.earned > b.earned)
	leaderboard.resize(mini(leaderboard.size(), MAX_LEADERBOARD))

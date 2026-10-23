class_name GameSystem
extends RefCounted
## Base for the systems that change a run outside the sim (DayCycle, Actions).
## They report through signals; the Game autoload relays them to EventBus.

signal logged(message: String, kind: Sim.LogKind)
signal toast_requested(message: String, kind: Sim.LogKind)

var data: GameData
var meta: MetaProgress
## Stands in for the original's Math.random(), kept apart from the sim's seeded
## stream so the sim matches the original exactly on its own.
var rng: Rng


func _init(game_data: GameData, meta_progress: MetaProgress, random: Rng) -> void:
	data = game_data
	meta = meta_progress
	rng = random


func _log(message: String, kind := Sim.LogKind.INFO) -> void:
	logged.emit(message, kind)


func _toast(message: String, kind := Sim.LogKind.INFO) -> void:
	toast_requested.emit(message, kind)


## Shows the reason an action couldn't happen; returns false for convenient early returns.
func _refuse(message: String) -> bool:
	_toast(message, Sim.LogKind.BAD)
	return false


## Footfall multiplier from difficulty and the Word of Mouth perk, and the
## earnings multiplier from the Lucky Coins perk.
func apply_meta(state: GameState) -> void:
	state.diff_foot_mul = data.difficulty(state.difficulty).foot_mul * (1.0 + meta.perk_effect(data, &"word"))
	state.prestige_mul = 1.0 + meta.perk_effect(data, &"coins")


func apply_research(state: GameState) -> void:
	state.research_elec_mul = 0.8 if state.has_research(&"power") else 1.0
	state.research_earn_mul = 1.08 if state.has_research(&"pricing") else 1.0
	state.research_foot_mul = (1.10 if state.has_research(&"buzz") else 1.0) * (1.15 if state.has_research(&"hype") else 1.0)


## Strength the rival is compared against.
func player_strength(state: GameState) -> int:
	return GameMath.js_round(state.rep + state.machines.size() * 3 + minf(50.0, state.total_earned / 2000.0))


func record_score(state: GameState, reason: StringName) -> ScoreEntry:
	var sc := data.scenario(state.scenario)
	var entry := ScoreEntry.new()
	entry.arcade_name = state.arcade_name
	entry.scenario = sc.id
	entry.scenario_name = sc.display_name
	entry.day = state.day
	entry.cash = GameMath.js_round(state.cash)
	entry.rep = GameMath.js_round(state.rep)
	entry.earned = GameMath.js_round(state.total_earned)
	entry.machines = state.machines.size()
	entry.prestige = meta.prestige_level
	entry.won = state.scenario_won or state.empire_won
	entry.reason = reason
	entry.timestamp = int(Time.get_unix_time_from_system())
	meta.add_score(entry)
	return entry

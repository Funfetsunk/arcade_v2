class_name ScoreEntry
extends Resource
## One finished (or abandoned) run on the local leaderboard.

@export var arcade_name: String
@export var scenario: StringName
@export var scenario_name: String
@export var day: int
@export var cash: int
@export var rep: int
@export var earned: int
@export var machines: int
@export var prestige: int
@export var won: bool
## Why it was recorded: scenario, empire, prestige or restart.
@export var reason: StringName
@export var timestamp: int

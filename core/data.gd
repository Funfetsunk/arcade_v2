extends Node
## Autoload "Data": the game's catalogs, loaded once.

const GAME_DATA: GameData = preload("res://data/catalogs/game_data.tres")

var db: GameData = GAME_DATA

extends Node
## Entry point: resume the saved run, or start a fresh one.


func _ready() -> void:
	if not Game.load_game():
		Game.new_game(&"free")

extends Node
## Entry point: resume the saved run, or start a fresh one (with the how-to-play
## the first time).


func _ready() -> void:
	if not Game.load_game():
		Game.new_game(&"free")
		if not Game.meta.tutorial_done:
			$GameUI.show_tutorial()

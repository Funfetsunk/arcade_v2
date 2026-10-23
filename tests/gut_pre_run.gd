extends GutHookScript
## Runs before the suite: keep tests that drive the Game autoload away from the
## real save files.


func run() -> void:
	Game.save_path = "user://test_run_save.tres"
	Game.meta_path = "user://test_run_meta.tres"
	Game.meta = MetaProgress.new()
	Game.day_cycle.meta = Game.meta
	Game.actions.meta = Game.meta

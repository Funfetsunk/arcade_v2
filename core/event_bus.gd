extends Node
## Autoload "EventBus": game-wide signals the view layer listens to.
## The sim's own signals are relayed through here by the Game autoload.
@warning_ignore_start("unused_signal")

signal logged(message: String, kind: Sim.LogKind)
signal toast_requested(message: String, kind: Sim.LogKind)
signal customers_reset
signal coin_spawned(machine_id: int, value: int)
signal repair_worker_spawned(machine_id: int, is_senior: bool)
## The state changed in a way the HUD and panels should redraw for.
signal state_changed
signal game_started
signal game_loaded

extends GutTest
## The Game autoload wires the sim to EventBus and starts runs from scenarios.


func test_new_game_relays_sim_signals_through_event_bus() -> void:
	watch_signals(EventBus)
	Game.new_game(&"weekend")
	assert_signal_emitted(EventBus, "game_started")
	assert_eq(Game.state.scenario, &"weekend")
	assert_eq(Game.state.machines.size(), 4)
	Game.sim.run_day(Game.state)
	assert_signal_emitted(EventBus, "logged")
	assert_signal_emitted(EventBus, "customers_reset")
	assert_signal_emitted(EventBus, "state_changed")
	assert_eq(Game.state.day, 6)

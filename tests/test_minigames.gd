extends GutTest
## Every cabinet minigame boots, plays 20 simulated seconds of input without
## errors, and the bonus rule matches the original (min(180, round(score × 0.4))).

const H := preload("res://tests/sim_test_helper.gd")


func test_bonus_rule() -> void:
	var s := H.make_state({ cash = 0.0 })
	var actions := Actions.new(H.DATA, MetaProgress.new(), Rng.new(1), null)
	assert_eq(actions.award_minigame(s, "Test", 100), 40)
	assert_eq(s.cash, 40.0)
	assert_eq(s.buzz, 5.0)
	assert_eq(actions.award_minigame(s, "Test", 1000), 180, "capped")
	assert_eq(actions.award_minigame(s, "Test", 0), 0)


func test_every_minigame_runs() -> void:
	var played := 0
	for def in H.DATA.machines:
		if def.minigame == null:
			continue
		var game := def.minigame.instantiate() as MiniGame
		assert_not_null(game, "%s minigame is a MiniGame" % def.id)
		add_child_autofree(game)
		var results := []
		game.finished.connect(func(score: int) -> void: results.append(score))
		for frame in 20 * 60:
			if frame % 7 == 0:
				var at := Vector2(randf() * 360.0, randf() * 460.0)
				var press := InputEventMouseButton.new()
				press.button_index = MOUSE_BUTTON_LEFT
				press.pressed = true
				press.position = at
				game._on_board_input(press)
			elif frame % 7 == 4:
				# Release too, so hold-and-release games (Pro Hoops) actually shoot.
				var release := InputEventMouseButton.new()
				release.button_index = MOUSE_BUTTON_LEFT
				release.pressed = false
				release.position = Vector2(randf() * 360.0, randf() * 460.0)
				game._on_board_input(release)
			game._physics_process(1.0 / 60.0)
			game.board.queue_redraw()
		assert_true(game.score >= 0, "%s score" % def.id)
		assert_true(results.size() <= 1, "%s finishes at most once" % def.id)
		played += 1
	assert_gt(played, 0)

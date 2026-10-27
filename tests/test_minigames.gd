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


func test_bests_and_stars_are_kept() -> void:
	var meta := MetaProgress.new()
	var actions := Actions.new(H.DATA, meta, Rng.new(1), null)
	assert_true(actions.record_minigame(&"pong", 120, 1), "first score is a best")
	assert_false(actions.record_minigame(&"pong", 90, 2), "lower score is not")
	assert_eq(meta.minigame_bests[&"pong"], 120)
	assert_eq(meta.minigame_stars[&"pong"], 2, "stars keep the most ever earned")


func test_three_paid_plays_a_day_then_practice() -> void:
	var s := H.make_state({ cash = 0.0 })
	var actions := Actions.new(H.DATA, MetaProgress.new(), Rng.new(1), null)
	var m := MachineInstance.new()
	m.def = H.DATA.machine(&"pac")
	for i in 3:
		assert_true(actions.start_minigame_play(s, m), "paid play %d" % (i + 1))
	assert_false(actions.start_minigame_play(s, m), "fourth is practice")
	var result := actions.finish_minigame(s, m, &"maze", "Dot Maze", 100, 1, false)
	assert_eq(result.bonus, 0, "practice pays nothing")
	assert_eq(m.best_score, 100, "but the cabinet keeps your best")
	s.day += 1
	assert_eq(actions.minigame_plays_left(s, m), 3, "plays come back the next day")


func test_tuned_up_cabinets_pay_more_and_first_three_stars_pay_once() -> void:
	var s := H.make_state({ cash = 0.0 })
	var actions := Actions.new(H.DATA, MetaProgress.new(), Rng.new(1), null)
	assert_eq(actions.award_minigame(s, "Test", 100, 2), 60, "+25% per Tune-Up level")
	var m := MachineInstance.new()
	m.def = H.DATA.machine(&"pac")
	var first := actions.finish_minigame(s, m, &"maze", "Dot Maze", 500, 3, true)
	assert_eq(first.star_bonus, H.DATA.balance.minigame_three_star_bonus)
	var again := actions.finish_minigame(s, m, &"maze", "Dot Maze", 500, 3, true)
	assert_eq(again.star_bonus, 0, "only the first time")
	assert_eq(m.best_stars, 3)


func test_rounds_wait_for_a_tap_then_count_down() -> void:
	var game := (H.DATA.machine(&"pac").minigame.instantiate() as MiniGame)
	add_child_autofree(game)
	for i in 30:
		game._physics_process(1.0 / 60.0)
	assert_eq(game.stage, MiniGame.Stage.READY, "nothing starts until a tap")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	game._on_board_input(press)
	assert_eq(game.stage, MiniGame.Stage.COUNTDOWN)
	for i in MiniGame.COUNT_STEP * 3:
		game._physics_process(1.0 / 60.0)
	assert_eq(game.stage, MiniGame.Stage.PLAYING)
	assert_eq(game.stars_for(game.star_scores[1]), 2)


func test_skee_rings_score_from_the_edge_in() -> void:
	var game := (load("res://minigames/aim/aim.tscn") as PackedScene).instantiate() as MiniGame
	add_child_autofree(game)
	assert_eq(game.points_at(game.CENTRE), 50, "bullseye")
	assert_eq(game.points_at(game.CENTRE + Vector2(0, 100)), 10, "outer ring")
	assert_eq(game.points_at(game.POCKETS[0]), 100, "corner pocket")
	assert_eq(game.points_at(Vector2(180, 300)), 0, "short of the rings")


func test_every_pinball_table_launches_into_play() -> void:
	for path in ["res://minigames/pinball/table_stars.tres", "res://minigames/pinball/table_planets.tres"]:
		var game := (load("res://minigames/pinball/pinball.tscn") as PackedScene).instantiate() as MiniGame
		add_child_autofree(game)
		game.use_table(load(path))
		game.stage = MiniGame.Stage.PLAYING
		game.state = game.State.CHARGING
		game._launch()
		var lowest := 999.0
		for i in 90:
			game._tick()
			lowest = minf(lowest, game.ball.y)
		assert_lt(lowest, 140.0, "%s: the launch reaches the top of the table" % path)
		assert_lt(game.ball.x, 320.0, "%s: and is turned into play" % path)


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


func test_maze_ghost_stays_on_the_grid_when_fright_starts_mid_tile() -> void:
	# A power pellet eaten while the ghost is between tiles used to switch its
	# speed mid-step, so it never landed on a centre again and left the maze.
	var maze_def: MachineDef = H.DATA.machine(&"pac")
	var game := maze_def.minigame.instantiate() as MiniGame
	add_child_autofree(game)
	for frame in 30 * 60:
		if frame % 37 == 5:
			game._fright = 0 if game._fright > 0 else 180
		game._move_ghost()
		var tile: Vector2i = game.ghost.tile
		if game._wall(tile):
			fail_test("ghost walked into a wall at %s on frame %d" % [tile, frame])
			return
	pass_test("ghost stayed on open tiles")

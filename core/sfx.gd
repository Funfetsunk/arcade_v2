extends Node
## Autoload "Sfx": the original's synthesized retro sound effects, the ambient
## hum and crowd murmur, and the jukebox. The sounds were built live with Web
## Audio; tools/render_sfx.py renders them once to assets/audio/.
##
## Browsers block audio until the first tap, so the ambience and music start on
## the first press, with a little "sound on" ding, like the original.

const SOUNDS := {
	coin = preload("res://assets/audio/coin.wav"),
	buy = preload("res://assets/audio/buy.wav"),
	day = preload("res://assets/audio/day.wav"),
	broke = preload("res://assets/audio/break.wav"),
	click = preload("res://assets/audio/click.wav"),
	error = preload("res://assets/audio/error.wav"),
	goal = preload("res://assets/audio/goal.wav"),
	# The minigames' shared set (tools/render_minigame_sfx.py).
	mg_count = preload("res://assets/audio/mg_count.wav"),
	mg_go = preload("res://assets/audio/mg_go.wav"),
	mg_score = preload("res://assets/audio/mg_score.wav"),
	mg_hit = preload("res://assets/audio/mg_hit.wav"),
	mg_miss = preload("res://assets/audio/mg_miss.wav"),
	mg_win = preload("res://assets/audio/mg_win.wav"),
	mg_lose = preload("res://assets/audio/mg_lose.wav"),
	mg_star = preload("res://assets/audio/mg_star.wav"),
	mg_best = preload("res://assets/audio/mg_best.wav"),
	# Pinball's table sounds.
	pb_flip = preload("res://assets/audio/pb_flip.wav"),
	pb_bump = preload("res://assets/audio/pb_bump.wav"),
	pb_drop = preload("res://assets/audio/pb_drop.wav"),
	pb_lane = preload("res://assets/audio/pb_lane.wav"),
	pb_launch = preload("res://assets/audio/pb_launch.wav"),
	pb_drain = preload("res://assets/audio/pb_drain.wav"),
	# The slot machine's.
	sl_pull = preload("res://assets/audio/sl_pull.wav"),
	sl_tick = preload("res://assets/audio/sl_tick.wav"),
	sl_stop = preload("res://assets/audio/sl_stop.wav"),
	sl_nudge = preload("res://assets/audio/sl_nudge.wav"),
	sl_win = preload("res://assets/audio/sl_win.wav"),
	sl_jackpot = preload("res://assets/audio/sl_jackpot.wav"),
	hp_swish = preload("res://assets/audio/hp_swish.wav"),
	hp_rim = preload("res://assets/audio/hp_rim.wav"),
	hp_board = preload("res://assets/audio/hp_board.wav"),
	hp_bounce = preload("res://assets/audio/hp_bounce.wav"),
	hp_buzzer = preload("res://assets/audio/hp_buzzer.wav"),
	hp_fire = preload("res://assets/audio/hp_fire.wav"),
	cp_clink = preload("res://assets/audio/cp_clink.wav"),
	cp_spill = preload("res://assets/audio/cp_spill.wav"),
	cp_bonus = preload("res://assets/audio/cp_bonus.wav"),
	cp_prize = preload("res://assets/audio/cp_prize.wav"),
}
const BLEEP_NOTES := [523, 587, 659, 784, 880, 1047]
const BEEP_NOTES := [330, 440, 495, 660, 880]
const TRACKS: Array[Dictionary] = [
	{ id = &"arcade", name = "Arcade Pad", stream = preload("res://assets/audio/music_arcade.wav") },
	{ id = &"synth", name = "Synthwave", stream = preload("res://assets/audio/music_synth.wav") },
	{ id = &"chip", name = "Chiptune", stream = preload("res://assets/audio/music_chip.wav") },
	{ id = &"lofi", name = "Lo-Fi", stream = preload("res://assets/audio/music_lofi.wav") },
]
const POOL_SIZE := 8
## Many machines pay out at once; coins closer together than this are dropped.
const COIN_GAP_MS := 50
## Full murmur at 10 customers, and how fast it follows the crowd (seconds).
const MURMUR_FULL := 10.0
const MURMUR_EASE := 0.5
const HUM_FADE_IN := 2.5
const SILENT_DB := -80.0

var muted := false
var started := false
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _bleeps: Array[AudioStream] = []
var _beeps: Dictionary[int, AudioStream] = {}
var _hum: AudioStreamPlayer
var _murmur: AudioStreamPlayer
var _music: AudioStreamPlayer
var _crowd := 0
var _murmur_level := 0.0
var _last_coin := -COIN_GAP_MS
## The Game autoload, looked up at runtime: the machine catalogs load minigame
## scenes that call Sfx, so a static reference to Game (which needs Data) would
## be a load cycle.
@onready var _game: Node = get_node(^"/root/Game")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		_pool.append(_add_player(&"SFX"))
	for note in BLEEP_NOTES:
		for wave in ["square", "triangle"]:
			_bleeps.append(load("res://assets/audio/bleep_%d_%s.wav" % [note, wave]))
	for note in BEEP_NOTES:
		_beeps[note] = load("res://assets/audio/beep_%d.wav" % note)
	_hum = _add_player(&"Ambience", preload("res://assets/audio/hum.wav"))
	_murmur = _add_player(&"Ambience", preload("res://assets/audio/murmur.wav"))
	_music = _add_player(&"Music")
	muted = _game.meta.sound_muted
	AudioServer.set_bus_mute(0, muted)
	_connect_cues()


func _add_player(bus: StringName, stream: AudioStream = null) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	player.stream = stream
	add_child(player)
	return player


func _connect_cues() -> void:
	EventBus.purchased.connect(buy)
	EventBus.refused.connect(error)
	EventBus.celebrated.connect(func(_confetti: int) -> void: goal())
	EventBus.coin_spawned.connect(func(_id: int, _value: int) -> void: coin())
	EventBus.day_ended.connect(play.bind(&"day"))
	EventBus.machine_broke.connect(play.bind(&"broke"))
	EventBus.goal_completed.connect(func(_goal: GoalDef) -> void: goal())
	EventBus.achievement_unlocked.connect(func(_a: AchievementDef) -> void: goal())
	EventBus.jackpot_hit.connect(func(_id: int, _amount: int) -> void: goal())
	EventBus.empire_completed.connect(goal)
	EventBus.scenario_won.connect(func(_s: ScenarioDef, _stars: int) -> void: goal())
	EventBus.daily_finished.connect(func(_score: int, _best: int, _new_best: bool) -> void: goal())
	EventBus.contract_resolved.connect(func(_c: ContractDef, delivered: bool) -> void:
		if delivered:
			goal())
	EventBus.tournament_resolved.connect(func(_t: TournamentDef, success: bool) -> void:
		if success:
			goal())


func _input(event: InputEvent) -> void:
	if started:
		return
	if (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey) and event.is_pressed():
		_start()


## Starts the ambience and music on the first real input (the web unlocks audio then).
func _start() -> void:
	started = true
	_hum.volume_db = SILENT_DB
	_hum.play()
	create_tween().tween_property(_hum, ^"volume_db", 0.0, HUM_FADE_IN)
	_murmur.volume_db = SILENT_DB
	_murmur.play()
	_play_track()
	if not muted:
		get_tree().create_timer(0.13).timeout.connect(play.bind(&"coin"))


func _process(delta: float) -> void:
	if not started:
		return
	# The murmur follows the crowd; an occasional soft bleep from the machines.
	var target := minf(1.0, _crowd / MURMUR_FULL)
	_murmur_level += (target - _murmur_level) * (1.0 - exp(-delta / MURMUR_EASE))
	_murmur.volume_db = linear_to_db(maxf(_murmur_level, 0.0001))
	if _crowd > 1 and randf() < 0.018 * delta * 60.0:
		_play_stream(_bleeps.pick_random(), linear_to_db(randf_range(0.05, 0.1) / 0.075))


## Plays one of the effects in SOUNDS.
func play(sound: StringName) -> void:
	_play_stream(SOUNDS[sound])


func _play_stream(stream: AudioStream, volume_db := 0.0) -> void:
	if muted:
		return
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func click() -> void:
	play(&"click")


func buy() -> void:
	play(&"buy")


func error() -> void:
	play(&"error")


func goal() -> void:
	play(&"goal")


func coin() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_coin < COIN_GAP_MS:
		return
	_last_coin = now
	play(&"coin")


## A short square-wave note (Riff Master), snapped to the nearest rendered pitch.
func beep(frequency: float) -> void:
	var nearest: int = BEEP_NOTES[0]
	for note in BEEP_NOTES:
		if absf(note - frequency) < absf(nearest - frequency):
			nearest = note
	_play_stream(_beeps[nearest])


## How many customers are on the floor, for the crowd murmur.
func set_crowd(count: int) -> void:
	_crowd = count


func toggle_mute() -> bool:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	_game.meta.sound_muted = muted
	_game.save_meta()
	if not started:
		_start()
	if not muted:
		get_tree().create_timer(0.09).timeout.connect(coin)
	return muted


func track() -> StringName:
	return _game.meta.jukebox_track


func set_track(id: StringName) -> void:
	_game.meta.jukebox_track = id
	_game.save_meta()
	if not started:
		_start()
	else:
		_play_track()
	click()


func _play_track() -> void:
	for t in TRACKS:
		if t.id == _game.meta.jukebox_track:
			_music.stream = t.stream
			_music.play()
			return
	_music.stream = TRACKS[0].stream
	_music.play()

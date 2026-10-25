class_name Confetti
extends Control
## Confetti bursts over the floor for big moments (goals, achievements,
## jackpots, wins), as in the original. Sits under the panels and never takes
## input. Speeds and sizes are the original's, scaled to the smaller logical
## screen.

const COLORS := [Color("ff006e"), Color("ffb703"), Color("00f5d4"), Color("3a86ff"), Color("c77dff"), Color("06d6a0"), Color("ff8c42")]
## The original drew on a full-resolution canvas; our logical screen is about
## half as many pixels across.
const SCALE := 0.6

var _bits: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	EventBus.goal_completed.connect(func(_g: GoalDef) -> void: burst(50, 0.28))
	EventBus.achievement_unlocked.connect(func(_a: AchievementDef) -> void: burst(50, 0.28))
	EventBus.jackpot_hit.connect(func(_id: int, _amount: int) -> void: burst(100))
	EventBus.celebrated.connect(burst)
	EventBus.empire_completed.connect(func() -> void:
		burst(120, 0.32)
		burst(160))
	EventBus.scenario_won.connect(func(_s: ScenarioDef, _stars: int) -> void: burst(120))
	EventBus.daily_finished.connect(func(_score: int, _best: int, _new_best: bool) -> void: burst(110))
	EventBus.contract_resolved.connect(func(_c: ContractDef, delivered: bool) -> void:
		if delivered:
			burst(80))
	EventBus.tournament_resolved.connect(func(_t: TournamentDef, success: bool) -> void:
		if success:
			burst(100))
	EventBus.game_started.connect(_bits.clear)


## Throws `count` pieces from the top-middle of the screen (`height` is how far down).
func burst(count := 45, height := 0.3) -> void:
	var from := Vector2(size.x / 2, size.y * height)
	for i in count:
		_bits.append({ at = from, v = Vector2((randf() - 0.5) * 7, -(2 + randf() * 6)) * SCALE,
			color = COLORS[i % COLORS.size()], size = (3 + randf() * 5) * SCALE, life = 1.0,
			rot = randf() * TAU, spin = (randf() - 0.5) * 0.5 })


func _physics_process(_delta: float) -> void:
	if _bits.is_empty():
		return
	for b in _bits.duplicate():
		b.v = Vector2(b.v.x * 0.99, b.v.y + 0.18 * SCALE)
		b.at += b.v
		b.rot += b.spin
		b.life -= 0.012
		if b.life <= 0.0 or b.at.y > size.y + 12:
			_bits.erase(b)
	queue_redraw()


func _draw() -> void:
	for b in _bits:
		var c: Color = b.color
		c.a = clampf(b.life, 0.0, 1.0)
		var s: float = b.size
		draw_set_transform(b.at.round(), b.rot)
		draw_rect(Rect2(-s / 2, -s / 2, s, s * 0.6), c)
	draw_set_transform(Vector2.ZERO)

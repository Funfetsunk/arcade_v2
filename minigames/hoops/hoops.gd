extends MiniGame
## Pro Hoops: press and HOLD to charge the power meter, release to shoot at the
## sliding hoop. Sweet-spot power sinks it; streaks score more. 30 s.

const GRAVITY := 0.5
const BALL_R := 11.0
const RIM := 44.0
const HOME := Vector2(BOARD.x / 2, BOARD.y - 56)
## Frames ahead the shot aims for the hoop's future position.
const AIM_FRAMES := 40.0
const METER := Rect2(BOARD.x - 34, 150, 16, 220)

var hoop := Vector2(BOARD.x / 2, 130)
var hoop_dir := 1.0
var hoop_speed := 1.1
var ball := HOME
var ball_vel := Vector2.ZERO
var ball_live := false
var ball_scored := false
var charging := false
var charge := 0.0
var charge_dir := 1.0
var streak := 0
var time := 30 * 60


func _pointer_pressed(_at: Vector2) -> void:
	if not ball_live and not charging:
		charging = true
		charge = 0.0
		charge_dir = 1.0


func _pointer_released(_at: Vector2) -> void:
	if charging:
		if not ball_live:
			_shoot(charge)
		charging = false


## Aims at where the hoop will be; only the right power drops it through the rim.
func _shoot(power: float) -> void:
	var target_x := clampf(hoop.x + hoop_dir * hoop_speed * AIM_FRAMES, 80, BOARD.x - 80)
	ball_vel = Vector2((target_x - HOME.x) / AIM_FRAMES, -(8 + power * 12))
	ball_live = true
	ball_scored = false


func _tick() -> void:
	time -= 1
	if time <= 0:
		end_round("BUZZER!", score >= 100)
		return
	hoop.x += hoop_dir * hoop_speed
	if hoop.x < 80:
		hoop.x = 80
		hoop_dir = 1
	if hoop.x > BOARD.x - 80:
		hoop.x = BOARD.x - 80
		hoop_dir = -1
	if charging:
		charge += 0.022 * charge_dir
		if charge >= 1:
			charge = 1
			charge_dir = -1
		if charge <= 0:
			charge = 0
			charge_dir = 1
	if not ball_live:
		return
	ball_vel.y += GRAVITY
	ball += ball_vel
	if ball.x < BALL_R or ball.x > BOARD.x - BALL_R:
		ball_vel.x *= -0.8
		ball.x = clampf(ball.x, BALL_R, BOARD.x - BALL_R)
	# A basket: falling through the rim line.
	if not ball_scored and ball_vel.y > 0 and ball.y > hoop.y and ball.y < hoop.y + 16 and absf(ball.x - hoop.x) < RIM / 2 - 4:
		ball_scored = true
		streak += 1
		var points := 20 + mini(20, (streak - 1) * 5)
		score += points
		hoop_speed = minf(3.2, hoop_speed + 0.18)
		add_pop(hoop, "+%d" % points, 36)
	if ball.y > BOARD.y + 30:
		if not ball_scored:
			streak = 0
			add_pop(Vector2(HOME.x, BOARD.y - 120), "MISS", 24, Color("888888"))
		ball = HOME
		ball_vel = Vector2.ZERO
		ball_live = false


func _draw_board() -> void:
	board.draw_rect(Rect2(hoop.x - 34, hoop.y - 58, 68, 46), Color("1c1430"))
	board.draw_rect(Rect2(hoop.x - 18, hoop.y - 40, 36, 24), Color.WHITE, false, 1.0)
	board.draw_line(hoop - Vector2(RIM / 2, 0), hoop + Vector2(RIM / 2, 0), Color("ff006e"), 4.0)
	for i in range(-2, 3):
		board.draw_line(hoop + Vector2(i * 9, 0), hoop + Vector2(i * 5, 22), DIM, 1.0)
	# Power meter, with the sweet zone (~0.66–0.82) marked.
	board.draw_rect(METER, Color("241a0e"))
	board.draw_rect(Rect2(METER.position.x, METER.position.y + METER.size.y * (1 - 0.82), METER.size.x, METER.size.y * 0.16), Color(Color("06d6a0"), 0.35))
	if charging:
		var fill := Color("06d6a0") if charge > 0.66 and charge < 0.82 else GOLD
		board.draw_rect(Rect2(METER.position.x, METER.position.y + METER.size.y * (1 - charge), METER.size.x, METER.size.y * charge), fill)
	board.draw_rect(METER, Color("6b4a23"), false, 1.0)
	text("PWR", Vector2(METER.get_center().x, METER.end.y + 16), 8, DIM)
	board.draw_circle(ball, BALL_R, Color("ff8c42"))
	board.draw_arc(ball, BALL_R, 0, TAU, 24, Color("7a3a10"), 1.0)
	board.draw_line(ball - Vector2(BALL_R, 0), ball + Vector2(BALL_R, 0), Color("7a3a10"), 1.0)
	if not ball_live and not charging and not over:
		text("hold to charge", Vector2(BOARD.x / 2, BOARD.y - 24), 9, DIM)
	draw_pops(0.5, 13)


func _hud_text() -> String:
	return "SCORE %d    STREAK %d    TIME %d" % [score, streak, ceili(maxi(0, time) / 60.0)]

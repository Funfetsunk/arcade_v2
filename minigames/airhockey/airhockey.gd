extends MiniGame
## Air Hockey: drag your mallet (bottom half) against the AI. The puck has
## friction and bounces off the walls. First to 5, or the most goals in 30 s.

const GOAL := 50.0
const MALLET_R := 21.0
const PUCK_R := 9.0

var me := Vector2(BOARD.x / 2, BOARD.y - 70)
var me_prev := me
var ai := Vector2(BOARD.x / 2, 70)
var ai_prev := ai
var puck := BOARD / 2
var puck_vel := Vector2.ZERO
var mine := 0
var theirs := 0
var time := 30 * 60
var _touch_cooldown := 0


func _pointer_moved(at: Vector2) -> void:
	me = Vector2(clampf(at.x, MALLET_R, BOARD.x - MALLET_R), clampf(at.y, BOARD.y / 2 + MALLET_R, BOARD.y - MALLET_R))


func _serve() -> void:
	puck = BOARD / 2
	puck_vel = Vector2.ZERO


func _hit_mallet(mallet: Vector2, mallet_vel: Vector2, is_me: bool) -> void:
	var offset := puck - mallet
	var d := offset.length()
	if d > MALLET_R + PUCK_R or d == 0.0:
		return
	var n := offset / d
	puck = mallet + n * (MALLET_R + PUCK_R)
	var dot := puck_vel.dot(n)
	if dot < 0:
		puck_vel -= 2 * dot * n
	puck_vel += mallet_vel * 0.55 + n * 1.2
	if puck_vel.length() > 9:
		puck_vel = puck_vel.normalized() * 9
	if is_me and _touch_cooldown <= 0:
		score += 2
		_touch_cooldown = 20


func _tick() -> void:
	time -= 1
	if time <= 0:
		_finish()
		return
	if _touch_cooldown > 0:
		_touch_cooldown -= 1
	# AI: chase the puck in its own half, otherwise drift home.
	var target := Vector2(puck.x, minf(puck.y, BOARD.y / 2 - MALLET_R)) if puck.y < BOARD.y / 2 else Vector2(BOARD.x / 2, 70)
	ai += ((target - ai) * 0.1).clamp(Vector2(-2.7, -2.7), Vector2(2.7, 2.7))
	# Substep so fast mallets and pucks can't pass through each other.
	const STEPS := 4
	var me_vel := me - me_prev
	var ai_vel := ai - ai_prev
	for s in range(1, STEPS + 1):
		puck += puck_vel / STEPS
		if puck.x - PUCK_R < 0:
			puck.x = PUCK_R
			puck_vel.x *= -0.92
		if puck.x + PUCK_R > BOARD.x:
			puck.x = BOARD.x - PUCK_R
			puck_vel.x *= -0.92
		var in_goal := absf(puck.x - BOARD.x / 2) < GOAL
		if puck.y - PUCK_R < 0:
			if in_goal:
				mine += 1
				score += 40
				_serve()
			else:
				puck.y = PUCK_R
				puck_vel.y *= -0.92
		if puck.y + PUCK_R > BOARD.y:
			if in_goal:
				theirs += 1
				score = maxi(0, score - 10)
				_serve()
			else:
				puck.y = BOARD.y - PUCK_R
				puck_vel.y *= -0.92
		var f := float(s) / STEPS
		_hit_mallet(me_prev + me_vel * f, me_vel, true)
		_hit_mallet(ai_prev + ai_vel * f, ai_vel, false)
	puck_vel *= 0.992
	me_prev = me
	ai_prev = ai
	if mine >= 5 or theirs >= 5:
		_finish()


func _finish() -> void:
	if mine > theirs:
		score += 30
	end_round("YOU WIN!" if mine > theirs else "AI WINS" if mine < theirs else "TIME!", mine >= theirs)


func _draw_board() -> void:
	board.draw_rect(Rect2(Vector2.ZERO, BOARD), Color("0e1626"))
	board.draw_line(Vector2(0, BOARD.y / 2), Vector2(BOARD.x, BOARD.y / 2), Color("24365a"), 2.0)
	board.draw_arc(BOARD / 2, 40, 0, TAU, 32, Color("24365a"), 2.0)
	board.draw_line(Vector2(BOARD.x / 2 - GOAL, 2), Vector2(BOARD.x / 2 + GOAL, 2), Color("ff006e"), 2.0)
	board.draw_line(Vector2(BOARD.x / 2 - GOAL, BOARD.y - 2), Vector2(BOARD.x / 2 + GOAL, BOARD.y - 2), GOLD, 2.0)
	board.draw_circle(ai, MALLET_R, Color("ff006e"))
	board.draw_circle(me, MALLET_R, GOLD)
	board.draw_circle(ai, 8, Color("102018"))
	board.draw_circle(me, 8, Color("102018"))
	board.draw_circle(puck, PUCK_R, Color.WHITE)


func _hud_text() -> String:
	return "SCORE %d    YOU %d-%d    TIME %d" % [score, mine, theirs, ceili(maxi(0, time) / 60.0)]

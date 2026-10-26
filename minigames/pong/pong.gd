extends MiniGame
## Paddle Blip: drag the bottom paddle and beat the AI. Every paddle hit speeds
## the ball up; a point resets the pace. Every fifth return grows your paddle.
## First to 5.

const PW := 70.0
const PH := 11.0
const BASE_SPEED := 4.0
const MAX_SPEED := 8.5
const GROW := 10.0
const MAX_PW := 110.0

const PADDLE_ME: StyleBoxTexture = preload("res://assets/sprites/minigames/paddle_gold.tres")
const PADDLE_AI: StyleBoxTexture = preload("res://assets/sprites/minigames/paddle_pink.tres")
const BALL: Texture2D = preload("res://assets/sprites/minigames/ball_small.png")

var me := Vector2(BOARD.x / 2 - PW / 2, BOARD.y - 34)
var ai := Vector2(BOARD.x / 2 - PW / 2, 24)
var me_w := PW
var returns := 0
var speed := BASE_SPEED
var ball := {}
var mine := 0
var theirs := 0


func _setup() -> void:
	ball = _serve(1)


func _serve(direction: int) -> Dictionary:
	speed = BASE_SPEED
	var vx := (randf() * 0.6 + 0.3) * speed * (1 if randf() < 0.5 else -1)
	return { pos = BOARD / 2, vel = Vector2(vx, direction * sqrt(speed * speed - vx * vx)), r = 5.0 }


## Keeps the ball at the current speed and never near-horizontal.
func _rescale() -> void:
	var v: Vector2 = ball.vel
	v = v / maxf(v.length(), 0.0001) * speed
	var min_vy := speed * 0.45
	if absf(v.y) < min_vy:
		var sy := signf(v.y) if v.y != 0 else 1.0
		var sx := signf(v.x) if v.x != 0 else 1.0
		v = Vector2(sx * sqrt(maxf(0, speed * speed - min_vy * min_vy)), sy * min_vy)
	ball.vel = v


func _pointer_moved(at: Vector2) -> void:
	me.x = clampf(at.x - me_w / 2, 0, BOARD.x - me_w)


## Widens your paddle about its centre.
func _grow() -> void:
	var grown := minf(MAX_PW, me_w + GROW)
	me.x = clampf(me.x - (grown - me_w) / 2, 0, BOARD.x - grown)
	me_w = grown
	add_pop(Vector2(me.x + me_w / 2, me.y - 16), "WIDER!", 40)


func _tick() -> void:
	ai.x = clampf(ai.x + clampf((ball.pos.x - (ai.x + PW / 2)) * 0.08, -3.1, 3.1), 0, BOARD.x - PW)
	var p: Vector2 = ball.pos + ball.vel
	var r: float = ball.r
	ball.pos = p
	var v: Vector2 = ball.vel
	if p.x - r < 0:
		p.x = r
		v.x *= -1
	if p.x + r > BOARD.x:
		p.x = BOARD.x - r
		v.x *= -1
	ball.pos = p
	ball.vel = v
	if ball.vel.y > 0 and p.y + r >= me.y and p.y + r <= me.y + PH + 8 and p.x >= me.x - 4 and p.x <= me.x + me_w + 4:
		ball.vel = Vector2((p.x - (me.x + me_w / 2)) / (me_w / 2) * speed, -absf(ball.vel.y))
		speed = minf(MAX_SPEED, speed + 0.3)
		_rescale()
		score += 2
		returns += 1
		if returns % 5 == 0 and me_w < MAX_PW:
			_grow()
	if ball.vel.y < 0 and p.y - r <= ai.y + PH and p.y - r >= ai.y - 8 and p.x >= ai.x - 4 and p.x <= ai.x + PW + 4:
		ball.vel = Vector2((p.x - (ai.x + PW / 2)) / (PW / 2) * speed, absf(ball.vel.y))
		speed = minf(MAX_SPEED, speed + 0.3)
		_rescale()
	if p.y < -10:
		mine += 1
		score += 40
		ball = _serve(1)
	elif p.y > BOARD.y + 10:
		theirs += 1
		play_miss()
		score = maxi(0, score - 10)
		ball = _serve(-1)
	if mine >= 5 or theirs >= 5:
		if mine > theirs:
			score += 30
		end_round("YOU WIN!" if mine > theirs else "AI WINS", mine > theirs)


func _draw_board() -> void:
	board.draw_dashed_line(Vector2(0, BOARD.y / 2), Vector2(BOARD.x, BOARD.y / 2), Color("2a2a44"), 1.0, 6.0)
	stretched(PADDLE_AI, Rect2(ai, Vector2(PW, PH)))
	stretched(PADDLE_ME, Rect2(me, Vector2(me_w, PH)))
	sprite(BALL, ball.pos)
	draw_pops(0.4, 10)
	text(str(theirs), Vector2(BOARD.x / 2, BOARD.y / 2 - 14), 14, DIM)
	text(str(mine), Vector2(BOARD.x / 2, BOARD.y / 2 + 26), 14, DIM)


func _hud_text() -> String:
	return "SCORE %d    YOU %d-%d    SPEED x%.1f" % [score, mine, theirs, speed / BASE_SPEED]

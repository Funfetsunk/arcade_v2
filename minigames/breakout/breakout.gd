extends MiniGame
## Brick Smash: knock out every brick with the ball. Drag (or hover) to move the
## paddle, or use ← →. Three lives; clearing the wall adds 50 per life left.

const COLS := 8
const ROWS := 5
const BW := BOARD.x / COLS
const BH := 18.0
const TOP := 36.0
const COLORS := [Color("ff006e"), Color("ff8c42"), Color("ffb703"), Color("06d6a0"), Color("3a86ff")]

const BRICK: StyleBoxTexture = preload("res://assets/sprites/minigames/brick.tres")
const PADDLE: StyleBoxTexture = preload("res://assets/sprites/minigames/paddle_gold.tres")
const BALL: Texture2D = preload("res://assets/sprites/minigames/ball_small.png")

var bricks: Array[Dictionary] = []
var paddle := Rect2(BOARD.x / 2 - 33, BOARD.y - 26, 66, 11)
var ball := {}
var lives := 3
var started := false
var _left := false
var _right := false


func _setup() -> void:
	for r in ROWS:
		for c in COLS:
			bricks.append({ rect = Rect2(c * BW, TOP + r * BH, BW - 2, BH - 2), color = COLORS[r % COLORS.size()], alive = true })
	ball = _new_ball()


func _new_ball() -> Dictionary:
	return { pos = Vector2(BOARD.x / 2, BOARD.y - 42), vel = Vector2(2.4 * (1 if randf() < 0.5 else -1), -3.4), r = 5.0 }


func _pointer_moved(at: Vector2) -> void:
	paddle.position.x = clampf(at.x - paddle.size.x / 2, 0, BOARD.x - paddle.size.x)
	started = true


func _key(event: InputEventKey) -> void:
	match event.keycode:
		KEY_LEFT:
			_left = event.pressed
		KEY_RIGHT:
			_right = event.pressed
		KEY_SPACE, KEY_UP:
			if event.pressed:
				started = true


func _tick() -> void:
	if _left:
		paddle.position.x = maxf(0, paddle.position.x - 6)
	if _right:
		paddle.position.x = minf(BOARD.x - paddle.size.x, paddle.position.x + 6)
	if not started:
		return
	var p: Vector2 = ball.pos
	var v: Vector2 = ball.vel
	var r: float = ball.r
	p += v
	if p.x - r < 0:
		p.x = r
		v.x *= -1
	if p.x + r > BOARD.x:
		p.x = BOARD.x - r
		v.x *= -1
	if p.y - r < 0:
		p.y = r
		v.y *= -1
	# Paddle bounce, angled by where it hits.
	if v.y > 0 and p.y + r >= paddle.position.y and p.y + r <= paddle.end.y + 8 and p.x >= paddle.position.x - 4 and p.x <= paddle.end.x + 4:
		v.y = -absf(v.y)
		v.x = (p.x - paddle.get_center().x) / (paddle.size.x / 2) * 4.2
	for b in bricks:
		var rect: Rect2 = b.rect
		if b.alive and p.x + r > rect.position.x and p.x - r < rect.end.x and p.y + r > rect.position.y and p.y - r < rect.end.y:
			b.alive = false
			score += 10
			v.y *= -1
			break
	ball.pos = p
	ball.vel = v
	if p.y - r > BOARD.y:
		lives -= 1
		if lives <= 0:
			end_round("GAME OVER", false)
			return
		ball = _new_ball()
		started = false
	if bricks.all(func(b: Dictionary) -> bool: return not b.alive):
		score += lives * 50
		end_round("CLEARED!", true)


func _draw_board() -> void:
	for b in bricks:
		if b.alive:
			stretched(BRICK, b.rect, b.color)
	stretched(PADDLE, paddle)
	sprite(BALL, ball.pos)
	if not started:
		text("move to launch", Vector2(BOARD.x / 2, BOARD.y - 72), 10, DIM)


func _hud_text() -> String:
	return "SCORE %d    LIVES %s" % [score, "●".repeat(maxi(0, lives))]

extends MiniGame
## Go Viral, at the Social Hub: a feed of posts scrolls up the phone. The
## trending topic is up top, and it changes every few seconds. Tap to like posts
## on the trend to win followers; likes in a row build a combo until you go
## VIRAL. Don't like scam adverts or trolls, and don't let a trending post
## scroll past unliked. The feed speeds up as it goes. 45 s.

const BACKDROP: Texture2D = preload("res://assets/sprites/minigames/feed_backdrop.png")
const CARD: Texture2D = preload("res://assets/sprites/minigames/feed_card.png")
const HEART: Texture2D = preload("res://assets/sprites/minigames/feed_heart.png")
const FIRE: Texture2D = preload("res://assets/sprites/minigames/feed_fire.png")
const LIKE: Texture2D = preload("res://assets/sprites/minigames/feed_like.png")

## The topics that can trend, and the pictures posted about them.
const TOPICS := {
	&"cats": { tag = "#CATS", art = [preload("res://assets/sprites/minigames/feed_cat.png")] },
	&"dogs": { tag = "#DOGS", art = [preload("res://assets/sprites/minigames/feed_dog.png")] },
	&"food": { tag = "#FOOD", art = [preload("res://assets/sprites/minigames/feed_pizza.png"), preload("res://assets/sprites/minigames/feed_burger.png")] },
	&"dance": { tag = "#DANCE", art = [preload("res://assets/sprites/minigames/feed_dancer.png")] },
	&"selfies": { tag = "#SELFIE", art = [preload("res://assets/sprites/minigames/feed_selfie.png")] },
	&"sunsets": { tag = "#SUNSET", art = [preload("res://assets/sprites/minigames/feed_sunset.png")] },
	&"gaming": { tag = "#GAMING", art = [preload("res://assets/sprites/minigames/feed_gamepad.png")] },
	&"skate": { tag = "#SKATE", art = [preload("res://assets/sprites/minigames/feed_skater.png")] },
}
## Posts never to like.
const BAD := {
	&"scam": { art = preload("res://assets/sprites/minigames/feed_scam.png"), says = "SCAM!" },
	&"troll": { art = preload("res://assets/sprites/minigames/feed_troll.png"), says = "TROLL!" },
}

const TIME := 45 * 60
const TREND_EVERY := 9 * 60
const FOLLOW := 10
const OFF_TREND := 1
const BAD_LIKE := 15
const VIRAL_AT := 8
## Dark enough to read on the pastel app background.
const INK := Color(0.3, 0.1, 0.4)
## The feed, below the trending banner.
const FEED_TOP := 92.0
const CARD_ZOOM := 1.7
const GAP := 146.0
## The photo in the card art, from the card's centre (in art pixels).
const PHOTO := Vector2(1, -6)
const PHOTO_ZOOM := 1.35

## Each post: what it is (a topic or a bad kind), its picture, how far up the
## feed it is, and whether you've liked it.
var posts: Array[Dictionary] = []
var trend := &"cats"
var time := TIME
var combo := 0
var _speed := 0.9
var _trend_t := TREND_EVERY
var _banner := 0
var _bursts: Array[Dictionary] = []


func _setup() -> void:
	trend = TOPICS.keys().pick_random()
	_banner = 50
	var y := FEED_TOP + 120
	while y < BOARD.y + GAP:
		_post(y)
		y += GAP


func multiplier() -> int:
	return 1 + mini(floori(combo / 4.0), 3)


func viral() -> bool:
	return combo >= VIRAL_AT


func _post(y: float) -> void:
	var roll := randf()
	var kind: StringName
	var art: Texture2D
	if roll < 0.18:
		kind = BAD.keys().pick_random()
		art = BAD[kind].art
	else:
		kind = trend if roll < 0.55 else TOPICS.keys().pick_random()
		art = TOPICS[kind].art.pick_random()
	posts.append({ kind = kind, art = art, y = y, liked = false })


func _pointer_pressed(at: Vector2) -> void:
	if at.y < FEED_TOP:
		return
	for p in posts:
		if not p.liked and absf(at.y - p.y) < CARD.get_height() * CARD_ZOOM / 2.0:
			_like(p)
			return


func _like(p: Dictionary) -> void:
	p.liked = true
	if BAD.has(p.kind):
		score = maxi(0, score - BAD_LIKE)
		combo = 0
		Sfx.play(&"so_spam")
		add_pop(Vector2(BOARD.x / 2, p.y - 20), "%s -%d" % [BAD[p.kind].says, BAD_LIKE], 40, PINK)
		return
	var on_trend: bool = p.kind == trend
	var gain := (FOLLOW * multiplier() * (2 if viral() else 1)) if on_trend else OFF_TREND
	score += gain
	if on_trend:
		combo += 1
		if combo == VIRAL_AT:
			Sfx.play(&"so_viral")
			add_pop(Vector2(BOARD.x / 2, FEED_TOP + 40), "YOU WENT VIRAL!", 60, GOLD)
		else:
			Sfx.play(&"so_like")
	else:
		Sfx.play(&"so_like")
	_bursts.append({ y = p.y, t = 24 })
	add_pop(Vector2(BOARD.x / 2 + 70, p.y + 38), "+%d" % gain, 30, GOLD if on_trend else CREAM)


func _tick() -> void:
	time -= 1
	if time <= 0:
		end_round("GONE VIRAL!" if score >= star_scores[1] else "TIME'S UP", score >= star_scores[0])
		return
	var pace := 1.0 - float(time) / TIME
	_speed = lerpf(0.9, 2.2, pace)
	_banner = maxi(0, _banner - 1)
	_trend_t -= 1
	if _trend_t <= 0:
		_trend_t = TREND_EVERY
		var was := trend
		while trend == was:
			trend = TOPICS.keys().pick_random()
		_banner = 50
		Sfx.play(&"so_trend")
	for p in posts:
		p.y -= _speed
	# A new post joins the bottom of the feed once the last one is up far enough.
	var last: float = posts[-1].y if not posts.is_empty() else BOARD.y
	if last < BOARD.y + GAP / 2.0:
		_post(last + GAP)
	for p in posts.duplicate():
		if p.y < FEED_TOP - CARD.get_height() * CARD_ZOOM / 2.0:
			if p.kind == trend and not p.liked:
				combo = 0
			posts.erase(p)
	for b in _bursts.duplicate():
		b.t -= 1
		b.y -= _speed
		if b.t <= 0:
			_bursts.erase(b)


func _draw_board() -> void:
	board.draw_texture_rect(BACKDROP, Rect2(Vector2.ZERO, BOARD), false)
	for p in posts:
		_draw_post(p)
	for b in _bursts:
		var k: float = b.t / 24.0
		sprite(HEART, Vector2(BOARD.x / 2, b.y), 1.2 + (1.0 - k) * 1.5, 0.0, false, Color(1, 1, 1, minf(1.0, k * 2.0)))
	_draw_banner()
	draw_pops(0.5, 16)


func _draw_post(p: Dictionary) -> void:
	var at := Vector2(BOARD.x / 2, p.y)
	sprite(CARD, at, CARD_ZOOM)
	var art: Texture2D = p.art
	var zoom := PHOTO_ZOOM * 60.0 / maxf(art.get_width(), art.get_height())
	sprite(art, at + PHOTO * CARD_ZOOM, zoom)
	if p.liked and not BAD.has(p.kind):
		sprite(LIKE, at + Vector2(100, 37), 0.5)


## The trending topic, up top (the posts scroll away under it): it bounces in
## when it changes.
func _draw_banner() -> void:
	board.draw_texture_rect_region(BACKDROP, Rect2(0, 0, BOARD.x, FEED_TOP), Rect2(0, 0, BACKDROP.get_width(), FEED_TOP / 2.0))
	var drop := float(_banner) / 50.0
	var y := 46.0 - drop * drop * 60.0
	sprite(FIRE, Vector2(46, y), 1.0)
	text("TRENDING", Vector2(150, y - 14), 12, INK)
	text(TOPICS[trend].tag, Vector2(150, y + 10), 22, PINK)
	sprite(TOPICS[trend].art[0], Vector2(BOARD.x - 54, y), 0.95)
	if combo > 0 and not over:
		text(("VIRAL! " if viral() else "") + "COMBO x%d" % multiplier(), Vector2(BOARD.x / 2, FEED_TOP - 8), 12, PINK if viral() else INK)


func _hud_text() -> String:
	return "FOLLOWERS %d    TIME %d" % [score, ceili(maxi(0, time) / 60.0)]

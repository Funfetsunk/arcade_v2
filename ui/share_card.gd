class_name ShareCard
extends Control
## A 640×400 picture of the current run (name, scenario, headline stats and the
## machines) that the player can save and share. ShareCard.save() renders it in
## an off-screen SubViewport and downloads it on the web, or writes it to
## user://share/ elsewhere.

const SIZE := Vector2i(640, 400)
const PIXEL_FONT: Font = preload("res://assets/fonts/arcade_empire_pixel.ttf")
const LABEL := Color("6a7088")
const VALUE := Color("e8e2d0")


## Renders the card for the current run and offers it to the player.
static func save(host: Node) -> void:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var card := ShareCard.new()
	card.size = SIZE
	viewport.add_child(card)
	host.add_child(viewport)
	await RenderingServer.frame_post_draw
	var png := viewport.get_texture().get_image().save_png_to_buffer()
	viewport.queue_free()
	var s := Game.state
	var slug := RegEx.create_from_string("[^a-z0-9]+").sub((s.arcade_name if s.arcade_name else "arcade").to_lower(), "_", true)
	var file := "%s_day%d.png" % [slug, s.day]
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(png, file, "image/png")
		EventBus.toast_requested.emit("📸 Share card saved!", Sim.LogKind.INFO)
	else:
		DirAccess.make_dir_recursive_absolute("user://share")
		var path := "user://share/" + file
		var out := FileAccess.open(path, FileAccess.WRITE)
		if out == null:
			EventBus.toast_requested.emit("Could not make card", Sim.LogKind.BAD)
			return
		out.store_buffer(png)
		out.close()
		EventBus.toast_requested.emit("📸 Share card saved to %s" % ProjectSettings.globalize_path(path), Sim.LogKind.INFO)
	Sfx.buy()


func _draw() -> void:
	var s := Game.state
	var w := float(SIZE.x)
	var h := float(SIZE.y)
	var sign_color := Data.db.theme(s.theme).sign_color
	draw_rect(Rect2(0, 0, w, h), Color("0b0b14"))
	# A frame in the theme's sign colour.
	draw_rect(Rect2(10, 10, w - 20, h - 20), sign_color, false, 4.0)
	draw_rect(Rect2(18, 18, w - 36, h - 36), Color(1, 1, 1, 0.08), false, 1.0)
	# The arcade's name, with a soft neon glow.
	var arcade := s.arcade_name.left(16) if s.arcade_name else "ARCADE EMPIRE"
	for r in [6.0, 4.0, 2.0]:
		for d in [Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
			_text(arcade, Vector2(w / 2, 72) + d, 30, Color(sign_color, 0.06), true)
	_text(arcade, Vector2(w / 2, 72), 30, sign_color, true)
	var sub := "%s  ·  Day %d" % [Data.db.scenario(s.scenario).display_name, s.day]
	if Game.meta.prestige_level:
		sub += "  ·  Prestige %d" % Game.meta.prestige_level
	_text(sub, Vector2(w / 2, 98), 11, Color("9aa0b5"), true)
	# Headline stats, two columns.
	var stats := [
		["CASH", GameMath.money(s.cash)], ["REPUTATION", "%d/100" % GameMath.js_round(s.rep)],
		["EARNED", GameMath.money(s.total_earned)], ["MACHINES", str(s.machines.size())],
		["BIGGEST DAY", GameMath.money(s.biggest_day if s.has_biggest_day else 0.0)], ["MOOD", UiKit.mood_face(s.satisfaction)],
	]
	for i in stats.size():
		var at := Vector2(70 + (i % 2) * 300, 150 + floori(i / 2.0) * 64)
		_text(stats[i][0], at, 11, LABEL)
		_text(stats[i][1], at + Vector2(0, 28), 20, VALUE)
	# A strip of the first dozen machines.
	var strip := PackedStringArray()
	for m in s.machines.slice(0, 12):
		strip.append(m.def.emoji if m.def.emoji else "🎮")
	if not strip.is_empty():
		_text(" ".join(strip), Vector2(w / 2, h - 54), 22, Color.WHITE, true, ThemeDB.fallback_font)
	_text("ARCADE EMPIRE", Vector2(w / 2, h - 26), 10, LABEL, true)


## Text with its baseline at `at`, left-aligned or centred.
func _text(value: String, at: Vector2, font_size: int, color: Color, centred := false, font: Font = PIXEL_FONT) -> void:
	var x := at.x
	if centred:
		x -= font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2.0
	draw_string(font, Vector2(x, at.y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

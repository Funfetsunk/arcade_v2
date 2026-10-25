class_name UiKit
extends RefCounted
## Small builders for the widgets the panels repeat (cards, rows, buttons),
## styled by the project theme's type variations.

## Largest card thumbnail, in UI pixels.
const THUMB := Vector2(32, 40)

const LOG_COLORS := {
	Sim.LogKind.MONEY: Color("ffd866"),
	Sim.LogKind.GOOD: Color("7cff6b"),
	Sim.LogKind.BAD: Color("ff6b8f"),
	Sim.LogKind.INFO: Color("c9d4e6"),
}


static func label(text: String, variation := &"", wraps := false) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	if wraps:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 40
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func button(text: String, on_press: Callable, variation := &"", enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(36, 28)
	b.pressed.connect(on_press)
	return b


static func hbox(children: Array, separation := 6) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", separation)
	for c: Control in children:
		box.add_child(c)
	return box


static func vbox(children: Array, separation := 4) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", separation)
	for c: Control in children:
		box.add_child(c)
	return box


static func spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


## A card: icon (an emoji, or a texture such as Icons.machine()), title +
## description, and an optional action on the right.
static func card(icon: Variant, title: String, description: String, action: Control = null) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"CardPanel"
	var text := vbox([label(title), label(description, &"DimLabel", true)], 1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := hbox([card_icon(icon), text])
	if action:
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(action)
	panel.add_child(row)
	return panel


## Puts an icon and a label side by side in the middle of a button (Godot's own
## button icon sits at the edge, away from centred text), or the icon above the
## label when `stacked`. The label keeps the button's font, and its colour follows
## the button's state (normal, hover, pressed, disabled) like the button's own text.
static func icon_label(b: Button, icon: Texture2D, text: String, stacked := false) -> void:
	b.text = ""
	b.icon = null
	var old := b.get_node_or_null(^"Content")
	if old:
		b.remove_child(old)
		old.queue_free()
	var centre := CenterContainer.new()
	centre.name = "Content"
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box: BoxContainer
	if stacked:
		box = VBoxContainer.new()
	else:
		box = HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 0 if stacked else 4)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var pic := TextureRect.new()
	pic.texture = icon
	pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var words := Label.new()
	words.text = text
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	words.add_theme_font_override(&"font", b.get_theme_font(&"font"))
	words.add_theme_font_size_override(&"font_size", b.get_theme_font_size(&"font_size"))
	box.add_child(pic)
	box.add_child(words)
	centre.add_child(box)
	b.add_child(centre)
	var recolour := func() -> void:
		var state := &"font_color"
		match b.get_draw_mode():
			BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED:
				state = &"font_pressed_color"
			BaseButton.DRAW_HOVER:
				state = &"font_hover_color"
			BaseButton.DRAW_DISABLED:
				state = &"font_disabled_color"
		words.add_theme_color_override(&"font_color", b.get_theme_color(state))
	# Rebuilding replaces the label, so drop the hook that coloured the old one.
	if b.has_meta(&"icon_label_recolour"):
		var previous: Callable = b.get_meta(&"icon_label_recolour")
		if b.draw.is_connected(previous):
			b.draw.disconnect(previous)
	b.set_meta(&"icon_label_recolour", recolour)
	b.draw.connect(recolour)
	recolour.call()


## A card's picture: an emoji label, or a texture scaled down to fit a thumbnail
## (never up, so pixel art stays crisp at its own size).
static func card_icon(icon: Variant) -> Control:
	if icon is Texture2D:
		var pic := TextureRect.new()
		pic.texture = icon
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var size: Vector2 = icon.get_size()
		# A fixed-width column, so card text lines up whatever the sprite's width.
		pic.custom_minimum_size = THUMB
		if size.x <= THUMB.x and size.y <= THUMB.y:
			pic.custom_minimum_size.y = size.y
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return pic
	var glyph := label(str(icon))
	glyph.add_theme_font_size_override(&"font_size", 18)
	glyph.custom_minimum_size.x = 24
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return glyph


## "Caption ............ value" row.
static func stat_row(caption: String, value: String, value_color := Color.TRANSPARENT) -> HBoxContainer:
	var v := label(value)
	if value_color.a > 0.0:
		v.add_theme_color_override(&"font_color", value_color)
	return hbox([label(caption, &"DimLabel"), spacer(), v])


static func section(title: String) -> Label:
	var l := label(title)
	l.add_theme_color_override(&"font_color", Color("ffb703"))
	l.add_theme_font_size_override(&"font_size", 10)
	return l


static func bar(value: float, max_value: float, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = max_value
	b.value = value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(60, 6)
	var fill := (b.get_theme_stylebox(&"fill") as StyleBoxFlat).duplicate() as StyleBoxFlat
	fill.bg_color = color
	b.add_theme_stylebox_override(&"fill", fill)
	return b


static func clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


## Condition colour: green, amber, then red as a machine wears out.
static func condition_color(hp: float) -> Color:
	return Color("7cff6b") if hp > 60.0 else Color("ffb703") if hp > 25.0 else Color("ff4f7b")


static func mood_face(satisfaction: float) -> String:
	if satisfaction >= 85.0:
		return "😄"
	if satisfaction >= 68.0:
		return "🙂"
	if satisfaction >= 45.0:
		return "😐"
	if satisfaction >= 28.0:
		return "😟"
	return "😠"

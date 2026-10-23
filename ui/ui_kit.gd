class_name UiKit
extends RefCounted
## Small builders for the widgets the panels repeat (cards, rows, buttons),
## styled by the project theme's type variations.

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


## A card: icon, title + description, and an optional action on the right.
static func card(icon: String, title: String, description: String, action: Control = null) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"CardPanel"
	var icon_label := label(icon)
	icon_label.add_theme_font_size_override(&"font_size", 18)
	icon_label.custom_minimum_size.x = 24
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var text := vbox([label(title), label(description, &"DimLabel", true)], 1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := hbox([icon_label, text])
	if action:
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(action)
	panel.add_child(row)
	return panel


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

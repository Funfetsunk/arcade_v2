extends VBoxContainer
## Short pop-up messages under the top bar. A few at most, oldest dropped first.

const MAX_TOASTS := 3
const SHOW_TIME := 2.6

const BORDER := {
	Sim.LogKind.MONEY: Color("ffb703"),
	Sim.LogKind.GOOD: Color("4fd8ff"),
	Sim.LogKind.BAD: Color("ff4f7b"),
	Sim.LogKind.INFO: Color("6f86a3"),
}


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	EventBus.toast_requested.connect(show_toast)


func show_toast(message: String, kind := Sim.LogKind.INFO) -> void:
	if get_child_count() >= MAX_TOASTS:
		get_child(0).queue_free()
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ToastPanel"
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	var style := panel.get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
	style.border_color = BORDER[kind]
	panel.add_theme_stylebox_override(&"panel", style)
	var text := UiKit.label(message)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(text)
	add_child(panel)
	panel.modulate.a = 0.0
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.15)
	tween.tween_interval(SHOW_TIME)
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(panel.queue_free)

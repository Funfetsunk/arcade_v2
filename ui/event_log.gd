extends VBoxContainer
## The event log: a toggle button and the recent entries, colour-coded by kind.

const MAX_ENTRIES := 60

var _entries: Array[String] = []

@onready var _toggle: Button = %LogToggle
@onready var _panel: PanelContainer = %LogPanel
@onready var _text: RichTextLabel = %LogText


func _ready() -> void:
	_panel.hide()
	_toggle.pressed.connect(func() -> void: _panel.visible = not _panel.visible)
	EventBus.logged.connect(add_entry)
	EventBus.game_started.connect(clear)


func add_entry(message: String, kind := Sim.LogKind.INFO) -> void:
	var day := Game.state.day if Game.state else 0
	_entries.append("[color=#6f86a3]D%d[/color] [color=#%s]%s[/color]" % [day, UiKit.LOG_COLORS[kind].to_html(false), message.replace("[", "[lb]")])
	if _entries.size() > MAX_ENTRIES:
		_entries.pop_front()
	_text.text = "\n".join(_entries.slice(-MAX_ENTRIES).duplicate())
	_text.scroll_to_line(_text.get_line_count())


func clear() -> void:
	_entries.clear()
	_text.text = ""

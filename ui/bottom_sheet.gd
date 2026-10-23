class_name BottomSheet
extends PanelContainer
## The sliding panel that hosts the shop, staff, books and machine panels.
## Only one panel shows at a time; tapping the title bar's X (or the same
## action-bar button) closes it.

signal closed

var current: Control

@onready var _title: Label = %SheetTitle
@onready var _body: VBoxContainer = %SheetBody
@onready var _scroll: ScrollContainer = %SheetScroll


func _ready() -> void:
	hide()
	%SheetClose.pressed.connect(close)
	EventBus.state_changed.connect(_refresh)


## Adds a panel (anything with a `refresh()` method and a `title` property), hidden.
func add_panel(panel: Control) -> void:
	panel.hide()
	_body.add_child(panel)


func open(panel: Control) -> void:
	if current and current != panel:
		current.hide()
	current = panel
	panel.show()
	_title.text = panel.get(&"title")
	_scroll.scroll_vertical = 0
	panel.call(&"refresh")
	show()


func close() -> void:
	if not visible:
		return
	hide()
	if current:
		current.hide()
	current = null
	closed.emit()


func is_showing(panel: Control) -> bool:
	return visible and current == panel


func _refresh() -> void:
	if visible and current:
		_title.text = current.get(&"title")
		current.call(&"refresh")

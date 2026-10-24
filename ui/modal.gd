class_name Modal
extends Control
## A centred dialog over a dimmed screen: a title, a body and buttons.
## Used for decisions, confirmations and announcements.

@onready var _title: Label = %ModalTitle
@onready var _body: VBoxContainer = %ModalBody
@onready var _close: Button = %ModalClose

var _closable := true


func _ready() -> void:
	hide()
	_close.pressed.connect(close)
	$Dim.gui_input.connect(func(event: InputEvent) -> void:
		if _closable and event is InputEventMouseButton and event.pressed:
			close())


## Opens with the given body controls. A non-closable modal (e.g. a decision)
## must be answered with one of its own buttons.
func present(title: String, body: Array, closable := true) -> void:
	_title.text = title
	UiKit.clear(_body)
	for c: Control in body:
		_body.add_child(c)
	_closable = closable
	_close.visible = closable
	show()


func close() -> void:
	hide()
	UiKit.clear(_body)


## A yes/no confirmation; `on_yes` runs only if confirmed.
func confirm(title: String, message: String, yes_text: String, on_yes: Callable, danger := false) -> void:
	var yes := UiKit.button(yes_text, func() -> void:
		Sfx.click()
		close()
		on_yes.call(), &"DangerButton" if danger else &"PrimaryButton")
	var no := UiKit.button("Cancel", func() -> void:
		Sfx.click()
		close())
	present(title, [UiKit.label(message, &"", true), UiKit.hbox([no, UiKit.spacer(), yes])])
	Sfx.click()

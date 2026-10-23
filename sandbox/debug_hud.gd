extends CanvasLayer
## TEMPORARY test controls for the floor until the real UI (phase 3) exists.

@export var arcade_floor: ArcadeFloor

var _last_message := ""


func _ready() -> void:
	EventBus.state_changed.connect(_refresh)
	EventBus.toast_requested.connect(func(msg: String, _k: Sim.LogKind) -> void: _last_message = msg; _refresh())
	EventBus.logged.connect(func(msg: String, _k: Sim.LogKind) -> void: _last_message = msg; _refresh())
	EventBus.machine_selected.connect(func(_id: int) -> void: _refresh())
	EventBus.decision_offered.connect(_show_decision)
	%NextDay.pressed.connect(Game.next_day)
	%BuyCabinet.pressed.connect(func() -> void: arcade_floor.start_placing(Data.db.machine(&"space_inv")))
	%BuyRandom.pressed.connect(func() -> void:
		var affordable := Data.db.machines.filter(func(d: MachineDef) -> bool:
			return d.cost <= Game.state.cash and d.rep_req <= Game.state.rep)
		if not affordable.is_empty():
			arcade_floor.start_placing(affordable.pick_random()))
	%Move.pressed.connect(func() -> void:
		var m := Game.state.machine_by_id(arcade_floor.selected_id)
		if m:
			arcade_floor.start_moving(m))
	%Sell.pressed.connect(func() -> void:
		var m := Game.state.machine_by_id(arcade_floor.selected_id)
		if m:
			Game.actions.sell_machine(Game.state, m)
			EventBus.state_changed.emit())
	%NewGame.pressed.connect(Game.new_game.bind(&"free"))
	_refresh()


func _refresh() -> void:
	var s := Game.state
	if s == null:
		return
	var sel := s.machine_by_id(arcade_floor.selected_id)
	%Status.text = "Day %d   %s   rep %d   sat %d%%   %d visitors\n%s%s" % [
		s.day, GameMath.money(s.cash), GameMath.js_round(s.rep), GameMath.js_round(s.satisfaction),
		s.last_day_customers, ("Selected: %s (%d%%)\n" % [sel.def.display_name, GameMath.js_round(sel.hp)]) if sel else "",
		_last_message]


func _show_decision(event: DecisionEventDef) -> void:
	for child in %Decision.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "%s %s" % [event.emoji, event.title]
	%Decision.add_child(title)
	for i in event.options.size():
		var b := Button.new()
		b.text = event.options[i].label
		b.pressed.connect(func() -> void:
			if Game.choose_decision(i):
				for child in %Decision.get_children():
					child.queue_free())
		%Decision.add_child(b)

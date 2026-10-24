class_name Crowd
extends Node
## The people on the floor: visitors who queue for and play the machines, repair
## techs called by the sim, and hired staff pacing the front. Behaviour ported
## from the original main.ts (spawnCustomer / stepCustomers / updateWorkers /
## updateFloorStaff), with frame counts converted to seconds at 60 fps.

const CUSTOMER_SCENE := preload("res://actors/customer.tscn")
const TECHNICIAN_SCENE := preload("res://actors/technician.tscn")
const STAFF_SCENE := preload("res://actors/staff_member.tscn")

## Longest visible queue per machine.
const QUEUE_MAX := 4
## Gap between queuers, in pixels.
const QUEUE_STEP := 11.0
## Most people on the floor at once (also capped by yesterday's visitors).
const MAX_ON_FLOOR := 12
const SPAWN_INTERVAL := 0.75
const FAMILY_CHANCE := 0.14
## Staff skills that walk the floor.
const ROAMING_SKILLS := [StaffDef.Skill.REPAIR, StaffDef.Skill.SECURITY, StaffDef.Skill.MANAGER]

## Where people are added; y-sorted with the cabinets.
@export var entities: Node2D

var walk_grid: WalkGrid
var customers: Array[Customer] = []
var technicians: Array[Technician] = []
var staff: Array[StaffMember] = []

var _spawn_timer := 0.0
var _staff_signature := ""


func _ready() -> void:
	EventBus.customers_reset.connect(clear_customers)
	EventBus.repair_worker_spawned.connect(spawn_technician)
	EventBus.staff_changed.connect(sync_staff)
	EventBus.state_changed.connect(sync_staff)


func _process(delta: float) -> void:
	if Game.state == null:
		return
	_spawn_timer += delta
	if _spawn_timer >= SPAWN_INTERVAL:
		_spawn_timer = 0.0
		if randf() < FAMILY_CHANCE:
			spawn_family()
		else:
			spawn_customer()
	for c in customers.duplicate():
		_update_customer(c, delta)
	Sfx.set_crowd(customers.size())
	for t in technicians.duplicate():
		_update_technician(t, delta)


func clear_customers() -> void:
	for c in customers:
		c.queue_free()
	customers.clear()


func spawn_family() -> void:
	spawn_customer(Customer.Persona.FAMILY)
	spawn_customer(Customer.Persona.FAMILY, true)
	if randf() < 0.5:
		spawn_customer(Customer.Persona.FAMILY, true)


func spawn_customer(persona := -1, kid := false) -> void:
	var state := Game.state
	if customers.size() >= mini(state.last_day_customers, MAX_ON_FLOOR):
		return
	# Prefer machines with room in the queue so the crowd spreads out.
	var open := state.machines.filter(func(m: MachineInstance) -> bool:
		return m.hp > 0.0 and _heading_to(m.id).size() < QUEUE_MAX)
	if open.is_empty():
		return
	# Visitors drift towards their favourite genre when it's on the floor.
	var favourite := _roll_favourite_genre(kid)
	var fans := open.filter(func(m: MachineInstance) -> bool: return m.def.genre != null and m.def.genre.id == favourite)
	var pool := fans if not fans.is_empty() and randf() < 0.65 else open
	var target: MachineInstance = pool.pick_random()

	var c: Customer = CUSTOMER_SCENE.instantiate()
	c.machine_id = target.id
	c.queue_pos = _heading_to(target.id).size()
	c.persona = (persona as Customer.Persona) if persona >= 0 else _roll_persona()
	c.kid = kid
	c.audience = &"kids" if kid else (&"teen" if randf() < 0.6 else &"adult")
	c.favourite_genre = favourite
	c.speed = randf_range(30.0, 56.0)
	c.play_time = randf_range(1.5, 4.5)
	var stand := FloorGeometry.stand_point(target)
	c.stand_point = Vector2(stand.x + randf_range(-4.8, 4.8), stand.y)
	var door := FloorGeometry.outside_door(state.room)
	c.position = Vector2(door.x + randf_range(-6.0, 6.0), door.y)
	if kid:
		c.scale = Vector2(0.8, 0.8)
	entities.add_child(c)
	c.walk(walk_grid.route(c.position, _queue_point(c)))
	customers.append(c)


func spawn_technician(machine_id: int, senior: bool) -> void:
	var m := Game.state.machine_by_id(machine_id)
	if m == null:
		return
	var t: Technician = TECHNICIAN_SCENE.instantiate()
	t.machine_id = machine_id
	t.senior = senior
	t.speed = randf_range(36.0, 54.0)
	t.work_time = randf_range(3.7, 4.7)
	if senior:
		t.sprite_modulate(Color(0.6, 0.75, 1.0))
	t.position = FloorGeometry.outside_door(Game.state.room)
	entities.add_child(t)
	var stand := FloorGeometry.stand_point(m)
	var route := walk_grid.route(t.position, stand)
	route.append(Vector2(FloorGeometry.machine_anchor(m).x, stand.y))
	t.walk(route)
	technicians.append(t)


## Re-routes everyone mid-walk after machines are placed, moved or sold.
func reroute() -> void:
	for c in customers:
		if c.is_moving():
			c.walk(walk_grid.route(c.position, c.waypoints[-1]))
	for t in technicians:
		if t.is_moving():
			t.walk(walk_grid.route(t.position, t.waypoints[-1]))


## Keeps the roaming staff in step with who's hired.
func sync_staff() -> void:
	if Game.state == null:
		return
	var roaming := Game.state.staff.filter(func(s: StaffInstance) -> bool: return s.def.skill in ROAMING_SKILLS)
	var ids: Array = roaming.map(func(s: StaffInstance) -> String: return s.def.id)
	ids.sort()
	var signature := ",".join(ids)
	if signature == _staff_signature:
		return
	_staff_signature = signature
	for s in staff:
		s.queue_free()
	staff.clear()
	var room := Game.state.room
	var front := FloorGeometry.front_y(room)
	var area := Rect2(20.0, front - 16.0, room.x * FloorGeometry.TILE - 40.0, 20.0)
	for i in roaming.size():
		var s: StaffMember = STAFF_SCENE.instantiate()
		s.roam_area = area
		s.speed = randf_range(19.0, 34.0)
		s.position = Vector2(area.position.x + (i + 0.5) * area.size.x / roaming.size(), front - 4.0)
		entities.add_child(s)
		staff.append(s)


func _update_customer(c: Customer, delta: float) -> void:
	var m := Game.state.machine_by_id(c.machine_id)
	if m == null and c.state != Customer.State.LEAVING:
		_leave(c)
		return
	match c.state:
		Customer.State.PLAYING:
			c.play_time -= delta
			if c.play_time <= 0.0:
				_finish_playing(c)
		Customer.State.WAITING:
			_try_step_up(c)
		Customer.State.WALKING:
			if not c.is_moving():
				_arrive(c, m)
		Customer.State.LEAVING:
			if not c.is_moving():
				customers.erase(c)
				c.queue_free()


func _arrive(c: Customer, m: MachineInstance) -> void:
	if c.queue_pos <= 0:
		c.state = Customer.State.PLAYING
		c.face(FloorGeometry.machine_anchor(m) - c.position if m.facing != MachineInstance.Facing.N else Vector2.UP)
	else:
		c.state = Customer.State.WAITING
		c.face(Vector2.UP)


## The front of the queue steps up the moment the machine frees; everyone
## behind shuffles forward a place.
func _try_step_up(c: Customer) -> void:
	var waiters := customers.filter(func(o: Customer) -> bool:
		return o.machine_id == c.machine_id and o.state == Customer.State.WAITING)
	var front: Customer = waiters.reduce(func(a: Customer, b: Customer) -> Customer: return b if b.queue_pos < a.queue_pos else a)
	if front != c or _machine_taken(c.machine_id):
		return
	c.queue_pos = 0
	c.state = Customer.State.WALKING
	c.walk(PackedVector2Array([_queue_point(c)]))
	for o: Customer in waiters:
		if o != c:
			o.queue_pos = maxi(1, o.queue_pos - 1)
			o.state = Customer.State.WALKING
			o.walk(PackedVector2Array([_queue_point(o)]))


func _finish_playing(c: Customer) -> void:
	if c.persona == Customer.Persona.VIP:
		var tip := randi_range(2, 6)
		Game.state.cash += tip
		EventBus.tip_received.emit(c.position, tip)
	elif c.persona == Customer.Persona.STAR:
		Game.state.buzz += 1.0
	_leave(c)


func _leave(c: Customer) -> void:
	c.state = Customer.State.LEAVING
	c.queue_pos = 99
	var room := Game.state.room
	var route := walk_grid.route(c.position, Vector2(FloorGeometry.door_x(room), FloorGeometry.front_y(room)))
	route.append(FloorGeometry.outside_door(room))
	c.walk(route)


func _update_technician(t: Technician, delta: float) -> void:
	match t.state:
		Technician.State.WALKING:
			if not t.is_moving():
				t.state = Technician.State.WORKING
				t.face(Vector2.UP)
		Technician.State.WORKING:
			t.work_time -= delta
			if t.work_time <= 0.0:
				t.state = Technician.State.LEAVING
				var room := Game.state.room
				var route := walk_grid.route(t.position, Vector2(FloorGeometry.door_x(room), FloorGeometry.front_y(room)))
				route.append(FloorGeometry.outside_door(room))
				t.walk(route)
		Technician.State.LEAVING:
			if not t.is_moving():
				technicians.erase(t)
				t.queue_free()


## Customers heading for a machine (playing, walking up or queueing).
func _heading_to(machine_id: int) -> Array[Customer]:
	var out: Array[Customer] = []
	out.assign(customers.filter(func(c: Customer) -> bool: return c.machine_id == machine_id and c.state != Customer.State.LEAVING))
	return out


## Someone is playing, or walking up to play.
func _machine_taken(machine_id: int) -> bool:
	return customers.any(func(c: Customer) -> bool:
		return c.machine_id == machine_id and (c.state == Customer.State.PLAYING or (c.state == Customer.State.WALKING and c.queue_pos == 0)))


func _queue_point(c: Customer) -> Vector2:
	return c.stand_point + Vector2(0.0, c.queue_pos * QUEUE_STEP)


static func _roll_persona() -> Customer.Persona:
	var r := randf()
	if r < 0.08:
		return Customer.Persona.VIP
	if r < 0.15:
		return Customer.Persona.STAR
	return Customer.Persona.REGULAR


static func _roll_favourite_genre(kid: bool) -> StringName:
	if kid and randf() < 0.5:
		return &"prize"
	return (Data.db.genres.pick_random() as GenreDef).id

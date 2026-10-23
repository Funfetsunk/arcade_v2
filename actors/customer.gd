class_name Customer
extends Walker
## A visitor: walks to a cabinet, queues if it's busy, plays, then leaves.
## The crowd logic (spawning, queues) lives in Crowd.

enum State { WALKING, WAITING, PLAYING, LEAVING }
## Most are regulars; VIPs tip on the way out, stars build a little buzz,
## families arrive together.
enum Persona { REGULAR, VIP, STAR, FAMILY }

const NAMES := [
	"Maya", "Leo", "Zoe", "Finn", "Ada", "Rex", "Ivy", "Gus", "Nia", "Sam", "Joy", "Max", "Lula", "Theo", "Pia", "Cole",
	"Ruby", "Otis", "Wren", "Ezra", "Cleo", "Hank", "Isla", "Jude", "Kira", "Lars", "Mona", "Nico", "Opal", "Pete", "Quin", "Rosa",
	"Seth", "Tess", "Umi", "Vera", "Walt", "Xena", "Yuki", "Zane", "Bea", "Cody", "Dot", "Eli", "Faye", "Gil", "Hope", "Iggy",
	"June", "Kobe", "Lena", "Milo", "Nell", "Omar", "Posy", "Reid", "Sage", "Tova", "Vito", "Willa", "Yara", "Ziggy",
]

static var _next_id := 200

var visitor_id := 0
var state := State.WALKING
var machine_id := -1
## 0 = heading straight to play; 1+ = place in the queue.
var queue_pos := 0
## Where this customer stands to play (x has a little jitter).
var stand_point := Vector2.ZERO
var play_time := 0.0
var persona := Persona.REGULAR
var kid := false
var favourite_genre: StringName
var audience := &"teen"


func _init() -> void:
	visitor_id = _next_id
	_next_id += 1


func display_name() -> String:
	return NAMES[visitor_id % NAMES.size()]


## Mood 0-100 from today's satisfaction, coloured by what this visitor is up to.
## Visitors still walking in only half-feel the arcade's mood.
func mood(state_now: GameState) -> Dictionary:
	var sat := state_now.satisfaction
	var s := (sat + 70.0) / 2.0 if state == State.WALKING else sat
	var m := state_now.machine_by_id(machine_id)
	if state == State.PLAYING:
		s += 5.0
		if m and m.def.genre and m.def.genre.id == favourite_genre:
			s += 12.0
	if state == State.WAITING:
		s -= 8.0 * queue_pos
	if persona == Persona.VIP or persona == Persona.STAR:
		s += 8.0
	if kid:
		s += 5.0
	var score := clampi(GameMath.js_round(s), 0, 100)
	var faces: Array = ["😄", "Delighted"] if score >= 85 else ["🙂", "Happy"] if score >= 65 else ["😐", "Okay"] if score >= 45 else ["😠", "Grumpy"] if score >= 25 else ["😡", "Fuming"]
	return { score = score, emoji = faces[0], label = faces[1] }


func activity(state_now: GameState) -> String:
	if state == State.LEAVING:
		return "Heading home 👋"
	var m := state_now.machine_by_id(machine_id)
	if m == null:
		return "Wandering the floor 🚶"
	match state:
		State.PLAYING:
			return "Playing %s 🕹️" % m.def.display_name
		State.WAITING:
			return "In line for %s (#%d) ⏳" % [m.def.display_name, queue_pos]
	return "Heading to %s 🚶" % m.def.display_name

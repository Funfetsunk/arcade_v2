class_name Customer
extends Walker
## A visitor: walks to a cabinet, queues if it's busy, plays, then leaves.
## The crowd logic (spawning, queues) lives in Crowd.

enum State { WALKING, WAITING, PLAYING, LEAVING }
## Most are regulars; VIPs tip on the way out, stars build a little buzz,
## families arrive together.
enum Persona { REGULAR, VIP, STAR, FAMILY }

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

class_name Technician
extends Walker
## A repair tech who walks to a fixed machine, works on it a while, then leaves.

enum State { WALKING, WORKING, LEAVING }

var state := State.WALKING
var machine_id := -1
var work_time := 0.0
var senior := false

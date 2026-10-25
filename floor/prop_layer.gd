class_name PropLayer
extends Node
## Shows the bought decor and facilities. Standing props join the y-sorted
## entities so people walk in front of and behind them; wall props and rugs go
## on the backdrop, under everyone.

const PROP_SCENE := preload("res://floor/floor_prop.tscn")

@export var entities: Node2D
@export var backdrop: Node2D

var _props: Array[FloorProp] = []


func show_spots(spots: Array[PropLayout.Spot]) -> void:
	for p in _props:
		p.queue_free()
	_props.clear()
	for spot in spots:
		var prop: FloorProp = PROP_SCENE.instantiate()
		(backdrop if spot.def.on_wall or spot.def.flat else entities).add_child(prop)
		prop.show_spot(spot)
		_props.append(prop)


## A string that changes whenever the layout would look different.
static func key_of(spots: Array[PropLayout.Spot]) -> String:
	return ",".join(spots.map(func(s: PropLayout.Spot) -> String: return "%s@%s" % [s.def.id, s.tile]))

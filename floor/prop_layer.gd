class_name PropLayer
extends Node
## Shows the bought decor and facilities. Standing props join the y-sorted
## entities so people walk in front of and behind them; wall props and rugs go
## on the backdrop, under everyone.

const PROP_SCENE := preload("res://floor/floor_prop.tscn")
const SIGN_SCRIPT := preload("res://floor/neon_sign.gd")

@export var entities: Node2D
@export var backdrop: Node2D

var _props: Array[Node2D] = []


func show_spots(spots: Array[PropLayout.Spot], arcade_name: String, sign_colour: Color) -> void:
	for p in _props:
		p.queue_free()
	_props.clear()
	for spot in spots:
		if spot.name_sign:
			var neon: NeonSign = SIGN_SCRIPT.new()
			neon.position.x = spot.tile.x * FloorGeometry.TILE
			backdrop.add_child(neon)
			neon.show_sign(arcade_name, sign_colour)
			_props.append(neon)
			continue
		var prop: FloorProp = PROP_SCENE.instantiate()
		(backdrop if spot.def.on_wall or spot.def.flat else entities).add_child(prop)
		prop.show_spot(spot)
		_props.append(prop)


## A string that changes whenever the layout would look different.
static func key_of(spots: Array[PropLayout.Spot]) -> String:
	return ",".join(spots.map(func(s: PropLayout.Spot) -> String: return "%s@%s" % [s.def.id, s.tile]))

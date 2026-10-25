class_name FloorPropDef
extends Resource
## Something bought for the room that shows on the floor or the back wall:
## decor props and facilities share this.

@export var id: StringName
@export var display_name: String
@export var emoji: String
@export var cost: int
@export var blurb: String

@export_group("Art")
## Drawn bottom-centre on its spot.
@export var sprite: Texture2D
## Tiles wide on the floor (props are always one tile deep).
@export_range(1, 2) var width := 1
## Hangs on the back wall instead of standing on the floor.
@export var on_wall := false
## Lies flat under people (a rug): never blocks walking.
@export var flat := false

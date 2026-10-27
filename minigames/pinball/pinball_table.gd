class_name PinballTable
extends Resource
## One pinball table: its playfield art and where its pieces sit, in board
## pixels (the 180x230 art is drawn at 2x). The flippers and the launcher are
## the same on every table; everything else follows the art.

@export var playfield: Texture2D
## The playfield's sides and top (the ball can't leave them).
@export var bounds := Rect2(6, 12, 348, 460)
## Rails and guides painted on the playfield, as polylines.
@export var walls: Array[PackedVector2Array] = []
@export var bumpers := PackedVector2Array()
@export var bumper_r := 14.0
@export var posts := PackedVector2Array()
## Rollover lights; lighting them all raises the multiplier.
@export var lanes := PackedVector2Array()
## A bank of drop targets; knocking them all down pays a bonus.
@export var drops := PackedVector2Array()
## Where a launched ball, rising up the right-hand lane, is turned into play (and
## a ball falling back in is turned out again).
@export var deflector := Rect2(310, 20, 44, 50)
@export var deflect_dir := Vector2(-0.95, 0.3)

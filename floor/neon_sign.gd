class_name NeonSign
extends Node2D
## The arcade's name in neon on a dark board with a neon frame, centred high on
## the back wall in the theme's sign colour, with a soft glow and the odd flicker
## (as in the original). Lit by the first Neon Sign bought.

const FONT := preload("res://assets/fonts/arcade_empire_pixel.ttf")
const FONT_SIZE := 16
## Centre of the sign, above the floor's top edge.
const CENTRE_Y := -30.0
const BOARD := Color("0c0916")

var text := "ARCADE EMPIRE"
var colour := Color("00f5d4")
var _time := 0.0


func show_sign(arcade_name: String, sign_colour: Color) -> void:
	text = arcade_name.to_upper().left(20)
	colour = sign_colour
	position.y = CENTRE_Y
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	# A slow breathe, and now and then a quick dip like a tired tube.
	var flick := 0.88 + 0.12 * sin(_time * 3.0)
	if sin(_time * 54.0) > 0.97:
		flick -= 0.3
	modulate.a = maxf(0.5, flick)


func _draw() -> void:
	var size := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	# Baseline 5 px below the centre: the capitals are 10 px tall at this size.
	var origin := Vector2(-size.x / 2.0, 5.0)
	var core := colour.lerp(Color.WHITE, 0.55)
	var box := Rect2(-size.x / 2.0 - 6, -9, size.x + 12, 18)
	draw_rect(box, BOARD)
	draw_rect(box.grow(-1), Color(colour, 0.9), false, 1.0)
	# Glow: soft outlines around the letters, then the bright core.
	draw_string_outline(FONT, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, Color(colour, 0.25))
	draw_string_outline(FONT, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 2, Color(colour, 0.45))
	draw_string(FONT, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, core)

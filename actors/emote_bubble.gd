class_name EmoteBubble
extends Node2D
## A customer's thought bubble (RCT-style emotes) and, when they aren't
## thinking anything, their persona badge: 🎩 for a VIP, a pulsing ⭐ for a
## star. Drawn above every walker so neighbours never cover it.

## Fade out over the last 16 frames, as in the original.
const FADE := 16.0 / 60.0
## Bubble centre and badge foot, above the customer's feet.
const BUBBLE_Y := -48.0
const BADGE_Y := -38.0
const BUBBLE := Color("fdf6e3")

var _customer: Customer
var _time := 0.0


func _ready() -> void:
	_customer = get_parent() as Customer
	z_index = 100


func _process(delta: float) -> void:
	_time += delta
	if _customer.emote_time > 0.0:
		_customer.emote_time = maxf(0.0, _customer.emote_time - delta)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	if _customer.emote_time > 0.0:
		var fade := minf(1.0, _customer.emote_time / FADE)
		var body := Color(BUBBLE, 0.95 * fade)
		draw_rect(Rect2(-8, BUBBLE_Y - 7, 16, 14), body)
		draw_rect(Rect2(-8, BUBBLE_Y - 7, 16, 1.6), Color(1, 1, 1, 0.95 * fade))
		draw_rect(Rect2(-1.4, BUBBLE_Y + 7, 3.2, 3.2), body)
		_glyph(font, _customer.emote, Vector2(0, BUBBLE_Y), 10, Color(1, 1, 1, fade))
	elif _customer.persona == Customer.Persona.VIP:
		_glyph(font, "🎩", Vector2(0, BADGE_Y - 3), 6, Color.WHITE)
	elif _customer.persona == Customer.Persona.STAR:
		_glyph(font, "⭐", Vector2(0, BADGE_Y - 3), 6, Color(1, 1, 1, 0.7 + 0.3 * sin(_time * 2.0)))


## Draws a glyph centred on a point.
func _glyph(font: Font, text: String, at: Vector2, size: int, color: Color) -> void:
	var extent := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	draw_string(font, at + Vector2(-extent.x / 2.0, font.get_ascent(size) - extent.y / 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

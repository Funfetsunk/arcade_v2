class_name FloorCamera
extends Camera2D
## Pan and zoom over the floor: drag to pan, wheel or pinch to zoom, and
## zoom-to-fit the whole room (which is also the smallest zoom allowed).

const MAX_ZOOM := 4.0
## Margin kept around the room when fitting, as a fraction of the view.
const FIT_MARGIN := 0.92

## Screen space covered by the HUD at the top and bottom, kept clear when fitting.
@export var hud_top := 36.0
@export var hud_bottom := 44.0

var bounds := Rect2()
var _fit_zoom := 1.0


## Frames the whole room in the space between the top bar and the action bar.
func fit(rect: Rect2) -> void:
	bounds = rect
	var view := get_viewport_rect().size - Vector2(0.0, hud_top + hud_bottom)
	_fit_zoom = minf(view.x / rect.size.x, view.y / rect.size.y) * FIT_MARGIN
	zoom = Vector2.ONE * _fit_zoom
	# Shift the view so the room is centred in the free space, not the screen.
	position = rect.get_center() + Vector2(0.0, (hud_bottom - hud_top) / 2.0) / _fit_zoom


func pan_by(screen_delta: Vector2) -> void:
	position -= screen_delta / zoom
	_clamp()


## Zooms by `factor`, keeping the floor point under `screen_point` still.
func zoom_at(factor: float, screen_point: Vector2) -> void:
	var before := screen_to_floor(screen_point)
	zoom = Vector2.ONE * clampf(zoom.x * factor, _fit_zoom, MAX_ZOOM)
	position += before - screen_to_floor(screen_point)
	_clamp()


func screen_to_floor(screen_point: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_point


func _clamp() -> void:
	if bounds.size == Vector2.ZERO:
		return
	var half_view := get_viewport_rect().size / zoom / 2.0
	var lo := bounds.position + half_view
	var hi := bounds.end - half_view
	position.x = bounds.get_center().x if lo.x > hi.x else clampf(position.x, lo.x, hi.x)
	position.y = bounds.get_center().y if lo.y > hi.y else clampf(position.y, lo.y, hi.y)

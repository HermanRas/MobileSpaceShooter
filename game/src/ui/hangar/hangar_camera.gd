class_name HangarCamera
extends Camera2D
## The hangar camera: zoom around a point, pan by screen pixels, clamp to sane limits.
##
## Touch gestures are interpreted by the hangar controller (it decides whether one finger
## pans or carries a tile), which then calls `pan_by()` and `zoom_at()`. Mouse wheel and
## middle-drag are handled here for desktop.

## From the whole 16 U build area down to a Small tile filling a thumb on the phone.
const MIN_ZOOM := 0.5
const MAX_ZOOM := 12.0
const WHEEL_STEP := 1.15

var _middle_dragging := false


func pan_by(screen_delta: Vector2) -> void:
	position -= screen_delta / zoom.x


func zoom_at(screen_point: Vector2, factor: float) -> void:
	var before := screen_to_world(screen_point)
	var z := clampf(zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2(z, z)
	force_update_scroll()
	position += before - screen_to_world(screen_point)


func screen_to_world(screen_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_point


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			zoom_at(button.position, WHEEL_STEP)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			zoom_at(button.position, 1.0 / WHEEL_STEP)
		elif button.button_index == MOUSE_BUTTON_MIDDLE:
			_middle_dragging = button.pressed
	elif event is InputEventMouseMotion and _middle_dragging:
		pan_by((event as InputEventMouseMotion).relative)
	elif event is InputEventMagnifyGesture:
		var magnify := event as InputEventMagnifyGesture
		zoom_at(magnify.position, magnify.factor)
	elif event is InputEventPanGesture:
		pan_by(-(event as InputEventPanGesture).delta * 8.0)

class_name TouchStick
extends Control
## A floating virtual stick (PLAN.md 4.7, Phase 3.4): it appears where the thumb lands inside
## this control's rect and reads the drag from there. `value` is a direction of length 0..1
## (screen space, which is world space while the camera doesn't rotate). The dead zone is the
## flight model's, so the stick reports raw values.
##
## Each instance follows one finger, so a second finger elsewhere (FIRE, 3.4) never moves it.

signal released

## Drag distance that counts as full deflection at stick size 1, in canvas pixels.
const RADIUS := 110.0

var value := Vector2.ZERO
## Settings' stick_size and stick_opacity.
var size_scale := 1.0
var opacity := 0.6

var _finger := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func is_active() -> bool:
	return _finger >= 0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _finger < 0:
			_finger = touch.index
			_origin = touch.position
			_knob = touch.position
			value = Vector2.ZERO
			accept_event()
			queue_redraw()
		elif not touch.pressed and touch.index == _finger:
			_finger = -1
			value = Vector2.ZERO
			accept_event()
			queue_redraw()
			released.emit()
	elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _finger:
		var radius := RADIUS * size_scale
		var offset := (event as InputEventScreenDrag).position - _origin
		value = offset.limit_length(radius) / radius
		_knob = _origin + offset.limit_length(radius)
		accept_event()
		queue_redraw()


func _draw() -> void:
	if _finger < 0:
		return
	draw_arc(_origin, RADIUS * size_scale, 0.0, TAU, 48, Color(1, 1, 1, opacity * 0.45), 3.0, true)
	draw_circle(_knob, 34.0 * size_scale, Color(1, 1, 1, opacity))


## Lets go without a release event, e.g. when the layout moves the stick's zone.
func reset() -> void:
	_finger = -1
	value = Vector2.ZERO
	queue_redraw()

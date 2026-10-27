class_name TouchButton
extends Control
## A round on-screen button that works under any finger (PLAN.md 4.7, Phase 3.4).
##
## Godot's Button only hears the first finger (the one emulated as a mouse), so FIRE pressed
## while the other thumb holds the stick would be ignored. This reads InputEventScreenTouch
## directly and follows one finger, the same way TouchStick does.

signal pressed
signal released

@export var text := ""
## Drawn in place of `text` when set (A.4's symbols), ICON_SHARE of the button across.
var icon: Texture2D:
	set(value):
		icon = value
		queue_redraw()
var held := false
var fill := Color(1, 1, 1, 0.18)
var outline := Color(1, 1, 1, 0.6)

var _finger := -1

const ICON_SHARE := 0.55


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventScreenTouch:
		return
	var touch := event as InputEventScreenTouch
	if touch.pressed and _finger < 0 and _inside(touch.position):
		_finger = touch.index
		held = true
		accept_event()
		queue_redraw()
		pressed.emit()
	elif not touch.pressed and touch.index == _finger:
		_finger = -1
		held = false
		accept_event()
		queue_redraw()
		released.emit()


## Lets go without a release event, e.g. when the layout hides the button.
func reset() -> void:
	_finger = -1
	held = false
	queue_redraw()


func _inside(local: Vector2) -> bool:
	return local.distance_to(size * 0.5) <= minf(size.x, size.y) * 0.5


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 2.0
	draw_circle(center, radius, Color(fill, fill.a * (2.5 if held else 1.0)))
	draw_arc(center, radius, 0.0, TAU, 48, outline, 3.0, true)
	if icon != null:
		var side := radius * 2.0 * ICON_SHARE
		draw_texture_rect(icon, Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side)), false,
				Color(1, 1, 1, maxf(outline.a, 0.75)))
		return
	var font := get_theme_default_font()
	var font_size := 20
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, center + Vector2(-width * 0.5, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size, Color(1, 1, 1, outline.a))

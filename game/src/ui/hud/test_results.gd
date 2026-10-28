class_name TestResults
extends ColorRect
## The results card at the end of a Creative test fight (PLAN.md 7.2): cleared or destroyed, the
## time, the kills and the damage taken, over a dimmed, paused game; or the performance test's
## frame times (7.5). Fly again restarts the same
## level; Return to hangar (or the back gesture) leaves. Whoever shows it pauses the tree; it runs
## while paused.

signal again_requested
signal hangar_requested

var _title := MenuKit.label("", 44)
var _lines := VBoxContainer.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	color = Color(0, 0, 0, 0.6)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ChromePanel"
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 16)
	panel.add_child(column)
	column.add_child(_title)
	_lines.add_theme_constant_override(&"separation", 6)
	column.add_child(_lines)
	var size := Vector2(320, 64)
	var again := MenuKit.button("Fly again", func() -> void: again_requested.emit(), size, 24)
	again.theme_type_variation = &"GoButton"
	column.add_child(again)
	column.add_child(MenuKit.button("Return to hangar", func() -> void: hangar_requested.emit(), size, 24))


func show_flight(flight: TestFlight) -> void:
	show_report(flight.title(), flight.lines(), flight.outcome == TestFlight.Outcome.CLEARED)


## `title` (green if `good`, else red) over `lines`.
func show_report(title: String, lines: PackedStringArray, good: bool, font_size := 24) -> void:
	_title.text = title
	_title.add_theme_color_override(&"font_color", Color(0.6, 1.0, 0.55) if good else Color(1.0, 0.5, 0.45))
	for child in _lines.get_children():
		child.queue_free()
	for line in lines:
		_lines.add_child(MenuKit.label(line, font_size if not line.begins_with("  ") else font_size - 6))
	visible = true

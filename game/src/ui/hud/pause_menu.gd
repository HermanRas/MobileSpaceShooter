class_name PauseMenu
extends ColorRect
## The flight's pause menu (PLAN.md 6.5, D18): Resume, Settings and Return to hangar over a
## dimmed, paused game. The pause action (Esc, P, a gamepad's Start) resumes too. Story adds
## "Save and return to hangar" once it exists (§4.10). Whoever opens it pauses the tree; it
## runs while paused.

signal resumed
signal settings_requested
signal hangar_requested


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	color = Color(0, 0, 0, 0.55)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 16)
	center.add_child(column)
	column.add_child(MenuKit.label("Paused", 48))
	var size := Vector2(320, 64)
	column.add_child(MenuKit.button("Resume", func() -> void: resumed.emit(), size, 24))
	column.add_child(MenuKit.button("Settings", func() -> void: settings_requested.emit(), size, 24))
	column.add_child(MenuKit.button("Return to hangar", func() -> void: hangar_requested.emit(), size, 24))


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		resumed.emit()

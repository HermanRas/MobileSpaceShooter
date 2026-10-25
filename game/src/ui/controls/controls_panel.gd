class_name ControlsPanel
extends PanelContainer
## The control settings (PLAN.md 4.7): scheme, handedness, stick size and opacity. Writes
## straight to Settings; FlightControls re-lays itself out on the change. Opened from the
## flight sandbox now, and part of the Settings menu later (6.4).

signal closed


func _ready() -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.05, 0.06, 0.09, 0.95)
	background.set_content_margin_all(20)
	background.set_corner_radius_all(8)
	add_theme_stylebox_override(&"panel", background)
	refresh()


## Rebuilds the widgets from the current Settings; call it each time the panel opens, since
## the settings may have changed elsewhere since it was built.
func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 14)
	add_child(column)

	var title := Label.new()
	title.text = "Controls"
	title.add_theme_font_size_override(&"font_size", 26)
	column.add_child(title)

	var schemes := HBoxContainer.new()
	column.add_child(schemes)
	var group := ButtonGroup.new()
	for scheme: Array in [["2-stick", "Stick + FIRE"], ["1-stick", "Stick only (auto-fire)"]]:
		var button := Button.new()
		button.text = scheme[1]
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(220, 56)
		button.button_pressed = Settings.get_value(&"control_scheme") == scheme[0]
		button.toggled.connect(func(on: bool) -> void:
			if on:
				Settings.set_value(&"control_scheme", scheme[0]))
		schemes.add_child(button)

	var handed := CheckButton.new()
	handed.text = "Left-handed (stick on the right)"
	handed.button_pressed = Settings.get_value(&"left_handed")
	handed.custom_minimum_size = Vector2(0, 56)
	handed.toggled.connect(func(on: bool) -> void: Settings.set_value(&"left_handed", on))
	column.add_child(handed)

	_slider(column, "Stick size", &"stick_size", 0.6, 1.6)
	_slider(column, "Opacity", &"stick_opacity", 0.2, 1.0)

	var close := Button.new()
	close.text = "Done"
	close.custom_minimum_size = Vector2(160, 56)
	close.pressed.connect(func() -> void: closed.emit())
	column.add_child(close)


func _slider(parent: Control, text: String, key: StringName, low: float, high: float) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(140, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.05
	slider.value = float(Settings.get_value(key))
	slider.custom_minimum_size = Vector2(300, 48)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Saved when the thumb lets go, not on every step of the drag.
	slider.drag_ended.connect(func(_changed: bool) -> void: Settings.set_value(key, slider.value))
	row.add_child(slider)

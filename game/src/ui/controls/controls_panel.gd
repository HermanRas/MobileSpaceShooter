class_name ControlsPanel
extends PanelContainer
## The control settings (PLAN.md 4.7): scheme, handedness, stick size and opacity, the
## combat HUD's vibration and screen shake (4.7), the flight view's zoom, and a list of the
## hotkeys (owner, 2026-10-26). Writes
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
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override(&"separation", 32)
	add_child(sides)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 14)
	sides.add_child(column)

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

	_toggle(column, "Left-handed (stick on the right)", &"left_handed")
	_toggle(column, "Vibrate when hit", &"vibration")
	_toggle(column, "Screen shake", &"screen_shake")

	_slider(column, "Stick size", &"stick_size", 0.6, 1.6)
	_slider(column, "Opacity", &"stick_opacity", 0.2, 1.0)
	var camera: Dictionary = Data.table(&"flight").get("camera", {})
	_slider(column, "View zoom", &"view_zoom", float(camera.get("view_zoom_min", 0.35)),
			float(camera.get("view_zoom_max", 2.5)))

	var close := Button.new()
	close.text = "Done"
	close.custom_minimum_size = Vector2(160, 56)
	close.pressed.connect(func() -> void: closed.emit())
	column.add_child(close)
	sides.add_child(_hotkeys())


## Every keyboard shortcut, by where it works (Settings.hotkeys()), scrolling if it's tall.
func _hotkeys() -> Control:
	var side := VBoxContainer.new()
	side.add_theme_constant_override(&"separation", 10)
	side.name = "Hotkeys"
	var title := Label.new()
	title.text = "Hotkeys"
	title.add_theme_font_size_override(&"font_size", 26)
	side.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 440)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 20)
	grid.add_theme_constant_override(&"v_separation", 6)
	scroll.add_child(grid)
	var where := ""
	for row: Array in Settings.hotkeys():
		if row[0] != where:
			where = row[0]
			grid.add_child(_small(where, Color(1, 1, 1, 0.55)))
			grid.add_child(_small("", Color.WHITE))
		grid.add_child(_small(row[1], Color(1, 0.85, 0.5)))
		grid.add_child(_small(row[2], Color.WHITE))
	return side


func _small(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 16)
	label.add_theme_color_override(&"font_color", color)
	return label


func _toggle(parent: Control, text: String, key: StringName) -> void:
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.button_pressed = Settings.get_value(key)
	toggle.custom_minimum_size = Vector2(0, 56)
	toggle.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
	parent.add_child(toggle)


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

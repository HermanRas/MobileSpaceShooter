class_name ControlsPanel
extends PanelContainer
## Every setting (PLAN.md 4.7, 6.4) in three columns: Controls (scheme, handedness, stick size
## and opacity), Sound & feel (music and SFX volume, vibration, screen shake, the flight view's
## zoom) and the hotkeys (owner, 2026-10-26). Each applies at once (a slider while it's dragged)
## and is saved to Settings. Opened from the flight sandbox and the main menu's Settings; back
## (the gesture, or Esc) closes it.

## How long a slider must be still before its value is saved, in seconds.
const SAVE_AFTER_S := 0.4


func _ready() -> void:
	theme_type_variation = &"ChromePanel"
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
		button.custom_minimum_size = Vector2(180, 56)
		button.button_pressed = Settings.get_value(&"control_scheme") == scheme[0]
		button.toggled.connect(func(on: bool) -> void:
			if on:
				Settings.set_value(&"control_scheme", scheme[0]))
		schemes.add_child(button)

	_toggle(column, "Left-handed (stick on the right)", &"left_handed")
	_slider(column, "Stick size", &"stick_size", 0.6, 1.6)
	_slider(column, "Opacity", &"stick_opacity", 0.2, 1.0)

	var feel := VBoxContainer.new()
	feel.name = "SoundAndFeel"
	feel.add_theme_constant_override(&"separation", 14)
	sides.add_child(feel)
	var heading := Label.new()
	heading.text = "Sound & feel"
	heading.add_theme_font_size_override(&"font_size", 26)
	feel.add_child(heading)
	_slider(feel, "Music", &"music_volume", 0.0, 1.0)
	_slider(feel, "Sound effects", &"sfx_volume", 0.0, 1.0)
	_toggle(feel, "Vibrate when hit", &"vibration")
	_toggle(feel, "Screen shake", &"screen_shake")
	var camera: Dictionary = Data.table(&"flight").get("camera", {})
	_slider(feel, "View zoom", &"view_zoom", float(camera.get("view_zoom_min", 0.35)),
			float(camera.get("view_zoom_max", 2.5)))
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
	slider.name = String(key)
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.05
	slider.value = float(Settings.get_value(key))
	slider.custom_minimum_size = Vector2(220, 48)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Applies at every step; saved once the slider has been still for SAVE_AFTER_S, not on every
	# step of a drag (a tap on the track moves it without a drag ending).
	var moves := [0]
	slider.value_changed.connect(func(value: float) -> void:
		Settings.preview_value(key, value)
		moves[0] += 1
		var this_move: int = moves[0]
		get_tree().create_timer(SAVE_AFTER_S).timeout.connect(func() -> void:
			if moves[0] == this_move:
				Settings.set_value(key, value)))
	row.add_child(slider)

extends Control
## Placeholder main menu (Phase 0). Phase 6.1 replaces it with the real one.
##
## Built in code rather than authored in the editor, so the editor cannot silently reformat it.

const DEV_PROFILE := "dev"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	center.add_child(column)

	column.add_child(_label("MSS", 64))
	column.add_child(_label("Mobile Space Shooter  v%s" % ProjectSettings.get_setting("application/config/version"), 20))

	if not Data.errors.is_empty():
		var errors := _label("%d data file error(s), see the log" % Data.errors.size(), 20)
		errors.add_theme_color_override(&"font_color", Color(1.0, 0.35, 0.35))
		column.add_child(errors)

	var hangar := Button.new()
	hangar.text = "Hangar"
	hangar.custom_minimum_size = Vector2(260, 72)
	hangar.add_theme_font_size_override(&"font_size", 28)
	hangar.pressed.connect(func() -> void:
		Profiles.active_id = ""  # Creative until the mode buttons arrive (6.1)
		Router.goto("res://scenes/hangar/hangar.tscn"))
	column.add_child(hangar)

	if OS.is_debug_build():
		# Building that pays from a dev profile's stock (PLAN.md 4.8a), until profiles (6.2).
		var stocked := Button.new()
		stocked.text = "Hangar (stocked)"
		stocked.custom_minimum_size = Vector2(260, 56)
		stocked.pressed.connect(func() -> void:
			Profiles.active_id = DEV_PROFILE
			Router.goto("res://scenes/hangar/hangar.tscn"))
		column.add_child(stocked)
		var reset := Button.new()
		reset.text = "Reset stocked hangar"
		reset.custom_minimum_size = Vector2(260, 56)
		reset.pressed.connect(func() -> void:
			var path := Profiles.profile_dir(DEV_PROFILE).path_join(StockStore.FILE)
			for file in [path, path + Save.BAK_SUFFIX]:
				if FileAccess.file_exists(file):
					DirAccess.remove_absolute(file)
			reset.text = "Stocked hangar reset")
		column.add_child(reset)
		var stress := Button.new()
		stress.text = "Shot stress test"
		stress.custom_minimum_size = Vector2(260, 56)
		stress.pressed.connect(func() -> void: Router.goto("res://scenes/debug/shot_stress.tscn"))
		column.add_child(stress)


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", size)
	return label

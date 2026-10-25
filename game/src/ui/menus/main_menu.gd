extends Control
## Placeholder main menu (Phase 0). Phase 6.1 replaces it with the real one.
##
## Built in code rather than authored in the editor, so the editor cannot silently reformat it.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(column)

	column.add_child(_label("MSP", 64))
	column.add_child(_label("Mobile Space Shooter  v%s" % ProjectSettings.get_setting("application/config/version"), 20))

	if not Data.errors.is_empty():
		var errors := _label("%d data file error(s), see the log" % Data.errors.size(), 20)
		errors.add_theme_color_override(&"font_color", Color(1.0, 0.35, 0.35))
		column.add_child(errors)


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", size)
	return label

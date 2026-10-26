extends Control
## Credits (PLAN.md 6.1): who made what (`data/credits.json`), then Godot's licence, which its
## MIT terms require we show, and the engine's third-party notices behind a button.

var _notices := Label.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(MenuBackdrop.new())
	var frame := MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		frame.add_theme_constant_override("margin_" + side, 40)
	add_child(frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	frame.add_child(column)
	var bar := HBoxContainer.new()
	column.add_child(bar)
	var title := _label("Credits", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 8)
	scroll.add_child(body)
	for section: Dictionary in Data.table(&"credits").get("sections", []):
		body.add_child(_label(str(section.get("title", "")), 24, Color(1, 0.85, 0.5)))
		for line: Variant in section.get("lines", []):
			body.add_child(_label(str(line), 18))
		body.add_child(_label("", 8))
	body.add_child(_label("Godot Engine licence", 24, Color(1, 0.85, 0.5)))
	body.add_child(_label(Engine.get_license_text(), 14, Color(1, 1, 1, 0.75)))
	var more := Button.new()
	more.name = "Notices"
	more.text = "Show the engine's third-party notices"
	more.custom_minimum_size = Vector2(0, 56)
	more.pressed.connect(func() -> void:
		_notices.visible = not _notices.visible
		more.text = ("Hide" if _notices.visible else "Show") + " the engine's third-party notices")
	body.add_child(more)
	_notices = _label(_third_party(), 12, Color(1, 1, 1, 0.65))
	_notices.visible = false
	body.add_child(_notices)


func on_back() -> void:
	Router.goto_main_menu()


## Every component Godot is built from, with its copyright lines, then each licence's text.
static func _third_party() -> String:
	var parts: PackedStringArray = []
	for component: Dictionary in Engine.get_copyright_info():
		parts.append(str(component["name"]))
		for part: Dictionary in component["parts"]:
			for holder: String in part["copyright"]:
				parts.append("  © " + holder)
			parts.append("  Licence: " + str(part["license"]))
	var licences := Engine.get_license_info()
	for name: String in licences:
		parts.append("\n" + name + "\n" + str(licences[name]))
	return "\n".join(parts)


func _label(text: String, size: int, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	return label

class_name MenuKit
extends RefCounted
## The menus' placeholder chrome (PLAN.md 6.1), shared by the main menu and its screens.

## A big tile: a title over a line of text. Disabled and dimmed when `action` is empty.
static func tile(title: String, note: String, action: Callable, node_name: String, tile_size: Vector2,
		title_size := 32) -> Button:
	var button := Button.new()
	button.name = node_name
	button.theme_type_variation = &"TileButton"
	button.custom_minimum_size = tile_size
	button.disabled = not action.is_valid()
	if action.is_valid():
		button.pressed.connect(action)
	var text := VBoxContainer.new()
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(text)
	var alpha := 1.0 if action.is_valid() else 0.45
	text.add_child(label(title, title_size, Color(1, 1, 1, alpha)))
	text.add_child(label(note, 16, Color(1, 1, 1, 0.6 * alpha)))
	for child: Label in text.get_children():
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		child.add_theme_color_override(&"font_outline_color", UiTheme.TEXT_OUTLINE)
		child.add_theme_constant_override(&"outline_size", UiTheme.OUTLINE_PX)
	return button


## A button named after its text without spaces; disabled when `action` is empty.
static func button(text: String, action: Callable, min_size := Vector2(200, 60), font_size := 22) -> Button:
	var out := Button.new()
	out.name = text.replace(" ", "")
	out.text = text
	out.custom_minimum_size = min_size
	out.add_theme_font_size_override(&"font_size", font_size)
	out.disabled = not action.is_valid()
	if action.is_valid():
		out.pressed.connect(action)
	return out


static func label(text: String, font_size: int, color := Color.WHITE) -> Label:
	var out := Label.new()
	out.text = text
	out.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	out.add_theme_font_size_override(&"font_size", font_size)
	out.add_theme_color_override(&"font_color", color)
	return out

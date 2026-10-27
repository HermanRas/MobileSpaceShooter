class_name UiTheme
extends RefCounted
## The game's one theme (PLAN.md 6.1, A.5), merged into Godot's default theme by Assets so every
## Control has it: the flashy arcade chrome as 9-slice styleboxes. Buttons are gold, `GoButton`
## and `DangerButton` the green and red ones; `ChromePanel`, `HeaderPanel` and `FramePanel` are PanelContainer
## variations for dialogs, title bars and picture cards. Sliders and progress bars use the bar.
##
## Each piece's margins come from data/visuals.json (vis.ui.*). The art is cut at `scale` texture
## px per screen unit and drawn through a size override, so it stays crisp on the phone's 1.7x
## canvas. Until the art is in (Assets.has_real_art) the buttons stay Godot's and the panels the
## flat dark box: the placeholder look.

const FLAT_PANEL := Color(0.05, 0.06, 0.09, 0.96)
const TEXT := Color.WHITE
const TEXT_OUTLINE := Color("#3a1606")
const TEXT_DISABLED := Color(0.78, 0.74, 0.66)
const OUTLINE_PX := 6
## Multiplied over the lit (pressed, toggled-on) button so a chosen tab stands out.
const LIT := Color(1.35, 1.3, 1.15)
## Without the art, the green and red buttons are told apart by their text.
const FALLBACK_TEXT: Dictionary[StringName, Color] = {&"GoButton": Color(0.6, 1.0, 0.55), &"DangerButton": Color(1.0, 0.5, 0.45)}
const BUTTONS: Dictionary[StringName, StringName] = {&"Button": &"gold", &"GoButton": &"go", &"DangerButton": &"danger"}


static func build() -> Theme:
	var theme := Theme.new()
	_panel(theme, &"ChromePanel", &"vis.ui.panel", _flat_panel())
	_panel(theme, &"HeaderPanel", &"vis.ui.header", _flat_panel())
	_panel(theme, &"FramePanel", &"vis.ui.frame", StyleBoxEmpty.new())
	for type: StringName in BUTTONS:
		if type != &"Button":
			theme.set_type_variation(type, &"Button")
		if Assets.has_real_art(StringName("vis.ui.btn_%s_normal" % BUTTONS[type])):
			_buttons(theme, type, BUTTONS[type])
		elif FALLBACK_TEXT.has(type):
			theme.set_color(&"font_color", type, FALLBACK_TEXT[type])
	if Assets.has_real_art(&"vis.ui.bar_track"):
		var track := _box(&"vis.ui.bar_track")
		var fill := _box(&"vis.ui.bar_fill")
		theme.set_stylebox(&"slider", &"HSlider", track)
		theme.set_stylebox(&"grabber_area", &"HSlider", fill)
		theme.set_stylebox(&"grabber_area_highlight", &"HSlider", fill)
		theme.set_stylebox(&"background", &"ProgressBar", track)
		theme.set_stylebox(&"fill", &"ProgressBar", fill)
	if Assets.has_real_art(&"vis.ui.btn_round"):
		var side: float = Assets.meta(&"vis.ui.btn_round").get("grabber_u", 40.0)
		var grabber := _texture(&"vis.ui.btn_round", Vector2(side, side))
		for icon: StringName in [&"grabber", &"grabber_highlight", &"grabber_disabled"]:
			theme.set_icon(icon, &"HSlider", grabber)
	return theme


## A Button type's styles: normal and hover the same (a touch leaves hover stuck), pressed and
## toggled-on lit up, disabled dull, and no focus ring.
static func _buttons(theme: Theme, type: StringName, kind: StringName) -> void:
	var normal := _box(StringName("vis.ui.btn_%s_normal" % kind))
	var lit := _box(StringName("vis.ui.btn_%s_selected" % kind))
	lit.modulate_color = LIT
	theme.set_stylebox(&"normal", type, normal)
	theme.set_stylebox(&"hover", type, normal)
	theme.set_stylebox(&"pressed", type, lit)
	theme.set_stylebox(&"hover_pressed", type, lit)
	theme.set_stylebox(&"disabled", type, _box(StringName("vis.ui.btn_%s_disabled" % kind)))
	theme.set_stylebox(&"focus", type, StyleBoxEmpty.new())
	for colour: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color",
			&"font_hover_pressed_color", &"font_focus_color"]:
		theme.set_color(colour, type, TEXT)
	theme.set_color(&"font_disabled_color", type, TEXT_DISABLED)
	theme.set_color(&"font_outline_color", type, TEXT_OUTLINE)
	theme.set_constant(&"outline_size", type, OUTLINE_PX)


static func _panel(theme: Theme, type: StringName, id: StringName, fallback: StyleBox) -> void:
	theme.set_type_variation(type, &"PanelContainer")
	theme.set_stylebox(&"panel", type, _box(id) if Assets.has_real_art(id) else fallback)


static func _flat_panel() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = FLAT_PANEL
	box.set_corner_radius_all(8)
	box.set_content_margin_all(20)
	return box


static func _box(id: StringName) -> StyleBoxTexture:
	var meta := Assets.meta(id)
	var box := StyleBoxTexture.new()
	box.texture = _texture(id)
	var slice: Array = meta.get("slice", [0, 0, 0, 0])
	var content: Array = meta.get("content", [0, 0, 0, 0])
	for side: int in 4:
		box.set_texture_margin(side as Side, slice[side])
		box.set_content_margin(side as Side, content[side])
	var tile: String = meta.get("tile", "")
	if "x" in tile:
		box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	if "y" in tile:
		box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return box


## The art at its full resolution, reporting `size` (default: its pixels / `scale`) so it draws
## that big in screen units.
static func _texture(id: StringName, size := Vector2.ZERO) -> Texture2D:
	var image := Assets.tex(id).get_image()
	if size == Vector2.ZERO:
		size = Vector2(image.get_size()) / float(Assets.meta(id).get("scale", 1.0))
	var out := ImageTexture.create_from_image(image)
	out.set_size_override(Vector2i(size.round()))
	return out

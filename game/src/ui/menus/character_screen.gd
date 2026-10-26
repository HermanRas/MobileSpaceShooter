extends Control
## Making or editing a pilot (PLAN.md 6.2, D3): a name (LineEdit, so Android brings up its
## keyboard), a male or female base, and a swatch for each of hair, eyes, outfit and trim
## (`data/characters.json`), with a portrait cycling the four moods. Save keeps it and returns
## to the pilots (or to `Profiles.edit_return`, when WaveTime sent a new player here); back (the
## gesture, or Esc) leaves without saving.

const PILOTS := "res://scenes/menu/profiles.tscn"
const SWATCH := 52.0

var _table: Dictionary
var _pilot: ProfileRecord
var _character := {}
var _name := LineEdit.new()
var _portrait := PortraitView.new()
var _mood := Label.new()
var _save: Button
var _swatches := {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_table = Data.table(&"characters")
	_pilot = Profiles.record(Profiles.editing_id)
	_character = _pilot.character.duplicate() if _pilot != null else ProfileRecord.default_character(_table)
	add_child(MenuBackdrop.new())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 40)
	center.add_child(row)

	var left := VBoxContainer.new()
	row.add_child(left)
	_portrait.name = "Portrait"
	_portrait.custom_minimum_size = Vector2(320, 320)
	_portrait.character = _character
	_portrait.cycle_s = 1.2
	left.add_child(_portrait)
	_mood.add_theme_font_size_override(&"font_size", 18)
	_mood.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mood.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.6))
	left.add_child(_mood)

	var right := VBoxContainer.new()
	right.add_theme_constant_override(&"separation", 14)
	row.add_child(right)
	var title := MenuKit.label("Edit pilot" if _pilot != null else "New pilot", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	right.add_child(title)
	_name.name = "PilotName"
	_name.placeholder_text = "Pilot name"
	_name.max_length = int(_table.get("name_max", 16))
	_name.text = _pilot.name if _pilot != null else ""
	_name.custom_minimum_size = Vector2(420, 56)
	_name.add_theme_font_size_override(&"font_size", 24)
	_name.text_changed.connect(func(_text: String) -> void: _update_save())
	right.add_child(_name)

	var bases := HBoxContainer.new()
	bases.add_theme_constant_override(&"separation", 10)
	right.add_child(bases)
	var group := ButtonGroup.new()
	for base: String in _table.get("bases", []):
		var button := MenuKit.button(base.capitalize(), func() -> void: _pick(&"base", base), Vector2(140, 52), 20)
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = _character["base"] == base
		bases.add_child(button)
	for region in ProfileRecord.REGIONS:
		right.add_child(_swatch_row(region))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 12)
	right.add_child(buttons)
	_save = MenuKit.button("Save", _save_pilot, Vector2(160, 60))
	buttons.add_child(_save)
	_update_save()


func _process(_delta: float) -> void:
	_mood.text = String(_portrait.mood).capitalize()


func on_back() -> void:
	_leave()


func _swatch_row(region: String) -> Control:
	var row := HBoxContainer.new()
	row.name = region.capitalize()
	row.add_theme_constant_override(&"separation", 8)
	var label := MenuKit.label(region.capitalize(), 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.custom_minimum_size = Vector2(80, 0)
	row.add_child(label)
	_swatches[region] = []
	for colour: String in _table.get("swatches", {}).get(region, []):
		var swatch := Button.new()
		swatch.name = "%s_%d" % [region, (_swatches[region] as Array).size()]
		swatch.custom_minimum_size = Vector2.ONE * SWATCH
		swatch.set_meta(&"colour", colour)
		swatch.pressed.connect(_pick.bind(StringName(region), colour))
		row.add_child(swatch)
		(_swatches[region] as Array).append(swatch)
	_paint_swatches(region)
	return row


## A swatch is a round button in its colour, ringed in white when it's the one chosen.
func _paint_swatches(region: String) -> void:
	for swatch: Button in _swatches.get(region, []):
		var colour := str(swatch.get_meta(&"colour"))
		var chosen: bool = colour.to_lower() == str(_character.get(region, "")).to_lower()
		for state in [&"normal", &"hover", &"pressed", &"focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(colour)
			style.set_corner_radius_all(int(SWATCH / 2.0))
			style.border_color = Color.WHITE if chosen else Color(1, 1, 1, 0.2)
			style.set_border_width_all(4 if chosen else 1)
			swatch.add_theme_stylebox_override(state, style)


func _pick(region: StringName, value: String) -> void:
	_character[String(region)] = value
	_portrait.character = _character.duplicate()
	_paint_swatches(String(region))


func _update_save() -> void:
	_save.disabled = ProfileRecord.clean_name(_name.text, _name.max_length).is_empty()


func _save_pilot() -> void:
	var pilot := _pilot if _pilot != null else Profiles.create(_name.text)
	pilot.name = ProfileRecord.clean_name(_name.text, _name.max_length)
	pilot.character = _character.duplicate()
	Profiles.save(pilot)
	_leave()


func _leave() -> void:
	var back := Profiles.edit_return if Profiles.edit_return != "" else PILOTS
	Profiles.edit_return = ""
	Router.goto(back)

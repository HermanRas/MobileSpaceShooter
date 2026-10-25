class_name PaintPanel
extends PanelContainer
## The paint panel (Phase 2.4): 12 swatches, recent colours, a full HSV picker, and what a tap
## paints (one tile, every tile of its type, or the whole ship).
##
## The panel only chooses; the hangar applies the colour when a tile is tapped. Recent colours
## are device-wide and kept in Settings.

signal ship_paint_requested(color: Color)

enum Scope { TILE, TYPE, SHIP }

const SWATCHES: Array[Color] = [
	Color("#e8e8e8"), Color("#9aa3ad"), Color("#4a5059"), Color("#1c1e22"),
	Color("#c0392b"), Color("#e67e22"), Color("#f1c40f"), Color("#27ae60"),
	Color("#16a085"), Color("#2e86de"), Color("#8e44ad"), Color("#e84393"),
]
const RECENT_MAX := 6
const SWATCH_SIZE := Vector2(52, 52)

var color: Color = SWATCHES[0]
var scope: Scope = Scope.TILE

var _current := ColorRect.new()
var _recent_row := HBoxContainer.new()
var _picker_popup := PopupPanel.new()
var _picker := ColorPicker.new()


func _ready() -> void:
	var column := VBoxContainer.new()
	add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	_current.custom_minimum_size = Vector2(52, 52)
	_current.color = color
	header.add_child(_current)
	var title := Label.new()
	title.text = "Paint: tap a tile"
	header.add_child(title)

	var scopes := HBoxContainer.new()
	column.add_child(scopes)
	var group := ButtonGroup.new()
	for entry: Array in [["Tile", Scope.TILE], ["Type", Scope.TYPE], ["Ship", Scope.SHIP]]:
		var button := Button.new()
		button.text = entry[0]
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = entry[1] == scope
		button.custom_minimum_size = Vector2(80, 48)
		button.toggled.connect(func(on: bool) -> void:
			if on:
				scope = entry[1])
		scopes.add_child(button)

	var grid := GridContainer.new()
	grid.columns = 4
	column.add_child(grid)
	for swatch_color in SWATCHES:
		grid.add_child(_swatch(swatch_color))

	column.add_child(_recent_row)
	_refresh_recent()

	var actions := HBoxContainer.new()
	column.add_child(actions)
	var custom := Button.new()
	custom.text = "Custom…"
	custom.custom_minimum_size = Vector2(120, 48)
	custom.pressed.connect(func() -> void:
		_picker.color = color
		_picker_popup.popup_centered())
	actions.add_child(custom)
	var whole := Button.new()
	whole.text = "Paint ship"
	whole.custom_minimum_size = Vector2(120, 48)
	whole.pressed.connect(func() -> void:
		_remember(color)
		ship_paint_requested.emit(color))
	actions.add_child(whole)

	_picker.edit_alpha = false
	_picker.picker_shape = ColorPicker.SHAPE_HSV_RECTANGLE
	_picker.color_changed.connect(choose)
	_picker_popup.add_child(_picker)
	add_child(_picker_popup)


## Sets the active colour (from a swatch, a recent colour or the picker).
func choose(new_color: Color) -> void:
	color = Color(new_color, 1.0)
	_current.color = color


## Records `used` at the front of the recent colours. The hangar calls this when paint lands.
func remember(used: Color) -> void:
	_remember(used)


func _remember(used: Color) -> void:
	var html := used.to_html(false)
	var recent: Array = Settings.get_value(&"recent_colors").duplicate()
	recent.erase(html)
	recent.push_front(html)
	Settings.set_value(&"recent_colors", recent.slice(0, RECENT_MAX))
	_refresh_recent()


func _refresh_recent() -> void:
	for child in _recent_row.get_children():
		child.queue_free()
	for html: String in Settings.get_value(&"recent_colors"):
		if Color.html_is_valid(html):
			_recent_row.add_child(_swatch(Color.html(html)))


func _swatch(swatch_color: Color) -> Control:
	var button := Button.new()
	button.custom_minimum_size = SWATCH_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = swatch_color
	style.set_corner_radius_all(6)
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		button.add_theme_stylebox_override(state, style)
	button.tooltip_text = swatch_color.to_html(false)
	button.pressed.connect(choose.bind(swatch_color))
	return button

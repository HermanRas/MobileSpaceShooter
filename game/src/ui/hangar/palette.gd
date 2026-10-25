class_name HangarPalette
extends PanelContainer
## The tile palette (Phase 2.2): type tabs, a row of shapes to drag out, and the S/M/L size.
##
## Pressing a shape emits `drag_started`; from then on the hangar controller follows the finger
## and handles the release, so the palette doesn't need to know where the tile lands.
##
## The tabs sit under the shapes on purpose. Android keeps the bottom strip of the screen for
## its home gesture even in immersive mode (130 px on the reference phone, ~78 canvas px), and a
## drag that starts there sends the game to the background. Taps there are fine, so the
## tap-only tabs fill that strip and every drag starts above it.

signal drag_started(type: StringName, shape: StringName, size: StringName)

const TYPES: Array[StringName] = [&"hull", &"armor", &"shield", &"hardpoint"]
const TYPE_COLORS := {
	&"hull": Color(0.55, 0.59, 0.63), &"armor": Color(0.45, 0.38, 0.27),
	&"shield": Color(0.25, 0.5, 0.78), &"hardpoint": Color(0.24, 0.26, 0.29),
}
const BUTTON := Vector2(76, 76)
## At least the phone's bottom gesture strip, in canvas pixels (see the note above).
const GESTURE_STRIP := 80.0

var shapes: ShapeLib
var type: StringName = &"hull"
var tile_size: StringName = &"L"

var _shape_row := HBoxContainer.new()


func _ready() -> void:
	var column := VBoxContainer.new()
	add_child(column)
	column.add_child(_shape_row)
	var tabs := HBoxContainer.new()
	column.add_child(tabs)
	var type_group := ButtonGroup.new()
	for tile_type in TYPES:
		var tab := Button.new()
		tab.text = String(tile_type).capitalize()
		tab.toggle_mode = true
		tab.button_group = type_group
		tab.button_pressed = tile_type == type
		tab.custom_minimum_size = Vector2(120, GESTURE_STRIP)
		tab.toggled.connect(func(on: bool) -> void:
			if on:
				type = tile_type
				_refresh_shapes())
		tabs.add_child(tab)
	tabs.add_child(_spacer())
	var size_group := ButtonGroup.new()
	for size_code: StringName in [&"S", &"M", &"L"]:
		var size_button := Button.new()
		size_button.text = String(size_code)
		size_button.toggle_mode = true
		size_button.button_group = size_group
		size_button.button_pressed = size_code == tile_size
		size_button.custom_minimum_size = Vector2(72, GESTURE_STRIP)
		size_button.toggled.connect(func(on: bool) -> void:
			if on:
				tile_size = size_code
				_refresh_shapes())
		tabs.add_child(size_button)
	_refresh_shapes()


func _refresh_shapes() -> void:
	for child in _shape_row.get_children():
		child.queue_free()
	for shape_id in shapes.shape_ids():
		var swatch := _ShapeSwatch.new()
		swatch.custom_minimum_size = BUTTON
		swatch.polygon = shapes.polygon(shape_id, &"L", 0)
		swatch.fill = TYPE_COLORS.get(type, Color.GRAY)
		swatch.scale_hint = {&"S": 0.45, &"M": 0.7, &"L": 1.0}[tile_size]
		swatch.tooltip_text = String(shape_id)
		swatch.gui_input.connect(func(event: InputEvent) -> void:
			if _is_press(event):
				drag_started.emit(type, shape_id, tile_size)
				accept_event())
		_shape_row.add_child(swatch)


static func _is_press(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT


func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer


## A palette cell that draws its shape.
class _ShapeSwatch extends PanelContainer:
	var polygon: PackedVector2Array
	var fill: Color
	var scale_hint: float = 1.0

	func _draw() -> void:
		var extent := 0.0
		for p in polygon:
			extent = maxf(extent, maxf(absf(p.x), absf(p.y)))
		var s := (minf(size.x, size.y) * 0.4 / extent) * scale_hint
		var center := size * 0.5
		var points := PackedVector2Array()
		for p in polygon:
			points.append(center + p * s)
		draw_colored_polygon(points, fill)
		draw_polyline(points + PackedVector2Array([points[0]]), Color(0, 0, 0, 0.8), 2.0, true)

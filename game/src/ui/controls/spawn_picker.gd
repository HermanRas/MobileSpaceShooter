class_name SpawnPicker
extends PanelContainer
## The flight sandbox's Spawn list (owner, 2026-10-26): a card per ship, with its picture and
## name, in sections (practice targets, enemies, the carrier, the player's own ships). A tap emits
## `picked`; the sandbox spawns it. It runs while the tree is paused (process mode ALWAYS); the
## sandbox pauses and resumes.

signal picked(kind: StringName, id: String)
signal closed

const CARD := Vector2(170, 160)
const MARGIN := 24.0

var _sections := VBoxContainer.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = MARGIN
	offset_top = MARGIN
	offset_right = -MARGIN
	offset_bottom = -MARGIN
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.05, 0.06, 0.09, 0.96)
	background.set_content_margin_all(16)
	background.set_corner_radius_all(8)
	add_theme_stylebox_override(&"panel", background)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 10)
	add_child(column)
	var bar := HBoxContainer.new()
	column.add_child(bar)
	var title := Label.new()
	title.text = "Spawn"
	title.add_theme_font_size_override(&"font_size", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	var back := Button.new()
	back.text = "Close"
	back.custom_minimum_size = Vector2(132, 56)
	back.pressed.connect(func() -> void: closed.emit())
	bar.add_child(back)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sections.add_theme_constant_override(&"separation", 12)
	scroll.add_child(_sections)


## Shows `sections`: [{"title", "cards": [{"kind", "id", "name", "bp", "note" (optional)}]}], or
## a section of plain `"buttons"` ([{"kind", "id", "name"}]). An empty section is left out.
func open(sections: Array[Dictionary], placement: Placement) -> void:
	for child in _sections.get_children():
		_sections.remove_child(child)
		child.queue_free()
	for section in sections:
		var cards: Array = section.get("cards", [])
		var buttons: Array = section.get("buttons", [])
		if cards.is_empty() and buttons.is_empty():
			continue
		var heading := Label.new()
		heading.text = section["title"]
		heading.add_theme_font_size_override(&"font_size", 20)
		heading.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.6))
		_sections.add_child(heading)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override(&"h_separation", 10)
		flow.add_theme_constant_override(&"v_separation", 10)
		_sections.add_child(flow)
		for card: Dictionary in cards:
			flow.add_child(_card(card, placement))
		for entry: Dictionary in buttons:
			var button := Button.new()
			button.name = "%s_%s" % [entry["kind"], entry["id"]]
			button.text = entry["name"]
			button.custom_minimum_size = Vector2(150, 64)
			button.pressed.connect(func() -> void: picked.emit(entry["kind"], entry["id"]))
			flow.add_child(button)


func _card(card: Dictionary, placement: Placement) -> Button:
	var button := Button.new()
	button.name = "%s_%s" % [card["kind"], card["id"]]
	button.custom_minimum_size = CARD
	button.pressed.connect(func() -> void: picked.emit(card["kind"], card["id"]))
	var picture := _Picture.new()
	picture.bp = card["bp"]
	picture.placement = placement
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	picture.offset_top = 8
	picture.offset_bottom = CARD.y - 44
	button.add_child(picture)
	var label := Label.new()
	label.text = card["name"] if not card.has("note") else "%s\n%s" % [card["name"], card["note"]]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", 14)
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -42
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	return button


## A ship drawn as the hangar draws it, scaled to fit the card.
class _Picture extends Control:
	var bp: Blueprint
	var placement: Placement
	var _view: ShipView

	func _ready() -> void:
		clip_contents = true
		_view = ShipView.new()
		_view.placement = placement
		_view.area_u = 0.0
		add_child(_view)
		_view.show_blueprint(bp, placement.analyze(bp))
		_view.set_guns(GunLayout.compute(bp, placement))
		resized.connect(_fit)
		_fit()

	func _fit() -> void:
		var low := Vector2.INF
		var high := -Vector2.INF
		for tile in bp.tiles:
			for p in placement.tile_polygon(tile):
				low = low.min(p)
				high = high.max(p)
		var extent := (high - low) * ShipMesh.PX_PER_U
		var fit := minf(size.x / maxf(extent.x, 1.0), size.y / maxf(extent.y, 1.0)) * 0.9
		_view.scale = Vector2(fit, fit)
		_view.position = size * 0.5 - (low + high) * 0.5 * ShipMesh.PX_PER_U * fit

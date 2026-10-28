class_name ShipShopPanel
extends PanelContainer
## The stocked hangar's ship shop (PLAN.md 7.3): every published library ship, with its picture,
## its author and what building it from nothing costs. Selecting one shows what buying it costs
## now, after the trade-in of the pilot's ship; Buy swaps the ship for it.
##
## Like the market, it only asks: the hangar quotes (`show_quote`) and buys through HangarEditor.

signal selected(id: String)
signal buy_requested(id: String)

const CARD := Vector2(220, 300)
const PRICE := Color(1, 0.85, 0.5)
const SHORT := Color(1.0, 0.45, 0.45)

var _grid := GridContainer.new()
var _empty := Label.new()
var _quote := Label.new()
var _buy: Button
var _selected_id := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme_type_variation = &"ChromePanel"
	var column := VBoxContainer.new()
	add_child(column)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override(&"separation", 16)
	column.add_child(bar)
	var title := Label.new()
	title.text = "Ships for sale"
	title.add_theme_font_size_override(&"font_size", 28)
	bar.add_child(title)
	_quote.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quote.add_theme_font_size_override(&"font_size", 20)
	_quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quote.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bar.add_child(_quote)
	_buy = Button.new()
	_buy.name = "Buy"
	_buy.text = "Buy"
	_buy.custom_minimum_size = Vector2(130, 56)
	_buy.theme_type_variation = &"GoButton"
	_buy.pressed.connect(func() -> void: buy_requested.emit(_selected_id))
	bar.add_child(_buy)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_grid.columns = 5
	_grid.add_theme_constant_override(&"h_separation", 12)
	_grid.add_theme_constant_override(&"v_separation", 12)
	scroll.add_child(_grid)
	_empty.text = "Nothing for sale yet. Ships published from the Creative library appear here."
	_empty.add_theme_font_size_override(&"font_size", 20)
	_empty.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.6))
	column.add_child(_empty)


## Lists `ships` (BlueprintLibrary.for_sale() entries); `thumbnail` is a Callable(id) -> path.
func show_ships(ships: Array[Dictionary], thumbnail: Callable) -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	if not ships.any(func(entry: Dictionary) -> bool: return entry["id"] == _selected_id):
		_selected_id = ""
	for entry in ships:
		_grid.add_child(_card(entry, thumbnail.call(entry["id"])))
	_empty.visible = ships.is_empty()
	if _selected_id.is_empty():
		show_quote("Pick a ship", false)


## The line beside the title: what buying the selected ship costs now, or why it can't be bought.
func show_quote(text: String, can_buy: bool) -> void:
	_quote.text = text
	_quote.add_theme_color_override(&"font_color", PRICE if can_buy or _selected_id.is_empty() else SHORT)
	_buy.disabled = not can_buy


func selected_id() -> String:
	return _selected_id


func _card(entry: Dictionary, thumbnail_path: String) -> Control:
	var card := Button.new()
	card.name = "ship_" + str(entry["id"])
	card.custom_minimum_size = CARD
	card.toggle_mode = true
	card.button_pressed = entry["id"] == _selected_id
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var picture := TextureRect.new()
	picture.custom_minimum_size = Vector2(CARD.x, CARD.x - 70)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if FileAccess.file_exists(thumbnail_path):
		picture.texture = ImageTexture.create_from_image(Image.load_from_file(thumbnail_path))
	column.add_child(picture)
	column.add_child(_line("%s  (%d)" % [entry["name"], entry["tiles"]], 18, Color.WHITE))
	if entry["author"] != "":
		column.add_child(_line("by %s" % entry["author"], 14, Color(1, 1, 1, 0.6)))
	column.add_child(_line(StatsPanel.format_cost(entry["cost"]), 14, PRICE))
	card.pressed.connect(func() -> void:
		_selected_id = entry["id"]
		for other in _grid.get_children():
			(other as Button).button_pressed = other == card
		selected.emit(_selected_id))
	return card


func _line(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", UiTheme.TEXT_OUTLINE)
	label.add_theme_constant_override(&"outline_size", UiTheme.OUTLINE_PX)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

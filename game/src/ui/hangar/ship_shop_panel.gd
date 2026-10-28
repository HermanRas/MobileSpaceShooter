class_name ShipShopPanel
extends PanelContainer
## The stocked hangar's Ships screen (PLAN.md 7.3): **Your ships**, the one being flown and the
## ones parked, above **For sale**, every published library ship with its author and what building
## it costs. Selecting a card shows a line about it and the one thing it offers: Buy, Fly this, or
## Sell ship (only while another is owned; owner, 2026-10-28).
##
## Like the market, it only asks: cards are keyed "flying", "parked:<index>" or "sale:<library id>",
## and the hangar says what each offers (`show_offer`) and does it.

signal selected(key: String)
signal action_requested(key: String)

const CARD := Vector2(220, 300)
const PRICE := Color(1, 0.85, 0.5)
const SHORT := Color(1.0, 0.45, 0.45)

var _owned := GridContainer.new()
var _for_sale := GridContainer.new()
var _empty := Label.new()
var _offer := Label.new()
var _action: Button
var _selected_key := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme_type_variation = &"ChromePanel"
	var column := VBoxContainer.new()
	add_child(column)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override(&"separation", 16)
	column.add_child(bar)
	var title := Label.new()
	title.text = "Ships"
	title.add_theme_font_size_override(&"font_size", 28)
	bar.add_child(title)
	_offer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_offer.add_theme_font_size_override(&"font_size", 20)
	_offer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_offer.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bar.add_child(_offer)
	_action = Button.new()
	_action.name = "Action"
	_action.custom_minimum_size = Vector2(150, 56)
	_action.theme_type_variation = &"GoButton"
	_action.pressed.connect(func() -> void: action_requested.emit(_selected_key))
	bar.add_child(_action)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var sections := VBoxContainer.new()
	sections.add_theme_constant_override(&"separation", 10)
	scroll.add_child(sections)
	sections.add_child(_heading("Your ships"))
	sections.add_child(_owned)
	sections.add_child(_heading("For sale"))
	sections.add_child(_for_sale)
	_empty.text = "Nothing for sale yet. Ships published from the Creative library appear here."
	_empty.add_theme_font_size_override(&"font_size", 20)
	_empty.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.6))
	sections.add_child(_empty)
	for grid in [_owned, _for_sale]:
		grid.columns = 5
		grid.add_theme_constant_override(&"h_separation", 12)
		grid.add_theme_constant_override(&"v_separation", 12)


## Lists the cards: `owned` as {"key", "name", "tiles", "thumb", "note"}, `for_sale` as
## BlueprintLibrary.for_sale() entries plus "thumb".
func show_ships(owned: Array[Dictionary], for_sale: Array[Dictionary]) -> void:
	for grid in [_owned, _for_sale]:
		for child in grid.get_children():
			grid.remove_child(child)
			child.queue_free()
	var keys: Array[String] = []
	for entry in owned:
		keys.append(entry["key"])
		_owned.add_child(_card(entry["key"], entry, [[entry["note"], 16, PRICE]]))
	for entry in for_sale:
		var key := "sale:" + str(entry["id"])
		keys.append(key)
		var lines := [[StatsPanel.format_cost(entry["cost"]), 14, PRICE]]
		if entry["author"] != "":
			lines.push_front(["by %s" % entry["author"], 14, Color(1, 1, 1, 0.6)])
		_for_sale.add_child(_card(key, entry, lines))
	_empty.visible = for_sale.is_empty()
	if not keys.has(_selected_key):
		_selected_key = ""
		show_offer("Pick a ship", "", true)


## The line beside the title for the selected card, and its button (`action` "" hides it).
func show_offer(text: String, action: String, can: bool) -> void:
	_offer.text = text
	_offer.add_theme_color_override(&"font_color", PRICE if can else SHORT)
	_action.text = action
	_action.visible = not action.is_empty()
	_action.disabled = not can


func selected_key() -> String:
	return _selected_key


func _card(key: String, entry: Dictionary, lines: Array) -> Control:
	var card := Button.new()
	card.name = key.replace(":", "_")
	card.custom_minimum_size = CARD
	card.toggle_mode = true
	card.button_pressed = key == _selected_key
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var picture := TextureRect.new()
	picture.custom_minimum_size = Vector2(CARD.x, CARD.x - 70)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if FileAccess.file_exists(entry["thumb"]):
		picture.texture = ImageTexture.create_from_image(Image.load_from_file(entry["thumb"]))
	column.add_child(picture)
	column.add_child(_line("%s  (%d)" % [entry["name"], entry["tiles"]], 18, Color.WHITE))
	for line: Array in lines:
		column.add_child(_line(line[0], line[1], line[2]))
	card.pressed.connect(func() -> void:
		_selected_key = key
		for grid in [_owned, _for_sale]:
			for other in grid.get_children():
				(other as Button).button_pressed = other == card
		selected.emit(key))
	return card


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 22)
	label.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.75))
	return label


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

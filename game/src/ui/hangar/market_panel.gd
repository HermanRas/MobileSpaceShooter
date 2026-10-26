class_name MarketPanel
extends PanelContainer
## The materials market (PLAN.md 4.6, 4.8c): buy and sell Hull, Alloy, Crystal and Tech for GC,
## in lots of 10 and 100. The stocked hangar opens it from its wallet. It only asks: the hangar
## trades through HangarEditor (so a trade is an undo step) and calls `show_market` again.

signal trade_requested(material: StringName, amount: int)

const LOTS: Array[int] = [10, 100]

var _column := VBoxContainer.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.05, 0.06, 0.09, 0.96)
	background.set_content_margin_all(20)
	background.set_corner_radius_all(8)
	add_theme_stylebox_override(&"panel", background)
	_column.add_theme_constant_override(&"separation", 12)
	add_child(_column)


## Lists every material the market trades, what the wallet holds, and the prices.
func show_market(stock: Inventory, economy: Economy) -> void:
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	var title := Label.new()
	title.text = "Market  ·  %d GC" % stock.amount(Inventory.GC)
	title.add_theme_font_size_override(&"font_size", 26)
	_column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 3 + LOTS.size() * 2
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 8)
	_column.add_child(grid)
	for heading in ["", "Have", "GC each"]:
		grid.add_child(_label(heading, 16, Color(1, 1, 1, 0.55)))
	for lot in LOTS:
		grid.add_child(_label("", 16, Color.WHITE))
	for lot in LOTS:
		grid.add_child(_label("", 16, Color.WHITE))
	for material: StringName in Inventory.MATERIALS:
		if not economy.market.has(material):
			continue
		var prices: Dictionary = economy.market[material]
		grid.add_child(_label(String(material).capitalize(), 22, Color.WHITE))
		grid.add_child(_label("%d" % stock.amount(material), 22, Color(1, 0.85, 0.5)))
		grid.add_child(_label("buy %d · sell %d" % [prices["buy"], prices["sell"]], 18, Color(1, 1, 1, 0.75)))
		for lot in LOTS:
			var buy := _button("Buy %d" % lot, func() -> void: trade_requested.emit(material, lot))
			buy.name = "buy_%s_%d" % [material, lot]
			buy.disabled = stock.amount(Inventory.GC) < int(prices["buy"]) * lot
			grid.add_child(buy)
		for lot in LOTS:
			var sell := _button("Sell %d" % lot, func() -> void: trade_requested.emit(material, -lot))
			sell.name = "sell_%s_%d" % [material, lot]
			sell.disabled = stock.amount(material) < lot
			grid.add_child(sell)


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(110, 56)
	button.pressed.connect(action)
	return button


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

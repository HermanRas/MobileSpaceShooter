class_name StatsPanel
extends PanelContainer
## The hangar's live stats (Phase 2.5): totals from ShipStats, what the carried tile would add,
## and the blueprint's problems.
##
## The "+50 HP" preview comes from the tile definition alone, not a full recompute, so it's
## cheap enough to refresh while a tile is being dragged.

const GOOD := Color(0.45, 1.0, 0.55)
const BAD := Color(1.0, 0.45, 0.45)
const DIM := Color(1, 1, 1, 0.55)
const MAX_PROBLEMS := 3

var _rows := {}  # key -> [value Label, delta Label]
var _problems := VBoxContainer.new()


func _ready() -> void:
	var column := VBoxContainer.new()
	add_child(column)
	var grid := GridContainer.new()
	grid.columns = 3
	column.add_child(grid)
	for entry: Array in [["tiles", "Tiles"], ["hp", "HP"], ["armor", "Armor"], ["shield", "Shield"],
			["mass", "Mass"], ["accel", "Accel"], ["cost", "Cost"]]:
		var name_label := _label(entry[1], DIM)
		var value := _label("", Color.WHITE)
		var delta := _label("", GOOD)
		grid.add_child(name_label)
		grid.add_child(value)
		grid.add_child(delta)
		_rows[entry[0]] = [value, delta]
	column.add_child(_problems)


func show_stats(stats: ShipStats, problems: Array[Placement.Problem], max_tiles: int) -> void:
	_set_row(&"tiles", "%d / %d" % [stats.tile_count, max_tiles])
	_set_row(&"hp", "%d" % stats.hp)
	_set_row(&"armor", "%.1f" % stats.armor_avg)
	_set_row(&"shield", "%d  +%.1f/s" % [stats.shield_cap, stats.shield_regen] if stats.shield_cap > 0.0 else "none")
	_set_row(&"mass", "%.2f" % stats.mass)
	# Thrusters arrive in Phase 3.2; until then there's nothing to accelerate with.
	_set_row(&"accel", "no thrusters")
	_set_row(&"cost", format_cost(stats.cost))
	for child in _problems.get_children():
		child.queue_free()
	for i in mini(problems.size(), MAX_PROBLEMS):
		_problems.add_child(_label(problems[i].message, BAD))
	if problems.size() > MAX_PROBLEMS:
		_problems.add_child(_label("…and %d more" % (problems.size() - MAX_PROBLEMS), BAD))


## Shows what one tile of `def` at `size` would add, or clears the preview when `def` is null.
func show_delta(def: TileDef, size: StringName) -> void:
	for key: StringName in _rows:
		(_rows[key][1] as Label).text = ""
	if def == null:
		return
	var stats := def.stats(size)
	_delta(&"tiles", "+1")
	_delta(&"hp", "+%d" % stats[&"hp"])
	if stats[&"shield_cap"] > 0.0:
		_delta(&"shield", "+%d" % stats[&"shield_cap"])
	_delta(&"mass", "+%.2f" % stats[&"mass"], BAD)
	var cost := def.cost(size)
	if not cost.is_empty():
		_delta(&"cost", "+" + format_cost(cost), BAD)


static func format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return "free"
	var parts: PackedStringArray = []
	for material: StringName in [&"hull", &"alloy", &"crystal", &"tech"]:
		if cost.has(material):
			parts.append("%d %s" % [cost[material], material])
	return ", ".join(parts)


func _set_row(key: StringName, text: String) -> void:
	(_rows[key][0] as Label).text = text


func _delta(key: StringName, text: String, color: Color = GOOD) -> void:
	var label: Label = _rows[key][1]
	label.text = text
	label.add_theme_color_override(&"font_color", color)


func _label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_font_size_override(&"font_size", 18)
	return label

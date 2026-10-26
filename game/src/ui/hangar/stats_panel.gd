class_name StatsPanel
extends PanelContainer
## The hangar's live stats (Phase 2.5): totals from ShipStats, what the carried tile would add,
## the blueprint's problems (red, they stop it flying) and the flight warnings (amber, they
## never do; PLAN.md 4.10).
##
## The "+50 HP" preview comes from the tile definition alone, not a full recompute, so it's
## cheap enough to refresh while a tile is being dragged.

const GOOD := Color(0.45, 1.0, 0.55)
const BAD := Color(1.0, 0.45, 0.45)
const WARN := Color(1.0, 0.75, 0.3)
const DIM := Color(1, 1, 1, 0.55)
const MAX_PROBLEMS := 3

var _rows := {}  # key -> [value Label, delta Label]
var _problems := VBoxContainer.new()
var _part := Label.new()


func _ready() -> void:
	# Display only: touches go through to the ship underneath, so it can be panned there.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var grid := GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = 3
	column.add_child(grid)
	for entry: Array in [["tiles", "Tiles"], ["hp", "HP"], ["armor", "Armor"], ["shield", "Shield"],
			["mass", "Mass"], ["accel", "Accel"], ["guns", "Guns"], ["cost", "Cost"]]:
		var name_label := _label(entry[1], DIM)
		var value := _label("", Color.WHITE)
		var delta := _label("", GOOD)
		grid.add_child(name_label)
		grid.add_child(value)
		grid.add_child(delta)
		_rows[entry[0]] = [value, delta]
	_part.add_theme_color_override(&"font_color", Color(0.6, 0.85, 1.0))
	_part.add_theme_font_size_override(&"font_size", 18)
	_part.visible = false
	column.add_child(_part)
	_problems.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_problems)


func show_stats(stats: ShipStats, problems: Array[Placement.Problem], max_tiles: int,
		envelope: ThrustEnvelope = null, guns: GunLayout = null) -> void:
	_set_row(&"tiles", "%d / %d" % [stats.tile_count, max_tiles])
	_set_row(&"hp", "%d" % stats.hp)
	_set_row(&"armor", "%.1f" % stats.armor_avg)
	_set_row(&"shield", "%d  +%.1f/s" % [stats.shield_cap, stats.shield_regen] if stats.shield_cap > 0.0 else "none")
	_set_row(&"mass", "%.2f" % stats.mass)
	if envelope == null or envelope.thrusters.is_empty():
		_set_row(&"accel", "no thrusters")
	else:
		_set_row(&"accel", "%.1f U/s² forward, %.1f back" % [envelope.accel(ThrustEnvelope.FORWARD),
				envelope.accel(ThrustEnvelope.BACK)])
	if guns == null or guns.guns.is_empty():
		_set_row(&"guns", "none")
	else:
		_set_row(&"guns", "%d (%d manual), %d dmg/s" % [guns.guns.size(), guns.manual_count(), roundi(guns.dps())])
	_set_row(&"cost", format_cost(stats.cost))
	for child in _problems.get_children():
		child.queue_free()
	for i in mini(problems.size(), MAX_PROBLEMS):
		_problems.add_child(_label(problems[i].message, BAD))
	if problems.size() > MAX_PROBLEMS:
		_problems.add_child(_label("…and %d more" % (problems.size() - MAX_PROBLEMS), BAD))
	var warnings: Array[Dictionary] = []
	if envelope != null:
		warnings.append_array(envelope.warnings)
	if guns != null:
		warnings.append_array(guns.warnings)
	for warning in warnings:
		_problems.add_child(_label("• " + str(warning["text"]), WARN))


## A line about the selected gun or thruster (its level, XP, what it sells for), or none for "".
func show_part(text: String) -> void:
	_part.text = text
	_part.visible = not text.is_empty()


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

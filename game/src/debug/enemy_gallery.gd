extends Node2D
## Phase 5.1 debug gallery: every ship on the roster (the carrier, an ally, among them), a row per
## tier (its boss at the end),
## drawn as the hangar draws them, with tier, role, behaviour, levels and firepower. Drag to
## look around; Back returns to the menu.

const CELL := Vector2(420, 400)
const SHIP_FIT_PX := 300.0
const PX := ShipMesh.PX_PER_U

var _camera := Camera2D.new()
var _dragging := false


func _ready() -> void:
	var tiles_table := Data.table(&"tiles")
	var placement := Placement.create(ShapeLib.from_table(Data.table(&"shapes")), TileLib.from_table(tiles_table), tiles_table)
	placement.thrusters = ThrusterLib.from_table(Data.table(&"thrusters"))
	placement.weapons = WeaponLib.from_table(Data.table(&"weapons"), Data.table(&"weapon_xp"))
	var roster := EnemyRoster.from_table(Data.table(&"enemies"), Data.json_dir("enemies"))
	for error in roster.errors:
		push_error("enemy_gallery: " + error)
	for tier in range(1, 5):
		var row: Array[EnemyRoster.Entry] = []
		for entry in roster.entries:
			if entry.tier == tier and not entry.boss:
				row.append(entry)
		if roster.boss(tier) != null:
			row.append(roster.boss(tier))
		for column in row.size():
			_card(row[column], placement, Vector2(column, tier - 1) * CELL + CELL * 0.5)
	_camera.position = Vector2(CELL.x * 2.5, CELL.y * 1.0)
	_camera.zoom = Vector2(0.75, 0.75)
	add_child(_camera)
	_camera.make_current()
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(132, 56)
	back.position = Vector2(16, 16)
	back.pressed.connect(on_back)
	var ui := CanvasLayer.new()
	ui.add_child(back)
	add_child(ui)


func _card(entry: EnemyRoster.Entry, placement: Placement, center: Vector2) -> void:
	var bp := entry.blueprint
	var view := ShipView.new()
	view.placement = placement
	view.area_u = 0.0
	add_child(view)
	view.show_blueprint(bp, placement.analyze(bp))
	var guns := GunLayout.compute(bp, placement)
	view.set_guns(guns)
	var low := Vector2.INF
	var high := -Vector2.INF
	for tile in bp.tiles:
		for p in placement.tile_polygon(tile):
			low = low.min(p)
			high = high.max(p)
	var extent := maxf(high.x - low.x, high.y - low.y) * PX
	var fit := minf(1.0, SHIP_FIT_PX / maxf(extent, 1.0))
	view.scale = Vector2(fit, fit)
	view.position = center + Vector2(0, -30) - (low + high) * 0.5 * PX * fit
	var stats := ShipStats.compute(bp, placement)
	var envelope := ThrustEnvelope.compute(bp, placement, stats)
	var label := Label.new()
	label.text = "%s%s\nT%d %s · %s · L%d-%d\n%d tiles · %d guns %d dmg/s · %.1f U/s²" % [
		bp.name, "  (BOSS)" if entry.boss else "  (ALLY)" if entry.ally else "", entry.tier, entry.role, entry.behaviour, entry.min_level, entry.max_level,
		bp.tiles.size(), guns.guns.size(), roundi(guns.dps()), envelope.accel(ThrustEnvelope.FORWARD)]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", 20)
	label.add_theme_color_override(&"font_color", Color(1, 0.8, 0.45) if entry.boss else Color(0.55, 0.85, 1.0) if entry.ally else Color.WHITE)
	label.size = Vector2(CELL.x, 90)
	label.position = center + Vector2(-CELL.x * 0.5, CELL.y * 0.5 - 100)
	add_child(label)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		_camera.position -= (event as InputEventScreenDrag).relative / _camera.zoom
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = (event as InputEventMouseButton).pressed
	elif event is InputEventMouseMotion and _dragging:
		_camera.position -= (event as InputEventMouseMotion).relative / _camera.zoom


func on_back() -> void:
	Router.goto_main_menu()


## `tools/preview.sh` hook: --row=<0-3> centres that tier's row.
func preview_setup(args: Dictionary) -> void:
	if args.has("row"):
		_camera.position.y = CELL.y * (float(args["row"]) + 0.5)

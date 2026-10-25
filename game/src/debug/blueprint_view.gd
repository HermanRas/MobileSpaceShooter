extends Node2D
## Phase 1.6 debug view: draws every blueprint in `data/blueprints/` with flat paint.
##
## White dots are free ports. Shared ports aren't drawn, so any seam with dots on it isn't
## really connected. Tiles with a validation problem are hatched red. The green arrow is the
## ship's forward (+x from the core), and the yellow cross is its centre of mass.

const PX_PER_U := 64.0
const COLUMN_PX := 500.0
const OUTLINE := Color(0.05, 0.05, 0.08)
const PORT := Color(1, 1, 1, 0.85)
const PROBLEM := Color(1, 0.15, 0.15, 0.55)
const FORWARD := Color(0.2, 0.85, 0.3)
const COM := Color(1, 0.85, 0.2)

var _placement: Placement
var _ships: Array = []  # [Blueprint, ShipStats, problem tile ids, Vector2 origin px]


func _ready() -> void:
	var tiles_table := Data.table(&"tiles")
	_placement = Placement.create(ShapeLib.from_table(Data.table(&"shapes")),
			TileLib.from_table(tiles_table), tiles_table)
	var files := Data.json_dir("blueprints")
	var column := 0
	for file_name: String in files:
		var errors: PackedStringArray = []
		var bp := Blueprint.from_dict(files[file_name], errors)
		if bp == null:
			push_error("blueprint_view: %s: %s" % [file_name, ", ".join(errors)])
			continue
		var bad := {}
		for problem in _placement.validate(bp):
			for tile_id in problem.tile_ids:
				bad[tile_id] = true
		var origin := Vector2(COLUMN_PX * (column + 0.5), 330)
		_ships.append([bp, ShipStats.compute(bp, _placement), bad, origin])
		column += 1
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for ship: Array in _ships:
		var bp: Blueprint = ship[0]
		var stats: ShipStats = ship[1]
		var bad: Dictionary = ship[2]
		var origin: Vector2 = ship[3]
		var all_ports: Array = []  # [point px, normal, tile id]
		for tile in bp.tiles:
			var polygon := _to_px(_placement.tile_polygon(tile), origin)
			draw_colored_polygon(polygon, tile.paint)
			if bad.has(tile.id):
				draw_colored_polygon(polygon, PROBLEM)
			draw_polyline(polygon + PackedVector2Array([polygon[0]]), OUTLINE, 2.0, true)
			for edge in _placement.tile_edges(tile):
				for port in edge.ports:
					all_ports.append([origin + port * PX_PER_U, edge.normal, tile.id])
		for i in all_ports.size():
			if not _is_shared(all_ports, i):
				draw_circle(all_ports[i][0], 2.5, PORT)

		var core_px := origin
		for tile in bp.tiles:
			if tile.type == _placement.tiles.core_id():
				core_px = origin + tile.pos * PX_PER_U
		var tip := core_px + Vector2.RIGHT * PX_PER_U * 1.2
		draw_line(core_px, tip, FORWARD, 3.0, true)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(8, 0), tip + Vector2(-6, -7), tip + Vector2(-6, 7)]), FORWARD)
		var com := origin + stats.center_of_mass * PX_PER_U
		draw_line(com - Vector2(7, 7), com + Vector2(7, 7), COM, 2.0)
		draw_line(com - Vector2(7, -7), com + Vector2(7, -7), COM, 2.0)

		var cost := ", ".join(stats.cost.keys().map(func(k: StringName) -> String: return "%d %s" % [stats.cost[k], k]))
		var lines := [
			"%s  (%d tiles)" % [bp.name, stats.tile_count],
			"HP %d   armor %.1f   shield %d" % [stats.hp, stats.armor_avg, stats.shield_cap],
			"mass %.2f   inertia %.2f" % [stats.mass, stats.inertia],
			"cost: %s" % (cost if not cost.is_empty() else "free"),
			"%s" % ("VALID" if bad.is_empty() else "INVALID"),
		]
		for i in lines.size():
			draw_string(font, origin + Vector2(-COLUMN_PX * 0.42, 210 + i * 24), lines[i],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 18)


func _to_px(polygon: PackedVector2Array, origin: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in polygon:
		out.append(origin + p * PX_PER_U)
	return out


func _is_shared(ports: Array, i: int) -> bool:
	for j in ports.size():
		if j != i and ports[j][2] != ports[i][2] \
				and (ports[j][0] as Vector2).distance_to(ports[i][0]) < 0.5 \
				and (ports[j][1] as Vector2).dot(ports[i][1]) < -0.999:
			return true
	return false

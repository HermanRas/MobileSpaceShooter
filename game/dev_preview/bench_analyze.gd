extends Node
## Times the parts of Placement.analyze on a 150-tile ship. Run headless; prints ms per part.

func _ready() -> void:
	var placement: Placement = Placement.create(ShapeLib.from_table(Data.table("shapes")),
			TileLib.from_table(Data.table("tiles")), Data.table("tiles"))
	var bp := Blueprint.new()
	for i in 150:
		var tile := Blueprint.Tile.new()
		tile.id = i
		tile.type = &"core" if i == 0 else &"hull"
		tile.shape = &"square"
		tile.size = &"L"
		tile.pos = Vector2(i % 10 - 5, i / 10 - 7)
		bp.tiles.append(tile)
	bp.tiles[0].pos = Vector2(0, 0)
	bp.tiles[75].pos = Vector2(-5, -7)
	placement.analyze(bp)
	var parts := {}
	for n in 10:
		var t := Time.get_ticks_usec()
		for tile in bp.tiles:
			placement.tile_edges(tile)
		_add(parts, "edges_cache", t)
		t = Time.get_ticks_usec()
		var index := placement._port_index(bp)
		_add(parts, "port_index", t)
		t = Time.get_ticks_usec()
		index.unmatched()
		_add(parts, "unmatched", t)
		t = Time.get_ticks_usec()
		var links := placement._neighbours_from(index, bp)
		_add(parts, "neighbours", t)
		t = Time.get_ticks_usec()
		placement._reach(bp, links)
		_add(parts, "reach", t)
		t = Time.get_ticks_usec()
		placement._placed_polygons(bp)
		_add(parts, "placed", t)
		t = Time.get_ticks_usec()
		placement.analyze(bp)
		_add(parts, "ANALYZE", t)
		t = Time.get_ticks_usec()
		ShipStats.compute(bp, placement)
		_add(parts, "STATS", t)
		t = Time.get_ticks_usec()
		ShipMesh.build(bp.tiles, placement)
		_add(parts, "MESH", t)
	for key in parts:
		print("%-12s %.2f ms" % [key, parts[key] / 10000.0])
	get_tree().quit()

func _add(parts: Dictionary, key: String, t: int) -> void:
	parts[key] = parts.get(key, 0) + Time.get_ticks_usec() - t

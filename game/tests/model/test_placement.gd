extends TestCase
## Phase 1.4: snapping and validation (PLAN.md 4.1).

var placement: Placement


func before_each() -> void:
	var tiles_table := Data.table(&"tiles")
	placement = Placement.create(ShapeLib.from_table(Data.table(&"shapes")),
			TileLib.from_table(tiles_table), tiles_table)


func test_first_tile_must_be_the_core_at_the_origin() -> void:
	var empty := Blueprint.new()
	assert_eq(placement.candidate_snaps(empty, &"hull", &"square", &"L").size(), 0)
	var snaps := placement.candidate_snaps(empty, &"core", &"square", &"L")
	assert_eq(snaps.size(), 1)
	assert_eq(snaps[0].pos, Vector2.ZERO)


func test_a_second_core_is_never_offered() -> void:
	var bp := _ship([[&"core", &"square", &"L", Vector2.ZERO, 0]])
	assert_eq(placement.candidate_snaps(bp, &"core", &"square", &"L").size(), 0)


func test_large_square_on_large_square() -> void:
	var bp := _ship([[&"core", &"square", &"L", Vector2.ZERO, 0]])
	var snaps := placement.candidate_snaps(bp, &"hull", &"square", &"L")
	# 4 sides x 7 port-aligned slides (full overlap plus 3 each way); square rotations dedupe.
	assert_eq(snaps.size(), 28)
	assert_true(_has_pos(snaps, Vector2(1, 0)), "flush to the right")
	assert_true(_has_pos(snaps, Vector2(0, -1)), "flush on top")
	assert_true(_has_pos(snaps, Vector2(1, 0.75)), "slid three ports down")


func test_every_shape_pair_snaps_and_validates() -> void:
	var ids := placement.shapes.shape_ids()
	var checked := 0
	for core_shape in ids:
		for new_shape in ids:
			for size: StringName in [&"S", &"L"]:
				var bp := _ship([[&"core", core_shape, &"L", Vector2.ZERO, 0]])
				var snaps := placement.candidate_snaps(bp, &"hull", new_shape, size)
				if snaps.is_empty():
					fail("no snaps for %s %s onto a %s core" % [size, new_shape, core_shape])
					continue
				for snap in snaps:
					var built := _ship([[&"core", core_shape, &"L", Vector2.ZERO, 0],
							[&"hull", new_shape, size, snap.pos, snap.rot]])
					var problems := placement.validate(built)
					if not problems.is_empty():
						fail("%s %s at %s rot %d onto %s: %s"
								% [size, new_shape, snap.pos, snap.rot, core_shape, problems[0].message])
						return
					checked += 1
	assert_true(checked > 500, "validated %d placements" % checked)
	print("            (validated %d snapped placements)" % checked)


func test_overlap_is_rejected() -> void:
	var bp := _ship([[&"core", &"square", &"L", Vector2.ZERO, 0],
			[&"hull", &"square", &"L", Vector2(0.5, 0), 0]])
	assert_true(_codes(placement.validate(bp)).has(&"overlap"))


func test_touching_edges_do_not_overlap() -> void:
	var bp := _ship([[&"core", &"square", &"L", Vector2.ZERO, 0],
			[&"hull", &"square", &"L", Vector2(1, 0), 0]])
	assert_eq(placement.validate(bp).size(), 0)


func test_disconnected_island_is_found() -> void:
	var bp := _ship([[&"core", &"square", &"L", Vector2.ZERO, 0],
			[&"hull", &"square", &"L", Vector2(1, 0), 0],
			[&"hull", &"square", &"L", Vector2(4, 0), 0]])
	var problems := placement.validate(bp)
	assert_eq(_codes(problems), [&"disconnected"])
	assert_eq(problems[0].tile_ids, PackedInt32Array([2]))


func test_corner_contact_does_not_connect() -> void:
	var bp := _ship([[&"core", &"square", &"L", Vector2.ZERO, 0],
			[&"hull", &"square", &"L", Vector2(1, 1), 0]])
	assert_eq(_codes(placement.validate(bp)), [&"disconnected"])


func test_hex_and_triangle_share_an_edge() -> void:
	# A Large triangle flat against the hex's bottom edge, pointing down.
	var hex_bottom := sqrt(3.0) * 0.5
	var tri_inradius := sqrt(3.0) / 6.0
	var bp := _ship([[&"core", &"hex", &"L", Vector2.ZERO, 0],
			[&"hull", &"triangle", &"L", Vector2(0, hex_bottom + tri_inradius), 12]])
	assert_eq(placement.validate(bp).size(), 0)
	assert_eq(placement.neighbours(bp)[0], PackedInt32Array([1]))


func test_core_count_problems() -> void:
	var none := _ship([[&"hull", &"square", &"L", Vector2.ZERO, 0]])
	assert_true(_codes(placement.validate(none)).has(&"no_core"))
	var two := _ship([[&"core", &"square", &"L", Vector2.ZERO, 0], [&"core", &"square", &"L", Vector2(1, 0), 0]])
	assert_true(_codes(placement.validate(two)).has(&"multiple_cores"))


func test_unknown_names_are_reported() -> void:
	var bp := _ship([[&"core", &"blob", &"L", Vector2.ZERO, 0]])
	assert_eq(_codes(placement.validate(bp)), [&"unknown_shape"])


func test_build_area_is_enforced() -> void:
	var row: Array = [[&"core", &"rect", &"L", Vector2.ZERO, 0]]
	for i in range(1, 9):
		row.append([&"hull", &"rect", &"L", Vector2(i * 2, 0), 0])
	assert_true(_codes(placement.validate(_ship(row))).has(&"over_cap"), "18 U long is over 16")


func test_snaps_near_a_point_only_use_nearby_edges() -> void:
	var bp := _ship([[&"core", &"square", &"L", Vector2.ZERO, 0], [&"hull", &"square", &"L", Vector2(1, 0), 0]])
	var near := placement.candidate_snaps(bp, &"hull", &"square", &"L", Vector2(1.5, 0), 0.3)
	for snap in near:
		assert_eq(snap.target_tile, 1, "only the right-hand tile's right edge is near")
	assert_true(_has_pos(near, Vector2(2, 0)))


func test_a_full_size_ship_validates_quickly() -> void:
	# 150 Large squares, 10 x 15, the tile cap (PLAN.md 4.1). The hangar re-validates on every edit.
	var rows: Array = [[&"core", &"square", &"L", Vector2.ZERO, 0]]
	for i in 150:
		if i > 0:
			rows.append([&"hull", &"square", &"L", Vector2(i % 10, i / 10), 0])
	var bp := _ship(rows)
	var started := Time.get_ticks_usec()
	var problems := placement.validate(bp)
	var validate_ms := (Time.get_ticks_usec() - started) / 1000.0
	started = Time.get_ticks_usec()
	placement.candidate_snaps(bp, &"hull", &"square", &"M", Vector2(10, 7), 1.5)
	var snaps_ms := (Time.get_ticks_usec() - started) / 1000.0
	print("            (150 tiles: validate %.1f ms, nearby snaps %.1f ms)" % [validate_ms, snaps_ms])
	assert_eq(problems.size(), 0)
	assert_true(validate_ms < 500.0, "validate took %.1f ms" % validate_ms)
	assert_true(snaps_ms < 100.0, "snaps took %.1f ms" % snaps_ms)


func _ship(rows: Array) -> Blueprint:
	var bp := Blueprint.new()
	bp.id = "test"
	for row: Array in rows:
		var tile := Blueprint.Tile.new()
		tile.id = bp.next_tile_id()
		tile.type = row[0]
		tile.shape = row[1]
		tile.size = row[2]
		tile.pos = row[3]
		tile.rot = row[4]
		bp.tiles.append(tile)
	return bp


func _has_pos(snaps: Array[Placement.Snap], pos: Vector2) -> bool:
	return snaps.any(func(s: Placement.Snap) -> bool: return s.pos.distance_to(pos) < 0.001)


func _codes(problems: Array[Placement.Problem]) -> Array:
	return problems.map(func(p: Placement.Problem) -> StringName: return p.code)

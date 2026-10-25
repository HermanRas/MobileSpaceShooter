extends TestCase
## Phase 1.5: ship totals, checked against values worked out by hand.

const EPS := 0.0001

var placement: Placement


func before_each() -> void:
	var tiles_table := Data.table(&"tiles")
	placement = Placement.create(ShapeLib.from_table(Data.table(&"shapes")),
			TileLib.from_table(tiles_table), tiles_table)


func test_a_lone_core() -> void:
	var stats := ShipStats.compute(_ship([[&"core", &"square", &"L", Vector2.ZERO]]), placement)
	assert_eq(stats.tile_count, 1)
	assert_almost_eq(stats.hp, 300.0)
	assert_almost_eq(stats.mass, 2.0)
	assert_eq(stats.center_of_mass, Vector2.ZERO)
	# A unit square of mass m: I = m (w² + h²) / 12 = 2 * 2 / 12.
	assert_almost_eq(stats.inertia, 1.0 / 3.0, EPS)
	assert_true(stats.cost.is_empty(), "the core is free")


func test_core_plus_hull_to_the_right() -> void:
	var stats := ShipStats.compute(_ship([[&"core", &"square", &"L", Vector2.ZERO],
			[&"hull", &"square", &"L", Vector2(1, 0)]]), placement)
	assert_almost_eq(stats.hp, 400.0)
	assert_almost_eq(stats.mass, 3.0)
	# (2 * 0 + 1 * 1) / 3
	assert_almost_eq(stats.center_of_mass.x, 1.0 / 3.0, EPS)
	assert_almost_eq(stats.center_of_mass.y, 0.0, EPS)
	# Core: 2/6 + 2 (1/3)²; hull: 1/6 + 1 (2/3)². Total 21/18.
	assert_almost_eq(stats.inertia, 21.0 / 18.0, EPS)
	assert_eq(stats.cost, {&"hull": 12})
	# HP-weighted armor: (5 * 300 + 0 * 100) / 400
	assert_almost_eq(stats.armor_avg, 3.75, EPS)


func test_mixed_sizes_and_materials() -> void:
	var stats := ShipStats.compute(_ship([[&"core", &"square", &"L", Vector2.ZERO],
			[&"shield", &"square", &"M", Vector2(0.75, -0.25)],
			[&"hardpoint", &"square", &"M", Vector2(0.75, 0.25)],
			[&"armor", &"rect", &"S", Vector2(-0.625, 0)]]), placement)
	assert_almost_eq(stats.shield_cap, 30.0)
	assert_almost_eq(stats.shield_regen, 2.0)
	assert_eq(stats.cost, {&"hull": 10, &"crystal": 6, &"alloy": 7, &"tech": 2})
	assert_almost_eq(stats.mass, 2.0 + 0.4 + 0.75 + 0.625)


func test_polygon_helpers_on_a_triangle() -> void:
	var tri := PackedVector2Array([Vector2(0, 0), Vector2(3, 0), Vector2(0, 3)])
	assert_almost_eq(ShipStats.polygon_area(tri), 4.5)
	assert_eq(ShipStats.polygon_centroid(tri), Vector2(1, 1))


func _ship(rows: Array) -> Blueprint:
	var bp := Blueprint.new()
	for row: Array in rows:
		var tile := Blueprint.Tile.new()
		tile.id = bp.next_tile_id()
		tile.type = row[0]
		tile.shape = row[1]
		tile.size = row[2]
		tile.pos = row[3]
		bp.tiles.append(tile)
	return bp

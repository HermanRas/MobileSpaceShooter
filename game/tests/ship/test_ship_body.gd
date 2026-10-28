extends TestCase
## Phase 3.1: a blueprint becomes a RigidBody2D with the right mass, shapes and hit lookup.

const PX := ShipMesh.PX_PER_U

var placement: Placement
var _bodies: Array[ShipBody] = []


func before_each() -> void:
	var tiles_table := Data.table(&"tiles")
	placement = Placement.create(ShapeLib.from_table(Data.table(&"shapes")),
			TileLib.from_table(tiles_table), tiles_table)


func after_each() -> void:
	for body in _bodies:
		body.free()
	_bodies.clear()


func test_mass_properties_come_from_ship_stats() -> void:
	for id: String in ["starter", "hexwing", "brick"]:
		var bp := _sample(id)
		var ship := _spawn(bp)
		var stats := ShipStats.compute(bp, placement)
		assert_almost_eq(ship.mass, stats.mass, 0.0001, "%s mass" % id)
		assert_true(ship.center_of_mass.is_equal_approx(stats.center_of_mass * PX), "%s centre of mass" % id)
		assert_almost_eq(ship.inertia, stats.inertia * PX * PX, 0.01, "%s inertia, in pixels" % id)
		assert_eq(ship.center_of_mass_mode, RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM)
		assert_eq(ship.gravity_scale, 0.0)


func test_one_shape_per_tile_with_the_tiles_outline() -> void:
	var bp := _sample("hexwing")
	var ship := _spawn(bp)
	assert_eq(ship.get_shape_owners().size(), bp.tiles.size())
	for index in bp.tiles.size():
		# Check against the geometry, not just a round trip: a shuffled table would round-trip.
		var tile := bp.tile_by_id(ship.tile_at_shape(index))
		assert_not_null(tile, "shape %d maps to a tile" % index)
		if tile == null:
			continue
		var shape := ship.shape_owner_get_shape(ship.shape_find_owner(index), 0) as ConvexPolygonShape2D
		var expected := PackedVector2Array()
		for p in placement.tile_polygon(tile):
			expected.append(p * PX)
		assert_eq(_rounded(shape.points), _rounded(expected), "shape %d has tile %d's outline" % [index, tile.id])
		assert_eq(ship.shape_of_tile(tile.id), index)


func test_out_of_range_shape_index_is_no_tile() -> void:
	var ship := _spawn(_sample("starter"))
	assert_eq(ship.tile_at_shape(-1), -1)
	assert_eq(ship.tile_at_shape(999), -1)


func test_rebuild_replaces_the_old_shapes() -> void:
	var ship := _spawn(_sample("hexwing"))
	var starter := _sample("starter")
	ship.build(starter, placement)
	assert_eq(ship.get_shape_owners().size(), starter.tiles.size())
	assert_almost_eq(ship.mass, ShipStats.compute(starter, placement).mass, 0.0001)


func test_the_mesh_is_one_surface() -> void:
	var ship := _spawn(_sample("hexwing"))
	var mesh := (ship.get_node(^"Mesh") as MeshInstance2D).mesh
	assert_not_null(mesh)
	assert_eq(mesh.get_surface_count(), 1, "one surface = one draw call")


func test_a_150_tile_ship_spawns_fast() -> void:
	var bp := _grid_ship(150)
	var samples: Array[float] = []
	for i in 5:
		var started := Time.get_ticks_usec()
		_spawn(bp)
		samples.append((Time.get_ticks_usec() - started) / 1000.0)
	samples.sort()
	# The target is 50 ms on the phone, which runs GDScript ~3.5x slower than this PC (§5.5).
	print("    150-tile spawn: median %.1f ms" % samples[2])
	assert_true(samples[2] < 50.0 / 3.5, "150-tile spawn median %.1f ms" % samples[2])
	assert_eq(_bodies[-1].get_shape_owners().size(), 150)


# ── helpers ───────────────────────────────────────────────────────────────────

func _spawn(bp: Blueprint) -> ShipBody:
	var ship := ShipBody.create(bp, placement)
	_bodies.append(ship)
	return ship


func _sample(id: String) -> Blueprint:
	var errors: PackedStringArray = []
	return Blueprint.from_dict(Data.json_dir("blueprints")[id], errors)


## A 10 x 15 slab of Large squares with the core in the middle of it.
static func _grid_ship(count: int) -> Blueprint:
	var bp := Blueprint.new()
	bp.id = "grid"
	for i in count:
		var tile := Blueprint.Tile.new()
		tile.id = i
		tile.type = &"core" if i == 0 else &"hull"
		tile.shape = &"square"
		tile.size = &"L"
		tile.pos = Vector2(i % 10 - 5, i / 10 - 7)
		tile.paint = Color.GRAY
		bp.tiles.append(tile)
	# Swap the core with the tile at the origin.
	bp.tiles[75].pos = bp.tiles[0].pos
	bp.tiles[0].pos = Vector2.ZERO
	return bp


static func _rounded(points: PackedVector2Array) -> Array:
	var out := []
	for p in points:
		out.append(Vector2i(roundi(p.x * 100.0), roundi(p.y * 100.0)))
	return out


func test_nearest_keeps_the_closest_few_in_order() -> void:
	var nodes: Array = []
	for x in [9.0, 2.0, 7.0, 1.0, 5.0, 3.0]:
		var node := Node2D.new()
		node.position = Vector2(x, 0)
		nodes.append(node)
	var near := ShipBody.nearest(nodes, Vector2.ZERO, 3)
	assert_eq(near.map(func(n: Node2D) -> float: return n.position.x), [1.0, 2.0, 3.0])
	assert_eq(ShipBody.nearest(nodes, Vector2.ZERO, 0).size(), 6, "0 keeps them all")
	assert_eq(ShipBody.nearest(nodes, Vector2.ZERO, 10).size(), 6, "as does asking for more than there are")
	for node: Node2D in nodes:
		node.free()


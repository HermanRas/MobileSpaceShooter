extends TestCase
## Phase 1.1: shape geometry (PLAN.md 4.1).

const EPS := 0.0005

var lib: ShapeLib


func before_each() -> void:
	lib = ShapeLib.from_table(Data.table(&"shapes"))


func test_shipped_shapes_load_cleanly() -> void:
	assert_eq(lib.errors.size(), 0, ", ".join(lib.errors))
	assert_eq(lib.shape_ids(), [&"hex", &"rect", &"square", &"triangle", &"wedge"])
	assert_eq(lib.rotation_steps(), 24)


func test_edge_lengths() -> void:
	_assert_lengths(&"square", &"L", [1.0, 1.0, 1.0, 1.0])
	_assert_lengths(&"rect", &"L", [2.0, 1.0, 2.0, 1.0])
	_assert_lengths(&"triangle", &"S", [0.25, 0.25, 0.25])
	_assert_lengths(&"hex", &"M", [0.5, 0.5, 0.5, 0.5, 0.5, 0.5])
	_assert_lengths(&"wedge", &"L", [1.0, sqrt(2.0), 1.0])


func test_port_counts() -> void:
	assert_eq(_port_count(&"square", &"L"), 16, "a Large square has 16 ports")
	assert_eq(_port_count(&"square", &"S"), 4)
	assert_eq(_port_count(&"rect", &"L"), 24)
	assert_eq(_port_count(&"triangle", &"L"), 12)
	assert_eq(_port_count(&"hex", &"L"), 24)
	assert_eq(_port_count(&"hex", &"S"), 6)
	assert_eq(_port_count(&"wedge", &"L"), 8, "the hypotenuse has no ports")


func test_ports_sit_on_their_edge_at_the_pitch() -> void:
	for edge in lib.edges(&"rect", &"L", 3, Vector2(2, -1)):
		for k in edge.ports.size():
			var expected_t := (k + 0.5) * lib.port_pitch / edge.length()
			assert_true(edge.ports[k].distance_to(edge.a.lerp(edge.b, expected_t)) < EPS,
					"rect edge %d port %d" % [edge.index, k])


func test_normals_point_outward_at_every_size_and_rotation() -> void:
	for shape_id in lib.shape_ids():
		for size_code: StringName in lib.sizes:
			for rot in lib.rotation_steps():
				var offset := Vector2(rot * 0.3, -rot * 0.1)
				var points := lib.polygon(shape_id, size_code, rot, offset)
				var center := Vector2.ZERO
				for p in points:
					center += p
				center /= points.size()
				for edge in lib.edges(shape_id, size_code, rot, offset):
					var ok := absf(edge.normal.length() - 1.0) < EPS \
							and edge.normal.dot(edge.midpoint() - center) > 0.0 \
							and absf(edge.normal.dot(edge.b - edge.a)) < EPS
					if not ok:
						fail("%s %s rot %d edge %d normal %s" % [shape_id, size_code, rot, edge.index, edge.normal])
						return
	assert_true(true)


func test_a_full_turn_returns_to_the_start() -> void:
	for shape_id in lib.shape_ids():
		var start := lib.polygon(shape_id, &"M", 0)
		var turned := lib.polygon(shape_id, &"M", lib.rotation_steps())
		for i in start.size():
			assert_true(start[i].distance_to(turned[i]) < EPS, "%s vertex %d" % [shape_id, i])


func test_every_edge_direction_is_on_the_rotation_grid() -> void:
	# Snapping joins edges antiparallel, which only works if every edge's angle is a
	# multiple of the rotation step.
	for shape_id in lib.shape_ids():
		for edge in lib.edges(shape_id, &"L", 0):
			var degrees := rad_to_deg((edge.b - edge.a).angle())
			var steps := degrees / lib.rotation_step_deg
			assert_true(absf(steps - roundf(steps)) < EPS,
					"%s edge %d at %.3f°" % [shape_id, edge.index, degrees])


func test_shapes_are_convex() -> void:
	# One CollisionPolygon2D per tile is only exact for convex shapes (PLAN.md 4.1).
	for shape_id in lib.shape_ids():
		var points := lib.polygon(shape_id, &"L", 0)
		assert_eq(Geometry2D.convex_hull(points).size() - 1, points.size(), "%s is convex" % shape_id)


func test_a_misfit_edge_is_rejected() -> void:
	var table := {
		"port_pitch": 0.25, "rotation_step_deg": 15,
		"sizes": {"L": 1.0},
		"shapes": {"odd": {"kind": "box", "w": 1.1, "h": 1}},
	}
	var bad := ShapeLib.from_table(table)
	assert_eq(bad.errors.size(), 2, "both 1.1 U edges are flagged")


func _assert_lengths(shape_id: StringName, size_code: StringName, expected: Array) -> void:
	var edges := lib.edges(shape_id, size_code, 0)
	assert_eq(edges.size(), expected.size(), "%s edge count" % shape_id)
	for i in edges.size():
		assert_almost_eq(edges[i].length(), expected[i], EPS, "%s %s edge %d" % [shape_id, size_code, i])


func _port_count(shape_id: StringName, size_code: StringName) -> int:
	var total := 0
	for edge in lib.edges(shape_id, size_code, 0):
		total += edge.ports.size()
	return total

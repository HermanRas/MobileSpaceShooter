extends TestCase
## Phase 3.2: thruster data, mounting on hardpoint edges, and the thrust envelope.

const EPS := 0.0001

var placement: Placement
var lib: ThrusterLib


func before_each() -> void:
	var tiles_table := Data.table(&"tiles")
	placement = Placement.create(ShapeLib.from_table(Data.table(&"shapes")),
			TileLib.from_table(tiles_table), tiles_table)
	lib = ThrusterLib.from_table(Data.table(&"thrusters"))
	placement.thrusters = lib


# ── data ──────────────────────────────────────────────────────────────────────

func test_the_table_loads_clean() -> void:
	assert_eq(lib.errors, PackedStringArray())
	assert_eq(lib.type_ids(), [&"ion", &"jet", &"pulse"])
	for type_id in lib.type_ids():
		assert_eq(lib.level_count(type_id), 3, "%s has L1-3" % type_id)


func test_never_better_than_ion_at_every_size() -> void:
	# PLAN.md 4.3: pulse Lx < jet Lx at every level, and max(pulse L3, jet L3) < ion L1 peak.
	for size_code: StringName in [&"S", &"M", &"L"]:
		for level in range(1, 4):
			assert_true(_thrust(&"pulse", size_code, level) < _thrust(&"jet", size_code, level),
					"pulse < jet at %s L%d" % [size_code, level])
		assert_true(maxf(_thrust(&"pulse", size_code, 3), _thrust(&"jet", size_code, 3)) < _thrust(&"ion", size_code, 1),
				"pulse and jet L3 stay under ion L1's peak at %s" % size_code)
		assert_true(lib.spec(&"ion", size_code, 1)["start"] < _thrust(&"jet", size_code, 1),
				"ion starts weaker than jet at %s (the commitment tradeoff)" % size_code)


func test_size_scales_thrust_mass_and_price() -> void:
	var large := lib.spec(&"jet", &"L", 2)
	var small := lib.spec(&"jet", &"S", 2)
	assert_almost_eq(small["thrust"], large["thrust"] * 0.25)
	assert_almost_eq(small["mass"], large["mass"] * 0.25)
	assert_eq(small["price_gc"], roundi(large["price_gc"] * 0.25))
	assert_eq(lib.spec(&"jet", &"XL", 1), {}, "unknown size")
	assert_eq(lib.spec(&"jet", &"L", 4), {}, "unknown level")


# ── mounting ──────────────────────────────────────────────────────────────────

func test_a_lone_hardpoint_offers_its_three_free_edges() -> void:
	var bp := _ship([[&"core", Vector2.ZERO], [&"hardpoint", Vector2(-1, 0)]])
	# One edge touches the core; the other three take 1 Large, 3 Medium or 4 Small each.
	assert_eq(Mounting.thruster_slots(placement, bp, &"L").size(), 3)
	assert_eq(Mounting.thruster_slots(placement, bp, &"M").size(), 9)
	assert_eq(Mounting.thruster_slots(placement, bp, &"S").size(), 12)


func test_only_hardpoints_take_thrusters() -> void:
	var bp := _ship([[&"core", Vector2.ZERO], [&"hull", Vector2(-1, 0)]])
	assert_eq(Mounting.thruster_slots(placement, bp, &"L").size(), 0)


func test_the_frame_sits_on_the_edge_and_faces_out() -> void:
	var bp := _ship([[&"core", Vector2.ZERO], [&"hardpoint", Vector2(-1, 0)]])
	var mount := _mount(bp, 1, Vector2.LEFT, &"L", &"pulse")
	var mount_frame := Mounting.frame(placement, bp, mount)
	assert_true((mount_frame["center"] as Vector2).is_equal_approx(Vector2(-1.5, 0)), "centre of the rear edge")
	assert_true((mount_frame["normal"] as Vector2).is_equal_approx(Vector2.LEFT), "exhaust points back")
	assert_almost_eq(mount_frame["length"], 1.0)
	assert_eq((mount_frame["ports"] as PackedVector2Array).size(), 4)


func test_a_thruster_blocks_its_edge_and_the_space_behind_it() -> void:
	var bp := _ship([[&"core", Vector2.ZERO], [&"hardpoint", Vector2(-1, 0)]])
	bp.mounts.append(_mount(bp, 1, Vector2.LEFT, &"L", &"pulse"))
	assert_eq(placement.validate(bp).size(), 0, "a well-placed thruster is no problem")
	var rear_small := Mounting.thruster_slots(placement, bp, &"S").filter(
			func(s: Dictionary) -> bool: return _normal_of(bp, s).is_equal_approx(Vector2.LEFT))
	assert_eq(rear_small.size(), 0, "no second thruster on the same stretch")
	var behind := placement.candidate_snaps(bp, &"hull", &"square", &"L").filter(
			func(s: Placement.Snap) -> bool: return s.pos.is_equal_approx(Vector2(-2, 0)))
	assert_eq(behind.size(), 0, "no tile can snap onto the thruster")


func test_a_tile_on_top_of_a_thruster_is_a_problem() -> void:
	var bp := _ship([[&"core", Vector2.ZERO], [&"hardpoint", Vector2(-1, 0)]])
	bp.mounts.append(_mount(bp, 1, Vector2.LEFT, &"L", &"pulse"))
	bp.tiles.append(_tile(9, &"hull", Vector2(-2, 0)))  # bypassing the editor
	var problems := placement.validate(bp).filter(func(p: Placement.Problem) -> bool: return p.code == &"mount")
	assert_eq(problems.size(), 1)
	assert_true("blocked" in (problems[0] as Placement.Problem).message)
	assert_eq((problems[0] as Placement.Problem).tile_ids, PackedInt32Array([1]))


func test_a_thruster_on_a_hull_tile_is_a_problem() -> void:
	var bp := _ship([[&"core", Vector2.ZERO], [&"hull", Vector2(-1, 0)]])
	bp.mounts.append({"tile": 1, "edge": 0, "port": 0, "part": "thruster.jet", "size": "L", "level": 1})
	var problems := placement.validate(bp).filter(func(p: Placement.Problem) -> bool: return p.code == &"mount")
	assert_eq(problems.size(), 1)
	assert_true("hardpoint" in (problems[0] as Placement.Problem).message)


func test_thrusters_add_their_mass_where_they_sit() -> void:
	var bp := _ship([[&"core", Vector2.ZERO], [&"hardpoint", Vector2(-1, 0)]])
	var before := ShipStats.compute(bp, placement)
	bp.mounts.append(_mount(bp, 1, Vector2.LEFT, &"L", &"ion"))
	var after := ShipStats.compute(bp, placement)
	assert_almost_eq(after.mass, before.mass + 0.8)
	assert_eq(after.thruster_count, 1)
	assert_true(after.center_of_mass.x < before.center_of_mass.x, "a rear thruster moves the centre of mass back")


# ── envelope ──────────────────────────────────────────────────────────────────

func test_the_starter_blueprint_carries_its_three_thrusters() -> void:
	var errors: PackedStringArray = []
	var bp := Blueprint.from_dict(Data.json_dir("blueprints")["starter"], errors)
	assert_eq(placement.validate(bp).size(), 0)
	var envelope := ThrustEnvelope.compute(bp, placement)
	assert_eq(envelope.thrusters.size(), 3, "PLAN.md 4.10: 3 pulse thrusters")
	assert_eq(envelope.warnings, [] as Array[Dictionary])


func test_the_starter_layout_flies_clean() -> void:
	var bp := _starter_layout(true, true, true)
	var envelope := ThrustEnvelope.compute(bp, placement)
	assert_eq(envelope.warnings, [] as Array[Dictionary], "2 rear + 1 front: no warnings")
	assert_almost_eq(envelope.rose[ThrustEnvelope.FORWARD], 80.0, 0.01, "two Large L1 pulses forward")
	assert_almost_eq(envelope.rose[ThrustEnvelope.BACK], 40.0, 0.01, "one to brake")
	assert_true(envelope.turn_left > 0.0 and envelope.turn_right > 0.0)
	assert_almost_eq(envelope.accel(ThrustEnvelope.FORWARD), 80.0 / envelope.mass, EPS)


func test_the_right_rear_thruster_turns_the_ship_left() -> void:
	# PLAN.md 4.3: drag left + forward fires the right rear thruster. +y is the ship's right.
	var envelope := ThrustEnvelope.compute(_starter_layout(true, true, true), placement)
	var right_rear: Dictionary = envelope.thrusters.filter(
			func(t: Dictionary) -> bool: return t["push"].x > 0.5 and t["pos"].y > 0.0)[0]
	var torque := (right_rear["pos"] as Vector2).cross(right_rear["push"] * right_rear["force"])
	assert_true(torque < 0.0, "negative torque = nose turns left (torque %.2f)" % torque)


func test_one_centred_rear_thruster_cant_turn() -> void:
	var bp := _ship([[&"core", Vector2.ZERO], [&"hardpoint", Vector2(-1, 0)], [&"hardpoint", Vector2(1, 0)]])
	bp.mounts.append(_mount(bp, 1, Vector2.LEFT, &"L", &"jet"))
	bp.mounts.append(_mount(bp, 2, Vector2.RIGHT, &"L", &"jet"))
	var envelope := ThrustEnvelope.compute(bp, placement)
	assert_true(envelope.has_warning(&"cant_turn_left") and envelope.has_warning(&"cant_turn_right"))
	assert_false(envelope.has_warning(&"pulls"), "dead centre doesn't pull")


func test_bad_builds_get_their_warnings() -> void:
	var lopsided := ThrustEnvelope.compute(_starter_layout(true, false, true), placement)
	assert_true(lopsided.has_warning(&"pulls"), "one rear thruster off-centre pulls")
	var no_forward := ThrustEnvelope.compute(_starter_layout(false, false, true), placement)
	assert_true(no_forward.has_warning(&"no_forward"))
	var no_brake := ThrustEnvelope.compute(_starter_layout(true, true, false), placement)
	assert_true(no_brake.has_warning(&"cant_brake"))
	assert_false(no_brake.has_warning(&"pulls"))
	var bare := ThrustEnvelope.compute(_starter_layout(false, false, false), placement)
	assert_true(bare.has_warning(&"no_thrusters"))


func test_thrusters_facing_four_ways_can_strafe() -> void:
	var bp := _starter_layout(true, true, true)
	# Side thrusters on the outer edges of the rear hardpoints.
	bp.mounts.append(_mount(bp, 4, Vector2.UP, &"M", &"jet"))
	bp.mounts.append(_mount(bp, 5, Vector2.DOWN, &"M", &"jet"))
	var envelope := ThrustEnvelope.compute(bp, placement)
	assert_true(envelope.rose[ThrustEnvelope.LEFT] > 0.0 and envelope.rose[ThrustEnvelope.RIGHT] > 0.0)


# ── editor ────────────────────────────────────────────────────────────────────

func test_editor_mounts_in_mirror_and_undo_restores() -> void:
	var editor := HangarEditor.create(placement, _starter_layout(false, false, false))
	editor.mirror = true
	var slot := _slot(editor.blueprint, 4, Vector2.LEFT, &"L")
	var added := editor.add_thruster(&"pulse", &"L", 1, slot)
	assert_eq(added.size(), 2, "mirror mode mounts the twin on the other rear hardpoint")
	assert_eq(int(editor.blueprint.mounts[1]["tile"]), 5)
	assert_true(ThrustEnvelope.compute(editor.blueprint, placement).turn_left > 0.0)
	assert_eq(editor.add_thruster(&"pulse", &"L", 1, slot).size(), 0, "a taken slot is refused")
	editor.remove_mount(0)
	assert_eq(editor.blueprint.mounts.size(), 0, "removing one removes its twin")
	editor.undo()
	assert_eq(editor.blueprint.mounts.size(), 2, "undo restores both")


func test_moving_a_thruster_is_one_undo_step() -> void:
	var editor := HangarEditor.create(placement, _starter_layout(true, true, true))
	var bp := editor.blueprint
	# The front thruster (mount 2) moves to the free top edge of the rear-left hardpoint.
	var to := _slot(bp, 4, Vector2.UP, &"L")
	assert_true(editor.move_mount(2, to))
	assert_eq(bp.mounts.size(), 3)
	assert_eq(editor.mount_index(to), 2, "it lands at the end of the list")
	assert_true(ThrustEnvelope.compute(editor.blueprint, placement).has_warning(&"cant_brake"), "nothing faces forward now")
	editor.undo()
	assert_eq(int(editor.blueprint.mounts[2]["tile"]), 6, "one undo puts it back on the front hardpoint")
	assert_false(editor.move_mount(2, _slot(editor.blueprint, 4, Vector2.LEFT, &"L")), "an occupied slot is refused")
	assert_eq(editor.blueprint.mounts.size(), 3, "and nothing is lost")


func test_removing_a_hardpoint_removes_its_thrusters() -> void:
	var editor := HangarEditor.create(placement, _starter_layout(true, true, true))
	editor.remove(4)
	assert_false(editor.blueprint.mounts.any(func(m: Dictionary) -> bool: return int(m["tile"]) == 4))
	assert_eq(editor.blueprint.mounts.size(), 2)


func test_mounts_round_trip_through_json() -> void:
	var bp := _starter_layout(true, true, true)
	var errors: PackedStringArray = []
	var back := Blueprint.from_dict(JSON.parse_string(JSON.stringify(bp.to_dict())), errors)
	assert_eq(back.mounts, bp.mounts)
	assert_eq(typeof(back.mounts[0]["edge"]), TYPE_INT)


# ── helpers ───────────────────────────────────────────────────────────────────

func _thrust(type_id: StringName, size_code: StringName, level: int) -> float:
	return lib.spec(type_id, size_code, level)["thrust"]


## The starter's tiles (PLAN.md 4.10), with any of its three Large pulse thrusters.
func _starter_layout(left_rear: bool, right_rear: bool, front: bool) -> Blueprint:
	var errors: PackedStringArray = []
	var bp := Blueprint.from_dict(Data.json_dir("blueprints")["starter"], errors)
	bp.mounts.clear()
	if left_rear:
		bp.mounts.append(_mount(bp, 4, Vector2.LEFT, &"L", &"pulse"))
	if right_rear:
		bp.mounts.append(_mount(bp, 5, Vector2.LEFT, &"L", &"pulse"))
	if front:
		bp.mounts.append(_mount(bp, 6, Vector2.RIGHT, &"L", &"pulse"))
	return bp


func _mount(bp: Blueprint, tile_id: int, normal: Vector2, size_code: StringName, type_id: StringName) -> Dictionary:
	var slot := _slot(bp, tile_id, normal, size_code)
	return {"tile": tile_id, "edge": slot["edge"], "port": slot["port"],
			"part": ThrusterLib.part_id(type_id), "size": String(size_code), "level": 1}


## The first free slot on `tile_id`'s edge facing `normal`.
func _slot(bp: Blueprint, tile_id: int, normal: Vector2, size_code: StringName) -> Dictionary:
	for edge in placement.tile_edges(bp.tile_by_id(tile_id)):
		if edge.normal.is_equal_approx(normal):
			return {"tile": tile_id, "edge": edge.index, "port": 0}
	fail("tile %d has no edge facing %s" % [tile_id, normal])
	return {}


func _normal_of(bp: Blueprint, slot: Dictionary) -> Vector2:
	return placement.tile_edges(bp.tile_by_id(slot["tile"]))[slot["edge"]].normal


func _ship(rows: Array) -> Blueprint:
	var bp := Blueprint.new()
	bp.id = "test"
	for i in rows.size():
		bp.tiles.append(_tile(i, rows[i][0], rows[i][1]))
	return bp


func _tile(id: int, type: StringName, pos: Vector2) -> Blueprint.Tile:
	var tile := Blueprint.Tile.new()
	tile.id = id
	tile.type = type
	tile.shape = &"square"
	tile.size = &"L"
	tile.pos = pos
	tile.paint = Color.GRAY
	return tile

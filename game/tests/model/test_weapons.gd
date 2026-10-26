extends TestCase
## Phase 4.3: gun data, mounting guns on hardpoint edges and faces, where each gun can shoot,
## and the fire control that aims, leads and fires them.

const DT := 1.0 / 60.0

var placement: Placement
var lib: WeaponLib


func before_each() -> void:
	var tiles_table := Data.table(&"tiles")
	placement = Placement.create(ShapeLib.from_table(Data.table(&"shapes")),
			TileLib.from_table(tiles_table), tiles_table)
	placement.thrusters = ThrusterLib.from_table(Data.table(&"thrusters"))
	lib = WeaponLib.from_table(Data.table(&"weapons"))
	placement.weapons = lib


# ── data ──────────────────────────────────────────────────────────────────────

func test_the_table_loads_clean() -> void:
	assert_eq(lib.errors, PackedStringArray())
	assert_true(lib.has_weapon(&"gatling_single"), "the starter gun")
	assert_eq(lib.mount_type(&"fixed")["arc"], 0.0)
	assert_almost_eq(lib.mount_type(&"swivel")["arc"], deg_to_rad(22.5))
	assert_true(lib.mount_type(&"turret")["face"], "a turret sits on a face")
	assert_eq(lib.mount_type(&"turret")["modes"], [&"auto"], "PLAN.md 4.4: turrets are always auto")
	assert_true(lib.mount_type(&"turret")["over_hull"], "turrets sit on top and fire over the hull")
	assert_false(lib.mount_type(&"fixed")["over_hull"] or lib.mount_type(&"swivel")["over_hull"])
	assert_eq(lib.mode_for(&"turret", &"manual"), &"auto")
	assert_eq(lib.mode_for(&"swivel", &"manual"), &"manual")


func test_accuracy_comes_with_level() -> void:
	var stats := lib.weapon(&"gatling_single")
	assert_almost_eq(WeaponLib.spread_for(stats, 1), deg_to_rad(5.0), 0.0001, "L1 sprays")
	assert_almost_eq(WeaponLib.spread_for(stats, lib.max_level), deg_to_rad(0.5), 0.0001, "the top level is near-perfect")
	var last := INF
	for level in [1, 2, 10, 50, 100, 400, 999]:
		var spread := WeaponLib.spread_for(stats, level)
		assert_true(spread < last or level == 1, "L%d is tighter than the level before (%.2f°)" % [level, rad_to_deg(spread)])
		last = spread
	assert_true(WeaponLib.spread_for(stats, 100) < deg_to_rad(2.75), "a log curve: the early levels count the most")


func test_a_low_level_gun_scatters_and_a_high_one_doesnt() -> void:
	for row: Array in [[1, 5.0], [999, 0.5]]:
		var layout := GunLayout.compute(_nose_gun(&"fixed", &"manual"), placement, row[0])
		var gunnery := Gunnery.create(layout, lib)
		gunnery.rng.seed = 7
		var widest := 0.0
		for i in 120:
			for shot in gunnery.step(DT, Vector2.ZERO, 0.0, Vector2.ZERO, [], true):
				widest = maxf(widest, absf(rad_to_deg((shot["vel"] as Vector2).angle())))
		assert_true(widest <= row[1] + 0.001 and widest > row[1] * 0.7,
				"L%d strays up to %.1f° (limit %.1f°)" % [row[0], widest, row[1]])


func test_every_gun_deals_a_known_damage_type() -> void:
	var damage := DamageTable.from_table(Data.table(&"damage_types"))
	for weapon_id in lib.weapon_ids():
		assert_true(damage.has_type(lib.weapon(weapon_id)["damage_type"]), "%s's damage type" % weapon_id)


func test_bad_rows_are_reported_and_left_out() -> void:
	var table: Dictionary = Data.table(&"weapons").duplicate(true)
	table["weapons"]["broken"] = {"name": "Broken", "damage_type": "kinetic", "mounts": ["fixed", "catapult"]}
	var bad := WeaponLib.from_table(table)
	assert_true(bad.errors.size() > 0)
	assert_false(bad.has_weapon(&"broken"))
	assert_true(bad.has_weapon(&"gatling_single"), "the good rows still load")
	table["weapons"]["gatling_single"]["spread_deg"] = [1, 4]
	assert_false(WeaponLib.from_table(table).has_weapon(&"gatling_single"), "spread can't widen with level")


# ── mounting ──────────────────────────────────────────────────────────────────

func test_a_lone_hardpoint_offers_edge_and_face_slots() -> void:
	var bp := _ship([[&"core", Vector2.ZERO], [&"hardpoint", Vector2(-1, 0)]])
	# Three free edges with 4 ports each; a gatling covers 2 of them.
	assert_eq(Mounting.weapon_slots(placement, bp, &"gatling_single", &"fixed").size(), 9)
	assert_eq(Mounting.weapon_slots(placement, bp, &"gatling_single", &"swivel").size(), 9)
	assert_eq(Mounting.weapon_slots(placement, bp, &"gatling_single", &"turret"), [{"tile": 1, "face": true}] as Array[Dictionary])


func test_a_small_hardpoint_is_too_small_for_a_turret() -> void:
	var bp := _ship([[&"core", Vector2.ZERO]])
	var small := _tile(1, &"hardpoint", Vector2(-0.625, -0.375))
	small.size = &"S"
	bp.tiles.append(small)
	assert_eq(Mounting.weapon_slots(placement, bp, &"gatling_single", &"turret").size(), 0)


func test_a_turret_needs_a_hardpoint_and_auto() -> void:
	var on_hull := _ship([[&"core", Vector2.ZERO], [&"hull", Vector2(-1, 0)]])
	on_hull.mounts.append(_turret(1))
	assert_true(_mount_problems(on_hull)[0].contains("hardpoint"), "a turret on hull")
	var manual := _ship([[&"core", Vector2.ZERO], [&"hardpoint", Vector2(-1, 0)]])
	var mount := _turret(1)
	mount["mode"] = "manual"
	manual.mounts.append(mount)
	assert_true(_mount_problems(manual)[0].contains("manual"), "a manual turret")
	var twice := _ship([[&"core", Vector2.ZERO], [&"hardpoint", Vector2(-1, 0)]])
	twice.mounts.append(_turret(1))
	twice.mounts.append(_turret(1))
	assert_eq(_mount_problems(twice).size(), 2, "two turrets on one tile")


func test_an_edge_gun_takes_its_ports_and_the_space_ahead() -> void:
	var bp := _ship([[&"core", Vector2.ZERO], [&"hardpoint", Vector2(-1, 0)]])
	bp.mounts.append(_edge_gun(bp, 1, Vector2.LEFT, 1, &"fixed", &"manual"))
	assert_eq(placement.validate(bp).size(), 0, "a well-placed gun is no problem")
	var rear := func(s: Dictionary) -> bool: return _normal_of(bp, s).is_equal_approx(Vector2.LEFT)
	assert_eq(Mounting.thruster_slots(placement, bp, &"L").filter(rear).size(), 0, "no Large thruster beside it")
	assert_eq(Mounting.thruster_slots(placement, bp, &"S").filter(rear).size(), 2, "Small ones fit either side")
	var on_top := placement.candidate_snaps(bp, &"hull", &"square", &"L").filter(
			func(s: Placement.Snap) -> bool: return s.pos.is_equal_approx(Vector2(-2, 0)))
	assert_eq(on_top.size(), 0, "no tile can snap onto the barrel")


func test_guns_add_their_mass_where_they_sit() -> void:
	var bp := _ship([[&"core", Vector2.ZERO], [&"hardpoint", Vector2(1, 0)]])
	var before := ShipStats.compute(bp, placement)
	bp.mounts.append(_turret(1))
	var after := ShipStats.compute(bp, placement)
	assert_almost_eq(after.mass, before.mass + lib.weapon(&"gatling_single")["mass"])
	assert_eq(after.weapon_count, 1)
	assert_true(after.center_of_mass.x > before.center_of_mass.x)


# ── editor ────────────────────────────────────────────────────────────────────

func test_editor_mounts_guns_in_mirror_and_switches_modes() -> void:
	var editor := HangarEditor.create(placement, _sample("starter"))
	editor.blueprint.mounts.clear()
	editor.mirror = true
	var slot := _slot(editor.blueprint, 4, Vector2.UP, 1)
	assert_eq(editor.add_weapon(&"gatling_single", &"swivel", &"auto", slot).size(), 2, "the twin goes on tile 5")
	assert_eq(int(editor.blueprint.mounts[1]["tile"]), 5)
	assert_true(editor.set_mount_mode(0, &"manual"))
	assert_eq(editor.blueprint.mounts.map(func(m: Dictionary) -> String: return m["mode"]), ["manual", "manual"])
	editor.undo()
	assert_eq(editor.blueprint.mounts.map(func(m: Dictionary) -> String: return m["mode"]), ["auto", "auto"])
	var added := editor.add_weapon(&"gatling_single", &"turret", &"manual", {"tile": 6, "face": true})
	assert_eq(added.size(), 1, "the nose sits on the axis: no twin")
	assert_eq(editor.blueprint.mounts[added[0]]["mode"], "auto", "a turret comes out auto whatever was asked")
	assert_false(editor.set_mount_mode(added[0], &"manual"), "and stays auto")
	assert_eq(editor.add_weapon(&"gatling_single", &"turret", &"auto", {"tile": 6, "face": true}).size(), 0, "one turret per tile")


func test_moving_a_turret_is_one_undo_step() -> void:
	var editor := HangarEditor.create(placement, _sample("starter"))
	var turret := editor.mount_index({"tile": 6, "face": true})
	assert_true(turret >= 0, "the starter carries a turret on its nose")
	assert_true(editor.move_mount(turret, {"tile": 4, "face": true}))
	assert_eq(editor.mount_index({"tile": 6, "face": true}), -1)
	assert_true(editor.mount_index({"tile": 4, "face": true}) >= 0)
	editor.undo()
	assert_true(editor.mount_index({"tile": 6, "face": true}) >= 0, "one undo puts it back")
	assert_false(editor.move_mount(editor.mount_index({"tile": 6, "face": true}), {"tile": 1, "face": true}), "not onto hull")


func test_gun_mounts_round_trip_through_json() -> void:
	var bp := _sample("gunboat")
	var errors: PackedStringArray = []
	var back := Blueprint.from_dict(JSON.parse_string(JSON.stringify(bp.to_dict())), errors)
	assert_eq(back.mounts, bp.mounts)
	assert_eq(typeof(back.mounts[7]["face"]), TYPE_BOOL)


# ── where guns can shoot ──────────────────────────────────────────────────────

func test_an_edge_gun_points_out_of_its_edge() -> void:
	var bp := _ship([[&"core", Vector2.ZERO], [&"hardpoint", Vector2(1, 0)]])
	bp.mounts.append(_edge_gun(bp, 1, Vector2.RIGHT, 1, &"fixed", &"auto"))
	var gun: GunLayout.Gun = GunLayout.compute(bp, placement).guns[0]
	assert_true(gun.pivot.is_equal_approx(Vector2(1.5, 0)), "pivot at the middle of its stretch")
	assert_almost_eq(gun.facing, 0.0)
	assert_almost_eq(gun.muzzle, lib.weapon(&"gatling_single")["length_u"])
	assert_true(gun.clear(0.0) and gun.auto)


func test_the_starter_turret_fires_over_the_hull_all_round() -> void:
	var layout := GunLayout.compute(_sample("starter"), placement)
	assert_eq(layout.guns.size(), 1)
	var gun := layout.guns[0]
	assert_almost_eq(gun.arc, PI)
	assert_eq(gun.blocked.size(), 0, "nothing blocks a top-mounted gun")
	assert_true(gun.clear(PI) and gun.clear(deg_to_rad(90)), "over the core behind it and the wedges beside it")
	assert_eq(layout.warnings, [] as Array[Dictionary])


func test_a_gun_facing_into_the_hull_is_warned() -> void:
	var bp := _ship([[&"core", Vector2.ZERO], [&"hardpoint", Vector2(0, -1)], [&"hull", Vector2(2, -1)]])
	bp.mounts.append(_edge_gun(bp, 1, Vector2.RIGHT, 1, &"fixed", &"auto"))
	var layout := GunLayout.compute(bp, placement)
	assert_false(layout.guns[0].clear(0.0), "the hull tile ahead is in the way")
	assert_eq(layout.warnings.size(), 1)
	assert_eq(layout.warnings[0]["code"], &"gun_blocked")


# ── fire control ──────────────────────────────────────────────────────────────

func test_a_shot_meets_a_still_target_at_distance_over_speed() -> void:
	assert_almost_eq(Gunnery.intercept_time(Vector2(20, 0), Vector2.ZERO, 40.0), 0.5)


func test_the_lead_meets_a_crossing_target() -> void:
	var rel_pos := Vector2(20, 5)
	var rel_vel := Vector2(-3, 10)
	var t := Gunnery.intercept_time(rel_pos, rel_vel, 40.0)
	assert_true(t > 0.0)
	assert_almost_eq((rel_pos + rel_vel * t).length(), 40.0 * t, 0.001, "the shot and the target arrive together")
	assert_eq(Gunnery.intercept_time(Vector2(20, 0), Vector2(50, 0), 40.0), -1.0, "it can't catch one that outruns it")


func test_an_auto_turret_turns_onto_its_target_then_fires() -> void:
	var gunnery := _gunnery(_sample("starter"))
	var target := [{"pos": Vector2(10, 6), "vel": Vector2.ZERO}]  # about 34° right of the nose turret
	var shots := gunnery.step(DT, Vector2.ZERO, 0.0, Vector2.ZERO, target, false)
	assert_eq(shots.size(), 0, "not on it yet")
	assert_almost_eq(gunnery.angles[0], lib.mount_type(&"turret")["turn_rate"] * DT, 0.0001, "turning at its rate")
	var total := 0
	for i in 60:
		total += gunnery.step(DT, Vector2.ZERO, 0.0, Vector2.ZERO, target, false).size()
	assert_almost_eq(gunnery.angles[0], (Vector2(10, 6) - Vector2(1, 0)).angle(), 0.01, "on the target")
	# 34° at 180°/s takes ~0.19 s; the rest of the second at 8 shots/s.
	assert_true(total >= 6 and total <= 8, "fired %d in a second" % total)


func test_a_manual_gun_fires_only_while_fire_is_held() -> void:
	var gunnery := _gunnery(_nose_gun(&"fixed", &"manual"))
	var ahead := [{"pos": Vector2(15, 0), "vel": Vector2.ZERO}]
	assert_eq(_run(gunnery, ahead, 0.5, false), 0, "a target alone doesn't fire it")
	assert_eq(_run(gunnery, ahead, 0.5, true), 4, "8 shots/s while held")
	assert_eq(_run(gunnery, [], 0.5, true), 4, "and it fires at nothing too")
	gunnery.all_auto = true
	assert_true(_run(gunnery, ahead, 0.5, false) >= 3, "1-stick: every gun fires on its own")


func test_an_auto_fixed_gun_waits_for_the_ship_to_point_at_the_target() -> void:
	var gunnery := _gunnery(_nose_gun(&"fixed", &"auto"))
	var target := [{"pos": Vector2.from_angle(deg_to_rad(30)) * 15.0, "vel": Vector2.ZERO}]
	assert_eq(_run(gunnery, target, 0.5, false), 0, "30° off the nose")
	var total := 0
	for i in 30:
		total += gunnery.step(DT, Vector2.ZERO, deg_to_rad(30), Vector2.ZERO, target, false).size()
	assert_true(total >= 3, "the ship turned onto it (%d shots)" % total)


func test_a_swivel_tracks_inside_its_arc_only() -> void:
	var gunnery := _gunnery(_nose_gun(&"swivel", &"auto"))
	var wide := [{"pos": Vector2.from_angle(deg_to_rad(60)) * 15.0, "vel": Vector2.ZERO}]
	assert_eq(_run(gunnery, wide, 0.5, false), 0)
	assert_eq(gunnery.aims[0], -1, "60° is outside ±22.5°")
	assert_almost_eq(gunnery.angles[0], 0.0, 0.0001, "so it rests straight ahead")
	var near := [{"pos": Vector2(1.5, 0) + Vector2.from_angle(deg_to_rad(15)) * 15.0, "vel": Vector2.ZERO}]
	assert_true(_run(gunnery, near, 0.5, false) > 0)
	assert_almost_eq(gunnery.angles[0], deg_to_rad(15), 0.01, "it swung 15° to follow")


func test_a_side_gun_never_fires_into_its_own_ship() -> void:
	var bp := _ship([[&"core", Vector2.ZERO], [&"hardpoint", Vector2(0, -1)], [&"hull", Vector2(2, -1)]])
	bp.mounts.append(_edge_gun(bp, 1, Vector2.RIGHT, 1, &"fixed", &"auto"))
	var gunnery := _gunnery(bp)
	assert_eq(_run(gunnery, [{"pos": Vector2(15, -1), "vel": Vector2.ZERO}], 1.0, false), 0, "the hull tile is in the way")
	assert_eq(gunnery.aims[0], -1)
	gunnery.layout.guns[0].auto = false
	assert_eq(_run(gunnery, [], 0.5, true), 0, "not even on FIRE")


func test_a_turret_fires_over_its_own_ship() -> void:
	var gunnery := _gunnery(_sample("starter"))
	assert_true(_run(gunnery, [{"pos": Vector2(-12, 0), "vel": Vector2.ZERO}], 1.0, false) > 0, "back over the core")


func test_the_lead_carries_the_shot_onto_a_moving_target_from_a_moving_ship() -> void:
	var gunnery := _gunnery(_nose_gun(&"swivel", &"auto"))
	var ship_vel := Vector2(0, 3)
	var target := {"pos": Vector2(16, 0), "vel": Vector2(-2, -1)}  # 4 U/s across the ship's line of travel
	var shot: Dictionary = {}
	var count := 0
	for i in 120:
		var shots := gunnery.step(DT, ship_vel * i * DT, 0.0, ship_vel, [_moved(target, i * DT)], false)
		count += shots.size()
		if count >= 3:  # the first may leave while the barrel is still swinging on (within fire_within)
			shot = shots[0]
			shot["at"] = i * DT
			break
	assert_false(shot.is_empty(), "it fired")
	# Fly the shot and the target forward together: how close do they get?
	var gap: Vector2 = shot["from"] - _moved(target, shot["at"])["pos"]
	var closing: Vector2 = shot["vel"] - target["vel"]
	var t := maxf(-gap.dot(closing) / closing.length_squared(), 0.0)
	var closest := (gap + closing * t).length()
	assert_true(closest < 0.05, "the shot passes %.3f U from the target" % closest)


func test_a_gun_keeps_its_aim_when_the_ship_loses_other_tiles() -> void:
	var bp := _sample("gunboat")
	var gunnery := _gunnery(bp)
	gunnery.angles[gunnery.layout.guns.size() - 1] = 1.0
	var survivor := bp.subset(_ids_without(bp, [7]))  # the top turret's tile goes
	gunnery.set_layout(GunLayout.compute(survivor, placement))
	assert_eq(gunnery.layout.guns.size(), 4, "one turret fewer")
	assert_almost_eq(gunnery.angles[3], 1.0, 0.0001, "the bottom turret kept its aim")


# ── helpers ───────────────────────────────────────────────────────────────────

## Fire control for `bp` with no spread, so a test can follow one shot.
func _gunnery(bp: Blueprint) -> Gunnery:
	var table: Dictionary = Data.table(&"weapons").duplicate(true)
	for weapon_id: String in table["weapons"]:
		table["weapons"][weapon_id]["spread_deg"] = [0, 0]
	placement.weapons = WeaponLib.from_table(table)
	return Gunnery.create(GunLayout.compute(bp, placement), placement.weapons)


func _run(gunnery: Gunnery, targets: Array, seconds: float, fire: bool) -> int:
	var total := 0
	for i in roundi(seconds / DT):
		total += gunnery.step(DT, Vector2.ZERO, 0.0, Vector2.ZERO, targets, fire).size()
	return total


func _moved(target: Dictionary, t: float) -> Dictionary:
	return {"pos": target["pos"] + target["vel"] * t, "vel": target["vel"]}


## A core with a hardpoint ahead and one gun on its front edge.
func _nose_gun(type: StringName, mode: StringName) -> Blueprint:
	var bp := _ship([[&"core", Vector2.ZERO], [&"hardpoint", Vector2(1, 0)]])
	bp.mounts.append(_edge_gun(bp, 1, Vector2.RIGHT, 1, type, mode))
	return bp


func _sample(id: String) -> Blueprint:
	var errors: PackedStringArray = []
	return Blueprint.from_dict(Data.json_dir("blueprints")[id], errors)


func _ids_without(bp: Blueprint, gone: Array) -> Dictionary:
	var ids := {}
	for tile in bp.tiles:
		if not gone.has(tile.id):
			ids[tile.id] = true
	return ids


func _mount_problems(bp: Blueprint) -> PackedStringArray:
	var out: PackedStringArray = []
	for problem in placement.validate(bp):
		if problem.code == &"mount":
			out.append(problem.message)
	return out


func _turret(tile_id: int) -> Dictionary:
	return {"tile": tile_id, "face": true, "part": "weapon.gatling_single", "mount": "turret", "mode": "auto"}


func _edge_gun(bp: Blueprint, tile_id: int, normal: Vector2, port: int, type: StringName, mode: StringName) -> Dictionary:
	return Mounting.moved_to({"part": "weapon.gatling_single", "mount": String(type), "mode": String(mode)},
			_slot(bp, tile_id, normal, port))


## The slot at `port` on `tile_id`'s edge facing `normal`.
func _slot(bp: Blueprint, tile_id: int, normal: Vector2, port: int) -> Dictionary:
	for edge in placement.tile_edges(bp.tile_by_id(tile_id)):
		if edge.normal.is_equal_approx(normal):
			return {"tile": tile_id, "edge": edge.index, "port": port}
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

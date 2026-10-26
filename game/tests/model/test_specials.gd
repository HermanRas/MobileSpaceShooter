extends TestCase
## Phase 4.6b: the laser (a beam that overheats), EMP (a burst that knocks out shields and
## thrusters) and mines (rear edges only, dropped behind, triggered by proximity).

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


func test_the_specials_load_with_their_roles() -> void:
	assert_eq(lib.errors, PackedStringArray())
	var damage := DamageTable.from_table(Data.table(&"damage_types"))
	var laser := lib.weapon(&"laser")
	assert_true(laser["beam"] and laser["damage_type"] == &"energy", "PLAN.md 4.4: an energy beam")
	assert_true(damage.vs_shield(laser["damage_type"]) > 1.0, "a shield breaker")
	var emp := lib.weapon(&"emp")
	assert_eq(emp["splash_type"], &"emp")
	assert_true(damage.disable_s(&"emp") > 0.0, "its burst knocks things out")
	assert_eq(emp["mounts"], [&"fixed", &"turret"], "PLAN.md 4.4: EMP is F / T")
	var mines := lib.weapon(&"mines")
	assert_eq(mines["mounts"], [&"fixed"], "PLAN.md 4.4: mines are a rear edge's fixed mount")
	assert_true(mines["rear_only"] and mines["proximity_u"] > 0.0 and mines["rocket"], "rear, proximity, shootable")


func test_every_gun_has_a_palette_family() -> void:
	assert_eq(lib.families(), PackedStringArray(["Guns", "Rockets", "Special"]))
	for weapon_id in lib.weapon_ids():
		assert_true(lib.families().has(lib.weapon(weapon_id)["family"]), "%s has a family" % weapon_id)


func test_a_laser_overheats_then_recovers() -> void:
	var gunnery := _gunnery(&"laser", &"fixed", &"manual", Vector2.RIGHT)
	var stats := lib.weapon(&"laser")
	var shots := _run(gunnery, stats["heat_s"] + 0.1, true)
	assert_true(gunnery.overheated[0], "overheated after heat_s of firing")
	assert_almost_eq(float(shots), stats["heat_s"] * stats["rate"], 2.0, "pulsing at its rate until then")
	assert_eq(_run(gunnery, 0.5, true), 0, "an overheated laser won't fire")
	assert_false(gunnery.beaming[0], "and shows no beam")
	_run(gunnery, stats["cool_s"] * (1.0 - stats["heat_resume"]) + 0.1, false)
	assert_false(gunnery.overheated[0], "cooled to heat_resume, it's ready")
	var pulses: Array[Dictionary] = []
	for i in 12:
		pulses.append_array(gunnery.step(DT, Vector2.ZERO, 0.0, Vector2.ZERO, [], true))
	assert_true(gunnery.beaming[0] and pulses.size() > 0, "firing again")
	assert_true(pulses.all(func(p: Dictionary) -> bool: return p["beam"]), "its shots are beam pulses, not projectiles")


func test_mines_only_go_on_rear_edges() -> void:
	var bp := _ship()
	var slots := Mounting.weapon_slots(placement, bp, &"mines", &"fixed")
	assert_true(slots.size() > 0)
	for slot in slots:
		assert_true(_normal(bp, slot).is_equal_approx(Vector2.LEFT), "slot faces the rear")
	var forward: Dictionary = Mounting.weapon_slots(placement, bp, &"gatling_single", &"fixed").filter(
			func(s: Dictionary) -> bool: return _normal(bp, s).is_equal_approx(Vector2.UP))[0]
	bp.mounts.append(Mounting.moved_to({"part": "weapon.mines", "mount": "fixed", "mode": "manual"}, forward))
	var problems := placement.validate(bp).map(func(p: Placement.Problem) -> String: return p.message)
	assert_true(problems.size() == 1 and "rear" in problems[0], "a mine layer facing sideways: %s" % [problems])


func test_mines_drop_behind_while_an_enemy_is_near() -> void:
	var gunnery := _gunnery(&"mines", &"fixed", &"auto", Vector2.LEFT)
	var stats := lib.weapon(&"mines")
	assert_eq(_run(gunnery, 1.0, false, [{"pos": Vector2(40, 0), "vel": Vector2.ZERO}]), 0, "nothing near: nothing dropped")
	var ahead := [{"pos": Vector2(8, 0), "vel": Vector2.ZERO}]  # in front, where no other gun would see it behind
	var shots: Array[Dictionary] = []
	for i in 90:
		shots.append_array(gunnery.step(DT, Vector2.ZERO, 0.0, Vector2.ZERO, ahead, false))
	assert_true(shots.size() >= 1, "an enemy within range_u: mines drop")
	if shots.is_empty():
		return
	assert_true((shots[0]["vel"] as Vector2).x < 0.0, "behind the ship")
	assert_almost_eq(shots[0]["life"], stats["life_s"], 0.0001, "they wait for life_s")
	assert_true(shots[0]["proximity_u"] > 0.0 and shots[0]["drag"] > 0.0)


func test_emp_bursts_where_its_target_is() -> void:
	var gunnery := _gunnery(&"emp", &"turret", &"auto", Vector2.ZERO)
	var shots: Array[Dictionary] = []
	for i in 120:
		shots.append_array(gunnery.step(DT, Vector2.ZERO, 0.0, Vector2.ZERO, [{"pos": Vector2(10, 0), "vel": Vector2.ZERO}], false))
	assert_true(shots.size() > 0)
	if not shots.is_empty():
		assert_true(shots[0]["airburst"] and shots[0]["splash_type"] == &"emp")
		assert_true(shots[0]["life"] < lib.weapon(&"emp")["range_u"] / lib.weapon(&"emp")["speed_u"], "fused short of full range")


## Fire control for one `weapon_id` on a hardpoint behind the core: on the edge facing `normal`,
## or on its face for a turret (normal ZERO).
func _gunnery(weapon_id: StringName, type: StringName, mode: StringName, normal: Vector2) -> Gunnery:
	var bp := _ship()
	for s: Dictionary in Mounting.weapon_slots(placement, bp, weapon_id, type):
		if s.has("face") or _normal(bp, s).is_equal_approx(normal):
			bp.mounts.append(Mounting.moved_to({"part": WeaponLib.part_id(weapon_id), "mount": String(type), "mode": String(mode)}, s))
			break
	assert_eq(bp.mounts.size(), 1, "%s mounted" % weapon_id)
	return Gunnery.create(GunLayout.compute(bp, placement), lib)


func _run(gunnery: Gunnery, seconds: float, fire: bool, targets: Array = []) -> int:
	var total := 0
	for i in roundi(seconds / DT):
		total += gunnery.step(DT, Vector2.ZERO, 0.0, Vector2.ZERO, targets, fire).size()
	return total


## A core with a hardpoint behind it (so it has rear, top, bottom and no front edge) and one ahead.
func _ship() -> Blueprint:
	var bp := Blueprint.new()
	bp.id = "test"
	for row: Array in [[0, &"core", Vector2.ZERO], [1, &"hardpoint", Vector2(-1, 0)], [2, &"hardpoint", Vector2(1, 0)]]:
		var tile := Blueprint.Tile.new()
		tile.id = row[0]
		tile.type = row[1]
		tile.shape = &"square"
		tile.size = &"L"
		tile.pos = row[2]
		tile.paint = Color.GRAY
		bp.tiles.append(tile)
	return bp


func _normal(bp: Blueprint, slot: Dictionary) -> Vector2:
	return placement.tile_edges(bp.tile_by_id(slot["tile"]))[slot["edge"]].normal

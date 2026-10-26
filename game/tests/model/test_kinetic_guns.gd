extends TestCase
## Phase 4.5: the kinetic guns (single gatling, multi gatling, cannon) on every mount they allow,
## the multi gatling's spin-up, and the cannon's armour piercing.

const DT := 1.0 / 60.0
const KINETIC: Array[StringName] = [&"gatling_single", &"gatling_multi", &"cannon"]

var placement: Placement
var lib: WeaponLib


func before_each() -> void:
	var tiles_table := Data.table(&"tiles")
	placement = Placement.create(ShapeLib.from_table(Data.table(&"shapes")),
			TileLib.from_table(tiles_table), tiles_table)
	placement.thrusters = ThrusterLib.from_table(Data.table(&"thrusters"))
	lib = WeaponLib.from_table(Data.table(&"weapons"))
	placement.weapons = lib


func test_every_kinetic_gun_mounts_and_fires_on_every_mount() -> void:
	assert_eq(lib.errors, PackedStringArray())
	for weapon_id in KINETIC:
		assert_eq(lib.weapon(weapon_id)["damage_type"], &"kinetic", "%s is kinetic" % weapon_id)
		for type: StringName in WeaponLib.MOUNT_TYPES:
			assert_true(lib.allows(weapon_id, type), "PLAN.md 4.4: %s goes on %s" % [weapon_id, type])
			var editor := HangarEditor.create(placement, _core_and_hardpoint())
			var slots := Mounting.weapon_slots(placement, editor.blueprint, weapon_id, type)
			var forward := slots.filter(func(s: Dictionary) -> bool:
				return s.has("face") or placement.tile_edges(editor.blueprint.tile_by_id(1))[s["edge"]].normal.x > 0.5)
			assert_true(forward.size() > 0, "%s on %s has a slot" % [weapon_id, type])
			if forward.is_empty():
				continue
			var mode := lib.mode_for(type, &"manual")
			assert_eq(editor.add_weapon(weapon_id, type, mode, forward[0]).size(), 1, "%s mounts on %s" % [weapon_id, type])
			assert_eq(placement.validate(editor.blueprint).size(), 0, "%s on %s is a valid ship" % [weapon_id, type])
			var gunnery := Gunnery.create(GunLayout.compute(editor.blueprint, placement), lib)
			var target := [{"pos": Vector2(12, 0), "vel": Vector2.ZERO}]
			var shots: Array[Dictionary] = []
			for i in 120:
				shots.append_array(gunnery.step(DT, Vector2.ZERO, 0.0, Vector2.ZERO, target, true))
			assert_true(shots.size() > 0, "%s on %s fires" % [weapon_id, type])
			if not shots.is_empty():
				assert_eq(shots[0]["damage"], lib.weapon(weapon_id)["damage"])


func test_the_multi_gatling_spins_up_and_winds_down() -> void:
	var gunnery := _gunnery(&"gatling_multi")
	var stats := lib.weapon(&"gatling_multi")
	var first := _shots(gunnery, 0.5, true)
	_shots(gunnery, stats["spin_up_s"], true)
	assert_almost_eq(gunnery.spins[0], 1.0, 0.0001, "fully spun after spin_up_s")
	var spun := _shots(gunnery, 0.5, true)
	assert_true(spun > first * 2, "it fires far faster spun up (%d vs %d in half a second)" % [spun, first])
	assert_almost_eq(float(spun), stats["rate"] * 0.5, 1.0, "at its top rate")
	_shots(gunnery, stats["spin_down_s"], false)
	assert_almost_eq(gunnery.spins[0], 0.0, 0.0001, "and winds down when it stops")


func test_the_single_gatling_doesnt_spin() -> void:
	var gunnery := _gunnery(&"gatling_single")
	assert_almost_eq(float(_shots(gunnery, 1.0, true)), lib.weapon(&"gatling_single")["rate"], 1.0)


func test_the_cannon_is_the_armour_breaker() -> void:
	var damage := DamageTable.from_table(Data.table(&"damage_types"))
	var armor: float = TileLib.from_table(Data.table(&"tiles")).tile(&"armor").stats(&"L")[&"armor"]
	var per_second := func(weapon_id: StringName) -> float:
		var stats := lib.weapon(weapon_id)
		return damage.tile_damage(stats["damage"], stats["damage_type"], armor, stats["pierce"]) * float(stats["rate"])
	var cannon := lib.weapon(&"cannon")
	assert_true(cannon["pierce"] > 0.0, "PLAN.md 4.4: armour-piercing")
	assert_true(cannon["rate"] < lib.weapon(&"gatling_single")["rate"], "slow")
	assert_true(per_second.call(&"cannon") > per_second.call(&"gatling_single") * 2.0,
			"against armor the cannon out-damages the gatling (%.0f vs %.0f a second)"
			% [per_second.call(&"cannon"), per_second.call(&"gatling_single")])
	assert_true(per_second.call(&"gatling_multi") > per_second.call(&"gatling_single"), "the multi gatling shreds once spun")


func _gunnery(weapon_id: StringName) -> Gunnery:
	var bp := _core_and_hardpoint()
	for s: Dictionary in Mounting.weapon_slots(placement, bp, weapon_id, &"fixed"):
		if placement.tile_edges(bp.tile_by_id(1))[s["edge"]].normal.x > 0.5:
			bp.mounts.append(Mounting.moved_to({"part": WeaponLib.part_id(weapon_id), "mount": "fixed", "mode": "manual"}, s))
			break
	return Gunnery.create(GunLayout.compute(bp, placement), lib)


func _shots(gunnery: Gunnery, seconds: float, fire: bool) -> int:
	var total := 0
	for i in roundi(seconds / DT):
		total += gunnery.step(DT, Vector2.ZERO, 0.0, Vector2.ZERO, [], fire).size()
	return total


func _core_and_hardpoint() -> Blueprint:
	var bp := Blueprint.new()
	bp.id = "test"
	for row: Array in [[0, &"core", Vector2.ZERO], [1, &"hardpoint", Vector2(1, 0)]]:
		var tile := Blueprint.Tile.new()
		tile.id = row[0]
		tile.type = row[1]
		tile.shape = &"square"
		tile.size = &"L"
		tile.pos = row[2]
		tile.paint = Color.GRAY
		bp.tiles.append(tile)
	return bp

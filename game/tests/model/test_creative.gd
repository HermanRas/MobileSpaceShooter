extends TestCase
## Phase 7.1: the Creative hangar has no stock, so nothing costs anything, and each gun carries
## its own level (L1 to the XP curve's top) on its mount. Only Creative flight reads it: an
## enemy's guns stay at its encounter level, and a pilot's at their XP.

var placement: Placement
var editor: HangarEditor


func before_each() -> void:
	var tiles_table := Data.table(&"tiles")
	placement = Placement.create(ShapeLib.from_table(Data.table(&"shapes")),
			TileLib.from_table(tiles_table), tiles_table)
	placement.thrusters = ThrusterLib.from_table(Data.table(&"thrusters"))
	placement.weapons = WeaponLib.from_table(Data.table(&"weapons"), Data.table(&"weapon_xp"))
	editor = HangarEditor.create(placement)


func test_anything_places_with_no_cost_check() -> void:
	for type: StringName in [&"hull", &"armor", &"shield", &"hardpoint"]:
		assert_eq(editor.place(type, &"square", &"L", Vector2(editor.blueprint.tiles.size(), 0), 0).size(), 1,
				"%s places with no stock" % type)
	assert_eq(editor.refusal, "", "and nothing is refused")


func test_a_creative_gun_keeps_its_own_level() -> void:
	var at := _turret(&"cannon", 250)
	assert_eq(int(editor.blueprint.mounts[at]["level"]), 250)
	var guns := GunLayout.compute(editor.blueprint, placement, 1, {}, 1.0, true)
	assert_eq(guns.guns[0].level, 250, "Creative flight flies it at L250")
	var at_l1 := GunLayout.compute(editor.blueprint, placement, 1)
	assert_true(float(guns.guns[0].stats["damage"]) > float(at_l1.guns[0].stats["damage"]) * 2.0,
			"and it hits much harder than at L1")


func test_levels_clamp_to_the_curve() -> void:
	var top := placement.weapons.xp.max_level
	var at := _turret(&"gatling_single", 5000)
	assert_eq(int(editor.blueprint.mounts[at]["level"]), top, "no higher than L%d" % top)
	assert_true(editor.set_gun_level(at, 0))
	assert_eq(int(editor.blueprint.mounts[at]["level"]), 1, "and no lower than L1")


func test_set_gun_level_is_one_undo_step() -> void:
	var at := _turret(&"laser", 10)
	assert_true(editor.set_gun_level(at, 500))
	assert_false(editor.set_gun_level(at, 500), "already there: no change, no undo step")
	editor.undo()
	assert_eq(int(editor.blueprint.mounts[at]["level"]), 10)


func test_only_creative_flight_reads_mount_levels() -> void:
	_turret(&"cannon", 250)
	var as_enemy := GunLayout.compute(editor.blueprint, placement, 40)
	assert_eq(as_enemy.guns[0].level, 40, "an enemy built from it fights at its encounter level")


func test_a_stocked_hangar_keeps_no_mount_level() -> void:
	editor.economy = Economy.from_table(Data.table(&"economy"))
	editor.stock = Inventory.new()
	editor.stock.wallet = {&"hull": 5000, &"alloy": 5000, &"tech": 5000, &"gc": 100000}
	var at := _turret(&"cannon", 250)
	assert_false(editor.blueprint.mounts[at].has("level"), "a pilot's gun levels by XP")
	assert_false(editor.set_gun_level(at, 300))


func _turret(weapon_id: StringName, level: int) -> int:
	var hardpoint := editor.place(&"hardpoint", &"square", &"L", Vector2(1, 0), 0)[0]
	var added := editor.add_weapon(weapon_id, &"turret", &"auto", {"tile": hardpoint, "face": true}, "", level)
	assert_eq(added.size(), 1, "the %s mounts" % weapon_id)
	return added[0]

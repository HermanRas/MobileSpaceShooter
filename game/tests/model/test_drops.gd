extends TestCase
## Phase 5.4: a kill drops what the enemy is built of, as pickups, and now and then one of its
## parts; the run's cargo is banked into the profile's stock (PLAN.md 4.6).

var placement: Placement
var economy: Economy


func before_each() -> void:
	var tiles_table := Data.table(&"tiles")
	placement = Placement.create(ShapeLib.from_table(Data.table(&"shapes")),
			TileLib.from_table(tiles_table), tiles_table)
	placement.thrusters = ThrusterLib.from_table(Data.table(&"thrusters"))
	placement.weapons = WeaponLib.from_table(Data.table(&"weapons"), Data.table(&"weapon_xp"))
	economy = Economy.from_table(Data.table(&"economy"))


func test_the_drop_table_loads_clean() -> void:
	assert_eq(economy.errors, PackedStringArray())
	assert_almost_eq(economy.part_chance, 0.04, 0.0001, "PLAN.md 4.6: a 4% part drop to start")


func test_an_all_shield_enemy_drops_mostly_crystal() -> void:
	var editor := HangarEditor.create(placement)
	var placed := 0
	for at: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		placed += editor.place(&"shield", &"square", &"L", at, 0).size()
	assert_true(placed >= 2, "shield tiles round the core (%d)" % placed)
	var loot := economy.kill_loot(placement, editor.blueprint, 1)
	var crystal := int(loot.get(&"crystal", 0))
	assert_true(crystal > 0, "it drops crystal (%s)" % [loot])
	for material: StringName in Inventory.MATERIALS:
		if material != &"crystal":
			assert_true(int(loot.get(material, 0)) < crystal, "more crystal than %s (%s)" % [material, loot])


func test_tech_comes_from_mounted_parts() -> void:
	var errors: PackedStringArray = []
	var wasp := Blueprint.from_dict(Data.json_dir("enemies")["wasp"], errors)
	var parts := wasp.mounts.filter(func(mount: Dictionary) -> bool:
		return Mounting.is_weapon(mount) or Mounting.is_thruster(mount)).size()
	assert_true(parts > 0, "the wasp has guns and thrusters")
	var built := Economy.tiles_cost(placement, wasp)
	var loot := economy.kill_loot(placement, wasp, 1)
	assert_eq(int(loot.get(&"tech", 0)), floori(int(built.get(&"tech", 0)) * economy.drop_share
			+ economy.drop_tech_per_part * parts + 1e-6), "a share of its hardpoints' tech, plus one a part")


func test_a_part_drops_only_under_the_chance() -> void:
	var errors: PackedStringArray = []
	var wasp := Blueprint.from_dict(Data.json_dir("enemies")["wasp"], errors)
	var barge := Blueprint.from_dict(Data.json_dir("enemies")["target_barge"], errors)
	assert_eq(economy.part_drop(placement, wasp, economy.part_chance, 0, 10), {}, "a roll at the chance drops nothing")
	assert_eq(economy.part_drop(placement, barge, 0.0, 0, 10), {}, "nor does a ship with no parts")
	var guns := 0
	var thrusters := 0
	var parts := wasp.mounts.filter(func(mount: Dictionary) -> bool:
		return Mounting.is_weapon(mount) or Mounting.is_thruster(mount))
	for pick in parts.size():
		var drop := economy.part_drop(placement, wasp, 0.0, pick, 30)
		if drop.has("gun"):
			guns += 1
			assert_eq(drop["xp"], placement.weapons.xp.xp_for(30), "a dropped gun keeps the XP it fought at")
			assert_true(placement.weapons.weapon(drop["gun"]).size() > 0, "and is a real weapon (%s)" % drop["gun"])
		else:
			thrusters += 1
			assert_eq(Inventory.thruster_parts(drop["thruster"]).size(), 3, "a thruster comes as its key")
	assert_true(guns > 0 and thrusters > 0, "either kind can drop (%d guns, %d thrusters)" % [guns, thrusters])


func test_loot_splits_into_a_few_pickups_and_nothing_is_lost() -> void:
	var pieces := economy.loot_pieces({&"hull": 7, &"gc": 2, &"tech": 1})
	var hull: Array = []
	var total := {}
	for piece in pieces:
		for resource: StringName in piece:
			total[resource] = int(total.get(resource, 0)) + int(piece[resource])
			if resource == &"hull":
				hull.append(piece[resource])
	assert_eq(hull, [3, 2, 2], "at most %d pieces, as even as whole numbers allow" % economy.drop_pieces)
	assert_eq(total, {&"hull": 7, &"gc": 2, &"tech": 1}, "every unit is in a pickup")
	assert_eq(pieces.size(), 3 + 2 + 1)


func test_cargo_banks_into_the_stock() -> void:
	var stock := Inventory.new()
	stock.wallet = {&"hull": 10}
	var mine := stock.new_gun(&"cannon", &"fixed")
	var cargo := Inventory.new()
	cargo.receive({&"hull": 5, &"crystal": 3})
	cargo.add_found_gun(&"laser", &"turret", 640)
	cargo.add_thrusters(Inventory.thruster_key(&"chemical", &"M", 1), 1)
	assert_false(cargo.is_empty())
	stock.bank(cargo)
	assert_eq(stock.wallet, {&"hull": 15, &"crystal": 3}, "materials add up")
	assert_eq(stock.guns.size(), 2, "the found gun joins the stock")
	var found: Inventory.GunItem = null
	for id: String in stock.guns:
		if id != mine.id:
			found = stock.guns[id]
	assert_true(found != null and found.weapon == &"laser" and found.xp == 640 and found.mount == &"turret",
			"with its weapon, mount and XP")
	assert_eq(stock.thrusters, {"chemical:M:1": 1}, "a found thruster is loose in the stock")
	assert_true(cargo.is_empty(), "and the cargo hold is empty after")

extends TestCase
## Phase 7.3: a library ship bought in the shop replaces the pilot's ship. The old one is traded
## in (tiles refunded 1:1, parts into the inventory), and the new one takes loose parts first and
## buys the rest, so what it costs is exactly what building it by hand would.

const START := {&"hull": 5000, &"alloy": 2000, &"crystal": 1000, &"tech": 1000, &"gc": 30000}

var placement: Placement
var editor: HangarEditor
var samples: Dictionary


func before_each() -> void:
	var tiles_table := Data.table(&"tiles")
	placement = Placement.create(ShapeLib.from_table(Data.table(&"shapes")),
			TileLib.from_table(tiles_table), tiles_table)
	placement.thrusters = ThrusterLib.from_table(Data.table(&"thrusters"))
	placement.weapons = WeaponLib.from_table(Data.table(&"weapons"), Data.table(&"weapon_xp"))
	samples = Data.json_dir("blueprints")
	editor = HangarEditor.create(placement, _sample("starter"))
	editor.economy = Economy.from_table(Data.table(&"economy"))
	editor.stock = Inventory.new()
	editor.stock.wallet = START.duplicate()
	for mount in editor.blueprint.mounts:
		if Mounting.is_weapon(mount):
			mount["gun"] = editor.stock.new_gun(WeaponLib.type_of_part(str(mount["part"])), StringName(mount["mount"])).id


func test_the_build_cost_is_the_tiles_and_every_part() -> void:
	var bp := _sample("starter")
	var parts := 3 * _price({"part": "thruster.pulse", "size": "L", "level": 1}) + _price({"part": "weapon.gatling_single"})
	assert_eq(Economy.build_cost(placement, bp), Economy.add(Economy.tiles_cost(placement, bp), {&"gc": parts}))


func test_a_swap_pays_the_difference_and_reuses_what_it_can() -> void:
	var gunboat := _sample("gunboat")
	var old_gun := str(editor.blueprint.mounts.filter(Mounting.is_weapon)[0]["gun"])
	editor.stock.guns[old_gun].xp = 900
	var quote := editor.quote_swap(gunboat)
	assert_eq(quote["refusal"], "")
	assert_eq(editor.stock.wallet, START, "a quote spends nothing")
	assert_true(editor.swap_to(gunboat))
	assert_eq(editor.blueprint.tiles.size(), gunboat.tiles.size(), "the ship is the gunboat now")
	var materials := Economy.add(Economy.tiles_cost(placement, gunboat), Economy.tiles_cost(placement, _sample("starter")), -1)
	var reused := 2 * _price({"part": "thruster.pulse", "size": "L", "level": 1}) + _price({"part": "weapon.gatling_single"})
	var expected := Economy.add(materials, {&"gc": int(Economy.build_cost(placement, gunboat)[&"gc"]) - reused})
	for resource: StringName in START:
		assert_eq(START[resource] - editor.stock.amount(resource), int(expected.get(resource, 0)), "%s paid" % resource)
		assert_eq(int(quote["pay"].get(resource, 0)), int(expected.get(resource, 0)), "%s quoted" % resource)
	assert_true(Inventory.fitted_ids(editor.blueprint).has(old_gun), "the starter's gatling moved over")
	assert_eq(editor.stock.guns[old_gun].xp, 900, "with its XP")
	assert_eq(editor.stock.thrusters, {Inventory.thruster_key(&"pulse", &"L", 1): 1}, "the third pulse thruster is loose")
	assert_eq(editor.blueprint.mounts.filter(Mounting.is_weapon).filter(func(m: Dictionary) -> bool:
			return not editor.stock.guns.has(str(m.get("gun", "")))), [], "every gun is an inventory item")


func test_one_undo_gives_the_old_ship_back() -> void:
	var before := editor.blueprint.to_dict()
	editor.swap_to(_sample("gunboat"))
	assert_true(editor.undo())
	assert_eq(editor.blueprint.to_dict(), before)
	assert_eq(editor.stock.wallet, START)


func test_a_swap_you_cant_afford_changes_nothing() -> void:
	editor.stock.wallet[&"gc"] = 100
	var before := editor.blueprint.to_dict()
	assert_eq(editor.quote_swap(_sample("gunboat"))["refusal"], "Not enough GC")
	assert_false(editor.swap_to(_sample("gunboat")))
	assert_eq(editor.refusal, "Not enough GC")
	assert_eq(editor.blueprint.to_dict(), before, "the old ship stays")
	assert_eq(editor.stock.amount(&"gc"), 100)
	assert_false(editor.can_undo(), "and there's nothing to undo")


func test_creative_levels_and_foreign_gun_ids_dont_come_along() -> void:
	var design := _sample("gunboat")
	design.tags.append(Blueprint.PUBLISHED)
	for mount in design.mounts:
		if Mounting.is_weapon(mount):
			mount["level"] = 999
			mount["gun"] = "g77"
	assert_true(editor.swap_to(design))
	for mount in editor.blueprint.mounts.filter(Mounting.is_weapon):
		assert_false(mount.has("level"), "no Creative level")
		assert_true(editor.stock.guns.has(str(mount["gun"])) and str(mount["gun"]) != "g77", "its own gun item")
	assert_false(editor.blueprint.tags.has(Blueprint.PUBLISHED), "the pilot's ship isn't for sale")
	assert_true(editor.blueprint.mounts.filter(Mounting.is_thruster).all(func(m: Dictionary) -> bool:
			return m.has("level")), "thrusters keep their level")


func test_creative_cant_swap() -> void:
	var creative := HangarEditor.create(placement)
	assert_false(creative.swap_to(_sample("gunboat")))
	assert_ne(creative.quote_swap(_sample("gunboat"))["refusal"], "")


func _sample(id: String) -> Blueprint:
	var errors: PackedStringArray = []
	return Blueprint.from_dict(samples[id], errors)


func _price(mount: Dictionary) -> int:
	return int(Economy.part_price(placement, mount)[&"gc"])

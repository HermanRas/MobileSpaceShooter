extends TestCase
## Phase 7.3, owned ships (owner, 2026-10-28): buying a library ship parks the one being flown,
## parts and all; the new one takes loose parts first and buys the rest. A parked ship can be
## flown again, and the flown ship sold (like Remove) while another is owned.

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


func test_buying_parks_the_old_ship_and_pays_the_full_cost() -> void:
	var gunboat := _sample("gunboat")
	var starter := editor.blueprint.to_dict()
	var old_gun := _gun_on(editor.blueprint)
	var quote := editor.quote_buy(gunboat)
	assert_eq(quote["refusal"], "")
	assert_eq(editor.stock.wallet, START, "a quote spends nothing")
	assert_true(editor.buy_ship(gunboat))
	assert_eq(editor.blueprint.tiles.size(), gunboat.tiles.size(), "the gunboat is flown now")
	var cost := Economy.build_cost(placement, gunboat)
	for resource: StringName in START:
		assert_eq(START[resource] - editor.stock.amount(resource), int(cost.get(resource, 0)), "%s paid" % resource)
		assert_eq(int(quote["pay"].get(resource, 0)), int(cost.get(resource, 0)), "%s quoted" % resource)
	assert_eq(editor.parked.size(), 1, "the starter is parked")
	assert_eq(editor.parked[0]["ship"], starter, "as it was")
	assert_false(editor.stock.guns.has(old_gun), "its gun left the inventory with it")
	assert_eq(editor.stock.thrusters, {}, "and its thrusters stayed on it")
	assert_false(editor.can_undo(), "buying isn't an undo step")


func test_a_bought_ship_takes_loose_parts_first() -> void:
	var spare := editor.stock.new_gun(&"gatling_single", &"turret")
	spare.xp = 900
	editor.stock.add_thrusters(Inventory.thruster_key(&"pulse", &"M", 1), 1)
	assert_true(editor.buy_ship(_sample("gunboat")))
	assert_true(Inventory.fitted_ids(editor.blueprint).has(spare.id), "the loose gatling is fitted")
	assert_eq(editor.stock.guns[spare.id].xp, 900, "with its XP")
	assert_eq(editor.stock.thrusters, {}, "and the loose thruster")
	var saved := _price({"part": "weapon.gatling_single"}) + _price({"part": "thruster.pulse", "size": "M", "level": 1})
	assert_eq(START[&"gc"] - editor.stock.amount(&"gc"), int(Economy.build_cost(placement, _sample("gunboat"))[&"gc"]) - saved)


func test_a_parked_ship_comes_back_as_it_was() -> void:
	var starter := editor.blueprint.to_dict()
	var old_gun := _gun_on(editor.blueprint)
	editor.stock.guns[old_gun].xp = 1234
	editor.buy_ship(_sample("gunboat"))
	var gunboat := editor.blueprint.to_dict()
	assert_true(editor.fly_parked(0))
	assert_eq(editor.blueprint.to_dict(), starter, "flying the starter again")
	assert_eq(editor.stock.guns[old_gun].xp, 1234, "its gun is back, XP and all")
	assert_eq(editor.parked.size(), 1)
	assert_eq(editor.parked[0]["ship"], gunboat, "and the gunboat is parked")
	assert_true(editor.fly_parked(0))
	assert_eq(editor.blueprint.to_dict(), gunboat, "back and forth")
	assert_false(editor.fly_parked(3), "no such ship")


func test_selling_needs_another_ship_and_works_like_remove() -> void:
	assert_false(editor.sell_ship(), "not your only ship")
	editor.buy_ship(_sample("gunboat"))
	var wallet: Dictionary = editor.stock.wallet.duplicate()
	var guns := Inventory.fitted_ids(editor.blueprint).keys()
	var tiles := Economy.tiles_cost(placement, editor.blueprint)
	assert_true(editor.sell_ship())
	for material: StringName in tiles:
		assert_eq(editor.stock.amount(material) - int(wallet.get(material, 0)), int(tiles[material]), "%s refunded 1:1" % material)
	assert_eq(editor.stock.amount(&"gc"), int(wallet[&"gc"]), "parts aren't sold for GC")
	for id: String in guns:
		assert_true(editor.stock.loose_guns(editor.blueprint).any(func(g: Inventory.GunItem) -> bool: return g.id == id),
				"its guns are loose in the inventory")
	assert_eq(editor.stock.thrusters, {Inventory.thruster_key(&"pulse", &"L", 1): 2, Inventory.thruster_key(&"pulse", &"M", 1): 2},
			"and its thrusters")
	assert_eq(editor.blueprint.name, "Starter", "the parked starter is flown")
	assert_eq(editor.parked.size(), 0)


func test_a_ship_you_cant_afford_changes_nothing() -> void:
	editor.stock.wallet[&"gc"] = 100
	var before := editor.blueprint.to_dict()
	var stock_before := editor.stock.to_dict()
	assert_eq(editor.quote_buy(_sample("gunboat"))["refusal"], "Not enough GC")
	assert_false(editor.buy_ship(_sample("gunboat")))
	assert_eq(editor.refusal, "Not enough GC")
	assert_eq(editor.blueprint.to_dict(), before, "the old ship stays")
	assert_eq(editor.stock.to_dict(), stock_before, "its gun and the wallet too")
	assert_eq(editor.parked.size(), 0, "nothing parked")
	assert_false(editor.can_undo(), "and there's nothing to undo")


func test_creative_levels_and_foreign_gun_ids_dont_come_along() -> void:
	var design := _sample("gunboat")
	design.tags.append(Blueprint.PUBLISHED)
	for mount in design.mounts:
		if Mounting.is_weapon(mount):
			mount["level"] = 999
			mount["gun"] = "g77"
	assert_true(editor.buy_ship(design))
	for mount in editor.blueprint.mounts.filter(Mounting.is_weapon):
		assert_false(mount.has("level"), "no Creative level")
		assert_true(editor.stock.guns.has(str(mount["gun"])) and str(mount["gun"]) != "g77", "its own gun item")
	assert_false(editor.blueprint.tags.has(Blueprint.PUBLISHED), "the pilot's ship isn't for sale")
	assert_true(editor.blueprint.mounts.filter(Mounting.is_thruster).all(func(m: Dictionary) -> bool:
			return m.has("level")), "thrusters keep their level")


func test_creative_cant_buy() -> void:
	var creative := HangarEditor.create(placement)
	assert_false(creative.buy_ship(_sample("gunboat")))
	assert_ne(creative.quote_buy(_sample("gunboat"))["refusal"], "")


func _sample(id: String) -> Blueprint:
	var errors: PackedStringArray = []
	return Blueprint.from_dict(samples[id], errors)


func _gun_on(bp: Blueprint) -> String:
	return str(bp.mounts.filter(Mounting.is_weapon)[0]["gun"])


func _price(mount: Dictionary) -> int:
	return int(Economy.part_price(placement, mount)[&"gc"])

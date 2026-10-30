extends TestCase
## Phase 4.8a: building outside Creative pays from the profile's stock. Tiles cost materials and
## come back 1:1, parts go in and out of the inventory, Sell pays 75% rounded down, and undo
## keeps the books straight (PLAN.md 4.6).

const START := {&"hull": 5000, &"alloy": 2000, &"crystal": 1000, &"tech": 1000, &"gc": 30000}

var placement: Placement
var editor: HangarEditor


func before_each() -> void:
	var tiles_table := Data.table(&"tiles")
	placement = Placement.create(ShapeLib.from_table(Data.table(&"shapes")),
			TileLib.from_table(tiles_table), tiles_table)
	placement.thrusters = ThrusterLib.from_table(Data.table(&"thrusters"))
	placement.weapons = WeaponLib.from_table(Data.table(&"weapons"))
	editor = HangarEditor.create(placement)
	editor.economy = Economy.from_table(Data.table(&"economy"))
	editor.stock = Inventory.new()
	editor.stock.wallet = START.duplicate()


func test_the_economy_table_loads_clean() -> void:
	assert_eq(editor.economy.errors, PackedStringArray())
	assert_almost_eq(editor.economy.sell_rate, 0.75, 0.0001, "owner, 2026-10-26: Sell pays 75%")


func test_a_tile_costs_its_materials_and_comes_back_one_for_one() -> void:
	var ids := editor.place(&"armor", &"square", &"L", Vector2(1, 0), 0)
	assert_eq(_spent(), {&"hull": 80, &"alloy": 120})
	editor.remove(ids[0])
	assert_eq(_spent(), {})


func test_a_tile_you_cant_afford_is_refused() -> void:
	editor.stock.wallet[&"alloy"] = 119
	assert_eq(editor.place(&"armor", &"square", &"L", Vector2(1, 0), 0).size(), 0)
	assert_eq(editor.refusal, "Not enough alloy")
	assert_eq(editor.blueprint.tiles.size(), 1, "nothing placed")
	assert_false(editor.can_undo(), "and nothing to undo")


func test_a_bought_gun_goes_in_the_inventory_and_reinstalls_free() -> void:
	var hardpoint := _hardpoint()
	var price: int = placement.weapons.weapon(&"gatling_single")["price_gc"]
	var before := editor.stock.amount(&"gc")
	editor.add_weapon(&"gatling_single", &"turret", &"auto", {"tile": hardpoint, "face": true})
	assert_eq(editor.stock.amount(&"gc"), before - price, "bought")
	var id := str(editor.blueprint.mounts[0]["gun"])
	assert_true(editor.stock.guns.has(id), "an item in the inventory, fitted")
	assert_eq(editor.stock.loose_guns(editor.blueprint).size(), 0)
	editor.stock.guns[id].xp = 1234
	editor.remove_mount(0)
	assert_eq(editor.stock.loose_guns(editor.blueprint).map(func(g: Inventory.GunItem) -> String: return g.id), [id],
			"removed: loose in the inventory")
	editor.add_weapon(&"gatling_single", &"turret", &"auto", {"tile": hardpoint, "face": true}, id)
	assert_eq(editor.stock.amount(&"gc"), before - price, "reinstalling is free")
	assert_eq(str(editor.blueprint.mounts[0]["gun"]), id)
	assert_eq(editor.stock.guns[id].xp, 1234, "it kept its XP")


func test_a_thruster_round_trips_through_the_inventory() -> void:
	_hardpoint()
	var slot: Dictionary = Mounting.thruster_slots(placement, editor.blueprint, &"S")[0]
	var price: int = placement.thrusters.spec(&"pulse", &"S", 1)["price_gc"]
	editor.add_thruster(&"pulse", &"S", 1, slot)
	assert_eq(_spent(), Economy.add(_hardpoint_cost(), {&"gc": price}))
	editor.remove_mount(0)
	assert_eq(editor.stock.thrusters, {"pulse:S:1": 1})
	assert_eq(editor.add_thruster(&"pulse", &"S", 1, slot, true).size(), 1)
	assert_eq(editor.stock.thrusters, {}, "taken back out")
	assert_eq(_spent(), Economy.add(_hardpoint_cost(), {&"gc": price}), "free the second time")
	editor.remove_mount(0)
	assert_eq(editor.add_thruster(&"pulse", &"M", 1, slot, true).size(), 0, "none of that size in stock")
	assert_eq(editor.refusal, "None left in the inventory")


func test_sell_pays_three_quarters_rounded_down() -> void:
	var hardpoint := _hardpoint()
	var slot: Dictionary = Mounting.thruster_slots(placement, editor.blueprint, &"S")[0]
	editor.add_thruster(&"pulse", &"S", 1, slot)
	var price: int = placement.thrusters.spec(&"pulse", &"S", 1)["price_gc"]
	assert_eq(price, 150, "pulse L1 is 600 GC Large, a quarter of that Small")
	var gc := editor.stock.amount(&"gc")
	assert_true(editor.sell_mount(0))
	assert_eq(editor.stock.amount(&"gc"), gc + 112, "75% of 150 is 112.5: 112")
	assert_eq(editor.stock.thrusters, {}, "sold, not kept")
	editor.add_weapon(&"cannon", &"turret", &"auto", {"tile": hardpoint, "face": true})
	var id := str(editor.blueprint.mounts[0]["gun"])
	editor.remove_mount(0)
	gc = editor.stock.amount(&"gc")
	assert_true(editor.sell_gun(id))
	assert_eq(editor.stock.amount(&"gc"), gc + 3150, "a loose 4200 GC cannon sells for 3150")
	assert_false(editor.stock.guns.has(id))


func test_reinstalling_on_another_mount_type_is_a_paid_refit() -> void:
	var hardpoint := _hardpoint()
	editor.add_weapon(&"gatling_single", &"turret", &"auto", {"tile": hardpoint, "face": true})
	var id := str(editor.blueprint.mounts[0]["gun"])
	editor.remove_mount(0)
	var spent := _spent()
	var slot: Dictionary = Mounting.weapon_slots(placement, editor.blueprint, &"gatling_single", &"fixed")[0]
	editor.add_weapon(&"gatling_single", &"fixed", &"manual", slot, id)
	assert_eq(_spent(), Economy.add(spent, editor.economy.refit), "refit: Alloy + Tech")
	assert_eq(editor.stock.guns[id].mount, &"fixed")


func test_undo_and_redo_restore_the_wallet_and_the_items() -> void:
	var hardpoint := _hardpoint()
	var after_tile := editor.stock.to_dict()
	editor.add_weapon(&"laser", &"turret", &"auto", {"tile": hardpoint, "face": true})
	var after_gun := editor.stock.to_dict()
	editor.undo()
	assert_eq(editor.stock.to_dict(), after_tile, "undo: GC back, no gun")
	editor.redo()
	assert_eq(editor.stock.to_dict(), after_gun)
	assert_true(editor.sell_mount(0))
	editor.undo()
	assert_eq(editor.stock.to_dict(), after_gun, "an undone sale is unsold")


func test_mirror_pays_for_both_and_takes_only_what_the_inventory_has() -> void:
	editor.mirror = true
	var ids := editor.place(&"hardpoint", &"square", &"L", Vector2(0, -1), 0)
	assert_eq(ids.size(), 2)
	assert_eq(_spent(), Economy.add({}, _hardpoint_cost(), 2), "two hardpoints")
	editor.mirror = false
	editor.add_weapon(&"flak", &"turret", &"auto", {"tile": ids[0], "face": true})
	editor.remove_mount(0)
	editor.mirror = true
	var gc := editor.stock.amount(&"gc")
	var id := str(editor.stock.guns.keys()[0])
	assert_eq(editor.add_weapon(&"flak", &"turret", &"auto", {"tile": ids[0], "face": true}, id).size(), 1,
			"one flak in the inventory: its twin is left off")
	assert_eq(editor.stock.amount(&"gc"), gc)
	editor.remove_mount(0)
	assert_eq(editor.add_weapon(&"flak", &"turret", &"auto", {"tile": ids[0], "face": true}).size(), 2, "bought: a pair")
	assert_eq(editor.stock.amount(&"gc"), gc - 2 * int(placement.weapons.weapon(&"flak")["price_gc"]))
	assert_eq(editor.stock.loose_guns(editor.blueprint).size(), 1, "the first flak is still loose")


func test_removing_a_tile_puts_its_parts_in_the_inventory() -> void:
	var hardpoint := _hardpoint()
	editor.add_thruster(&"jet", &"S", 2, Mounting.thruster_slots(placement, editor.blueprint, &"S")[0])
	editor.add_weapon(&"emp", &"turret", &"auto", {"tile": hardpoint, "face": true})
	var parts := Economy.add({}, _spent())
	editor.remove(hardpoint)
	assert_eq(_spent(), {&"gc": parts[&"gc"]}, "the hardpoint's materials are back, the parts' GC isn't")
	assert_eq(editor.stock.thrusters, {"jet:S:2": 1})
	assert_eq(editor.stock.loose_guns(editor.blueprint).size(), 1)


func test_stripping_and_rebuilding_the_starter_leaves_the_materials_where_they_started() -> void:
	var errors: PackedStringArray = []
	var starter := Blueprint.from_dict(Data.json_dir("blueprints")["starter"], errors)
	for mount in starter.mounts:
		if Mounting.is_weapon(mount):
			mount["gun"] = editor.stock.new_gun(WeaponLib.type_of_part(str(mount["part"])), StringName(mount["mount"])).id
	editor.load_blueprint(starter)
	var plan := Blueprint.from_dict(starter.to_dict(), errors)
	for tile in plan.tiles:
		if tile.type != placement.tiles.core_id():
			assert_true(editor.remove(tile.id), "removed tile %d" % tile.id)
	assert_eq(editor.blueprint.mounts.size(), 0, "stripped")
	assert_eq(editor.stock.amount(&"hull"), START[&"hull"] + int(Economy.tiles_cost(placement, plan)[&"hull"]))
	var new_ids := {}
	for tile in plan.tiles:
		if tile.type != placement.tiles.core_id():
			new_ids[tile.id] = editor.place(tile.type, tile.shape, tile.size, tile.pos, tile.rot)[0]
		else:
			new_ids[tile.id] = tile.id
	for mount in plan.mounts:
		var slot := mount.duplicate()
		slot["tile"] = new_ids[int(mount["tile"])]
		var added: PackedInt32Array
		if Mounting.is_weapon(mount):
			added = editor.add_weapon(WeaponLib.type_of_part(str(mount["part"])), StringName(mount["mount"]),
					StringName(mount["mode"]), slot, str(mount["gun"]))
		else:
			added = editor.add_thruster(ThrusterLib.type_of_part(str(mount["part"])), StringName(mount["size"]),
					int(mount["level"]), slot, true)
		assert_eq(added.size(), 1, "remounted %s" % mount["part"])
	assert_eq(editor.stock.wallet, START, "every material and GC back where it started")
	assert_eq(editor.stock.thrusters, {}, "every thruster back on")
	assert_eq(editor.stock.loose_guns(editor.blueprint).size(), 0, "and every gun")


func test_an_inventory_round_trips_through_json() -> void:
	editor.stock.new_gun(&"cannon", &"swivel").xp = 77
	editor.stock.add_thrusters(Inventory.thruster_key(&"ion", &"M", 3), 2)
	var errors: PackedStringArray = []
	var copy := Inventory.from_dict(JSON.parse_string(JSON.stringify(editor.stock.to_dict())), errors)
	assert_eq(errors, PackedStringArray())
	assert_eq(copy.to_dict(), editor.stock.to_dict())
	assert_eq(copy.new_gun(&"flak", &"fixed").id, "g2", "new ids carry on after the saved ones")


func test_the_market_buys_dear_and_sells_cheap() -> void:
	var market := editor.economy.market
	assert_eq(market.keys().size(), 4, "all four materials trade (PLAN.md 4.6)")
	for material: StringName in market:
		assert_true(market[material]["buy"] > market[material]["sell"], "%s: buying costs more than selling earns" % material)
	assert_true(editor.trade(&"alloy", 10))
	assert_eq(_spent(), {&"alloy": -10, &"gc": market[&"alloy"]["buy"] * 10})
	assert_true(editor.trade(&"alloy", -10))
	assert_eq(_spent(), {&"gc": (market[&"alloy"]["buy"] - market[&"alloy"]["sell"]) * 10}, "a round trip loses the spread")
	editor.undo()
	editor.undo()
	assert_eq(_spent(), {}, "trades are undo steps")


func test_the_market_wont_trade_what_you_dont_have() -> void:
	editor.stock.wallet[&"gc"] = 1
	assert_false(editor.trade(&"tech", 1))
	assert_eq(editor.refusal, "Not enough GC")
	assert_false(editor.trade(&"hull", -START[&"hull"] - 1))
	assert_eq(editor.refusal, "Not enough hull")
	assert_false(editor.can_undo(), "a refused trade isn't a step")


func test_a_kill_pays_a_share_of_what_the_enemy_is_built_of() -> void:
	var errors: PackedStringArray = []
	var barge := Blueprint.from_dict(Data.json_dir("enemies")["target_barge"], errors)
	var built := Economy.tiles_cost(placement, barge)
	var loot := editor.economy.kill_loot(placement, barge, 1)
	assert_true(loot.has(&"crystal") and not loot.has(&"tech"), "a barge with shields and no hardpoints drops crystal, not tech")
	assert_eq(loot[&"hull"], floori(built[&"hull"] * editor.economy.drop_share), "a share of its hull")
	assert_true(loot[&"gc"] > 0, "and some GC")
	var tougher := editor.economy.kill_loot(placement, barge, 10)
	assert_true(tougher[&"hull"] > loot[&"hull"] and tougher[&"gc"] > loot[&"gc"], "a higher encounter level pays more")


func test_creative_builds_for_free() -> void:
	editor.stock = null
	editor.place(&"hardpoint", &"square", &"L", Vector2(1, 0), 0)
	editor.add_weapon(&"laser", &"turret", &"auto", {"tile": 1, "face": true})
	assert_false(editor.blueprint.mounts[0].has("gun"), "no items in Creative")
	assert_false(editor.sell_mount(0), "and nothing to sell")


## A Large hardpoint ahead of the core; its id.
func _hardpoint() -> int:
	return editor.place(&"hardpoint", &"square", &"L", Vector2(1, 0), 0)[0]


func _hardpoint_cost() -> Dictionary:
	return placement.tiles.tile(&"hardpoint").cost(&"L")


## What's left the wallet since START, leaving out what hasn't changed.
func _spent() -> Dictionary:
	var out := {}
	for resource: StringName in START:
		var gone: int = START[resource] - editor.stock.amount(resource)
		if gone != 0:
			out[resource] = gone
	return out


func test_the_shortfall_says_what_is_missing() -> void:
	var stock := Inventory.new()
	stock.receive({&"hull": 30, &"gc": 500})
	assert_eq(stock.shortfall({&"hull": 70, &"alloy": 12, &"gc": 100}), {&"hull": 40, &"alloy": 12})
	assert_eq(stock.shortfall({&"hull": 30}), {}, "exactly enough is enough")
	assert_eq(Inventory.cost_text({&"gc": 300, &"alloy": 12, &"hull": 40}), "40 hull 12 alloy 300 GC", "materials first, GC last")

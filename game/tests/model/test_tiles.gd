extends TestCase
## Phase 1.2: tile definitions (PLAN.md 4.2).

var lib: TileLib


func before_each() -> void:
	lib = TileLib.from_table(Data.table(&"tiles"))


func test_shipped_tiles_load_cleanly() -> void:
	assert_eq(lib.errors.size(), 0, ", ".join(lib.errors))
	assert_eq(lib.tile_ids(), [&"armor", &"core", &"hardpoint", &"hull", &"shield"])
	assert_eq(lib.core_id(), &"core")


func test_medium_stats_are_half_of_large() -> void:
	var large := lib.tile(&"armor").stats(&"L")
	var medium := lib.tile(&"armor").stats(&"M")
	assert_almost_eq(medium[&"hp"], large[&"hp"] * 0.5)
	assert_almost_eq(medium[&"mass"], large[&"mass"] * 0.5)


func test_armor_does_not_shrink_with_size() -> void:
	assert_almost_eq(lib.tile(&"armor").stats(&"S")[&"armor"], lib.tile(&"armor").stats(&"L")[&"armor"])


func test_shield_capacity_scales() -> void:
	assert_almost_eq(lib.tile(&"shield").stats(&"S")[&"shield_cap"], 15.0)


func test_every_tile_needs_hull_except_the_core() -> void:
	# D5: every tile is built on Hull; the others add their own material.
	for tile_id in lib.tile_ids():
		var cost := lib.tile(tile_id).cost(&"L")
		if tile_id == lib.core_id():
			assert_true(cost.is_empty(), "the core is free")
		else:
			assert_true(cost.get(&"hull", 0) > 0, "%s needs hull" % tile_id)
	assert_eq(lib.tile(&"hardpoint").cost(&"L"), {&"hull": 8, &"alloy": 8, &"tech": 4})


func test_small_costs_are_whole() -> void:
	assert_eq(lib.tile(&"hull").cost(&"S"), {&"hull": 3})
	assert_eq(lib.tile(&"hardpoint").cost(&"S"), {&"hull": 2, &"alloy": 2, &"tech": 1})


func test_bad_tables_are_rejected() -> void:
	var table := {
		"size_cost_factor": {"S": 0.25, "L": 1.0}, "size_stat_factor": {"S": 0.25, "L": 1.0},
		"materials": ["hull"],
		"tiles": {
			"a": {"hp": 1, "armor": 0, "shield_cap": 0, "shield_regen": 0, "mass": 1, "cost": {"hull": 10}},
			"b": {"hp": 1, "armor": 0, "shield_cap": 0, "shield_regen": 0, "mass": 0, "cost": {}},
			"c": {"hp": 1, "armor": 0, "shield_cap": 0, "shield_regen": 0, "mass": 1, "cost": {"gold": 4}},
		},
	}
	var bad := TileLib.from_table(table)
	var joined := " | ".join(bad.errors)
	assert_true("not a whole amount" in joined, "10 x 0.25 is flagged")
	assert_true("mass must be positive" in joined)
	assert_true("unknown material 'gold'" in joined)
	assert_true("exactly one tile type must be unique" in joined)

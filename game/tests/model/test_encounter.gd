extends TestCase
## Phase 5.3: encounter levels 1-100. One deterministic generator: a rising budget, the level's
## tier mix and count, enemy guns at about 10 × the level, and a boss for Kill HVT.

var rules: Encounter.Rules
var roster: EnemyRoster


func before_each() -> void:
	rules = Encounter.Rules.from_table(Data.table(&"levels"))
	roster = EnemyRoster.from_table(Data.table(&"enemies"), Data.json_dir("enemies"))


func test_the_table_loads_clean() -> void:
	assert_eq(rules.errors, PackedStringArray())
	assert_eq(roster.errors, PackedStringArray())


func test_the_budget_rises_with_level() -> void:
	var flat := -1
	for level in range(2, 101):
		if rules.budget_for(level) <= rules.budget_for(level - 1) and flat < 0:
			flat = level
	assert_eq(flat, -1, "every level's budget beats the one before")
	assert_true(rules.budget_for(1) >= 9, "level 1 affords a small ship (%d tiles)" % rules.budget_for(1))


func test_the_same_seed_gives_the_same_encounter() -> void:
	var a := _ids(Encounter.generate(rules, roster, 40, 1234))
	var b := _ids(Encounter.generate(rules, roster, 40, 1234))
	assert_eq(a, b)
	var differ := false
	for s in range(1, 20):
		if _ids(Encounter.generate(rules, roster, 40, s)) != a:
			differ = true
	assert_true(differ, "and other seeds vary it")


func test_levels_1_25_50_and_100_all_generate() -> void:
	for level: int in [1, 25, 50, 100]:
		for s in 10:
			var fight := Encounter.generate(rules, roster, level, s)
			var band := rules.band_for(level)
			assert_true(fight.spawns.size() >= int(band["count"][0]) and fight.spawns.size() <= int(band["count"][1]),
					"L%d seed %d: %d enemies, within %s" % [level, s, fight.spawns.size(), band["count"]])
			assert_true(fight.spent <= fight.budget or fight.spawns.size() <= int(band["count"][0]),
					"L%d seed %d: within budget (%d of %d)" % [level, s, fight.spent, fight.budget])
			for spawn in fight.spawns:
				var entry := roster.entry(spawn.id)
				assert_true(entry.fits(level) and not entry.boss and not entry.ally, "L%d: %s belongs here" % [level, spawn.id])


func test_enemy_guns_are_about_ten_times_the_level() -> void:
	for level: int in [1, 5, 40, 99, 100]:
		var fight := Encounter.generate(rules, roster, level, 7)
		for spawn in fight.spawns:
			var centre: float = 10.0 * level
			assert_true(spawn.gun_level >= 1 and spawn.gun_level <= 999, "within L1-999")
			assert_true(absf(spawn.gun_level - minf(centre, 999.0)) <= maxf(centre * 0.2 + 1.0, centre - 999.0),
					"L%d: guns L%d, near %d (§4.8)" % [level, spawn.gun_level, centre])


func test_tougher_levels_bring_higher_tiers_and_full_damage() -> void:
	var low := 0.0
	var high := 0.0
	for s in 20:
		for spawn in Encounter.generate(rules, roster, 5, s).spawns:
			low = maxf(low, roster.entry(spawn.id).tier)
		for spawn in Encounter.generate(rules, roster, 95, s).spawns:
			high += roster.entry(spawn.id).tier
	assert_eq(low, 1.0, "level 5 is tier 1 only")
	assert_true(Encounter.generate(rules, roster, 1, 0).damage < Encounter.generate(rules, roster, 100, 0).damage,
			"early enemies deal a smaller share of their damage")


func test_kill_hvt_brings_the_boss_that_fits() -> void:
	var fight := Encounter.generate(rules, roster, 60, 3, true)
	assert_true(fight.spawns[0].boss and roster.entry(fight.spawns[0].id).fits(60), "a boss leads it (%s)" % fight.spawns[0].id)
	assert_eq(fight.spawns.filter(func(s: Encounter.Spawn) -> bool: return s.boss).size(), 1, "just the one")
	assert_true(fight.spawns.size() >= 2, "with company")


func test_an_enemy_damage_share_scales_its_guns() -> void:
	var tiles_table := Data.table(&"tiles")
	var placement := Placement.create(ShapeLib.from_table(Data.table(&"shapes")), TileLib.from_table(tiles_table), tiles_table)
	placement.thrusters = ThrusterLib.from_table(Data.table(&"thrusters"))
	placement.weapons = WeaponLib.from_table(Data.table(&"weapons"))
	var gnat := roster.entry(&"gnat").blueprint
	var full: float = GunLayout.compute(gnat, placement, 1).guns[0].stats["damage"]
	assert_almost_eq(GunLayout.compute(gnat, placement, 1, {}, 0.5).guns[0].stats["damage"], full * 0.5, 0.0001)


func _ids(fight: Encounter) -> Array:
	return fight.spawns.map(func(s: Encounter.Spawn) -> Array: return [s.id, s.gun_level])

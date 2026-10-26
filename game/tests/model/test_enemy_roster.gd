extends TestCase
## Phase 5.1: the roster. 12 enemies over 4 tiers and 6 roles, a boss per tier, and the carrier
## the player escorts; every one valid, able to fly, and armed for its role.

const COMBAT_ROLES: Array[StringName] = [&"chaser", &"strafer", &"sniper", &"kamikaze", &"minelayer", &"brute"]

var placement: Placement
var roster: EnemyRoster


func before_each() -> void:
	var tiles_table := Data.table(&"tiles")
	placement = Placement.create(ShapeLib.from_table(Data.table(&"shapes")),
			TileLib.from_table(tiles_table), tiles_table)
	placement.thrusters = ThrusterLib.from_table(Data.table(&"thrusters"))
	placement.weapons = WeaponLib.from_table(Data.table(&"weapons"))
	roster = EnemyRoster.from_table(Data.table(&"enemies"), Data.json_dir("enemies"))


func test_all_seventeen_load() -> void:
	assert_eq(roster.errors, PackedStringArray())
	assert_eq(roster.entries.size(), 17)
	var regular := roster.entries.filter(func(e: EnemyRoster.Entry) -> bool: return e.role in COMBAT_ROLES)
	assert_eq(regular.size(), 12, "12 over the 6 combat roles")
	for tier in range(1, 5):
		assert_eq(regular.filter(func(e: EnemyRoster.Entry) -> bool: return e.tier == tier).size(), 3, "3 in tier %d" % tier)
		assert_true(roster.boss(tier) != null, "a boss for tier %d" % tier)
	for role in COMBAT_ROLES:
		assert_eq(regular.filter(func(e: EnemyRoster.Entry) -> bool: return e.role == role).size(), 2, "%s at two tiers" % role)
	var allies := roster.entries.filter(func(e: EnemyRoster.Entry) -> bool: return e.ally)
	assert_eq(allies.map(func(e: EnemyRoster.Entry) -> StringName: return e.id), [&"pike"], "one ally: the carrier")
	assert_eq(allies[0].role, &"carrier")
	assert_eq(allies[0].behaviour, &"convoy", "it flies a route")
	assert_true(roster.entries.all(func(e: EnemyRoster.Entry) -> bool: return e.faction == &"neutral"), "neutral until v2")


func test_every_ship_is_valid_and_flies_without_warnings() -> void:
	for entry in roster.entries:
		var bp := entry.blueprint
		assert_eq(placement.validate(bp).map(func(p: Placement.Problem) -> String: return p.message), [], "%s is valid" % entry.id)
		var stats := ShipStats.compute(bp, placement)
		var envelope := ThrustEnvelope.compute(bp, placement, stats)
		assert_eq(envelope.warnings.map(func(w: Dictionary) -> String: return w["text"]), [], "%s: forward, brake, turn" % entry.id)
		assert_eq(GunLayout.compute(bp, placement).warnings.map(func(w: Dictionary) -> String: return w["text"]), [],
				"%s: no gun fires into its own hull" % entry.id)
		assert_true(("ally" if entry.ally else "enemy") in bp.tags and "role:%s" % entry.role in bp.tags and "tier:%d" % entry.tier in bp.tags,
				"%s is tagged" % entry.id)


func test_each_role_is_armed_for_its_job() -> void:
	for entry in roster.entries:
		var guns := GunLayout.compute(entry.blueprint, placement).guns
		var weapons := guns.map(func(g: GunLayout.Gun) -> StringName: return g.weapon)
		match entry.role:
			&"kamikaze":
				assert_true(ThrustEnvelope.compute(entry.blueprint, placement, ShipStats.compute(entry.blueprint, placement))
						.accel(ThrustEnvelope.FORWARD) > 8.0, "%s is fast" % entry.id)
			&"minelayer":
				assert_true(weapons.has(&"mines"), "%s lays mines" % entry.id)
			&"sniper":
				assert_true(guns.any(func(g: GunLayout.Gun) -> bool: return g.stats["range_u"] >= 30.0), "%s outranges" % entry.id)
			_:
				assert_true(guns.size() >= 1, "%s is armed" % entry.id)


func test_the_carrier_is_long_skinny_and_armoured() -> void:
	var pike := roster.entry(&"pike").blueprint
	var low := Vector2.INF
	var high := -Vector2.INF
	for tile in pike.tiles:
		for p in placement.tile_polygon(tile):
			low = low.min(p)
			high = high.max(p)
	var size := high - low
	assert_true(size.x >= 3.0 * size.y, "owner, 2026-10-26: long and skinny (%s U)" % size)
	assert_true(roster.for_level(50).all(func(e: EnemyRoster.Entry) -> bool: return e.id != &"pike"), "and never an enemy")
	assert_true(pike.tiles.filter(func(t: Blueprint.Tile) -> bool: return t.type == &"armor").size() >= 4, "and armoured")


func test_a_boss_outguns_its_tier() -> void:
	for tier in range(1, 5):
		var boss := roster.boss(tier)
		var boss_tiles := boss.blueprint.tiles.size()
		for entry in roster.entries:
			if entry.tier == tier and not entry.boss and not entry.ally:
				assert_true(boss_tiles > entry.blueprint.tiles.size(), "%s is bigger than %s" % [boss.id, entry.id])
		assert_true(boss_tiles <= placement.max_tiles, "%s fits the tile cap" % boss.id)


func test_every_level_has_enemies() -> void:
	var empty: Array[int] = []
	for level in range(1, 101):
		if roster.for_level(level).is_empty():
			empty.append(level)
	assert_eq(empty, [] as Array[int], "levels 1-100 all have something to fight")


func test_bad_rows_are_reported() -> void:
	var bad := EnemyRoster.from_table({"roles": ["chaser"], "behaviours": ["chase"], "enemies": {
		"gnat": {"tier": 5, "role": "chaser", "behaviour": "chase", "levels": [1, 2]},
		"ghost": {"tier": 1, "role": "chaser", "behaviour": "chase", "levels": [1, 2]},
		"wasp": {"tier": 1, "role": "chaser", "behaviour": "dance", "levels": [1, 2]},
	}}, Data.json_dir("enemies"))
	assert_eq(bad.entries.size(), 0)
	assert_eq(bad.errors.size(), 3)

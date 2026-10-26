extends TestCase
## Phase 4.8b: guns level L1-L999 on XP from kills (PLAN.md 4.4, D8).

var xp: WeaponXp


func before_each() -> void:
	xp = WeaponXp.from_table(Data.table(&"weapon_xp"))


func test_the_table_loads_clean_and_owns_the_top_level() -> void:
	assert_eq(xp.errors, PackedStringArray())
	assert_eq(xp.max_level, 999)
	var lib := WeaponLib.from_table(Data.table(&"weapons"), Data.table(&"weapon_xp"))
	assert_eq(lib.max_level, 999, "WeaponLib takes it from weapon_xp.json")
	assert_false(Data.table(&"weapons").has("levels"), "moved out of weapons.json")


func test_the_curve_rises_and_reaches_the_top_level() -> void:
	assert_eq(xp.xp_for(1), 0)
	var flat := -1
	for level in range(2, xp.max_level + 1):
		if xp.xp_for(level) <= xp.xp_for(level - 1) and flat < 0:
			flat = level
	assert_eq(flat, -1, "every level needs more XP than the one before")
	assert_eq(xp.level_for(xp.xp_for(xp.max_level)), xp.max_level)
	assert_eq(xp.level_for(xp.xp_for(xp.max_level) * 10), xp.max_level, "and stops there")


func test_level_for_inverts_the_curve_at_every_boundary() -> void:
	for level in [1, 2, 3, 10, 57, 100, 400, 998, 999]:
		assert_eq(xp.level_for(xp.xp_for(level)), level, "exactly the XP for L%d" % level)
		if level > 1:
			assert_eq(xp.level_for(xp.xp_for(level) - 1), level - 1, "one short of L%d" % level)
	assert_almost_eq(xp.progress(xp.xp_for(10)), 0.0, 0.0001)
	assert_almost_eq(xp.progress((xp.xp_for(10) + xp.xp_for(11)) / 2), 0.5, 0.01)


func test_level_scales_damage_one_percent_a_level() -> void:
	var gatling := WeaponLib.from_table(Data.table(&"weapons")).weapon(&"gatling_single")
	assert_eq(xp.scaled(gatling, 1), gatling)
	assert_almost_eq(xp.scaled(gatling, 101)["damage"], gatling["damage"] * 2.0, 0.0001, "+1% a level: L101 doubles")
	assert_almost_eq(xp.damage_factor(999), 10.98, 0.0001, "PLAN.md 4.4: L999 is about ×11")
	var rocket := WeaponLib.from_table(Data.table(&"weapons")).weapon(&"rocket_ff_he")
	assert_almost_eq(xp.scaled(rocket, 51)["splash_damage"], rocket["splash_damage"] * 1.5, 0.0001, "splash too")


func test_a_kill_grows_with_size_and_encounter_level() -> void:
	assert_true(xp.kill_xp(10, 1) > xp.kill_xp(4, 1), "a bigger ship is worth more")
	assert_true(xp.kill_xp(4, 20) > xp.kill_xp(4, 2), "so is a tougher encounter")
	assert_true(xp.kill_xp(1, 1) >= 1)


func test_the_split_adds_up_to_the_kill() -> void:
	var shares := WeaponXp.split(100, {"g1": 30.0, "g2": 60.0, "g3": 10.0})
	assert_eq(shares, {"g1": 30, "g2": 60, "g3": 10})
	shares = WeaponXp.split(10, {"a": 1.0, "b": 1.0, "c": 1.0})
	assert_eq(shares.values().reduce(func(s: int, v: int) -> int: return s + v, 0), 10, "thirds of 10 still add up")
	shares = WeaponXp.split(7, {"a": 999.0, "b": 0.0001})
	assert_eq(shares, {"a": 7}, "a gun that barely scratched it gets nothing")
	assert_eq(WeaponXp.split(50, {}), {}, "no damage, no XP")


func test_a_fitted_gun_flies_at_its_items_level() -> void:
	var tiles_table := Data.table(&"tiles")
	var placement := Placement.create(ShapeLib.from_table(Data.table(&"shapes")),
			TileLib.from_table(tiles_table), tiles_table)
	placement.weapons = WeaponLib.from_table(Data.table(&"weapons"), Data.table(&"weapon_xp"))
	var errors: PackedStringArray = []
	var bp := Blueprint.from_dict(Data.json_dir("blueprints")["gunboat"], errors)
	var first := bp.mounts.find_custom(Mounting.is_weapon)
	bp.mounts[first]["gun"] = "g7"
	var layout := GunLayout.compute(bp, placement, 1, {"g7": 101})
	var fitted: GunLayout.Gun = layout.guns.filter(func(g: GunLayout.Gun) -> bool: return g.item == "g7")[0]
	assert_eq(fitted.level, 101)
	var base := placement.weapons.weapon(fitted.weapon)
	assert_almost_eq(fitted.stats["damage"], base["damage"] * 2.0, 0.0001, "hits twice as hard at L101")
	assert_true(fitted.spread < base["spread"], "and scatters less")
	assert_true(layout.guns.all(func(g: GunLayout.Gun) -> bool:
		return g == fitted or (g.level == 1 and g.stats == placement.weapons.weapon(g.weapon))), "the rest are L1")

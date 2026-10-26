extends TestCase
## Phase 4.7: FIRE fires only the active manual weapon (every manual gun of that type), auto guns
## keep firing on their own, and SWITCH picks between the manual weapon types.

const DT := 1.0 / 60.0

var placement: Placement
var lib: WeaponLib


func before_each() -> void:
	var tiles_table := Data.table(&"tiles")
	placement = Placement.create(ShapeLib.from_table(Data.table(&"shapes")),
			TileLib.from_table(tiles_table), tiles_table)
	placement.thrusters = ThrusterLib.from_table(Data.table(&"thrusters"))
	lib = WeaponLib.from_table(Data.table(&"weapons"))
	placement.weapons = lib


func test_fire_fires_only_the_active_manual_weapon() -> void:
	var gunnery := Gunnery.create(GunLayout.compute(_two_manual_types(), placement), lib)
	assert_eq(gunnery.manual_weapons(), [&"cannon", &"gatling_multi"] as Array[StringName], "in mount order")
	assert_eq(gunnery.active, &"cannon", "the first one starts active")
	assert_eq(gunnery.manual_count(&"gatling_multi"), 2)
	var fired := _fire(gunnery, 1.0)
	assert_true(fired[&"cannon"] > 0 and fired[&"gatling_multi"] == 0, "only the cannon: %s" % fired)
	assert_true(fired[&"gatling_single"] > 0, "the auto turrets fire on their own")
	assert_true(gunnery.select(&"gatling_multi"))
	fired = _fire(gunnery, 1.0)
	assert_true(fired[&"gatling_multi"] > 0 and fired[&"cannon"] == 0, "now only the swivels: %s" % fired)
	assert_false(gunnery.select(&"laser"), "a weapon the ship hasn't got can't be picked")
	gunnery.cycle()
	assert_eq(gunnery.active, &"cannon", "cycling wraps round")


func test_losing_the_active_weapon_falls_back_to_another() -> void:
	var bp := _two_manual_types()
	var gunnery := Gunnery.create(GunLayout.compute(bp, placement), lib)
	var without_nose := {}
	for tile in bp.tiles:
		if tile.id != 6:
			without_nose[tile.id] = true
	gunnery.set_layout(GunLayout.compute(bp.subset(without_nose), placement))
	assert_eq(gunnery.active, &"gatling_multi", "the cannon went with its tile")


## The gunboat with its multi-gatling swivels on manual: two manual types and two auto turrets.
func _two_manual_types() -> Blueprint:
	var errors: PackedStringArray = []
	var bp := Blueprint.from_dict(Data.json_dir("blueprints")["gunboat"], errors)
	for mount in bp.mounts:
		if mount["part"] == "weapon.gatling_multi":
			mount["mode"] = "manual"
	return bp


## Shots per weapon type over `seconds` with FIRE held and a target dead ahead.
func _fire(gunnery: Gunnery, seconds: float) -> Dictionary:
	var out := {&"cannon": 0, &"gatling_multi": 0, &"gatling_single": 0}
	for i in roundi(seconds / DT):
		for shot in gunnery.step(DT, Vector2.ZERO, 0.0, Vector2.ZERO, [{"pos": Vector2(12, 0), "vel": Vector2.ZERO}], true):
			out[gunnery.layout.guns[shot["gun"]].weapon] += 1
	return out

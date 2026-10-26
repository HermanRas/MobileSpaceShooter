extends TestCase
## Phase 4.6a: the four rockets (homing or fire-and-forget, each HE or AP) and flak (pellets,
## an airburst fuse timed to the target, shooting down rockets).

const DT := 1.0 / 60.0
const ROCKETS := {
	&"rocket_ff_he": [false, &"he"], &"rocket_ff_ap": [false, &"ap"],
	&"rocket_homing_he": [true, &"he"], &"rocket_homing_ap": [true, &"ap"],
}

var placement: Placement
var lib: WeaponLib


func before_each() -> void:
	var tiles_table := Data.table(&"tiles")
	placement = Placement.create(ShapeLib.from_table(Data.table(&"shapes")),
			TileLib.from_table(tiles_table), tiles_table)
	placement.thrusters = ThrusterLib.from_table(Data.table(&"thrusters"))
	lib = WeaponLib.from_table(Data.table(&"weapons"))
	placement.weapons = lib


func test_four_rockets_homing_or_not_he_or_ap() -> void:
	assert_eq(lib.errors, PackedStringArray())
	for weapon_id: StringName in ROCKETS:
		var stats := lib.weapon(weapon_id)
		var homing: bool = ROCKETS[weapon_id][0]
		assert_true(stats["rocket"], "%s can be shot down" % weapon_id)
		assert_eq(stats["damage_type"], &"explosive")
		assert_eq(stats["homing"] > 0.0, homing, "%s %s" % [weapon_id, "homes" if homing else "flies straight"])
		for type: StringName in WeaponLib.MOUNT_TYPES:
			assert_true(lib.allows(weapon_id, type), "%s on %s" % [weapon_id, type])
	for guidance in ["ff", "homing"]:
		var he := lib.weapon(StringName("rocket_%s_he" % guidance))
		var ap := lib.weapon(StringName("rocket_%s_ap" % guidance))
		assert_true(he["splash_u"] > ap["splash_u"] * 2.0, "HE: the big splash")
		assert_true(ap["damage"] > he["damage"] * 2.0 and ap["pierce"] > 0.0, "AP: the concentrated, piercing hit")
	assert_true(lib.weapon(&"rocket_homing_he")["speed_u"] < lib.weapon(&"rocket_ff_he")["speed_u"],
			"seekers are slower: flak gets its chance")


func test_flak_is_a_short_range_anti_missile_shotgun() -> void:
	var flak := lib.weapon(&"flak")
	assert_true(flak["pellets"] > 1 and flak["airburst"] and flak["anti_missile"])
	assert_true(flak["range_u"] < lib.weapon(&"gatling_single")["range_u"], "close range")


func test_flak_fires_its_pellets_with_a_fuse_set_for_the_target() -> void:
	var gunnery := _gunnery(&"flak", &"auto")
	var target := [{"pos": Vector2(9, 0), "vel": Vector2.ZERO}]
	var shots: Array[Dictionary] = []
	for i in 30:
		shots.append_array(gunnery.step(DT, Vector2.ZERO, 0.0, Vector2.ZERO, target, false))
	assert_eq(shots.size(), lib.weapon(&"flak")["pellets"] * gunnery.fired[0], "every trigger fires a full shotgun load")
	assert_true(shots.size() > 0)
	if shots.is_empty():
		return
	var flight: Vector2 = Vector2(9, 0) - shots[0]["from"]
	assert_almost_eq(shots[0]["life"], flight.length() / lib.weapon(&"flak")["speed_u"], 0.02,
			"the fuse bursts it where the target is, not at full range")
	assert_true(shots[0]["airburst"] and shots[0]["splash_u"] > 0.0)


func test_flak_goes_for_incoming_rockets_and_a_gatling_doesnt() -> void:
	var rocket := [{"pos": Vector2(7, 1), "vel": Vector2(-15, 0)}]
	var flak := _gunnery(&"flak", &"auto")
	var gatling := _gunnery(&"gatling_single", &"auto")
	var flak_shots := 0
	var gatling_shots := 0
	for i in 30:
		flak_shots += flak.step(DT, Vector2.ZERO, 0.0, Vector2.ZERO, [], false, rocket).size()
		gatling_shots += gatling.step(DT, Vector2.ZERO, 0.0, Vector2.ZERO, [], false, rocket).size()
	assert_true(flak_shots > 0, "flak fires at a rocket")
	assert_eq(gatling_shots, 0, "a gatling leaves rockets alone")


func test_a_seeker_names_its_target_and_turns_at_its_rate() -> void:
	var gunnery := _gunnery(&"rocket_homing_he", &"auto")
	var targets := [{"pos": Vector2(20, 30), "vel": Vector2.ZERO}, {"pos": Vector2(14, 1), "vel": Vector2.ZERO}]
	var shot: Dictionary = {}
	for i in 120:
		var shots := gunnery.step(DT, Vector2.ZERO, 0.0, Vector2.ZERO, targets, false)
		if not shots.is_empty():
			shot = shots[0]
			break
	assert_eq(shot.get("target", -1), 1, "the one in its arc")
	var turn: float = lib.weapon(&"rocket_homing_he")["homing"]
	var vel := Vector2(18, 0)
	var steered := Gunnery.steer(vel, Vector2(0, 10), turn, DT)
	assert_almost_eq(steered.angle(), turn * DT, 0.0001, "turns no faster than homing_deg_s")
	assert_almost_eq(steered.length(), vel.length(), 0.0001, "at the same speed")
	assert_almost_eq(Gunnery.steer(vel, Vector2(10, 0.01), turn, DT).angle(), Vector2(10, 0.01).angle(), 0.0001,
			"and no further than its target")


func test_every_sandbox_target_is_a_valid_ship() -> void:
	var files := Data.json_dir("enemies")
	assert_true(files.has("rocket_pod"), "the flak target ships")
	for file_name: String in files:
		var errors: PackedStringArray = []
		var bp := Blueprint.from_dict(files[file_name], errors)
		assert_not_null(bp, "%s: %s" % [file_name, ", ".join(errors)])
		if bp != null:
			var messages := placement.validate(bp).map(func(p: Placement.Problem) -> String: return p.message)
			assert_eq(messages.size(), 0, "%s: %s" % [file_name, ", ".join(messages)])
	assert_eq(GunLayout.compute(Blueprint.from_dict(files["rocket_pod"], PackedStringArray()), placement).guns.size(), 2)


## A core with a hardpoint ahead and one `weapon_id` swivel on its front edge.
func _gunnery(weapon_id: StringName, mode: StringName) -> Gunnery:
	var bp := Blueprint.new()
	bp.id = "test"
	for row: Array in [[0, &"core", Vector2.ZERO], [1, &"hardpoint", Vector2(1, 0)]]:
		var tile := Blueprint.Tile.new()
		tile.id = row[0]
		tile.type = row[1]
		tile.shape = &"square"
		tile.size = &"L"
		tile.pos = row[2]
		tile.paint = Color.GRAY
		bp.tiles.append(tile)
	for s: Dictionary in Mounting.weapon_slots(placement, bp, weapon_id, &"swivel"):
		if placement.tile_edges(bp.tile_by_id(1))[s["edge"]].normal.x > 0.5:
			bp.mounts.append(Mounting.moved_to({"part": WeaponLib.part_id(weapon_id), "mount": "swivel", "mode": String(mode)}, s))
			break
	var gunnery := Gunnery.create(GunLayout.compute(bp, placement), lib)
	gunnery.rng.seed = 3
	return gunnery

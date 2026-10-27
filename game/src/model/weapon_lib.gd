class_name WeaponLib
extends RefCounted
## Every gun and mount type from `data/weapons.json` (PLAN.md 4.4, Phase 4.3).
##
## A part id is `weapon.<id>` (the blueprint's `part` field, §5.4). A weapon mount also names
## its mount type (`fixed`, `swivel` or `turret`) and its fire mode (`manual` or `auto`).

const PART_PREFIX := "weapon."
const MOUNT_TYPES: Array[StringName] = [&"fixed", &"swivel", &"turret"]
const MODES: Array[StringName] = [&"manual", &"auto"]
const NUMBERS := ["damage", "rate", "speed_u", "range_u", "edge_u", "length_u", "turret_radius_u", "mass", "price_gc"]

## A gun fires once its barrel is within this of its aim (radians).
var fire_within := deg_to_rad(3.0)
## The top gun level; a gun's spread narrows from L1 to here.
var max_level := 999
## Levels from XP, and what they do (Phase 4.8b).
var xp := WeaponXp.new()
var errors: PackedStringArray = []

var _mounts: Dictionary = {}  # mount type -> read-only {"name", "face", "arc", "turn_rate", "modes"}
var _weapons: Dictionary = {}  # weapon id -> read-only def


## `xp_table`: `data/weapon_xp.json` (its defaults when left out).
static func from_table(table: Dictionary, xp_table := {}) -> WeaponLib:
	var lib := WeaponLib.new()
	lib.fire_within = deg_to_rad(float(table.get("aim", {}).get("fire_within_deg", 3.0)))
	lib.xp = WeaponXp.from_table(xp_table)
	lib.errors.append_array(lib.xp.errors)
	lib.max_level = lib.xp.max_level
	for mount_type: String in table.get("mounts", {}):
		var raw: Dictionary = table["mounts"][mount_type]
		if not MOUNT_TYPES.has(StringName(mount_type)):
			lib.errors.append("mount %s: must be one of %s" % [mount_type, MOUNT_TYPES])
			continue
		var modes: Array[StringName] = []
		for mode: Variant in raw.get("modes", []):
			if MODES.has(StringName(str(mode))):
				modes.append(StringName(str(mode)))
			else:
				lib.errors.append("mount %s: unknown mode %s" % [mount_type, mode])
		if modes.is_empty() or str(raw.get("on", "")) not in ["edge", "face"]:
			lib.errors.append("mount %s: needs modes and `on` (edge or face)" % mount_type)
			continue
		var def := {
			"name": str(raw.get("name", mount_type)), "face": raw["on"] == "face",
			"arc": deg_to_rad(float(raw.get("arc_deg", 0.0))), "turn_rate": deg_to_rad(float(raw.get("turn_deg_s", 0.0))),
			"over_hull": bool(raw.get("over_hull", false)), "modes": modes,
		}
		def.make_read_only()
		lib._mounts[StringName(mount_type)] = def
	for type: StringName in MOUNT_TYPES:
		if not lib._mounts.has(type):
			lib.errors.append("mount %s is missing" % type)
	for weapon_id: String in table.get("weapons", {}):
		var raw: Dictionary = table["weapons"][weapon_id]
		var ok := true
		for key: String in NUMBERS:
			if typeof(raw.get(key)) not in [TYPE_INT, TYPE_FLOAT] or float(raw[key]) <= 0.0:
				lib.errors.append("%s: %s must be > 0" % [weapon_id, key])
				ok = false
		if typeof(raw.get("pierce")) not in [TYPE_INT, TYPE_FLOAT] or float(raw["pierce"]) < 0.0:
			lib.errors.append("%s: pierce must be >= 0" % weapon_id)
			ok = false
		var spread: Variant = raw.get("spread_deg")
		if typeof(spread) in [TYPE_INT, TYPE_FLOAT]:
			spread = [spread, spread]
		if typeof(spread) != TYPE_ARRAY or spread.size() != 2 or spread.any(func(v: Variant) -> bool:
				return typeof(v) not in [TYPE_INT, TYPE_FLOAT] or float(v) < 0.0) or float(spread[1]) > float(spread[0]):
			lib.errors.append("%s: spread_deg must be [at L1, at the top level], both >= 0, narrowing" % weapon_id)
			ok = false
		var mounts: Array[StringName] = []
		for mount: Variant in raw.get("mounts", []):
			if lib._mounts.has(StringName(str(mount))):
				mounts.append(StringName(str(mount)))
			else:
				lib.errors.append("%s: unknown mount %s" % [weapon_id, mount])
				ok = false
		if mounts.is_empty() or str(raw.get("damage_type", "")).is_empty():
			lib.errors.append("%s: needs mounts and a damage_type" % weapon_id)
			ok = false
		if not ok:
			continue
		var def := {"name": str(raw.get("name", weapon_id)), "damage_type": StringName(raw["damage_type"]), "mounts": mounts,
				"spread": deg_to_rad(float(spread[0])), "spread_best": deg_to_rad(float(spread[1])),
				"max_level": lib.max_level, "pierce": float(raw["pierce"])}
		for key: String in NUMBERS:
			def[key] = float(raw[key])
		def["rate_start"] = float(raw.get("rate_start", raw["rate"]))
		def["spin_up_s"] = maxf(float(raw.get("spin_up_s", 0.0)), 0.0)
		def["spin_down_s"] = maxf(float(raw.get("spin_down_s", def["spin_up_s"])), 0.001)
		if def["rate_start"] <= 0.0 or def["rate_start"] > def["rate"]:
			lib.errors.append("%s: rate_start must be > 0 and no more than rate" % weapon_id)
			continue
		def["pellets"] = maxi(int(raw.get("pellets", 1)), 1)
		def["splash_u"] = maxf(float(raw.get("splash_u", 0.0)), 0.0)
		def["splash_damage"] = float(raw.get("splash_damage", 0.0))
		def["splash_type"] = StringName(raw.get("splash_type", "explosive"))
		def["airburst"] = bool(raw.get("airburst", false))
		def["homing"] = deg_to_rad(maxf(float(raw.get("homing_deg_s", 0.0)), 0.0))
		def["rocket"] = bool(raw.get("rocket", false))
		def["anti_missile"] = bool(raw.get("anti_missile", false))
		def["family"] = str(raw.get("family", "Guns"))
		def["beam"] = bool(raw.get("beam", false))
		def["heat_s"] = float(raw.get("heat_s", 0.0))
		def["cool_s"] = float(raw.get("cool_s", 0.0))
		def["heat_resume"] = clampf(float(raw.get("heat_resume", 0.3)), 0.0, 0.99)
		def["rear_only"] = bool(raw.get("rear_only", false))
		def["proximity_u"] = maxf(float(raw.get("proximity_u", 0.0)), 0.0)
		def["hit_u"] = maxf(float(raw.get("hit_u", 0.4)), 0.0)
		def["drag"] = maxf(float(raw.get("drag", 0.0)), 0.0)
		def["life_s"] = maxf(float(raw.get("life_s", 0.0)), 0.0)
		if def["beam"] and (def["heat_s"] <= 0.0 or def["cool_s"] <= 0.0):
			lib.errors.append("%s: a beam needs heat_s and cool_s > 0" % weapon_id)
			continue
		if def["proximity_u"] > 0.0 and (def["splash_u"] <= 0.0 or def["life_s"] <= 0.0):
			lib.errors.append("%s: a mine needs a splash and life_s" % weapon_id)
			continue
		if (def["splash_u"] > 0.0) != (def["splash_damage"] > 0.0) or (def["airburst"] and def["splash_u"] <= 0.0):
			lib.errors.append("%s: splash_u and splash_damage go together, and airburst needs them" % weapon_id)
			continue
		def.make_read_only()
		lib._weapons[StringName(weapon_id)] = def
	return lib


## The palette's gun groups, in the order the data first names them.
func families() -> PackedStringArray:
	var out: PackedStringArray = []
	for weapon_id: StringName in _weapons:
		if not out.has(_weapons[weapon_id]["family"]):
			out.append(_weapons[weapon_id]["family"])
	return out


func weapon_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_weapons.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


func has_weapon(weapon_id: StringName) -> bool:
	return _weapons.has(weapon_id)


## One gun's numbers, or {} if unknown. Read-only.
##   name, damage_type, mounts (allowed mount types), damage (per shot), rate (shots/s),
##   speed_u, range_u, spread and spread_best (rad either side, at L1 and at max_level),
##   pierce (0-1), edge_u, length_u, turret_radius_u, mass, price_gc, and for a gun that spins
##   up: rate_start (shots/s when it starts), spin_up_s, spin_down_s (spin_up_s 0 if it doesn't);
##   pellets (shots per trigger), splash_u, splash_damage, splash_type, airburst, homing (rad/s),
##   rocket (can be shot down), anti_missile (also targets enemy rockets); family (palette group);
##   beam, heat_s, cool_s, heat_resume (lasers); rear_only; proximity_u, hit_u, drag, life_s (mines)
func weapon(weapon_id: StringName) -> Dictionary:
	return _weapons.get(weapon_id, {})


## A mount type's rules, or {}: name, face (sits on a face, not an edge), arc (rad either side
## of its facing), turn_rate (rad/s), over_hull (fires over the ship's own tiles), modes.
func mount_type(type: StringName) -> Dictionary:
	return _mounts.get(type, {})


func allows(weapon_id: StringName, type: StringName) -> bool:
	return has_weapon(weapon_id) and (weapon(weapon_id)["mounts"] as Array).has(type)


## The mode a gun on `type` gets when `wanted` isn't allowed there (a turret is always auto).
func mode_for(type: StringName, wanted: StringName) -> StringName:
	var modes: Array = mount_type(type).get("modes", [])
	return wanted if modes.has(wanted) or modes.is_empty() else modes[0]


## A gun's scatter (rad either side of its aim) at `level`: from `spread` at L1 to `spread_best`
## at max_level, on a log curve, so the early levels count the most.
static func spread_for(stats: Dictionary, level: int) -> float:
	var share := clampf(log(float(maxi(level, 1))) / log(float(stats["max_level"])), 0.0, 1.0)
	return lerpf(stats["spread"], stats["spread_best"], share)


## &"gatling_single" from "weapon.gatling_single"; &"" if `part` isn't a weapon.
static func type_of_part(part: String) -> StringName:
	return StringName(part.trim_prefix(PART_PREFIX)) if part.begins_with(PART_PREFIX) else &""


static func part_id(weapon_id: StringName) -> String:
	return PART_PREFIX + String(weapon_id)

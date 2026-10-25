class_name ThrusterLib
extends RefCounted
## Every thruster type from `data/thrusters.json` (PLAN.md 4.3), at any size and level.
##
## A part id is `thruster.<type>` (the blueprint's `part` field, §5.4). `spec()` resolves one
## type × size × level into the numbers the hangar and the flight controller use.

const PART_PREFIX := "thruster."
const BEHAVIOURS: Array[StringName] = [&"pulse", &"steady", &"ramp"]

var size_factor: Dictionary = {}
## How far a thruster sticks out from its edge, as a fraction of its length.
var depth_factor: float = 0.5
var errors: PackedStringArray = []

var _types: Dictionary = {}  # type -> {"name", "behaviour", "mass", "interval_s", "levels": [Dictionary]}
var _specs: Dictionary = {}  # "type|size|level" -> read-only spec


static func from_table(table: Dictionary) -> ThrusterLib:
	var lib := ThrusterLib.new()
	for code: String in table.get("size_factor", {}):
		lib.size_factor[StringName(code)] = float(table["size_factor"][code])
	if lib.size_factor.is_empty():
		lib.errors.append("size_factor is required")
	lib.depth_factor = float(table.get("depth_factor", 0.5))
	for type_id: String in table.get("types", {}):
		var def: Dictionary = table["types"][type_id]
		var behaviour := StringName(def.get("behaviour", ""))
		if not BEHAVIOURS.has(behaviour):
			lib.errors.append("%s: behaviour must be one of %s" % [type_id, BEHAVIOURS])
			continue
		var levels: Array = def.get("levels", [])
		if levels.is_empty():
			lib.errors.append("%s: needs at least one level" % type_id)
			continue
		var ok := true
		for level: Dictionary in levels:
			var keys := ["thrust", "price_gc"] + (["start", "ramp_s"] if behaviour == &"ramp" else [])
			for key: String in keys:
				if typeof(level.get(key)) not in [TYPE_INT, TYPE_FLOAT] or float(level[key]) < 0.0:
					lib.errors.append("%s: every level needs %s >= 0" % [type_id, key])
					ok = false
		if behaviour == &"pulse" and float(def.get("interval_s", 0.0)) <= 0.0:
			lib.errors.append("%s: a pulse thruster needs interval_s > 0" % type_id)
			ok = false
		if float(def.get("mass", 0.0)) <= 0.0:
			lib.errors.append("%s: mass must be positive" % type_id)
			ok = false
		if ok:
			lib._types[StringName(type_id)] = {
				"name": str(def.get("name", type_id)), "behaviour": behaviour,
				"mass": float(def["mass"]), "interval_s": float(def.get("interval_s", 0.0)),
				"levels": levels,
			}
	return lib


func type_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_types.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


func has_type(type_id: StringName) -> bool:
	return _types.has(type_id)


func level_count(type_id: StringName) -> int:
	return (_types[type_id]["levels"] as Array).size() if _types.has(type_id) else 0


func display_name(type_id: StringName) -> String:
	return _types[type_id]["name"] if _types.has(type_id) else String(type_id)


## One thruster's numbers, or {} for an unknown type, size or level. Read-only.
##   behaviour   &"pulse", &"steady" or &"ramp"
##   thrust      steady force; a pulse's average force; a ramp's peak force
##   start       a ramp's force when it switches on (0 otherwise)
##   ramp_s      seconds from start to peak (0 if it doesn't ramp)
##   interval_s  seconds between pulses (0 if it doesn't pulse)
##   mass, price_gc, size_factor
func spec(type_id: StringName, size_code: StringName, level: int) -> Dictionary:
	var key := "%s|%s|%d" % [type_id, size_code, level]
	var cached: Variant = _specs.get(key)
	if cached != null:
		return cached
	if not _types.has(type_id) or not size_factor.has(size_code) or level < 1 or level > level_count(type_id):
		return {}
	var def: Dictionary = _types[type_id]
	var row: Dictionary = def["levels"][level - 1]
	var factor: float = size_factor[size_code]
	var out := {
		"behaviour": def["behaviour"],
		"thrust": float(row["thrust"]) * factor,
		"start": float(row.get("start", 0.0)) * factor,
		"ramp_s": float(row.get("ramp_s", 0.0)),
		"interval_s": def["interval_s"],
		"mass": def["mass"] * factor,
		"price_gc": roundi(float(row["price_gc"]) * factor),
		"size_factor": factor,
	}
	out.make_read_only()
	_specs[key] = out
	return out


## &"pulse" from "thruster.pulse"; &"" if `part` isn't a thruster.
static func type_of_part(part: String) -> StringName:
	return StringName(part.trim_prefix(PART_PREFIX)) if part.begins_with(PART_PREFIX) else &""


static func part_id(type_id: StringName) -> String:
	return PART_PREFIX + String(type_id)

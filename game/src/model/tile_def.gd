class_name TileDef
extends RefCounted
## One tile type from `data/tiles.json` (PLAN.md 4.2), with its stats and cost at any size.

const STAT_KEYS: Array[StringName] = [&"hp", &"armor", &"shield_cap", &"shield_regen", &"mass"]
## Stats that grow with tile size. Armor is a per-hit reduction, so it doesn't.
const SCALED_STATS: Array[StringName] = [&"hp", &"shield_cap", &"shield_regen", &"mass"]

var id: StringName
## Large-size values, keyed by STAT_KEYS.
var base: Dictionary = {}
## Large-size cost: material -> amount.
var base_cost: Dictionary = {}
var unique: bool = false
var has_mounts: bool = false

var _stat_factor: Dictionary
var _cost_factor: Dictionary


func stats(size_code: StringName) -> Dictionary:
	var factor: float = _stat_factor.get(size_code, 0.0)
	var out := {}
	for key in STAT_KEYS:
		out[key] = base[key] * factor if SCALED_STATS.has(key) else base[key]
	return out


## Material -> whole amount. The loader guarantees every size comes out whole.
func cost(size_code: StringName) -> Dictionary:
	var factor: float = _cost_factor.get(size_code, 0.0)
	var out := {}
	for material: StringName in base_cost:
		out[material] = roundi(base_cost[material] * factor)
	return out


static func from_def(tile_id: StringName, def: Dictionary, stat_factor: Dictionary,
		cost_factor: Dictionary, materials: Array[StringName], errors: PackedStringArray) -> TileDef:
	var tile := TileDef.new()
	tile.id = tile_id
	tile._stat_factor = stat_factor
	tile._cost_factor = cost_factor
	for key in STAT_KEYS:
		var value: Variant = def.get(String(key))
		if typeof(value) not in [TYPE_FLOAT, TYPE_INT] or value < 0.0:
			errors.append("%s: %s must be a number >= 0" % [tile_id, key])
			return null
		tile.base[key] = float(value)
	if tile.base[&"mass"] <= 0.0:
		errors.append("%s: mass must be positive" % tile_id)
		return null
	for material: String in def.get("cost", {}):
		if not materials.has(StringName(material)):
			errors.append("%s: unknown material '%s'" % [tile_id, material])
			return null
		tile.base_cost[StringName(material)] = float(def["cost"][material])
	tile.unique = def.get("unique", false)
	tile.has_mounts = def.get("mounts", false)
	for size_code: StringName in cost_factor:
		for material: StringName in tile.base_cost:
			var amount: float = tile.base_cost[material] * cost_factor[size_code]
			if absf(amount - roundf(amount)) > 0.0001:
				errors.append("%s %s costs %.2f %s, not a whole amount" % [tile_id, size_code, amount, material])
	return tile

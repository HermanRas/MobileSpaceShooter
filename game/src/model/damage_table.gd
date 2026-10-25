class_name DamageTable
extends RefCounted
## The damage rules (PLAN.md 4.5), from data/damage_types.json: how much of a hit the shield
## pool soaks up, and what armor does to the rest.

var min_share := 0.2
var regen_delay_s := 3.0
var splash_edge_share := 0.5
## How wrecks behave (Phase 4.2): drift_u, spin, fade_s, explode_chunk_tiles, explode_speed_u.
var wreck: Dictionary = {"drift_u": 0.8, "spin": 0.8, "fade_s": 5.0, "explode_chunk_tiles": 3, "explode_speed_u": 4.0}
var errors: PackedStringArray = []

## Type id -> {vs_shield, vs_hull, armor_factor, disable_s}.
var _types: Dictionary = {}


static func from_table(table: Dictionary) -> DamageTable:
	var out := DamageTable.new()
	out.min_share = float(table.get("min_share", out.min_share))
	out.regen_delay_s = float(table.get("regen_delay_s", out.regen_delay_s))
	out.splash_edge_share = float(table.get("splash_edge_share", out.splash_edge_share))
	var wreck_table: Dictionary = table.get("wreck", {})
	for key: String in out.wreck:
		out.wreck[key] = float(wreck_table.get(key, out.wreck[key]))
	var types: Dictionary = table.get("types", {})
	for type_id: String in types:
		var raw: Dictionary = types[type_id]
		for key in ["vs_shield", "vs_hull", "armor_factor"]:
			if not raw.has(key):
				out.errors.append("damage type %s has no %s" % [type_id, key])
		out._types[StringName(type_id)] = {
			"vs_shield": float(raw.get("vs_shield", 1.0)),
			"vs_hull": float(raw.get("vs_hull", 1.0)),
			"armor_factor": float(raw.get("armor_factor", 1.0)),
			"disable_s": float(raw.get("disable_s", 0.0)),
		}
	return out


func type_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_types.keys())
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


func has_type(type_id: StringName) -> bool:
	return _types.has(type_id)


func vs_shield(type_id: StringName) -> float:
	return _types.get(type_id, {}).get("vs_shield", 1.0)


## How long a hit of this type knocks out shields and thrusters (EMP), else 0.
func disable_s(type_id: StringName) -> float:
	return _types.get(type_id, {}).get("disable_s", 0.0)


## The HP a tile with `armor` loses to `raw` damage of `type_id` that got past the shield.
## `pierce` (0..1) is the share of armor an armour-piercing round ignores.
func tile_damage(raw: float, type_id: StringName, armor: float, pierce := 0.0) -> float:
	var type: Dictionary = _types.get(type_id, {})
	var armor_left := armor * float(type.get("armor_factor", 1.0)) * (1.0 - clampf(pierce, 0.0, 1.0))
	return maxf(raw * float(type.get("vs_hull", 1.0)) - armor_left, raw * min_share)

class_name WeaponXp
extends RefCounted
## Gun levels from XP (PLAN.md 4.4, D8, Phase 4.8b): the curve, what a level does to a gun's
## numbers, and what a kill is worth and to which guns. From `data/weapon_xp.json`; the defaults
## here are that file's numbers.

var max_level := 999
## Total XP to reach level L: base × (L − 1)^power.
var base := 10.0
var power := 2.0
## Damage × (1 + damage_per_level × (L − 1)).
var damage_per_level := 0.01
## A kill: per_tile × tiles × encounter level^level_power.
var per_tile := 1.0
var level_power := 2.0
var errors: PackedStringArray = []


static func from_table(table: Dictionary) -> WeaponXp:
	var xp := WeaponXp.new()
	xp.max_level = int(table.get("max_level", xp.max_level))
	xp.base = float(table.get("curve", {}).get("base", xp.base))
	xp.power = float(table.get("curve", {}).get("power", xp.power))
	xp.damage_per_level = float(table.get("per_level", {}).get("damage", xp.damage_per_level))
	xp.per_tile = float(table.get("kill", {}).get("per_tile", xp.per_tile))
	xp.level_power = float(table.get("kill", {}).get("level_power", xp.level_power))
	if xp.max_level < 2 or xp.base <= 0.0 or xp.power <= 0.0:
		xp.errors.append("max_level must be >= 2, and the curve's base and power > 0")
		xp.max_level = maxi(xp.max_level, 2)
	if xp.damage_per_level < 0.0 or xp.per_tile <= 0.0 or xp.level_power < 0.0:
		xp.errors.append("per_level.damage must be >= 0, kill.per_tile > 0, kill.level_power >= 0")
	return xp


## Total XP a gun needs to be at `level`.
func xp_for(level: int) -> int:
	return roundi(base * pow(float(clampi(level, 1, max_level) - 1), power))


## The level `xp` makes a gun.
func level_for(xp: int) -> int:
	var level := clampi(int(pow(maxf(xp, 0) / base, 1.0 / power)) + 1, 1, max_level)
	# The float guess can be one off either way at a boundary.
	while level < max_level and xp_for(level + 1) <= xp:
		level += 1
	while level > 1 and xp_for(level) > xp:
		level -= 1
	return level


## How far `xp` is from its level to the next (0..1; 1 at the top level).
func progress(xp: int) -> float:
	var level := level_for(xp)
	if level >= max_level:
		return 1.0
	return float(xp - xp_for(level)) / float(xp_for(level + 1) - xp_for(level))


func damage_factor(level: int) -> float:
	return 1.0 + damage_per_level * float(clampi(level, 1, max_level) - 1)


## A gun's numbers (WeaponLib.weapon()) at `level`: damage and splash damage scaled. Read-only.
func scaled(stats: Dictionary, level: int) -> Dictionary:
	if level <= 1 or stats.is_empty():
		return stats
	var out := stats.duplicate()
	var factor := damage_factor(level)
	out["damage"] = float(stats["damage"]) * factor
	out["splash_damage"] = float(stats["splash_damage"]) * factor
	out.make_read_only()
	return out


## What killing a ship of `tiles` tiles at `encounter_level` is worth (at least 1).
func kill_xp(tiles: int, encounter_level: int) -> int:
	return maxi(roundi(per_tile * tiles * pow(float(maxi(encounter_level, 1)), level_power)), 1)


## `total` XP split by `damage_by` (anything -> damage dealt): whole numbers, in proportion,
## that add up to `total` (largest remainders get the leftovers). Nothing for no damage.
static func split(total: int, damage_by: Dictionary) -> Dictionary:
	var sum := 0.0
	for key: Variant in damage_by:
		sum += maxf(float(damage_by[key]), 0.0)
	var out := {}
	if sum <= 0.0 or total <= 0:
		return out
	var given := 0
	var remainders: Array = []
	for key: Variant in damage_by:
		var exact := total * maxf(float(damage_by[key]), 0.0) / sum
		out[key] = floori(exact)
		given += out[key]
		remainders.append([exact - floori(exact), key])
	remainders.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for i in total - given:
		out[remainders[i][1]] += 1
	for key: Variant in out.keys():
		if out[key] == 0:
			out.erase(key)
	return out

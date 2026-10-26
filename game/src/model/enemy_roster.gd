class_name EnemyRoster
extends RefCounted
## The roster of AI-flown ships (PLAN.md 5.1) from `data/enemies.json`: which blueprints exist,
## their tier, role, the AI behaviour that flies them (5.2), the encounter levels they appear at,
## and their faction (`neutral` until v2). The encounter generator (5.3) picks enemies from here;
## an ally (the carrier the player escorts, 12.3) flies on the player's side and is never one.

const DEFAULT_FACTION := &"neutral"


class Entry:
	var id: StringName
	var tier: int
	var role: StringName
	var behaviour: StringName
	var min_level: int
	var max_level: int
	var faction: StringName
	var boss: bool
	## On the player's side (the carrier), not an enemy.
	var ally: bool
	## The AI turns for home below this share of its hull (0: it never does).
	var flee_below: float
	var blueprint: Blueprint

	func fits(level: int) -> bool:
		return level >= min_level and level <= max_level


var entries: Array[Entry] = []
var errors: PackedStringArray = []


## `blueprints`: the parsed `data/enemies/` files (id -> Dictionary).
static func from_table(table: Dictionary, blueprints: Dictionary) -> EnemyRoster:
	var roster := EnemyRoster.new()
	var roles: Array = table.get("roles", [])
	var behaviours: Array = table.get("behaviours", [])
	for id: String in table.get("enemies", {}):
		var raw: Dictionary = table["enemies"][id]
		var levels: Array = raw.get("levels", [])
		var bp_errors: PackedStringArray = []
		var bp := Blueprint.from_dict(blueprints[id], bp_errors) if blueprints.has(id) else null
		var why := ""
		if bp == null:
			why = "no blueprint data/enemies/%s.json %s" % [id, bp_errors]
		elif int(raw.get("tier", 0)) not in [1, 2, 3, 4]:
			why = "tier must be 1-4"
		elif not roles.has(raw.get("role")) or not behaviours.has(raw.get("behaviour")):
			why = "role must be one of %s and behaviour one of %s" % [roles, behaviours]
		elif levels.size() != 2 or int(levels[0]) < 1 or int(levels[1]) < int(levels[0]):
			why = "levels must be [min, max], 1 <= min <= max"
		if not why.is_empty():
			roster.errors.append("%s: %s" % [id, why])
			continue
		var entry := Entry.new()
		entry.id = StringName(id)
		entry.tier = int(raw["tier"])
		entry.role = StringName(raw["role"])
		entry.behaviour = StringName(raw["behaviour"])
		entry.min_level = int(levels[0])
		entry.max_level = int(levels[1])
		entry.faction = StringName(raw.get("faction", DEFAULT_FACTION))
		entry.boss = bool(raw.get("boss", false))
		entry.ally = bool(raw.get("ally", false))
		entry.flee_below = clampf(float(raw.get("flee_below", 0.0)), 0.0, 1.0)
		entry.blueprint = bp
		roster.entries.append(entry)
	return roster


func entry(id: StringName) -> Entry:
	for each in entries:
		if each.id == id:
			return each
	return null


## The ordinary enemies (no bosses, no allies) that appear at `level`.
func for_level(level: int) -> Array[Entry]:
	var out: Array[Entry] = []
	for each in entries:
		if not each.boss and not each.ally and each.fits(level):
			out.append(each)
	return out


## The boss of `tier`, or null.
func boss(tier: int) -> Entry:
	for each in entries:
		if each.boss and each.tier == tier:
			return each
	return null

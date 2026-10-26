class_name Encounter
extends RefCounted
## What a fight at an encounter level brings (PLAN.md 5.3, §4.8): which enemies, their gun levels
## and the share of their damage they deal, from `data/levels.json` and the roster. Every mode
## asks this one generator (Creative's test, WaveTime's waves, Story's tiles), so balance lives in
## one place. Deterministic: the same level and seed give the same encounter.

## One enemy to spawn.
class Spawn:
	var id: StringName
	var gun_level: int
	var boss := false


var level: int
var seed_value: int
## Tiles' worth of enemies this level may spend, and what was spent.
var budget: int
var spent: int
## The share of their guns' damage these enemies deal.
var damage := 1.0
var spawns: Array[Spawn] = []


## The rules from levels.json; `errors` collects what's wrong with them.
class Rules:
	var base := 8.0
	var per_level := 1.6
	var power := 1.15
	var gun_per_level := 10.0
	var gun_spread := 0.2
	## [{"to", "tiers": {tier int: weight}, "count": [min, max], "damage"}], by "to" ascending.
	var bands: Array[Dictionary] = []
	var errors: PackedStringArray = []

	static func from_table(table: Dictionary) -> Rules:
		var rules := Rules.new()
		var budget: Dictionary = table.get("budget", {})
		rules.base = float(budget.get("base", rules.base))
		rules.per_level = float(budget.get("per_level", rules.per_level))
		rules.power = float(budget.get("power", rules.power))
		rules.gun_per_level = float(table.get("gun_level", {}).get("per_level", rules.gun_per_level))
		rules.gun_spread = clampf(float(table.get("gun_level", {}).get("spread", rules.gun_spread)), 0.0, 0.9)
		var last := 0
		for raw: Variant in table.get("bands", []):
			var band: Dictionary = raw
			var count: Array = band.get("count", [])
			var tiers := {}
			for tier: String in band.get("tiers", {}):
				tiers[int(tier)] = float(band["tiers"][tier])
			if int(band.get("to", 0)) <= last or count.size() != 2 or int(count[0]) < 1 or int(count[1]) < int(count[0]) \
					or tiers.is_empty() or float(band.get("damage", 0.0)) <= 0.0:
				rules.errors.append("band to %s: needs a rising `to`, tiers, count [min >= 1, max] and damage > 0" % band.get("to"))
				continue
			last = int(band["to"])
			rules.bands.append({"to": last, "tiers": tiers, "count": [int(count[0]), int(count[1])], "damage": float(band["damage"])})
		if rules.bands.is_empty() or last < 100:
			rules.errors.append("bands must cover levels 1-100")
		if rules.base <= 0.0 or rules.per_level <= 0.0 or rules.power <= 0.0:
			rules.errors.append("budget: base, per_level and power must be > 0")
		return rules

	func budget_for(at_level: int) -> int:
		return roundi(base + per_level * pow(float(maxi(at_level, 1)), power))

	func band_for(at_level: int) -> Dictionary:
		for band in bands:
			if at_level <= int(band["to"]):
				return band
		return bands.back() if not bands.is_empty() else {}


## The encounter at `at_level` with `with_seed`. `with_boss`: a Kill HVT fight (12.2), led by the
## boss whose levels fit (none if no boss fits).
static func generate(rules: Rules, roster: EnemyRoster, at_level: int, with_seed: int, with_boss := false) -> Encounter:
	var out := Encounter.new()
	out.level = clampi(at_level, 1, 100)
	out.seed_value = with_seed
	out.budget = rules.budget_for(out.level)
	var band := rules.band_for(out.level)
	out.damage = float(band.get("damage", 1.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([with_seed, out.level, with_boss])
	if with_boss:
		for entry in roster.entries:
			if entry.boss and not entry.ally and entry.fits(out.level):
				out._add(entry, rules, rng, true)
				break
	var pool := {}  # tier -> entries that fit the level
	for entry in roster.for_level(out.level):
		if not pool.has(entry.tier):
			pool[entry.tier] = []
		pool[entry.tier].append(entry)
	var tiers := {}
	for tier: int in band.get("tiers", {}):
		if pool.has(tier) and float(band["tiers"][tier]) > 0.0:
			tiers[tier] = float(band["tiers"][tier])
	if tiers.is_empty():
		return out
	var count: Array = band["count"]
	var wanted := rng.randi_range(int(count[0]), int(count[1]))
	var tries := 0
	while out.spawns.size() < wanted + (1 if with_boss and not out.spawns.is_empty() else 0) and tries < 50:
		tries += 1
		var tier := _weighted(tiers, rng)
		var options: Array = pool[tier]
		var entry: EnemyRoster.Entry = options[rng.randi_range(0, options.size() - 1)]
		var cost := entry.blueprint.tiles.size()
		# Over budget: skip it, unless the band's minimum count isn't met yet.
		if out.spent + cost > out.budget and out.spawns.size() >= int(count[0]):
			continue
		out._add(entry, rules, rng, false)
	return out


func _add(entry: EnemyRoster.Entry, rules: Rules, rng: RandomNumberGenerator, is_boss: bool) -> void:
	var spawn := Spawn.new()
	spawn.id = entry.id
	spawn.boss = is_boss
	var centre := rules.gun_per_level * level
	spawn.gun_level = clampi(roundi(centre * (1.0 + rng.randf_range(-rules.gun_spread, rules.gun_spread))), 1, 999)
	spawns.append(spawn)
	spent += entry.blueprint.tiles.size()


static func _weighted(weights: Dictionary, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for key: int in weights:
		total += weights[key]
	var roll := rng.randf() * total
	for key: int in weights:
		roll -= weights[key]
		if roll <= 0.0:
			return key
	return weights.keys().back()

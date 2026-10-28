class_name Economy
extends RefCounted
## What building costs outside Creative (PLAN.md 4.6, 4.8a): tiles cost their materials, guns
## and thrusters their `price_gc`, and Sell pays `sell_rate` of a part's price, rounded down.
## The market trades materials for GC, and a kill drops a share of what the enemy is built of
## (4.8c), as pickups (5.4), and now and then one of its parts. From `data/economy.json`.

var sell_rate := 0.75
## Material -> amount, for reinstalling a gun on another mount type (PLAN.md 4.4).
var refit: Dictionary = {}
## Material -> {"buy": GC a unit, "sell": GC a unit}; buying costs more than selling earns.
var market: Dictionary = {}
## A kill drops drop_share of the materials the enemy's tiles cost, drop_tech_per_part Tech a
## mounted part and drop_gc_per_tile GC a tile, all × (1 + drop_per_level × (encounter level − 1)).
var drop_share := 0.02
var drop_tech_per_part := 1.0
var drop_gc_per_tile := 2.0
var drop_per_level := 0.25
## The chance a kill also drops one of its guns or thrusters (5.4), and how many pickups at most
## each resource of a kill is split into.
var part_chance := 0.04
var drop_pieces := 3
var errors: PackedStringArray = []


static func from_table(table: Dictionary) -> Economy:
	var economy := Economy.new()
	economy.sell_rate = float(table.get("sell_rate", 0.75))
	if economy.sell_rate <= 0.0 or economy.sell_rate > 1.0:
		economy.errors.append("sell_rate must be in (0, 1]")
	for material: String in table.get("refit", {}):
		if not Inventory.MATERIALS.has(StringName(material)):
			economy.errors.append("refit: unknown material %s" % material)
		else:
			economy.refit[StringName(material)] = int(table["refit"][material])
	for material: String in table.get("market", {}):
		if material.begins_with("_"):
			continue
		var row: Variant = table["market"][material]
		if not Inventory.MATERIALS.has(StringName(material)) or typeof(row) != TYPE_DICTIONARY \
				or int(row.get("sell", 0)) <= 0 or int(row.get("buy", 0)) <= int(row.get("sell", 0)):
			economy.errors.append("market %s: a material, with buy > sell > 0" % material)
			continue
		economy.market[StringName(material)] = {"buy": int(row["buy"]), "sell": int(row["sell"])}
	var drops: Dictionary = table.get("drops", {})
	economy.drop_share = float(drops.get("share", economy.drop_share))
	economy.drop_tech_per_part = float(drops.get("tech_per_part", economy.drop_tech_per_part))
	economy.drop_gc_per_tile = float(drops.get("gc_per_tile", economy.drop_gc_per_tile))
	economy.drop_per_level = float(drops.get("per_level", economy.drop_per_level))
	economy.part_chance = float(drops.get("part_chance", economy.part_chance))
	economy.drop_pieces = int(drops.get("pieces", economy.drop_pieces))
	if economy.drop_share < 0.0 or economy.drop_tech_per_part < 0.0 or economy.drop_gc_per_tile < 0.0 \
			or economy.drop_per_level < 0.0:
		economy.errors.append("drops: share, tech_per_part, gc_per_tile and per_level must be >= 0")
	if economy.part_chance < 0.0 or economy.part_chance > 1.0 or economy.drop_pieces < 1:
		economy.errors.append("drops: part_chance in [0, 1], pieces >= 1")
	return economy


## What killing `bp` (as it was built) at `encounter_level` drops: materials and GC, rounded
## down. It follows what the ship is made of, so shield ships drop Crystal (PLAN.md 4.6).
func kill_loot(placement: Placement, bp: Blueprint, encounter_level: int) -> Dictionary:
	var factor := 1.0 + drop_per_level * float(maxi(encounter_level, 1) - 1)
	var out := {}
	var built := tiles_cost(placement, bp)
	var parts := bp.mounts.filter(func(mount: Dictionary) -> bool:
		return Mounting.is_weapon(mount) or Mounting.is_thruster(mount)).size()
	for material: StringName in Inventory.MATERIALS:
		var amount := floori((int(built.get(material, 0)) * drop_share
				+ (drop_tech_per_part * parts if material == &"tech" else 0.0)) * factor + 1e-6)
		if amount > 0:
			out[material] = amount
	var gc := floori(drop_gc_per_tile * bp.tiles.size() * factor + 1e-6)
	if gc > 0:
		out[Inventory.GC] = gc
	return out


## The part a kill drops, if `roll` (0..1) falls under part_chance: one of `bp`'s guns or
## thrusters, chosen by `pick`. A gun keeps the XP of `gun_level`, the level it fought at.
## {"gun": weapon id, "mount": mount type, "xp"} or {"thruster": Inventory.thruster_key()}, or {}.
func part_drop(placement: Placement, bp: Blueprint, roll: float, pick: int, gun_level: int) -> Dictionary:
	if roll >= part_chance:
		return {}
	var parts := bp.mounts.filter(func(mount: Dictionary) -> bool:
		return Mounting.is_weapon(mount) or Mounting.is_thruster(mount))
	if parts.is_empty():
		return {}
	var mount: Dictionary = parts[posmod(pick, parts.size())]
	if Mounting.is_thruster(mount):
		return {"thruster": Inventory.key_of(mount)}
	var xp := placement.weapons.xp
	return {"gun": WeaponLib.type_of_part(str(mount["part"])), "mount": StringName(mount["mount"]),
			"xp": xp.xp_for(clampi(gun_level, 1, xp.max_level))}


## `loot` split into pickups: [{resource: amount}], at most drop_pieces a resource, as even as
## whole numbers allow.
func loot_pieces(loot: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for resource: StringName in loot:
		var total := int(loot[resource])
		var count := mini(drop_pieces, total)
		for i in count:
			out.append({resource: total / count + (1 if i < total % count else 0)})
	return out


## What buying (`amount` > 0) or selling (< 0) that much of `material` costs: {resource: n} to
## pay and {resource: n} to receive, as [pay, receive]; [] if the market doesn't trade it.
func trade(material: StringName, amount: int) -> Array:
	if not market.has(material) or amount == 0:
		return []
	if amount > 0:
		return [{Inventory.GC: market[material]["buy"] * amount}, {material: amount}]
	return [{material: -amount}, {Inventory.GC: market[material]["sell"] * -amount}]


## A gun's or thruster's price, as {&"gc": n}.
static func part_price(placement: Placement, mount: Dictionary) -> Dictionary:
	if Mounting.is_weapon(mount):
		return {Inventory.GC: int(placement.weapons.weapon(WeaponLib.type_of_part(str(mount["part"])))["price_gc"])}
	var spec := placement.thrusters.spec(ThrusterLib.type_of_part(str(mount["part"])), StringName(mount["size"]),
			int(mount["level"]))
	return {Inventory.GC: int(spec["price_gc"])}


## What building `bp` from nothing costs: its tiles' materials and its parts' GC (a library
## ship's price in the shop, PLAN.md 7.3).
static func build_cost(placement: Placement, bp: Blueprint) -> Dictionary:
	var total := tiles_cost(placement, bp)
	for mount in bp.mounts:
		if Mounting.is_weapon(mount) or Mounting.is_thruster(mount):
			total = add(total, part_price(placement, mount))
	return total


## The materials `bp`'s tiles cost (the core is free).
static func tiles_cost(placement: Placement, bp: Blueprint) -> Dictionary:
	var total := {}
	for tile in bp.tiles:
		var cost := placement.tiles.tile(tile.type).cost(tile.size)
		for material: StringName in cost:
			total[material] = int(total.get(material, 0)) + int(cost[material])
	return total


## What selling something that cost `cost` pays: sell_rate of each, rounded down.
func sell_value(cost: Dictionary) -> Dictionary:
	var out := {}
	for resource: StringName in cost:
		out[resource] = floori(int(cost[resource]) * sell_rate + 1e-6)  # 0.29 × 100 is 28.999…
	return out


## `a` + `b` × `times`, resource by resource.
static func add(a: Dictionary, b: Dictionary, times := 1) -> Dictionary:
	var out := a.duplicate()
	for resource: StringName in b:
		out[resource] = int(out.get(resource, 0)) + int(b[resource]) * times
	return out

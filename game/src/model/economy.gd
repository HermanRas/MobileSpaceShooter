class_name Economy
extends RefCounted
## What building costs outside Creative (PLAN.md 4.6, 4.8a): tiles cost their materials, guns
## and thrusters their `price_gc`, and Sell pays `sell_rate` of a part's price, rounded down.
## The market trades materials for GC, and a kill pays a share of what the enemy is built of
## (4.8c). From `data/economy.json`.

var sell_rate := 0.75
## Material -> amount, for reinstalling a gun on another mount type (PLAN.md 4.4).
var refit: Dictionary = {}
## Material -> {"buy": GC a unit, "sell": GC a unit}; buying costs more than selling earns.
var market: Dictionary = {}
## A kill pays drop_share of the materials the enemy's tiles cost and drop_gc_per_tile GC a
## tile, both × (1 + drop_per_level × (encounter level − 1)).
var drop_share := 0.02
var drop_gc_per_tile := 2.0
var drop_per_level := 0.25
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
	economy.drop_gc_per_tile = float(drops.get("gc_per_tile", economy.drop_gc_per_tile))
	economy.drop_per_level = float(drops.get("per_level", economy.drop_per_level))
	if economy.drop_share < 0.0 or economy.drop_gc_per_tile < 0.0 or economy.drop_per_level < 0.0:
		economy.errors.append("drops: share, gc_per_tile and per_level must be >= 0")
	return economy


## What killing `bp` (as it was built) at `encounter_level` pays: materials and GC, rounded down.
func kill_loot(placement: Placement, bp: Blueprint, encounter_level: int) -> Dictionary:
	var factor := 1.0 + drop_per_level * float(maxi(encounter_level, 1) - 1)
	var out := {}
	var built := tiles_cost(placement, bp)
	for material: StringName in built:
		var amount := floori(int(built[material]) * drop_share * factor + 1e-6)
		if amount > 0:
			out[material] = amount
	var gc := floori(drop_gc_per_tile * bp.tiles.size() * factor + 1e-6)
	if gc > 0:
		out[Inventory.GC] = gc
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

class_name Economy
extends RefCounted
## What building costs outside Creative (PLAN.md 4.6, 4.8a): tiles cost their materials, guns
## and thrusters their `price_gc`, and Sell pays `sell_rate` of a part's price, rounded down.
## From `data/economy.json`.

var sell_rate := 0.75
## Material -> amount, for reinstalling a gun on another mount type (PLAN.md 4.4).
var refit: Dictionary = {}
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
	return economy


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

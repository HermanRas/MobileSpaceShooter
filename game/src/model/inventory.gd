class_name Inventory
extends RefCounted
## A profile's stock (PLAN.md 4.6, 4.8a): its materials and GC, every gun it owns, and the
## thrusters it has loose.
##
## A gun is an item with its own XP, whether it's fitted or loose: a fitted one is named by its
## weapon mount (`"gun": "<id>"`, §5.4), so which guns are loose depends on the ship
## (`loose_guns`). Thrusters have no identity, so only the loose ones are counted here.

const MATERIALS: Array[StringName] = [&"hull", &"alloy", &"crystal", &"tech"]
const GC := &"gc"
const FORMAT := 1


## One gun the profile owns.
class GunItem:
	var id: String
	var weapon: StringName
	## The mount type it was last fitted to; reinstalling it on another is a refit (PLAN.md 4.4).
	var mount: StringName
	var xp: int = 0

	func to_dict() -> Dictionary:
		return {"id": id, "weapon": String(weapon), "mount": String(mount), "xp": xp}


## Material or GC -> amount.
var wallet: Dictionary = {}
## Every gun owned, fitted or loose: id -> GunItem.
var guns: Dictionary = {}
## Loose thrusters: thruster_key() -> count.
var thrusters: Dictionary = {}

var _next_gun := 1


func amount(resource: StringName) -> int:
	return int(wallet.get(resource, 0))


## The first resource `cost` needs more of than the wallet holds, or &"" if it can be paid.
func short_of(cost: Dictionary) -> StringName:
	for resource: StringName in cost:
		if int(cost[resource]) > amount(resource):
			return resource
	return &""


## Takes `cost` from the wallet; false (and nothing taken) if it can't.
func pay(cost: Dictionary) -> bool:
	if short_of(cost) != &"":
		return false
	for resource: StringName in cost:
		wallet[resource] = amount(resource) - int(cost[resource])
	return true


func receive(cost: Dictionary) -> void:
	for resource: StringName in cost:
		wallet[resource] = amount(resource) + int(cost[resource])


## A new gun item (a bought one, or one fitted to a new profile's first ship).
func new_gun(weapon: StringName, mount: StringName) -> GunItem:
	var item := GunItem.new()
	item.id = "g%d" % _next_gun
	_next_gun += 1
	item.weapon = weapon
	item.mount = mount
	guns[item.id] = item
	return item


## The guns no mount of `bp` names, sorted by weapon, then highest XP first.
func loose_guns(bp: Blueprint) -> Array[GunItem]:
	var fitted := fitted_ids(bp)
	var out: Array[GunItem] = []
	for id: String in guns:
		if not fitted.has(id):
			out.append(guns[id])
	out.sort_custom(func(a: GunItem, b: GunItem) -> bool:
		return [a.weapon, -a.xp, a.id] < [b.weapon, -b.xp, b.id])
	return out


## The gun ids `bp`'s mounts name, as a set.
static func fitted_ids(bp: Blueprint) -> Dictionary:
	var out := {}
	for mount in bp.mounts:
		if mount.has("gun"):
			out[str(mount["gun"])] = true
	return out


static func thruster_key(type_id: StringName, size: StringName, level: int) -> String:
	return "%s:%s:%d" % [type_id, size, level]


## [type id, size, level] from a thruster_key().
static func thruster_parts(key: String) -> Array:
	var parts := key.split(":")
	return [StringName(parts[0]), StringName(parts[1]), int(parts[2])]


## The thruster_key() of a thruster mount.
static func key_of(mount: Dictionary) -> String:
	return thruster_key(ThrusterLib.type_of_part(str(mount["part"])), StringName(mount["size"]), int(mount["level"]))


func add_thrusters(key: String, count: int) -> void:
	thrusters[key] = int(thrusters.get(key, 0)) + count
	if thrusters[key] <= 0:
		thrusters.erase(key)



## Adds a gun found in flight (PLAN.md 5.4) with the XP it came with.
func add_found_gun(weapon: StringName, mount: StringName, xp: int) -> GunItem:
	var item := new_gun(weapon, mount)
	item.xp = xp
	return item


## Moves everything in `cargo` (a run's pickups) into this stock; guns get ids here.
func bank(cargo: Inventory) -> void:
	receive(cargo.wallet)
	for id: String in cargo.guns:
		var found: GunItem = cargo.guns[id]
		add_found_gun(found.weapon, found.mount, found.xp)
	for key: String in cargo.thrusters:
		add_thrusters(key, cargo.thrusters[key])
	cargo.wallet.clear()
	cargo.guns.clear()
	cargo.thrusters.clear()


## Whether there's nothing in it.
func is_empty() -> bool:
	return guns.is_empty() and thrusters.is_empty() and wallet.values().all(func(n: Variant) -> bool: return int(n) == 0)


func to_dict() -> Dictionary:
	var wallet_out := {}
	for resource: StringName in wallet:
		wallet_out[String(resource)] = wallet[resource]
	var guns_out: Array = []
	for id: String in guns:
		guns_out.append((guns[id] as GunItem).to_dict())
	return {"format": FORMAT, "wallet": wallet_out, "guns": guns_out, "thrusters": thrusters.duplicate(),
			"next_gun": _next_gun}


static func from_dict(data: Dictionary, errors: PackedStringArray) -> Inventory:
	var inv := Inventory.new()
	if int(data.get("format", FORMAT)) != FORMAT:
		errors.append("inventory: unknown format %s" % data.get("format"))
		return inv
	for resource: String in data.get("wallet", {}):
		var name := StringName(resource)
		if not MATERIALS.has(name) and name != GC:
			errors.append("inventory: unknown resource %s" % resource)
			continue
		inv.wallet[name] = int(data["wallet"][resource])
	for raw: Variant in data.get("guns", []):
		if typeof(raw) != TYPE_DICTIONARY or not (raw as Dictionary).has_all(["id", "weapon", "mount"]):
			errors.append("inventory: bad gun %s" % [raw])
			continue
		var item := GunItem.new()
		item.id = str(raw["id"])
		item.weapon = StringName(str(raw["weapon"]))
		item.mount = StringName(str(raw["mount"]))
		item.xp = int(raw.get("xp", 0))
		inv.guns[item.id] = item
	for key: String in data.get("thrusters", {}):
		if key.split(":").size() == 3 and int(data["thrusters"][key]) > 0:
			inv.thrusters[key] = int(data["thrusters"][key])
	inv._next_gun = maxi(int(data.get("next_gun", 1)), inv.guns.size() + 1)
	while inv.guns.has("g%d" % inv._next_gun):
		inv._next_gun += 1
	return inv

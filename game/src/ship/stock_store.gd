class_name StockStore
extends RefCounted
## A profile's hangar between visits (PLAN.md 4.8a): its inventory, the ship it's building and the
## ships it has parked (7.3), in `<profile dir>/hangar.json`, written through `Save`. A new profile
## starts with the stock `economy.json` gives it: that ship, with an inventory gun item fitted to
## each of its guns, and that wallet.

const FILE := "hangar.json"
## 2 added the parked ships (7.3); a format 1 save has none.
const FORMAT := 2

var path: String
var inventory: Inventory
var ship: Blueprint
## The pilot's other ships (HangarEditor.parked).
var parked: Array[Dictionary] = []


## The stock saved in `profile_dir`, or a new one from `start` (economy.json's `new_pilot`) and
## the sample ships (`data/blueprints`, as id -> parsed JSON).
static func open(profile_dir: String, start: Dictionary, samples: Dictionary) -> StockStore:
	var store := StockStore.new()
	store.path = profile_dir.path_join(FILE)
	var errors: PackedStringArray = []
	var saved := Save.read_json(store.path) if FileAccess.file_exists(store.path) \
			or FileAccess.file_exists(store.path + Save.BAK_SUFFIX) else {}
	if int(saved.get("format", 0)) in [1, FORMAT]:
		store.inventory = Inventory.from_dict(saved.get("inventory", {}), errors)
		store.ship = Blueprint.from_dict(saved.get("ship", {}), errors)
		for record: Variant in saved.get("parked", []):
			if typeof(record) == TYPE_DICTIONARY and typeof(record.get("ship")) == TYPE_DICTIONARY:
				store.parked.append(record)
	if store.ship == null:
		store.inventory = Inventory.new()
		for resource: String in start.get("wallet", {}):
			store.inventory.wallet[StringName(resource)] = int(start["wallet"][resource])
		store.ship = Blueprint.from_dict(samples.get(str(start.get("ship", "starter")), {}), errors)
		if store.ship == null:
			return null
		for mount in store.ship.mounts:
			if Mounting.is_weapon(mount):
				mount["gun"] = store.inventory.new_gun(WeaponLib.type_of_part(str(mount["part"])),
						StringName(mount["mount"])).id
	for error in errors:
		push_warning("StockStore %s: %s" % [store.path, error])
	return store


func save() -> Error:
	return Save.write_json(path, {"format": FORMAT, "inventory": inventory.to_dict(), "ship": ship.to_dict(),
			"parked": parked})


## Deletes the saved stock (and its backup): the next open() starts the profile over.
func erase() -> void:
	for file in [path, path + Save.BAK_SUFFIX]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)

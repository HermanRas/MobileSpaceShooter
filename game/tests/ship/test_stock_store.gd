extends TestCase
## A pilot's hangar file keeps the parked ships (7.3, format 2), and a format 1 file from before
## owned ships still opens, with none parked.

const DIR := "user://test_stock_store"


func before_each() -> void:
	_wipe()
	DirAccess.make_dir_recursive_absolute(DIR)


func after_each() -> void:
	_wipe()


func test_parked_ships_survive_a_save() -> void:
	var store := _open()
	store.parked = [{"ship": Data.json_dir("blueprints")["gunboat"], "guns": [{"id": "g9", "weapon": "cannon", "mount": "fixed", "xp": 40}]}]
	assert_eq(store.save(), OK)
	var again := _open()
	assert_eq(again.parked.size(), 1)
	assert_eq(again.parked[0]["guns"][0]["id"], "g9", "with their guns")
	assert_eq(again.ship.id, "starter", "and the flown ship")


func test_a_format_1_save_opens_with_nothing_parked() -> void:
	var store := _open()
	store.inventory.wallet[&"gc"] = 777
	Save.write_json(store.path, {"format": 1, "inventory": store.inventory.to_dict(), "ship": store.ship.to_dict()})
	var old := _open()
	assert_eq(old.inventory.amount(&"gc"), 777, "the old stock is kept, not started over")
	assert_eq(old.parked.size(), 0)


func _open() -> StockStore:
	return StockStore.open(DIR, Data.table(&"economy").get("new_pilot", {}), Data.json_dir("blueprints"))


func _wipe() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for file_name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))
	DirAccess.remove_absolute(DIR)

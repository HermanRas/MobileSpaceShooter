extends TestCase
## Phase 7.3: publishing marks a library ship for sale (no second store), signed by its pilot.
## The shops list every published ship that can fly, at what building it costs.

const DIR := "user://test_publish_library"

var library: BlueprintLibrary
var placement: Placement


func before_each() -> void:
	library = BlueprintLibrary.new(DIR)
	var tiles_table := Data.table(&"tiles")
	placement = Placement.create(ShapeLib.from_table(Data.table(&"shapes")),
			TileLib.from_table(tiles_table), tiles_table)
	placement.thrusters = ThrusterLib.from_table(Data.table(&"thrusters"))
	placement.weapons = WeaponLib.from_table(Data.table(&"weapons"), Data.table(&"weapon_xp"))
	_wipe()
	library.seed_samples(Data.json_dir("blueprints"))


func after_each() -> void:
	_wipe()


func test_nothing_is_for_sale_until_published() -> void:
	assert_eq(library.for_sale(placement).size(), 0)
	assert_true(library.list().all(func(entry: Dictionary) -> bool: return not entry["published"]))


func test_a_published_ship_is_for_sale_signed_and_priced() -> void:
	assert_eq(library.publish("gunboat", true, "Ada"), OK)
	var entry := _entry("gunboat")
	assert_true(entry["published"])
	assert_eq(entry["author"], "Ada", "the author is shown")
	var shop := library.for_sale(placement)
	assert_eq(shop.size(), 1)
	assert_eq(shop[0]["id"], "gunboat")
	assert_eq(shop[0]["cost"], Economy.build_cost(placement, library.load_ship("gunboat")))
	assert_eq(library.publish("gunboat", false), OK)
	assert_eq(library.for_sale(placement).size(), 0, "unpublished, it's off sale")
	assert_eq(library.load_ship("gunboat").author, "Ada", "but still signed")


func test_a_ship_that_cant_fly_isnt_offered() -> void:
	library.publish("gunboat", true, "Ada")
	var broken := library.load_ship("gunboat")
	broken.tiles.erase(broken.tiles.filter(func(t: Blueprint.Tile) -> bool: return t.type == &"core")[0])
	library.save_ship(broken)
	var ids := library.for_sale(placement).map(func(entry: Dictionary) -> String: return entry["id"])
	assert_false(ids.has("gunboat"), "a coreless ship isn't for sale")


func _entry(id: String) -> Dictionary:
	for entry in library.list():
		if entry["id"] == id:
			return entry
	return {}


func _wipe() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for file_name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))
	DirAccess.remove_absolute(DIR)

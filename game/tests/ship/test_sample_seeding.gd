extends TestCase
## The game's sample ships reach the device's ship library (BlueprintLibrary.seed_samples): once
## each, again only when the game ships a changed one, and a deleted one stays deleted until then.

const DIR := "user://test_seed_library"

var library: BlueprintLibrary


func before_each() -> void:
	library = BlueprintLibrary.new(DIR)
	_wipe()


func after_each() -> void:
	_wipe()


func test_every_sample_lands_in_the_library_once() -> void:
	var samples := Data.json_dir("blueprints")
	var written := library.seed_samples(samples)
	assert_eq(written.size(), samples.size(), "all of them the first time")
	assert_true(library.has("gunboat") and library.has("test_laser"), "the samples and the weapon test ships")
	assert_eq(library.load_ship("test_rocket_homing_he").name, "Seeker HE test", "named after their weapon")
	assert_eq(library.list().size(), samples.size(), "the record file isn't listed as a ship")
	assert_eq(library.seed_samples(samples).size(), 0, "not again")


func test_a_deleted_sample_stays_gone_until_it_changes() -> void:
	var samples := Data.json_dir("blueprints")
	library.seed_samples(samples)
	library.delete("gunboat")
	assert_eq(library.seed_samples(samples).size(), 0, "deleting it doesn't bring it back")
	var changed: Dictionary = samples["gunboat"].duplicate(true)
	changed["name"] = "Gunboat II"
	samples["gunboat"] = changed
	assert_eq(library.seed_samples(samples), PackedStringArray(["gunboat"]), "a new version does")
	assert_eq(library.load_ship("gunboat").name, "Gunboat II")


func _wipe() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for file_name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))
	DirAccess.remove_absolute(DIR)

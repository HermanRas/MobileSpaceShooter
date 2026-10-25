extends TestCase
## Atomic JSON saves (PLAN.md 5.2; the full set of save tests is Phase 6.3).

const DIR := "user://test_save"
const PATH := DIR + "/thing.json"


func before_each() -> void:
	_wipe()


func after_each() -> void:
	_wipe()


func test_round_trip() -> void:
	assert_eq(Save.write_json(PATH, {"format": 1, "name": "viper"}), OK)
	var back := Save.read_json(PATH)
	assert_eq(back.get("name"), "viper")


func test_second_write_keeps_the_first_as_backup() -> void:
	Save.write_json(PATH, {"format": 1, "n": 1})
	Save.write_json(PATH, {"format": 1, "n": 2})
	assert_eq(Save.read_json(PATH).get("n"), 2.0)
	assert_true(FileAccess.file_exists(PATH + Save.BAK_SUFFIX))


func test_corrupt_file_falls_back_to_backup() -> void:
	Save.write_json(PATH, {"format": 1, "n": 1})
	Save.write_json(PATH, {"format": 1, "n": 2})
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	assert_eq(Save.read_json(PATH).get("n"), 1.0)


func test_missing_file_reads_empty() -> void:
	assert_true(Save.read_json(PATH).is_empty())


func _wipe() -> void:
	for suffix in ["", Save.TMP_SUFFIX, Save.BAK_SUFFIX]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)

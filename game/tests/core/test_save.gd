extends TestCase
## Atomic JSON saves (PLAN.md 6.3): a write killed at any point keeps the last good save, a
## corrupt file falls back to the backup, and old files migrate step by step.

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


func test_a_write_killed_while_writing_keeps_the_last_save() -> void:
	Save.write_json(PATH, {"format": 1, "n": 1})
	_raw(PATH + Save.TMP_SUFFIX, '{"format": 1, "n": 2, "na')  # the app died mid-write
	assert_eq(Save.read_json(PATH).get("n"), 1.0, "a half-written temp file is ignored")
	Save.write_json(PATH, {"format": 1, "n": 3})
	assert_eq(Save.read_json(PATH).get("n"), 3.0, "and the next save goes through")
	assert_false(FileAccess.file_exists(PATH + Save.TMP_SUFFIX), "leaving no temp file")


func test_a_write_killed_between_its_renames_keeps_the_new_save() -> void:
	Save.write_json(PATH, {"format": 1, "n": 1})
	# The new file is complete, the old one moved to .bak, and then the app died.
	DirAccess.rename_absolute(PATH, PATH + Save.BAK_SUFFIX)
	_raw(PATH + Save.TMP_SUFFIX, JSON.stringify({"format": 1, "n": 2}))
	assert_eq(Save.read_json(PATH).get("n"), 2.0, "the finished temp file is the newest save")
	_raw(PATH + Save.TMP_SUFFIX, "")
	assert_eq(Save.read_json(PATH).get("n"), 1.0, "and without it, the backup")


func test_an_old_file_migrates_step_by_step() -> void:
	var steps := {
		0: func(d: Dictionary) -> Dictionary:
			d["name"] = d.get("pilot", "")
			d.erase("pilot")
			return d,
		1: func(d: Dictionary) -> Dictionary:
			d["kills"] = 0
			return d,
	}
	_raw(PATH, JSON.stringify({"pilot": "viper"}))  # v0: no format field
	var back := Save.read_versioned(PATH, 2, steps)
	assert_eq(back, {"format": 2, "name": "viper", "kills": 0}, "v0 -> v1 -> v2")
	assert_eq(Save.read_versioned(PATH, 3, steps), {}, "a missing step reads as nothing")
	_raw(PATH, JSON.stringify({"format": 9, "name": "from the future"}))
	assert_eq(Save.read_versioned(PATH, 2, steps), {}, "nor is a newer build's file read as ours")
	assert_eq(Save.migrate({"format": 2, "x": 1}, 2, {}), {"format": 2, "x": 1}, "a current file is untouched")


func _raw(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _wipe() -> void:
	for suffix in ["", Save.TMP_SUFFIX, Save.BAK_SUFFIX]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)

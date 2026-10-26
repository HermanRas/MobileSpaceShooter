extends TestCase
## Phase 6.2: a pilot's name, id, character and record, and how they save.

var table: Dictionary


func before_each() -> void:
	table = Data.table(&"characters")


func test_names_are_cleaned() -> void:
	assert_eq(ProfileRecord.clean_name("  Ace   Vanguard\t9 ", 16), "Ace Vanguard 9")
	assert_eq(ProfileRecord.clean_name("A very long pilot name indeed", 16), "A very long pilo")
	assert_eq(ProfileRecord.clean_name("   ", 16), "", "only spaces is no name")


func test_ids_are_folder_safe_and_unique() -> void:
	assert_eq(ProfileRecord.make_id("Ace Vanguard 9!", []), "ace-vanguard-9")
	assert_eq(ProfileRecord.make_id("Ace", ["ace"]), "ace-2")
	assert_eq(ProfileRecord.make_id("Ace", ["ace", "ace-2"]), "ace-3")
	assert_eq(ProfileRecord.make_id("☆☆", []), "pilot", "nothing usable falls back to pilot")


func test_a_new_pilot_starts_with_the_first_base_and_swatches() -> void:
	var record := ProfileRecord.create(" Viper ", table, ["viper"], 1000)
	assert_eq(record.name, "Viper")
	assert_eq(record.id, "viper-2")
	assert_eq(record.character["base"], table["bases"][0])
	for region in ProfileRecord.REGIONS:
		assert_eq(record.character[region], table["swatches"][region][0], region)
	assert_eq(record.stats, ProfileRecord.STATS)


func test_round_trip() -> void:
	var record := ProfileRecord.create("Viper", table, [], 1000)
	record.character["base"] = "female"
	record.character["hair"] = "#ff0000"
	record.stats["kills"] = 14
	var errors: PackedStringArray = []
	var back := ProfileRecord.from_dict(JSON.parse_string(JSON.stringify(record.to_dict())), table, errors)
	assert_eq(errors, PackedStringArray())
	assert_eq(back.to_dict(), record.to_dict())
	assert_eq(back.summary()["name"], "Viper")
	assert_eq(back.summary()["kills"], 14)


func test_bad_fields_fall_back_to_defaults() -> void:
	var errors: PackedStringArray = []
	var back := ProfileRecord.from_dict({"id": "x", "name": "X", "character": {"base": "robot", "eyes": "not a colour"},
			"stats": {"kills": "lots"}}, table, errors)
	assert_eq(back.character["base"], table["bases"][0], "an unknown base")
	assert_eq(back.character["eyes"], table["swatches"]["eyes"][0], "a bad colour")
	assert_eq(back.stats["kills"], 0, "a bad number")
	ProfileRecord.from_dict({}, table, errors)
	assert_eq(errors.size(), 1, "no id or name is an error")

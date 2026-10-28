extends TestCase
## Phase 7.4: a ship leaves as a `.mssship` file or a share code and comes back identical, minus
## what belongs to the sender (gun items) or the receiver (whether it's for sale). Anything else
## that arrives is refused with a reason, never a crash.

var samples: Dictionary


func before_each() -> void:
	samples = Data.json_dir("blueprints")


func test_a_file_round_trips_every_sample_exactly() -> void:
	for id: String in samples:
		var bp := _sample(id)
		var errors: PackedStringArray = []
		var back := ShipCode.read(ShipCode.file_text(bp), errors)
		assert_eq(errors, PackedStringArray(), id)
		assert_eq(back.to_dict() if back != null else {}, bp.to_dict(), "%s rebuilds identically from its file" % id)


func test_a_share_code_round_trips_and_is_one_short_line() -> void:
	var bp := _sample("gunboat")
	var code := ShipCode.code(bp)
	assert_true(code.begins_with(ShipCode.CODE_PREFIX))
	assert_false("\n" in code or " " in code, "one line")
	assert_true(code.length() < ShipCode.file_text(bp).length() / 2, "much shorter than the file (%d)" % code.length())
	var errors: PackedStringArray = []
	assert_eq(ShipCode.read(code, errors).to_dict(), bp.to_dict())


func test_a_code_survives_a_chat_message_around_it() -> void:
	var bp := _sample("hexwing")
	var code := ShipCode.code(bp)
	var wrapped := "Look at my ship!\n  %s\n%s \r\n %s  " % [code.substr(0, 20), code.substr(20, 30), code.substr(50)]
	var errors: PackedStringArray = []
	var back := ShipCode.read(wrapped, errors)
	assert_eq(back.to_dict() if back != null else {}, bp.to_dict())


func test_gun_items_and_for_sale_stay_home() -> void:
	var bp := _sample("gunboat")
	bp.tags.append(Blueprint.PUBLISHED)
	for mount in bp.mounts:
		if Mounting.is_weapon(mount):
			mount["gun"] = "g12"
			mount["level"] = 300
	for text in [ShipCode.code(bp), ShipCode.file_text(bp)]:
		var errors: PackedStringArray = []
		var back := ShipCode.read(text, errors)
		assert_false(back.tags.has(Blueprint.PUBLISHED), "not for sale on arrival")
		for mount in back.mounts.filter(Mounting.is_weapon):
			assert_false(mount.has("gun"), "no gun item")
			assert_eq(int(mount["level"]), 300, "a Creative level is part of the design")
	assert_true(bp.tags.has(Blueprint.PUBLISHED), "the original isn't touched")


func test_junk_is_refused_with_a_reason() -> void:
	var cut := ShipCode.code(_sample("gunboat"))
	for junk in ["", "hello", "{\"format\": 1}", "[1, 2]", "MSS1:", "MSS1:!!!!", cut.substr(0, cut.length() / 2),
			JSON.stringify({"format": 99, "id": "x", "tiles": []})]:
		var errors: PackedStringArray = []
		assert_null(ShipCode.read(junk, errors), "refused: %s" % junk.left(30))
		assert_false(errors.is_empty(), "with a reason")


func test_a_code_that_unpacks_too_big_is_refused() -> void:
	var bomb := " ".repeat(ShipCode.MAX_BYTES * 2).to_utf8_buffer().compress(FileAccess.COMPRESSION_DEFLATE)
	var errors: PackedStringArray = []
	assert_null(ShipCode.read(ShipCode.CODE_PREFIX + Marshalls.raw_to_base64(bomb), errors))
	assert_false(errors.is_empty())


func test_file_names_are_safe() -> void:
	var bp := _sample("gunboat")
	bp.name = "  Viper Mk/II: *best*  "
	assert_eq(ShipCode.file_name(bp), "Viper_Mk_II_best.mssship")
	bp.name = "???"
	assert_eq(ShipCode.file_name(bp), "ship.mssship")


func _sample(id: String) -> Blueprint:
	var errors: PackedStringArray = []
	return Blueprint.from_dict(samples[id], errors)

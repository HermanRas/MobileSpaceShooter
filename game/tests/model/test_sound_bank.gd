extends TestCase
## Phase 14.1: the sound table. Every ID the game plays has a file that exists; a gatling's shots
## fold into a few voices; files take turns.


func _bank() -> SoundBank:
	return SoundBank.from_table({"sounds": {
		"fire.gun": {"files": ["a.wav", "b.wav", "c.wav"], "voices": 2, "gap_s": 0.05, "pitch": 0.1},
		"bad": {"files": []},
	}, "music": {"menu": {"file": "m.ogg"}, "broken": {}},
		"music_for_scene": {"res://hangar.tscn": "hangar"}, "default_music": "menu"})


func test_bad_rows_are_reported_and_left_out() -> void:
	var bank := _bank()
	assert_true(bank.has(&"fire.gun"))
	assert_false(bank.has(&"bad"))
	assert_false(bank.music.has(&"broken"))
	assert_eq(bank.errors.size(), 2)


func test_voices_and_the_gap_fold_rapid_fire() -> void:
	var bank := _bank()
	assert_true(bank.may_play(&"fire.gun", 0.0))
	bank.started(&"fire.gun", 0.0)
	assert_false(bank.may_play(&"fire.gun", 0.02), "inside the gap")
	assert_true(bank.may_play(&"fire.gun", 0.06))
	bank.started(&"fire.gun", 0.06)
	assert_false(bank.may_play(&"fire.gun", 1.0), "both voices busy")
	bank.finished(&"fire.gun")
	assert_true(bank.may_play(&"fire.gun", 1.0), "one came free")
	assert_false(bank.may_play(&"nothing", 1.0), "an unknown ID never plays")


func test_files_take_turns() -> void:
	var bank := _bank()
	var played: PackedStringArray = []
	for i in 4:
		played.append(bank.started(&"fire.gun", i))
		bank.finished(&"fire.gun")
	assert_eq(played, PackedStringArray(["a.wav", "b.wav", "c.wav", "a.wav"]))


func test_pitch_jitters_within_its_share() -> void:
	var bank := _bank()
	assert_almost_eq(bank.pitch_for(&"fire.gun", 0.0), 0.9)
	assert_almost_eq(bank.pitch_for(&"fire.gun", 1.0), 1.1)
	assert_almost_eq(bank.pitch_for(&"nothing", 1.0), 1.0)


func test_scenes_pick_their_music() -> void:
	var bank := _bank()
	assert_eq(bank.music_for("res://hangar.tscn"), &"hangar")
	assert_eq(bank.music_for("res://anything.tscn"), &"menu")


func test_the_shipped_table_is_clean_and_every_file_exists() -> void:
	var bank := SoundBank.from_table(Data.table(&"audio"))
	assert_eq(bank.errors, PackedStringArray())
	assert_true(bank.entries.size() >= 30, "%d sounds" % bank.entries.size())
	for id: StringName in bank.entries:
		for file in bank.entry(id).files:
			assert_true(ResourceLoader.exists(file), "%s: %s" % [id, file])
	for id: StringName in bank.music:
		assert_true(ResourceLoader.exists(bank.music[id]["file"]), "music %s" % id)


func test_every_sound_the_code_plays_is_in_the_table() -> void:
	var bank := SoundBank.from_table(Data.table(&"audio"))
	var called := {}
	var pattern := RegEx.create_from_string("Audio\\.(?:play_sfx|play_at|loop)\\(&\"([a-z0-9_.]+)\"")
	for path in _scripts("res://src"):
		for found in pattern.search_all(FileAccess.get_file_as_string(path)):
			called[found.get_string(1)] = path
	assert_true(called.size() >= 15, "%d IDs found in the code" % called.size())
	for id: String in called:
		assert_true(bank.has(StringName(id)), "%s (played in %s)" % [id, called[id]])


func _scripts(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(sub)))
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	return out

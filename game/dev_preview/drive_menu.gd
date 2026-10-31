extends Node
## Drives the main menu (PLAN.md 6.1): every button goes somewhere or is visibly disabled, and
## each screen comes back to the menu. Run with `tools/drive.sh res://dev_preview/drive_menu.tscn`.
##
## The Router swaps the whole current scene, so the drive loads the menu as a scene of its own
## and follows the real scene changes. Profiles live in a scratch folder with one pilot, so the
## real pilots are left alone (the WaveTime check resets its stock).

const ScriptErrorSpy := preload("res://dev_preview/script_error_spy.gd")

const SCRATCH := "user://drive_menu_profiles"

var _failures: PackedStringArray = []
var _spy := ScriptErrorSpy.new()


func _ready() -> void:
	OS.add_logger(_spy)
	var real_root := Profiles.root
	_wipe(SCRATCH)
	Profiles.root = SCRATCH
	Profiles.reload()
	Profiles.create("Pilot")
	var stock_path := Profiles.profile_dir(Profiles.selected_id).path_join(StockStore.FILE)
	var menu_scene := (load(Router.MAIN_MENU) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(menu_scene)
	await get_tree().process_frame
	get_tree().current_scene = menu_scene
	await _frames(3)

	var menu := get_tree().current_scene
	_check(_button(menu, "Story") != null and _button(menu, "Story").disabled, "Story is there, locked")
	var card := menu.find_child("ProfileCard", true, false) as ProfileCard
	_check(card != null and not _button(card, "EditProfile").disabled, "the profile card is there, with Pilots")
	if card != null:
		var portrait := card.find_child("Portrait", true, false) as Control
		_check(absf(portrait.size.x - card.size.x * 0.3) < 2.0 and absf(portrait.size.x - portrait.size.y) < 2.0,
				"its portrait is a square, 30%% of the card (%s of %s)" % [portrait.size, card.size])
		var shown := _all_text(card)
		_check("Pilot" in shown and "Best" in shown and "K 0 / D 0" in shown and "S0% / J0" in shown,
				"with the name, best WaveTime, kills / deaths and Story / jobs")
		var modes := (_button(menu, "Creative").get_global_rect() as Rect2).merge(_button(menu, "Story").get_global_rect())
		_check(absf(card.get_global_rect().size.x - modes.size.x) < 2.0 and card.get_global_rect().end.y <= modes.position.y,
				"as wide as the mode tiles, above them")
	_check(_find_text(menu, "Shot stress test") == null and _find_text(menu, "Enemy gallery") == null
			and _find_text(menu, "Reset WaveTime stock") == null, "no debug buttons on the menu")
	var tutorials_button := _button(menu, "Tutorials")
	var scoreboard_button := _button(menu, "Scoreboard")
	_check(tutorials_button != null and scoreboard_button != null
			and absf(tutorials_button.size.x - _button(menu, "Settings").size.x) < 2.0
			and tutorials_button.get_global_rect().end.y <= _button(menu, "Settings").get_global_rect().position.y,
			"Tutorials and Scoreboard sit above Settings and Credits")
	_save_shot("drive_menu.png")
	menu.call("on_back")
	await _frames(2)
	var quit := menu.find_child("ConfirmQuit", true, false) as Control
	_check(quit != null and quit.visible and _is(get_tree().current_scene, Router.MAIN_MENU), "back on the menu asks before quitting")
	menu.call("on_back")
	await _frames(2)
	_check(quit != null and not quit.visible, "and back again stays")

	await _press("Creative")
	var hangar := get_tree().current_scene
	_check(_is(hangar, "res://scenes/hangar/hangar.tscn") and not hangar.call("stocked") and Profiles.active_id == "",
			"Creative opens the free hangar")
	hangar.call("on_back")
	await _frames(3)
	_check(_is(get_tree().current_scene, Router.MAIN_MENU), "and back comes home")

	await _press("WaveTime")
	hangar = get_tree().current_scene
	_check(_is(hangar, "res://scenes/hangar/hangar.tscn") and hangar.call("stocked") and Profiles.active_id != "",
			"WaveTime opens the hangar building from a profile's stock (%s)" % Profiles.active_id)
	var reset := _button(hangar, "ResetStock")
	_check(reset != null, "a debug WaveTime hangar has Reset")
	if reset != null:
		reset.pressed.emit()
		await _frames(2)
		_check(_is(get_tree().current_scene, "res://scenes/hangar/hangar.tscn") and reset.text == "Tap again",
				"one tap only arms it")
		reset.pressed.emit()
		await _frames(4)
		_check(_is(get_tree().current_scene, Router.MAIN_MENU) and not FileAccess.file_exists(stock_path),
				"a second tap wipes the stock and goes to the menu")
	else:
		hangar.call("on_back")
		await _frames(3)
	Profiles.active_id = ""

	await _press("Tutorials")
	var tutorials := get_tree().current_scene
	_check(_is(tutorials, "res://scenes/menu/tutorials.tscn") and _button(tutorials, "WaveTimeTutorial").disabled
			and _button(tutorials, "StoryTutorial").disabled, "Tutorials: WaveTime and Story are locked for now")
	await _press("EnemyGallery")
	_check(_is(get_tree().current_scene, "res://scenes/debug/enemy_gallery.tscn"), "the enemy gallery opens from there")
	get_tree().current_scene.call("on_back")
	await _frames(3)
	_check(_is(get_tree().current_scene, "res://scenes/menu/tutorials.tscn"), "and back returns to Tutorials")
	get_tree().current_scene.call("on_back")
	await _frames(3)

	await _press("Settings")
	var settings := get_tree().current_scene
	_check(_is(settings, "res://scenes/menu/settings.tscn") and settings.find_child("Controls", true, false) != null,
			"Settings shows the controls")
	_save_shot("drive_menu_settings.png")
	# 6.4: a setting applies at once and is saved (the player's own values are put back).
	var music := settings.find_child("music_volume", true, false) as HSlider
	var was_music: float = Settings.get_value(&"music_volume")
	var was_shake: bool = Settings.get_value(&"screen_shake")
	_check(music != null, "Settings has a music volume")
	if music != null:
		music.value = 0.3
		var bus := AudioServer.get_bus_index(Audio.MUSIC)
		_check(absf(AudioServer.get_bus_volume_db(bus) - linear_to_db(0.3)) < 0.1, "moving it sets the Music bus at once")
		await get_tree().create_timer(0.6).timeout
		_check(absf(float(Save.read_json(Settings.PATH).get("music_volume", -1.0)) - 0.3) < 0.01, "and it's saved")
		music.value = 0.0
		_check(AudioServer.is_bus_mute(bus), "0 mutes it")
	var shake := _find_text(settings, "Screen shake")
	if shake != null:
		shake.button_pressed = not was_shake
		_check(Save.read_json(Settings.PATH).get("screen_shake") == (not was_shake), "a toggle is saved at once")
		shake.button_pressed = was_shake
	if music != null:
		music.value = was_music
		await get_tree().create_timer(0.6).timeout
	_check(_find_text(settings, "Done") == null, "with no Done button (back closes it)")
	_check(Audio.music_id() == &"menu", "the menus play the menu music")
	# 14.1: the Sound test plays every sound in audio.json, a button each.
	var clicks := int(Audio.played.get(&"ui.click", 0))
	await _press("Soundtest")
	_check(int(Audio.played.get(&"ui.click", 0)) > clicks, "a button clicks")
	var test := get_tree().current_scene
	_check(_is(test, "res://scenes/menu/sound_test.tscn"), "Settings opens the Sound test")
	var buttons := test.find_children("*", "Button", true, false).size()
	_check(buttons >= Audio.bank.entries.size() + Audio.bank.music.size(), "a button for every sound and track (%d)" % buttons)
	var booms := int(Audio.played.get(&"boom.big", 0))
	(test.find_child("boom_big", true, false) as Button).pressed.emit()
	_check(int(Audio.played.get(&"boom.big", 0)) == booms + 1, "and one plays its sound")
	await _frames(2)
	_save_shot("drive_menu_sound_test.png")
	test.call("on_back")
	await _frames(3)
	settings = get_tree().current_scene
	_check(_is(settings, "res://scenes/menu/settings.tscn"), "back to Settings")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await _frames(3)
	_check(_is(get_tree().current_scene, Router.MAIN_MENU), "Esc comes home")

	await _press("Scoreboard")
	var board := get_tree().current_scene
	_check(_is(board, "res://scenes/menu/scoreboard.tscn") and "Scoreboard" in _all_text(board), "Scoreboard opens")
	board.call("on_back")
	await _frames(3)
	_check(_is(get_tree().current_scene, Router.MAIN_MENU), "and back comes home")

	await _press("Credits")
	var credits := get_tree().current_scene
	_check(_is(credits, "res://scenes/menu/credits.tscn"), "Credits opens")
	var text := _all_text(credits)
	_check("Herman Ras" in text and "Permission is hereby granted" in text, "with who made it and Godot's licence")
	var notices := _button(credits, "Notices")
	if notices != null:
		notices.pressed.emit()
		await _frames(2)
	_check("FreeType" in _all_text(credits), "and the engine's third-party notices on request")
	_check(_find_text(credits, "Back") == null, "with no Back button")
	credits.call("on_back")
	await _frames(3)
	_check(_is(get_tree().current_scene, Router.MAIN_MENU), "back comes home")

	Profiles.root = real_root
	Profiles.reload()
	_wipe(SCRATCH)
	OS.remove_logger(_spy)
	for error in _spy.seen:
		_failures.append("script error: " + error)
	if _failures.is_empty():
		print("drive_menu: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			printerr("drive_menu: FAIL  " + failure)
		get_tree().quit(1)


func _press(button_name: String) -> void:
	var button := _button(get_tree().current_scene, button_name)
	_check(button != null and not button.disabled, "%s is pressable" % button_name)
	if button != null:
		button.pressed.emit()
	await _frames(4)


func _button(root: Node, button_name: String) -> Button:
	return root.find_child(button_name, true, false) as Button


func _find_text(root: Node, text: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node
	return null


func _all_text(root: Node) -> String:
	var parts: PackedStringArray = []
	for node in root.find_children("*", "Label", true, false):
		if (node as Label).is_visible_in_tree():
			parts.append((node as Label).text)
	return "\n".join(parts)


func _is(scene: Node, path: String) -> bool:
	return scene != null and scene.scene_file_path == path


func _wipe(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_wipe(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _save_shot(file_name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://dev_preview/out/" + file_name))


func _check(ok: bool, what: String) -> void:
	print("drive_menu: %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures.append(what)

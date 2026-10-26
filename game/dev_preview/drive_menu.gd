extends Node
## Drives the main menu (PLAN.md 6.1): every button goes somewhere or is visibly disabled, and
## each screen comes back to the menu. Run with `tools/drive.sh res://dev_preview/drive_menu.tscn`.
##
## The Router swaps the whole current scene, so the drive loads the menu as a scene of its own
## and follows the real scene changes. The WaveTime check resets the dev profile's stock, so its
## save is backed up first and put back after.

const ScriptErrorSpy := preload("res://dev_preview/script_error_spy.gd")

var _failures: PackedStringArray = []
var _spy := ScriptErrorSpy.new()


func _ready() -> void:
	OS.add_logger(_spy)
	var stock_path := Profiles.profile_dir("dev").path_join(StockStore.FILE)
	var saved_stock := FileAccess.get_file_as_bytes(stock_path) if FileAccess.file_exists(stock_path) else PackedByteArray()
	var menu_scene := (load(Router.MAIN_MENU) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(menu_scene)
	await get_tree().process_frame
	get_tree().current_scene = menu_scene
	await _frames(3)

	var menu := get_tree().current_scene
	_check(_button(menu, "Story") != null and _button(menu, "Story").disabled, "Story is there, locked")
	var card := menu.find_child("ProfileCard", true, false) as ProfileCard
	_check(card != null and _button(card, "EditProfile").disabled, "the profile card is there; editing waits for 6.2")
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
	_check(tutorials_button != null and absf(tutorials_button.size.x - (_button(menu, "Settings").size.x * 2 + 12)) < 2.0
			and tutorials_button.get_global_rect().end.y <= _button(menu, "Settings").get_global_rect().position.y,
			"Tutorials is as wide as Settings and Credits together, above them")
	_save_shot("drive_menu.png")

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
	if not saved_stock.is_empty():
		var restore := FileAccess.open(stock_path, FileAccess.WRITE)
		restore.store_buffer(saved_stock)
		restore.close()

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
	var done := _find_text(settings, "Done")
	_check(done != null, "with a Done button")
	if done != null:
		done.pressed.emit()
		await _frames(3)
	_check(_is(get_tree().current_scene, Router.MAIN_MENU), "Done comes home")

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
	credits.call("on_back")
	await _frames(3)
	_check(_is(get_tree().current_scene, Router.MAIN_MENU), "back comes home")

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

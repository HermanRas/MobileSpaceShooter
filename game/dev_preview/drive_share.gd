extends "res://dev_preview/drive_shop.gd"
## Drives 7.4 in the Creative library's Share menu: a ship saved to a `.mssship` file and loaded
## back, copied as a share code and pasted back, both rebuilding identically; a clipboard of junk
## refused; Save as enemy; and Back closing the menu before the library. The file picker can't
## be tapped through here, so the drive hands ShipShare the path a player would have picked.
## Run with `tools/drive.sh res://dev_preview/drive_share.tscn`. Exit code 0 = every step passed.

const OUT := "user://drive_share"
const SHARED_NAME := "Drive share gunboat"

var _made: PackedStringArray = []


func _ready() -> void:
	OS.add_logger(_spy)
	_wipe_dir(OUT)
	DirAccess.make_dir_recursive_absolute(OUT)
	Profiles.active_id = ""
	await _open_hangar()
	_hangar._share.enemy_dir = OUT
	_hangar.preview_setup({"ship": "gunboat"})
	await _hangar.save_as(SHARED_NAME)
	_ship_id = _hangar.editor.blueprint.id
	_made.append(_ship_id)
	await _tap_button(_find(_hangar._ui, "Ships", VBoxContainer))

	await _step_a_file_goes_out_and_comes_back()
	await _step_a_share_code_goes_out_and_comes_back()
	await _step_junk_on_the_clipboard_is_refused()
	await _step_save_as_enemy()
	await _step_back_closes_the_menu_first()

	for id in _made:
		_hangar._library.delete(id)
	_hangar.queue_free()
	_wipe_dir(OUT)
	OS.remove_logger(_spy)
	for error in _spy.seen:
		_failures.append("script error: " + error)
	if _failures.is_empty():
		print("drive_share: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			printerr("drive_share: FAIL  " + failure)
		get_tree().quit(1)


func _step_a_file_goes_out_and_comes_back() -> void:
	await _share_action("save_file")
	var dialog: FileDialog = _hangar._share._dialog
	_check(dialog.visible and dialog.current_file == "Drive_share_gunboat.mssship",
			"Save to file opens the picker with the ship's file name (%s)" % dialog.current_file)
	_save_shot("drive_share_picker.png")
	dialog.hide()
	var path := OUT.path_join(dialog.current_file)
	_hangar._share._on_file_chosen(path)
	_check(FileAccess.file_exists(path) and "Saved" in _note(), "the file is written: %s" % _note())
	var before: int = _hangar._library.list().size()
	await _share_action("open_file")
	dialog.hide()
	_hangar._share._on_file_chosen(path)
	await _frames(6)
	var arrived := _newest_other_than(_ship_id)
	_check(_hangar._library.list().size() == before + 1 and arrived != "", "loading it adds a ship (%s)" % _note())
	_check(_same_design(arrived, _ship_id), "that rebuilds identically")
	_check(FileAccess.file_exists(_hangar._library.thumbnail_path(arrived)), "with a thumbnail")


func _step_a_share_code_goes_out_and_comes_back() -> void:
	await _share_action("copy_code")
	var code := DisplayServer.clipboard_get()
	_check(code.begins_with(ShipCode.CODE_PREFIX) and "copied" in _note(), "Copy share code fills the clipboard (%d chars)" % code.length())
	DisplayServer.clipboard_set("Look at my ship!\n" + code.substr(0, 40) + "\n" + code.substr(40) + "\n")
	await _share_action("paste_code")
	await _frames(6)
	var arrived := _newest_other_than(_ship_id)
	_check(arrived != "" and _same_design(arrived, _ship_id) and "Added" in _note(),
			"Paste share code adds the same ship: %s" % _note())


func _step_junk_on_the_clipboard_is_refused() -> void:
	var before: int = _hangar._library.list().size()
	DisplayServer.clipboard_set("hello there")
	await _share_action("paste_code")
	_check(_hangar._library.list().size() == before and _note().begins_with("Clipboard:"), "junk is refused: %s" % _note())


func _step_save_as_enemy() -> void:
	await _share_action("save_enemy")
	var path := OUT.path_join("drive_share_gunboat.json")
	var design := Save.read_json(path) if FileAccess.file_exists(path) else {}
	_check((design.get("tags", []) as Array).has("enemy") and design.get("id") == "drive_share_gunboat",
			"Save as enemy writes an enemy design: %s" % _note())


func _step_back_closes_the_menu_first() -> void:
	await _tap_button(_hangar._library_panel.find_child("Share", true, false))
	_check(_hangar._library_panel._share_menu.visible, "Share opens its menu")
	_save_shot("drive_share_menu.png")
	_hangar.on_back()
	_check(not _hangar._library_panel._share_menu.visible and _hangar._library_panel.visible, "Back closes the menu, not the library")
	_hangar.on_back()
	_check(not _hangar._library_panel.visible, "and Back again closes the library")


## Selects the shared ship's card, opens Share and taps `action`.
func _share_action(action: String) -> void:
	var card := _library_card(_ship_id)
	if card != null and not card.button_pressed:
		await _tap_button(card)
	await _tap_button(_hangar._library_panel.find_child("Share", true, false))
	await _tap_button(_hangar._library_panel._share_menu.find_child(action, true, false))


func _note() -> String:
	return _hangar._library_panel._note.text


## The newest library ship that isn't `id` or one counted already (and counts it).
func _newest_other_than(id: String) -> String:
	for entry in _hangar._library.list():
		if entry["id"] != id and not _made.has(entry["id"]) and entry["name"] == SHARED_NAME:
			_made.append(entry["id"])
			return entry["id"]
	return ""


func _same_design(a: String, b: String) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	var left := ShipCode.shared(_hangar._library.load_ship(a))
	var right := ShipCode.shared(_hangar._library.load_ship(b))
	left.erase("id")
	right.erase("id")
	return JSON.stringify(left) == JSON.stringify(right)


func _check(ok: bool, what: String) -> void:
	print("drive_share: %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures.append(what)

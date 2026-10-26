extends Node
## Drives the pilots (PLAN.md 6.2, the "done when"): three pilots made through the character
## screen, each with its own stock, switching between them, and deleting one after the
## confirmation. Run with `tools/drive.sh res://dev_preview/drive_profiles.tscn`.
##
## Profiles live in a scratch folder for the drive, so the real pilots are left alone.

const ScriptErrorSpy := preload("res://dev_preview/script_error_spy.gd")
const ROOT := "user://drive_profiles"
const HANGAR := "res://scenes/hangar/hangar.tscn"
const PILOTS := "res://scenes/menu/profiles.tscn"
const CHARACTER := "res://scenes/menu/character.tscn"

var _failures: PackedStringArray = []
var _spy := ScriptErrorSpy.new()
var _real_root := ""


func _ready() -> void:
	OS.add_logger(_spy)
	_real_root = Profiles.root
	_wipe(ROOT)
	Profiles.root = ROOT
	Profiles.reload()
	var menu_scene := (load(Router.MAIN_MENU) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(menu_scene)
	await get_tree().process_frame
	get_tree().current_scene = menu_scene
	await _frames(3)

	_check("No pilot yet" in _text(_scene()), "a fresh device has no pilot yet")
	await _press(_scene(), "WaveTime")
	_check(_is(CHARACTER), "WaveTime with no pilot opens the character screen first")
	await _make_pilot("Viper", "female", 2)
	_check(_is(Router.MAIN_MENU) and "Viper" in _text(_scene()), "Save returns to the menu, with Viper on the card")
	var viper := Profiles.selected()
	_check(viper != null and viper.character["base"] == "female" and viper.character["hair"] == Data.table(&"characters")["swatches"]["hair"][2],
			"her base and hair colour are kept")

	await _press(_scene(), "EditProfile")
	_check(_is(PILOTS) and _scene().find_child("Pilot_viper", true, false) != null, "Pilots lists her")
	for pilot_name in ["Ghost", "Rook"]:
		await _press(_scene(), "NewPilot")
		await _make_pilot(pilot_name, "male", 4)
	_check(_is(PILOTS) and Profiles.list().size() == 3, "three pilots (%d)" % Profiles.list().size())
	_save_shot("drive_profiles_pilots.png")

	# Separate stock: Viper buys alloy; Ghost doesn't have it; Viper still does.
	await _select("viper")
	var start := await _alloy_in_wavetime(10)
	var ghost_alloy := 0
	await _select("ghost")
	ghost_alloy = await _alloy_in_wavetime(0)
	await _select("viper")
	var viper_alloy := await _alloy_in_wavetime(0)
	_check(viper_alloy == start + 10 and ghost_alloy == start, "each pilot has their own stock (Viper %d, Ghost %d, start %d)"
			% [viper_alloy, ghost_alloy, start])
	_check(FileAccess.file_exists(ROOT.path_join("viper/hangar.json")) and FileAccess.file_exists(ROOT.path_join("ghost/hangar.json")),
			"in their own folders")

	# Deleting asks first.
	await _open(PILOTS)
	var card := _scene().find_child("Pilot_rook", true, false)
	await _press(card, "Delete")
	var confirm := _scene().find_child("ConfirmDelete", true, false) as Control
	_check(confirm.visible and Profiles.record("rook") != null, "Delete asks first")
	await _press(_scene(), "Cancel")
	_check(not confirm.visible and Profiles.record("rook") != null, "Cancel keeps Rook")
	await _press(_scene().find_child("Pilot_rook", true, false), "Delete")
	await _press(_scene(), "DeleteConfirm")
	_check(Profiles.record("rook") == null and not DirAccess.dir_exists_absolute(ROOT.path_join("rook"))
			and Profiles.list().size() == 2, "and Delete removes Rook and his folder")

	# The selection outlives a restart.
	Profiles.select("ghost")
	Profiles.reload()
	_check(Profiles.selected_id == "ghost", "the selected pilot is remembered")

	Profiles.root = _real_root
	Profiles.reload()
	Profiles.active_id = ""
	_wipe(ROOT)
	OS.remove_logger(_spy)
	for error in _spy.seen:
		_failures.append("script error: " + error)
	if _failures.is_empty():
		print("drive_profiles: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			printerr("drive_profiles: FAIL  " + failure)
		get_tree().quit(1)


## On the character screen: type `pilot_name`, pick `base` and the `swatch`th of each region,
## check the preview follows and cycles its moods, and Save.
func _make_pilot(pilot_name: String, base: String, swatch: int) -> void:
	var screen := _scene()
	var save := _find_text(screen, "Save")
	_check(save != null and save.disabled, "%s: Save waits for a name" % pilot_name)
	var line := screen.find_child("PilotName", true, false) as LineEdit
	line.text = pilot_name
	line.text_changed.emit(pilot_name)
	(_find_text(screen, base.capitalize())).pressed.emit()
	for region in ProfileRecord.REGIONS:
		var button := screen.find_child("%s_%d" % [region, swatch], true, false) as Button
		if button != null:
			button.pressed.emit()
	var portrait := screen.find_child("Portrait", true, false) as PortraitView
	_check(portrait.character["base"] == base and portrait.character["outfit"] == Data.table(&"characters")["swatches"]["outfit"][swatch],
			"%s: the portrait shows the choices" % pilot_name)
	var first := portrait.mood
	await get_tree().create_timer(portrait.cycle_s + 0.3).timeout
	_check(portrait.mood != first, "%s: the preview cycles its moods (%s -> %s)" % [pilot_name, first, portrait.mood])
	if pilot_name == "Viper":
		_save_shot("drive_profiles_character.png")
	_check(not save.disabled, "%s: a name lets it save" % pilot_name)
	save.pressed.emit()
	await _frames(4)


func _select(id: String) -> void:
	await _open(PILOTS)
	var card := _scene().find_child("Pilot_" + id, true, false)
	var select := card.find_child("Select", true, false) as Button
	if not select.disabled:
		select.pressed.emit()
		await _frames(2)
	_check(Profiles.selected_id == id, "%s selected" % id)
	await _open(Router.MAIN_MENU)


## WaveTime with the selected pilot: their alloy, after buying `buy` more. Back to the menu.
func _alloy_in_wavetime(buy: int) -> int:
	await _press(_scene(), "WaveTime")
	var hangar := _scene()
	_check(_is(HANGAR) and hangar.call("stocked") and Profiles.active_id == Profiles.selected_id,
			"WaveTime builds from %s's stock" % Profiles.selected_id)
	var before: int = hangar.editor.stock.amount(&"alloy")
	if buy > 0:
		hangar.editor.trade(&"alloy", buy)
		hangar.call("_on_changed")
	var after: int = hangar.editor.stock.amount(&"alloy")
	hangar.call("on_back")
	await _frames(3)
	return before if buy > 0 else after


func _open(path: String) -> void:
	Router.goto(path)
	await _frames(3)


func _press(root: Node, button_name: String) -> void:
	var button := root.find_child(button_name, true, false) as Button if root != null else null
	_check(button != null and not button.disabled, "%s is pressable" % button_name)
	if button != null:
		button.pressed.emit()
	await _frames(4)


func _scene() -> Node:
	return get_tree().current_scene


func _is(path: String) -> bool:
	return _scene() != null and _scene().scene_file_path == path


func _find_text(root: Node, text: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node
	return null


func _text(root: Node) -> String:
	var parts: PackedStringArray = []
	for node in root.find_children("*", "Label", true, false):
		parts.append((node as Label).text)
	return "\n".join(parts)


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
	print("drive_profiles: %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures.append(what)

class_name ShipShare
extends Node
## Ships in and out of the device (PLAN.md 7.4): a `.mssship` file through the system's file picker
## (FileDialog's native dialog: Android's own picker on the phone, Godot's dialog where there's no
## native one), or a share code through the clipboard (ShipCode). And, run from the project rather
## than an exported game, a ship saved straight into `data/enemies/`: that's how enemies get authored.
##
## It only moves text: what arrives goes out through `loaded`, and the hangar files it in the library.

signal loaded(bp: Blueprint)
## A line for the player: what happened, or what went wrong.
signal done(message: String)

const ENEMY_DIR := "res://data/enemies"

## Where Save as enemy writes; a drive points it somewhere harmless.
var enemy_dir := ENEMY_DIR
var _dialog := FileDialog.new()
## The ship the save dialog is open for, or null while it's open to load.
var _saving: Blueprint


func _ready() -> void:
	_dialog.use_native_dialog = true
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.filters = PackedStringArray(["*.%s ; MSS ship" % ShipCode.FILE_EXTENSION])
	_dialog.size = Vector2i(900, 560)
	_dialog.file_selected.connect(_on_file_chosen)
	add_child(_dialog)


func save_file(bp: Blueprint) -> void:
	_saving = bp
	_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_dialog.title = "Save ship"
	_dialog.current_file = ShipCode.file_name(bp)
	_dialog.popup_centered()


func open_file() -> void:
	_saving = null
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.title = "Load ship"
	_dialog.popup_centered()


## Where the picker landed (drives call it straight, as there's no one to pick).
func _on_file_chosen(path: String) -> void:
	if _saving != null:
		write_file(_saving, path)
	else:
		read_file(path)


func write_file(bp: Blueprint, path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		done.emit("Couldn't save %s (%s)" % [path.get_file(), error_string(FileAccess.get_open_error())])
		return FAILED
	file.store_string(ShipCode.file_text(bp))
	file.close()
	done.emit("Saved %s" % path.get_file())
	return OK


func read_file(path: String) -> Blueprint:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		done.emit("Couldn't open %s (%s)" % [path.get_file(), error_string(FileAccess.get_open_error())])
		return null
	if file.get_length() > ShipCode.MAX_BYTES:
		done.emit("%s is too big to be a ship" % path.get_file())
		return null
	return _take(file.get_as_text(), path.get_file() + ": ")


func copy_code(bp: Blueprint) -> void:
	DisplayServer.clipboard_set(ShipCode.code(bp))
	done.emit("Share code copied: paste it into a chat")


func paste_code() -> Blueprint:
	return _take(DisplayServer.clipboard_get(), "Clipboard: ")


## Whether this run can write `data/` (a project run, not an exported game).
static func can_save_enemies() -> bool:
	return not OS.has_feature("template")


## Saves `bp` as an enemy design, named after the ship (`data/enemies/<name>.json`, tagged
## "enemy"). The roster (`enemies.json`) is still edited by hand.
func save_enemy(bp: Blueprint) -> Error:
	var design := ShipCode.shared(bp)
	design["id"] = ShipCode.file_name(bp).get_basename().to_lower()
	design["author"] = "mss"
	if not (design["tags"] as Array).has("enemy"):
		design["tags"].append("enemy")
	var path := enemy_dir.path_join(design["id"] + ".json")
	var replacing := FileAccess.file_exists(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		done.emit("Couldn't write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return FAILED
	file.store_string(JSON.stringify(design, "\t"))
	file.close()
	done.emit("%s %s: add it to enemies.json to put it on the roster" % ["Replaced" if replacing else "Saved", path])
	return OK


func _take(text: String, where: String) -> Blueprint:
	var errors: PackedStringArray = []
	var bp := ShipCode.read(text, errors)
	if bp == null:
		done.emit(where + (errors[0] if not errors.is_empty() else "that isn't a ship"))
		return null
	loaded.emit(bp)
	return bp

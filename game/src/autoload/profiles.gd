extends Node
## The pilots on this device (PLAN.md 6.2, D2: hot-seat profiles, taking turns).
##
## Each owns `user://profiles/<id>/`: its `profile.json` (ProfileRecord) and its stock
## (StockStore's `hangar.json`). The device-wide blueprint library lives outside that, in
## `user://library/` (D6). `index.json` beside the profiles remembers who was last selected.
##
## `selected_id` is the pilot chosen on the main menu; `active_id` is the profile whose stock the
## hangar builds from, which is the selected pilot in WaveTime and "" in Creative.

signal changed

const SUMMARY_FILE := "profile.json"
const INDEX_FILE := "index.json"
## A save from before profiles (4.8's WaveTime stock) becomes a pilot of this name.
const LEGACY_ID := "dev"
const LEGACY_NAME := "Pilot"
const SUMMARY_DEFAULTS := {
	"name": "",
	"best_wave_s": 0,
	"kills": 0,
	"deaths": 0,
	"story_pct": 0,
	"jobs": 0,
}

## Where the profiles live. Drives point it at a scratch folder and call reload().
var root := "user://profiles"
var active_id: String = ""
var selected_id: String = ""
## The pilot the character screen edits ("" for a new one), and where it returns afterwards
## ("" for the pilots screen).
var editing_id: String = ""
var edit_return: String = ""

var _records: Dictionary = {}


func _ready() -> void:
	reload()


func profile_dir(id: String) -> String:
	return root.path_join(id)


## Reads every pilot under `root`, adopting a pre-profiles save as LEGACY_NAME.
func reload() -> void:
	_records.clear()
	_adopt_legacy()
	var ids := DirAccess.get_directories_at(root) if DirAccess.dir_exists_absolute(root) else PackedStringArray()
	for id in ids:
		var path := profile_dir(id).path_join(SUMMARY_FILE)
		var data := Save.read_versioned(path, ProfileRecord.FORMAT)
		if data.is_empty():
			continue
		var errors: PackedStringArray = []
		var record := ProfileRecord.from_dict(data, Data.table(&"characters"), errors)
		if errors.is_empty():
			_records[record.id] = record
	var index := Save.read_json(root.path_join(INDEX_FILE))
	selected_id = str(index.get("selected", ""))
	if not _records.has(selected_id):
		selected_id = list()[0].id if not _records.is_empty() else ""
	changed.emit()


## Every pilot, oldest first.
func list() -> Array[ProfileRecord]:
	var out: Array[ProfileRecord] = []
	for id: String in _records:
		out.append(_records[id])
	out.sort_custom(func(a: ProfileRecord, b: ProfileRecord) -> bool: return [a.created, a.id] < [b.created, b.id])
	return out


func record(id: String) -> ProfileRecord:
	return _records.get(id)


func selected() -> ProfileRecord:
	return _records.get(selected_id)


## A new pilot called `raw_name` (cleaned), with the default character; saved and selected.
func create(raw_name: String) -> ProfileRecord:
	var made := ProfileRecord.create(raw_name, Data.table(&"characters"), _records.keys(), int(Time.get_unix_time_from_system()))
	_records[made.id] = made
	save(made)
	select(made.id)
	return made


func save(pilot: ProfileRecord) -> Error:
	_records[pilot.id] = pilot
	var result := Save.write_json(profile_dir(pilot.id).path_join(SUMMARY_FILE), pilot.to_dict())
	changed.emit()
	return result


func select(id: String) -> void:
	if not _records.has(id):
		return
	selected_id = id
	Save.write_json(root.path_join(INDEX_FILE), {"format": 1, "selected": id})
	changed.emit()


## Deletes pilot `id` and everything in its folder (its stock too). Another pilot is selected.
func delete(id: String) -> void:
	if not _records.has(id):
		return
	_records.erase(id)
	_remove_tree(profile_dir(id))
	if active_id == id:
		active_id = ""
	if selected_id == id:
		selected_id = list()[0].id if not _records.is_empty() else ""
		Save.write_json(root.path_join(INDEX_FILE), {"format": 1, "selected": selected_id})
	changed.emit()


## What the profile card shows for pilot `id`: SUMMARY_DEFAULTS if there's no such pilot.
func summary(id: String) -> Dictionary:
	var pilot := record(id)
	return pilot.summary() if pilot != null else SUMMARY_DEFAULTS.duplicate()


## The WaveTime stock saved before there were profiles (4.8's dev profile) gets a profile.json,
## so its ship, parts and wallet carry on as a pilot.
func _adopt_legacy() -> void:
	var dir := profile_dir(LEGACY_ID)
	if FileAccess.file_exists(dir.path_join(StockStore.FILE)) and not FileAccess.file_exists(dir.path_join(SUMMARY_FILE)):
		var pilot := ProfileRecord.create(LEGACY_NAME, Data.table(&"characters"), [], 0)
		pilot.id = LEGACY_ID
		Save.write_json(dir.path_join(SUMMARY_FILE), pilot.to_dict())


static func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)

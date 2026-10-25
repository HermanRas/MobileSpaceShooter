class_name BlueprintLibrary
extends RefCounted
## The device-wide ship library (D6, Phase 2.6): `user://library/<id>.json`, with a thumbnail
## beside each as `<id>.png`. Writes go through `Save`, so they're atomic with a `.bak`.

const DIR := "user://library"

var dir: String


func _init(library_dir: String = DIR) -> void:
	dir = library_dir


## Every saved ship, newest first, as {"id", "name", "tiles", "modified"}.
func list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for file_name in DirAccess.get_files_at(dir):
		if file_name.get_extension() != "json":
			continue
		var id := file_name.get_basename()
		var data := Save.read_json(json_path(id))
		if data.is_empty():
			continue
		out.append({
			"id": id,
			"name": str(data.get("name", id)),
			"tiles": (data.get("tiles", []) as Array).size(),
			"modified": FileAccess.get_modified_time(json_path(id)),
		})
	# File times have 1 s resolution, so ships saved together tie; break ties by name.
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["modified"] > b["modified"] if a["modified"] != b["modified"] else a["name"] < b["name"])
	return out


func load_ship(id: String) -> Blueprint:
	var errors: PackedStringArray = []
	var bp := Blueprint.from_dict(Save.read_json(json_path(id)), errors)
	if bp == null:
		push_error("BlueprintLibrary: %s: %s" % [id, ", ".join(errors)])
	return bp


func save_ship(bp: Blueprint) -> Error:
	if not is_valid_id(bp.id):
		return ERR_INVALID_PARAMETER
	return Save.write_json(json_path(bp.id), bp.to_dict())


## Saves a copy under a new id and name; returns the copy.
func save_as(bp: Blueprint, new_name: String) -> Blueprint:
	var errors: PackedStringArray = []
	var copy := Blueprint.from_dict(bp.to_dict(), errors)
	copy.id = new_id()
	copy.name = new_name
	save_ship(copy)
	return copy


func rename(id: String, new_name: String) -> Error:
	var bp := load_ship(id)
	if bp == null:
		return ERR_FILE_NOT_FOUND
	bp.name = new_name
	return save_ship(bp)


func delete(id: String) -> void:
	for path in [json_path(id), json_path(id) + Save.BAK_SUFFIX, json_path(id) + Save.TMP_SUFFIX, thumbnail_path(id)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func has(id: String) -> bool:
	return FileAccess.file_exists(json_path(id))


func json_path(id: String) -> String:
	return dir.path_join(id + ".json")


func thumbnail_path(id: String) -> String:
	return dir.path_join(id + ".png")


static func new_id() -> String:
	return "ship_%d_%04d" % [Time.get_unix_time_from_system(), randi() % 10000]


## Ids become file names, so only [a-z0-9_-] is allowed.
static func is_valid_id(id: String) -> bool:
	var regex := RegEx.create_from_string("^[a-z0-9_-]{1,64}$")
	return regex.search(id) != null

extends Node
## Versioned JSON persistence with atomic writes.
##
## A write goes to `<path>.tmp` and is then renamed over `<path>`, and the previous good file is
## kept as `<path>.bak`. A read falls back to the `.bak` when the main file is missing or
## corrupt, so killing the app mid-save never loses the last good save.

const TMP_SUFFIX := ".tmp"
const BAK_SUFFIX := ".bak"


func write_json(path: String, data: Dictionary) -> Error:
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var made := DirAccess.make_dir_recursive_absolute(dir)
		if made != OK:
			return made
	var tmp := path + TMP_SUFFIX
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if FileAccess.file_exists(path):
		var backed_up := DirAccess.rename_absolute(path, path + BAK_SUFFIX)
		if backed_up != OK:
			return backed_up
	return DirAccess.rename_absolute(tmp, path)


## Returns the saved Dictionary, the `.bak` copy if the main file is unreadable, or {} if neither.
func read_json(path: String) -> Dictionary:
	for candidate in [path, path + BAK_SUFFIX]:
		var parsed := _parse(candidate)
		if not parsed.is_empty():
			if candidate != path:
				push_warning("Save: %s unreadable, using backup" % path)
			return parsed
	return {}


func _parse(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return json.data if typeof(json.data) == TYPE_DICTIONARY else {}

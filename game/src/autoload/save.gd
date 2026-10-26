extends Node
## Versioned JSON persistence with atomic writes (PLAN.md 6.3).
##
## A write goes to `<path>.tmp` and is then renamed over `<path>`, and the previous good file is
## kept as `<path>.bak`. A read takes the newest complete copy: the `.tmp` if a write was killed
## after finishing it (it's only ever left behind by a crash, and a half-written one doesn't
## parse), else the main file, else the `.bak`. So killing the app mid-save never loses the last
## good save. `read_versioned` also brings old files up to date through migration steps.

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


## Returns the newest complete copy (see above), or {} if there's none.
func read_json(path: String) -> Dictionary:
	for candidate in [path + TMP_SUFFIX, path, path + BAK_SUFFIX]:
		var parsed := _parse(candidate)
		if not parsed.is_empty():
			if candidate != path:
				push_warning("Save: %s: using %s" % [path, candidate.get_file()])
			return parsed
	return {}


## read_json() brought up to format `current` with `steps` (see migrate()); {} if there's no
## save or it can't be brought up to date.
func read_versioned(path: String, current: int, steps: Dictionary = {}) -> Dictionary:
	var data := read_json(path)
	if data.is_empty():
		return {}
	var out := migrate(data, current, steps)
	if out.is_empty():
		push_warning("Save: %s is format %s; this build reads up to %d" % [path, data.get("format", 0), current])
	return out


## `data` brought up to format `current`, one step at a time: `steps[n]` (a Callable taking and
## returning a Dictionary) turns format n into n + 1. Data with no `format` is format 0. Returns
## {} if a step is missing or the data is newer than `current` (written by a later build: it
## must not be read as if it were ours, or saving would overwrite it).
static func migrate(data: Dictionary, current: int, steps: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	var at := int(out.get("format", 0))
	if at > current:
		return {}
	while at < current:
		if not steps.has(at):
			return {}
		out = (steps[at] as Callable).call(out)
		at += 1
		out["format"] = at
	return out


func _parse(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return json.data if typeof(json.data) == TYPE_DICTIONARY else {}

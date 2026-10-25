extends Node
## Loads every `res://data/*.json` table at boot and validates its envelope.
##
## Each table is a JSON object with an integer `format` field. A table that fails to load is
## recorded in `errors` and reported with push_error, and the boot screen shows the count,
## so a bad data file is never silently skipped.

const DATA_DIR := "res://data"

var errors: PackedStringArray = []

var _tables: Dictionary = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	_tables.clear()
	errors.clear()
	for file_name in DirAccess.get_files_at(DATA_DIR):
		if file_name.get_extension() == "json":
			_load_table(DATA_DIR.path_join(file_name))


## Returns the table named after its file (without `.json`), or an empty Dictionary.
func table(table_name: StringName) -> Dictionary:
	return _tables.get(table_name, {})


func has_table(table_name: StringName) -> bool:
	return _tables.has(table_name)


func _load_table(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		_fail(path, "empty or unreadable (%s)" % error_string(FileAccess.get_open_error()))
		return
	var json := JSON.new()
	if json.parse(text) != OK:
		_fail(path, "line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return
	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail(path, "top level must be an object")
		return
	if typeof(parsed.get("format")) != TYPE_FLOAT:
		_fail(path, "missing integer `format` field")
		return
	_tables[StringName(path.get_file().get_basename())] = parsed


func _fail(path: String, why: String) -> void:
	var message := "%s: %s" % [path, why]
	errors.append(message)
	push_error("Data: " + message)

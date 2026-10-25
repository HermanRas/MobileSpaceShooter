extends Logger
## Any script error during a drive is a failure. Without this, a step that crashes half-way
## skips its remaining checks and the drive still reports PASS (it did, building 2.5).
## Same idea as the Logger in tests/run_tests.gd. Shared by the drive_*.gd scenes.

var seen: PackedStringArray = []


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Variant) -> void:
	if error_type == ERROR_TYPE_SCRIPT:
		seen.append("%s (%s:%d in %s)" % [rationale if rationale != "" else code, file.get_file(), line, function])

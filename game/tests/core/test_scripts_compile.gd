extends TestCase
## Every script under src/ compiles. Unit tests only load what they touch, so a parse error in,
## say, an effect used only in flight slipped past the suite until a drive ran (4.5).

const ROOTS := ["res://src", "res://dev_preview"]


func test_every_script_compiles() -> void:
	var paths: PackedStringArray = []
	for root: String in ROOTS:
		paths.append_array(_scripts(root))
	assert_true(paths.size() > 40, "found the scripts (%d)" % paths.size())
	for path in paths:
		var script := load(path) as GDScript
		assert_true(script != null and script.can_instantiate(), "%s compiles" % path)


func _scripts(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file_name in DirAccess.get_files_at(dir_path):
		if file_name.get_extension() == "gd":
			found.append(dir_path.path_join(file_name))
	for sub in DirAccess.get_directories_at(dir_path):
		found.append_array(_scripts(dir_path.path_join(sub)))
	return found

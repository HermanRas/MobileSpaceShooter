extends TestCase
## PLAN.md 5.1: nothing in src/model/ may be a Node, load art, or read input.
## That rule is what lets the hard logic run headless in milliseconds.

const MODEL_DIR := "res://src/model"

const FORBIDDEN := {
	"extends a Node type": "^extends\\s+(Node|Control|CanvasItem|Sprite2D|Area2D|RigidBody2D|CharacterBody2D|StaticBody2D|Camera2D)\\b",
	"reads input": "\\bInput\\.",
	"loads a texture": "(load|preload)\\(\"res://assets/",
	"reaches into the scene tree": "\\bget_tree\\(\\)",
}


func test_model_dir_exists() -> void:
	assert_true(DirAccess.dir_exists_absolute(MODEL_DIR), "src/model/ is missing")


func test_no_model_script_breaks_the_boundary() -> void:
	var patterns := {}
	for why: String in FORBIDDEN:
		var regex := RegEx.new()
		regex.compile(FORBIDDEN[why])
		patterns[why] = regex
	for path in _scripts(MODEL_DIR):
		var source := FileAccess.get_file_as_string(path)
		for why: String in patterns:
			var hit: RegExMatch = (patterns[why] as RegEx).search(source)
			assert_null(hit, "%s %s" % [path, why])
	assert_true(true, "boundary scan completed")


func _scripts(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file_name in DirAccess.get_files_at(dir_path):
		if file_name.get_extension() == "gd":
			found.append(dir_path.path_join(file_name))
	for sub in DirAccess.get_directories_at(dir_path):
		found.append_array(_scripts(dir_path.path_join(sub)))
	return found

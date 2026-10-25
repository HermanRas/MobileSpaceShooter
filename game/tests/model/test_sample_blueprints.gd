extends TestCase
## Phase 1.6: every shipped blueprint parses and is buildable.

func test_every_shipped_blueprint_is_valid() -> void:
	var tiles_table := Data.table(&"tiles")
	var placement := Placement.create(ShapeLib.from_table(Data.table(&"shapes")),
			TileLib.from_table(tiles_table), tiles_table)
	var files := Data.json_dir("blueprints")
	assert_true(files.has("starter"), "the starter ship ships")
	for file_name: String in files:
		var errors: PackedStringArray = []
		var bp := Blueprint.from_dict(files[file_name], errors)
		assert_not_null(bp, "%s: %s" % [file_name, ", ".join(errors)])
		if bp == null:
			continue
		assert_eq(bp.id, file_name, "a blueprint's id matches its file name")
		var problems := placement.validate(bp)
		var messages := problems.map(func(p: Placement.Problem) -> String: return p.message)
		assert_eq(problems.size(), 0, "%s: %s" % [file_name, ", ".join(messages)])


func test_starter_has_three_hardpoints_for_its_thrusters() -> void:
	var errors: PackedStringArray = []
	var bp := Blueprint.from_dict(Data.json_dir("blueprints")["starter"], errors)
	var hardpoints := bp.tiles.filter(func(t: Blueprint.Tile) -> bool: return t.type == &"hardpoint")
	assert_eq(hardpoints.size(), 3, "rear-left, rear-right, front (PLAN.md 4.3)")

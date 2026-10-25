extends TestCase
## Phase 2.3: hangar edits, undo/redo and mirror mode.

var editor: HangarEditor


func before_each() -> void:
	var tiles_table := Data.table(&"tiles")
	var placement := Placement.create(ShapeLib.from_table(Data.table(&"shapes")),
			TileLib.from_table(tiles_table), tiles_table)
	editor = HangarEditor.create(placement)


func test_a_new_ship_is_just_a_core() -> void:
	assert_eq(editor.blueprint.tiles.size(), 1)
	assert_eq(editor.core_tile().type, &"core")
	assert_eq(editor.placement.validate(editor.blueprint).size(), 0)


func test_place_and_remove() -> void:
	var ids := editor.place(&"hull", &"square", &"L", Vector2(1, 0), 0)
	assert_eq(ids.size(), 1)
	assert_eq(editor.blueprint.tiles.size(), 2)
	assert_true(editor.remove(ids[0]))
	assert_eq(editor.blueprint.tiles.size(), 1)


func test_overlapping_placement_is_refused() -> void:
	assert_eq(editor.place(&"hull", &"square", &"L", Vector2(0.5, 0), 0).size(), 0)
	assert_false(editor.can_undo(), "a refused edit leaves no undo step")


func test_the_core_cannot_be_removed_or_moved() -> void:
	assert_false(editor.remove(editor.core_tile().id))
	assert_false(editor.move(editor.core_tile().id, Vector2(3, 3), 0))


func test_undo_restores_exactly_and_redo_reapplies() -> void:
	var start := JSON.stringify(editor.blueprint.to_dict())
	editor.place(&"hull", &"square", &"L", Vector2(1, 0), 0)
	var after_place := JSON.stringify(editor.blueprint.to_dict())
	editor.paint_all(Color.RED)
	editor.undo()
	assert_eq(JSON.stringify(editor.blueprint.to_dict()), after_place)
	editor.undo()
	assert_eq(JSON.stringify(editor.blueprint.to_dict()), start)
	assert_false(editor.undo(), "nothing left to undo")
	editor.redo()
	assert_eq(JSON.stringify(editor.blueprint.to_dict()), after_place)


func test_a_new_edit_clears_redo() -> void:
	editor.place(&"hull", &"square", &"L", Vector2(1, 0), 0)
	editor.undo()
	editor.place(&"hull", &"square", &"L", Vector2(-1, 0), 0)
	assert_false(editor.can_redo())


func test_undo_is_capped() -> void:
	for i in HangarEditor.UNDO_DEPTH + 20:
		editor.paint_all(Color(i / 200.0, 0, 0))
	var undone := 0
	while editor.undo():
		undone += 1
	assert_eq(undone, HangarEditor.UNDO_DEPTH)


func test_mirror_places_and_removes_pairs() -> void:
	editor.mirror = true
	var ids := editor.place(&"hull", &"square", &"L", Vector2(0, -1), 0)
	assert_eq(ids.size(), 2, "the image lands below the axis")
	var twin := editor.blueprint.tile_by_id(ids[1])
	assert_true(twin.pos.distance_to(Vector2(0, 1)) < 0.001, "image at %s" % twin.pos)
	assert_true(editor.remove(ids[0]))
	assert_eq(editor.blueprint.tiles.size(), 1, "removing one side removes both")


func test_mirror_skips_tiles_on_the_axis() -> void:
	editor.mirror = true
	assert_eq(editor.place(&"hull", &"square", &"L", Vector2(1, 0), 0).size(), 1)


func test_mirror_handles_the_wedge() -> void:
	# The wedge has no symmetry of its own, so its image needs a different rotation.
	editor.mirror = true
	editor.place(&"hull", &"square", &"L", Vector2(1, 0), 0)
	var ids := editor.place(&"hull", &"wedge", &"L", Vector2(1, -1), 18)
	assert_eq(ids.size(), 2)
	var twin := editor.blueprint.tile_by_id(ids[1])
	assert_true(twin.pos.distance_to(Vector2(1, 1)) < 0.001, "image at %s" % twin.pos)
	assert_eq(twin.rot, 0, "the starter's lower nose wedge")
	assert_eq(editor.placement.validate(editor.blueprint).size(), 0)


func test_mirror_builds_the_starter_shape_from_half_the_clicks() -> void:
	editor.mirror = true
	editor.place(&"hull", &"square", &"L", Vector2(-1, 0), 0)
	editor.place(&"hull", &"square", &"L", Vector2(0, -1), 0)
	editor.place(&"hardpoint", &"square", &"L", Vector2(-1, -1), 0)
	editor.place(&"hardpoint", &"square", &"L", Vector2(1, 0), 0)
	editor.place(&"hull", &"wedge", &"L", Vector2(1, -1), 18)
	assert_eq(editor.blueprint.tiles.size(), 9, "same tile count as data/blueprints/starter.json")
	assert_eq(editor.placement.validate(editor.blueprint).size(), 0)


func test_move_keeps_paint_and_moves_the_twin() -> void:
	editor.mirror = true
	var ids := editor.place(&"hull", &"square", &"L", Vector2(0, -1), 0, Color.BLUE)
	assert_true(editor.move(ids[0], Vector2(0.25, -1), 0))
	var moved := editor.blueprint.tile_by_id(ids[0])
	assert_eq(moved.paint, Color.BLUE)
	assert_true(editor.blueprint.tile_by_id(ids[1]).pos.distance_to(Vector2(0.25, 1)) < 0.001)
	editor.undo()
	assert_true(editor.blueprint.tile_by_id(ids[0]).pos.distance_to(Vector2(0, -1)) < 0.001)


func test_paint_by_tile_type_and_all() -> void:
	editor.place(&"hull", &"square", &"L", Vector2(1, 0), 0)
	editor.place(&"armor", &"square", &"L", Vector2(-1, 0), 0)
	editor.paint_type(&"armor", Color.GREEN)
	assert_eq(editor.blueprint.tile_by_id(2).paint, Color.GREEN)
	assert_ne(editor.blueprint.tile_by_id(1).paint, Color.GREEN)
	editor.paint_all(Color.YELLOW)
	for tile in editor.blueprint.tiles:
		assert_eq(tile.paint, Color.YELLOW)


func test_mirrored_paint_reaches_the_twin() -> void:
	editor.mirror = true
	var ids := editor.place(&"hull", &"square", &"L", Vector2(0, -1), 0)
	editor.paint_tiles(PackedInt32Array([ids[0]]), Color.ORANGE)
	assert_eq(editor.blueprint.tile_by_id(ids[1]).paint, Color.ORANGE)


func test_changed_fires_on_every_edit() -> void:
	var count := [0]
	editor.changed.connect(func() -> void: count[0] += 1)
	editor.place(&"hull", &"square", &"L", Vector2(1, 0), 0)
	editor.paint_all(Color.RED)
	editor.undo()
	assert_eq(count[0], 3)

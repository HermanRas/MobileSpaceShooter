extends Node
## Drives the real hangar with synthetic touch events and checks what happened.
## Run with `tools/drive.sh res://dev_preview/drive_hangar.tscn`. Exit code 0 = every step passed.
##
## This is the check a screenshot can't make: that a finger dragging out of the palette,
## tapping, pinching and panning actually reach the right code.

var _hangar: Node
var _failures: PackedStringArray = []
var _spy := ScriptErrorSpy.new()


## Any script error during a drive is a failure. Without this, a step that crashes half-way
## skips its remaining checks and the drive still reports PASS (it did, building 2.5).
## Same idea as the Logger in tests/run_tests.gd.
class ScriptErrorSpy extends Logger:
	var seen: PackedStringArray = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Variant) -> void:
		if error_type == ERROR_TYPE_SCRIPT:
			seen.append("%s (%s:%d in %s)" % [rationale if rationale != "" else code, file.get_file(), line, function])


func _ready() -> void:
	OS.add_logger(_spy)
	_hangar = (load("res://scenes/hangar/hangar.tscn") as PackedScene).instantiate()
	add_child(_hangar)
	await _frames(5)
	var errors: PackedStringArray = []
	_hangar.load_blueprint(Blueprint.from_dict(Data.json_dir("blueprints")["starter"], errors))
	await _frames(3)

	await _step_drag_from_palette()
	await _step_tap_select_delete_undo()
	await _step_move_selected()
	await _step_paint()
	await _step_stats_match_and_refresh_fast()
	await _step_library()
	await _step_pinch_zooms()
	await _step_one_finger_pans()

	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://dev_preview/out/drive_hangar.png"))
	OS.remove_logger(_spy)
	for error in _spy.seen:
		_failures.append("script error: " + error)
	if _failures.is_empty():
		print("drive_hangar: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			printerr("drive_hangar: FAIL  " + failure)
		get_tree().quit(1)


func _step_drag_from_palette() -> void:
	var before: int = _hangar.editor.blueprint.tiles.size()
	var swatch := _swatch("triangle")
	var start := swatch.get_global_rect().get_center()
	# Aim the ghost (which floats GHOST_LIFT_PX above the finger) at the top of the ship.
	var target := _screen_of_u(Vector2(0, -1.75)) + Vector2(0, _hangar.GHOST_LIFT_PX)
	await _drag(0, start, target)
	_check(_hangar.editor.blueprint.tiles.size() == before + 1, "dragging a triangle onto the ship adds a tile")
	_check(_hangar.placement.validate(_hangar.editor.blueprint).is_empty(), "the dropped tile is valid")
	_check(_hangar._selected >= 0, "the new tile is selected")


func _step_tap_select_delete_undo() -> void:
	_hangar._select(-1)
	# Straight after a palette drag: the case where a swallowed release left the GUI's touch
	# focus on the swatch and this tap never reached the ship.
	await _tap(0, _screen_of_u(Vector2(-1, 0)))
	var picked: Blueprint.Tile = _hangar.editor.blueprint.tile_by_id(_hangar._selected)
	_check(picked != null and picked.pos == Vector2(-1, 0), "a tap selects the tile under the finger")
	var before: int = _hangar.editor.blueprint.tiles.size()
	_hangar._delete_selected()
	_check(_hangar.editor.blueprint.tiles.size() == before - 1, "delete removes it")
	_hangar.editor.undo()
	await _frames(2)
	_check(_hangar.editor.blueprint.tiles.size() == before, "undo brings it back")


func _step_move_selected() -> void:
	# The wedge at (1, 1), dragged down onto the free bottom edge of the lower hull tile.
	await _tap(0, _screen_of_u(Vector2(0.8, 1.2)))
	var tile_id: int = _hangar._selected
	_check(tile_id >= 0, "tap selects the lower wedge")
	var from := _screen_of_u(Vector2(0.8, 1.2))
	var to := _screen_of_u(Vector2(0, 2.0)) + Vector2(0, _hangar.GHOST_LIFT_PX)
	await _drag(0, from, to)
	var moved: Blueprint.Tile = _hangar.editor.blueprint.tile_by_id(tile_id)
	_check(moved != null and moved.pos.distance_to(Vector2(1, 1)) > 0.1, "dragging a selected tile moves it")
	_check(_hangar.placement.validate(_hangar.editor.blueprint).is_empty(), "the moved tile is valid")


func _step_paint() -> void:
	var paint: PaintPanel = _hangar._paint
	paint.visible = true
	paint.choose(Color("#c0392b"))
	paint.scope = PaintPanel.Scope.TILE
	await _tap(0, _screen_of_u(Vector2(0, -1)))
	var top: Blueprint.Tile = _hangar.editor.blueprint.tiles.filter(
			func(t: Blueprint.Tile) -> bool: return t.pos == Vector2(0, -1))[0]
	_check(top.paint.is_equal_approx(Color("#c0392b")), "with the paint panel open, a tap paints that tile")
	paint.scope = PaintPanel.Scope.TYPE
	paint.choose(Color("#2e86de"))
	await _tap(0, _screen_of_u(Vector2(-1, -1)))
	var hardpoints: Array = _hangar.editor.blueprint.tiles.filter(
			func(t: Blueprint.Tile) -> bool: return t.type == &"hardpoint")
	_check(hardpoints.all(func(t: Blueprint.Tile) -> bool: return t.paint.is_equal_approx(Color("#2e86de"))),
			"Type scope paints every hardpoint")
	_check(Settings.get_value(&"recent_colors")[0] == "2e86de", "the colour lands in recent colours")
	await _frames(2)
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://dev_preview/out/drive_hangar_paint.png"))
	paint.visible = false


func _step_stats_match_and_refresh_fast() -> void:
	var stats := ShipStats.compute(_hangar.editor.blueprint, _hangar.placement)
	var shown: String = (_hangar._stats._rows[&"hp"][0] as Label).text
	_check(shown == "%d" % stats.hp, "the panel's HP (%s) matches ShipStats (%d)" % [shown, stats.hp])

	# A full 150-tile ship: how long does one edit's refresh take? (PLAN.md 2.5: under a frame.)
	var bp := Blueprint.new()
	bp.id = "big"
	bp.name = "Big"
	for i in 150:
		var tile := Blueprint.Tile.new()
		tile.id = i
		tile.type = &"core" if i == 0 else &"hull"
		tile.shape = &"square"
		tile.size = &"L"
		tile.pos = Vector2(i % 10 - 5, i / 10 - 7)
		tile.paint = Color.GRAY
		bp.tiles.append(tile)
	bp.tiles[0].pos = Vector2(0, 0)
	bp.tiles[75].pos = Vector2(-5, -7)  # tile 75 started on the core's spot
	_hangar.load_blueprint(bp)
	await _frames(1)
	# One wall-clock sample in a shared container swings 2x (8.8 vs 17.1 ms on the same code),
	# so take the median of five edits.
	var samples: Array[float] = []
	for i in 5:
		_hangar.editor.paint_all(Color.from_hsv(i / 5.0, 0.5, 0.9))
		samples.append(_hangar.last_refresh_usec / 1000.0)
		await _frames(1)
	samples.sort()
	var ms := samples[2]
	print("drive_hangar: 150-tile refresh median %.1f ms (min %.1f, max %.1f) on this machine"
			% [ms, samples[0], samples[4]])
	_check(ms < 16.7, "a 150-tile refresh fits in one 60 fps frame here (median %.1f ms)" % ms)
	for i in 5:
		_hangar.editor.undo()
	var errors: PackedStringArray = []
	_hangar.load_blueprint(Blueprint.from_dict(Data.json_dir("blueprints")["starter"], errors))
	await _frames(1)


func _step_library() -> void:
	var library: BlueprintLibrary = _hangar._library
	for entry in library.list():
		library.delete(entry["id"])
	var saved_error: Error = await _hangar.save_current()
	var first_id: String = _hangar.editor.blueprint.id
	_check(saved_error == OK and library.has(first_id), "Save writes the ship to the library")
	_check(FileAccess.file_exists(library.thumbnail_path(first_id)), "Save renders a thumbnail")
	var thumb := Image.load_from_file(library.thumbnail_path(first_id))
	_check(thumb != null and thumb.get_used_rect().size.x > 100, "the thumbnail has the ship in it")
	var expected := JSON.stringify(_hangar.editor.blueprint.to_dict())

	for i in 9:
		_hangar.editor.paint_all(Color.from_hsv(i / 9.0, 0.7, 0.9))
		await _hangar.save_as("Test ship %d" % (i + 1))
	_check(library.list().size() == 10, "10 ships saved (%d)" % library.list().size())

	_hangar.load_from_library(first_id)
	_check(JSON.stringify(_hangar.editor.blueprint.to_dict()) == expected, "loading gives back exactly what was saved")
	library.rename(first_id, "Renamed")
	_check(library.list().any(func(e: Dictionary) -> bool: return e["name"] == "Renamed"), "rename shows in the list")
	library.delete(library.list()[0]["id"])
	_check(library.list().size() == 9, "delete removes one")

	_hangar._open_library(true)
	await _frames(4)
	get_viewport().get_texture().get_image().save_png(
			ProjectSettings.globalize_path("res://dev_preview/out/drive_hangar_library.png"))
	_hangar._open_library(false)


func _step_pinch_zooms() -> void:
	var zoom_before: float = _hangar._camera.zoom.x
	var center := Vector2(780, 360)
	_touch(0, center + Vector2(-40, 0), true)
	_touch(1, center + Vector2(40, 0), true)
	await _frames(1)
	for i in range(1, 11):
		_drag_event(1, center + Vector2(40 + i * 12, 0), Vector2(12, 0))
		await _frames(1)
	_touch(1, center + Vector2(160, 0), false)
	_touch(0, center + Vector2(-40, 0), false)
	await _frames(2)
	_check(_hangar._camera.zoom.x > zoom_before * 1.3, "spreading two fingers zooms in (%.2f -> %.2f)"
			% [zoom_before, _hangar._camera.zoom.x])


func _step_one_finger_pans() -> void:
	var before: Vector2 = _hangar._camera.position
	await _drag(0, Vector2(300, 150), Vector2(400, 200))
	_check(_hangar._camera.position.distance_to(before) > 1.0, "one finger on empty space pans")


# ── helpers ───────────────────────────────────────────────────────────────────

func _drag(finger: int, from: Vector2, to: Vector2) -> void:
	_touch(finger, from, true)
	await _frames(1)
	var steps := 12
	var last := from
	for i in range(1, steps + 1):
		var at := from.lerp(to, float(i) / steps)
		_drag_event(finger, at, at - last)
		last = at
		await _frames(1)
	await _frames(2)
	_touch(finger, to, false)
	await _frames(2)


func _tap(finger: int, at: Vector2) -> void:
	_touch(finger, at, true)
	await _frames(1)
	_touch(finger, at, false)
	await _frames(2)


func _touch(finger: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = at
	event.pressed = pressed
	Input.parse_input_event(event)


func _drag_event(finger: int, at: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = finger
	event.position = at
	event.relative = relative
	Input.parse_input_event(event)


func _screen_of_u(point_u: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * (point_u * ShipMesh.PX_PER_U)


func _swatch(shape_id: String) -> Control:
	for child in _hangar._palette._shape_row.get_children():
		if (child as Control).tooltip_text == shape_id:
			return child
	return null


func _check(ok: bool, what: String) -> void:
	print("drive_hangar: %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

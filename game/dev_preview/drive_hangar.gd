extends Node
## Drives the real hangar with synthetic touch events and checks what happened.
## Run with `tools/drive.sh res://dev_preview/drive_hangar.tscn`. Exit code 0 = every step passed.
##
## This is the check a screenshot can't make: that a finger dragging out of the palette,
## tapping, pinching and panning actually reach the right code.

var _hangar: Node
var _failures: PackedStringArray = []


func _ready() -> void:
	_hangar = (load("res://scenes/hangar/hangar.tscn") as PackedScene).instantiate()
	add_child(_hangar)
	await _frames(5)
	var errors: PackedStringArray = []
	_hangar.load_blueprint(Blueprint.from_dict(Data.json_dir("blueprints")["starter"], errors))
	await _frames(3)

	await _step_drag_from_palette()
	await _step_tap_select_delete_undo()
	await _step_move_selected()
	await _step_pinch_zooms()
	await _step_one_finger_pans()

	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://dev_preview/out/drive_hangar.png"))
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

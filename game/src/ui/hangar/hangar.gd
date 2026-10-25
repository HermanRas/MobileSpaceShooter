extends Node
## The hangar (Phase 2): build a ship with your thumbs.
##
## Input, in priority order:
## - CARRYING a tile (dragged from the palette, or a selected tile being moved): handled in
##   `_input`, before the GUI, so the finger can roam over any control. The ghost floats
##   GHOST_LIFT_PX above the finger so the thumb doesn't hide it. Release places it.
## - Otherwise world touches arrive in `_unhandled_input` (the GUI has had first pick):
##   one finger taps (select) or pans, two fingers pinch-zoom and pan. Dragging a selected
##   tile starts moving it.
## Snap searches are throttled to once per frame; the latest finger position wins.

const PX := ShipMesh.PX_PER_U
const GHOST_LIFT_PX := 90.0
const SNAP_REACH_U := 1.0
const TAP_SLOP_PX := 14.0
const VARIANT_SPREAD_U := 0.75

var editor: HangarEditor
var placement: Placement

var _camera: HangarCamera
var _view: ShipView
var _palette: HangarPalette
var _paint: PaintPanel
var _stats: StatsPanel
var _library := BlueprintLibrary.new()
var _library_panel: LibraryPanel
var _thumbs: ThumbnailRenderer
var _mirror_button: Button
var _undo_button: Button
var _redo_button: Button
var _status: Label

var _selected: int = -1
## Active carry: {"type", "shape", "size", "paint", "moving": tile id or -1, "finger": index}
var _carry: Dictionary = {}
var _carry_screen := Vector2.ZERO
var _carry_dirty := false
var _snap: Placement.Snap = null
var _rot_pref: int = 0

var _touches: Dictionary = {}  # finger index -> screen position
var _gesture: StringName = &""  # &"tap", &"pan", &"pinch"
var _press_screen := Vector2.ZERO
var _press_tile: int = -1


func _ready() -> void:
	var tiles_table := Data.table(&"tiles")
	placement = Placement.create(ShapeLib.from_table(Data.table(&"shapes")),
			TileLib.from_table(tiles_table), tiles_table)
	editor = HangarEditor.create(placement)
	editor.changed.connect(_on_changed)

	var world := Node2D.new()
	add_child(world)
	_view = ShipView.new()
	_view.placement = placement
	_view.area_u = placement.area_u
	world.add_child(_view)
	_camera = HangarCamera.new()
	_camera.zoom = Vector2(1.6, 1.6)
	world.add_child(_camera)

	_build_ui()
	_on_changed()


## Loads a ship into the hangar (from the library, or a test).
func load_blueprint(bp: Blueprint) -> void:
	editor.load_blueprint(bp)
	_select(-1)


## Saves the ship being edited to the library, with a fresh thumbnail.
func save_current() -> Error:
	var error := _library.save_ship(editor.blueprint)
	if error == OK:
		error = await _thumbs.render(editor.blueprint, placement, _library.thumbnail_path(editor.blueprint.id))
	_on_changed()
	return error


## Saves a copy under a new name and keeps editing the copy (undo history is kept).
func save_as(new_name: String) -> void:
	var copy := _library.save_as(editor.blueprint, new_name)
	editor.blueprint.id = copy.id
	editor.blueprint.name = copy.name
	await _thumbs.render(editor.blueprint, placement, _library.thumbnail_path(copy.id))
	_on_changed()


func load_from_library(id: String) -> void:
	var bp := _library.load_ship(id)
	if bp != null:
		load_blueprint(bp)


func _open_library(open: bool) -> void:
	_library_panel.visible = open
	if open:
		_library_panel.refresh()


func on_back() -> void:
	if not _carry.is_empty():
		_end_carry()
	else:
		Router.goto_main_menu()


# ── input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if _carry.is_empty():
		if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
			_on_key(event as InputEventKey)
		return
	if event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _carry["finger"]:
		_carry_screen = (event as InputEventScreenDrag).position
		_carry_dirty = true
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).index == _carry["finger"] \
			and not (event as InputEventScreenTouch).pressed:
		_carry_screen = (event as InputEventScreenTouch).position
		_update_ghost()
		_commit_carry()
		# NOT marked handled: the GUI gave this finger's touch focus to the palette swatch the
		# drag started on, and only the release clears it. Swallow it and the next tap goes to
		# the swatch instead of the ship (found by drive_hangar).
	elif event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_R:
		_cycle_carry_rotation()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touches[touch.index] = touch.position
			if _touches.size() == 1:
				_gesture = &"tap"
				_press_screen = touch.position
				_press_tile = _tile_at(touch.position)
			else:
				_gesture = &"pinch"
		else:
			_touches.erase(touch.index)
			if _gesture == &"tap" and _touches.is_empty():
				_on_tap(touch.position)
			if _touches.is_empty():
				_gesture = &""
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if not _touches.has(drag.index):
			return
		var previous: Vector2 = _touches[drag.index]
		_touches[drag.index] = drag.position
		if _gesture == &"pinch" and _touches.size() >= 2:
			_pinch(drag.index, previous, drag.position)
		elif _gesture == &"tap" and drag.position.distance_to(_press_screen) > TAP_SLOP_PX:
			if _press_tile >= 0 and _press_tile == _selected and _press_tile != editor.core_tile().id:
				_start_move(_press_tile, drag.index, drag.position)
				_touches.erase(drag.index)
				_gesture = &""
			else:
				_gesture = &"pan"
		elif _gesture == &"pan":
			_camera.pan_by(drag.position - previous)


func _pinch(moved: int, previous: Vector2, now: Vector2) -> void:
	var other := -1
	for index: int in _touches:
		if index != moved:
			other = index
			break
	var anchor: Vector2 = _touches[other]
	var before := previous.distance_to(anchor)
	var after := now.distance_to(anchor)
	if before > 1.0:
		_camera.zoom_at((now + anchor) * 0.5, after / before)
	_camera.pan_by((now - previous) * 0.5)


func _on_key(key: InputEventKey) -> void:
	match key.keycode:
		KEY_Z when key.ctrl_pressed and key.shift_pressed: editor.redo()
		KEY_Z when key.ctrl_pressed: editor.undo()
		KEY_Y when key.ctrl_pressed: editor.redo()
		KEY_DELETE, KEY_BACKSPACE: _delete_selected()
		KEY_R: _rotate_selected()
		KEY_D: _duplicate_selected()
		KEY_M: _mirror_button.button_pressed = not _mirror_button.button_pressed


# ── carrying ──────────────────────────────────────────────────────────────────

func _start_carry_new(type: StringName, shape: StringName, size: StringName) -> void:
	_select(-1)
	_carry = {"type": type, "shape": shape, "size": size,
			"paint": HangarEditor.DEFAULT_PAINT, "moving": -1, "finger": 0}
	_carry_screen = _touch_position_or_mouse(0)
	_carry_dirty = true


func _start_move(tile_id: int, finger: int, screen: Vector2) -> void:
	var tile := editor.blueprint.tile_by_id(tile_id)
	_carry = {"type": tile.type, "shape": tile.shape, "size": tile.size,
			"paint": tile.paint, "moving": tile_id, "finger": finger}
	_rot_pref = tile.rot
	_carry_screen = screen
	_carry_dirty = true


func _process(_delta: float) -> void:
	if _carry_dirty:
		_carry_dirty = false
		_update_ghost()


func _update_ghost() -> void:
	if _carry.is_empty():
		return
	var point_u := _camera.screen_to_world(_carry_screen + Vector2(0, -GHOST_LIFT_PX)) / PX
	var target := editor.blueprint
	if _carry["moving"] >= 0:
		target = editor.blueprint_without(PackedInt32Array([_carry["moving"], editor.twin_of(_carry["moving"])]))
	var snaps := placement.candidate_snaps(target, _carry["type"], _carry["shape"], _carry["size"],
			point_u, SNAP_REACH_U + 1.0)
	_snap = _choose_snap(snaps, point_u)
	var ghost := Blueprint.Tile.new()
	ghost.type = _carry["type"]
	ghost.shape = _carry["shape"]
	ghost.size = _carry["size"]
	ghost.paint = _carry["paint"]
	if _snap != null:
		ghost.pos = _snap.pos
		ghost.rot = _snap.rot
	else:
		ghost.rot = _rot_pref
		ghost.pos = point_u - ShipStats.polygon_centroid(placement.shapes.polygon(ghost.shape, ghost.size, ghost.rot))
	_view.set_ghost(ghost, _snap != null)
	_stats.show_delta(placement.tiles.tile(ghost.type) if _snap != null and _carry["moving"] < 0 else null, ghost.size)


## The snap whose tile centre is nearest the finger, preferring the player's chosen rotation
## among the variants at that spot.
func _choose_snap(snaps: Array[Placement.Snap], point_u: Vector2) -> Placement.Snap:
	var best: Placement.Snap = null
	var best_d := INF
	for snap in snaps:
		var d := _snap_center(snap).distance_to(point_u)
		if d < best_d:
			best_d = d
			best = snap
	if best == null or best_d > SNAP_REACH_U:
		return null
	for variant in _variants(snaps, best):
		if variant.rot == _rot_pref:
			return variant
	return best


func _variants(snaps: Array[Placement.Snap], around: Placement.Snap) -> Array[Placement.Snap]:
	var center := _snap_center(around)
	var out: Array[Placement.Snap] = []
	for snap in snaps:
		if snap.target_tile == around.target_tile and snap.target_edge == around.target_edge \
				and _snap_center(snap).distance_to(center) <= VARIANT_SPREAD_U:
			out.append(snap)
	out.sort_custom(func(a: Placement.Snap, b: Placement.Snap) -> bool: return a.rot < b.rot)
	return out


func _snap_center(snap: Placement.Snap) -> Vector2:
	return ShipStats.polygon_centroid(placement.shapes.polygon(_carry["shape"], _carry["size"], snap.rot, snap.pos))


func _cycle_carry_rotation() -> void:
	if _snap == null:
		_rot_pref = posmod(_rot_pref + 2, placement.shapes.rotation_steps())
	else:
		var point_u := _camera.screen_to_world(_carry_screen + Vector2(0, -GHOST_LIFT_PX)) / PX
		var target := editor.blueprint
		var snaps := placement.candidate_snaps(target, _carry["type"], _carry["shape"], _carry["size"], point_u, SNAP_REACH_U + 1.0)
		var variants := _variants(snaps, _snap)
		var at := variants.find_custom(func(s: Placement.Snap) -> bool: return s.rot == _snap.rot)
		if variants.size() > 1:
			_rot_pref = variants[(at + 1) % variants.size()].rot
	_update_ghost()


func _commit_carry() -> void:
	if _snap != null:
		_rot_pref = _snap.rot
		if _carry["moving"] >= 0:
			editor.move(_carry["moving"], _snap.pos, _snap.rot)
			_select(_carry["moving"])
		else:
			var ids := editor.place(_carry["type"], _carry["shape"], _carry["size"], _snap.pos, _snap.rot, _carry["paint"])
			if not ids.is_empty():
				_select(ids[0])
	_end_carry()


func _end_carry() -> void:
	_carry = {}
	_snap = null
	_view.set_ghost(null, false)
	_stats.show_delta(null, &"")


# ── toolbar actions ───────────────────────────────────────────────────────────

## A tap selects the tile under the finger, or paints it while the paint panel is open.
func _on_tap(screen: Vector2) -> void:
	var tile_id := _tile_at(screen)
	if not _paint.visible:
		_select(tile_id)
		return
	var tile := editor.blueprint.tile_by_id(tile_id)
	if tile == null:
		return
	match _paint.scope:
		PaintPanel.Scope.TILE: editor.paint_tiles(PackedInt32Array([tile_id]), _paint.color)
		PaintPanel.Scope.TYPE: editor.paint_type(tile.type, _paint.color)
		PaintPanel.Scope.SHIP: editor.paint_all(_paint.color)
	_paint.remember(_paint.color)


func _select(tile_id: int) -> void:
	_selected = tile_id
	var ids := PackedInt32Array()
	if tile_id >= 0:
		ids.append(tile_id)
		var twin := editor.twin_of(tile_id)
		if twin >= 0:
			ids.append(twin)
	_view.set_selected(ids)
	_refresh_buttons()


func _delete_selected() -> void:
	if _selected >= 0 and editor.remove(_selected):
		_select(-1)


func _duplicate_selected() -> void:
	var tile := editor.blueprint.tile_by_id(_selected)
	if tile == null or tile.type == placement.tiles.core_id():
		return
	var center := ShipStats.polygon_centroid(placement.tile_polygon(tile))
	var snaps := placement.candidate_snaps(editor.blueprint, tile.type, tile.shape, tile.size, center, 2.5)
	var best: Placement.Snap = null
	var best_d := INF
	for snap in snaps:
		var d := ShipStats.polygon_centroid(placement.shapes.polygon(tile.shape, tile.size, snap.rot, snap.pos)).distance_to(center)
		if d < best_d:
			best_d = d
			best = snap
	if best != null:
		var ids := editor.place(tile.type, tile.shape, tile.size, best.pos, best.rot, tile.paint)
		if not ids.is_empty():
			_select(ids[0])


## Turns the selected tile to its next valid orientation at about the same spot.
func _rotate_selected() -> void:
	var tile := editor.blueprint.tile_by_id(_selected)
	if tile == null or tile.type == placement.tiles.core_id():
		return
	var center := ShipStats.polygon_centroid(placement.tile_polygon(tile))
	var without := editor.blueprint_without(PackedInt32Array([tile.id, editor.twin_of(tile.id)]))
	var options: Array[Placement.Snap] = []
	var seen := {}
	for snap in placement.candidate_snaps(without, tile.type, tile.shape, tile.size, center, 2.0):
		var polygon := placement.shapes.polygon(tile.shape, tile.size, snap.rot, snap.pos)
		var key := Placement._polygon_key(polygon)
		if not seen.has(key) and ShipStats.polygon_centroid(polygon).distance_to(center) <= VARIANT_SPREAD_U:
			seen[key] = true
			options.append(snap)
	if options.size() < 2:
		return
	options.sort_custom(func(a: Placement.Snap, b: Placement.Snap) -> bool:
		return [a.rot, a.pos.x, a.pos.y] < [b.rot, b.pos.x, b.pos.y])
	var current := Placement._polygon_key(placement.tile_polygon(tile))
	var at := options.find_custom(func(s: Placement.Snap) -> bool:
		return Placement._polygon_key(placement.shapes.polygon(tile.shape, tile.size, s.rot, s.pos)) == current)
	var next := options[(at + 1) % options.size()]
	editor.move(tile.id, next.pos, next.rot)
	_rot_pref = next.rot


## Microseconds the last full refresh (validate + stats + mesh) took; drive_hangar reads it,
## and the debug Perf log prints it with its parts.
var last_refresh_usec: int = 0
var last_refresh_parts := {}


func _on_changed() -> void:
	var started := Time.get_ticks_usec()
	var analysis := placement.analyze(editor.blueprint)
	var problems := analysis.problems
	var analyzed := Time.get_ticks_usec()
	_view.show_blueprint(editor.blueprint, analysis)
	var drawn := Time.get_ticks_usec()
	if _selected >= 0 and editor.blueprint.tile_by_id(_selected) == null:
		_select(-1)
	else:
		_select(_selected)
	if _status != null:
		_status.text = "%s  ·  %s" % [editor.blueprint.name, "ready to fly" if problems.is_empty() else "can't fly yet"]
		_stats.show_stats(ShipStats.compute(editor.blueprint, placement), problems, placement.max_tiles)
	last_refresh_usec = Time.get_ticks_usec() - started
	last_refresh_parts = {"analyze": analyzed - started, "view": drawn - analyzed,
			"stats": started + last_refresh_usec - drawn}


func _refresh_buttons() -> void:
	if _undo_button == null:
		return
	_undo_button.disabled = not editor.can_undo()
	_redo_button.disabled = not editor.can_redo()


func _tile_at(screen: Vector2) -> int:
	var point_u := _camera.screen_to_world(screen) / PX
	for i in range(editor.blueprint.tiles.size() - 1, -1, -1):
		var tile := editor.blueprint.tiles[i]
		if Geometry2D.is_point_in_polygon(point_u, placement.tile_polygon(tile)):
			return tile.id
	return -1


func _touch_position_or_mouse(index: int) -> Vector2:
	return _touches.get(index, get_viewport().get_mouse_position())


# ── UI ────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	_palette = HangarPalette.new()
	_palette.shapes = placement.shapes
	_palette.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_palette.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_palette.drag_started.connect(_start_carry_new)
	root.add_child(_palette)

	var tools := VBoxContainer.new()
	tools.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tools.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tools.position = Vector2(-16, 16)
	root.add_child(tools)
	_undo_button = _tool_button(tools, "Undo", func() -> void: editor.undo())
	_redo_button = _tool_button(tools, "Redo", func() -> void: editor.redo())
	_tool_button(tools, "Rotate", _rotate_selected)
	_tool_button(tools, "Duplicate", _duplicate_selected)
	_tool_button(tools, "Delete", _delete_selected)
	_mirror_button = _tool_button(tools, "Mirror", func() -> void: pass)
	_mirror_button.toggle_mode = true
	_mirror_button.toggled.connect(func(on: bool) -> void:
		editor.mirror = on
		_select(_selected))
	var paint_button := _tool_button(tools, "Paint", func() -> void: pass)
	paint_button.toggle_mode = true

	_paint = PaintPanel.new()
	_paint.position = Vector2(16, 56)
	_paint.visible = false
	_paint.ship_paint_requested.connect(func(color: Color) -> void: editor.paint_all(color))
	root.add_child(_paint)
	paint_button.toggled.connect(func(on: bool) -> void:
		_paint.visible = on
		_stats.visible = not on
		_palette.visible = not on
		_select(-1))

	_status = Label.new()
	_status.position = Vector2(16, 12)
	_status.add_theme_font_size_override(&"font_size", 20)
	root.add_child(_status)

	_stats = StatsPanel.new()
	_stats.position = Vector2(16, 48)
	_stats.self_modulate = Color(1, 1, 1, 0.85)
	root.add_child(_stats)

	_tool_button(tools, "Ships", _open_library.bind(true))
	_thumbs = ThumbnailRenderer.new()
	add_child(_thumbs)
	_library_panel = LibraryPanel.new()
	_library_panel.library = _library
	_library_panel.visible = false
	_library_panel.closed.connect(_open_library.bind(false))
	_library_panel.new_requested.connect(func() -> void:
		editor.new_ship("New ship")
		_select(-1)
		_open_library(false))
	_library_panel.save_requested.connect(func() -> void:
		await save_current()
		_library_panel.refresh())
	_library_panel.save_as_requested.connect(func(new_name: String) -> void:
		await save_as(new_name)
		_library_panel.refresh())
	_library_panel.load_requested.connect(func(id: String) -> void:
		load_from_library(id)
		_open_library(false))
	root.add_child(_library_panel)


func _tool_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(132, 56)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


# ── dev_preview hook ──────────────────────────────────────────────────────────

## `tools/preview.sh` calls this to stage a state worth photographing.
##   --ship=<blueprint id>  load data/blueprints/<id>.json
##   --select=<tile id>     select a tile
##   --ghost=<shape>,<size>,<x>,<y>   show a carried ghost at that screen point
##   --mirror=1
##   --paint=1             open the paint panel
func preview_setup(args: Dictionary) -> void:
	if args.get("paint", "0") == "1":
		_paint.visible = true
		_stats.visible = false
		_palette.visible = false
	if args.has("ship"):
		var errors: PackedStringArray = []
		var bp := Blueprint.from_dict(Data.json_dir("blueprints").get(args["ship"], {}), errors)
		if bp != null:
			load_blueprint(bp)
	if args.get("mirror", "0") == "1":
		_mirror_button.button_pressed = true
	if args.has("select"):
		_select(int(args["select"]))
	if args.has("ghost"):
		var parts: PackedStringArray = (args["ghost"] as String).split(",")
		_carry = {"type": _palette.type, "shape": StringName(parts[0]), "size": StringName(parts[1]),
				"paint": HangarEditor.DEFAULT_PAINT, "moving": -1, "finger": 0}
		_carry_screen = Vector2(float(parts[2]), float(parts[3]))
		_update_ghost()

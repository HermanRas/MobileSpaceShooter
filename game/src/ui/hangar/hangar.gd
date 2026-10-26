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
##
## Stocked (PLAN.md 4.8a): with an active profile, the hangar builds that profile's ship from its
## stock, and every edit is paid for (HangarEditor). Delete becomes Remove, Sell sells the
## selected part (or a part dropped on it), a part dragged off the ship onto the palette goes in
## the inventory, and the Inventory tab holds what's loose. Without a profile it's Creative.

const PX := ShipMesh.PX_PER_U
const GHOST_LIFT_PX := 90.0
const SNAP_REACH_U := 1.0
const TAP_SLOP_PX := 14.0
const VARIANT_SPREAD_U := 0.75
const NOTICE_S := 2.5

var editor: HangarEditor
var placement: Placement

var _world: Node2D
var _ui: CanvasLayer
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
var _fly_button: Button
var _mode_button: Button
var _rotate_button: Button
var _duplicate_button: Button
var _sandbox: FlightSandbox
## The profile's hangar while stocked, or null in Creative.
var _store: StockStore
var _sell_button: Button
var _wallet: Label
var _notice: Label
var _notice_left := 0.0

var _selected: int = -1
var _selected_mount: int = -1
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
var _press_mount: int = -1
## While carrying a thruster or gun: the slot it would go in ({} for none).
var _mount_slot: Dictionary = {}


func _ready() -> void:
	var tiles_table := Data.table(&"tiles")
	placement = Placement.create(ShapeLib.from_table(Data.table(&"shapes")),
			TileLib.from_table(tiles_table), tiles_table)
	placement.thrusters = ThrusterLib.from_table(Data.table(&"thrusters"))
	placement.weapons = WeaponLib.from_table(Data.table(&"weapons"), Data.table(&"weapon_xp"))
	editor = HangarEditor.create(placement)
	if not Profiles.active_id.is_empty():
		_store = StockStore.open(Profiles.profile_dir(Profiles.active_id), Data.table(&"economy").get("dev_profile", {}),
				Data.json_dir("blueprints"))
	if _store != null:
		editor.economy = Economy.from_table(Data.table(&"economy"))
		editor.stock = _store.inventory
		editor.load_blueprint(_store.ship)
	editor.changed.connect(_on_changed)

	_world = Node2D.new()
	add_child(_world)
	_view = ShipView.new()
	_view.placement = placement
	_view.area_u = placement.area_u
	_world.add_child(_view)
	_camera = HangarCamera.new()
	_camera.zoom = Vector2(1.6, 1.6)
	_world.add_child(_camera)

	_build_ui()
	_on_changed()
	_seed_samples.call_deferred()


## Puts the game's sample ships in the library (new or changed ones only), with thumbnails from
## a renderer of their own, so a Save made meanwhile can't share its viewport.
func _seed_samples() -> void:
	var written := _library.seed_samples(Data.json_dir("blueprints"))
	if written.is_empty():
		return
	var renderer := ThumbnailRenderer.new()
	add_child(renderer)
	for id in written:
		var bp := _library.load_ship(id)
		if bp != null:
			await renderer.render(bp, placement, _library.thumbnail_path(id))
	renderer.queue_free()


## Whether building pays from a profile's stock (not Creative).
func stocked() -> bool:
	return _store != null


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


## Test-flies a copy of the ship on top of the hangar (Phase 3). Returns null if the ship has
## problems. The hangar is hidden and paused, not freed, so edits and undo survive the flight.
func fly() -> FlightSandbox:
	if _sandbox != null or not placement.validate(editor.blueprint).is_empty():
		return null
	if not _carry.is_empty():
		_end_carry()
	var errors: PackedStringArray = []
	var copy := Blueprint.from_dict(editor.blueprint.to_dict(), errors)
	_set_hangar_active(false)
	_sandbox = FlightSandbox.new()
	_sandbox.name = "FlightSandbox"
	_sandbox.stock = editor.stock
	add_child(_sandbox)
	_sandbox.open(copy, placement)
	_sandbox.closed.connect(land)
	return _sandbox


## Back from a test flight.
func land() -> void:
	if _sandbox == null:
		return
	_sandbox.queue_free()
	_sandbox = null
	_set_hangar_active(true)
	_camera.make_current()
	if stocked():
		_on_changed()  # saves the XP the flight earned, and shows it


func _set_hangar_active(on: bool) -> void:
	_world.visible = on
	_world.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	_ui.visible = on
	set_process_input(on)
	set_process_unhandled_input(on)


## One line for the debug Perf log.
func perf_note() -> String:
	if _sandbox != null:
		return _sandbox.perf_note()
	var parts: Array[String] = []
	for key: String in last_refresh_parts:
		parts.append("%s %.1f" % [key, last_refresh_parts[key] / 1000.0])
	return "  last refresh %.1f ms (%s)" % [last_refresh_usec / 1000.0, ", ".join(parts)]


func on_back() -> void:
	if _sandbox != null:
		land()
	elif not _carry.is_empty():
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
				_press_mount = _mount_at(touch.position)
				_press_tile = _tile_at(touch.position) if _press_mount < 0 else -1
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
			if _press_mount >= 0 and _press_mount == _selected_mount:
				_start_move_mount(_press_mount, drag.index, drag.position)
				_touches.erase(drag.index)
				_gesture = &""
			elif _press_tile >= 0 and _press_tile == _selected and _press_tile != editor.core_tile().id:
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


func _start_carry_thruster(type_id: StringName, size: StringName, level: int) -> void:
	_start_carry_part({"part": ThrusterLib.part_id(type_id), "size": String(size), "level": level})


func _start_carry_weapon(weapon_id: StringName, mount_type: StringName, mode: StringName) -> void:
	_start_carry_part({"part": WeaponLib.part_id(weapon_id), "mount": String(mount_type), "mode": String(mode)})


## Carrying a loose part from the Inventory tab (`part` as `stock_drag_started` gives it).
func _start_carry_stock(part: Dictionary) -> void:
	_start_carry_part(part)


## Carrying a new thruster or gun (`part`: its mount without a place) toward a free slot.
func _start_carry_part(part: Dictionary) -> void:
	_select(-1)
	_carry = {"part": part, "moving_mount": -1, "finger": 0, "slots": _slots_for(part, editor.blueprint),
			"target": editor.blueprint}
	_carry_screen = _touch_position_or_mouse(0)
	_carry_dirty = true


func _start_move_mount(index: int, finger: int, screen: Vector2) -> void:
	var mount := editor.blueprint.mounts[index]
	# Slots as if this part (and its mirror twin) weren't there.
	var errors: PackedStringArray = []
	var without := Blueprint.from_dict(editor.blueprint.to_dict(), errors)
	without.mounts.remove_at(index)
	var twin_id := editor.twin_of(int(mount["tile"]))
	if twin_id >= 0:
		var image := Mounting.mirrored(placement, editor.blueprint, mount, twin_id, editor.axis_y())
		without.mounts.assign(without.mounts.filter(func(m: Dictionary) -> bool: return not Mounting.same_place(m, image)))
	var part := mount.duplicate()
	for key in ["tile", "face", "edge", "port"]:
		part.erase(key)
	_carry = {"part": part, "moving_mount": index, "finger": finger, "slots": _slots_for(part, without), "target": without}
	_carry_screen = screen
	_carry_dirty = true


func _slots_for(part: Dictionary, bp: Blueprint) -> Array[Dictionary]:
	if Mounting.is_weapon(part):
		return Mounting.weapon_slots(placement, bp, WeaponLib.type_of_part(str(part["part"])), StringName(part["mount"]))
	return Mounting.thruster_slots(placement, bp, StringName(part["size"]))


func _start_move(tile_id: int, finger: int, screen: Vector2) -> void:
	var tile := editor.blueprint.tile_by_id(tile_id)
	_carry = {"type": tile.type, "shape": tile.shape, "size": tile.size,
			"paint": tile.paint, "moving": tile_id, "finger": finger}
	_rot_pref = tile.rot
	_carry_screen = screen
	_carry_dirty = true


func _process(delta: float) -> void:
	if _notice_left > 0.0:
		_notice_left -= delta
		_notice.modulate.a = clampf(_notice_left / 0.5, 0.0, 1.0)
	if _carry_dirty:
		_carry_dirty = false
		_update_ghost()


func _update_ghost() -> void:
	if _carry.is_empty():
		return
	if _carry.has("part"):
		_update_part_ghost()
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


## A carried thruster or gun snaps to the free slot whose centre is nearest the (lifted) finger.
func _update_part_ghost() -> void:
	var point_u := _camera.screen_to_world(_carry_screen + Vector2(0, -GHOST_LIFT_PX)) / PX
	var target: Blueprint = _carry["target"]
	var part: Dictionary = _carry["part"]
	var centers := PackedVector2Array()
	var best_d := INF
	_mount_slot = {}
	for slot: Dictionary in _carry["slots"]:
		var at := Mounting.anchor(placement, target, Mounting.moved_to(part, slot))
		centers.append(at)
		var d := at.distance_to(point_u)
		if d < best_d and d <= SNAP_REACH_U:
			best_d = d
			_mount_slot = slot
	var ghost: PackedVector2Array
	if not _mount_slot.is_empty():
		ghost = Mounting.outline(placement, target, Mounting.moved_to(part, _mount_slot))
	else:
		ghost = _loose_outline(part, point_u)
	_view.set_part_ghost(ghost, not _mount_slot.is_empty(), centers)


## A carried part's outline off the ship, at `point_u`, edge side up.
func _loose_outline(part: Dictionary, point_u: Vector2) -> PackedVector2Array:
	if Mounting.is_thruster(part):
		var half := placement.shapes.edge_u(StringName(part["size"])) * 0.5
		return Mounting.nozzle({"a": point_u + Vector2(-half, 0), "b": point_u + Vector2(half, 0),
				"normal": Vector2.DOWN, "depth": half * 2.0 * placement.thrusters.depth_factor})
	var gun := placement.weapons.weapon(WeaponLib.type_of_part(str(part["part"])))
	if placement.weapons.mount_type(StringName(part["mount"]))["face"]:
		return Mounting.circle(point_u, gun["turret_radius_u"])
	var half_gun: float = gun["edge_u"] * 0.5
	return Mounting.footprint({"a": point_u + Vector2(-half_gun, 0), "b": point_u + Vector2(half_gun, 0),
			"normal": Vector2.DOWN, "depth": gun["length_u"]})


## The snap whose tile centre is nearest the finger, preferring the player's chosen rotation
## among the variants at that spot. An edge often offers several spots in the same rotation
## (slid along it by a port), so the preferred rotation's nearest one wins, not its first.
func _choose_snap(snaps: Array[Placement.Snap], point_u: Vector2) -> Placement.Snap:
	var best := _nearest_snap(snaps, point_u)
	if best == null or _snap_center(best).distance_to(point_u) > SNAP_REACH_U:
		return null
	if best.rot == _rot_pref:
		return best
	var preferred := _variants(snaps, best).filter(func(s: Placement.Snap) -> bool: return s.rot == _rot_pref)
	var nearest := _nearest_snap(preferred, point_u)
	return nearest if nearest != null else best


func _nearest_snap(snaps: Array, point_u: Vector2) -> Placement.Snap:
	var best: Placement.Snap = null
	var best_d := INF
	for snap: Placement.Snap in snaps:
		var d := _snap_center(snap).distance_to(point_u)
		if d < best_d:
			best_d = d
			best = snap
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
		# Step through the distinct rotations on offer here (several spots can share one).
		var rots: Array[int] = []
		for variant in _variants(snaps, _snap):
			if not rots.has(variant.rot):
				rots.append(variant.rot)
		if rots.size() > 1:
			_rot_pref = rots[(rots.find(_snap.rot) + 1) % rots.size()]
	_update_ghost()


func _commit_carry() -> void:
	if _carry.has("part"):
		var part: Dictionary = _carry["part"]
		if stocked() and _sell_button.get_global_rect().has_point(_carry_screen):
			_sell_carried(part)
		elif stocked() and _carry["moving_mount"] >= 0 and _palette.get_global_rect().has_point(_carry_screen):
			editor.remove_mount(_carry["moving_mount"])  # into the inventory
			_select(-1)
		elif not _mount_slot.is_empty():
			var done: bool
			if _carry["moving_mount"] >= 0:
				done = editor.move_mount(_carry["moving_mount"], _mount_slot)
			elif Mounting.is_weapon(part):
				done = not editor.add_weapon(WeaponLib.type_of_part(str(part["part"])), StringName(part["mount"]),
						StringName(part["mode"]), _mount_slot, str(part.get("gun", ""))).is_empty()
			else:
				done = not editor.add_thruster(ThrusterLib.type_of_part(str(part["part"])), StringName(part["size"]),
						int(part["level"]), _mount_slot, bool(part.get("stock", false))).is_empty()
			if done:
				_select_mount(editor.mount_index(_mount_slot))
		_end_carry()
		return
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


## A part dropped on Sell: one being moved off the ship, or a loose one from the Inventory tab.
## A new one from a shop tab isn't anyone's yet, so nothing happens.
func _sell_carried(part: Dictionary) -> void:
	if _carry["moving_mount"] >= 0:
		editor.sell_mount(_carry["moving_mount"])
		_select(-1)
	elif part.has("gun"):
		editor.sell_gun(str(part["gun"]))
	elif part.get("stock", false):
		editor.sell_thruster(Inventory.key_of(part))


func _end_carry() -> void:
	_carry = {}
	_snap = null
	_mount_slot = {}
	_view.set_ghost(null, false)
	_stats.show_delta(null, &"")


# ── toolbar actions ───────────────────────────────────────────────────────────

## A tap selects the part (thruster or gun) or tile under the finger, or paints the tile while the paint
## panel is open.
func _on_tap(screen: Vector2) -> void:
	var tile_id := _tile_at(screen)
	if not _paint.visible:
		var mount := _mount_at(screen)
		if mount >= 0:
			_select_mount(mount)
		else:
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


func _select_mount(index: int) -> void:
	_select(-1)
	_selected_mount = index
	_view.set_selected_mount(index)
	_refresh_buttons()


func _select(tile_id: int) -> void:
	if _selected_mount >= 0:
		_selected_mount = -1
		_view.set_selected_mount(-1)
	_selected = tile_id
	var ids := PackedInt32Array()
	if tile_id >= 0:
		ids.append(tile_id)
		var twin := editor.twin_of(tile_id)
		if twin >= 0:
			ids.append(twin)
	_view.set_selected(ids)
	_refresh_buttons()


func _sell_selected() -> void:
	if _selected_mount >= 0 and editor.sell_mount(_selected_mount):
		_select(-1)


func _delete_selected() -> void:
	if _selected_mount >= 0:
		editor.remove_mount(_selected_mount)
		_select(-1)
	elif _selected >= 0 and editor.remove(_selected):
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
	if _selected_mount >= editor.blueprint.mounts.size():
		_select(-1)
	elif _selected_mount >= 0:
		_view.set_selected_mount(_selected_mount)
	elif _selected >= 0 and editor.blueprint.tile_by_id(_selected) == null:
		_select(-1)
	else:
		_select(_selected)
	if _status != null:
		_status.text = "%s  ·  %s" % [editor.blueprint.name, "ready to fly" if problems.is_empty() else "can't fly yet"]
		_fly_button.disabled = not problems.is_empty()
		var stats := ShipStats.compute(editor.blueprint, placement)
		var envelope := ThrustEnvelope.compute(editor.blueprint, placement, stats)
		var guns := GunLayout.compute(editor.blueprint, placement, 1, gun_levels())
		_view.set_envelope(envelope, stats.center_of_mass)
		_view.set_guns(guns)
		_stats.show_stats(stats, problems, placement.max_tiles, envelope, guns)
	if stocked():
		_store.inventory = editor.stock
		_store.ship = editor.blueprint
		_store.save()
		_palette.show_stock(editor.stock, editor.blueprint)
		if _wallet != null:
			_show_wallet()
		if not editor.refusal.is_empty():
			_show_notice(editor.refusal)
			editor.refusal = ""
	last_refresh_usec = Time.get_ticks_usec() - started
	last_refresh_parts = {"analyze": analyzed - started, "view": drawn - analyzed,
			"stats": started + last_refresh_usec - drawn}


## The selected part, for the stats panel: "Gatling L3 · 40% to L4 · sells for 60 GC".
func _part_text() -> String:
	if _selected_mount < 0 or _selected_mount >= editor.blueprint.mounts.size():
		return ""
	var mount := editor.blueprint.mounts[_selected_mount]
	var parts: PackedStringArray = []
	if Mounting.is_weapon(mount):
		var gun := placement.weapons.weapon(WeaponLib.type_of_part(str(mount["part"])))
		var item: Inventory.GunItem = editor.stock.guns.get(str(mount.get("gun", ""))) if editor.stock != null else null
		if item == null:
			parts.append(str(gun.get("name", "?")))
		else:
			var xp := placement.weapons.xp
			var level := xp.level_for(item.xp)
			parts.append("%s L%d" % [gun.get("name", "?"), level])
			parts.append("top level" if level >= xp.max_level else "%d%% to L%d" % [floori(xp.progress(item.xp) * 100.0), level + 1])
	elif Mounting.is_thruster(mount):
		parts.append("%s %s L%d" % [placement.thrusters.display_name(ThrusterLib.type_of_part(str(mount["part"]))),
				mount["size"], int(mount["level"])])
	if stocked():
		parts.append("sells for %d GC" % editor.economy.sell_value(Economy.part_price(placement, mount))[Inventory.GC])
	return "  ·  ".join(parts)


## Each fitted inventory gun's level (item id -> level); empty in Creative.
func gun_levels() -> Dictionary:
	var out := {}
	if editor.stock != null:
		for id: String in editor.stock.guns:
			out[id] = placement.weapons.xp.level_for((editor.stock.guns[id] as Inventory.GunItem).xp)
	return out


func _show_wallet() -> void:
	var parts: PackedStringArray = []
	for material in Inventory.MATERIALS:
		parts.append("%s %d" % [String(material).capitalize(), editor.stock.amount(material)])
	parts.append("%d GC" % editor.stock.amount(Inventory.GC))
	_wallet.text = "  ·  ".join(parts)


func _show_notice(text: String) -> void:
	_notice.text = text
	_notice_left = NOTICE_S
	_notice.modulate.a = 1.0


func _refresh_buttons() -> void:
	if _undo_button == null:
		return
	if _sell_button != null:
		_sell_button.disabled = _selected_mount < 0
	_stats.show_part(_part_text())
	_undo_button.disabled = not editor.can_undo()
	_redo_button.disabled = not editor.can_redo()
	var mount := editor.blueprint.mounts[_selected_mount] if _selected_mount >= 0 \
			and _selected_mount < editor.blueprint.mounts.size() else {}
	var gun := Mounting.is_weapon(mount)
	_rotate_button.visible = not gun
	_duplicate_button.visible = not gun
	_mode_button.visible = gun
	_mode_button.text = "Mode: Manual" if gun and mount.get("mode") == "manual" else "Mode: Auto"
	_mode_button.disabled = not gun or placement.weapons.mount_type(StringName(mount.get("mount", ""))) \
			.get("modes", []).size() < 2


## Flips the selected gun between manual and auto (turrets are always auto).
func _toggle_selected_mode() -> void:
	if _selected_mount < 0 or _selected_mount >= editor.blueprint.mounts.size():
		return
	var mode := StringName(editor.blueprint.mounts[_selected_mount].get("mode", ""))
	editor.set_mount_mode(_selected_mount, &"auto" if mode == &"manual" else &"manual")


## The part whose outline is under the finger (with some slack, as a Small one is tiny), or -1.
func _mount_at(screen: Vector2) -> int:
	var point_u := _camera.screen_to_world(screen) / PX
	var slack_u := TAP_SLOP_PX / PX / _camera.zoom.x
	for i in range(editor.blueprint.mounts.size() - 1, -1, -1):
		var shape := Mounting.outline(placement, editor.blueprint, editor.blueprint.mounts[i])
		if shape.is_empty():
			continue
		if Geometry2D.is_point_in_polygon(point_u, shape) or ShipStats.polygon_centroid(shape).distance_to(point_u) <= slack_u:
			return i
	return -1


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
	_ui = CanvasLayer.new()
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)

	_palette = HangarPalette.new()
	_palette.shapes = placement.shapes
	_palette.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_palette.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_palette.drag_started.connect(_start_carry_new)
	_palette.thrusters = placement.thrusters
	_palette.thruster_drag_started.connect(_start_carry_thruster)
	_palette.weapons = placement.weapons
	_palette.weapon_drag_started.connect(_start_carry_weapon)
	_palette.stock = editor.stock
	_palette.ship = editor.blueprint
	_palette.stock_drag_started.connect(_start_carry_stock)
	root.add_child(_palette)

	var tools := VBoxContainer.new()
	tools.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tools.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tools.position = Vector2(-16, 16)
	root.add_child(tools)
	_undo_button = _tool_button(tools, "Undo", func() -> void: editor.undo())
	_redo_button = _tool_button(tools, "Redo", func() -> void: editor.redo())
	_rotate_button = _tool_button(tools, "Rotate", _rotate_selected)
	_duplicate_button = _tool_button(tools, "Duplicate", _duplicate_selected)
	# Shown in place of Rotate and Duplicate while a gun is selected; the column is full.
	_mode_button = _tool_button(tools, "Mode: Auto", _toggle_selected_mode)
	_mode_button.visible = false
	# Outside Creative a removed tile is refunded and a removed part goes in the inventory.
	_tool_button(tools, "Remove" if stocked() else "Delete", _delete_selected)
	if stocked():
		_sell_button = _tool_button(tools, "Sell", _sell_selected)
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

	# The stocked hangar builds the profile's own ship; buying library ships comes with shops (7.3).
	_tool_button(tools, "Ships", _open_library.bind(true)).visible = not stocked()

	_wallet = Label.new()
	_wallet.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_wallet.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_wallet.position.y = 12
	_wallet.add_theme_font_size_override(&"font_size", 18)
	_wallet.add_theme_color_override(&"font_color", Color(1, 0.85, 0.5))
	_wallet.visible = stocked()
	root.add_child(_wallet)
	_notice = Label.new()
	_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_notice.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_notice.position.y = 40
	_notice.add_theme_font_size_override(&"font_size", 20)
	_notice.add_theme_color_override(&"font_color", Color(1.0, 0.45, 0.45))
	_notice.modulate.a = 0.0
	root.add_child(_notice)
	if stocked():
		_show_wallet()
	_fly_button = _tool_button(tools, "Fly", func() -> void: fly())
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
##   --tab=<name>          open a palette tab (e.g. weapons)
##   --mount=<index>       select a mount
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
	if args.has("mount"):
		_select_mount(int(args["mount"]))
	if args.has("tab"):
		for button in _palette.find_children("*", "Button", true, false):
			if (button as Button).text.to_lower() == String(args["tab"]).to_lower():
				(button as Button).button_pressed = true
	if args.has("ghost"):
		var parts: PackedStringArray = (args["ghost"] as String).split(",")
		_carry = {"type": _palette.type, "shape": StringName(parts[0]), "size": StringName(parts[1]),
				"paint": HangarEditor.DEFAULT_PAINT, "moving": -1, "finger": 0}
		_carry_screen = Vector2(float(parts[2]), float(parts[3]))
		_update_ghost()

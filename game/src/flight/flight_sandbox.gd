class_name FlightSandbox
extends Node
## Test-flying the ship being built (Phase 3; M1 is "build → Fly → back").
##
## Opened by the hangar on top of itself rather than as a scene change, so the hangar keeps
## its undo history and unsaved edits. Phase 3.1: the ship spawns as a physics body, and
## tapping it highlights the tile the physics query hit (the hit → tile table, checkable on
## the phone). Controls arrive in 3.3–3.4, the starfield and follow camera in 3.5.

signal closed

const PX := ShipMesh.PX_PER_U

var ship: ShipBody
## How long building the ship body took, for the debug Perf log.
var last_spawn_usec: int = 0

var _camera := Camera2D.new()
var _status := Label.new()
var _picked := -1
var _overlay := Node2D.new()


## Spawns `bp` (already validated) at the origin.
func open(bp: Blueprint, placement: Placement) -> void:
	var world := Node2D.new()
	world.name = "World"
	add_child(world)
	var backdrop := _Backdrop.new()
	world.add_child(backdrop)

	var started := Time.get_ticks_usec()
	ship = ShipBody.create(bp, placement)
	last_spawn_usec = Time.get_ticks_usec() - started
	world.add_child(ship)
	_overlay.draw.connect(_draw_pick)
	ship.add_child(_overlay)

	_camera.zoom = Vector2.ONE * _fit_zoom(bp, placement)
	world.add_child(_camera)
	_camera.make_current()
	_build_ui()
	_show_status()


func perf_note() -> String:
	return "  ship spawn %.1f ms (%d tiles)" % [last_spawn_usec / 1000.0, ship.blueprint.tiles.size() if ship else 0]


func close() -> void:
	closed.emit()


func _process(_delta: float) -> void:
	if ship:
		_camera.position = ship.global_position


func _unhandled_input(event: InputEvent) -> void:
	var tapped := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
			or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if not tapped:
		return
	var world_point: Vector2 = _camera.get_canvas_transform().affine_inverse() * (event as InputEventFromWindow).position
	_picked = tile_at_point(world_point)
	_overlay.queue_redraw()
	_show_status()


## The tile under a world point, found the way a bullet will find it: a physics query, then
## the body's shape index → tile id table.
func tile_at_point(world_point: Vector2) -> int:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_point
	for hit in ship.get_world_2d().direct_space_state.intersect_point(query, 8):
		if hit["collider"] == ship:
			return ship.tile_at_shape(hit["shape"])
	return -1


func _draw_pick() -> void:
	if _picked < 0:
		return
	var tile := ship.blueprint.tile_by_id(_picked)
	if tile == null:
		return
	var outline := PackedVector2Array()
	for p in ship.placement.tile_polygon(tile):
		outline.append(p * PX)
	outline.append(outline[0])
	_overlay.draw_polyline(outline, Color(1.0, 0.85, 0.2), 3.0, true)


func _show_status() -> void:
	var text := "%s  ·  mass %.1f  ·  %d tiles" % [ship.blueprint.name, ship.mass, ship.get_shape_owners().size()]
	if _picked >= 0:
		var tile := ship.blueprint.tile_by_id(_picked)
		text += "  ·  hit tile %d (%s)" % [_picked, tile.type]
	else:
		text += "  ·  tap the ship to test hits"
	_status.text = text


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	_status.position = Vector2(16, 12)
	_status.add_theme_font_size_override(&"font_size", 20)
	ui.add_child(_status)
	var back := Button.new()
	back.text = "Hangar"
	back.size = Vector2(132, 56)
	back.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 16)
	back.pressed.connect(close)
	ui.add_child(back)


## Zoom that shows the whole ship at about a third of the screen height.
func _fit_zoom(bp: Blueprint, placement: Placement) -> float:
	var bounds := Rect2()
	for tile in bp.tiles:
		for p in placement.tile_polygon(tile):
			bounds = bounds.expand(p)  # starts at the origin, which the core always covers
	var extent := maxf(maxf(bounds.size.x, bounds.size.y), 1.0) * PX
	return clampf(240.0 / extent, 0.25, 3.0)


## A plain reference grid so the ship has something to move against until 3.5's starfield.
class _Backdrop extends Node2D:
	const STEP := 256.0
	const REACH := 40

	func _draw() -> void:
		var color := Color(0.25, 0.3, 0.4, 0.35)
		for i in range(-REACH, REACH + 1):
			draw_line(Vector2(i * STEP, -REACH * STEP), Vector2(i * STEP, REACH * STEP), color, 1.0)
			draw_line(Vector2(-REACH * STEP, i * STEP), Vector2(REACH * STEP, i * STEP), color, 1.0)

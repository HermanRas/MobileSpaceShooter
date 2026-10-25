class_name FlightSandbox
extends Node
## Test-flying the ship being built (Phase 3; M1 is "build → Fly → back").
##
## Opened by the hangar on top of itself rather than as a scene change, so the hangar keeps
## its undo history and unsaved edits. The ship spawns as a physics body flown by a
## FlightController (3.3) from the FlightControls (3.4: stick, FIRE, SWITCH, laid out from
## Settings; WASD/arrows/gamepad too). Tapping the ship highlights the tile a physics query hit
## (the 3.1 check). A FollowCamera and a parallax Starfield (3.5); the Arena warns near its edge
## and pushes the ship back in past it.

signal closed

const PX := ShipMesh.PX_PER_U

var ship: ShipBody
var pilot: FlightController
## How long building the ship body took, for the debug Perf log.
var last_spawn_usec: int = 0

var arena: Arena

var _camera := FollowCamera.new()
var _arena_view := _ArenaView.new()
var _edge_glow := _EdgeGlow.new()
var _status := Label.new()
var _picked := -1
var _overlay := Node2D.new()
var controls := FlightControls.new()
var _hud := Label.new()
var _controls_panel: ControlsPanel
## A short message under the HUD (e.g. SWITCH before there are weapons), and when it fades.
var _note := ""
var _note_until := 0


## Spawns `bp` (already validated) at the origin.
func open(bp: Blueprint, placement: Placement) -> void:
	var flight: Dictionary = Data.table(&"flight")
	arena = Arena.from_table(flight.get("arena", {}))
	var world := Node2D.new()
	world.name = "World"
	add_child(world)
	_arena_view.arena = arena
	world.add_child(_arena_view)

	var started := Time.get_ticks_usec()
	ship = ShipBody.create(bp, placement)
	last_spawn_usec = Time.get_ticks_usec() - started
	world.add_child(ship)
	pilot = FlightController.new()
	pilot.name = "Pilot"
	ship.add_child(pilot)
	pilot.attach(ship, flight)
	_overlay.draw.connect(_draw_pick)
	ship.add_child(_overlay)

	world.add_child(_camera)
	_camera.configure(flight.get("camera", {}), ship, _extent_u(bp, placement))
	_camera.make_current()
	var stars := Starfield.new()
	stars.camera = _camera
	add_child(stars)
	_build_ui()
	_show_status()


func perf_note() -> String:
	return "  ship spawn %.1f ms (%d tiles)" % [last_spawn_usec / 1000.0, ship.blueprint.tiles.size() if ship else 0]


func close() -> void:
	closed.emit()


func _process(_delta: float) -> void:
	if ship == null:
		return
	pilot.stick = controls.stick_value()
	var warning := arena.warning(ship.global_position / PX)
	_edge_glow.strength = warning
	var parts: PackedStringArray = ["%.1f U/s" % (ship.linear_velocity.length() / PX)]
	if pilot.braking and ship.linear_velocity.length() > 1.0:
		parts.append("braking")
	if controls.is_firing():
		parts.append("FIRE (weapons arrive in Phase 4)")
	if warning > 0.0:
		parts.append("leaving the area" if arena.contains(ship.global_position / PX) else "outside the area: turning you back")
	if Time.get_ticks_msec() < _note_until:
		parts.append(_note)
	_hud.text = "  ·  ".join(parts)


func _physics_process(_delta: float) -> void:
	if ship != null:
		# The sandbox's soft wall. Story mode opens the world map at the edge instead (4.10).
		ship.apply_central_force(arena.push(ship.global_position / PX) * ship.mass * PX)


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
	# First, so the labels and buttons added after it sit on top.
	controls.name = "Controls"
	controls.switch_pressed.connect(func() -> void:
		_note = "SWITCH: no manual weapons yet"
		_note_until = Time.get_ticks_msec() + 2000)
	ui.add_child(controls)
	_edge_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_edge_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_edge_glow)
	_status.position = Vector2(16, 12)
	_status.add_theme_font_size_override(&"font_size", 20)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_status)
	_hud.position = Vector2(16, 44)
	_hud.add_theme_font_size_override(&"font_size", 20)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_hud)
	var back := Button.new()
	back.text = "Hangar"
	back.size = Vector2(132, 56)
	back.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 16)
	back.pressed.connect(close)
	ui.add_child(back)
	var settings := Button.new()
	settings.text = "Controls"
	settings.size = Vector2(132, 56)
	settings.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 16)
	settings.position.y += 64
	settings.pressed.connect(_open_controls_panel.bind(true))
	ui.add_child(settings)
	_controls_panel = ControlsPanel.new()
	_controls_panel.visible = false
	_controls_panel.closed.connect(_open_controls_panel.bind(false))
	ui.add_child(_controls_panel)


func _open_controls_panel(open: bool) -> void:
	_controls_panel.visible = open
	if open:
		_controls_panel.refresh()
		_controls_panel.reset_size()
		_controls_panel.position = (_controls_panel.get_viewport_rect().size - _controls_panel.size) * 0.5


## The ship's longest side, in U, for the camera's resting zoom.
func _extent_u(bp: Blueprint, placement: Placement) -> float:
	var bounds := Rect2()
	for tile in bp.tiles:
		for p in placement.tile_polygon(tile):
			bounds = bounds.expand(p)  # starts at the origin, which the core always covers
	return maxf(bounds.size.x, bounds.size.y)


## The arena's edge in the world: a red line, drawn the same width on screen at any zoom.
class _ArenaView extends Node2D:
	var arena: Arena

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if arena == null:
			return
		var camera := get_viewport().get_camera_2d()
		var width := 3.0 / (camera.zoom.x if camera != null else 1.0)
		var half := arena.half_size_u * ShipMesh.PX_PER_U
		draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), Color(1.0, 0.3, 0.25, 0.7), false, width)


## A red glow around the screen's edge that strengthens as the ship nears the arena's edge.
class _EdgeGlow extends Control:
	const BANDS := 8
	const DEPTH := 90.0

	var strength := 0.0:
		set(value):
			if not is_equal_approx(value, strength):
				strength = value
				queue_redraw()

	func _draw() -> void:
		if strength <= 0.0:
			return
		for i in BANDS:
			var inset := DEPTH * i / BANDS
			var alpha := strength * 0.45 * (1.0 - float(i) / BANDS)
			draw_rect(Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0), Color(1.0, 0.2, 0.15, alpha),
					false, DEPTH / BANDS)

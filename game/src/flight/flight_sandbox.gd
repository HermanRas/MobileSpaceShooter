class_name FlightSandbox
extends Node
## Test-flying the ship being built (Phase 3; M1 is "build → Fly → back").
##
## Opened by the hangar on top of itself rather than as a scene change, so the hangar keeps
## its undo history and unsaved edits. The ship spawns as a physics body flown by a
## FlightController (3.3) from the FlightControls (3.4: stick, FIRE, SWITCH, laid out from
## Settings; WASD/arrows/gamepad too). Tapping the ship highlights the tile a physics query hit
## (the 3.1 check). The starfield and follow camera come in 3.5.

signal closed

const PX := ShipMesh.PX_PER_U

var ship: ShipBody
var pilot: FlightController
## How long building the ship body took, for the debug Perf log.
var last_spawn_usec: int = 0

var _camera := Camera2D.new()
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
	var world := Node2D.new()
	world.name = "World"
	add_child(world)
	var backdrop := _Backdrop.new()
	world.add_child(backdrop)

	var started := Time.get_ticks_usec()
	ship = ShipBody.create(bp, placement)
	last_spawn_usec = Time.get_ticks_usec() - started
	world.add_child(ship)
	pilot = FlightController.new()
	pilot.name = "Pilot"
	ship.add_child(pilot)
	pilot.attach(ship, Data.table(&"flight"))
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
	if ship == null:
		return
	pilot.stick = controls.stick_value()
	_camera.position = ship.global_position
	var parts: PackedStringArray = ["%.1f U/s" % (ship.linear_velocity.length() / PX)]
	if pilot.braking and ship.linear_velocity.length() > 1.0:
		parts.append("braking")
	if controls.is_firing():
		parts.append("FIRE (weapons arrive in Phase 4)")
	if Time.get_ticks_msec() < _note_until:
		parts.append(_note)
	_hud.text = "  ·  ".join(parts)


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

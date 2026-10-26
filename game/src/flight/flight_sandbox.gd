class_name FlightSandbox
extends Node
## Test-flying the ship being built (Phase 3; M1 is "build → Fly → back").
##
## Opened by the hangar on top of itself rather than as a scene change, so the hangar keeps
## its undo history and unsaved edits. The ship spawns as a physics body flown by a
## FlightController (3.3) from the FlightControls (3.4: stick, FIRE, SWITCH, laid out from
## Settings; WASD/arrows/gamepad too). A FollowCamera and a parallax Starfield (3.5); the Arena
## warns near its edge and pushes the ship back in past it.
##
## Damage (4.2): a practice target is parked ahead. Ships lose tiles, break apart and blow up;
## a destroyed ship comes back after a few seconds. Tapping a tile highlights it (and hits it for
## `test_hit`, if data sets one).
##
## Guns (4.3): the ship's WeaponController fires into one ProjectilePool. Auto guns pick off the
## target on their own; FIRE fires the manual ones (in 1-stick, every gun is auto).

signal closed

const PX := ShipMesh.PX_PER_U

var ship: ShipBody
var pilot: FlightController
var weapons: WeaponController
## Every shot in flight.
var pool := ProjectilePool.new()
## How long building the ship body took, for the debug Perf log.
var last_spawn_usec: int = 0

var arena: Arena
## The practice target, or null while it's respawning.
var target: ShipBody
var damage_table: DamageTable
## Raw damage a tap deals (from data; 0 makes taps only pick).
var test_hit := 60.0

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
var _world := Node2D.new()
var _bp: Blueprint
var _placement: Placement
var _flight: Dictionary
var _sandbox: Dictionary
## Which ship _picked is on.
var _picked_ship: ShipBody
var _last_hit := ""


## Spawns `bp` (already validated) at the origin, and the practice target ahead of it.
func open(bp: Blueprint, placement: Placement) -> void:
	_bp = bp
	_placement = placement
	_flight = Data.table(&"flight")
	_sandbox = _flight.get("sandbox", {})
	arena = Arena.from_table(_flight.get("arena", {}))
	damage_table = DamageTable.from_table(Data.table(&"damage_types"))
	test_hit = float(_sandbox.get("test_hit", test_hit))
	_world.name = "World"
	add_child(_world)
	_arena_view.arena = arena
	_world.add_child(_arena_view)
	_overlay.draw.connect(_draw_pick)
	_overlay.z_index = 2
	_world.add_child(_overlay)
	_world.add_child(_camera)
	pool.name = "Shots"
	pool.z_index = 2
	_world.add_child(pool)
	_spawn_player()
	_camera.make_current()
	_spawn_target()
	var stars := Starfield.new()
	stars.camera = _camera
	add_child(stars)
	_build_ui()
	_show_status()


func _spawn_player() -> void:
	var started := Time.get_ticks_usec()
	ship = ShipBody.create(_bp, _placement)
	last_spawn_usec = Time.get_ticks_usec() - started
	ship.enable_damage(damage_table)
	_world.add_child(ship)
	pilot = FlightController.new()
	pilot.name = "Pilot"
	ship.add_child(pilot)
	pilot.attach(ship, _flight)
	var exhaust := ThrusterFxSet.new()
	exhaust.name = "Exhaust"
	ship.add_child(exhaust)
	exhaust.attach(ship, pilot)
	weapons = WeaponController.new()
	weapons.name = "Weapons"
	ship.add_child(weapons)
	weapons.attach(ship, pool, _placement.weapons, func() -> Array: return [target] if target != null else [])
	var guns := GunView.new()
	guns.name = "Guns"
	ship.add_child(guns)
	guns.attach(weapons)
	ship.rebuilt.connect(_show_status)
	ship.destroyed.connect(_on_player_destroyed)
	_camera.configure(_flight.get("camera", {}), ship, _extent_u(_bp, _placement))


func _spawn_target() -> void:
	var errors: PackedStringArray = []
	var raw: Dictionary = Data.json_dir("enemies").get(str(_sandbox.get("target", "")), {})
	var bp := Blueprint.from_dict(raw, errors) if not raw.is_empty() else null
	if bp == null:
		push_warning("sandbox: no target blueprint %s" % [errors])
		return
	target = ShipBody.create(bp, _placement)
	target.name = "Target"
	target.team = 1
	var at: Array = _sandbox.get("target_at_u", [10, 0])
	target.position = Vector2(float(at[0]), float(at[1])) * PX
	target.rotation = deg_to_rad(float(_sandbox.get("target_rotation_deg", 0.0)))
	target.enable_damage(damage_table)
	target.linear_damp = 0.3
	target.angular_damp = 0.3
	target.rebuilt.connect(_show_status)
	target.destroyed.connect(func() -> void:
		target = null
		_clear_pick()
		_after_respawn_delay(_spawn_target))
	_world.add_child(target)


func _on_player_destroyed() -> void:
	ship = null
	pilot = null
	weapons = null
	_clear_pick()
	_note = "destroyed"
	_note_until = Time.get_ticks_msec() + int(float(_sandbox.get("respawn_s", 3.0)) * 1000.0)
	_after_respawn_delay(func() -> void:
		_spawn_player()
		_show_status())


func _after_respawn_delay(then: Callable) -> void:
	get_tree().create_timer(float(_sandbox.get("respawn_s", 3.0))).timeout.connect(then)


func perf_note() -> String:
	return "  ship spawn %.1f ms (%d tiles)" % [last_spawn_usec / 1000.0, ship.blueprint.tiles.size() if ship else 0]


func close() -> void:
	closed.emit()


func _process(_delta: float) -> void:
	if ship == null:
		_hud.text = _note
		return
	pilot.stick = controls.stick_value()
	weapons.fire_held = controls.is_firing()
	weapons.all_auto = Settings.get_value(&"control_scheme") != "2-stick"
	if _picked >= 0:
		_overlay.queue_redraw()  # the highlight follows its ship
	var warning := arena.warning(ship.global_position / PX)
	_edge_glow.strength = warning
	var parts: PackedStringArray = ["%.1f U/s" % (ship.linear_velocity.length() / PX)]
	if ship.damage.shield_cap > 0.0:
		parts.append("shield %d/%d" % [roundi(ship.damage.shield), roundi(ship.damage.shield_cap)])
	if ship.damage.is_disabled():
		parts.append("EMP: thrusters out")
	if pilot.braking and ship.linear_velocity.length() > 1.0:
		parts.append("braking")
	if controls.is_firing():
		parts.append("FIRE" if weapons.all_auto or ship.guns.manual_count() > 0 else "FIRE: no manual guns")
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
	# Touches only: a mouse click arrives as a touch too (emulate_touch_from_mouse), and taking
	# both would hit twice.
	if not (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
		return
	var world_point: Vector2 = _camera.get_canvas_transform().affine_inverse() * (event as InputEventFromWindow).position
	var hit := ship_tile_at_point(world_point)
	_picked_ship = hit[0]
	_picked = hit[1]
	if _picked_ship != null and test_hit > 0.0:
		_test_hit(_picked_ship, _picked)
	_overlay.queue_redraw()
	_show_status()


## The tile of the player's ship under a world point, or -1.
func tile_at_point(world_point: Vector2) -> int:
	var hit := ship_tile_at_point(world_point)
	return hit[1] if hit[0] == ship else -1


## [ship, tile id] under a world point, found the way a bullet will find it: a physics query,
## then the body's shape index → tile id table. [null, -1] if it's open space or a wreck.
func ship_tile_at_point(world_point: Vector2) -> Array:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_point
	for hit in _world.get_world_2d().direct_space_state.intersect_point(query, 8):
		var body := hit["collider"] as ShipBody
		if body != null and not body.is_wreck():
			return [body, body.tile_at_shape(hit["shape"])]
	return [null, -1]


## The sandbox's stand-in for a gun (until 4.3): `test_hit` raw damage on a tapped tile.
func _test_hit(body: ShipBody, tile_id: int) -> void:
	var tile := body.blueprint.tile_by_id(tile_id)
	var kind := StringName(_sandbox.get("test_hit_type", "kinetic"))
	var result := body.take_hit(tile_id, test_hit, kind)
	if not is_instance_valid(body) or body.damage.dead:
		_last_hit = "%s destroyed" % body.blueprint.name
		_clear_pick()
		return
	var parts: PackedStringArray = ["hit %s %d" % [tile.type, tile_id]]
	if result.shield > 0.0:
		parts.append("shield -%d (%d left)" % [roundi(result.shield), roundi(body.damage.shield)])
	if body.damage.is_destroyed(tile_id):
		parts.append("destroyed")
		_clear_pick()
	else:
		parts.append("%d/%d HP" % [roundi(body.damage.hp[tile_id]), roundi(body.damage.max_hp[tile_id])])
	_last_hit = ", ".join(parts)


func _clear_pick() -> void:
	_picked = -1
	_picked_ship = null
	_overlay.queue_redraw()


func _draw_pick() -> void:
	if _picked < 0 or not is_instance_valid(_picked_ship):
		return
	var tile := _picked_ship.blueprint.tile_by_id(_picked)
	if tile == null:
		return
	var outline := PackedVector2Array()
	for p in _picked_ship.placement.tile_polygon(tile):
		outline.append(_picked_ship.global_transform * (p * PX))
	outline.append(outline[0])
	_overlay.draw_polyline(outline, Color(1.0, 0.85, 0.2), 3.0, true)


func _show_status() -> void:
	if ship == null:
		_status.text = "respawning…"
		return
	var text := "%s  ·  mass %.1f  ·  %d tiles  ·  %d guns" % [ship.blueprint.name, ship.mass,
			ship.get_shape_owners().size(), ship.guns.guns.size()]
	if _last_hit != "":
		text += "  ·  " + _last_hit
	_status.text = text


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	# First, so the labels and buttons added after it sit on top.
	controls.name = "Controls"
	controls.switch_pressed.connect(func() -> void:
		_note = "SWITCH arrives in Phase 4.7"
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

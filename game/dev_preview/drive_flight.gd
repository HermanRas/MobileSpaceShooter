extends Node
## Phase 3.1, end to end: hangar → Fly → the ship is a physics body you can hit → back.
## Run with `tools/drive.sh res://dev_preview/drive_flight.tscn`. Exit code 0 = every step passed.

const ScriptErrorSpy := preload("res://dev_preview/script_error_spy.gd")
const PX := ShipMesh.PX_PER_U

var _hangar: Node
var _failures: PackedStringArray = []
var _spy := ScriptErrorSpy.new()


func _ready() -> void:
	OS.add_logger(_spy)
	_hangar = (load("res://scenes/hangar/hangar.tscn") as PackedScene).instantiate()
	add_child(_hangar)
	await _frames(5)
	var errors: PackedStringArray = []
	_hangar.load_blueprint(Blueprint.from_dict(Data.json_dir("blueprints")["hexwing"], errors))
	_hangar.editor.paint_all(Color("#c0392b"))  # an edit, so there's undo history to keep
	await _frames(2)
	var before := JSON.stringify(_hangar.editor.blueprint.to_dict())

	var sandbox: FlightSandbox = _hangar.fly()
	_check(sandbox != null, "Fly opens the sandbox")
	if sandbox == null:
		_finish()
		return
	await _physics_frames(3)
	await _frames(3)
	var ship := sandbox.ship
	_check(ship.is_inside_tree() and ship.get_shape_owners().size() == ship.blueprint.tiles.size(),
			"the ship is in the world with one shape per tile")
	print("drive_flight: spawn %.1f ms for %d tiles" % [sandbox.last_spawn_usec / 1000.0, ship.blueprint.tiles.size()])

	await _step_taps_pick_the_right_tile(sandbox)
	await _step_rays_hit_every_tile(ship)
	sandbox._picked = -1  # the pick highlight is drawn separately; count the ship alone
	sandbox._overlay.queue_redraw()
	await _step_one_draw_call(ship)
	_save_shot("drive_flight.png")
	await _step_ships_collide(sandbox)

	_hangar.on_back()
	await _frames(3)
	_check(_hangar.get_node_or_null(^"FlightSandbox") == null, "back closes the sandbox")
	_check(JSON.stringify(_hangar.editor.blueprint.to_dict()) == before, "the hangar's ship is untouched")
	_check(_hangar.editor.can_undo(), "the undo history survived the flight")
	_check(_hangar._world.visible and _hangar._ui.visible, "the hangar is visible again")

	await _step_fly_the_starter_with_the_stick()
	await _step_control_layouts()
	await _step_camera_and_arena()
	_finish()


## Phase 3.5: the camera leads and zooms out at speed; the arena warns and pushes back.
func _step_camera_and_arena() -> void:
	var errors: PackedStringArray = []
	_hangar.load_blueprint(Blueprint.from_dict(Data.json_dir("blueprints")["starter"], errors))
	await _frames(2)
	var sandbox: FlightSandbox = _hangar.fly()
	await _frames(3)
	var ship := sandbox.ship
	var camera := get_viewport().get_camera_2d()
	var rest_zoom := camera.zoom.x
	var base := Vector2(300, 400)
	_touch_at(0, base, true)
	await _frames(1)
	_drag_to(0, base + Vector2(110, 0))
	await _physics_frames(150)
	var lead := camera.get_screen_center_position() - ship.global_position
	_check(lead.x > 20.0, "the camera leads the ship along its velocity (%.0f px ahead)" % lead.x)
	_check(camera.zoom.x < rest_zoom * 0.95, "and zooms out at speed (%.2f -> %.2f)" % [rest_zoom, camera.zoom.x])
	_save_shot("drive_flight_space.png")
	_touch_at(0, base + Vector2(110, 0), false)
	await _physics_frames(30)

	var half := sandbox.arena.half_size_u * PX
	_teleport(ship, Vector2(half - 5.0 * PX, 0))
	await _physics_frames(2)
	await _frames(2)
	_check(sandbox._edge_glow.strength > 0.5 and "leaving" in sandbox._hud.text,
			"near the edge: the glow (%.2f) and the warning (%s)" % [sandbox._edge_glow.strength, sandbox._hud.text])
	_save_shot("drive_flight_edge.png")
	_teleport(ship, Vector2(half + 10.0 * PX, 0))
	await _physics_frames(2)
	_check((ship.global_position.x - half) / PX > 9.0, "teleported past the edge")
	await _physics_frames(180)
	var depth := (ship.global_position.x - half) / PX
	_check(depth < 8.0, "past the edge it's pushed back in (10 U out -> %.1f U)" % depth)
	_hangar.land()
	await _frames(2)


## Phase 3.4: stick + FIRE with two fingers at once, the 1-stick scheme, and the left-handed
## mirror. The player's own settings are put back afterwards.
func _step_control_layouts() -> void:
	var saved := {}
	for key: StringName in [&"control_scheme", &"left_handed", &"stick_size", &"stick_opacity"]:
		saved[key] = Settings.get_value(key)
	Settings.set_value(&"control_scheme", "2-stick")
	Settings.set_value(&"left_handed", false)
	var errors: PackedStringArray = []
	_hangar.load_blueprint(Blueprint.from_dict(Data.json_dir("blueprints")["starter"], errors))
	await _frames(2)
	var sandbox: FlightSandbox = _hangar.fly()
	await _frames(3)
	var controls := sandbox.controls

	var stick_at := Vector2(300, 400)
	var fire_at := controls.fire.get_global_rect().get_center()
	_touch_at(0, stick_at, true)
	await _frames(1)
	_drag_to(0, stick_at + Vector2(80, 0))
	_touch_at(1, fire_at, true)
	await _frames(2)
	_check(controls.is_firing() and controls.stick_value().x > 0.5,
			"two fingers: stick (%.2f) and FIRE (%s) at once" % [controls.stick_value().x, controls.is_firing()])
	_save_shot("drive_flight_controls.png")
	_touch_at(1, fire_at, false)
	_touch_at(0, stick_at + Vector2(80, 0), false)
	await _frames(2)
	_check(not controls.is_firing() and controls.stick_value() == Vector2.ZERO, "both let go")

	Settings.set_value(&"control_scheme", "1-stick")
	await _frames(2)
	_check(not controls.fire.visible and not controls.switch_button.visible, "1-stick hides FIRE and SWITCH")

	Settings.set_value(&"left_handed", true)
	await _frames(2)
	_touch_at(0, Vector2(300, 400), true)
	await _frames(1)
	_drag_to(0, Vector2(380, 400))
	await _frames(1)
	var left_side := controls.stick_value()
	_touch_at(0, Vector2(380, 400), false)
	var right := Vector2(get_viewport().get_visible_rect().size.x - 300, 400)
	_touch_at(0, right, true)
	await _frames(1)
	_drag_to(0, right + Vector2(80, 0))
	await _frames(1)
	_check(left_side == Vector2.ZERO and controls.stick_value().x > 0.5,
			"left-handed: the stick lives on the right (left %s, right %s)" % [left_side, controls.stick_value()])
	_touch_at(0, right + Vector2(80, 0), false)
	await _frames(1)

	sandbox._open_controls_panel(true)
	await _frames(3)
	_save_shot("drive_flight_controls_panel.png")
	sandbox._open_controls_panel(false)
	for key: StringName in saved:
		Settings.set_value(key, saved[key])
	_hangar.land()
	await _frames(2)


## Phase 3.3/3.4: real touches on the stick fly the starter, through the real physics.
func _step_fly_the_starter_with_the_stick() -> void:
	var errors: PackedStringArray = []
	_hangar.load_blueprint(Blueprint.from_dict(Data.json_dir("blueprints")["starter"], errors))
	await _frames(2)
	var sandbox: FlightSandbox = _hangar.fly()
	await _physics_frames(2)
	var ship := sandbox.ship
	var base := Vector2(300, 400)

	_touch_at(1, base, true)
	await _frames(1)
	_drag_to(1, base + Vector2(110, 0))  # full right: forward
	await _physics_frames(90)
	var speed := ship.linear_velocity.length() / PX
	_check(ship.linear_velocity.x > 0.0 and speed > 2.0, "stick forward: it accelerates (%.2f U/s)" % speed)
	_check(absf(ship.rotation) < 0.1, "and flies straight (heading %.3f)" % ship.rotation)

	_drag_to(1, base + Vector2(0, -110))  # full up: a quarter turn left
	await _physics_frames(240)
	_check(absf(wrapf(ship.rotation + PI * 0.5, -PI, PI)) < 0.2,
			"stick up: it turns left to face up (heading %.2f)" % ship.rotation)
	# Three frames after a pulse kick, so the shot shows the exhaust.
	var kicked := [false]
	sandbox.pilot.kicked.connect(func(_i: int, _t: float) -> void: kicked[0] = true)
	while not kicked[0]:
		await _frames(1)
	await _frames(6)
	_save_shot("drive_flight_flying.png")

	_touch_at(1, base + Vector2(0, -110), false)
	var peak := ship.linear_velocity.length()
	await _physics_frames(60 * 8)
	_check(ship.linear_velocity.length() < peak * 0.1,
			"let go: it brakes (%.2f -> %.2f U/s)" % [peak / PX, ship.linear_velocity.length() / PX])
	_check(absf(ship.angular_velocity) < 0.1, "and stops turning (%.3f rad/s)" % ship.angular_velocity)
	_hangar.land()
	await _frames(2)


## Moves a rigid body through the physics server; setting global_position on an awake body is
## overwritten by the next physics step.
func _teleport(body: RigidBody2D, at: Vector2) -> void:
	PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, at))
	PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
	PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)


func _touch_at(finger: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = at
	event.pressed = pressed
	Input.parse_input_event(event)


func _drag_to(finger: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = finger
	event.position = at
	Input.parse_input_event(event)


func _step_taps_pick_the_right_tile(sandbox: FlightSandbox) -> void:
	var ship := sandbox.ship
	var wrong := 0
	for tile in ship.blueprint.tiles:
		var center := ShipStats.polygon_centroid(ship.placement.tile_polygon(tile)) * PX
		await _tap(get_viewport().get_canvas_transform() * ship.to_global(center))
		if sandbox._picked != tile.id:
			wrong += 1
			print("drive_flight: tap on tile %d picked %d" % [tile.id, sandbox._picked])
	_check(wrong == 0, "a tap on each tile's centre picks that tile (%d wrong)" % wrong)


func _step_rays_hit_every_tile(ship: ShipBody) -> void:
	# The way a bullet will find a tile: a ray from outside, through the tile's centre.
	var space := ship.get_world_2d().direct_space_state
	var wrong := 0
	for tile in ship.blueprint.tiles:
		var target := ship.to_global(ShipStats.polygon_centroid(ship.placement.tile_polygon(tile)) * PX)
		var query := PhysicsRayQueryParameters2D.create(target + Vector2(0, -5000), target)
		query.hit_from_inside = true
		var hit := space.intersect_ray(query)
		if hit.is_empty() or hit["collider"] != ship:
			wrong += 1
			continue
		var hit_tile := ship.tile_at_shape(hit["shape"])
		var hit_polygon := ship.placement.tile_polygon(ship.blueprint.tile_by_id(hit_tile))
		if not Geometry2D.is_point_in_polygon(ship.to_local(hit["position"]) / PX + Vector2(0, 0.001), hit_polygon):
			wrong += 1
	_check(wrong == 0, "a ray from above reports the tile it actually hit, for every tile (%d wrong)" % wrong)


func _step_one_draw_call(ship: ShipBody) -> void:
	await _frames(3)
	var with_ship := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	ship.visible = false
	await _frames(3)
	var without := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	ship.visible = true
	await _frames(2)
	_check(with_ship - without == 1, "the ship costs one draw call (%d with, %d without)" % [with_ship, without])


func _step_ships_collide(sandbox: FlightSandbox) -> void:
	# A second ship flung at the first: the convex shapes must actually collide.
	var other := ShipBody.create(sandbox.ship.blueprint, sandbox.ship.placement)
	other.position = sandbox.ship.position + Vector2(-900, 0)
	other.linear_velocity = Vector2(1500, 0)
	other.contact_monitor = true
	other.max_contacts_reported = 4
	sandbox.ship.get_parent().add_child(other)
	# An array, because a lambda captures a local bool by value and would never see the change.
	var touched := [false]
	other.body_shape_entered.connect(func(_rid: RID, body: Node, _body_shape: int, _local: int) -> void:
		touched[0] = touched[0] or body == sandbox.ship)
	await _physics_frames(90)
	_check(touched[0], "a second ship flung at the first collides with it")
	_check(sandbox.ship.linear_velocity.x > 1.0, "and pushes it (vx %.1f)" % sandbox.ship.linear_velocity.x)
	other.queue_free()


# ── helpers ───────────────────────────────────────────────────────────────────

func _finish() -> void:
	OS.remove_logger(_spy)
	for error in _spy.seen:
		_failures.append("script error: " + error)
	if _failures.is_empty():
		print("drive_flight: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			printerr("drive_flight: FAIL  " + failure)
		get_tree().quit(1)


func _tap(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = at
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(1)


func _save_shot(file_name: String) -> void:
	get_viewport().get_texture().get_image().save_png(
			ProjectSettings.globalize_path("res://dev_preview/out/" + file_name))


func _check(ok: bool, what: String) -> void:
	print("drive_flight: %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

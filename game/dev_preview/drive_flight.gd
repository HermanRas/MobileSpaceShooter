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
	_finish()


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

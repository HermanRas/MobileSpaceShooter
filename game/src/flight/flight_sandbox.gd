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
## target on their own; FIRE fires the manual ones (in 1-stick, every gun is auto). The Target
## button swaps the practice target; one with guns (the rocket pod, 4.6a) shoots back.
##
## Combat HUD (4.7): shield and hull bars, the active manual weapon, and a flash, jolt and buzz
## when hit. SWITCH pauses and lists the manual weapons (Q on a keyboard cycles them instead).

signal closed

const PX := ShipMesh.PX_PER_U

var ship: ShipBody
var pilot: FlightController
var weapons: WeaponController
## Every shot in flight, and the sparks where they strike.
var pool := ProjectilePool.new()
var impacts := ImpactFx.new()
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
var hud := CombatHud.new()
var picker := WeaponPicker.new()
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
## The level the player's guns are at (the Guns button steps through `gun_levels`); Creative only.
var gun_level := 1
## The profile's stock when the ship was built from it (PLAN.md 4.8a), or null. Its fitted guns
## fly at their own levels, and a kill's XP goes to them.
var stock: Inventory
## Prices and what a kill pays (4.8c), with `stock`.
var economy: Economy
## XP earned this flight, all guns together, and what the kills paid.
var xp_earned := 0
var loot_earned := {}
var _level_button := Button.new()
## Which of the sandbox's `targets` is parked ahead.
var target_index := 0
var _target_button := Button.new()


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
	impacts.name = "Impacts"
	impacts.z_index = 3
	_world.add_child(impacts)
	pool.hit.connect(func(_body: ShipBody, _tile: int, point: Vector2, velocity: Vector2, weapon_id: StringName) -> void:
		impacts.burst(point, velocity, weapon_id))
	pool.exploded.connect(impacts.blast)
	pool.shot_down.connect(impacts.pop)
	pool.shot_down.connect(func(_point: Vector2) -> void: _show_status())
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
	if stock != null:
		ship.gun_levels = _item_levels()
		ship.guns = GunLayout.compute(ship.blueprint, _placement, 1, ship.gun_levels)
	elif gun_level != ship.gun_level:
		ship.gun_level = gun_level
		ship.build(_bp, _placement)
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
	hud.attach(ship, weapons, _camera, _flight.get("combat_hud", {}))
	ship.rebuilt.connect(_show_status)
	ship.destroyed.connect(_on_player_destroyed)
	_camera.configure(_flight.get("camera", {}), ship, _extent_u(_bp, _placement))


func _spawn_target() -> void:
	if target != null:
		return  # a respawn that a Target press already beat
	var errors: PackedStringArray = []
	var names: Array = _sandbox.get("targets", ["target_barge"])
	var raw: Dictionary = Data.json_dir("enemies").get(str(names[target_index % names.size()]), {})
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
	var spawned := target
	target.destroyed.connect(func() -> void:
		target = null
		_clear_pick()
		_on_kill(spawned, bp)
		_after_respawn_delay(_spawn_target))
	_world.add_child(target)
	if not target.guns.guns.is_empty():
		var guns := WeaponController.new()
		guns.name = "Weapons"
		target.add_child(guns)
		guns.attach(target, pool, _placement.weapons, func() -> Array: return [ship] if ship != null else [])
		var view := GunView.new()
		target.add_child(view)
		view.attach(guns)
	_target_button.text = "Target: %s" % target.blueprint.name


## Parks the next practice target in place of this one.
func _next_target() -> void:
	target_index += 1
	if target != null:
		target.queue_free()
		target = null
	_clear_pick()
	_spawn_target()


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


## A kill the player's guns had a hand in: its XP (PLAN.md 4.8b), split between the gun items by
## the damage each dealt to `body`, and what it pays (4.8c, from `built`, the ship as it spawned)
## straight into the wallet until there are pickups (5.4). Guns that level up fly at their new
## level straight away.
func _on_kill(body: ShipBody, built: Blueprint) -> void:
	if stock == null or body.damage == null:
		return
	var xp := _placement.weapons.xp
	var dealt := {}
	for source: StringName in body.damage_by:
		if stock.guns.has(String(source)):
			dealt[String(source)] = body.damage_by[source]
	if dealt.is_empty():
		return
	var level := int(_sandbox.get("encounter_level", 1))
	var loot := economy.kill_loot(_placement, built, level) if economy != null else {}
	stock.receive(loot)
	loot_earned = Economy.add(loot_earned, loot)
	var total := xp.kill_xp(body.damage.hp.size(), level)
	var ups: PackedStringArray = []
	var shares := WeaponXp.split(total, dealt)
	for id: String in shares:
		var item: Inventory.GunItem = stock.guns[id]
		var before := xp.level_for(item.xp)
		item.xp += shares[id]
		if xp.level_for(item.xp) > before:
			ups.append("%s L%d" % [_placement.weapons.weapon(item.weapon).get("name", item.weapon), xp.level_for(item.xp)])
	xp_earned += total
	var paid: PackedStringArray = []
	for resource: StringName in loot:
		paid.append("+%d %s" % [loot[resource], "GC" if resource == Inventory.GC else String(resource)])
	_note = "+%d XP  ·  %s%s" % [total, ", ".join(paid), "  ·  " + ", ".join(ups) + "!" if not ups.is_empty() else ""]
	_note_until = Time.get_ticks_msec() + 2500
	if not ups.is_empty() and ship != null:
		ship.gun_levels = _item_levels()
		ship.guns = GunLayout.compute(ship.blueprint, _placement, 1, ship.gun_levels)
		weapons.gunnery.set_layout(ship.guns)


## Each gun item's level (item id -> level).
func _item_levels() -> Dictionary:
	var out := {}
	for id: String in stock.guns:
		out[id] = _placement.weapons.xp.level_for((stock.guns[id] as Inventory.GunItem).xp)
	return out


func _after_respawn_delay(then: Callable) -> void:
	get_tree().create_timer(float(_sandbox.get("respawn_s", 3.0))).timeout.connect(then)


func perf_note() -> String:
	return "  ship spawn %.1f ms (%d tiles)" % [last_spawn_usec / 1000.0, ship.blueprint.tiles.size() if ship else 0]


func close() -> void:
	get_tree().paused = false
	closed.emit()


func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false  # never leave the game paused behind a closed sandbox


## SWITCH: pause and list the manual weapons (4.7).
func open_switch() -> void:
	if ship == null or weapons == null:
		return
	if weapons.all_auto or weapons.gunnery.manual_weapons().is_empty():
		_note = "1-stick: every gun fires on its own" if weapons.all_auto else "SWITCH: no manual weapons"
		_note_until = Time.get_ticks_msec() + 2000
		return
	picker.open(weapons.gunnery)
	picker.visible = true
	picker.reset_size()
	picker.position = (picker.get_viewport_rect().size - picker.size) * 0.5
	get_tree().paused = true


func _close_switch(weapon_id: StringName = &"") -> void:
	if weapon_id != &"" and weapons != null:
		weapons.gunnery.select(weapon_id)
	picker.visible = false
	get_tree().paused = false


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
	if event.is_action_pressed(&"switch_weapon") and weapons != null:
		weapons.gunnery.cycle()
		return
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
	if pool.downed > 0:
		text += "  ·  %d rockets shot down" % pool.downed
	_status.text = text


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	# First, so the labels and buttons added after it sit on top.
	controls.name = "Controls"
	controls.switch_pressed.connect(open_switch)
	ui.add_child(controls)
	hud.name = "CombatHud"
	ui.add_child(hud)
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
	_level_button.text = "Guns L%d" % gun_level
	_level_button.size = Vector2(132, 56)
	_level_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 16)
	_level_button.position.y += 128
	_level_button.pressed.connect(_next_gun_level)
	_level_button.visible = stock == null  # a stocked ship's guns are at their own levels
	ui.add_child(_level_button)
	_target_button.size = Vector2(220, 56)
	_target_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 16)
	_target_button.position.y += 192
	_target_button.pressed.connect(_next_target)
	ui.add_child(_target_button)
	if target != null:
		_target_button.text = "Target: %s" % target.blueprint.name
	picker.name = "WeaponPicker"
	picker.visible = false
	picker.picked.connect(_close_switch)
	picker.closed.connect(_close_switch.bind(&""))
	ui.add_child(picker)
	_controls_panel = ControlsPanel.new()
	_controls_panel.visible = false
	_controls_panel.closed.connect(_open_controls_panel.bind(false))
	ui.add_child(_controls_panel)


## Steps the player's guns to the next test level (a stand-in for Creative's level slider, 7.x),
## so accuracy by level can be felt before guns are items (4.8).
func _next_gun_level() -> void:
	var levels: Array = (_sandbox.get("gun_levels", [1, 10, 100, 999]) as Array).map(func(v: Variant) -> int: return int(v))
	gun_level = levels[(levels.find(gun_level) + 1) % levels.size()]
	_level_button.text = "Guns L%d" % gun_level
	if ship != null:
		ship.gun_level = gun_level
		ship.guns = GunLayout.compute(ship.blueprint, ship.placement, gun_level)
		weapons.gunnery.set_layout(ship.guns)


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

extends Node
## Phase 3.1, end to end: hangar → Fly → the ship is a physics body you can hit → back.
## Run with `tools/drive.sh res://dev_preview/drive_flight.tscn`. Exit code 0 = every step passed.

const ScriptErrorSpy := preload("res://dev_preview/script_error_spy.gd")
const PX := ShipMesh.PX_PER_U

var _hangar: Node
var _failures: PackedStringArray = []
var _spy := ScriptErrorSpy.new()


func _ready() -> void:
	# These checks place targets by the first sandbox's 6 U spawn gap (guns in range, a beam that
	# reaches); the game spawns them further out (owner, 2026-10-26). Only this run's copy changes.
	Data.table(&"flight")["spawner"]["spawn_gap_u"] = 6.0
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

	sandbox.test_hit = 0.0  # taps only pick here; _step_damage does the shooting
	await _step_taps_pick_the_right_tile(sandbox)
	await _step_rays_hit_every_tile(ship)
	sandbox._picked = -1  # the pick highlight is drawn separately; count the ship alone
	sandbox._overlay.queue_redraw()
	await _step_one_draw_call(ship)
	_save_shot("drive_flight.png")
	await _step_ships_collide(sandbox)
	await _step_damage(sandbox)

	_hangar.land()
	await _frames(3)
	_check(_hangar.get_node_or_null(^"FlightSandbox") == null, "landing closes the sandbox")
	_check(JSON.stringify(_hangar.editor.blueprint.to_dict()) == before, "the hangar's ship is untouched")
	_check(_hangar.editor.can_undo(), "the undo history survived the flight")
	_check(_hangar._world.visible and _hangar._ui.visible, "the hangar is visible again")

	await _step_guns()
	await _step_rockets_and_flak()
	await _step_specials()
	await _step_switch_and_hud()
	await _step_enemies_fly_themselves()
	await _step_fly_the_starter_with_the_stick()
	await _step_control_layouts()
	await _step_camera_and_arena()
	await _step_zoom_and_markers()
	await _step_a_level_30_fight()
	await _step_pause_and_lifecycle()
	_finish()


## Phase 4.2: shoot the practice barge in half (a drifting wreck and a lighter survivor), then
## blow it up and see it come back; shoot a thruster off our own ship and fly on with less.
func _step_damage(sandbox: FlightSandbox) -> void:
	var target := sandbox.target
	_check(target != null and target.damage != null, "a practice target is parked ahead")
	if target == null:
		return
	var tiles_before := target.blueprint.tiles.size()
	var mass_before := target.mass
	var wrecks_before := _wrecks(sandbox).size()
	# The barge's column at x = -1 (tiles 4 and 12) holds its left end on.
	for tile_id in [4, 12]:
		for i in 12:
			if target.damage.is_destroyed(tile_id):
				break
			await _shoot(sandbox, target, tile_id)
	await _frames(2)
	var wrecks := _wrecks(sandbox)
	_check(wrecks.size() == wrecks_before + 1, "cutting the barge in half leaves one wreck (%d)" % (wrecks.size() - wrecks_before))
	_check(target.blueprint.tiles.size() == tiles_before - 9 and target.get_shape_owners().size() == tiles_before - 9,
			"the survivor lost the 2 shot tiles and the 7 beyond them (%d left of %d)" % [target.blueprint.tiles.size(), tiles_before])
	_check(target.mass < mass_before, "and is lighter (%.1f -> %.1f)" % [mass_before, target.mass])
	if wrecks.size() > wrecks_before:
		var wreck: ShipBody = wrecks.back()
		_check(wreck.blueprint.tiles.size() == 7 and wreck.collision_layer == ShipBody.WRECK_LAYER,
				"the wreck holds the 7 cut-off tiles and collides with nothing")
		await _physics_frames(30)
		_check(wreck.linear_velocity.length() > 1.0, "the wreck drifts away")
	# Wear on the survivor: one tile per step, so the shot shows each.
	for row: Array in [[6, 30.0], [7, 50.0], [14, 70.0], [15, 95.0]]:
		target.damage.shield = 0.0
		target.take_hit(row[0], row[1], &"kinetic")
	await _frames(2)
	_check(target._wear.size() == 4, "each damaged tile shows its wear (%d)" % target._wear.size())
	_save_shot("drive_damage.png")

	for i in 30:
		if not is_instance_valid(target) or target.damage.dead:
			break
		await _shoot(sandbox, target, target.damage.core_id)
	await _frames(2)
	_check(sandbox.target == null, "destroying the core removes the ship")
	_check(sandbox._world.get_children().any(func(n: Node) -> bool: return n is Explosion), "with an explosion")
	_check(_wrecks(sandbox).size() >= 3, "and flings its pieces apart (%d wrecks)" % _wrecks(sandbox).size())
	_save_shot("drive_explosion.png")
	sandbox.spawn(FlightSandbox.SPAWN_ENEMIES, "target_barge")
	await _physics_frames(2)
	_check(sandbox.target != null and sandbox.target.blueprint.tiles.size() == tiles_before, "Spawn brings a fresh one")


## Phase 4.3, the "done when": the gunboat carries one gun of each mount type. Its auto guns (two
## swivels, two turrets) open up on the practice target by themselves, the manual nose gun waits
## for FIRE, no shot touches our own ship, and a target abeam is only for the turrets, which fire
## over the hull.
func _step_guns() -> void:
	var errors: PackedStringArray = []
	_hangar.load_blueprint(Blueprint.from_dict(Data.json_dir("blueprints")["gunboat"], errors))
	await _frames(2)
	var sandbox: FlightSandbox = _hangar.fly()
	_check(sandbox != null, "the gunboat can fly")
	if sandbox == null:
		return
	await _physics_frames(2)
	var ship := sandbox.ship
	var target := sandbox.target
	_check(ship.guns.guns.size() == 5, "it has 5 guns (%d)" % ship.guns.guns.size())
	if ship.guns.guns.size() != 5 or target == null:
		_hangar.land()
		return
	# Layout order follows the mounts: the fixed nose gun, the swivels, then the turrets.
	var fired := sandbox.weapons.gunnery.fired
	var health := func(body: ShipBody) -> float:
		var total := body.damage.shield
		for tile_id: int in body.damage.hp:
			total += body.damage.hp[tile_id]
		return total
	var target_before: float = health.call(target)
	var ours_before: float = health.call(ship)
	await _physics_frames(60)
	_check(fired[0] == 0, "the manual nose gun holds fire without FIRE")
	_check(fired[1] > 0 and fired[2] > 0, "both swivels fire on their own (%d, %d)" % [fired[1], fired[2]])
	_check(fired[3] > 0 and fired[4] > 0, "both turrets fire on their own (%d, %d)" % [fired[3], fired[4]])
	_check(sandbox.pool.count > 0, "shots are in flight (%d)" % sandbox.pool.count)
	_check(is_instance_valid(target) and health.call(target) < target_before, "and they hurt the target")
	_save_shot("drive_guns.png")
	Input.action_press(&"fire")
	await _physics_frames(30)
	Input.action_release(&"fire")
	_check(fired[0] >= 1, "FIRE fires the manual nose cannon (%d)" % fired[0])
	_check(sandbox.impacts.count > 0, "hits throw sparks (%d)" % sandbox.impacts.count)
	_check(health.call(ship) == ours_before, "not one shot touched our own ship")
	sandbox._level_button.pressed.emit()
	await _physics_frames(2)
	_check(ship.guns.guns[0].level == 10 and sandbox.weapons.gunnery.layout == ship.guns
			and ship.guns.guns[0].spread < WeaponLib.spread_for(ship.guns.guns[0].stats, 1),
			"the Guns button levels the guns to L10, and they tighten up")

	# Turn so the target is off the right wing: the swivels can't reach it; both turrets can, the
	# left one over the hull.
	_teleport(ship, ship.position, -PI / 2)
	await _physics_frames(2)
	var before := fired.duplicate()
	await _physics_frames(45)
	_check(fired[1] == before[1] and fired[2] == before[2], "the swivels can't reach a target abeam")
	_check(fired[4] > before[4], "the right-wing turret can (%d more)" % (fired[4] - before[4]))
	_check(fired[3] > before[3], "so can the left-wing one, over the hull (%d more)" % (fired[3] - before[3]))
	_check(health.call(ship) == ours_before, "and its shots pass over our own tiles")
	_hangar.land()
	await _frames(3)


## Phase 4.6a: the skirmisher's Seeker swivels blow holes in the barge (splash hurts several
## tiles), the manual AP rocket fires on FIRE, and against the rocket pod, whose seekers come at
## us, the flak turrets shoot rockets down.
func _step_rockets_and_flak() -> void:
	var errors: PackedStringArray = []
	_hangar.load_blueprint(Blueprint.from_dict(Data.json_dir("blueprints")["skirmisher"], errors))
	await _frames(2)
	var sandbox: FlightSandbox = _hangar.fly()
	_check(sandbox != null, "the skirmisher can fly")
	if sandbox == null:
		return
	await _physics_frames(2)
	var fired := sandbox.weapons.gunnery.fired
	await _physics_frames(150)
	_check(fired[1] > 0 and fired[2] > 0, "the Seeker swivels launch on their own (%d, %d)" % [fired[1], fired[2]])
	_check(sandbox.pool.explosions > 0, "rockets explode (%d)" % sandbox.pool.explosions)
	var target := sandbox.target
	var hurt := 0
	if target != null:
		for tile_id: int in target.damage.hp:
			if target.damage.hp[tile_id] < target.damage.max_hp[tile_id]:
				hurt += 1
	_check(hurt >= 3 or target == null, "the splash hurts several tiles (%d)" % hurt)
	_save_shot("drive_rockets.png")
	Input.action_press(&"fire")
	await _physics_frames(20)
	Input.action_release(&"fire")
	_check(fired[0] >= 1, "FIRE launches the nose AP rocket (%d)" % fired[0])

	await _swap(sandbox, "rocket_pod")
	_check(sandbox.target != null and sandbox.target.blueprint.id == "rocket_pod", "Spawn puts the rocket pod ahead")
	# The skirmisher can destroy the pod, so count while it lasts.
	var pod_shots := 0
	for i in 360:
		await _physics_frames(1)
		if sandbox.target != null and sandbox.target.has_node(^"Weapons"):
			var fired_now: PackedInt32Array = (sandbox.target.get_node(^"Weapons") as WeaponController).gunnery.fired
			var total := 0
			for n in fired_now:
				total += n
			pod_shots = maxi(pod_shots, total)
	_check(pod_shots > 0, "the pod fires seekers at us (%d)" % pod_shots)
	_check(sandbox.pool.downed > 0, "the flak shoots rockets down (%d)" % sandbox.pool.downed)
	_save_shot("drive_flak.png")
	_hangar.land()
	await _frames(3)


## Phase 4.6b: the specialist against the shield block. Its laser swivels beam the shield down,
## its EMP turrets knock the block out, and a mine dropped behind goes off when the block is put
## on top of it.
func _step_specials() -> void:
	var errors: PackedStringArray = []
	_hangar.load_blueprint(Blueprint.from_dict(Data.json_dir("blueprints")["specialist"], errors))
	await _frames(2)
	var sandbox: FlightSandbox = _hangar.fly()
	_check(sandbox != null, "the specialist can fly")
	if sandbox == null:
		return
	await _swap(sandbox, "shield_block")
	var block := sandbox.target
	var health := func() -> float:
		var total := block.damage.shield
		for tile_id: int in block.damage.hp:
			total += block.damage.hp[tile_id]
		return total
	var before: float = health.call()
	var laser_hits := [0]
	sandbox.pool.hit.connect(func(_b: ShipBody, _t: int, _p: Vector2, _v: Vector2, weapon_id: StringName) -> void:
		if weapon_id == &"laser":
			laser_hits[0] += 1)
	var beamed := false
	var knocked_out := false
	for i in 120:
		await _physics_frames(1)
		beamed = beamed or not sandbox.weapons.beam_ends.is_empty()
		knocked_out = knocked_out or (is_instance_valid(block) and block.damage.is_disabled())
	_check(beamed, "the laser swivels beam on their own")
	_check(laser_hits[0] >= 10, "their pulses land (%d)" % laser_hits[0])
	_check(not is_instance_valid(block) or health.call() < before - 150.0,
			"the block loses shield and hull (%.0f -> %.0f)" % [before, health.call() if is_instance_valid(block) else 0.0])
	_check(knocked_out, "the EMP knocks the block out")
	_save_shot("drive_specials.png")

	sandbox.weapons.gunnery.select(&"mines")  # the nose laser is the other manual weapon (4.7)
	Input.action_press(&"fire")
	await _physics_frames(10)
	Input.action_release(&"fire")
	var pool := sandbox.pool
	var mine := Vector2.INF
	for k in pool.count:
		if pool._specs[pool._spec[k]]["proximity"] > 0.0:
			mine = pool._pos[k]
	_check(mine != Vector2.INF, "FIRE drops a mine behind")
	if mine == Vector2.INF or sandbox.target == null:
		_hangar.land()
		return
	await _physics_frames(30)  # it drifts to a stop
	for k in pool.count:
		if pool._specs[pool._spec[k]]["proximity"] > 0.0:
			mine = pool._pos[k]
	var blasts := pool.explosions
	_teleport(sandbox.target, mine + Vector2(0, 0.8 * PX))
	await _physics_frames(6)
	_check(pool.explosions > blasts, "an enemy beside the mine sets it off")
	_hangar.land()
	await _frames(3)


## Phase 5.2: a roster ship on the Target list flies itself with the player's own flight
## controller: it gets a pilot, moves, turns and stays in the arena, and a practice barge doesn't.
func _step_enemies_fly_themselves() -> void:
	var errors: PackedStringArray = []
	_hangar.load_blueprint(Blueprint.from_dict(Data.json_dir("blueprints")["starter"], errors))
	await _frames(2)
	var sandbox: FlightSandbox = _hangar.fly()
	if sandbox == null:
		_check(false, "the starter flies")
		return
	_check(sandbox.target.get_node_or_null("Ai") == null, "a practice barge has no pilot")
	# The Spawn button (owner, 2026-10-26): a paused list of cards; a tap spawns that ship ahead.
	sandbox._spawn_button.pressed.emit()
	await _frames(3)
	var picker := sandbox.spawn_list
	_check(picker.visible and get_tree().paused, "Spawn pauses and opens the list")
	var card := func(name: String) -> Button: return picker.find_child(name, true, false) as Button
	_check(card.call("enemies_target_barge") != null and card.call("enemies_wasp") != null and card.call("enemies_leviathan") != null
			and card.call("enemies_pike") != null, "with practice targets, the roster and the carrier")
	_check(card.call("library_starter") != null, "and the player's own ships")
	_save_shot("drive_flight_spawn.png")
	var before := sandbox.enemies.size()
	var wasp_card: Button = card.call("enemies_wasp")
	if wasp_card != null:
		wasp_card.pressed.emit()
		await _physics_frames(2)
		_check(not picker.visible and not get_tree().paused, "a tap closes it and play resumes")
		_check(sandbox.enemies.size() == before + 1 and sandbox.target.blueprint.id == "wasp", "and the Wasp is spawned")
		var ahead := (sandbox.target.global_position - sandbox.ship.global_position).rotated(-sandbox.ship.global_rotation)
		_check(ahead.x > 3.0 * ShipMesh.PX_PER_U, "ahead of us, stepped aside from the barge (%s U)" % (ahead / ShipMesh.PX_PER_U))
	# Encounters (5.3): a generated fight at a level, and a Kill HVT one led by a boss.
	sandbox.clear_enemies()
	sandbox._spawn_button.pressed.emit()
	await _frames(3)
	var level_25: Button = card.call("encounter_25")
	_check(level_25 != null and card.call("hvt_40") != null, "the list has encounter and boss buttons")
	if level_25 != null:
		level_25.pressed.emit()
		await _physics_frames(2)
		var band: Dictionary = sandbox.levels.band_for(25)
		var fought := sandbox.enemies
		_check(fought.size() >= int(band["count"][0]) and fought.size() <= int(band["count"][1]),
				"Level 25 spawns %d enemies (band %s)" % [fought.size(), band["count"]])
		var right := true
		for e in fought:
			right = right and e.level == 25 and e.gun_level >= 200 and e.gun_level <= 300 and is_equal_approx(e.gun_damage, float(band["damage"]))
		_check(right, "at level 25, guns about L250, %d%% damage" % roundi(float(band["damage"]) * 100.0))
		sandbox.clear_enemies()
		sandbox.open_spawner()
		await _frames(3)
		(card.call("hvt_40") as Button).pressed.emit()
		await _physics_frames(2)
		_check(sandbox.enemies.any(func(e: ShipBody) -> bool: return "boss" in e.blueprint.tags), "Boss L40 brings a boss")
		_save_shot("drive_flight_encounter.png")
		sandbox.clear_enemies()
	await _check_flies_itself(sandbox, "wasp")
	# Escort (12.3): the carrier joins our side beside us, flies its route, and the raider goes for it.
	var carrier := sandbox.spawn(FlightSandbox.SPAWN_ENEMIES, "pike")
	await _physics_frames(2)
	_check(carrier != null and carrier == sandbox.carrier and carrier.team == 0 and carrier.get_node_or_null("Ai") != null
			and not sandbox.enemies.has(carrier), "spawning the Pike brings in the carrier, on our side, flying itself")
	if carrier != null:
		var off := (carrier.global_position - sandbox.ship.global_position).rotated(-sandbox.ship.global_rotation) / ShipMesh.PX_PER_U
		_check(off.y > 1.0 and absf(off.x) < 3.0, "beside us, to our right (%s U)" % off)
	if carrier != null:
		var start := carrier.global_position
		_teleport(sandbox.target, carrier.global_position + Vector2(9, -3) * ShipMesh.PX_PER_U)
		_teleport(sandbox.ship, carrier.global_position + Vector2(-30, 0) * ShipMesh.PX_PER_U)
		await _physics_frames(30)
		if is_instance_valid(carrier) and sandbox.target != null:
			var ai := sandbox.target.get_node("Ai") as AiPilot
			_check(ai.target.call() == carrier, "a raider nearer the carrier goes for it")
			_check(carrier.global_position.distance_to(start) / ShipMesh.PX_PER_U > 1.0, "the carrier keeps flying its route")
			_save_shot("drive_flight_escort.png")
	if is_instance_valid(sandbox.carrier):
		sandbox.carrier.queue_free()
	await _check_flies_itself(sandbox, "marauder")
	_save_shot("drive_flight_ai.png")
	_hangar.land()
	await _frames(3)


## A roster target `id` gets a pilot, and in 4 s moves, turns and holds its stick (5.2).
func _check_flies_itself(sandbox: FlightSandbox, id: String) -> void:
	await _swap(sandbox, id)
	var enemy := sandbox.target
	var ai := enemy.get_node_or_null("Ai") as AiPilot
	_check(ai != null, "%s gets an AI pilot" % id)
	if ai == null:
		return
	var start := enemy.global_position
	var turned := 0.0
	var last := enemy.global_rotation
	var sticks := 0
	for i in 240:
		await _physics_frames(1)
		if not is_instance_valid(enemy):
			break
		turned += absf(angle_difference(last, enemy.global_rotation))
		last = enemy.global_rotation
		if (enemy.get_node("Pilot") as FlightController).stick.length() > 0.15:
			sticks += 1
	if not is_instance_valid(enemy):
		_check(false, "%s survived 4 s" % id)
		return
	var moved := enemy.global_position.distance_to(start) / ShipMesh.PX_PER_U
	# A chaser spawns facing us, so it needn't turn much; it must steer a little all the same.
	_check(sticks > 60 and moved > 2.0 and turned > 0.1,
			"%s flies itself: %.1f U, turned %.0f°, stick held %d of 240 ticks (%s)" % [id, moved, rad_to_deg(turned), sticks, ai.brain.behaviour])
	_check(sandbox.arena.contains(enemy.global_position / ShipMesh.PX_PER_U), "%s stays in the arena (at %s U, we are at %s U)" % [id, (enemy.global_position / ShipMesh.PX_PER_U).round(), (sandbox.ship.global_position / ShipMesh.PX_PER_U).round() if sandbox.ship != null else Vector2.INF])


## Phase 4.7, the "done when": with two manual weapon types aboard, FIRE fires only the active
## one while the auto turrets keep going; SWITCH pauses, lists them, and a pick swaps what FIRE
## fires. A hit on our ship flashes the screen and drops the hull bar.
func _step_switch_and_hud() -> void:
	var errors: PackedStringArray = []
	_hangar.load_blueprint(Blueprint.from_dict(Data.json_dir("blueprints")["gunboat"], errors))
	for i in _hangar.editor.blueprint.mounts.size():
		if _hangar.editor.blueprint.mounts[i]["part"] == "weapon.gatling_multi":
			_hangar.editor.set_mount_mode(i, &"manual")
	await _frames(2)
	var sandbox: FlightSandbox = _hangar.fly()
	await _physics_frames(2)
	var gunnery := sandbox.weapons.gunnery
	_check(gunnery.manual_weapons().size() == 2 and gunnery.active == &"cannon", "two manual types, the cannon active")
	var before := gunnery.fired.duplicate()
	Input.action_press(&"fire")
	await _physics_frames(60)
	Input.action_release(&"fire")
	var after := gunnery.fired
	_check(after[0] > before[0], "FIRE fires the cannon")
	_check(after[1] == before[1] and after[2] == before[2], "and not the manual swivels")
	_check(after[3] > before[3] or after[4] > before[4], "while the auto turrets keep firing")

	sandbox.controls.switch_pressed.emit()
	await _frames(2)
	_check(sandbox.picker.visible and get_tree().paused, "SWITCH pauses and lists the weapons")
	_check(sandbox.picker.find_child("gatling_multi", true, false) != null, "with the multi gatling on it")
	_save_shot("drive_switch.png")
	(sandbox.picker.find_child("gatling_multi", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(not get_tree().paused and not sandbox.picker.visible, "a pick resumes")
	_check(gunnery.active == &"gatling_multi", "and makes it what FIRE fires")
	before = gunnery.fired.duplicate()
	Input.action_press(&"fire")
	await _physics_frames(60)
	Input.action_release(&"fire")
	_check(gunnery.fired[1] > before[1] and gunnery.fired[0] == before[0], "now FIRE fires the swivels, not the cannon")

	var ship := sandbox.ship
	ship.take_hit(ship.blueprint.tiles[1].id, 40.0, &"kinetic")
	await _frames(1)
	_check(sandbox.hud.flash_left > 0.0 and sandbox.hud.hull_share < 1.0,
			"a hit flashes and drops the hull bar (%.2f)" % sandbox.hud.hull_share)
	_save_shot("drive_hud.png")
	_hangar.land()
	await _frames(3)
	_check(not get_tree().paused, "back in the hangar, nothing is paused")


## Phase 4.2: shoot off the tile carrying a thruster, and fly on with the rest.
func _step_lose_a_thruster(sandbox: FlightSandbox) -> void:
	var ship := sandbox.ship
	var thrusters_before := ship.envelope.thrusters.size()
	_check(thrusters_before > 0, "our ship has thrusters to lose")
	if thrusters_before == 0:
		return
	var host := int(ship.blueprint.mounts[ship.envelope.thrusters[0]["mount"]]["tile"])
	_check(host != ship.damage.core_id, "the thruster isn't on the core")
	for i in 30:
		if ship.damage.is_destroyed(host):
			break
		ship.take_hit(host, 60.0, &"kinetic")
		await _physics_frames(1)
	await _frames(2)
	_check(ship.envelope.thrusters.size() == thrusters_before - 1, "losing a hardpoint loses its thruster")
	_check(sandbox.pilot.model.envelope == ship.envelope, "the pilot flies with the new envelope")
	_check(ship.get_node(^"Exhaust").get_child_count() == thrusters_before - 1, "and the exhaust follows")


## Flight checks want open space: the practice target sits right ahead.
func _remove_target(sandbox: FlightSandbox) -> void:
	sandbox.clear_enemies()


## The enemies cleared and ship `id` (data/enemies) spawned ahead.
## (At level 1 with level-1 guns, so the starter outlives a few seconds next to a boss.)
func _swap(sandbox: FlightSandbox, id: String) -> void:
	sandbox.clear_enemies()
	await _physics_frames(1)
	sandbox.spawn(FlightSandbox.SPAWN_ENEMIES, id, 1, 1)
	await _physics_frames(2)


## A hit on `tile_id` found the way a bullet will find it: a physics query at its centre.
func _shoot(sandbox: FlightSandbox, body: ShipBody, tile_id: int) -> void:
	var tile := body.blueprint.tile_by_id(tile_id)
	var center := body.to_global(ShipStats.polygon_centroid(body.placement.tile_polygon(tile)) * PX)
	var found: Array = sandbox.ship_tile_at_point(center)
	if found[0] != body or found[1] != tile_id:
		_check(false, "a query at tile %d's centre finds it (got %s)" % [tile_id, found])
		return
	body.take_hit(tile_id, 60.0, &"kinetic")
	await _physics_frames(1)


func _wrecks(sandbox: FlightSandbox) -> Array:
	return sandbox._world.get_children().filter(func(n: Node) -> bool: return n is ShipBody and (n as ShipBody).is_wreck())


## Phase 3.5: the camera leads and zooms out at speed; the arena warns and pushes back.
func _step_camera_and_arena() -> void:
	var errors: PackedStringArray = []
	_hangar.load_blueprint(Blueprint.from_dict(Data.json_dir("blueprints")["starter"], errors))
	await _frames(2)
	var sandbox: FlightSandbox = _hangar.fly()
	_remove_target(sandbox)
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


## Phase 6.5: Pause, the pause key and the back button pause and resume; back closes an open
## panel first; switching away from the app pauses (and the world stands still); Settings opens
## over the pause menu and comes back to it; Return to hangar lands.
func _step_pause_and_lifecycle() -> void:
	var errors: PackedStringArray = []
	_hangar.load_blueprint(Blueprint.from_dict(Data.json_dir("blueprints")["starter"], errors))
	await _frames(2)
	var sandbox: FlightSandbox = _hangar.fly()
	await _physics_frames(3)
	var menu := sandbox.pause_menu
	(sandbox.find_child("Pause", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(menu.visible and get_tree().paused, "Pause pauses under the pause menu")
	_find_button(menu, "Resume").pressed.emit()
	await _frames(2)
	_check(not menu.visible and not get_tree().paused, "Resume resumes")

	for presses in 2:
		var key := InputEventAction.new()
		key.action = &"pause"
		key.pressed = true
		Input.parse_input_event(key)
		await _frames(2)
		key = InputEventAction.new()
		key.action = &"pause"
		key.pressed = false
		Input.parse_input_event(key)
		await _frames(2)
		_check(get_tree().paused == (presses == 0), "the pause key %s" % ["pauses", "resumes"][presses])

	_hangar.on_back()
	await _frames(2)
	_check(menu.visible and get_tree().paused and _hangar._sandbox == sandbox, "back pauses rather than lands")
	_hangar.on_back()
	await _frames(2)
	_check(not get_tree().paused, "and back again resumes")
	sandbox.open_spawner()
	await _frames(2)
	_hangar.on_back()
	await _frames(2)
	_check(not sandbox.spawn_list.visible and not menu.visible and not get_tree().paused, "back closes the Spawn list first")

	# Switching away from the app mid-flight: paused, and nothing moves until we come back.
	sandbox.ship.linear_velocity = Vector2(4, 0) * PX
	await _physics_frames(2)
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(2)
	var at := sandbox.ship.global_position
	await _frames(30)
	_check(menu.visible and get_tree().paused and sandbox.ship.global_position == at,
			"losing focus pauses the flight, and the ship stands still")
	_save_shot("drive_flight_paused.png")
	_find_button(menu, "Settings").pressed.emit()
	await _frames(2)
	_check(sandbox._controls_panel.visible and not menu.visible and get_tree().paused, "Settings opens over it, still paused")
	_check(_find_button(sandbox._controls_panel, "Done") == null, "with no Done button")
	_hangar.on_back()
	await _frames(2)
	_check(menu.visible and get_tree().paused, "back goes back to the pause menu")
	_find_button(menu, "Return to hangar").pressed.emit()
	await _frames(3)
	_check(_hangar._sandbox == null and not get_tree().paused, "Return to hangar lands")


func _find_button(root: Node, text: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node
	return null


## Phase 5.5, the "done when": a level-30 encounter spawns off screen round us (inside the
## arena), closes in and fights, and once every ship is down the fight is cleared.
func _step_a_level_30_fight() -> void:
	var errors: PackedStringArray = []
	_hangar.load_blueprint(Blueprint.from_dict(Data.json_dir("blueprints")["starter"], errors))
	await _frames(2)
	var sandbox: FlightSandbox = _hangar.fly()
	_remove_target(sandbox)
	await _physics_frames(3)
	var fight := sandbox.spawn_encounter(30)
	await _physics_frames(2)
	var foes := sandbox.enemies.duplicate()
	var hidden := foes.all(func(e: ShipBody) -> bool: return not sandbox.markers.on_screen(sandbox._camera, e.global_position))
	var inside := foes.all(func(e: ShipBody) -> bool: return sandbox.arena.contains(e.global_position / PX))
	_check(foes.size() == fight.spawns.size() and foes.size() > 0 and hidden and inside,
			"level 30: %d enemies spawn off screen round us, inside the arena" % foes.size())
	var nearest := func() -> float:
		var best := INF
		for e in sandbox.spawner.live():
			if sandbox.ship != null:
				best = minf(best, (e as ShipBody).global_position.distance_to(sandbox.ship.global_position) / PX)
		return best
	var start: float = nearest.call()
	var shot := false
	for i in 480:
		await _physics_frames(1)
		for e in sandbox.spawner.live():
			var guns := (e as ShipBody).get_node_or_null("Weapons") as WeaponController
			if guns != null and Array(guns.gunnery.fired).any(func(n: int) -> bool: return n > 0):
				shot = true
		if shot or sandbox.ship == null:
			break
	_check(shot, "they come at us and open fire (nearest %.0f U, then %.0f U)" % [start, nearest.call()])
	_save_shot("drive_flight_level_30.png")
	for e in sandbox.spawner.live():
		var body := e as ShipBody
		var core: int = body.blueprint.tiles.filter(func(t: Blueprint.Tile) -> bool: return t.type == &"core")[0].id
		body.take_hit(core, 1.0e9, &"kinetic", 1.0)
	await _frames(3)
	_check(sandbox.enemies.is_empty() and "level 30 cleared" in sandbox._hud.text,
			"every ship down: the fight is cleared (%s)" % sandbox._hud.text)
	_check(sandbox.pickups.count() > 0, "and their loot floats where they fell (%d pickups)" % sandbox.pickups.count())
	_hangar.land()
	await _frames(2)


## Owner, 2026-10-26: +/-, the mouse wheel and a two-finger pinch zoom the view (saved in
## Settings, put back afterwards); a carrier off screen gets a green arrow at the edge.
func _step_zoom_and_markers() -> void:
	var saved: float = Settings.get_value(&"view_zoom")
	Settings.set_value(&"view_zoom", 1.0)
	var errors: PackedStringArray = []
	_hangar.load_blueprint(Blueprint.from_dict(Data.json_dir("blueprints")["starter"], errors))
	await _frames(2)
	var sandbox: FlightSandbox = _hangar.fly()
	_remove_target(sandbox)
	await _frames(3)
	var camera: FollowCamera = get_viewport().get_camera_2d()
	_key(KEY_EQUAL)
	_key(KEY_EQUAL)
	await _frames(1)
	_check(is_equal_approx(camera.view_zoom, camera.zoom_step * camera.zoom_step)
			and is_equal_approx(float(Settings.get_value(&"view_zoom")), camera.view_zoom),
			"= zooms in twice and saves it (%.2f)" % camera.view_zoom)
	_key(KEY_MINUS)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	Input.parse_input_event(wheel)
	await _frames(1)
	_check(is_equal_approx(camera.view_zoom, 1.0), "- and a wheel notch zoom back out (%.2f)" % camera.view_zoom)

	# Two fingers on open space (right of the stick, above FIRE) spread to twice as far apart.
	var screen := get_viewport().get_visible_rect().size
	var a := Vector2(screen.x * 0.55, screen.y * 0.3)
	var b := a + Vector2(100, 0)
	_touch_at(3, a, true)
	_touch_at(4, b, true)
	await _frames(1)
	for step in 5:
		_drag_to(4, b + Vector2(20 * (step + 1), 0))
		await _frames(1)
	_check(absf(camera.view_zoom - 2.0) < 0.05 and is_equal_approx(float(Settings.get_value(&"view_zoom")), 1.0),
			"a pinch spreading 100 -> 200 px zooms to 2x (%.2f), not saved yet" % camera.view_zoom)
	_touch_at(4, b + Vector2(100, 0), false)
	_touch_at(3, a, false)
	await _frames(1)
	_check(is_equal_approx(float(Settings.get_value(&"view_zoom")), camera.view_zoom), "and saved when the fingers lift")
	var zoomed := camera.zoom.x
	await _frames(30)
	_check(camera.zoom.x > zoomed * 0.95, "the zoom holds at rest (%.2f -> %.2f)" % [zoomed, camera.zoom.x])

	camera.zoom_by(1.0 / camera.view_zoom)
	var carrier := sandbox.spawn(FlightSandbox.SPAWN_ENEMIES, "pike")
	await _frames(2)
	var on_screen := _carrier_arrow(sandbox)
	if carrier != null:
		_teleport(carrier, sandbox.ship.global_position + Vector2(0, 120) * PX)
	await _physics_frames(2)
	await _frames(2)
	_check(not on_screen and _carrier_arrow(sandbox), "a carrier off screen gets an arrow at the edge (beside us: %s, %s)"
			% [on_screen, sandbox.markers._marks])
	var far: float = sandbox.markers._marks[0][2] if not sandbox.markers._marks.is_empty() else 0.0
	_check(far > sandbox.markers.dot_within_u and sandbox.markers.size_share(far) < 1.0
			and sandbox.markers.size_share(sandbox.markers.dot_within_u) == 1.0,
			"far off it's a smaller arrow (%.0f U out: %.2f), full size near the view" % [far, sandbox.markers.size_share(far)])
	_save_shot("drive_flight_markers.png")

	# 5.5: an enemy you've seen gets a fixed-size dot off screen, until it's beyond sight range.
	var enemy := sandbox.spawn(FlightSandbox.SPAWN_ENEMIES, "target_barge")
	await _frames(2)
	var home := sandbox.ship.global_position
	var sight := sandbox.markers.sight_range_u
	_teleport(enemy, home + Vector2(-sight * 0.5, 0) * PX)
	await _physics_frames(2)
	await _frames(2)
	var dotted := _enemy_dot(sandbox)
	_teleport(enemy, home + Vector2(-sight * 1.5, 0) * PX)
	await _physics_frames(2)
	await _frames(2)
	var beyond := _enemy_dot(sandbox)
	_teleport(enemy, home + Vector2(-sight * 0.5, 0) * PX)
	await _physics_frames(2)
	await _frames(2)
	_check(dotted and not beyond and not _enemy_dot(sandbox),
			"a seen enemy gets a dot off screen (%s), lost beyond sight range (%s) until seen again (%s)"
			% [dotted, beyond, _enemy_dot(sandbox)])
	_hangar.land()
	await _frames(2)
	Settings.set_value(&"view_zoom", saved)


## Whether the edge markers show an enemy's dot.
func _enemy_dot(sandbox: FlightSandbox) -> bool:
	for mark: Array in sandbox.markers._marks:
		if mark[1] == FlightSandbox.ENEMY_MARK and mark[3] and EdgeMarkers.edge_point(mark[0], sandbox.markers.size) != null:
			return true
	return false


## Whether the edge markers show a carrier arrow.
func _carrier_arrow(sandbox: FlightSandbox) -> bool:
	for mark: Array in sandbox.markers._marks:
		if mark[1] == FlightSandbox.CARRIER_MARK and EdgeMarkers.edge_point(mark[0], sandbox.markers.size) != null:
			return true
	return false


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = keycode
		key.keycode = keycode
		key.pressed = pressed
		Input.parse_input_event(key)


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
	_remove_target(sandbox)
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
	await _step_lose_a_thruster(sandbox)
	_hangar.land()
	await _frames(2)


## Moves a rigid body through the physics server; setting global_position on an awake body is
## overwritten by the next physics step.
func _teleport(body: RigidBody2D, at: Vector2, rotation := 0.0) -> void:
	PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(rotation, at))
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

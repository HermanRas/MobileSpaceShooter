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
## the player's comes back after a few seconds. Tapping a tile highlights it (and hits it for
## `test_hit`, if data sets one).
##
## Guns (4.3): the ship's WeaponController fires into one ProjectilePool. Auto guns pick off the
## enemies on their own; FIRE fires the manual ones (in 1-stick, every gun is auto).
##
## Spawn (owner, 2026-10-26): the Spawn button pauses and lists every ship with its picture
## (SpawnPicker): practice targets, the enemy roster, the carrier and the player's own ships. A
## tap puts an enemy a few tiles ahead, facing the player (a roster ship flies itself, 5.2; the
## player's own ships fly as chasers or strafers), or the carrier beside the player, starting its
## route (an escort, 12.3), which enemies then go for. Enemies come at the sandbox's encounter
## level (guns about 10 × it, dealing the level's damage share, 5.3), and the Encounter buttons
## spawn a whole generated fight off screen round the player, a Kill HVT one led by a boss. The
## Spawner (5.5) does all of that, as it will for WaveTime and Story; the sandbox handles loot,
## XP and the HUD.
##
## Combat HUD (4.7): shield and hull bars, the active manual weapon, and a flash, jolt and buzz
## when hit. SWITCH pauses and lists the manual weapons (Q on a keyboard cycles them instead).
## The RunHud (8.2) counts the loot in the hold and banners a found part (and in a run, each new
## wave), and shows a run's clock, wave and score. Arcade feedback (8.3): DamageNumbers float
## over every hit on an enemy, a kill in a run pops its score, and a run's kills now and then drop a
## PowerUps bullet multiplier, which lives only in that run.
##
## Test fight (7.2, Creative): with `test_level` set before `open()`, there's no practice target,
## no Spawn or Guns button and no respawn: a generated fight at that level comes in, and when it's
## cleared or the ship is destroyed, the results card (TestResults) shows how it went.
##
## Performance test (7.5, Creative): `test_level` BENCH flies §5.5's worst case instead (BenchRun),
## the player's ship taking no damage, and the results card shows the frame times.
##
## WaveTime (8.1, stocked): `test_level` WAVETIME flies a run (WaveRun): waves of generated fights
## at rising levels, each coming when the last is cleared or after a minute, with no respawn. The
## guns earn XP and the cargo banks on landing as in free flight; the results card shows how far
## the run got.
##
## Fly out and fly back (8.1, WaveTime and Story; Creative goes straight in): with `cinematic`
## set before `open()`, space fades in with the ship in a LaunchBay, and it boosts out on its own
## for `cinematics.launch_s` before the player has it (and the first wave or the practice target
## comes). A ship lost in a run throws out an EscapePod. Leaving plays the DockScreen (the ship, or
## the pod, gliding into the bay) before `closed`.

signal closed
## Fly again, from the results card: the hangar flies a fresh copy at `level`.
signal again(level: int)

const PX := ShipMesh.PX_PER_U
## Seconds from a test fight's end to its results card, so the last explosion is seen.
const RESULTS_DELAY_S := 1.2
## The edge mark for the carrier you escort (enemies get marks with radar tech, v2).
const CARRIER_MARK := Color(0.4, 1.0, 0.5, 0.95)
## The edge dot for an enemy you've seen (5.5).
const ENEMY_MARK := Color(1.0, 0.35, 0.3, 0.95)

var ship: ShipBody
var pilot: FlightController
var weapons: WeaponController
## Every shot in flight, and the sparks where they strike.
var pool := ProjectilePool.new()
var impacts := ImpactFx.new()
## How long building the ship body took, for the debug Perf log.
var last_spawn_usec: int = 0

var arena: Arena
## Brings in the enemies and the carrier, and owns them (5.5).
var spawner := Spawner.new()
## Every enemy alive, oldest first, and the newest of them (or null when there are none).
var enemies: Array[ShipBody]:
	get:
		return spawner.enemies
var target: ShipBody:
	get:
		return spawner.target
## The carrier the player escorts (PLAN.md 12.3), an ally flying its route that enemies go for,
## or null.
var carrier: ShipBody:
	get:
		return spawner.carrier
## The roster (5.1) and the difficulty curve (5.3).
var roster: EnemyRoster:
	get:
		return spawner.roster
var levels: Encounter.Rules:
	get:
		return spawner.levels
var damage_table: DamageTable
## Raw damage a tap deals (from data; 0 makes taps only pick).
var test_hit := 60.0

var _camera := FollowCamera.new()
var _arena_view := _ArenaView.new()
var _edge_glow := _EdgeGlow.new()
## Marks at the screen's edge: the carrier off screen, and enemies you've seen.
var markers := EdgeMarkers.new()
## Enemies seen on screen and still within sight range (owner, 2026-10-26), as instance ids;
## further off they're forgotten until seen again. Radar tech (v2) will mark the rest.
var _seen := {}
## Fingers down on open space (not the stick or a button), index -> screen position: two of
## them pinch the zoom.
var _touches := {}
var _status := Label.new()
var _picked := -1
var _overlay := Node2D.new()
var controls := FlightControls.new()
var _hud := Label.new()
var _controls_panel: ControlsPanel
## Pause (6.5): its menu, opened by the Pause button, the pause key, the back button, or the app
## losing focus.
var pause_menu := PauseMenu.new()
var hud := CombatHud.new()
var run_hud := RunHud.new()
var numbers := DamageNumbers.new()
## A run's power-ups (8.3), or null outside a run.
var power: PowerUps
## The pilot flying (WaveTime), whose record a run adds up into when it ends (8.4), or null.
var profile: ProfileRecord
## The bests the run just beat ("score", "wave", "time"), once it's recorded.
var run_bests: PackedStringArray = []
var _run_recorded := false
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
## Creative only: the level the Guns button has put every gun at, or 0 while they fly at their
## own levels (each mount's, set in the hangar, 7.1). The button steps through `gun_levels`.
var gun_level := 0
## The profile's stock when the ship was built from it (PLAN.md 4.8a), or null. Its fitted guns
## fly at their own levels, and a kill's XP goes to them.
var stock: Inventory
## Prices and what a kill pays (4.8c), with `stock`.
var economy: Economy
## XP earned this flight, all guns together, and what the kills paid.
var xp_earned := 0
## What this flight has picked up (5.4): banked into `stock` on landing; lost with the run
## otherwise. Kept through the ship's own respawns in the sandbox.
var cargo := Inventory.new()
## Loot floating in space, and the dice for part drops.
var pickups := PickupField.new()
var _rng := RandomNumberGenerator.new()
var _level_button := Button.new()
var spawn_list := SpawnPicker.new()
var _spawn_button := Button.new()
## The level of the fight spawned from the list, until it's cleared (0: none).
var _fight_level := 0
## A test fight's level (Creative, 7.2), or 0 for free flight; set before `open()`.
var test_level := 0
## `test_level` for the performance test (7.5).
const BENCH := -1
var bench_run: BenchRun
## `test_level` for a WaveTime run (8.1).
const WAVETIME := -2
## The WaveTime run under way, or null.
var run: WaveRun
## Fly out and fly back (8.1): set before `open()`.
var cinematic := false
var bay: LaunchBay
var dock := DockScreen.new()
## Seconds of the launch left (0 once the player has the ship).
var launch_left := 0.0
var _cine: Dictionary = {}
## Space fading in from black at the start of a cinematic flight.
var _fade_in := ColorRect.new()
## The test fight under way, or null.
var test: TestFlight
var results := TestResults.new()


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
	if economy == null:
		economy = Economy.from_table(Data.table(&"economy"))  # Creative: loot drops, nothing is banked
	_rng.randomize()
	pickups.name = "Pickups"
	pickups.z_index = 2  # over wrecks and debris
	pickups.configure(_flight.get("pickups", {}))
	pickups.collected.connect(_on_pickup)
	_world.add_child(pickups)
	pool.name = "Shots"
	pool.z_index = 2
	_world.add_child(pool)
	impacts.name = "Impacts"
	impacts.z_index = 3
	_world.add_child(impacts)
	pool.hit.connect(func(_body: ShipBody, _tile: int, point: Vector2, velocity: Vector2, weapon_id: StringName) -> void:
		impacts.burst(point, velocity, weapon_id))
	pool.hit.connect(func(body: ShipBody, _tile: int, point: Vector2, _velocity: Vector2, _weapon_id: StringName) -> void:
		numbers.aim(body, point))
	pool.exploded.connect(impacts.blast)
	pool.shot_down.connect(impacts.pop)
	pool.shot_down.connect(func(_point: Vector2) -> void: _show_status())
	spawner.name = "Spawner"
	spawner.setup(placement, _flight, pool, _world)
	spawner.player = func() -> ShipBody: return ship
	spawner.view_half_u = func() -> Vector2: return _world.get_viewport_rect().size * 0.5 / (_camera.zoom.x * PX)
	spawner.spawned.connect(func(body: ShipBody) -> void:
		body.rebuilt.connect(_show_status)
		if body.team != 0:
			body.damaged.connect(func(result: ShipDamage.Result) -> void: numbers.hit(body, result.shield + result.hull)))
	spawner.enemy_destroyed.connect(_on_enemy_destroyed)
	spawner.cleared.connect(_on_cleared)
	spawner.carrier_lost.connect(func() -> void:
		_note = "the carrier is lost"
		_note_until = Time.get_ticks_msec() + 3000)
	add_child(spawner)
	_cine = _flight.get("cinematics", {})
	if cinematic:
		bay = LaunchBay.create(Spawner.extent_u(_bp, _placement))
		_world.add_child(bay)
		bay.position = -bay.berth_u() * PX  # the ship starts at the origin, in its berth
	_spawn_player()
	_camera.make_current()
	if cinematic:
		launch_left = float(_cine.get("launch_s", 2.0))
		_camera.zoom *= float(_cine.get("zoom_in", 1.6))
		weapons.hold_fire = true
	if test_level > 0:
		test = TestFlight.start(test_level, spawn_encounter(test_level).spawns.size())
	elif test_level == BENCH:
		bench_run = BenchRun.new()
		bench_run.name = "BenchRun"
		add_child(bench_run)
		bench_run.start(self)
		bench_run.finished.connect(func(run: Dictionary) -> void:
			_touches.clear()
			controls.stick.reset()
			controls.fire.reset()
			pause_menu.visible = false
			results.show_report("Performance test", bench_run.lines, run["summary"]["slow"] == 0)
			get_tree().paused = true)
	elif test_level == WAVETIME:
		run = WaveRun.from_table(Data.table(&"levels").get("waves", {}))
		power = PowerUps.from_table(Data.table(&"powerups"))
		if not cinematic and run.tick(0.0):
			_start_wave()
	elif not cinematic:
		spawn(SPAWN_ENEMIES, str(_sandbox.get("start_target", "target_barge")))
	var stars := Starfield.new()
	stars.camera = _camera
	add_child(stars)
	stars.use_nebula(randi() if test_level in [0, WAVETIME] else absi(test_level))  # a test fight keeps its sky
	_build_ui()
	_show_status()


func _spawn_player() -> void:
	var started := Time.get_ticks_usec()
	ship = ShipBody.create(_bp, _placement)
	if stock != null:
		ship.gun_levels = _item_levels()
		ship.guns = GunLayout.compute(ship.blueprint, _placement, 1, ship.gun_levels)
	else:
		ship.gun_level = maxi(gun_level, 1)
		ship.own_levels = gun_level == 0
		ship.guns = GunLayout.compute(ship.blueprint, _placement, ship.gun_level, {}, 1.0, ship.own_levels)
	last_spawn_usec = Time.get_ticks_usec() - started
	ship.enable_damage(damage_table)
	ship.invulnerable = test_level == BENCH  # the performance test's scenario holds while the player lives
	_world.add_child(ship)
	pickups.target = ship
	pickups.reach_u = Spawner.extent_u(_bp, _placement) * 0.5
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
	weapons.attach(ship, pool, _placement.weapons, spawner.live)
	var guns := GunView.new()
	guns.name = "Guns"
	ship.add_child(guns)
	guns.attach(weapons)
	hud.attach(ship, weapons, _camera, _flight.get("combat_hud", {}))
	ship.rebuilt.connect(_show_status)
	ship.destroyed.connect(_on_player_destroyed)
	ship.damaged.connect(func(result: ShipDamage.Result) -> void:
		if test != null:
			test.took(result.shield + result.hull)
		if run != null:
			run.took(result.shield + result.hull))
	_camera.configure(_flight.get("camera", {}), ship, Spawner.extent_u(_bp, _placement))


## Where a spawn comes from (the Spawner's), and the Spawn list's encounter buttons: a
## generated fight at a level, or a Kill HVT one.
const SPAWN_ENEMIES := Spawner.FROM_ENEMIES
const SPAWN_LIBRARY := Spawner.FROM_LIBRARY
const SPAWN_ENCOUNTER := &"encounter"
const SPAWN_HVT := &"hvt"


## Spawns ship `id` from `kind`: an enemy a few tiles ahead, facing the player, at encounter
## level `level` (the sandbox's when 0) with its guns at `gun_level` (10 × the level when 0); the
## roster's ally is the carrier, beside the player and flying `carrier_route`. Returns the ship,
## or null if there's no such ship.
func spawn(kind: StringName, id: String, level := 0, gun_level := 0) -> ShipBody:
	var entry := roster.entry(StringName(id)) if kind == SPAWN_ENEMIES else null
	if entry != null and entry.ally:
		var bp := spawner.blueprint(kind, id)
		return spawner.spawn_carrier(bp, entry, _sandbox.get("carrier_route", [])) if bp != null else null
	return spawner.spawn_ship(kind, id, level if level > 0 else int(_sandbox.get("encounter_level", 1)), gun_level)


## A generated fight at `level` (5.3), off screen round the player (5.5). Returns it.
func spawn_encounter(level: int, hvt := false) -> Encounter:
	var fight := spawner.spawn_encounter(level, hvt)
	_fight_level = level
	_note = "level %d: %d enemies, guns ~L%d" % [level, fight.spawns.size(),
			mini(roundi(levels.gun_per_level * level), _placement.weapons.xp.max_level)]
	_note_until = Time.get_ticks_msec() + 3000
	return fight


## The run's next wave (8.1): a generated fight at its level, off screen round the player.
func _start_wave() -> void:
	spawner.spawn_encounter(run.level())
	run_hud.found("WAVE %d   ·   level %d" % [run.wave, run.level()])


## Every enemy, gone.
func clear_enemies() -> void:
	spawner.clear()
	_fight_level = 0
	_clear_pick()


## Spawn: pause and list everything that can be spawned.
func open_spawner() -> void:
	_touches.clear()  # a panel over the fingers takes their release
	var sections: Array[Dictionary] = []
	var practice: Array[Dictionary] = []
	var foes: Array[Dictionary] = []
	var friends: Array[Dictionary] = []
	var raws := Data.json_dir("enemies")
	for id: String in raws:
		var errors: PackedStringArray = []
		var bp := Blueprint.from_dict(raws[id], errors)
		if bp == null:
			continue
		var entry := roster.entry(StringName(id))
		var card := {"kind": SPAWN_ENEMIES, "id": id, "name": bp.name, "bp": bp}
		if entry == null:
			practice.append(card)
		elif entry.ally:
			card["note"] = "ally"
			friends.append(card)
		else:
			card["note"] = "T%d %s" % [entry.tier, entry.role]
			card["order"] = entry.tier * 10 + (5 if entry.boss else 0)
			foes.append(card)
	foes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return [a["order"], a["name"]] < [b["order"], b["name"]])
	var library := BlueprintLibrary.new()
	var own: Array[Dictionary] = []
	for row in library.list():
		var bp := library.load_ship(row["id"])
		if bp != null and _placement.validate(bp).is_empty():
			own.append({"kind": SPAWN_LIBRARY, "id": row["id"], "name": bp.name, "bp": bp})
	var fights: Array[Dictionary] = []
	for level: Variant in _sandbox.get("encounter_buttons", [1, 10, 25, 50, 75, 100]):
		fights.append({"kind": SPAWN_ENCOUNTER, "id": str(int(level)), "name": "Level %d" % int(level)})
	for level: Variant in _sandbox.get("hvt_buttons", [15, 40, 65, 90]):
		fights.append({"kind": SPAWN_HVT, "id": str(int(level)), "name": "Boss L%d" % int(level)})
	sections.append({"title": "Encounters (5.3): a generated fight", "buttons": fights})
	sections.append({"title": "Practice targets", "cards": practice})
	sections.append({"title": "Enemies", "cards": foes})
	sections.append({"title": "Escort: the carrier flies beside you", "cards": friends})
	sections.append({"title": "Your ships, as enemies", "cards": own})
	spawn_list.open(sections, _placement)
	spawn_list.visible = true
	get_tree().paused = true


func _close_spawner(kind: StringName = &"", id: String = "") -> void:
	spawn_list.visible = false
	get_tree().paused = false
	if id.is_empty():
		return
	if kind == SPAWN_ENCOUNTER or kind == SPAWN_HVT:
		spawn_encounter(int(id), kind == SPAWN_HVT)
	else:
		spawn(kind, id)


func _on_player_destroyed() -> void:
	if cinematic and run != null:
		_launch_pod()
	ship = null
	pilot = null
	weapons = null
	_clear_pick()
	if test != null:
		test.destroyed()
		_show_results_soon()
		return
	if run != null:
		run.destroyed()
		_record_run(true)
		_show_results_soon(float(_cine.get("pod_s", RESULTS_DELAY_S)) if cinematic else RESULTS_DELAY_S)
		return
	_note = "destroyed"
	_note_until = Time.get_ticks_msec() + int(float(_sandbox.get("respawn_s", 3.0)) * 1000.0)
	_after_respawn_delay(func() -> void:
		_spawn_player()
		_show_status())


## An enemy is gone: its loot (5.4) and, if the player's guns had a hand in it, its XP (4.8b).
func _on_enemy_destroyed(body: ShipBody, built: Blueprint) -> void:
	_clear_pick()
	_drop_loot(body, built)
	_on_kill(body)
	if test != null:
		test.killed()
	if run != null:
		var points := run.killed(built.tiles.size(), body.level)
		if points > 0:
			numbers.pop(body.global_position, points)


## The last enemy is gone; if it was a fight from the Spawn list, say so.
func _on_cleared() -> void:
	if test != null and ship != null:
		test.cleared()
		_show_results_soon()
	if run != null and ship != null:
		var bonus := run.cleared()
		if bonus > 0:  # every run banks something (8.7)
			cargo.receive({Inventory.GC: bonus})
			run_hud.found("WAVE %d CLEARED!   +%d GC" % [run.wave, bonus])
	if _fight_level > 0:
		_note = "level %d cleared!" % _fight_level
		_note_until = Time.get_ticks_msec() + 4000
		_fight_level = 0


## What `body` (built as `built`) drops when it's destroyed, by whoever (5.4): its materials
## and GC as a few pickups each, and now and then one of its parts, a gun at the level it
## fought at.
func _drop_loot(body: ShipBody, built: Blueprint) -> void:
	var pieces := economy.loot_pieces(economy.kill_loot(_placement, built, body.level))
	var part := economy.part_drop(_placement, built, _rng.randf(), _rng.randi(), body.gun_level)
	if not part.is_empty():
		pieces.append(part)
	var shots := power.roll(_rng.randf(), _rng.randf()) if power != null and not run.over else 0
	if shots > 0:
		pieces.append({"powerup": shots})
	# From the tiles still attached, as hard as the ship blew up: the blast is the size of what
	# was left of it (Explosion), so a ship shot to a stub drops its loot close by.
	var origins := PackedVector2Array()
	for tile in body.blueprint.tiles:
		origins.append(body.to_global(ShipStats.polygon_centroid(_placement.tile_polygon(tile)) * PX))
	pickups.drop(origins, body.linear_velocity, pieces, Spawner.extent_u(body.blueprint, _placement))


## A pickup reached the ship: into the cargo hold. A part gets a note.
func _on_pickup(piece: Dictionary) -> void:
	if piece.has("powerup"):
		if power != null and not run.over:  # never banked: it's spent here and now
			power.take(int(piece["powerup"]))
			_apply_power()
			run_hud.found("×%d FIREPOWER!" % power.shots())
		return
	if piece.has("gun"):
		var xp := _placement.weapons.xp
		cargo.add_found_gun(piece["gun"], piece["mount"], int(piece["xp"]))
		_note = "Found a %s, L%d!" % [_placement.weapons.weapon(piece["gun"]).get("name", piece["gun"]),
				xp.level_for(int(piece["xp"]))]
		_note_until = Time.get_ticks_msec() + 3000
		run_hud.found(_note)
	elif piece.has("thruster"):
		cargo.add_thrusters(piece["thruster"], 1)
		var parts := Inventory.thruster_parts(piece["thruster"])
		_note = "Found a thruster: %s %s L%d!" % [String(parts[0]).capitalize(), parts[1], parts[2]]
		_note_until = Time.get_ticks_msec() + 3000
		run_hud.found(_note)
	else:
		cargo.receive(piece)


## The cargo hold in words, for the results card: "cargo 12 hull 3 crystal 40 GC 1 part", or "" when
## it's empty (the RunHud counts it in flight).
func cargo_text() -> String:
	if cargo.is_empty():
		return ""
	var parts: PackedStringArray = []
	for resource: StringName in Inventory.MATERIALS + [Inventory.GC]:
		if cargo.amount(resource) > 0:
			parts.append("%d %s" % [cargo.amount(resource), "GC" if resource == Inventory.GC else String(resource)])
	var found := cargo.guns.size()
	for key: String in cargo.thrusters:
		found += int(cargo.thrusters[key])
	if found > 0:
		parts.append("%d part%s" % [found, "" if found == 1 else "s"])
	return "cargo " + " ".join(parts)


## Lands the cargo hold in the profile's stock (the hangar calls it on landing). Creative has
## no stock, so its cargo is only for show.
func bank_cargo() -> void:
	if stock != null:
		stock.bank(cargo)


## A kill the player's guns had a hand in: its XP (PLAN.md 4.8b), split between the gun items by
## the damage each dealt to `body`. Guns that level up fly at their new level straight away.
func _on_kill(body: ShipBody) -> void:
	if stock == null or body.damage == null:
		return
	var xp := _placement.weapons.xp
	var dealt := {}
	for source: StringName in body.damage_by:
		if stock.guns.has(String(source)):
			dealt[String(source)] = body.damage_by[source]
	if dealt.is_empty():
		return
	var total := xp.kill_xp(body.damage.hp.size(), body.level)
	var ups: PackedStringArray = []
	var shares := WeaponXp.split(total, dealt)
	for id: String in shares:
		var item: Inventory.GunItem = stock.guns[id]
		var before := xp.level_for(item.xp)
		item.xp += shares[id]
		if xp.level_for(item.xp) > before:
			ups.append("%s L%d" % [_placement.weapons.weapon(item.weapon).get("name", item.weapon), xp.level_for(item.xp)])
	xp_earned += total
	_note = "+%d XP%s" % [total, "  ·  " + ", ".join(ups) + "!" if not ups.is_empty() else ""]
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


## The results card, `delay_s` after a test fight or a run ends; it pauses the flight under it.
func _show_results_soon(delay_s := RESULTS_DELAY_S) -> void:
	get_tree().create_timer(delay_s).timeout.connect(func() -> void:
		if not is_inside_tree() or (test == null and run == null):
			return
		_touches.clear()
		controls.stick.reset()
		controls.fire.reset()
		pause_menu.visible = false
		if run != null:
			var lines := run.lines()
			for best in run_bests:
				lines.insert(0, {"score": "NEW BEST SCORE!", "wave": "Furthest wave yet!", "time": "Longest run yet!"}[best])
			lines.append("Cargo: " + (cargo_text().trim_prefix("cargo ") if not cargo.is_empty() else "nothing"))
			results.show_report(run.title(), lines, false)
		else:
			results.show_flight(test)
		get_tree().paused = true)


func _after_respawn_delay(then: Callable) -> void:
	get_tree().create_timer(float(_sandbox.get("respawn_s", 3.0))).timeout.connect(then)


func perf_note() -> String:
	return "  ship spawn %.1f ms (%d tiles)" % [last_spawn_usec / 1000.0, ship.blueprint.tiles.size() if ship else 0]


## Leaves the flight: in a cinematic one, after the dock screen. A run left alive is recorded
## as it stands.
func close() -> void:
	if run != null:
		_record_run(false)
	if cinematic and not dock.running:
		_touches.clear()
		pause_menu.visible = false
		results.visible = false
		_controls_panel.visible = false
		get_tree().paused = true
		dock.docked.connect(func() -> void:
			get_tree().paused = false
			closed.emit(), CONNECT_ONE_SHOT)
		dock.play(ship.blueprint if ship != null else null, _placement, _cine)
		return
	if dock.running:
		return
	get_tree().paused = false
	closed.emit()


## The run is over (the ship lost, or left from the pause menu): it adds up into the pilot's
## record, saved at once, and `run_bests` says which bests it beat. Once only.
func _record_run(died: bool) -> void:
	if _run_recorded or profile == null:
		return
	_run_recorded = true
	run_bests = profile.record_run(run.score(), run.wave, floori(run.seconds), run.kills, died)
	Profiles.save(profile)


## The ship's lost in a run: its escape pod bursts out of the wreck and burns for the bay.
func _launch_pod() -> void:
	var at := ship.global_transform * ship.center_of_mass
	var home := bay.global_position if bay != null else Vector2.ZERO
	var heading := (home - at).angle() if at.distance_to(home) > PX else ship.global_rotation
	_world.add_child(EscapePod.launch(at, ship.linear_velocity, heading,
			float(_cine.get("pod_speed_u", 5.0)), float(_cine.get("pod_accel_u_s2", 9.0))))


## The guns fire as many shots as the power-up running says (1 when none is).
func _apply_power() -> void:
	if weapons != null:
		weapons.shots_each = power.shots()
		weapons.spread_rad = deg_to_rad(power.spread_deg)


## The launch is over: the player has the ship, and the fight (or the practice target) comes.
func _end_launch() -> void:
	launch_left = 0.0
	controls.visible = true
	if weapons != null:
		weapons.hold_fire = false
	if test_level == 0:
		spawn(SPAWN_ENEMIES, str(_sandbox.get("start_target", "target_barge")))


## Pauses the flight under the pause menu (6.5).
func open_pause() -> void:
	if pause_menu.visible or spawn_list.visible or picker.visible or results.visible or dock.running:
		return
	_touches.clear()  # a panel over the fingers takes their release
	controls.stick.reset()
	controls.fire.reset()
	pause_menu.visible = true
	get_tree().paused = true


func resume() -> void:
	pause_menu.visible = false
	_controls_panel.visible = false
	get_tree().paused = false


## The Android back button (through the hangar): it closes whatever is open, and otherwise
## pauses or resumes. It never lands straight away; Return to hangar is in the pause menu.
func on_back() -> void:
	if dock.running:
		return
	if results.visible:
		close()
	elif _controls_panel.visible:
		_open_controls_panel(false)
	elif spawn_list.visible:
		_close_spawner()
	elif picker.visible:
		_close_switch()
	elif pause_menu.visible:
		resume()
	else:
		open_pause()


## Switching away from the app mid-flight pauses it, so coming back finds the game waiting.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] and is_inside_tree():
		open_pause()


func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false  # never leave the game paused behind a closed sandbox


## SWITCH: pause and list the manual weapons (4.7).
func open_switch() -> void:
	_touches.clear()  # a panel over the fingers takes their release
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


func _process(delta: float) -> void:
	if test != null:
		test.tick(delta)
	if _fade_in.visible:
		_fade_in.modulate.a -= delta / maxf(float(_cine.get("fade_s", 0.35)), 0.01)
		_fade_in.visible = _fade_in.modulate.a > 0.0
	if run != null and launch_left <= 0.0 and run.tick(delta):
		_start_wave()
	if power != null and power.tick(delta):
		_apply_power()
	if Engine.get_process_frames() % 2 == 0:  # the HUD's frames (below)
		run_hud.show_cargo(cargo)
		if run != null:
			run_hud.show_run(run)
			run_hud.show_power(power)
	if ship == null:
		_hud.text = _note
		return
	if launch_left > 0.0:
		pilot.stick = Vector2.from_angle(ship.global_rotation)  # out of the bay, on its own
		launch_left -= delta
		if launch_left <= 0.0:
			_end_launch()
		return
	pilot.stick = controls.stick_value()
	weapons.fire_held = controls.is_firing()
	weapons.all_auto = Settings.get_value(&"control_scheme") != "2-stick"
	if _picked >= 0:
		_overlay.queue_redraw()  # the highlight follows its ship
	# Nobody reads the status line or the edge marks 60 times a second (owner, 2026-10-28): the
	# HUD takes the even frames and the marks the odd ones. The stick and FIRE stay every frame.
	if Engine.get_process_frames() % 2 == 1:
		var marking := Time.get_ticks_usec()
		markers.point_at(_camera, _marks())
		BenchRun.spent(&"markers", marking)
		return
	var started := Time.get_ticks_usec()
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
	if is_instance_valid(carrier) and carrier.damage != null:
		parts.append("carrier %d%%" % roundi(_hull_share(carrier) * 100.0))
	if Time.get_ticks_msec() < _note_until:
		parts.append(_note)
	_hud.text = "  ·  ".join(parts)
	BenchRun.spent(&"hud", started)


## The edge marks: the carrier's arrow, and a dot for each enemy seen and still in sight range.
func _marks() -> Array:
	var marks: Array = []
	var seen := {}
	for enemy: ShipBody in spawner.live():
		var id := enemy.get_instance_id()
		if enemy.global_position.distance_to(ship.global_position) > markers.sight_range_u * PX:
			continue
		if _seen.has(id) or markers.on_screen(_camera, enemy.global_position):
			seen[id] = true
			marks.append([enemy.global_position, ENEMY_MARK, true])
	_seen = seen
	if is_instance_valid(carrier):
		marks.append([carrier.global_position, CARRIER_MARK])
	return marks


static func _hull_share(body: ShipBody) -> float:
	var left := 0.0
	var full := 0.0
	for tile_id: int in body.damage.hp:
		full += body.damage.max_hp[tile_id]
		if body.damage.is_attached(tile_id):
			left += body.damage.hp[tile_id]
	return left / full if full > 0.0 else 0.0


func _physics_process(_delta: float) -> void:
	# The sandbox's soft wall, for the player and a flying target. Story mode opens the world map
	# at the edge instead (4.10).
	for body: ShipBody in Spawner.alive([ship, carrier], enemies):
		body.apply_central_force(arena.push(body.global_position / PX) * body.mass * PX)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		open_pause()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"switch_weapon") and weapons != null:
		weapons.gunnery.cycle()
		return
	if event.is_action_pressed(&"zoom_in", true) or event.is_action_pressed(&"zoom_out", true):
		_camera.zoom_by(_camera.zoom_step if event.is_action(&"zoom_in") else 1.0 / _camera.zoom_step)
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var wheel := (event as InputEventMouseButton).button_index
		if wheel == MOUSE_BUTTON_WHEEL_UP or wheel == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.zoom_by(_camera.zoom_step if wheel == MOUSE_BUTTON_WHEEL_UP else 1.0 / _camera.zoom_step)
		return
	if event is InputEventMagnifyGesture:  # a laptop's touchpad pinch
		_camera.zoom_by((event as InputEventMagnifyGesture).factor)
		return
	if event is InputEventScreenDrag:
		_pinch(event as InputEventScreenDrag)
		return
	# Touches only: a mouse click arrives as a touch too (emulate_touch_from_mouse), and taking
	# both would hit twice.
	if not event is InputEventScreenTouch:
		return
	var touch := event as InputEventScreenTouch
	if not touch.pressed:
		if _touches.has(touch.index):
			_touches.erase(touch.index)
			_camera.save_zoom()
		return
	_touches[touch.index] = touch.position
	if _touches.size() > 1:
		return  # the second finger of a pinch doesn't pick
	var world_point: Vector2 = _camera.get_canvas_transform().affine_inverse() * (event as InputEventFromWindow).position
	var hit := ship_tile_at_point(world_point)
	_picked_ship = hit[0]
	_picked = hit[1]
	if _picked_ship != null and test_hit > 0.0:
		_test_hit(_picked_ship, _picked)
	_overlay.queue_redraw()
	_show_status()


## Two fingers on open space zoom the view by how far apart they spread (owner, 2026-10-26).
func _pinch(drag: InputEventScreenDrag) -> void:
	if not _touches.has(drag.index):
		return  # the stick's finger, or FIRE's
	var previous: Vector2 = _touches[drag.index]
	_touches[drag.index] = drag.position
	if _touches.size() < 2:
		return
	for index: int in _touches:
		if index != drag.index:
			var anchor: Vector2 = _touches[index]
			var before := previous.distance_to(anchor)
			if before > 1.0:
				_camera.zoom_by(drag.position.distance_to(anchor) / before, false)
			return


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
	numbers.name = "DamageNumbers"
	numbers.camera = _camera
	numbers.configure(_flight.get("damage_numbers", {}))
	ui.add_child(numbers)
	run_hud.name = "RunHud"
	ui.add_child(run_hud)
	_edge_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_edge_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_edge_glow)
	markers.name = "EdgeMarkers"
	markers.configure(_flight.get("edge_markers", {}))
	ui.add_child(markers)
	_status.position = Vector2(16, 12)
	_status.add_theme_font_size_override(&"font_size", 20)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_status)
	_hud.position = Vector2(16, 44)
	_hud.add_theme_font_size_override(&"font_size", 20)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_hud)
	var pause := Button.new()
	pause.name = "Pause"
	pause.text = "Pause"
	pause.size = Vector2(132, 56)
	if Assets.has_real_art(&"vis.icon.pause"):
		pause.text = ""
		pause.icon = Assets.tex(&"vis.icon.pause")
		pause.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pause.add_theme_constant_override(&"icon_max_width", 34)
		pause.size = Vector2(72, 56)
		pause.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pause.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 16)
	pause.pressed.connect(open_pause)
	ui.add_child(pause)
	_level_button.text = _level_text()
	_level_button.size = Vector2(132, 56)
	_level_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 16)
	_level_button.position.y += 64
	_level_button.pressed.connect(_next_gun_level)
	_level_button.visible = stock == null and test_level == 0  # a stocked ship's guns are at their own levels
	ui.add_child(_level_button)
	_spawn_button.text = "Spawn"
	_spawn_button.size = Vector2(132, 56)
	_spawn_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 16)
	_spawn_button.position.y += 128
	_spawn_button.pressed.connect(open_spawner)
	_spawn_button.visible = test_level == 0  # a test fight is the fight
	ui.add_child(_spawn_button)
	spawn_list.name = "SpawnPicker"
	spawn_list.visible = false
	spawn_list.picked.connect(_close_spawner)
	ui.add_child(spawn_list)
	picker.name = "WeaponPicker"
	picker.visible = false
	picker.picked.connect(_close_switch)
	ui.add_child(picker)
	pause_menu.name = "PauseMenu"
	pause_menu.resumed.connect(resume)
	pause_menu.settings_requested.connect(_open_controls_panel.bind(true))
	pause_menu.hangar_requested.connect(close)
	ui.add_child(pause_menu)
	results.name = "TestResults"
	results.again_requested.connect(func() -> void: again.emit(test_level))
	results.hangar_requested.connect(close)
	ui.add_child(results)
	_controls_panel = ControlsPanel.new()
	_controls_panel.process_mode = Node.PROCESS_MODE_ALWAYS  # opened from the pause menu
	_controls_panel.visible = false
	ui.add_child(_controls_panel)
	controls.visible = launch_left <= 0.0
	_fade_in.name = "FadeIn"
	_fade_in.color = Color.BLACK
	_fade_in.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_in.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_in.visible = cinematic
	ui.add_child(_fade_in)
	dock.name = "DockScreen"
	ui.add_child(dock)


## Steps every gun through the sandbox's `gun_levels`, then back to their own levels (0).
func _next_gun_level() -> void:
	var levels: Array = [0] + (_sandbox.get("gun_levels", [1, 10, 100, 999]) as Array).map(func(v: Variant) -> int: return int(v))
	gun_level = levels[(levels.find(gun_level) + 1) % levels.size()]
	_level_button.text = _level_text()
	if ship != null:
		ship.gun_level = maxi(gun_level, 1)
		ship.own_levels = gun_level == 0
		ship.guns = GunLayout.compute(ship.blueprint, ship.placement, ship.gun_level, {}, 1.0, ship.own_levels)
		weapons.gunnery.set_layout(ship.guns)


func _level_text() -> String:
	return "Guns: own" if gun_level == 0 else "Guns L%d" % gun_level


## The settings, over the pause menu (6.5); Done goes back to it.
func _open_controls_panel(open: bool) -> void:
	_touches.clear()  # a panel over the fingers takes their release
	_controls_panel.visible = open
	# Opened from the pause menu, it covers it; closing it goes back to it while still paused.
	pause_menu.visible = not open and get_tree().paused and not spawn_list.visible and not picker.visible
	if open:
		_controls_panel.refresh()
		_controls_panel.reset_size()
		_controls_panel.position = (_controls_panel.get_viewport_rect().size - _controls_panel.size) * 0.5


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

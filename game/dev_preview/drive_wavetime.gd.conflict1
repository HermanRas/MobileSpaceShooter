extends "res://dev_preview/drive_shop.gd"
## Drives 8.1's "done when": a WaveTime run starts, escalates and ends in death. A new pilot's
## WaveTime hangar: Fly opens the launch panel with Start run; the hangar fades out and the ship
## boosts out of the launch bay on its own, then the run's first wave comes in off screen holding
## its fire until seen (8.7); the starter sits still with every gun on auto, clears wave 1, and
## wave 2 comes after the breather, at a higher level; a wave left standing is joined by the next
## at the minute; the ship is destroyed and its escape pod flies off, the results card shows how
## far it got, and Return to hangar docks the pod and banks the cargo and the guns' XP. A second
## run's Fly again starts over at wave 1, and Return to hangar from the pause menu docks the ship.
## Time runs at TIME_SCALE. Run with `tools/drive.sh res://dev_preview/drive_wavetime.tscn`.
## Exit 0 = passed. Pilots live in a scratch folder.

const TIME_SCALE := 4.0
## Game seconds the idle starter gets to clear wave 1.
const CLEAR_S := 90.0


func _ready() -> void:
	OS.add_logger(_spy)
	_real_root = Profiles.root
	_wipe_dir(ROOT)
	Profiles.root = ROOT
	Profiles.reload()
	Profiles.active_id = Profiles.create("Wave").id
	await _open_hangar()
	_check(_hangar.stocked(), "the pilot's WaveTime hangar is stocked")

	await _step_fly_offers_a_run()
	var sandbox: FlightSandbox = await _step_the_ship_launches()
	if sandbox != null:
		await _step_wave_1_holds_fire_until_seen(sandbox)
		await _step_waves_escalate(sandbox)
		await _step_death_ends_the_run(sandbox)
		await _step_the_pod_docks(sandbox)
		await _step_fly_again_and_the_ship_docks()

	Engine.time_scale = 1.0
	if _hangar != null:
		_hangar.queue_free()
	Profiles.active_id = ""
	Profiles.root = _real_root
	Profiles.reload()
	_wipe_dir(ROOT)
	OS.remove_logger(_spy)
	for error in _spy.seen:
		_failures.append("script error: " + error)
	if _failures.is_empty():
		print("drive_wavetime: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			printerr("drive_wavetime: FAIL  " + failure)
		get_tree().quit(1)


func _step_fly_offers_a_run() -> void:
	await _tap_button(_hangar._fly_button)
	var launch: LaunchPanel = _hangar._launch
	var run := launch.find_child("StartRun", true, false) as Button
	_check(launch.visible and run != null and run.visible, "in WaveTime, Fly offers Start run")
	_check(not (launch.find_child("TestLevel", true, false) as Control).visible
			and not (launch.find_child("PerformanceTest", true, false) as Control).visible,
			"and none of Creative's test flights")
	await _frames(2)
	_save_shot("drive_wavetime_launch.png")
	await _tap_button(run)


## Start run: the hangar fades out, then the ship boosts out of the bay on its own, with no wave
## and no controls until it's out. Returns the flight, or null.
func _step_the_ship_launches() -> FlightSandbox:
	_check(_hangar._sandbox == null and _hangar._fade.visible, "the hangar fades out first")
	var limit_ms := Time.get_ticks_msec() + 3000
	while _hangar._sandbox == null and Time.get_ticks_msec() < limit_ms:
		await _frames(1)
	var sandbox: FlightSandbox = _hangar._sandbox
	_check(sandbox != null and sandbox.run != null and sandbox.cinematic, "then a WaveTime run flies, with the launch")
	if sandbox == null or sandbox.run == null:
		return null
	_check(sandbox.bay != null and sandbox.launch_left > 0.0 and not sandbox.controls.visible and sandbox.enemies.is_empty(),
			"the ship sits in the launch bay: no controls, no wave yet")
	var mouth_x := sandbox.bay.global_position.x
	await _frames(20)
	_save_shot("drive_wavetime_bay.png")
	limit_ms = Time.get_ticks_msec() + 8000
	while sandbox.launch_left > 0.0 and Time.get_ticks_msec() < limit_ms:
		await _frames(1)
	_check(sandbox.ship.global_position.x > mouth_x and sandbox.ship.linear_velocity.x > 0.0,
			"it boosts out of the bay on its own (%.1f U past the mouth)" % ((sandbox.ship.global_position.x - mouth_x) / ShipMesh.PX_PER_U))
	await _physics_frames(2)
	await _frames(2)
	_check(sandbox.controls.visible and sandbox.run.wave == 1, "then the player has it, and wave 1 comes")
	return sandbox


func _step_wave_1_holds_fire_until_seen(sandbox: FlightSandbox) -> void:
	var run := sandbox.run
	_check(run.wave == 1 and run.level() == run.levels[0] and sandbox.enemies.size() > 0,
			"wave 1 comes in at level %d (%d enemies)" % [run.level(), sandbox.enemies.size()])
	_check(not sandbox._spawn_button.visible and not sandbox._level_button.visible, "no Spawn or Guns button in a run")
	# The first frame can take a second in the container, and physics catches up, so a fast enemy
	# may already be in view: check the rule, not a moment. No enemy fires early out of view.
	var grace := float(Data.table(&"flight")["spawner"]["fire_grace_s"])
	var early: PackedStringArray = []
	var waited := 0.0
	while waited < grace + 0.5:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
		for enemy: ShipBody in sandbox.enemies:
			var guns := _guns(enemy)
			if guns == null:
				continue
			if not guns.hold_fire and run.seconds < grace - 0.2 and sandbox.ship != null and not SpawnRing.in_view(
					sandbox.ship.global_position / ShipMesh.PX_PER_U, sandbox.spawner.view_half_u.call(),
					enemy.global_position / ShipMesh.PX_PER_U, Spawner.reach_u(enemy.blueprint, sandbox._placement) + 1.0):
				early.append(enemy.blueprint.name)
	_check(early.is_empty(), "no enemy opens fire out of view within the grace (%s)" % ", ".join(early))
	var still := sandbox.enemies.filter(func(enemy: ShipBody) -> bool: return _guns(enemy) != null and _guns(enemy).hold_fire)
	_check(still.is_empty(), "past the grace (%.1f s), they're all free to fire" % grace)
	_check(sandbox._hud.text.contains("wave 1 (L%d)" % run.level()), "the HUD shows the wave (%s)" % sandbox._hud.text)


func _step_waves_escalate(sandbox: FlightSandbox) -> void:
	var run := sandbox.run
	Engine.time_scale = TIME_SCALE
	var limit_ms := Time.get_ticks_msec() + int((CLEAR_S / TIME_SCALE + 10.0) * 1000.0)
	while run.wave < 2 and sandbox.ship != null and Time.get_ticks_msec() < limit_ms:
		sandbox.weapons.all_auto = true
		await _physics_frames(10)
	Engine.time_scale = 1.0
	_check(run.waves_cleared >= 1 and run.wave == 2, "the idle starter clears wave 1 (%s), and wave 2 follows" % TestFlight.clock(run.seconds))
	_check(run.seconds < run.wave_s, "after the breather, not the minute (%.1f s)" % run.seconds)
	_check(run.level() > run.level_for(1), "at a higher level (L%d)" % run.level())
	await _frames(2)
	_save_shot("drive_wavetime_wave2.png")
	# A wave left standing is joined by the next at the minute.
	if sandbox.enemies.is_empty() or sandbox.ship == null:
		_check(false, "wave 2 is still up to be joined")
		return
	var before := sandbox.enemies.size()
	run.wave_seconds = run.wave_s - 0.05
	await _physics_frames(10)
	_check(run.wave == 3 and sandbox.enemies.size() > before,
			"at the minute, wave 3 joins wave 2 (%d -> %d enemies)" % [before, sandbox.enemies.size()])


func _step_death_ends_the_run(sandbox: FlightSandbox) -> void:
	var run := sandbox.run
	_destroy(sandbox.ship)
	_check(run.over and sandbox.ship == null, "the ship is destroyed and the run is over")
	var pod := sandbox._world.find_child("EscapePod", true, false) as EscapePod
	_check(pod != null, "its escape pod bursts out")
	var pod_from := pod.position if pod != null else Vector2.ZERO
	await _frames(20)
	_save_shot("drive_wavetime_pod.png")
	_check(pod != null and is_instance_valid(pod) and pod.position.distance_to(pod_from) > ShipMesh.PX_PER_U,
			"and flies off")
	var limit_ms := Time.get_ticks_msec() + 6000
	while not sandbox.results.visible and Time.get_ticks_msec() < limit_ms:
		await _frames(5)
	_check(sandbox.results.visible and get_tree().paused, "the results card shows, paused")
	var title := sandbox.results._title.text
	_check(title == "Destroyed in wave %d" % run.wave, "it says how far the run got (%s)" % title)
	var lines: PackedStringArray = []
	for label in sandbox.results._lines.get_children():
		lines.append((label as Label).text)
	_check(lines.size() == run.lines().size() + 1 and lines[3] == "Kills: %d" % run.kills and lines[-1].begins_with("Cargo: "),
			"with the waves, time, kills, damage and cargo (%s)" % ", ".join(lines))
	await _frames(3)
	_save_shot("drive_wavetime_results.png")
	var waited := run.seconds
	await _physics_frames(30)
	_check(run.seconds == waited and run.wave == 3, "no more waves after the end")


## Return to hangar from the results card: the pod glides into the bay, the shutter closes, and
## the hangar fades back in with the run's cargo and XP banked and saved.
func _step_the_pod_docks(sandbox: FlightSandbox) -> void:
	var stock: Inventory = _hangar.editor.stock
	var gc := stock.amount(Inventory.GC) + sandbox.cargo.amount(Inventory.GC)
	sandbox.results.hangar_requested.emit()
	await _frames(2)
	_check(sandbox.dock.running and sandbox.dock._title.text == "Pod recovered" and _hangar._sandbox == sandbox,
			"Return to hangar plays the dock screen, with the pod")
	await _frames(40)
	_save_shot("drive_wavetime_dock_pod.png")
	await _until_landed()
	_check(_hangar._fade.visible, "the hangar fades back in")
	_check(stock.amount(Inventory.GC) == gc, "the run's cargo banks into the pilot's stock")
	var xp := 0
	for id: String in stock.guns:
		xp += (stock.guns[id] as Inventory.GunItem).xp
	_check(xp > 0, "the run's kills levelled the guns (%d XP)" % xp)
	await _open_hangar()
	var saved := 0
	for id: String in _hangar.editor.stock.guns:
		saved += (_hangar.editor.stock.guns[id] as Inventory.GunItem).xp
	_check(saved == xp and _hangar.editor.stock.amount(Inventory.GC) == gc, "and both are saved")


## A second run: lost straight after launch, Fly again starts a fresh run at wave 1 (no dock), and
## Return to hangar from its pause menu docks the ship itself.
func _step_fly_again_and_the_ship_docks() -> void:
	await _tap_button(_hangar._fly_button)
	await _tap_button(_hangar._launch.find_child("StartRun", true, false))
	var first: FlightSandbox = await _launched()
	if first == null:
		return
	_destroy(first.ship)
	var limit_ms := Time.get_ticks_msec() + 5000
	while not first.results.visible and Time.get_ticks_msec() < limit_ms:
		await _frames(5)
	first.results.again_requested.emit()
	await _frames(4)
	var again: FlightSandbox = _hangar._sandbox
	_check(again != null and again != first and again.run != null and again.launch_left > 0.0,
			"Fly again starts a fresh run, straight into its launch")
	if again == null:
		return
	again = await _launched()
	_check(again != null and again.run.wave == 1, "at wave 1")
	if again == null:
		return
	again.open_pause()
	again.pause_menu.hangar_requested.emit()
	await _frames(2)
	_check(again.dock.running and again.dock._title.text == "Docking" and not again.pause_menu.visible,
			"Return to hangar from the pause menu docks the ship")
	again.on_back()
	await _frames(2)
	_check(again.dock.running, "the back gesture doesn't cut it short")
	await _frames(60)
	_save_shot("drive_wavetime_dock_ship.png")
	await _until_landed()
	_check(not get_tree().paused, "landed, unpaused")


## Waits out the launch of the flight now open. Returns it, or null.
func _launched() -> FlightSandbox:
	var limit_ms := Time.get_ticks_msec() + 8000
	while (_hangar._sandbox == null or _hangar._sandbox.launch_left > 0.0) and Time.get_ticks_msec() < limit_ms:
		await _frames(1)
	await _frames(2)
	var sandbox: FlightSandbox = _hangar._sandbox
	_check(sandbox != null and sandbox.launch_left <= 0.0 and sandbox.ship != null, "the run launches")
	return sandbox


func _until_landed() -> void:
	var limit_ms := Time.get_ticks_msec() + 8000
	while _hangar._sandbox != null and Time.get_ticks_msec() < limit_ms:
		await _frames(2)
	_check(_hangar._sandbox == null, "docked and back in the hangar")


func _destroy(ship: ShipBody) -> void:
	for tile_id: int in ship.damage.hp.keys():
		if is_instance_valid(ship) and not ship.is_wreck() and ship.damage.is_attached(tile_id):
			ship.take_hit(tile_id, 1.0e6, &"kinetic")


func _guns(enemy: ShipBody) -> WeaponController:
	return enemy.get_node_or_null("Weapons") as WeaponController if is_instance_valid(enemy) else null


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	print("drive_wavetime: %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures.append(what)

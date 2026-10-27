extends "res://dev_preview/drive_hangar.gd"
## Drives Creative's test flight (Phase 7.2): Fly opens the launch panel, the back gesture closes
## it, a test fight comes in at the slider's level with no Spawn button and no respawn, and its end
## shows the results card, whose Fly again restarts the level and Return to hangar lands.
##
## And the "done when", measured: the starter sits still with every gun on auto. At level 1 it
## clears the fight; at level 100 it's destroyed fast. Time runs at TIME_SCALE so it doesn't take
## minutes. Run with `tools/drive.sh res://dev_preview/drive_testflight.tscn`. Exit 0 = passed.

const TIME_SCALE := 4.0
## Game seconds the starter gets to clear level 1, and that level 100 may take to destroy it.
const EASY_S := 90.0
const BRUTAL_S := 20.0


func _ready() -> void:
	OS.add_logger(_spy)
	Profiles.active_id = ""  # Creative
	_hangar = (load("res://scenes/hangar/hangar.tscn") as PackedScene).instantiate()
	add_child(_hangar)
	await _frames(5)
	var errors: PackedStringArray = []
	_hangar.load_blueprint(Blueprint.from_dict(Data.json_dir("blueprints")["starter"], errors))
	await _frames(3)

	await _step_fly_opens_the_launch_panel()
	var easy := await _fight(1)
	_check(easy.outcome == TestFlight.Outcome.CLEARED,
			"level 1 is easy: the idle starter clears it (%s, %s)" % [easy.title(), ", ".join(easy.lines())])
	await _step_the_results_card(easy)
	var brutal := await _fight(100)
	_check(brutal.outcome == TestFlight.Outcome.DESTROYED and brutal.seconds <= BRUTAL_S,
			"level 100 is brutal: destroyed in %.1f s (%s)" % [brutal.seconds, ", ".join(brutal.lines())])
	await _frames(5)
	_save_shot("drive_testflight_results.png")
	_hangar._sandbox.results.hangar_requested.emit()
	await _frames(3)
	_check(_hangar._sandbox == null and not get_tree().paused, "Return to hangar lands, unpaused")

	Engine.time_scale = 1.0
	OS.remove_logger(_spy)
	for error in _spy.seen:
		_failures.append("script error: " + error)
	if _failures.is_empty():
		print("drive_testflight: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			printerr("drive_testflight: FAIL  " + failure)
		get_tree().quit(1)


func _step_fly_opens_the_launch_panel() -> void:
	_tool("Fly").pressed.emit()
	await _frames(2)
	var launch: LaunchPanel = _hangar._launch
	_check(launch.visible and _hangar._sandbox == null, "in Creative, Fly opens the launch panel")
	_check(launch.max_level == 100, "its level slider runs to 100 (data/levels.json)")
	_hangar.on_back()
	await _frames(2)
	_check(not launch.visible and _hangar._sandbox == null, "the back gesture closes it")


## Flies a test fight at `level` from the launch panel, sitting still with every gun on auto,
## until the results card shows. Returns the fight's record.
func _fight(level: int) -> TestFlight:
	if _hangar._sandbox == null:
		_tool("Fly").pressed.emit()
		await _frames(2)
		var slider := _hangar._launch.find_child("TestLevel", true, false) as HSlider
		slider.value = level
		(_hangar._launch.find_child("Testfight", true, false) as Button).pressed.emit()
	await _frames(3)
	var sandbox: FlightSandbox = _hangar._sandbox
	_check(sandbox != null and sandbox.test_level == level and sandbox.test != null, "a level %d test fight flies" % level)
	if sandbox == null or sandbox.test == null:
		return TestFlight.start(level, 0)
	_check(not sandbox._spawn_button.visible and not sandbox._level_button.visible, "no Spawn or Guns button in it")
	_check(sandbox.enemies.size() > 0 and sandbox.enemies.size() == sandbox.test.enemies,
			"the generated fight comes in (%d enemies)" % sandbox.enemies.size())
	Engine.time_scale = TIME_SCALE
	var limit_ms := Time.get_ticks_msec() + int((EASY_S / TIME_SCALE + 10.0) * 1000.0)
	while not sandbox.results.visible and Time.get_ticks_msec() < limit_ms:
		if sandbox.weapons != null:
			sandbox.weapons.all_auto = true
		await _physics_frames(10)
	Engine.time_scale = 1.0
	_check(sandbox.results.visible and get_tree().paused, "the fight ends on the results card, paused")
	return sandbox.test


func _step_the_results_card(flight: TestFlight) -> void:
	var sandbox: FlightSandbox = _hangar._sandbox
	_save_shot("drive_testflight_cleared.png")
	_check(sandbox.ship != null, "no respawn needed: the starter survived")
	_check(flight.kills == flight.enemies, "every enemy counted as a kill (%d of %d)" % [flight.kills, flight.enemies])
	_check(flight.seconds > 1.0, "the clock ran (%s)" % TestFlight.clock(flight.seconds))
	sandbox.results.again_requested.emit()
	await _frames(4)
	_check(_hangar._sandbox != null and _hangar._sandbox != sandbox and _hangar._sandbox.test_level == 1,
			"Fly again restarts the same level in a fresh flight")
	# Into level 100 from here: back to the hangar, then the panel.
	_hangar._sandbox.close()
	await _frames(3)


func _tool(text: String) -> Button:
	for button in _hangar.find_children("*", "Button", true, false):
		if (button as Button).text == text and not button.is_queued_for_deletion():
			return button
	return null


func _check(ok: bool, what: String) -> void:
	print("drive_testflight: %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

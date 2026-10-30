extends "res://dev_preview/drive_shop.gd"
## A tuning measure for 8.7, not a pass/fail drive: a fresh pilot's starter flies RUNS WaveTime runs
## sitting still with every gun on auto, banking each run's cargo, and the log says how long each
## lasted, how far it got, and what it banked against what upgrades cost. An idle ship is a floor,
## not a player: a real pilot dodges and lasts longer. Time runs at TIME_SCALE.
## Run with `tools/drive.sh res://dev_preview/measure_runs.tscn`.

const RUNS := 3
const TIME_SCALE := 4.0
## Game seconds before a run is cut off.
const LIMIT_S := 600.0


func _ready() -> void:
	_real_root = Profiles.root
	_wipe_dir(ROOT)
	Profiles.root = ROOT
	Profiles.reload()
	Profiles.active_id = Profiles.create("Measure").id
	await _open_hangar()
	_hangar.cinematics = false
	var placement: Placement = _hangar.placement
	var armor: Dictionary = placement.tiles.tile(&"armor").cost(&"L")
	print("measure: prices  armor L %s · hull L %s · gatling %d GC · cannon %d GC" % [Inventory.cost_text(armor),
			Inventory.cost_text(placement.tiles.tile(&"hull").cost(&"L")), int(placement.weapons.weapon(&"gatling_single")["price_gc"]),
			int(placement.weapons.weapon(&"cannon")["price_gc"])])
	for n in RUNS:
		var sandbox: FlightSandbox = _hangar.fly(FlightSandbox.WAVETIME)
		await _frames(3)
		Engine.time_scale = TIME_SCALE
		var limit_ms := Time.get_ticks_msec() + int((LIMIT_S / TIME_SCALE + 30.0) * 1000.0)
		while not sandbox.run.over and sandbox.run.seconds < LIMIT_S and Time.get_ticks_msec() < limit_ms:
			if sandbox.weapons != null:
				sandbox.weapons.all_auto = true
			await get_tree().physics_frame
		Engine.time_scale = 1.0
		var run := sandbox.run
		print("measure: run %d  %s  wave %d (L%d)  cleared %d  kills %d  score %d  damage %d  cargo: %s%s" % [n + 1,
				TestFlight.clock(run.seconds), run.wave, run.level(), run.waves_cleared, run.kills, run.score(),
				roundi(run.damage_taken), sandbox.cargo_text().trim_prefix("cargo "), "" if run.over else "  (cut off, alive)"])
		sandbox.close()
		await _frames(3)
	print("measure: wallet after %d runs: %s" % [RUNS, Inventory.cost_text(_hangar.editor.stock.wallet)])
	_hangar.queue_free()
	Profiles.active_id = ""
	Profiles.root = _real_root
	Profiles.reload()
	_wipe_dir(ROOT)
	get_tree().quit(0)

extends "res://dev_preview/drive_shop.gd"
## Drives 7.5: Creative's Fly → Performance test flies §5.5's worst case (40 enemies, the station,
## 600 shots) and ends on a results card with the frame times; the run is kept in
## user://perf_runs.json (put back as it was afterwards). The tools container renders on the CPU,
## so its numbers only show the run works; the phone (or a native PC run) gives the real ones.
## Run with `tools/drive.sh res://dev_preview/drive_bench.tscn`. Exit code 0 = every step passed.

const WAIT_S := 60.0


func _ready() -> void:
	OS.add_logger(_spy)
	var kept := FileAccess.get_file_as_string(BenchRun.RUNS_PATH) if FileAccess.file_exists(BenchRun.RUNS_PATH) else ""
	Profiles.active_id = ""
	await _open_hangar()
	_hangar.preview_setup({"ship": "gunboat"})
	await _frames(3)
	await _tap_button(_hangar._fly_button)
	_check(_hangar._launch.visible, "Fly opens the launch panel")
	await _tap_button(_hangar._launch.find_child("PerformanceTest", true, false))
	var sandbox: FlightSandbox = _hangar._sandbox
	_check(sandbox != null and sandbox.bench_run != null, "Performance test flies the bench")
	if sandbox != null and sandbox.bench_run != null:
		await _step_the_run(sandbox)
	if kept.is_empty():
		DirAccess.remove_absolute(BenchRun.RUNS_PATH)
	else:
		var file := FileAccess.open(BenchRun.RUNS_PATH, FileAccess.WRITE)
		file.store_string(kept)
	_hangar.queue_free()
	OS.remove_logger(_spy)
	for error in _spy.seen:
		_failures.append("script error: " + error)
	if _failures.is_empty():
		print("drive_bench: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			printerr("drive_bench: FAIL  " + failure)
		get_tree().quit(1)


func _step_the_run(sandbox: FlightSandbox) -> void:
	var cfg: Dictionary = Data.table(&"flight")["bench"]
	var started := Time.get_ticks_msec()
	var peak_ships := 0
	while sandbox.bench_run.run.is_empty() and Time.get_ticks_msec() - started < WAIT_S * 1000.0:
		peak_ships = maxi(peak_ships, sandbox.spawner.live().size())
		if Time.get_ticks_msec() - started > 8000 and Time.get_ticks_msec() - started < 8100:
			_save_shot("drive_bench_flight.png")
		await _frames(1)
	var run := sandbox.bench_run.run
	_check(not run.is_empty(), "the run finishes")
	if run.is_empty():
		return
	var s: Dictionary = run["summary"]
	_check(peak_ships == int(cfg["enemies"]) + 1, "40 enemies and the station fly (peak %d)" % peak_ships)
	_check(float(s["shots"]) >= float(cfg["shots"]) * 0.9, "about 600 shots live (%.0f)" % s["shots"])
	_check(int(s["frames"]) > 0 and float(s["seconds"]) >= float(cfg["seconds"]) * 0.9, "%d frames timed over %.1f s" % [s["frames"], s["seconds"]])
	_check(is_instance_valid(sandbox.ship), "the player's ship lasts the run")
	var kept := Save.read_json(BenchRun.RUNS_PATH)
	_check((kept.get("runs", []) as Array).size() >= 1 and kept["runs"].back()["date"] == run["date"], "the run is kept")
	await _frames(3)
	_check(sandbox.results.visible and "fps" in _labels(sandbox.results)[1], "the results card shows it: %s" % ", ".join(_labels(sandbox.results)))
	_save_shot("drive_bench_results.png")
	print("drive_bench: PC numbers  %s" % JSON.stringify(s))
	sandbox.results.hangar_requested.emit()
	await _frames(4)
	_check(_hangar._sandbox == null, "Return to hangar lands")

extends Node
## Phase 4.4: one ramp of the shot stress test (scenes/debug/shot_stress.tscn) on this machine,
## printed as a table. Run with `tools/drive.sh res://dev_preview/drive_shots.tscn`.
## Exit code 0 = the ramp ran with no script errors and no shot was dropped below capacity.
## The phone's numbers are what count (PLAN.md 5.5); this is the PC's for comparison.

const ScriptErrorSpy := preload("res://dev_preview/script_error_spy.gd")

var _spy := ScriptErrorSpy.new()


func _ready() -> void:
	OS.add_logger(_spy)
	var stress: Node = (load("res://scenes/debug/shot_stress.tscn") as PackedScene).instantiate()
	add_child(stress)
	await stress.finished
	OS.remove_logger(_spy)
	var failures: PackedStringArray = []
	for error in _spy.seen:
		failures.append("script error: " + error)
	for row: Dictionary in stress.results:
		if row["dropped"] > 0 and row["shots"] <= ProjectilePool.CAPACITY:
			failures.append("%d shots: %d dropped" % [row["shots"], row["dropped"]])
	if failures.is_empty():
		print("drive_shots: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			printerr("drive_shots: FAIL  " + failure)
		get_tree().quit(1)

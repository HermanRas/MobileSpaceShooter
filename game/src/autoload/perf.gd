extends Node
## Debug builds only: every few seconds, prints the frame rate, the slowest frame, draw calls
## and memory (and the hangar's last edit refresh), so a phone check is `tools/android.sh perf`
## instead of guessing by eye. Release builds free this node at start.
##
## Lines also go to `user://perf.log` (cleared each launch): Honor phones drop app output from
## logcat, so print() alone never reaches the PC.

const INTERVAL_S := 5.0
const LOG_PATH := "user://perf.log"

var _elapsed := 0.0
var _worst_ms := 0.0
var _last_tick := 0
var _log: FileAccess


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)


func _process(delta: float) -> void:
	_elapsed += delta
	# Wall clock, not delta: Godot smooths delta, which hid a 29 ms hangar refresh as 16.7 ms.
	var now := Time.get_ticks_usec()
	if _last_tick > 0:
		_worst_ms = maxf(_worst_ms, (now - _last_tick) / 1000.0)
	_last_tick = now
	if _elapsed < INTERVAL_S:
		return
	var scene := get_tree().current_scene
	var line := "perf: %s  %d fps  worst %.1f ms  %d draw calls  %.0f MB" % [
		scene.scene_file_path.get_file() if scene else "-",
		Engine.get_frames_per_second(), _worst_ms,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
	] + (_refresh_note(scene) if scene and &"last_refresh_usec" in scene else "")
	print(line)
	if _log:
		_log.store_line(Time.get_time_string_from_system() + " " + line)
		_log.flush()
	_elapsed = 0.0
	_worst_ms = 0.0


static func _refresh_note(scene: Node) -> String:
	var parts: Array[String] = []
	var detail: Dictionary = scene.get(&"last_refresh_parts")
	for key: String in detail:
		parts.append("%s %.1f" % [key, detail[key] / 1000.0])
	return "  last refresh %.1f ms (%s)" % [scene.get(&"last_refresh_usec") / 1000.0, ", ".join(parts)]

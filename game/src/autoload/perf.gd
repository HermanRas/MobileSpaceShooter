extends Node
## Debug builds only: every few seconds, prints the frame rate, the slowest frame, draw calls
## and memory (plus the scene's own `perf_note()`, if it has one), so a phone check is `tools/android.sh perf`
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


## Writes a line of the caller's own to the log (and stdout), e.g. a stress test's summary.
func log_line(text: String) -> void:
	print(text)
	if _log:
		_log.store_line(Time.get_time_string_from_system() + " " + text)
		_log.flush()


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
	var line: String = "perf: %s  %d fps  worst %.1f ms  %d draw calls  %.0f MB" % [
		scene.scene_file_path.get_file() if scene else "-",
		Engine.get_frames_per_second(), _worst_ms,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
	] + (scene.perf_note() if scene and scene.has_method(&"perf_note") else "")
	print(line)
	if _log:
		_log.store_line(Time.get_time_string_from_system() + " " + line)
		_log.flush()
	_elapsed = 0.0
	_worst_ms = 0.0


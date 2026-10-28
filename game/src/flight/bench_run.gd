class_name BenchRun
extends Node
## The performance test (PLAN.md 7.5, D15), run inside a FlightSandbox flying the Creative ship:
## §5.5's worst case, from `data/flight.json` → bench. A station stand-in (Bench.station) sits
## ahead, roster enemies come in round the player and are replaced as they fall, and the
## projectile pool is topped up to `shots` with harmless sprays from the player (zero damage, so
## they cost the hit tests without ending anyone). The player's ship takes no damage, so the
## scenario holds. After `warmup_s`, every frame's wall-clock time goes into a Bench for
## `seconds`; then the run is kept in RUNS_PATH and shown on the results card.

signal finished(run: Dictionary)

## While a run is on, each system adds what its ticks cost here (`spent`), by name; the run reads
## and clears it every frame. Off, it costs a branch.
static var timing := false
static var costs := {}

## Every run kept on this device, oldest first: {"format", "runs": [{"date", "version",
## "device", "size", "ship_tiles", "scenario", "summary"}]}.
const RUNS_PATH := "user://perf_runs.json"
const PX := ShipMesh.PX_PER_U

var bench := Bench.new()
var run: Dictionary = {}
## The results card's lines: this run, then the ones before it (Bench.report).
var lines := PackedStringArray()

var _sandbox: FlightSandbox
var _cfg: Dictionary
var _ids: Array[StringName] = []
var _next := 0
var _station: ShipBody
var _station_bp: Blueprint
var _clock := 0.0
var _last_tick := 0
var _angle := 0.0
var _last_physics_frame := 0


## Adds the time since `since_usec` to `key`'s cost, while a run is timing.
static func spent(key: StringName, since_usec: int) -> void:
	if timing:
		costs[key] = int(costs.get(key, 0)) + Time.get_ticks_usec() - since_usec


func start(sandbox: FlightSandbox) -> void:
	_sandbox = sandbox
	timing = true
	costs.clear()
	_cfg = Data.table(&"flight").get("bench", {})
	var station_cfg: Dictionary = _cfg.get("station", {})
	_station_bp = Bench.station(int(station_cfg.get("cols", 15)), int(station_cfg.get("rows", 10)),
			station_cfg.get("guns", ["gatling_single"]))
	for entry in sandbox.roster.for_level(_level()):
		_ids.append(entry.id)
	_top_up_ships()


func _level() -> int:
	return int(_cfg.get("level", 20))


func _physics_process(_delta: float) -> void:
	if not run.is_empty():
		return
	_top_up_ships()
	_top_up_shots()


func _process(delta: float) -> void:
	if not run.is_empty():
		return
	var now := Time.get_ticks_usec()
	if _last_tick > 0 and _clock >= float(_cfg.get("warmup_s", 3.0)):
		bench.add_frame(now - _last_tick, _sandbox.spawner.live().size(), _sandbox.pool.count)
		# Physics runs at a fixed rate, so a slow frame runs several ticks to catch up (at most
		# max_physics_steps_per_frame; past that the game slows): the tick count and a tick's
		# cost say whether that's what makes it slow, and the systems' costs say which part.
		var ticks := Engine.get_physics_frames() - _last_physics_frame
		var per_tick := 1000.0 * maxi(ticks, 1)
		bench.add_parts({
			"ticks": ticks,
			"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"pool_ms": _sandbox.pool.step_usec / 1000.0,
			"ai_ms": int(costs.get(&"ai", 0)) / per_tick,
			"flight_ms": int(costs.get(&"flight", 0)) / per_tick,
			"guns_ms": int(costs.get(&"guns", 0)) / per_tick,
			"pairs": Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS),
		})
	costs.clear()
	_last_tick = now
	_last_physics_frame = Engine.get_physics_frames()
	_clock += delta
	if _clock >= float(_cfg.get("warmup_s", 3.0)) + float(_cfg.get("seconds", 20.0)):
		_finish()


## Brings the enemies back up to `enemies` (a few a tick, as a wave would) and the station back.
func _top_up_ships() -> void:
	var spawner := _sandbox.spawner
	if not is_instance_valid(_station) or _station.is_wreck():
		_station = spawner.spawn_design(_station_bp, _level())
	var want := int(_cfg.get("enemies", 40)) + 1  # and the station
	for i in int(_cfg.get("spawns_per_tick", 4)):
		if spawner.enemies.size() >= want or _ids.is_empty():
			break
		spawner.spawn_ship(Spawner.FROM_ENEMIES, String(_ids[_next % _ids.size()]), _level(), 0, Spawner.AROUND)
		_next += 1


## Sprays harmless shots from the player round the circle until the pool holds `shots`.
func _top_up_shots() -> void:
	var ship := _sandbox.ship
	if not is_instance_valid(ship):
		return
	var from := ship.global_position / PX
	var speed := float(_cfg.get("shot_speed_u", 40.0))
	var life := float(_cfg.get("shot_range_u", 24.0)) / speed
	var want := mini(int(_cfg.get("shots", 600)), ProjectilePool.CAPACITY)
	while _sandbox.pool.count < want:
		_angle = fmod(_angle + 2.39996, TAU)  # the golden angle spreads them evenly
		_sandbox.pool.fire({"from": from, "vel": Vector2.from_angle(_angle) * speed, "life": life,
				"damage": 0.0, "type": &"kinetic"}, 0, &"default")


func _exit_tree() -> void:
	timing = false


func _finish() -> void:
	timing = false
	var size := get_viewport().get_visible_rect().size
	run = {
		"date": Time.get_datetime_string_from_system(false, true),
		"version": str(ProjectSettings.get_setting("application/config/version", "?")),
		"device": OS.get_model_name() if OS.get_model_name() != "GenericDevice" else OS.get_name(),
		"size": "%dx%d" % [size.x, size.y],
		"ship_tiles": _sandbox.ship.blueprint.tiles.size() if is_instance_valid(_sandbox.ship) else 0,
		"scenario": _cfg.duplicate(true),
		"summary": bench.summary(),
	}
	var kept := Save.read_json(RUNS_PATH) if FileAccess.file_exists(RUNS_PATH) else {}
	var runs: Array = kept.get("runs", [])
	lines = Bench.report(run, runs)
	runs.append(run)
	Save.write_json(RUNS_PATH, {"format": 1, "runs": runs})
	for line in lines:
		if OS.is_debug_build():
			Perf.log_line("bench: " + line)  # perf.log, for tools/android.sh perf
		else:
			print("bench: " + line)
	finished.emit(run)

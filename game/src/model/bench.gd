class_name Bench
extends RefCounted
## The performance test (PLAN.md 7.5, D15): what a scripted worst case's frames cost. The scenario
## is `data/flight.json` → bench; BenchRun flies it in the real flight sandbox and feeds
## `add_frame` once a frame after the warm-up. Runs are kept, so the reference phone's numbers
## can be compared phase by phase (`report`).

## A frame slower than this missed the 30 fps floor (§5.5).
const SLOW_MS := 1000.0 / 30.0

var frames_usec := PackedInt32Array()
var _ships := 0
var _shots := 0
## Where the time went, summed over the frames: name -> total (see `add_parts`).
var _parts := {}


## One frame: its wall-clock time, and how many ships and shots were live.
func add_frame(usec: int, ships: int, shots: int) -> void:
	frames_usec.append(usec)
	_ships += ships
	_shots += shots


## A frame's breakdown, numbers by name (BenchRun: "ticks" physics ticks this frame,
## "physics_ms" a tick's cost, "process_ms", "pool_ms", "pairs" collision pairs); `summary`
## averages each over the frames.
func add_parts(parts: Dictionary) -> void:
	for key: String in parts:
		_parts[key] = float(_parts.get(key, 0.0)) + float(parts[key])


## {"frames", "seconds", "fps", "frame_ms", "p95_ms", "worst_ms", "slow" (frames over SLOW_MS),
## "ships", "shots" (the average live), "parts" (add_parts' averages)}.
func summary() -> Dictionary:
	var count := frames_usec.size()
	if count == 0:
		return {"frames": 0, "seconds": 0.0, "fps": 0.0, "frame_ms": 0.0, "p95_ms": 0.0, "worst_ms": 0.0, "slow": 0,
				"ships": 0.0, "shots": 0.0}
	var sorted := frames_usec.duplicate()
	sorted.sort()
	var total := 0
	var slow := 0
	for usec in frames_usec:
		total += usec
		if usec / 1000.0 > SLOW_MS:
			slow += 1
	return {
		"frames": count,
		"seconds": total / 1000000.0,
		"fps": count / maxf(total / 1000000.0, 0.000001),
		"frame_ms": total / 1000.0 / count,
		"p95_ms": sorted[int(0.95 * (count - 1))] / 1000.0,
		"worst_ms": sorted[count - 1] / 1000.0,
		"slow": slow,
		"ships": float(_ships) / count,
		"shots": float(_shots) / count,
		"parts": _averages(count),
	}


func _averages(count: int) -> Dictionary:
	var out := {}
	for key: String in _parts:
		out[key] = float(_parts[key]) / count
	return out


## The stand-in for a large station (stations are Phase 11): a `cols` × `rows` block of Large
## squares round a core, armour round the edge, and a hardpoint with a turret every 4th column
## and 3rd row, its gun taken in turn from `guns` (weapon ids). It has no thrusters, so it sits.
static func station(cols: int, rows: int, guns: Array) -> Blueprint:
	var bp := Blueprint.new()
	bp.id = "bench_station"
	bp.name = "Bench station"
	bp.author = "mss"
	bp.tags = PackedStringArray(["bench"])
	var center := Vector2i(cols / 2, rows / 2)
	var next_id := 1
	var turrets := 0
	for y in rows:
		for x in cols:
			var tile := Blueprint.Tile.new()
			var at := Vector2i(x, y)
			tile.shape = &"square"
			tile.size = &"L"
			tile.pos = Vector2(at - center)
			if at == center:
				tile.id = 0
				tile.type = &"core"
				tile.paint = Color("#d8d8d8")
			else:
				tile.id = next_id
				next_id += 1
				var edge := x == 0 or y == 0 or x == cols - 1 or y == rows - 1
				var hardpoint := x % 4 == 1 and y % 3 == 1 and not guns.is_empty()
				tile.type = &"hardpoint" if hardpoint else (&"armor" if edge else &"hull")
				tile.paint = Color("#3a3f45") if hardpoint else (Color("#6f7f8f") if edge else Color("#8c96a0"))
				if hardpoint:
					bp.mounts.append({"tile": tile.id, "face": true, "part": WeaponLib.part_id(StringName(guns[turrets % guns.size()])),
							"mount": "turret", "mode": "auto"})
					turrets += 1
			bp.tiles.append(tile)
	bp.tiles.sort_custom(func(a: Blueprint.Tile, b: Blueprint.Tile) -> bool: return a.id < b.id)
	return bp


## The results card's lines: `run` (a kept run: {"date", "version", "device", "size", "summary"}),
## then up to `keep` of the `earlier` runs, newest first, one line each.
static func report(run: Dictionary, earlier: Array, keep := 4) -> PackedStringArray:
	var s: Dictionary = run["summary"]
	var lines := PackedStringArray([
		"%.0f fps  ·  frame %.1f ms  (95%% under %.1f, worst %.1f)" % [s["fps"], s["frame_ms"], s["p95_ms"], s["worst_ms"]],
		"%d of %d frames under 30 fps" % [s["slow"], s["frames"]],
		"%.0f ships and %.0f shots live on average" % [s["ships"], s["shots"]],
		"%s  ·  v%s  ·  %s" % [run["device"], run["version"], run["size"]],
	])
	var parts := _parts_lines(s)
	for i in parts.size():
		lines.insert(3 + i, parts[i])
	var shown := 0
	for i in range(earlier.size() - 1, -1, -1):
		if shown >= keep:
			break
		var old: Dictionary = earlier[i]
		var o: Dictionary = old.get("summary", {})
		if shown == 0:
			lines.append("Earlier runs:")
		lines.append("  %s  v%s  %s:  %.0f fps, %.1f ms, worst %.1f" % [str(old.get("date", "?")).left(16),
				old.get("version", "?"), old.get("device", "?"), float(o.get("fps", 0.0)), float(o.get("frame_ms", 0.0)),
				float(o.get("worst_ms", 0.0))])
		shown += 1
	return lines


## Where a frame went, from `summary`'s parts: the ticks it ran and the game speed that left,
## what one tick cost by system (the engine's own physics being the rest), and what each
## per-frame script cost. [] without parts.
static func _parts_lines(s: Dictionary) -> PackedStringArray:
	var parts: Dictionary = s.get("parts", {})
	if parts.is_empty():
		return PackedStringArray()
	var ticks := float(parts.get("ticks", 0.0))
	var physics := float(parts.get("physics_ms", 0.0))
	var systems := 0.0
	for key in ["ai_ms", "flight_ms", "guns_ms", "pool_ms"]:
		systems += float(parts.get(key, 0.0))
	return PackedStringArray([
		"%.1f physics ticks a frame (game at %.0f%% speed)  ·  frame scripts %.1f ms  ·  %.0f contacts" % [
			ticks, ticks * float(s["fps"]) / 60.0 * 100.0, float(parts.get("process_ms", 0.0)), float(parts.get("pairs", 0.0))],
		"a tick %.1f ms: AI %.1f  ·  flight %.1f  ·  guns %.1f  ·  shots %.1f  ·  engine %.1f" % [physics,
			float(parts.get("ai_ms", 0.0)), float(parts.get("flight_ms", 0.0)), float(parts.get("guns_ms", 0.0)),
			float(parts.get("pool_ms", 0.0)), maxf(physics - systems, 0.0)],
	]) + _frame_line(parts)


## The per-frame scripts ("frame:<name>" parts), costliest first: "a frame's scripts: gun views
## 4.1  ·  exhaust 2.0 ...", or nothing if none were timed.
static func _frame_line(parts: Dictionary) -> PackedStringArray:
	var named: Array = []
	for key: String in parts:
		if key.begins_with("frame:"):
			named.append([float(parts[key]), key.trim_prefix("frame:").replace("_", " ")])
	if named.is_empty():
		return PackedStringArray()
	named.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	return PackedStringArray(["a frame's scripts: " + "  ·  ".join(named.map(func(n: Array) -> String:
			return "%s %.1f" % [n[1], n[0]]))])

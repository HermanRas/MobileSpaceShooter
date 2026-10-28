extends TestCase
## Phase 7.5: the performance test's station stand-in is a valid 150-tile ship that sits and
## shoots, and its frame times sum up the way §5.5 reads them (mean, 95th percentile, worst, and
## frames under 30 fps).

func test_the_station_is_a_valid_150_tile_turret_block() -> void:
	var tiles_table := Data.table(&"tiles")
	var placement := Placement.create(ShapeLib.from_table(Data.table(&"shapes")),
			TileLib.from_table(tiles_table), tiles_table)
	placement.thrusters = ThrusterLib.from_table(Data.table(&"thrusters"))
	placement.weapons = WeaponLib.from_table(Data.table(&"weapons"), Data.table(&"weapon_xp"))
	var station_cfg: Dictionary = Data.table(&"flight")["bench"]["station"]
	var bp := Bench.station(int(station_cfg["cols"]), int(station_cfg["rows"]), station_cfg["guns"])
	assert_eq(placement.validate(bp).map(func(p: Placement.Problem) -> String: return p.message), [], "it validates")
	assert_eq(bp.tiles.size(), placement.max_tiles, "at the tile cap")
	assert_eq(bp.tile_by_id(0).type, &"core")
	assert_eq(bp.mounts.size(), 12, "a turret every 4th column and 3rd row")
	assert_true(bp.mounts.all(Mounting.is_weapon), "and no thrusters: it sits")
	var kinds := {}
	for mount in bp.mounts:
		kinds[mount["part"]] = true
	assert_eq(kinds.size(), (station_cfg["guns"] as Array).size(), "every gun in the list is used")


func test_a_summary_reads_like_section_5_5() -> void:
	var bench := Bench.new()
	for i in 99:
		bench.add_frame(10000, 40, 600)
	bench.add_frame(50000, 42, 610)
	var s := bench.summary()
	assert_eq(s["frames"], 100)
	assert_almost_eq(s["frame_ms"], 10.4, 0.001, "the mean")
	assert_almost_eq(s["fps"], 1000.0 / 10.4, 0.01)
	assert_almost_eq(s["p95_ms"], 10.0, 0.001, "one slow frame isn't the 95th percentile")
	assert_almost_eq(s["worst_ms"], 50.0, 0.001)
	assert_eq(s["slow"], 1, "but it is under 30 fps")
	assert_almost_eq(s["ships"], 40.02, 0.001)


func test_the_breakdown_is_averaged_per_frame() -> void:
	var bench := Bench.new()
	bench.add_frame(20000, 40, 600)
	bench.add_parts({"ticks": 1, "physics_ms": 10.0})
	bench.add_frame(60000, 40, 600)
	bench.add_parts({"ticks": 4, "physics_ms": 14.0, "frame:gun_views": 4.0, "frame:hud": 1.0})
	var parts: Dictionary = bench.summary()["parts"]
	assert_almost_eq(parts["ticks"], 2.5, 0.001)
	assert_almost_eq(parts["physics_ms"], 12.0, 0.001)
	var lines := Bench.report({"date": "", "version": "", "device": "", "size": "", "summary": bench.summary()}, [])
	assert_true(lines[3].begins_with("2.5 physics ticks a frame"), lines[3])
	assert_true(lines[4].begins_with("a tick 12.0 ms"), lines[4])
	assert_eq(lines[5], "a frame's scripts: gun views 2.0  ·  hud 0.5", "costliest first, averaged per frame")


func test_no_frames_is_no_crash() -> void:
	assert_eq(Bench.new().summary()["frames"], 0)


func test_the_report_puts_this_run_first_then_the_newest_earlier_ones() -> void:
	var runs: Array = []
	for i in 6:
		runs.append(_run("2026-10-%02d 12:00" % (20 + i), 50.0 + i))
	var lines := Bench.report(_run("2026-10-28 12:00", 61.0), runs, 4)
	assert_true(lines[0].begins_with("61 fps"), lines[0])
	var earlier := Array(lines).filter(func(line: String) -> bool: return line.begins_with("  "))
	assert_eq(earlier.size(), 4, "at most 4 earlier runs")
	assert_true("2026-10-25" in earlier[0] and "55 fps" in earlier[0], "newest first: %s" % earlier[0])


func _run(date: String, fps: float) -> Dictionary:
	var bench := Bench.new()
	bench.add_frame(int(1000000.0 / fps), 41, 600)
	return {"date": date, "version": "0.0.7", "device": "LNA-NX1", "size": "1560x720", "summary": bench.summary()}

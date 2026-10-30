extends TestCase
## Phase 8.1: a WaveTime run. Waves come at rising levels, the next one when the last is cleared
## (after a breather) or after a minute, whichever is first, until the ship is destroyed.


func _run() -> WaveRun:
	return WaveRun.from_table({"levels": [1, 2, 4], "then_per_wave": 10, "wave_s": 60, "clear_pause_s": 3})


func test_the_data_loads_and_rises_to_100() -> void:
	var run := WaveRun.from_table(Data.table(&"levels").get("waves", {}))
	assert_true(run.levels.size() > 1, "levels.json lists the first waves")
	var last := 0
	for n in range(1, 60):
		assert_true(run.level_for(n) >= last, "wave %d is no easier than the one before" % n)
		last = run.level_for(n)
	assert_eq(run.level_for(1), run.levels[0])
	assert_eq(last, 100, "the waves reach level 100 and stay there")


func test_past_the_list_each_wave_adds_its_step() -> void:
	var run := _run()
	assert_eq([run.level_for(1), run.level_for(2), run.level_for(3)], [1, 2, 4])
	assert_eq(run.level_for(4), 14)
	assert_eq(run.level_for(5), 24)
	assert_eq(run.level_for(50), 100, "capped at 100")


func test_the_first_tick_brings_wave_1() -> void:
	var run := _run()
	assert_eq(run.wave, 0)
	assert_true(run.tick(0.0), "wave 1 comes at once")
	assert_eq([run.wave, run.level()], [1, 1])
	assert_false(run.tick(1.0))


func test_a_wave_not_cleared_is_joined_by_the_next_after_a_minute() -> void:
	var run := _run()
	run.tick(0.0)
	assert_false(run.tick(59.0))
	assert_almost_eq(run.next_in(), 1.0)
	assert_true(run.tick(1.0), "60 s on, the next wave comes whatever is left")
	assert_eq([run.wave, run.level()], [2, 2])
	assert_eq(run.waves_cleared, 0)


func test_a_cleared_wave_brings_the_next_after_a_breather() -> void:
	var run := _run()
	run.tick(0.0)
	run.tick(20.0)
	run.cleared()
	assert_almost_eq(run.next_in(), 3.0, 0.001, "the breather, not the minute")
	assert_false(run.tick(2.0))
	assert_true(run.tick(1.0), "the next wave comes after the breather")
	assert_eq([run.wave, run.waves_cleared], [2, 1])
	assert_almost_eq(run.seconds, 23.0)
	run.cleared()
	run.cleared()
	assert_eq(run.waves_cleared, 2, "clearing twice in one breather counts once")


func test_the_breather_never_outlasts_the_minute() -> void:
	var run := _run()
	run.tick(0.0)
	run.tick(59.0)
	run.cleared()
	assert_almost_eq(run.next_in(), 1.0)
	assert_true(run.tick(1.0))
	assert_eq(run.wave, 2)
	assert_false(run.tick(2.5), "the old breather is gone with the wave it followed")


func test_destroyed_ends_the_run_and_nothing_counts_after() -> void:
	var run := _run()
	run.tick(0.0)
	run.killed()
	run.took(40.0)
	run.tick(70.0)
	run.destroyed()
	assert_false(run.tick(100.0), "no wave after the end")
	assert_eq(run.killed(9, 9), 0, "a kill after the end scores nothing")
	run.took(999.0)
	assert_eq([run.wave, run.kills], [2, 1])
	assert_eq(run.title(), "Destroyed in wave 2")
	assert_eq(run.lines(), PackedStringArray(["Score: %d" % run.score(), "Reached wave 2 (level 2)", "Waves cleared: 0",
			"Time: 1:10", "Kills: 1", "Damage taken: 40"]))


func test_kills_score_by_size_and_level_times_the_wave() -> void:
	var run := WaveRun.from_table({"levels": [1, 2, 4], "wave_s": 60,
			"score": {"per_tile_level": 10, "wave_bonus": 0.5, "survival_per_s": 0}})
	run.tick(0.0)
	assert_eq(run.killed(12, 3), 360, "wave 1: 12 tiles x level 3 x 10")
	run.tick(60.0)
	assert_almost_eq(run.multiplier(), 1.5)
	assert_eq(run.killed(12, 3), 540, "wave 2 multiplies it by 1.5")
	assert_eq(run.score(), 900)


func test_staying_alive_scores_by_the_second() -> void:
	var run := WaveRun.from_table({"levels": [1, 2], "wave_s": 60,
			"score": {"per_tile_level": 0, "wave_bonus": 1.0, "survival_per_s": 5}})
	run.tick(0.0)
	run.tick(10.0)
	assert_eq(run.score(), 50, "10 s of wave 1 at 5 a second")
	run.tick(50.0)
	run.tick(10.0)
	assert_eq(run.score(), 300 + 100, "a minute of wave 1, then 10 s of wave 2 at twice the rate")
	run.destroyed()
	run.tick(100.0)
	assert_eq(run.score(), 400, "nothing after the end")


func test_the_shipped_score_rules_load() -> void:
	var run := WaveRun.from_table(Data.table(&"levels").get("waves", {}))
	assert_true(run.per_tile_level > 0.0 and run.survival_per_s > 0.0 and run.wave_bonus > 0.0)


func test_a_clear_pays_gc_by_the_wave_once() -> void:
	var run := WaveRun.from_table({"levels": [1, 2, 4], "wave_s": 60, "clear_pause_s": 3, "clear_bonus_gc": 50})
	run.tick(0.0)
	assert_eq(run.cleared(), 50, "wave 1: 50 GC")
	assert_eq(run.cleared(), 0, "a second clear in the same breather pays nothing")
	run.tick(3.0)
	assert_eq(run.cleared(), 100, "wave 2: 100 GC")
	run.destroyed()
	assert_eq(run.cleared(), 0, "nothing after the end")

extends TestCase
## Phase 8.4: a run adds up into the pilot's record, and the scoreboard ranks every pilot by kills ÷
## deaths, ties by kills (D20).


func _pilot(pilot_name: String, kills: int, deaths: int, runs := 1) -> ProfileRecord:
	var pilot := ProfileRecord.new()
	pilot.id = pilot_name.to_lower()
	pilot.name = pilot_name
	pilot.stats["kills"] = kills
	pilot.stats["deaths"] = deaths
	pilot.stats["runs"] = runs
	return pilot


func test_a_run_adds_up_and_beats_bests() -> void:
	var pilot := _pilot("Ada", 0, 0, 0)
	assert_eq(pilot.record_run(500, 4, 95, 7, true), PackedStringArray(["score", "wave", "time"]), "a first run beats them all")
	assert_eq([pilot.stats["kills"], pilot.stats["deaths"], pilot.stats["runs"]], [7, 1, 1])
	assert_eq(pilot.record_run(300, 5, 60, 3, false), PackedStringArray(["wave"]), "only the wave this time")
	assert_eq([pilot.stats["kills"], pilot.stats["deaths"], pilot.stats["runs"]], [10, 1, 2], "leaving alive isn't a death")
	assert_eq([pilot.stats["best_score"], pilot.stats["best_wave"], pilot.stats["best_wave_s"]], [500, 5, 95])


func test_the_record_survives_a_save() -> void:
	var pilot := _pilot("Ada", 0, 0, 0)
	pilot.record_run(1234, 6, 80, 9, true)
	var errors: PackedStringArray = []
	var back := ProfileRecord.from_dict(pilot.to_dict(), Data.table(&"characters"), errors)
	assert_eq(back.stats["best_score"], 1234)
	assert_eq(back.stats["best_wave"], 6)
	assert_eq(back.stats["runs"], 1)


func test_ranked_by_kills_per_death_then_kills() -> void:
	var rows := Scoreboard.rank([_pilot("Bo", 30, 10), _pilot("Ada", 40, 8), _pilot("Cy", 9, 3), _pilot("Di", 12, 4)]
			as Array[ProfileRecord])
	assert_eq(rows.map(func(row: Dictionary) -> String: return row["name"]), ["Ada", "Bo", "Di", "Cy"],
			"Ada 5.0, then Bo, Di and Cy at 3.0 by kills (30, 12, 9)")
	assert_almost_eq(rows[0]["ratio"], 5.0)


func test_no_deaths_counts_as_one_and_no_runs_go_last() -> void:
	var rows := Scoreboard.rank([_pilot("New", 0, 0, 0), _pilot("Ace", 6, 0), _pilot("Bo", 10, 2)] as Array[ProfileRecord])
	assert_eq(rows.map(func(row: Dictionary) -> String: return row["name"]), ["Ace", "Bo", "New"])
	assert_almost_eq(rows[0]["ratio"], 6.0, 0.0001, "6 kills, no deaths: 6.00, not infinity")
	assert_eq(Scoreboard.ratio_text(rows[1]["ratio"]), "5.00")

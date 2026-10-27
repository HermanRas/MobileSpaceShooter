extends TestCase
## Phase 7.2: a test fight's record for the results card: survived, time, kills, damage taken.


func test_a_cleared_fight_reads_as_survived() -> void:
	var flight := TestFlight.start(12, 3)
	flight.tick(83.4)
	flight.took(120.0)
	flight.took(30.5)
	for i in 3:
		flight.killed()
	flight.cleared()
	assert_eq(flight.title(), "Level 12 cleared!")
	assert_eq(flight.lines(), PackedStringArray(["Survived: yes", "Time: 1:23", "Kills: 3 of 3", "Damage taken: 151"]))


func test_a_lost_fight_reads_as_destroyed() -> void:
	var flight := TestFlight.start(100, 7)
	flight.killed()
	flight.destroyed()
	assert_true(flight.is_over())
	assert_eq(flight.title(), "Destroyed at level 100")
	assert_eq(flight.lines()[0], "Survived: no")
	assert_eq(flight.lines()[2], "Kills: 1 of 7")


func test_nothing_counts_once_its_over() -> void:
	var flight := TestFlight.start(5, 2)
	flight.tick(10.0)
	flight.destroyed()
	flight.tick(5.0)
	flight.took(999.0)
	flight.killed()
	flight.cleared()
	assert_eq(flight.outcome, TestFlight.Outcome.DESTROYED, "the first ending stands")
	assert_almost_eq(flight.seconds, 10.0)
	assert_eq(flight.kills, 0)
	assert_almost_eq(flight.damage_taken, 0.0)


func test_the_clock_pads_seconds() -> void:
	assert_eq(TestFlight.clock(0.0), "0:00")
	assert_eq(TestFlight.clock(9.9), "0:09")
	assert_eq(TestFlight.clock(605.0), "10:05")

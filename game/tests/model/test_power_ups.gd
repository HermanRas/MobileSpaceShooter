extends TestCase
## Phase 8.3: WaveTime's bullet multipliers. A kill sometimes drops one; picked up, every gun fires
## that many shots, fanned, until it runs out; a new one replaces the one running.


func _power() -> PowerUps:
	return PowerUps.from_table({"drop_chance": 0.1, "spread_deg": 4, "kinds": [
		{"shots": 2, "seconds": 15, "weight": 3}, {"shots": 5, "seconds": 8, "weight": 1}]})


func test_the_shipped_table_offers_x2_to_x5() -> void:
	var power := PowerUps.from_table(Data.table(&"powerups"))
	var shots := power.kinds.map(func(kind: Dictionary) -> int: return kind["shots"])
	assert_eq(shots, [2, 3, 4, 5])
	assert_true(power.drop_chance > 0.0 and power.drop_chance < 0.5, "a drop is a treat, not the rule")


func test_a_roll_drops_by_chance_and_weight() -> void:
	var power := _power()
	assert_eq(power.roll(0.1, 0.0), 0, "at or over the chance: nothing")
	assert_eq(power.roll(0.05, 0.0), 2)
	assert_eq(power.roll(0.05, 0.74), 2, "x2 takes the first 3 of 4 weights")
	assert_eq(power.roll(0.05, 0.76), 5)
	assert_eq(power.roll(0.05, 1.0), 5)


func test_it_runs_out_and_the_guns_go_back_to_one() -> void:
	var power := _power()
	assert_eq(power.shots(), 1)
	power.take(5)
	assert_eq([power.shots(), power.left], [5, 8.0])
	assert_false(power.tick(7.5))
	assert_true(power.tick(0.5), "the tick it runs out")
	assert_eq(power.shots(), 1)
	assert_false(power.tick(1.0), "and only once")


func test_a_new_one_replaces_the_one_running() -> void:
	var power := _power()
	power.take(5)
	power.tick(6.0)
	power.take(2)
	assert_eq([power.shots(), power.left], [2, 15.0])
	power.take(3)
	assert_eq(power.shots(), 2, "a kind the table doesn't have is ignored")


func test_the_fan_centres_on_the_aim() -> void:
	assert_eq(PowerUps.fan(1, 0.1), PackedFloat32Array([0.0]))
	var five := PowerUps.fan(5, 0.1)
	assert_almost_eq(five[0], -0.2)
	assert_almost_eq(five[2], 0.0)
	assert_almost_eq(five[4], 0.2)
	var two := PowerUps.fan(2, 0.1)
	assert_almost_eq(two[0] + two[1], 0.0)

extends TestCase
## Phase 3.3: the flight controller, flown headless in FlightSim (PLAN.md 4.3).
## World frame: the ship starts facing +x; -y is its left; a negative heading change is a
## left turn.

var placement: Placement
var tuning: Dictionary


func before_each() -> void:
	var tiles_table := Data.table(&"tiles")
	placement = Placement.create(ShapeLib.from_table(Data.table(&"shapes")),
			TileLib.from_table(tiles_table), tiles_table)
	placement.thrusters = ThrusterLib.from_table(Data.table(&"thrusters"))
	tuning = Data.table(&"flight")


func test_stick_forward_and_left_fires_the_right_rear_thruster() -> void:
	# PLAN.md 4.3, word for word: "Drag the stick left and forward, and the right rear thruster fires".
	var sim := _sim("starter")
	sim.step(Vector2(1, -1).normalized(), 1.0 / 60.0)
	var right_rear := _thruster_index(sim, func(t: Dictionary) -> bool: return t["push"].x > 0.5 and t["pos"].y > 0.0)
	var left_rear := _thruster_index(sim, func(t: Dictionary) -> bool: return t["push"].x > 0.5 and t["pos"].y < 0.0)
	assert_true(sim.last_throttles[right_rear] > sim.last_throttles[left_rear],
			"right rear %.2f > left rear %.2f" % [sim.last_throttles[right_rear], sim.last_throttles[left_rear]])
	sim.run(Vector2(1, -1).normalized(), 1.0)
	assert_true(sim.heading < -0.2, "and it turns left (heading %.2f rad)" % sim.heading)
	assert_true(sim.velocity.x > 0.5, "while moving forward (vx %.2f)" % sim.velocity.x)


func test_the_starter_brakes_with_its_front_thruster() -> void:
	var sim := _sim("starter")
	sim.velocity = Vector2(5, 0)
	sim.step(Vector2.ZERO, 1.0 / 60.0)
	var front := _thruster_index(sim, func(t: Dictionary) -> bool: return t["push"].x < -0.5)
	assert_true(sim.last_command["braking"], "a released stick brakes")
	assert_true(sim.last_throttles[front] > 0.9, "the front thruster fires (%.2f)" % sim.last_throttles[front])
	for i in sim.last_throttles.size():
		if i != front:
			assert_eq(sim.last_throttles[i], 0.0, "the rear ones stay off")


func test_a_released_stick_brings_the_ship_to_a_stop() -> void:
	for id: String in ["starter", "strafer"]:
		var sim := _sim(id)
		sim.velocity = Vector2(4, 1.5)
		sim.spin = 0.8
		sim.run(Vector2.ZERO, 12.0)
		assert_true(sim.velocity.length() < 0.15, "%s stops (speed %.3f)" % [id, sim.velocity.length()])
		assert_true(absf(sim.spin) < 0.1, "%s stops spinning (spin %.3f)" % [id, sim.spin])


func test_top_speed_is_push_over_mass_and_damping() -> void:
	# A jet's steady force makes this clean: v_max = F / (m × linear_damp).
	var bp := _blueprint("starter")
	for mount in bp.mounts:
		if Mounting.is_thruster(mount):
			mount["part"] = "thruster.jet"
	var sim := _sim_for(bp)
	sim.run(Vector2.RIGHT, 30.0)
	var expected := sim.model.envelope.rose[ThrustEnvelope.FORWARD] / (sim.model.envelope.mass * sim.model.linear_damp)
	assert_almost_eq(sim.velocity.x, expected, expected * 0.05, "top speed %.2f vs %.2f U/s" % [sim.velocity.x, expected])


func test_the_strafer_slides_sideways_and_the_starter_cant() -> void:
	var strafer := _sim("strafer")
	var starter := _sim("starter")
	strafer.run(Vector2.DOWN, 0.4)
	starter.run(Vector2.DOWN, 0.4)
	assert_true(strafer.velocity.y > 0.3, "the strafer moves right at once (vy %.2f)" % strafer.velocity.y)
	assert_true(absf(starter.velocity.y) < strafer.velocity.y * 0.25,
			"the starter has to turn first (vy %.2f)" % starter.velocity.y)


func test_heading_settles_without_overshooting_much() -> void:
	var sim := _sim("starter")
	var target := -PI * 0.5  # straight up the screen: a quarter turn left
	var worst := 0.0
	for i in 60 * 6:
		sim.step(Vector2.UP, 1.0 / 60.0)
		worst = minf(worst, wrapf(sim.heading - target, -PI, PI))
	assert_almost_eq(wrapf(sim.heading - target, -PI, PI), 0.0, 0.1, "ends facing the stick")
	assert_true(worst > -0.35, "overshoots by under 20 degrees (%.2f rad)" % worst)


func test_one_centred_rear_thruster_cant_turn() -> void:
	var bp := Blueprint.new()
	bp.id = "centred"
	for row: Array in [[0, &"core", Vector2.ZERO], [1, &"hardpoint", Vector2(-1, 0)]]:
		var tile := Blueprint.Tile.new()
		tile.id = row[0]
		tile.type = row[1]
		tile.shape = &"square"
		tile.size = &"L"
		tile.pos = row[2]
		bp.tiles.append(tile)
	bp.mounts.append({"tile": 1, "edge": 3, "port": 0, "part": "thruster.jet", "size": "L", "level": 1})
	var sim := _sim_for(bp)
	sim.run(Vector2.DOWN, 3.0)
	assert_almost_eq(sim.heading, 0.0, 0.001, "it can't turn toward the stick")
	assert_almost_eq(sim.spin, 0.0, 0.001)


func test_no_forward_never_flies_forward() -> void:
	var sim := _sim("no_forward")
	sim.run(Vector2.RIGHT, 3.0)
	assert_true(sim.velocity.x <= 0.001, "pushing forward gets it nowhere (vx %.3f)" % sim.velocity.x)
	assert_almost_eq(sim.heading, 0.0, 0.001, "and it can't turn either")


func test_lopsided_pulls_to_the_right() -> void:
	var sim := _sim("lopsided")
	# Hold the stick straight ahead with the heading loop's help disabled: raw thrust only.
	var cmd := {"move": Vector2.RIGHT, "turn": 0.0, "braking": false}
	var throttle := sim.model.throttles(cmd)
	var torque := 0.0
	for i in throttle.size():
		var t: Dictionary = sim.model.envelope.thrusters[i]
		torque += (t["pos"] as Vector2).cross(t["push"] * float(t["force"]) * throttle[i])
	assert_true(torque > 0.0, "full forward thrust turns it right (torque %.2f)" % torque)


func test_ion_ramps_while_on_and_cools_when_off() -> void:
	var bp := _blueprint("starter")
	for mount in bp.mounts:
		if Mounting.is_thruster(mount):
			mount["part"] = "thruster.ion"
	var sim := _sim_for(bp)
	sim.run(Vector2.RIGHT, 1.0)
	var rear := _thruster_index(sim, func(t: Dictionary) -> bool: return t["push"].x > 0.5)
	var after_one := sim.model.ramp_shares()[rear]
	assert_almost_eq(after_one, 1.0 / 3.0, 0.03, "L1 ion: a third of the way after 1 s of 3")
	sim.run(Vector2.RIGHT, 3.0)
	assert_almost_eq(sim.model.ramp_shares()[rear], 1.0, 0.001, "full after the ramp time")
	sim.velocity = Vector2.ZERO  # so the brake doesn't use the rear ones
	sim.run(Vector2.ZERO, 0.5)
	assert_almost_eq(sim.model.ramp_shares()[rear], 2.0 / 3.0, 0.03, "cools twice as fast as it built")


func test_pulse_kicks_every_interval() -> void:
	var sim := _sim("starter")
	var kicks := 0
	for i in 60 * 2:
		sim.last_command = sim.model.command(Vector2.RIGHT, 0.0, Vector2.ZERO, 0.0)
		var out := sim.model.step(sim.model.throttles(sim.last_command), 1.0 / 60.0)
		kicks += (out["impulses"] as Array).size()
	# Two rear pulse thrusters, primed: kicks at 0, 0.5, 1.0 and 1.5 s.
	assert_eq(kicks, 8, "2 thrusters × 4 kicks in 2 s")


# ── helpers ───────────────────────────────────────────────────────────────────

func _sim(id: String) -> FlightSim:
	return _sim_for(_blueprint(id))


func _sim_for(bp: Blueprint) -> FlightSim:
	assert_eq(placement.validate(bp).size(), 0, "%s is a valid ship" % bp.id)
	return FlightSim.create(FlightModel.create(tuning, ThrustEnvelope.compute(bp, placement)))


func _blueprint(id: String) -> Blueprint:
	var errors: PackedStringArray = []
	return Blueprint.from_dict(Data.json_dir("blueprints")[id], errors)


func _thruster_index(sim: FlightSim, match_fn: Callable) -> int:
	for i in sim.model.envelope.thrusters.size():
		if match_fn.call(sim.model.envelope.thrusters[i]):
			return i
	fail("no thruster matches")
	return 0

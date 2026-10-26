extends TestCase
## Phase 5.2: enemy pilots, flown headless through the real FlightModel in FlightSim. Each
## behaviour should be recognisable, and none should get stuck on the arena's edge.

const DT := 1.0 / 60.0

var placement: Placement
var roster: EnemyRoster
var flight: Dictionary
var ai: Dictionary


func before_each() -> void:
	var tiles_table := Data.table(&"tiles")
	placement = Placement.create(ShapeLib.from_table(Data.table(&"shapes")),
			TileLib.from_table(tiles_table), tiles_table)
	placement.thrusters = ThrusterLib.from_table(Data.table(&"thrusters"))
	placement.weapons = WeaponLib.from_table(Data.table(&"weapons"))
	roster = EnemyRoster.from_table(Data.table(&"enemies"), Data.json_dir("enemies"))
	flight = Data.table(&"flight")
	ai = Data.table(&"ai")


func test_every_roster_behaviour_is_known() -> void:
	for entry in roster.entries:
		assert_true(AiBrain.BEHAVIOURS.has(entry.behaviour), "%s flies %s" % [entry.id, entry.behaviour])
	assert_eq(Array(Data.table(&"enemies")["behaviours"]), AiBrain.BEHAVIOURS.map(func(b: StringName) -> String: return String(b)))


func test_a_chaser_closes_in_and_points_at_you() -> void:
	var pilot := _pilot(&"gnat", Vector2(-40, 15))
	var target := {"pos": Vector2.ZERO, "vel": Vector2.ZERO}
	var facing := 0
	for i in 60 * 14:
		_tick(pilot, target)
		if i >= 60 * 10 and absf(angle_difference(pilot.sim.heading, (target["pos"] - pilot.sim.position).angle())) < deg_to_rad(10.0):
			facing += 1
	var distance: float = pilot.sim.position.length()
	assert_true(distance < 10.0, "closed from 43 U to %.1f" % distance)
	assert_true(facing > 60 * 3, "nose on target for most of the last 4 s (%d ticks)" % facing)


func test_a_chaser_stays_on_a_moving_target() -> void:
	var pilot := _pilot(&"hornet", Vector2(-30, -10))
	var target := {"pos": Vector2(20, 0), "vel": Vector2.ZERO}
	var near := 0
	for i in 60 * 30:
		var t := i * DT * 0.3  # the player circling at 6 U/s, radius 20
		target["pos"] = Vector2(cos(t), sin(t)) * 20.0
		target["vel"] = Vector2(-sin(t), cos(t)) * 6.0
		_tick(pilot, target)
		if i >= 60 * 15 and pilot.sim.position.distance_to(target["pos"]) < 14.0:
			near += 1
	assert_true(near > 60 * 9, "within gun range of a circling target for most of 15 s (%d of 900 ticks)" % near)


func test_a_strafer_circles() -> void:
	var pilot := _pilot(&"wasp", Vector2(-20, 0))
	var target := {"pos": Vector2.ZERO, "vel": Vector2.ZERO}
	var swept := 0.0
	var last := pilot.sim.position.angle()
	var distances: Array[float] = []
	for i in 60 * 30:
		_tick(pilot, target)
		if i >= 60 * 10:
			swept += angle_difference(last, pilot.sim.position.angle())
			distances.append(pilot.sim.position.length())
		last = pilot.sim.position.angle()
	var radius: float = pilot.brain.range_u * float(ai["behaviours"]["strafe"]["radius_share"])
	assert_true(absf(swept) > TAU, "went right round the target (%.0f°)" % rad_to_deg(swept))
	assert_true(_mean(distances) > radius * 0.6 and _mean(distances) < radius * 1.5,
			"near its circle (%.1f U, wants %.1f)" % [_mean(distances), radius])


func test_a_sniper_keeps_its_distance() -> void:
	var pilot := _pilot(&"lance", Vector2(-4, 0))
	var target := {"pos": Vector2.ZERO, "vel": Vector2.ZERO}
	var near: float = pilot.brain.range_u * float(ai["behaviours"]["keep_range"]["min_share"])
	var far: float = pilot.brain.range_u * float(ai["behaviours"]["keep_range"]["max_share"])
	var inside := 0
	for i in 60 * 25:
		_tick(pilot, target)
		var d: float = pilot.sim.position.length()
		if i >= 60 * 15 and d > near * 0.8 and d < far * 1.2:
			inside += 1
	assert_true(inside > 60 * 8, "backed off from 4 U into its band %.0f-%.0f U (%d of 600 ticks)" % [near, far, inside])


func test_a_kamikaze_rams() -> void:
	var pilot := _pilot(&"dart", Vector2(-35, 10))
	var target := {"pos": Vector2.ZERO, "vel": Vector2(0, 2)}
	var closest := INF
	for i in 60 * 10:
		target["pos"] += target["vel"] * DT
		_tick(pilot, target)
		closest = minf(closest, pilot.sim.position.distance_to(target["pos"]))
	assert_true(closest < 1.5, "went through a moving target (closest %.2f U)" % closest)


func test_a_minelayer_circles_inside_mine_range() -> void:
	var pilot := _pilot(&"spinner", Vector2(-25, 0))
	var target := {"pos": Vector2.ZERO, "vel": Vector2.ZERO}
	var close := 0
	for i in 60 * 25:
		_tick(pilot, target)
		if i >= 60 * 10 and pilot.sim.position.length() < float(placement.weapons.weapon(&"mines")["range_u"]):
			close += 1
	assert_true(close > 60 * 10, "within mine range for most of 15 s (%d ticks)" % close)


func test_the_carrier_flies_its_route_whatever_attacks_it() -> void:
	var pilot := _pilot(&"pike", Vector2.ZERO)
	pilot.brain.route = PackedVector2Array([Vector2(40, 0), Vector2(40, 40), Vector2(0, 40), Vector2(0, 0)])
	var raider := {"pos": Vector2(10, 5), "vel": Vector2.ZERO}
	var reached := {}
	for i in 60 * 120:
		_tick(pilot, raider)
		reached[pilot.brain.route_index] = true
	assert_eq(reached.size(), 4, "owner, 2026-10-26: it heads for every waypoint in turn, raider or not")
	pilot.brain.route = PackedVector2Array([Vector2(-20, 0)])
	pilot.brain.route_index = 0
	pilot.brain.loop_route = false
	for i in 60 * 40:
		_tick(pilot, raider)
	assert_true(pilot.sim.position.distance_to(Vector2(-20, 0)) < 8.0 and pilot.sim.velocity.length() < 1.5,
			"and stops at the end of a one-way route (%.1f U off, %.1f U/s)" % [pilot.sim.position.distance_to(Vector2(-20, 0)),
			pilot.sim.velocity.length()])


func test_an_enemy_escort_holds_its_post_until_an_enemy_comes_near() -> void:
	var pilot := _pilot(&"hornet", Vector2(-10, 8))
	pilot.brain.behaviour = &"escort"  # a boss's guard (12.2)
	var charge := {"pos": Vector2.ZERO, "vel": Vector2(3, 0), "heading": 0.0}
	var far := {"pos": Vector2(500, 500), "vel": Vector2.ZERO}
	for i in 60 * 20:
		charge["pos"] += charge["vel"] * DT
		_tick(pilot, far, [], charge)
	var post: Vector2 = charge["pos"] + Vector2(0, float(ai["behaviours"]["escort"]["offset_u"]))  # its right, +y
	assert_true(pilot.sim.position.distance_to(post) < 2.5, "riding at its post (%.1f U off)" % pilot.sim.position.distance_to(post))
	var raider := {"pos": charge["pos"] + Vector2(12, -6), "vel": Vector2.ZERO}
	var start: float = pilot.sim.position.distance_to(raider["pos"])
	for i in 60 * 6:
		charge["pos"] += charge["vel"] * DT
		_tick(pilot, raider, [], charge)
	assert_true(pilot.sim.position.distance_to(raider["pos"]) < (charge["pos"] as Vector2).distance_to(raider["pos"]),
			"moves between its charge and a raider (%.1f U from it, was %.1f)" % [pilot.sim.position.distance_to(raider["pos"]), start])


func test_a_hurt_ship_flees() -> void:
	var pilot := _pilot(&"lance", Vector2(-10, 0))
	pilot.hull = 0.1
	var target := {"pos": Vector2.ZERO, "vel": Vector2.ZERO}
	for i in 60 * 12:  # a weak brake: it has to turn round first
		_tick(pilot, target)
	assert_true(pilot.brain.fleeing, "below flee_below it runs")
	assert_true(pilot.sim.position.length() > 30.0, "and gets away (%.1f U)" % pilot.sim.position.length())


func test_friends_keep_apart() -> void:
	var a := _pilot(&"gnat", Vector2(-30, 0))
	var b := _pilot(&"gnat", Vector2(-30, 0.5))
	var target := {"pos": Vector2.ZERO, "vel": Vector2.ZERO}
	for i in 60 * 12:
		_tick(a, target, [{"pos": b.sim.position}])
		_tick(b, target, [{"pos": a.sim.position}])
	assert_true(a.sim.position.distance_to(b.sim.position) > 1.5, "two chasers don't stack (%.1f U apart)" %
			a.sim.position.distance_to(b.sim.position))


func test_nobody_gets_stuck_on_the_edge() -> void:
	var arena := Arena.from_table(flight["arena"])
	for id: StringName in [&"gnat", &"dart", &"wasp", &"lance", &"bulwark", &"leviathan"]:
		var pilot := _pilot(id, Vector2(arena.half_size_u - 3.0, arena.half_size_u - 3.0), arena)
		pilot.sim.velocity = Vector2(6, 6)
		var target := {"pos": Vector2(arena.half_size_u + 30.0, 0), "vel": Vector2.ZERO}  # the player hugging the edge
		var worst := 0.0
		var moved := 0.0
		for i in 60 * 30:
			var before: Vector2 = pilot.sim.position
			_tick(pilot, target)
			moved += before.distance_to(pilot.sim.position)
			worst = maxf(worst, maxf(absf(pilot.sim.position.x), absf(pilot.sim.position.y)) - arena.half_size_u)
		assert_true(worst < 10.0, "%s stays near the arena (%.1f U past the edge at worst)" % [id, worst])
		assert_true(arena.contains(pilot.sim.position), "%s ends inside" % id)
		assert_true(moved > 20.0, "%s keeps flying (%.0f U)" % [id, moved])


## ── helpers ───────────────────────────────────────────────────────────────────

class Pilot:
	var sim: FlightSim
	var brain: AiBrain
	var hull := 1.0


func _pilot(id: StringName, at: Vector2, arena: Arena = null) -> Pilot:
	var entry := roster.entry(id)
	var pilot := Pilot.new()
	var envelope := ThrustEnvelope.compute(entry.blueprint, placement)
	pilot.sim = FlightSim.create(FlightModel.create(flight, envelope))
	pilot.sim.position = at
	pilot.brain = AiBrain.for_ship(ai, entry.behaviour, entry.blueprint, placement, float(flight["linear_damp"]), arena)
	pilot.brain.flee_below = entry.flee_below
	return pilot


func _tick(pilot: Pilot, target: Dictionary, friends: Array = [], charge: Dictionary = {}) -> void:
	var stick := pilot.brain.think({"pos": pilot.sim.position, "vel": pilot.sim.velocity, "heading": pilot.sim.heading,
			"hull": pilot.hull}, target, friends, charge)
	pilot.sim.step(stick, DT)
	if pilot.brain.arena != null:
		pilot.sim.velocity += pilot.brain.arena.push(pilot.sim.position) * DT  # the sandbox's push back (3.5)


func _mean(values: Array[float]) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total / maxf(values.size(), 1)

class_name AiBrain
extends RefCounted
## An enemy pilot's head (PLAN.md 5.2): from where it is, where its target is, its friends and
## the arena, the stick it holds. It flies through the same FlightModel as the player, so it has
## no physics of its own: it can only go where its thrusters push it.
##
## Each behaviour picks a velocity it wants; the stick steers toward it. With nothing to correct,
## it holds its nose on its aim, so fixed guns line up. A ship that brakes weakly (most enemies,
## PLAN.md 5.1) turns round to slow down: the flight model won't turn a ship toward a stick held
## straight behind it (the thrusters that would turn it push the wrong way), so the brain holds
## the stick at most 90° off the nose until it has come round. A ship closing on its aim too
## fast lets go of the stick instead: the auto-brake slows it without turning, so the nose stays
## on. It approaches no faster than it can stop. On top of every behaviour: friends closer than
## `separation_u` push it apart, and the arena's edge pulls it back in, so it never pins itself
## against the edge. Below `flee_below` of its hull it runs. Tuning is `data/ai.json`.
##
## The goal comes from outside (a target, a ship to guard), so a group leader can later hand out
## posts (v2 formations, PLAN.md §9).

const BEHAVIOURS: Array[StringName] = [&"chase", &"strafe", &"keep_range", &"ram", &"lay_mines", &"escort", &"convoy"]

var behaviour: StringName = &"chase"
var flee_below := 0.0
## U/s the ship reaches flat out ahead, its acceleration ahead and back (U/s²), and its longest
## gun range.
var top_speed := 10.0
var forward_accel := 5.0
var back_accel := 1.0
var range_u := 12.0
## The speed of its fixed guns' shots, for leading the target with its nose (0: no fixed guns).
var aim_speed := 0.0
var arena: Arena
## Which way it circles (+1 clockwise, -1 counter), so a pair doesn't follow one track.
var orbit_sign := 1.0
## Which side of its charge an escort holds (+1 right, -1 left).
var post_side := 1.0
## A convoy's waypoints (world U), the one it's heading for, and whether it goes round again.
## The carrier the player escorts flies one (PLAN.md 12.3).
var route := PackedVector2Array()
var route_index := 0
var loop_route := true
var tuning: Dictionary = {}
## The last tick's wish, for tests and the debug overlay.
var wanted := Vector2.ZERO
var fleeing := false


## A brain for `behaviour` with `ai_table` (data/ai.json).
static func create(ai_table: Dictionary, behaviour_id: StringName, ship_top_speed: float, gun_range_u: float,
		play_area: Arena = null) -> AiBrain:
	var brain := AiBrain.new()
	brain.tuning = ai_table
	brain.behaviour = behaviour_id if BEHAVIOURS.has(behaviour_id) else &"chase"
	brain.top_speed = maxf(ship_top_speed, 0.1)
	brain.range_u = gun_range_u if gun_range_u > 0.0 else float(ai_table.get("range_default_u", 12.0))
	brain.arena = play_area
	return brain


## A brain fitted to `bp`: its top speed (forward push ÷ (mass × `linear_damp`)), its longest gun
## range, and its fixed guns' shot speed.
static func for_ship(ai_table: Dictionary, behaviour_id: StringName, bp: Blueprint, placement: Placement,
		linear_damp: float, play_area: Arena = null) -> AiBrain:
	var envelope := ThrustEnvelope.compute(bp, placement)
	var guns := GunLayout.compute(bp, placement)
	var reach := 0.0
	var aim := 0.0
	for gun in guns.guns:
		reach = maxf(reach, float(gun.stats["range_u"]))
		if gun.arc <= 0.0 and not gun.stats["rear_only"]:  # a mine layer isn't aimed with the nose
			aim = maxf(aim, float(gun.stats["speed_u"]))
	var brain := create(ai_table, behaviour_id, envelope.accel(ThrustEnvelope.FORWARD) / maxf(linear_damp, 0.01),
			reach, play_area)
	brain.aim_speed = aim
	brain.forward_accel = envelope.accel(ThrustEnvelope.FORWARD)
	brain.back_accel = envelope.accel(ThrustEnvelope.BACK)
	return brain


## The stick (world space, length ≤ 1) for this tick.
##   me: {"pos", "vel", "heading", "hull"} (hull: share left, 0..1)
##   target: {"pos", "vel"}, or {} for none
##   friends: [{"pos"}] other ships on its side
##   charge: {"pos", "vel", "heading"}, the ship an escort guards, or {}
func think(me: Dictionary, target: Dictionary, friends: Array = [], charge: Dictionary = {}) -> Vector2:
	var pos: Vector2 = me["pos"]
	var vel: Vector2 = me["vel"]
	var face := Vector2.ZERO
	fleeing = not target.is_empty() and float(me.get("hull", 1.0)) < flee_below
	if fleeing:
		wanted = ((pos - (target["pos"] as Vector2)).normalized()) * top_speed
	elif behaviour == &"escort" and not charge.is_empty():
		var engage: bool = not target.is_empty() and (target["pos"] as Vector2).distance_to(charge["pos"]) \
				<= float(_rules().get("guard_u", 20.0))
		face = _hold_post(pos, charge, target if engage else {})
	elif behaviour == &"convoy":
		_follow_route(pos)
	elif target.is_empty():
		wanted = Vector2.ZERO
	else:
		match behaviour:
			&"chase": face = _chase(pos, vel, target)
			&"strafe": _circle(pos, target, range_u * float(_rules().get("radius_share", 0.55)))
			&"lay_mines": _circle(pos, target, float(_rules().get("radius_u", 7.0)))
			&"ram": _ram(pos, target)
			_: face = _keep_range(pos, target)
	wanted += _separation(pos, friends) + _edge(pos)
	wanted = wanted.limit_length(top_speed)
	var stick := ((wanted - vel) / (top_speed * float(tuning.get("steer_gain", 0.2)))).limit_length(1.0)
	var heading := float(me.get("heading", 0.0))
	if face != Vector2.ZERO:
		var toward := face.normalized()
		var closing := vel.dot(toward)
		var overspeed := float(tuning.get("overspeed", 0.5))
		if closing > overspeed and closing > wanted.dot(toward) + overspeed \
				and absf(angle_difference(heading, toward.angle())) < deg_to_rad(float(tuning.get("brake_facing_deg", 60.0))):
			return Vector2.ZERO  # the auto-brake, nose kept on
		if stick.length() < float(tuning.get("face_below", 0.35)):
			return toward * float(tuning.get("face_stick", 0.17))
	var off := angle_difference(heading, stick.angle())
	if back_accel < forward_accel * float(tuning.get("turn_first_below", 0.6)) and absf(off) > PI * 0.5:
		stick = Vector2.from_angle(heading + signf(off) * PI * 0.5) * stick.length()
	return stick


## This behaviour's numbers from ai.json.
func _rules() -> Dictionary:
	return tuning.get("behaviours", {}).get(String(behaviour), {})


## Where its nose should point to hit the target with its fixed guns.
func _aim_point(pos: Vector2, vel: Vector2, target: Dictionary) -> Vector2:
	var at: Vector2 = target["pos"]
	if aim_speed > 0.0:
		var t := Gunnery.intercept_time(at - pos, (target["vel"] as Vector2) - vel, aim_speed)
		if t > 0.0:
			at += ((target["vel"] as Vector2) - vel) * t
	return at


func _chase(pos: Vector2, vel: Vector2, target: Dictionary) -> Vector2:
	var aim := _aim_point(pos, vel, target)
	var to := aim - pos
	var stand_off := float(_rules().get("stand_off_u", 6.0))
	var slow := maxf(float(_rules().get("slow_within_u", 14.0)), stand_off + 0.1)
	var gap := to.length() - stand_off
	var speed := top_speed * clampf(gap / (slow - stand_off), 0.0, 1.0)  # inside its stand-off it holds, nose on
	if gap > 0.0:
		speed = minf(speed, _stopping_speed(gap, true))
	wanted = (target["vel"] as Vector2) + to.normalized() * speed
	return to


func _circle(pos: Vector2, target: Dictionary, radius: float) -> void:
	var out := pos - (target["pos"] as Vector2)
	var distance := maxf(out.length(), 0.01)
	var tangent := out.orthogonal().normalized() * orbit_sign
	var pull := float(_rules().get("pull", 0.8))
	var speed := top_speed * float(_rules().get("speed_share", 0.8))
	var inward := -out / distance * clampf((distance - radius) / maxf(radius, 1.0) * pull * 2.0, -1.0, 1.0)
	wanted = (target["vel"] as Vector2) + (tangent + inward).normalized() * speed


func _keep_range(pos: Vector2, target: Dictionary) -> Vector2:
	var to := (target["pos"] as Vector2) - pos
	var distance := to.length()
	var near := range_u * float(tuning.get("behaviours", {}).get("keep_range", {}).get("min_share", 0.6))
	var far := range_u * float(tuning.get("behaviours", {}).get("keep_range", {}).get("max_share", 0.85))
	wanted = target["vel"]
	if distance < near:
		wanted -= to.normalized() * top_speed * clampf((near - distance) / maxf(near, 1.0) * 2.0, 0.0, 1.0)
	elif distance > far:
		wanted += to.normalized() * top_speed * clampf((distance - far) / maxf(far, 1.0) * 2.0, 0.0, 1.0)
	return to


func _ram(pos: Vector2, target: Dictionary) -> void:
	var at: Vector2 = target["pos"]
	var t := Gunnery.intercept_time(at - pos, target["vel"], top_speed)
	if t > 0.0:
		at += (target["vel"] as Vector2) * t
	wanted = (at - pos).normalized() * top_speed * float(_rules().get("speed_share", 1.0))


## An escort's post: offset_u to one side of its charge (or, with a raider near, between the
## two), matching its speed; nose the way the charge goes, or at the raider.
func _hold_post(pos: Vector2, charge: Dictionary, raider: Dictionary = {}) -> Vector2:
	var side := Vector2.from_angle(float(charge["heading"]) + PI * 0.5 * post_side)
	if not raider.is_empty():
		side = ((raider["pos"] as Vector2) - (charge["pos"] as Vector2)).normalized()
	var post: Vector2 = (charge["pos"] as Vector2) + side * float(_rules().get("offset_u", 4.0))
	var gap := post - pos
	var speed := minf(gap.length() * float(_rules().get("hold_gain", 0.8)), _stopping_speed(gap.length()))
	wanted = (charge["vel"] as Vector2) + gap.normalized() * speed
	return (raider["pos"] as Vector2) - pos if not raider.is_empty() else Vector2.from_angle(float(charge["heading"]))


## On to the next waypoint at a cruise, whatever is shooting at it (its turrets fight); it stops
## at the end of a route that doesn't loop, and holds still without one.
func _follow_route(pos: Vector2) -> void:
	wanted = Vector2.ZERO
	if route.is_empty() or route_index >= route.size():
		return
	if pos.distance_to(route[route_index]) <= float(_rules().get("reach_u", 6.0)):
		route_index += 1
		if route_index >= route.size():
			if not loop_route:
				return
			route_index = 0
	var to := route[route_index] - pos
	var speed := top_speed * float(_rules().get("cruise_share", 0.6))
	if not loop_route and route_index == route.size() - 1:
		speed = minf(speed, _stopping_speed(to.length()))
	wanted = to.normalized() * speed


## How fast it can go and still stop within `distance`: by turning round if its brakes are weak,
## or with its brakes alone if it means to keep its nose on (`nose_on`).
func _stopping_speed(distance: float, nose_on := false) -> float:
	var decel := back_accel if nose_on else maxf(back_accel, forward_accel * float(tuning.get("turn_and_burn_share", 0.4)))
	return sqrt(2.0 * maxf(decel, float(tuning.get("min_brake", 0.5))) * maxf(distance, 0.0))


func _separation(pos: Vector2, friends: Array) -> Vector2:
	var reach := float(tuning.get("separation_u", 3.0))
	var push := Vector2.ZERO
	for friend: Dictionary in friends:
		var away := pos - (friend["pos"] as Vector2)
		var distance := away.length()
		if distance < reach and distance > 0.001:
			push += away / distance * (1.0 - distance / reach) * top_speed
	return push


## Back toward the middle, harder the nearer the edge (and past it).
func _edge(pos: Vector2) -> Vector2:
	if arena == null:
		return Vector2.ZERO
	var margin := float(tuning.get("edge_margin_u", 30.0))
	var out := Vector2.ZERO
	for axis in 2:
		var depth := absf(pos[axis]) - (arena.half_size_u - margin)
		if depth > 0.0:
			out[axis] = -signf(pos[axis]) * depth / margin * top_speed * float(tuning.get("edge_push", 2.0))
	return out

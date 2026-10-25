class_name ThrustEnvelope
extends RefCounted
## What a ship's thrusters can do (PLAN.md 4.3, 4.10): the thrust rose, the turn strength each
## way, and the flight warnings the hangar shows. Warnings never block saving or flying.
##
## Ship-local frame: forward is +x (the core's arrow), y points down, so +y is the ship's
## right. A positive torque (r × F) turns the nose to the right.
##
## Force per thruster is its rated thrust: a pulse thruster's average, an ion thruster's peak.
## Each thruster pushes along -normal of its edge, applied at its mount point.

## Rose directions, clockwise from forward.
const DIRECTIONS := ["forward", "forward-right", "right", "back-right", "back", "back-left", "left", "forward-left"]
const FORWARD := 0
const RIGHT := 2
const BACK := 4
const LEFT := 6
## Below this, a direction or a turn counts as missing.
const NONE := 0.001
## A thruster pushing within ~45° of forward counts toward forward thrust for "pulls".
const FORWARD_DOT := 0.7
## "Pulls to one side": the weaker side's forward torque is under this share of the stronger,
## and the stronger is over PULL_MIN_LEVER_U × the forward force (so a tiny offset doesn't warn).
const PULL_BALANCE := 0.5
const PULL_MIN_LEVER_U := 0.05

## [{"mount": index, "type", "behaviour", "pos": U from the centre of mass, "push": unit
## vector, "force", "start", "ramp_s", "interval_s"}] (the last three from ThrusterLib.spec)
var thrusters: Array[Dictionary] = []
## Total force available in each of DIRECTIONS (a thruster counts by the cosine of its angle).
var rose := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0])
## Total torque each way, in force × U.
var turn_right: float = 0.0
var turn_left: float = 0.0
var mass: float = 0.0
var inertia: float = 0.0
## [{"code": StringName, "text": String}]
var warnings: Array[Dictionary] = []


static func direction(index: int) -> Vector2:
	return Vector2.RIGHT.rotated(deg_to_rad(45.0 * index))


static func compute(bp: Blueprint, placement: Placement, stats: ShipStats = null) -> ThrustEnvelope:
	var envelope := ThrustEnvelope.new()
	if stats == null:
		stats = ShipStats.compute(bp, placement)
	envelope.mass = stats.mass
	envelope.inertia = stats.inertia
	if placement.thrusters != null:
		for i in bp.mounts.size():
			var mount := bp.mounts[i]
			var type_id := ThrusterLib.type_of_part(str(mount.get("part", "")))
			var spec := placement.thrusters.spec(type_id, StringName(mount.get("size", "")), int(mount.get("level", 0)))
			var mount_frame := Mounting.frame(placement, bp, mount)
			if spec.is_empty() or mount_frame.is_empty():
				continue
			envelope.thrusters.append({
				"mount": i, "type": type_id, "behaviour": spec["behaviour"],
				"pos": (mount_frame["center"] as Vector2) - stats.center_of_mass,
				"push": -(mount_frame["normal"] as Vector2), "force": spec["thrust"],
				"start": spec["start"], "ramp_s": spec["ramp_s"], "interval_s": spec["interval_s"],
			})
	envelope._sum()
	envelope._warn()
	return envelope


## Acceleration in U/s² toward DIRECTIONS[index], with every helpful thruster at full.
func accel(index: int) -> float:
	return rose[index] / mass if mass > 0.0 else 0.0


## Turn acceleration in rad/s² each way, at full.
func turn_accel_right() -> float:
	return turn_right / inertia if inertia > 0.0 else 0.0


func turn_accel_left() -> float:
	return turn_left / inertia if inertia > 0.0 else 0.0


## Total force available along a ship-local unit direction (each thruster by its cosine).
func push_toward(direction_local: Vector2) -> float:
	var total := 0.0
	for t in thrusters:
		total += maxf(0.0, (t["push"] as Vector2).dot(direction_local)) * float(t["force"])
	return total


func has_warning(code: StringName) -> bool:
	return warnings.any(func(w: Dictionary) -> bool: return w["code"] == code)


func _sum() -> void:
	for t in thrusters:
		var force: Vector2 = (t["push"] as Vector2) * float(t["force"])
		for i in DIRECTIONS.size():
			rose[i] += maxf(0.0, force.dot(direction(i)))
		var torque := (t["pos"] as Vector2).cross(force)
		if torque > 0.0:
			turn_right += torque
		else:
			turn_left -= torque


func _warn() -> void:
	if thrusters.is_empty():
		warnings.append({"code": &"no_thrusters", "text": "no thrusters"})
		return
	if rose[FORWARD] < NONE:
		warnings.append({"code": &"no_forward", "text": "no forward thrust"})
	if rose[BACK] < NONE:
		warnings.append({"code": &"cant_brake", "text": "can't brake"})
	if turn_left < NONE:
		warnings.append({"code": &"cant_turn_left", "text": "can't turn left"})
	if turn_right < NONE:
		warnings.append({"code": &"cant_turn_right", "text": "can't turn right"})
	# Pulls: everything that pushes forward, fired together, turns the ship one way and the
	# other side can't balance it.
	var right := 0.0
	var left := 0.0
	var forward := 0.0
	for t in thrusters:
		var push: Vector2 = t["push"]
		if push.dot(direction(FORWARD)) < FORWARD_DOT:
			continue
		var force := push * float(t["force"])
		forward += force.x
		var torque := (t["pos"] as Vector2).cross(force)
		if torque > 0.0:
			right += torque
		else:
			left -= torque
	var strong := maxf(right, left)
	if forward > NONE and strong > PULL_MIN_LEVER_U * forward and minf(right, left) < PULL_BALANCE * strong:
		warnings.append({"code": &"pulls", "text": "pulls to the %s" % ("right" if right > left else "left")})

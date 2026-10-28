class_name FlightController
extends Node
## Flies its parent ShipBody (PLAN.md 4.3, Phase 3.3): each physics tick, `stick` →
## FlightModel → throttles → forces and pulse kicks at the thrusters' mount points. No hidden
## turning force: the ship goes only where its thrusters can push it.
##
## The stick is world-space, length ≤ 1, set by whoever is flying: the touch stick (3.4), the
## keyboard, or later an AI pilot.

## A pulse thruster kicked this tick (for its puff, 3.6). `index` is in envelope order.
signal kicked(index: int, throttle: float)

const PX := ShipMesh.PX_PER_U

var stick := Vector2.ZERO
var model: FlightModel
## This tick's throttle per thruster (envelope order), for the exhaust VFX (3.6) and the HUD.
var throttles := PackedFloat32Array()
## Whether the last command was the auto-brake.
var braking := false

var _ship: ShipBody
## Until the body has had one physics step, Godot still divides an impulse by mass 1 (its mass
## is applied during the step), so a pulse kick on the first tick flings it at ~mass × the speed.
## The first tick after attach is skipped.
var _fresh := true


## Builds the flight model for `ship` with `tuning` (data/flight.json) and sets its damping.
func attach(ship: ShipBody, tuning: Dictionary) -> void:
	_ship = ship
	model = FlightModel.create(tuning, ship.envelope)
	ship.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	ship.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	ship.linear_damp = model.linear_damp
	ship.angular_damp = model.angular_damp
	# Losing tiles can lose thrusters (4.2): fly with what's left.
	ship.rebuilt.connect(func() -> void: model.set_envelope(ship.envelope))


func _physics_process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	if _ship == null or model == null:
		return
	if _fresh:
		_fresh = false
		return
	var cmd := model.command(stick, _ship.rotation, _ship.linear_velocity / PX, _ship.angular_velocity)
	braking = cmd["braking"]
	throttles = model.throttles(cmd)
	if _ship.damage != null and _ship.damage.is_disabled():
		throttles.fill(0.0)  # EMP: the thrusters are out (4.5)
	var out := model.step(throttles, delta)
	var turn := Transform2D(_ship.rotation, Vector2.ZERO)
	for f: Dictionary in out["forces"]:
		_ship.apply_force(turn * ((f["force"] as Vector2) * PX), turn * _offset(f["pos"]))
	for j: Dictionary in out["impulses"]:
		_ship.apply_impulse(turn * ((j["impulse"] as Vector2) * PX), turn * _offset(j["pos"]))
		kicked.emit(j["index"], throttles[j["index"]])
	BenchRun.spent(&"flight", started)


## A thruster's position (U from the centre of mass, ship-local) as Godot wants it for
## apply_force: pixels from the body's origin, still unrotated.
func _offset(pos_from_com: Vector2) -> Vector2:
	return _ship.center_of_mass + pos_from_com * PX

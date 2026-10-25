class_name FlightModel
extends RefCounted
## The flight controller's logic (PLAN.md 4.3, Phase 3.3): stick → a throttle per thruster →
## the forces they make. Pure, so it's tested headless; ShipBody (3.3) and FlightSim (tests)
## apply the forces.
##
## The stick is in WORLD space and says where to go: the ship turns toward it and pushes that
## way with whatever helps. Each thruster's throttle is how much its push helps the wanted move
## plus how much its torque helps the wanted turn, clamped to 0..1, so a thruster that would
## work against both stays off. Released, it auto-brakes: everything that opposes the current
## motion and spin fires, down to a stop if the thrusters can manage it.
##
## Frames: ship-local has forward +x and +y on the ship's right; positive spin and torque turn
## right (clockwise on screen, y down). All lengths in U.
##
## All pulse thrusters with the same interval kick on ONE shared clock, like a single engine
## cycle. Out of step, each kick on its own is a full one-sided push, and the ship yaws back and
## forth instead of turning by the throttle difference (found in the 3.3 heading test).
##
## Pulse thrusters deliver a whole interval of thrust in one kick, so a feedback loop tuned for
## steady thrust overshoots with them and rocks forever. Their share of the FEEDBACK (turning,
## braking) is scaled so one kick corrects about one interval's worth of error; a held stick
## still gets their full push.

var linear_damp := 0.5
var angular_damp := 0.5
var dead_zone := 0.15
## 1/s: how hard the heading loop chases the spin it wants.
var turn_response := 6.0
## Share of the stopping authority the heading loop plans with, so it doesn't overshoot.
var turn_brake_margin := 0.7
var max_spin := 4.0
## 1/s: the auto-brake asks for this × the current speed (as a share of full thrust).
var brake_response := 1.0
var stop_speed_u := 0.05
var stop_spin := 0.05
var min_throttle := 0.05
## How fast an ion thruster's ramp drains when it's off, relative to how fast it built.
var ion_cooldown_rate := 2.0

var envelope: ThrustEnvelope
## Per thruster, in envelope.thrusters order: each one's torque per unit throttle, as a share
## of the strongest (-1..1, positive turns right).
var _turn_share := PackedFloat32Array()
## Per thruster: how much of the turn and brake commands it acts on (1, or less for pulses).
var _turn_gain := PackedFloat32Array()
var _brake_gain := PackedFloat32Array()
## Spin acceleration (rad/s²) a turn command of +1 / -1 produces on average, pulses scaled
## down: what the heading loop can count on when planning to stop.
var _turn_accel_right := 0.0
var _turn_accel_left := 0.0
## The same before the pulse scaling: what a command is normalised by, so that the scaling
## (not the normalisation) decides how hard a pulse kicks.
var _turn_norm_right := 0.0
var _turn_norm_left := 0.0
## Runtime state: the shared pulse clocks (interval -> seconds since the last kick) and each
## thruster's ion ramp.
var _pulse_clock := {}
var _ramp_time := PackedFloat32Array()


static func create(tuning: Dictionary, ship_envelope: ThrustEnvelope) -> FlightModel:
	var model := FlightModel.new()
	for key in ["linear_damp", "angular_damp", "dead_zone", "turn_response", "turn_brake_margin",
			"max_spin", "brake_response", "stop_speed_u", "stop_spin", "min_throttle", "ion_cooldown_rate"]:
		if tuning.has(key):
			model.set(key, float(tuning[key]))
	model.set_envelope(ship_envelope)
	return model


## Call again whenever the ship's thrusters change (a refit, or one shot off).
func set_envelope(ship_envelope: ThrustEnvelope) -> void:
	envelope = ship_envelope
	var count := envelope.thrusters.size()
	_turn_share.resize(count)
	_turn_gain.resize(count)
	_brake_gain.resize(count)
	_pulse_clock.clear()
	_ramp_time.resize(count)
	var strongest := 0.0
	var torques := PackedFloat32Array()
	for t in envelope.thrusters:
		var torque := (t["pos"] as Vector2).cross(t["push"] * float(t["force"]))
		torques.append(torque)
		strongest = maxf(strongest, absf(torque))
	_turn_accel_right = 0.0
	_turn_accel_left = 0.0
	_turn_norm_right = 0.0
	_turn_norm_left = 0.0
	for i in count:
		_turn_share[i] = torques[i] / strongest if strongest > 0.0 else 0.0
		var interval := float(envelope.thrusters[i].get("interval_s", 0.0))
		var pulsed: bool = envelope.thrusters[i]["behaviour"] == &"pulse" and interval > 0.0
		_turn_gain[i] = minf(1.0, 1.0 / (turn_response * interval)) if pulsed else 1.0
		_brake_gain[i] = minf(1.0, 1.0 / (brake_response * interval)) if pulsed else 1.0
		var turning := _turn_share[i] * torques[i]  # always >= 0
		if torques[i] > 0.0:
			_turn_accel_right += turning * _turn_gain[i]
			_turn_norm_right += turning
		else:
			_turn_accel_left += turning * _turn_gain[i]
			_turn_norm_left += turning
		if pulsed:
			# Primed, so the first kick comes the moment one is asked for.
			_pulse_clock[interval] = interval
		_ramp_time[i] = 0.0
	if envelope.inertia > 0.0:
		_turn_accel_right /= envelope.inertia
		_turn_accel_left /= envelope.inertia
		_turn_norm_right /= envelope.inertia
		_turn_norm_left /= envelope.inertia


## What the pilot wants, from the stick and the ship's state:
##   {"move": ship-local Vector2 (length ≤ 1, a share of full thrust), "turn": -1..1 (+ right),
##    "braking": bool}
## `stick` is world-space (length ≤ 1); `heading` is the ship's rotation in radians;
## `velocity` is world-space U/s; `spin` is rad/s.
func command(stick: Vector2, heading: float, velocity: Vector2, spin: float) -> Dictionary:
	var local_velocity := velocity.rotated(-heading)
	if stick.length() <= dead_zone:
		return _brake(local_velocity, spin)
	var strength := clampf((stick.length() - dead_zone) / (1.0 - dead_zone), 0.0, 1.0)
	var error := wrapf(stick.angle() - heading, -PI, PI)
	return {
		"move": stick.normalized().rotated(-heading) * strength,
		"turn": _turn_toward(error, spin),
		"braking": false,
	}


## A throttle (0..1) per thruster for a command.
func throttles(cmd: Dictionary) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var move: Vector2 = cmd["move"]
	var turn: float = cmd["turn"]
	var braking: bool = cmd.get("braking", false)
	for i in envelope.thrusters.size():
		var push: Vector2 = envelope.thrusters[i]["push"]
		var along := push.dot(move) * (_brake_gain[i] if braking else 1.0)
		var throttle := clampf(along + _turn_share[i] * turn * _turn_gain[i], 0.0, 1.0)
		out.append(throttle if throttle >= min_throttle else 0.0)
	return out


## Advances each thruster by `delta` at these throttles and returns what they do this step:
##   {"forces": [{"pos", "force"}], "impulses": [{"pos", "impulse"}]}
## ship-local, positions relative to the centre of mass. Forces are held for the step;
## impulses (pulse kicks) are applied once.
func step(throttle: PackedFloat32Array, delta: float) -> Dictionary:
	var forces: Array[Dictionary] = []
	var impulses: Array[Dictionary] = []
	# Tick each shared pulse clock: it beats while any of its thrusters is on, and waits primed
	# while they're all off.
	var beat := {}
	for interval: float in _pulse_clock:
		var any_on := false
		for i in envelope.thrusters.size():
			if throttle[i] > 0.0 and envelope.thrusters[i]["behaviour"] == &"pulse" \
					and is_equal_approx(float(envelope.thrusters[i]["interval_s"]), interval):
				any_on = true
				break
		beat[interval] = any_on and _pulse_clock[interval] >= interval - 0.0001
		if beat[interval]:
			_pulse_clock[interval] -= interval
		_pulse_clock[interval] = (_pulse_clock[interval] + delta) if any_on else minf(_pulse_clock[interval] + delta, interval)
	for i in envelope.thrusters.size():
		var t: Dictionary = envelope.thrusters[i]
		var on := throttle[i] > 0.0
		var push: Vector2 = t["push"]
		match t["behaviour"]:
			&"steady":
				if on:
					forces.append({"pos": t["pos"], "force": push * float(t["force"]) * throttle[i]})
			&"pulse":
				var interval: float = t["interval_s"]
				if on and beat.get(interval, false):
					# A pulse's rated thrust is its average: each kick carries one interval's worth.
					impulses.append({"pos": t["pos"], "impulse": push * float(t["force"]) * interval * throttle[i]})
			&"ramp":
				var ramp_s: float = t["ramp_s"]
				if on:
					_ramp_time[i] = minf(_ramp_time[i] + delta, ramp_s)
					var share := _ramp_time[i] / ramp_s if ramp_s > 0.0 else 1.0
					var force := lerpf(float(t["start"]), float(t["force"]), share)
					forces.append({"pos": t["pos"], "force": push * force * throttle[i]})
				else:
					_ramp_time[i] = maxf(_ramp_time[i] - delta * ion_cooldown_rate, 0.0)
	return {"forces": forces, "impulses": impulses}


## How far each ion thruster's ramp has built (0..1), in envelope.thrusters order; 0 for others.
func ramp_shares() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in envelope.thrusters.size():
		var ramp_s := float(envelope.thrusters[i].get("ramp_s", 0.0))
		out.append(_ramp_time[i] / ramp_s if ramp_s > 0.0 else 0.0)
	return out


func _brake(local_velocity: Vector2, spin: float) -> Dictionary:
	if local_velocity.length() < stop_speed_u and absf(spin) < stop_spin:
		return {"move": Vector2.ZERO, "turn": 0.0, "braking": true}
	# Ask for a deceleration of brake_response × speed, as a share of what the thrusters can
	# push that way; full throttle when they can't keep up.
	var move := Vector2.ZERO
	var wanted := -local_velocity * brake_response
	if wanted.length() > 0.0:
		var available := envelope.push_toward(wanted.normalized()) / envelope.mass if envelope.mass > 0.0 else 0.0
		if available > 0.0:
			move = wanted.normalized() * minf(wanted.length() / available, 1.0)
	var turn := 0.0
	if absf(spin) >= stop_spin:
		turn = clampf(-spin * turn_response / maxf(_norm(-signf(spin)), 0.001), -1.0, 1.0)
	return {"move": move, "turn": turn, "braking": true}


## Spin toward a heading error: as fast as the ship could still stop in time (with a margin),
## capped, then a turn command that closes the gap between that and the current spin.
func _turn_toward(error: float, spin: float) -> float:
	var stopping := _authority(-signf(error)) * turn_brake_margin
	var wanted := signf(error) * minf(sqrt(2.0 * stopping * absf(error)), max_spin)
	var push_with := _norm(signf(wanted - spin))
	if push_with <= 0.0:
		return 0.0
	return clampf((wanted - spin) * turn_response / push_with, -1.0, 1.0)


func _norm(direction: float) -> float:
	if direction > 0.0:
		return _turn_norm_right
	if direction < 0.0:
		return _turn_norm_left
	return 0.0


## Spin acceleration (rad/s²) a full turn command makes toward `direction` (+1 right, -1 left).
func _authority(direction: float) -> float:
	if direction > 0.0:
		return _turn_accel_right
	if direction < 0.0:
		return _turn_accel_left
	return 0.0

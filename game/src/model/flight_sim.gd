class_name FlightSim
extends RefCounted
## A rigid ship in empty space, integrated the way Godot's 2D physics does it (semi-implicit
## Euler, then damping as v *= 1 - damp·dt), so flight can be tested headless and fast.
## Units: U, seconds, radians, world space. The ship's origin is its centre of mass.

var model: FlightModel
var position := Vector2.ZERO
var velocity := Vector2.ZERO
var heading := 0.0
var spin := 0.0
## The throttles from the last step, for tests to inspect.
var last_throttles := PackedFloat32Array()
var last_command := {}


static func create(flight: FlightModel) -> FlightSim:
	var sim := FlightSim.new()
	sim.model = flight
	return sim


func step(stick: Vector2, delta: float) -> void:
	last_command = model.command(stick, heading, velocity, spin)
	last_throttles = model.throttles(last_command)
	var out := model.step(last_throttles, delta)
	var mass := model.envelope.mass
	var inertia := model.envelope.inertia
	var force := Vector2.ZERO
	var torque := 0.0
	for f: Dictionary in out["forces"]:
		force += (f["force"] as Vector2).rotated(heading)
		torque += (f["pos"] as Vector2).cross(f["force"])
	for j: Dictionary in out["impulses"]:
		velocity += (j["impulse"] as Vector2).rotated(heading) / mass
		spin += (j["pos"] as Vector2).cross(j["impulse"]) / inertia
	velocity += force / mass * delta
	spin += torque / inertia * delta
	velocity *= maxf(1.0 - model.linear_damp * delta, 0.0)
	spin *= maxf(1.0 - model.angular_damp * delta, 0.0)
	position += velocity * delta
	heading += spin * delta


## Runs `seconds` at 60 Hz with the stick held.
func run(stick: Vector2, seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		step(stick, 1.0 / 60.0)

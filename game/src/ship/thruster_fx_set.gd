class_name ThrusterFxSet
extends Node2D
## Every thruster's exhaust on one ship (Phase 3.6), fed by its FlightController: throttles
## and ion ramps each frame, pulse puffs on each kick. A child of the ShipBody, drawn under
## the hull so the exhaust comes out from behind the nozzles. Rebuilt when the ship loses tiles.

const PX := ShipMesh.PX_PER_U

var _fx: Array[ThrusterFx] = []
var _pilot: FlightController


func attach(ship: ShipBody, pilot: FlightController) -> void:
	_pilot = pilot
	z_index = -1
	_build(ship)
	ship.rebuilt.connect(_build.bind(ship))
	pilot.kicked.connect(func(index: int, throttle: float) -> void:
		if index < _fx.size():
			_fx[index].kick(throttle))


func _build(ship: ShipBody) -> void:
	for fx in _fx:
		fx.queue_free()
	_fx.clear()
	for t in ship.envelope.thrusters:
		var mount: Dictionary = ship.blueprint.mounts[t["mount"]]
		var mount_frame := Mounting.frame(ship.placement, ship.blueprint, mount)
		var fx := ThrusterFx.create(t["type"], float(mount_frame["length"]) * PX, int(mount.get("level", 1)))
		fx.position = (mount_frame["center"] as Vector2) * PX
		fx.rotation = (mount_frame["normal"] as Vector2).angle()
		add_child(fx)
		_fx.append(fx)


func _process(_delta: float) -> void:
	var started := Time.get_ticks_usec()
	if _pilot == null or _pilot.throttles.size() != _fx.size():
		return
	var ramps := _pilot.model.ramp_shares()
	for i in _fx.size():
		_fx[i].set_state(_pilot.throttles[i], ramps[i])
	BenchRun.spent(&"exhaust", started)

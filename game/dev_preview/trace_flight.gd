extends Node
## Prints a FlightSim trace: `godot --headless --path game res://dev_preview/trace_flight.tscn -- --ship=starter --stick=0,-1 --seconds=6`

func _ready() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "1"
	var tiles_table := Data.table(&"tiles")
	var placement := Placement.create(ShapeLib.from_table(Data.table(&"shapes")), TileLib.from_table(tiles_table), tiles_table)
	placement.thrusters = ThrusterLib.from_table(Data.table(&"thrusters"))
	var errors: PackedStringArray = []
	var bp := Blueprint.from_dict(Data.json_dir("blueprints")[args.get("ship", "starter")], errors)
	var sim := FlightSim.create(FlightModel.create(Data.table(&"flight"), ThrustEnvelope.compute(bp, placement)))
	var stick_parts: PackedStringArray = str(args.get("stick", "0,-1")).split(",")
	var stick := Vector2(float(stick_parts[0]), float(stick_parts[1]))
	for i in roundi(float(args.get("seconds", "6")) * 60):
		sim.step(stick, 1.0 / 60.0)
		if args.has("from") and i >= roundi(float(args["from"]) * 60) and i < roundi(float(args["from"]) * 60) + 40:
			var error := wrapf(stick.angle() - sim.heading, -PI, PI)
			print("f=%d heading=%6.3f err=%6.3f spin=%6.3f turn=%5.2f planR=%.3f planL=%.3f normR=%.3f normL=%.3f thr=%s" % [i, sim.heading, error, sim.spin,
					sim.last_command["turn"], sim.model._turn_accel_right, sim.model._turn_accel_left,
					sim.model._turn_norm_right, sim.model._turn_norm_left, sim.last_throttles])
		elif not args.has("from") and i % 15 == 0:
			print("t=%5.2f heading=%6.3f spin=%6.3f v=(%5.2f,%5.2f) turn=%5.2f thr=%s" % [i / 60.0, sim.heading, sim.spin,
					sim.velocity.x, sim.velocity.y, sim.last_command["turn"], sim.last_throttles])
	get_tree().quit()

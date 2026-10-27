extends Node2D
## Phase 3.6's check: every thruster type × size at L1-3, side by side, firing, with the
## nozzle art (A.2) drawn by the ship mesh.
##   tools/preview.sh res://scenes/debug/thruster_fx_showcase.tscn 1560x720 --frames=45
## Rows: pulse, jet, ion. Columns: S, M, L at L1, then at L2 and L3. Exhaust points down.

const PX := ShipMesh.PX_PER_U
const SIZES := {&"S": 0.25, &"M": 0.5, &"L": 1.0}

var _fx: Array[ThrusterFx] = []
var _clock := 0.0


func _ready() -> void:
	var camera := Camera2D.new()
	camera.position = Vector2(910, 400)
	camera.zoom = Vector2(0.8, 0.8)  # room for the long ion plumes
	add_child(camera)
	var depth_factor := float(Data.table(&"thrusters").get("depth_factor", 0.5))
	var row := 0
	for type_id: StringName in [&"pulse", &"jet", &"ion"]:
		var column := 0
		for level in [1, 2, 3]:
			for size_code: StringName in SIZES:
				var width: float = SIZES[size_code] * PX
				var at := Vector2(110 + column * 200, 70 + row * 220)
				var nozzle := MeshInstance2D.new()
				nozzle.mesh = ShipMesh.nozzle_mesh(type_id, {"center": Vector2.ZERO, "normal": Vector2.DOWN,
						"length": SIZES[size_code], "depth": SIZES[size_code] * depth_factor}, level)
				nozzle.material = ShipMesh.make_material()
				nozzle.position = at
				add_child(nozzle)
				var fx := ThrusterFx.create(type_id, width, level)
				fx.position = at
				fx.rotation = PI * 0.5
				fx.z_index = -1  # under the nozzle, as ThrusterFxSet puts it under the hull
				add_child(fx)
				_fx.append(fx)
				var label := Label.new()
				label.text = "%s %s L%d" % [type_id, size_code, level]
				label.position = at + Vector2(-60, -40)
				add_child(label)
				column += 1
		row += 1


func _process(delta: float) -> void:
	_clock += delta
	var kick := _clock >= 0.5
	if kick:
		_clock -= 0.5
	for fx in _fx:
		fx.set_state(1.0, 1.0)
		if kick:
			fx.kick(1.0)

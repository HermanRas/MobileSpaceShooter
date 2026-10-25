extends Node2D
## Phase 3.6's check: every thruster type × size at L1 and L3, side by side, firing.
##   tools/preview.sh res://scenes/debug/thruster_fx_showcase.tscn 1560x720 --frames=45
## Rows: pulse, jet, ion. Columns: S, M, L at L1, then S, M, L at L3. Exhaust points down.

const PX := ShipMesh.PX_PER_U
const SIZES := {&"S": 0.25, &"M": 0.5, &"L": 1.0}

var _fx: Array[ThrusterFx] = []
var _clock := 0.0


func _ready() -> void:
	var camera := Camera2D.new()
	camera.position = Vector2(620, 400)
	camera.zoom = Vector2(0.8, 0.8)  # room for the long ion plumes
	add_child(camera)
	var row := 0
	for type_id: StringName in [&"pulse", &"jet", &"ion"]:
		var column := 0
		for level in [1, 3]:
			for size_code: StringName in SIZES:
				var width: float = SIZES[size_code] * PX
				var at := Vector2(110 + column * 200, 70 + row * 220)
				var nozzle := Polygon2D.new()
				nozzle.polygon = PackedVector2Array([Vector2(-width * 0.5, 0), Vector2(width * 0.5, 0),
						Vector2(width * 0.35, width * 0.5), Vector2(-width * 0.35, width * 0.5)])
				nozzle.color = Color(0.5, 0.5, 0.55)
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

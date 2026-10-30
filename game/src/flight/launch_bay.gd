class_name LaunchBay
extends Node2D
## The hangar bay a WaveTime (and Story) flight launches from and docks into (PLAN.md 8.1): a
## station block with an open mouth facing +x, floor lights chasing out to it, a glowing field
## across the mouth and a shutter that closes over it. Sized round a ship of `ship_u` (its longest
## side). Drawn in code (`vis.fx.launch_bay` has the colours) until the art track has one.

const PX := ShipMesh.PX_PER_U
const META_ID := &"vis.fx.launch_bay"
## U/s the floor lights chase toward the mouth.
const CHASE_U_S := 6.0

## 0 open .. 1 shut.
var shutter := 0.0:
	set(value):
		shutter = clampf(value, 0.0, 1.0)
		queue_redraw()
## Inside the bay, in U: across, and from the back wall to the mouth (at x = 0).
var inner_w := 6.0
var depth := 8.0

var _colors := {}
var _age := 0.0


static func create(ship_u: float) -> LaunchBay:
	var bay := LaunchBay.new()
	bay.name = "LaunchBay"
	bay.inner_w = maxf(ship_u, 2.0) + 3.0
	bay.depth = maxf(ship_u, 2.0) + 5.0
	return bay


## Where a ship waits inside, in the bay's frame (U): halfway in, nose to the mouth.
func berth_u() -> Vector2:
	return Vector2(-depth * 0.5, 0.0)


func _ready() -> void:
	z_index = -1  # under the ships
	var meta := Assets.meta(META_ID)
	for key: String in ["hull", "trim", "floor", "lights", "mouth", "shutter"]:
		_colors[key] = Color.from_string(str(meta.get(key, "#808080")), Color.GRAY)


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _draw() -> void:
	var half := inner_w * 0.5
	var lip := 0.6
	# The station behind, then the bay's block, its floor and the trim round the mouth.
	_rect(Vector2(-depth - 10.0, -half - 7.0), Vector2(-depth - 2.0, half + 7.0), _colors["hull"].darkened(0.25))
	_rect(Vector2(-depth - 3.0, -half - 3.0), Vector2(lip, half + 3.0), _colors["hull"])
	_rect(Vector2(-depth, -half), Vector2(lip, half), _colors["floor"])
	for side in [-1.0, 1.0]:
		_rect(Vector2(-depth - 3.0, side * (half + 3.0)), Vector2(lip, side * (half + 2.6)), _colors["trim"])
		_rect(Vector2(-0.4, side * half), Vector2(lip, side * (half + 3.0)), _colors["trim"])
	# Floor lights, two rows, a pulse running out to the mouth.
	var lights: Color = _colors["lights"]
	var x := -depth + 0.6
	while x < 0.0:
		var pulse := pow(0.5 + 0.5 * cos((x - _age * CHASE_U_S) * 0.9), 6.0)
		for side in [-1.0, 1.0]:
			var at := Vector2(x, side * (half - 0.5)) * PX
			draw_rect(Rect2(at - Vector2(5, 5), Vector2(10, 10)), lights.darkened(0.7).lerp(lights, pulse))
		x += 1.0
	# The field across the open mouth, and the shutter closing over it from both sides.
	var mouth: Color = _colors["mouth"]
	mouth.a = 0.35 + 0.15 * sin(_age * 4.0)
	_rect(Vector2(lip - 0.15, -half), Vector2(lip, half), mouth)
	if shutter > 0.0:
		for side in [-1.0, 1.0]:
			_rect(Vector2(-0.4, side * half), Vector2(lip, side * half * (1.0 - shutter)), _colors["shutter"])


## A filled rectangle between two corners, in U.
func _rect(a: Vector2, b: Vector2, color: Color) -> void:
	var low := Vector2(minf(a.x, b.x), minf(a.y, b.y))
	draw_rect(Rect2(low * PX, (Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) - low) * PX), color)

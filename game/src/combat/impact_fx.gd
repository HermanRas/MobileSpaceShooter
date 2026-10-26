class_name ImpactFx
extends Node2D
## Sparks where shots strike (Phase 4.5): a flash and a few sparks thrown back the way the shot
## came, all in one MultiMesh of soft dots, like the ProjectilePool. A busy fight lands dozens of
## hits a second, so this keeps them out of the node tree. Looks per weapon in `vis.fx.impacts`.
## Explosions (4.6a) flash as wide as their splash and throw sparks all round.

const CAPACITY := 768
const PX := ShipMesh.PX_PER_U
const LOOK_ID := &"vis.fx.impacts"

var count := 0

var _pos := PackedVector2Array()  # pixels
var _vel := PackedVector2Array()  # pixels per second
var _life := PackedFloat32Array()
var _span := PackedFloat32Array()  # its whole life, for the fade
var _size := PackedFloat32Array()  # pixels, at birth
var _color := PackedColorArray()
var _looks := {}  # weapon id -> look, with sizes in pixels
var _view := MultiMeshInstance2D.new()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_pos.resize(CAPACITY)
	_vel.resize(CAPACITY)
	_life.resize(CAPACITY)
	_span.resize(CAPACITY)
	_size.resize(CAPACITY)
	_color.resize(CAPACITY)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = CAPACITY
	multimesh.visible_instance_count = 0
	_view.multimesh = multimesh
	_view.texture = ThrusterFx._dot()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_view.material = additive
	add_child(_view)


## A hit at `point` by a shot moving at `velocity` (world pixels, pixels per second).
func burst(point: Vector2, velocity: Vector2, weapon_id: StringName) -> void:
	var look := _look(weapon_id)
	var back := -velocity.normalized()
	var life: float = look["life"]
	var speed: float = look["speed"]
	_add(point, Vector2.ZERO, life * 0.5, look["flash"], Color.WHITE)
	for i in int(look["sparks"]):
		var heading := back.rotated(_rng.randf_range(-1.1, 1.1)) * speed * _rng.randf_range(0.3, 1.0)
		_add(point, heading, life * _rng.randf_range(0.6, 1.0), look["size"], look["color"])


## An explosion at `point` reaching `radius` (world pixels).
func blast(point: Vector2, radius: float, weapon_id: StringName) -> void:
	var look := _look(weapon_id)
	var life: float = look["life"]
	_add(point, Vector2.ZERO, life * 0.5, radius * 1.1, Color(1.0, 0.95, 0.85))
	_add(point, Vector2.ZERO, life, radius * 1.6, look["color"])
	for i in int(look["sparks"]) * 2:
		var heading := Vector2.from_angle(_rng.randf() * TAU) * radius * _rng.randf_range(1.5, 3.5)
		_add(point, heading, life * _rng.randf_range(0.5, 1.0), look["size"], look["color"])


## A rocket destroyed in flight.
func pop(point: Vector2) -> void:
	_add(point, Vector2.ZERO, 0.15, 0.5 * PX, Color(1.0, 0.9, 0.6))


func _process(delta: float) -> void:
	var i := 0
	while i < count:
		_life[i] -= delta
		if _life[i] <= 0.0:
			_remove(i)
			continue
		_pos[i] += _vel[i] * delta
		i += 1
	var multimesh := _view.multimesh
	multimesh.visible_instance_count = count
	for k in count:
		var share := _life[k] / _span[k]
		var size := _size[k] * (0.4 + 0.6 * share)
		multimesh.set_instance_transform_2d(k, Transform2D(0.0, Vector2(size, size), 0.0, _pos[k]))
		multimesh.set_instance_color(k, Color(_color[k], share))


func _add(at: Vector2, vel: Vector2, life: float, size: float, color: Color) -> void:
	if count >= CAPACITY:
		return
	_pos[count] = at
	_vel[count] = vel
	_life[count] = life
	_span[count] = life
	_size[count] = size
	_color[count] = color
	count += 1


func _remove(i: int) -> void:
	count -= 1
	_pos[i] = _pos[count]
	_vel[i] = _vel[count]
	_life[i] = _life[count]
	_span[i] = _span[count]
	_size[i] = _size[count]
	_color[i] = _color[count]


func _look(weapon_id: StringName) -> Dictionary:
	if not _looks.has(weapon_id):
		var looks := Assets.meta(LOOK_ID)
		var raw: Dictionary = looks.get(String(weapon_id), looks.get("default", {}))
		_looks[weapon_id] = {
			"color": Color.from_string(str(raw.get("color", "#ffd890")), Color.ORANGE),
			"sparks": int(raw.get("sparks", 4)), "size": float(raw.get("size_u", 0.1)) * PX,
			"speed": float(raw.get("speed_u", 5.0)) * PX, "life": float(raw.get("life_s", 0.2)),
			"flash": float(raw.get("flash_u", 0.3)) * PX,
		}
	return _looks[weapon_id]

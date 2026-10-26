class_name ProjectilePool
extends Node2D
## Every shot in flight (PLAN.md 5.5): plain arrays, not a node per bullet. Each physics tick a
## shot moves on, and a ray along that step finds the first hull it crosses. Ships sit on a
## physics layer per team (ShipBody.TEAM_LAYER), so a shot's ray only sees the other side and
## never needs an exclusion list. Every shot draws in one MultiMesh as an additive streak.
##
## Brought forward from Phase 4.4 so the guns of 4.3 have something to fire; 4.4 stress-tests
## it at 600 shots on the phone.

## A shot struck `tile_id` of `body` at `point` (world pixels). Emitted before the damage lands.
signal hit(body: ShipBody, tile_id: int, point: Vector2)

const CAPACITY := 1024
const PX := ShipMesh.PX_PER_U
const LOOK_ID := &"vis.fx.projectiles"

## Shots in flight; the first `count` entries of each array are live.
var count := 0
## Shots dropped because the pool was full (4.4 watches this).
var dropped := 0

var _pos := PackedVector2Array()  # pixels
var _vel := PackedVector2Array()  # pixels per second
var _life := PackedFloat32Array()
var _damage := PackedFloat32Array()
var _pierce := PackedFloat32Array()
var _mask := PackedInt32Array()
var _look := PackedInt32Array()
var _type: Array[StringName] = []
## [{"color", "length", "width"}] in pixels, and weapon id -> index there.
var _looks: Array[Dictionary] = []
var _look_of := {}
var _query := PhysicsRayQueryParameters2D.new()
var _view := MultiMeshInstance2D.new()


func _ready() -> void:
	_pos.resize(CAPACITY)
	_vel.resize(CAPACITY)
	_life.resize(CAPACITY)
	_damage.resize(CAPACITY)
	_pierce.resize(CAPACITY)
	_mask.resize(CAPACITY)
	_look.resize(CAPACITY)
	_type.resize(CAPACITY)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = CAPACITY
	multimesh.visible_instance_count = 0
	_view.multimesh = multimesh
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_view.material = additive
	add_child(_view)
	_query.hit_from_inside = true  # point-blank: a shot that starts inside a hull hits it
	_look_for(&"default")


## Launches a shot from `from_u` at `vel_u` (world U and U/s) that lives `life` seconds and
## strikes the first hull on `mask`'s layers.
func fire(from_u: Vector2, vel_u: Vector2, life: float, damage: float, type: StringName, pierce: float,
		mask: int, weapon_id: StringName) -> void:
	if count >= CAPACITY:
		dropped += 1
		return
	var i := count
	_pos[i] = from_u * PX
	_vel[i] = vel_u * PX
	_life[i] = life
	_damage[i] = damage
	_pierce[i] = pierce
	_mask[i] = mask
	_type[i] = type
	_look[i] = _look_for(weapon_id)
	count += 1


func clear() -> void:
	count = 0
	_view.multimesh.visible_instance_count = 0


func _physics_process(delta: float) -> void:
	var space := get_world_2d().direct_space_state
	var i := 0
	while i < count:
		var to := _pos[i] + _vel[i] * delta
		_query.from = _pos[i]
		_query.to = to
		_query.collision_mask = _mask[i]
		var found := space.intersect_ray(_query)
		if not found.is_empty():
			var body := found["collider"] as ShipBody
			var tile_id := body.tile_at_shape(int(found["shape"])) if body != null else -1
			var damage := _damage[i]
			var type := _type[i]
			var pierce := _pierce[i]
			_remove(i)
			if tile_id >= 0:
				hit.emit(body, tile_id, found["position"])
				body.take_hit(tile_id, damage, type, pierce)
			continue
		_pos[i] = to
		_life[i] -= delta
		if _life[i] <= 0.0:
			_remove(i)
			continue
		i += 1


func _process(_delta: float) -> void:
	var multimesh := _view.multimesh
	multimesh.visible_instance_count = count
	for i in count:
		var look := _looks[_look[i]]
		var along := _vel[i].normalized()
		var length: float = look["length"]
		# A streak trailing back from the shot's head.
		multimesh.set_instance_transform_2d(i, Transform2D(along * length, along.orthogonal() * float(look["width"]),
				_pos[i] - along * length * 0.5))
		multimesh.set_instance_color(i, look["color"])


## Swap-remove: the last live shot takes slot `i`.
func _remove(i: int) -> void:
	count -= 1
	if i == count:
		return
	_pos[i] = _pos[count]
	_vel[i] = _vel[count]
	_life[i] = _life[count]
	_damage[i] = _damage[count]
	_pierce[i] = _pierce[count]
	_mask[i] = _mask[count]
	_type[i] = _type[count]
	_look[i] = _look[count]


func _look_for(weapon_id: StringName) -> int:
	if _look_of.has(weapon_id):
		return _look_of[weapon_id]
	var looks := Assets.meta(LOOK_ID)
	var raw: Dictionary = looks.get(String(weapon_id), looks.get("default", {}))
	_looks.append({
		"color": Color.from_string(str(raw.get("color", "#ffd27a")), Color.ORANGE),
		"length": float(raw.get("length_u", 0.5)) * PX, "width": float(raw.get("width_u", 0.07)) * PX,
	})
	_look_of[weapon_id] = _looks.size() - 1
	return _looks.size() - 1

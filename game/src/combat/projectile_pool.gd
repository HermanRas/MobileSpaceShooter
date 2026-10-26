class_name ProjectilePool
extends Node2D
## Every shot in flight (PLAN.md 5.5): plain arrays, not a node per bullet. Each physics tick a
## shot moves on, and a ray along that step finds the first hull it crosses. Ships sit on a
## physics layer per team (ShipBody.TEAM_LAYER), so a shot's ray only sees the other side and
## never needs an exclusion list. Every shot draws in one MultiMesh as an additive streak.
##
## Brought forward from Phase 4.4 so the guns of 4.3 have something to fire; 4.4 stress-tested
## it at 600 shots on the phone. 4.6a: a shot with splash explodes where it hits (an airburst one
## also when its fuse runs out), hurting every enemy tile in reach and destroying enemy rockets
## there; a homing shot steers for its target. What a weapon's shots do is kept once per weapon
## (`_specs`), so the per-shot arrays stay small.

## A shot from `weapon_id` moving at `velocity` struck `tile_id` of `body` at `point` (world
## pixels and pixels per second). Emitted before the damage lands.
signal hit(body: ShipBody, tile_id: int, point: Vector2, velocity: Vector2, weapon_id: StringName)
## A shot exploded at `point`, reaching `radius` (world pixels).
signal exploded(point: Vector2, radius: float, weapon_id: StringName)
## An explosion destroyed a rocket at `point`.
signal shot_down(point: Vector2)

const CAPACITY := 1024
const PX := ShipMesh.PX_PER_U
const LOOK_ID := &"vis.fx.projectiles"
## A life below this marks a rocket an explosion destroyed; it goes on its next step.
const DOWNED := -1000.0

## Shots in flight; the first `count` entries of each array are live.
var count := 0
## Shots dropped because the pool was full (4.4 watches this).
var dropped := 0
## Rockets destroyed by explosions, and explosions so far (the sandbox and drives read these).
var downed := 0
var explosions := 0
## Microseconds the last physics step (moves and rays) and the last draw update took.
var step_usec := 0
var draw_usec := 0

var _pos := PackedVector2Array()  # pixels
var _vel := PackedVector2Array()  # pixels per second
var _life := PackedFloat32Array()
var _mask := PackedInt32Array()
var _team := PackedByteArray()
var _spec := PackedInt32Array()
var _look := PackedInt32Array()
## The ShipBody a homing shot steers for, else null.
var _target: Array[Object] = []
## [{"weapon", "damage", "type", "pierce", "splash" (px), "splash_u", "splash_damage",
## "splash_type", "airburst", "homing", "rocket"}], and "weapon|damage" -> index there.
var _specs: Array[Dictionary] = []
var _spec_of := {}
## [{"color", "length", "width"}] in pixels, and weapon id -> index there.
var _looks: Array[Dictionary] = []
var _look_of := {}
var _query := PhysicsRayQueryParameters2D.new()
var _blast_query := PhysicsShapeQueryParameters2D.new()
var _blast_shape := CircleShape2D.new()
var _view := MultiMeshInstance2D.new()
## Live rockets as targets for anti-missile guns: [{"pos", "vel" (U), "team"}], built once a tick.
var _rockets: Array = []
var _rockets_frame := -1


func _ready() -> void:
	_pos.resize(CAPACITY)
	_vel.resize(CAPACITY)
	_life.resize(CAPACITY)
	_mask.resize(CAPACITY)
	_team.resize(CAPACITY)
	_spec.resize(CAPACITY)
	_look.resize(CAPACITY)
	_target.resize(CAPACITY)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = CAPACITY
	multimesh.visible_instance_count = 0
	_view.multimesh = multimesh
	_view.texture = _streak()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_view.material = additive
	add_child(_view)
	_query.hit_from_inside = true  # point-blank: a shot that starts inside a hull hits it
	_blast_query.shape = _blast_shape
	_look_for(&"default")


## Launches a shot from Gunnery.step() (world U and U/s) for `team`; a homing one steers for
## `homing_target`.
func fire(shot: Dictionary, team: int, weapon_id: StringName, homing_target: Node2D = null) -> void:
	if count >= CAPACITY:
		dropped += 1
		return
	var i := count
	_pos[i] = shot["from"] * PX
	_vel[i] = shot["vel"] * PX
	_life[i] = shot["life"]
	_mask[i] = ShipBody.enemy_mask(team)
	_team[i] = team
	_spec[i] = _spec_for(shot, weapon_id)
	_look[i] = _look_for(weapon_id)
	_target[i] = homing_target if float(shot.get("homing", 0.0)) > 0.0 else null
	count += 1


## Every rocket in flight, as targets for anti-missile guns: [{"pos", "vel" (U, U/s), "team"}].
func rockets() -> Array:
	var frame := Engine.get_physics_frames()
	if _rockets_frame != frame:
		_rockets_frame = frame
		_rockets = []
		for i in count:
			if _specs[_spec[i]]["rocket"] and _life[i] > 0.0:
				_rockets.append({"pos": _pos[i] / PX, "vel": _vel[i] / PX, "team": _team[i]})
	return _rockets


func clear() -> void:
	count = 0
	_view.multimesh.visible_instance_count = 0


func _physics_process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	var space := get_world_2d().direct_space_state
	var i := 0
	while i < count:
		if _life[i] <= DOWNED:
			downed += 1
			shot_down.emit(_pos[i])
			_remove(i)
			continue
		var spec := _specs[_spec[i]]
		if _target[i] != null:
			_home(i, spec, delta)
		var to := _pos[i] + _vel[i] * delta
		_query.from = _pos[i]
		_query.to = to
		_query.collision_mask = _mask[i]
		var found := space.intersect_ray(_query)
		if not found.is_empty():
			var body := found["collider"] as ShipBody
			var tile_id := body.tile_at_shape(int(found["shape"])) if body != null else -1
			var velocity := _vel[i]
			var team := _team[i]
			_remove(i)
			if tile_id >= 0:
				hit.emit(body, tile_id, found["position"], velocity, spec["weapon"])
				body.take_hit(tile_id, spec["damage"], spec["type"], spec["pierce"])
			if spec["splash"] > 0.0:
				_explode(space, found["position"], spec, team)
			continue
		_pos[i] = to
		_life[i] -= delta
		if _life[i] <= 0.0:
			var at := _pos[i]
			var team := _team[i]
			_remove(i)
			if spec["airburst"]:
				_explode(space, at, spec, team)
			continue
		i += 1
	step_usec = Time.get_ticks_usec() - started


func _process(_delta: float) -> void:
	var started := Time.get_ticks_usec()
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
	draw_usec = Time.get_ticks_usec() - started


## Steers shot `i` toward its target, or lets it fly straight on once the target is gone.
func _home(i: int, spec: Dictionary, delta: float) -> void:
	var body := _target[i] as ShipBody
	if not is_instance_valid(body) or body.is_wreck() or (body.damage != null and body.damage.dead):
		_target[i] = null
		return
	var toward := body.global_transform * body.center_of_mass - _pos[i]
	_vel[i] = Gunnery.steer(_vel[i], toward, spec["homing"], delta)


## A blast at `point` (pixels): splash damage to every enemy hull in reach, and enemy rockets
## there are destroyed.
func _explode(space: PhysicsDirectSpaceState2D, point: Vector2, spec: Dictionary, team: int) -> void:
	var radius: float = spec["splash"]
	explosions += 1
	exploded.emit(point, radius, spec["weapon"])
	_blast_shape.radius = radius
	_blast_query.transform = Transform2D(0.0, point)
	_blast_query.collision_mask = ShipBody.enemy_mask(team)
	var struck := {}
	for found in space.intersect_shape(_blast_query, 32):
		var body := found["collider"] as ShipBody
		if body != null and not struck.has(body):
			struck[body] = true
	for body: ShipBody in struck:
		if is_instance_valid(body):
			body.take_splash(point, spec["splash_u"], spec["splash_damage"], spec["splash_type"])
	for j in count:
		if _team[j] != team and _specs[_spec[j]]["rocket"] and _pos[j].distance_to(point) <= radius:
			_life[j] = DOWNED - 1.0


## Swap-remove: the last live shot takes slot `i`.
func _remove(i: int) -> void:
	count -= 1
	if i == count:
		_target[i] = null
		return
	_pos[i] = _pos[count]
	_vel[i] = _vel[count]
	_life[i] = _life[count]
	_mask[i] = _mask[count]
	_team[i] = _team[count]
	_spec[i] = _spec[count]
	_look[i] = _look[count]
	_target[i] = _target[count]
	_target[count] = null


func _spec_for(shot: Dictionary, weapon_id: StringName) -> int:
	var key := "%s|%s" % [weapon_id, shot["damage"]]
	if _spec_of.has(key):
		return _spec_of[key]
	_specs.append({
		"weapon": weapon_id, "damage": float(shot["damage"]), "type": StringName(shot["type"]),
		"pierce": float(shot.get("pierce", 0.0)), "splash_u": float(shot.get("splash_u", 0.0)),
		"splash": float(shot.get("splash_u", 0.0)) * PX, "splash_damage": float(shot.get("splash_damage", 0.0)),
		"splash_type": StringName(shot.get("splash_type", "explosive")), "airburst": bool(shot.get("airburst", false)),
		"homing": float(shot.get("homing", 0.0)), "rocket": bool(shot.get("rocket", false)),
	})
	_spec_of[key] = _specs.size() - 1
	return _specs.size() - 1


static var _streak_texture: GradientTexture2D


## A streak that fades in from its tail (u = 0) to a bright head (u = 1).
static func _streak() -> GradientTexture2D:
	if _streak_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.75, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.8), Color(1, 1, 1, 1)])
		_streak_texture = GradientTexture2D.new()
		_streak_texture.gradient = gradient
		_streak_texture.width = 32
		_streak_texture.height = 4
	return _streak_texture


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

class_name WeaponController
extends Node
## Fires its parent ShipBody's guns (PLAN.md 4.4, Phase 4.3): each physics tick, the ship's
## pose and its enemies → Gunnery → shots into the ProjectilePool. When the ship loses tiles,
## the guns on them go too, and the rest keep their aim.
##
## Whoever flies the ship sets `fire_held` (the FIRE button, or later an AI pilot) and
## `all_auto` (the 1-stick scheme, §4.7); `enemies` returns the ShipBodies to shoot at. Enemy
## rockets in the pool are targets too, for anti-missile guns (flak, 4.6a), and a homing shot is
## told which ship it was fired at. A beam (laser, 4.6b) is no shot at all: each tick a ray from
## its muzzle finds where it ends (`beam_ends`, for drawing), and its pulses damage what it hits.

const PX := ShipMesh.PX_PER_U

var gunnery: Gunnery
var fire_held := false
var all_auto := false:
	set(value):
		all_auto = value
		if gunnery != null:
			gunnery.all_auto = value
var enemies: Callable = func() -> Array: return []

## Gun index -> where its beam ends this tick (world pixels), for each beam that's on.
var beam_ends := {}

var _ship: ShipBody
var _pool: ProjectilePool
var _ray := PhysicsRayQueryParameters2D.new()
## How many of the nearest enemies the guns weigh (WeaponLib.nearest_targets; 0 for all).
var _nearest := 0


func attach(ship: ShipBody, pool: ProjectilePool, weapons: WeaponLib, enemy_list: Callable) -> void:
	_ship = ship
	_pool = pool
	enemies = enemy_list
	gunnery = Gunnery.create(ship.guns, weapons)
	_nearest = weapons.nearest_targets
	gunnery.all_auto = all_auto
	ship.rebuilt.connect(func() -> void: gunnery.set_layout(ship.guns))


func _physics_process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	if _ship == null or gunnery.layout.guns.is_empty():
		return
	var targets := []
	var bodies: Array[ShipBody] = []
	for body: Variant in ShipBody.nearest(enemies.call(), _ship.global_position, _nearest):
		var enemy := body as ShipBody
		if is_instance_valid(enemy) and not enemy.is_wreck() and enemy.damage != null and not enemy.damage.dead:
			targets.append({"pos": enemy.global_transform * enemy.center_of_mass / PX, "vel": enemy.linear_velocity / PX})
			bodies.append(enemy)
	var missiles := _pool.rockets().filter(func(r: Dictionary) -> bool: return r["team"] != _ship.team)
	var shots := gunnery.step(delta, _ship.global_position / PX, _ship.global_rotation, _ship.linear_velocity / PX,
			targets, fire_held, missiles)
	var beam_hits := _trace_beams()
	for shot in shots:
		var gun := gunnery.layout.guns[shot["gun"]]
		if shot["beam"]:
			_beam_pulse(shot, gun, beam_hits.get(shot["gun"], {}))
			continue
		var aimed: int = shot["target"]
		_pool.fire(shot, _ship.team, gun.weapon, bodies[aimed] if aimed >= 0 and aimed < bodies.size() else null,
				StringName(gun.item))
	BenchRun.spent(&"guns", started)


## A ray down every beam that's on: fills `beam_ends` and returns gun index -> the ray's hit.
func _trace_beams() -> Dictionary:
	beam_ends.clear()
	var hits := {}
	var space := _ship.get_world_2d().direct_space_state
	_ray.collision_mask = ShipBody.enemy_mask(_ship.team)
	_ray.hit_from_inside = true
	for i in gunnery.layout.guns.size():
		if not gunnery.beaming[i]:
			continue
		var gun := gunnery.layout.guns[i]
		var along := Vector2.from_angle(gunnery.angles[i] + _ship.global_rotation)
		var from := _ship.global_position + (gun.pivot * PX).rotated(_ship.global_rotation) + along * gun.muzzle * PX
		_ray.from = from
		_ray.to = from + along * float(gun.stats["range_u"]) * PX
		var found := space.intersect_ray(_ray)
		beam_ends[i] = found["position"] if not found.is_empty() else _ray.to
		if not found.is_empty():
			found["along"] = along
			hits[i] = found
	return hits


## One pulse of a beam's damage on what its ray hit, with sparks.
func _beam_pulse(shot: Dictionary, gun: GunLayout.Gun, found: Dictionary) -> void:
	var body := found.get("collider") as ShipBody
	if body == null:
		return
	var tile_id := body.tile_at_shape(int(found["shape"]))
	if tile_id < 0:
		return
	_pool.hit.emit(body, tile_id, found["position"], (found["along"] as Vector2) * 1000.0, gun.weapon)
	body.take_hit(tile_id, shot["damage"], shot["type"], shot["pierce"], StringName(gun.item))

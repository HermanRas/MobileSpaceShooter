class_name WeaponController
extends Node
## Fires its parent ShipBody's guns (PLAN.md 4.4, Phase 4.3): each physics tick, the ship's
## pose and its enemies → Gunnery → shots into the ProjectilePool. When the ship loses tiles,
## the guns on them go too, and the rest keep their aim.
##
## Whoever flies the ship sets `fire_held` (the FIRE button, or later an AI pilot) and
## `all_auto` (the 1-stick scheme, §4.7); `enemies` returns the ShipBodies to shoot at.

const PX := ShipMesh.PX_PER_U

var gunnery: Gunnery
var fire_held := false
var all_auto := false:
	set(value):
		all_auto = value
		if gunnery != null:
			gunnery.all_auto = value
var enemies: Callable = func() -> Array: return []

var _ship: ShipBody
var _pool: ProjectilePool


func attach(ship: ShipBody, pool: ProjectilePool, weapons: WeaponLib, enemy_list: Callable) -> void:
	_ship = ship
	_pool = pool
	enemies = enemy_list
	gunnery = Gunnery.create(ship.guns, weapons)
	gunnery.all_auto = all_auto
	ship.rebuilt.connect(func() -> void: gunnery.set_layout(ship.guns))


func _physics_process(delta: float) -> void:
	if _ship == null or gunnery.layout.guns.is_empty():
		return
	var targets := []
	for body: Variant in enemies.call():
		var enemy := body as ShipBody
		if is_instance_valid(enemy) and not enemy.is_wreck() and enemy.damage != null and not enemy.damage.dead:
			targets.append({"pos": enemy.global_transform * enemy.center_of_mass / PX, "vel": enemy.linear_velocity / PX})
	var shots := gunnery.step(delta, _ship.global_position / PX, _ship.global_rotation, _ship.linear_velocity / PX,
			targets, fire_held)
	var mask := ShipBody.enemy_mask(_ship.team)
	for shot in shots:
		_pool.fire(shot["from"], shot["vel"], shot["life"], shot["damage"], shot["type"], shot["pierce"], mask,
				gunnery.layout.guns[shot["gun"]].weapon)

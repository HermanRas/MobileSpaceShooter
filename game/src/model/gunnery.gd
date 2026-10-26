class_name Gunnery
extends RefCounted
## Aims and fires one ship's guns (PLAN.md 4.4, Phase 4.3), one physics tick at a time:
## world-space numbers in, shots out, so it runs headless.
##
## Every gun looks for the nearest target whose lead point it can reach and has a clear line to,
## and turns toward it at its mount's turn rate. An auto gun fires once its barrel is on that
## point. A manual gun fires while FIRE is held, wherever it points (a manual swivel still
## tracks a target in its arc). In the 1-stick scheme every gun is auto (`all_auto`, §4.7).
## A side-mounted gun never fires into its own ship; a turret fires over it (GunLayout). Shots carry the ship's velocity, and the
## lead accounts for it.

var layout: GunLayout
## A gun fires once it's within this of its aim (radians).
var fire_within: float = deg_to_rad(3.0)
var all_auto := false
## Per gun, in layout order: its ship-local angle, seconds until it may fire again, how far a
## multi gatling has spun up (0..1), the index of the target it's aiming at (-1 for none), and
## the shots it has fired.
var angles := PackedFloat32Array()
var cooldowns := PackedFloat32Array()
var spins := PackedFloat32Array()
var aims := PackedInt32Array()
var fired := PackedInt32Array()
var rng := RandomNumberGenerator.new()


static func create(gun_layout: GunLayout, weapons: WeaponLib) -> Gunnery:
	var out := Gunnery.new()
	out.fire_within = weapons.fire_within
	out.set_layout(gun_layout)
	return out


## Swaps in a new layout (the ship lost tiles), keeping each surviving gun's angle, cooldown
## and count by its key.
func set_layout(gun_layout: GunLayout) -> void:
	var before := {}
	if layout != null:
		for i in layout.guns.size():
			before[layout.guns[i].key] = [angles[i], cooldowns[i], fired[i], spins[i]]
	layout = gun_layout
	var count := layout.guns.size()
	angles.resize(count)
	cooldowns.resize(count)
	spins.resize(count)
	aims.resize(count)
	fired.resize(count)
	aims.fill(-1)
	for i in count:
		var kept: Array = before.get(layout.guns[i].key, [layout.guns[i].facing, 0.0, 0, 0.0])
		angles[i] = kept[0]
		cooldowns[i] = kept[1]
		fired[i] = kept[2]
		spins[i] = kept[3]


## One tick. The ship's position (U), rotation and velocity (U/s) are in world space, and so are
## `targets`: [{"pos", "vel"}]. Returns the shots fired, in world space:
## [{"gun": index, "from", "vel", "life", "damage", "type", "pierce"}].
func step(delta: float, ship_pos: Vector2, ship_rotation: float, ship_vel: Vector2, targets: Array,
		fire_held: bool) -> Array[Dictionary]:
	var shots: Array[Dictionary] = []
	for i in layout.guns.size():
		var gun := layout.guns[i]
		var pivot := ship_pos + gun.pivot.rotated(ship_rotation)
		var muzzle := pivot + Vector2.from_angle(angles[i] + ship_rotation) * gun.muzzle
		var aim := _choose(gun, muzzle, ship_rotation, ship_vel, targets)
		aims[i] = aim[0]
		var want: float = aim[1] if aim[0] >= 0 else gun.facing
		angles[i] = _turn(gun, angles[i], want, delta)
		cooldowns[i] -= delta
		var firing: bool
		if gun.auto or all_auto:
			firing = aim[0] >= 0 and absf(angle_difference(angles[i], want)) <= fire_within
		else:
			firing = fire_held
		firing = firing and gun.clear(angles[i])
		var rate := _spin(i, gun, firing, delta)
		if not firing:
			cooldowns[i] = maxf(cooldowns[i], 0.0)
			continue
		while cooldowns[i] <= 0.0:
			shots.append(_shot(i, gun, pivot, ship_rotation, ship_vel))
			cooldowns[i] += 1.0 / rate
	return shots


## When a shot at `speed` meets a target `rel_pos` away moving at `rel_vel` (both relative to
## the shooter), or -1 if it never can.
static func intercept_time(rel_pos: Vector2, rel_vel: Vector2, speed: float) -> float:
	var a := rel_vel.dot(rel_vel) - speed * speed
	var b := 2.0 * rel_pos.dot(rel_vel)
	var c := rel_pos.dot(rel_pos)
	if absf(a) < 0.000001:
		return -c / b if b < 0.0 else -1.0
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return -1.0
	var root := sqrt(disc)
	var t1 := (-b - root) / (2.0 * a)
	var t2 := (-b + root) / (2.0 * a)
	var t := minf(t1, t2) if minf(t1, t2) > 0.0 else maxf(t1, t2)
	return t if t > 0.0 else -1.0


## [target index, ship-local angle to its lead point] for the nearest target this gun can
## reach, in range and with a clear line; [-1, 0] if none. The lead is worked out from where the
## muzzle is now, which is where the shot will start once the barrel is on.
func _choose(gun: GunLayout.Gun, muzzle: Vector2, ship_rotation: float, ship_vel: Vector2, targets: Array) -> Array:
	var speed := float(gun.stats["speed_u"])
	var reach_s := float(gun.stats["range_u"]) / speed
	var best := [-1, 0.0]
	var best_d := INF
	for t in targets.size():
		var rel_pos: Vector2 = targets[t]["pos"] - muzzle
		var rel_vel: Vector2 = targets[t]["vel"] - ship_vel
		var time := intercept_time(rel_pos, rel_vel, speed)
		if time < 0.0 or time > reach_s:
			continue
		var angle := wrapf((rel_pos + rel_vel * time).angle() - ship_rotation, -PI, PI)
		if not gun.reaches(angle, fire_within) or not gun.clear(gun.clamp_to_arc(angle)):
			continue
		if rel_pos.length_squared() < best_d:
			best_d = rel_pos.length_squared()
			best = [t, angle]
	return best


## Spins a multi gatling up while it fires and down while it doesn't; returns its rate now.
func _spin(index: int, gun: GunLayout.Gun, firing: bool, delta: float) -> float:
	var spin_up := float(gun.stats["spin_up_s"])
	if spin_up <= 0.0:
		return gun.stats["rate"]
	var change := delta / spin_up if firing else -delta / float(gun.stats["spin_down_s"])
	spins[index] = clampf(spins[index] + change, 0.0, 1.0)
	return lerpf(gun.stats["rate_start"], gun.stats["rate"], spins[index])


## `from` turned toward `to` by at most one tick's worth, staying in the gun's arc.
static func _turn(gun: GunLayout.Gun, from: float, to: float, delta: float) -> float:
	var step := gun.turn_rate * delta
	if gun.arc >= PI:
		return wrapf(from + clampf(angle_difference(from, to), -step, step), -PI, PI)
	var target_off := clampf(angle_difference(gun.facing, to), -gun.arc, gun.arc)
	return gun.facing + move_toward(angle_difference(gun.facing, from), target_off, step)


func _shot(index: int, gun: GunLayout.Gun, pivot: Vector2, ship_rotation: float, ship_vel: Vector2) -> Dictionary:
	fired[index] += 1
	var barrel := Vector2.from_angle(angles[index] + ship_rotation)
	var spread := gun.spread
	var heading := Vector2.from_angle(angles[index] + ship_rotation + rng.randf_range(-spread, spread))
	var speed := float(gun.stats["speed_u"])
	return {
		"gun": index, "from": pivot + barrel * gun.muzzle, "vel": ship_vel + heading * speed,
		"life": float(gun.stats["range_u"]) / speed, "damage": gun.stats["damage"],
		"type": gun.stats["damage_type"], "pierce": gun.stats["pierce"],
	}

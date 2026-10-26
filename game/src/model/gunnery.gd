class_name Gunnery
extends RefCounted
## Aims and fires one ship's guns (PLAN.md 4.4, Phase 4.3), one physics tick at a time:
## world-space numbers in, shots out, so it runs headless.
##
## Every gun looks for the nearest target whose lead point it can reach and has a clear line to,
## and turns toward it at its mount's turn rate. An auto gun fires once its barrel is on that
## point. A manual gun fires while FIRE is held, wherever it points (a manual swivel still
## tracks a target in its arc). In the 1-stick scheme every gun is auto (`all_auto`, §4.7).
## A side-mounted gun never fires into its own ship; a turret fires over it (GunLayout).
## 4.6a: an anti-missile gun (flak) also considers enemy rockets as targets; a flak pellet's fuse
## is timed to its target, and a homing shot names the target it should steer for.
## 4.6b: a beam gun (laser) heats while it fires and stops when it overheats, until it has cooled
## to heat_resume; `beaming` says which beams are on this tick. A mine layer drops behind the
## ship, ignoring arcs and the hull; on auto it drops while an enemy is within its range. Shots carry the ship's velocity, and the
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
## Per gun: a beam's heat (0..1), whether it overheated, and whether it's firing this tick.
var heats := PackedFloat32Array()
var overheated: Array[bool] = []
var beaming: Array[bool] = []
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
			before[layout.guns[i].key] = [angles[i], cooldowns[i], fired[i], spins[i], heats[i], overheated[i]]
	layout = gun_layout
	var count := layout.guns.size()
	angles.resize(count)
	cooldowns.resize(count)
	spins.resize(count)
	heats.resize(count)
	overheated.resize(count)
	beaming.resize(count)
	beaming.fill(false)
	aims.resize(count)
	fired.resize(count)
	aims.fill(-1)
	for i in count:
		var kept: Array = before.get(layout.guns[i].key, [layout.guns[i].facing, 0.0, 0, 0.0, 0.0, false])
		angles[i] = kept[0]
		cooldowns[i] = kept[1]
		fired[i] = kept[2]
		spins[i] = kept[3]
		heats[i] = kept[4]
		overheated[i] = kept[5]


## One tick. The ship's position (U), rotation and velocity (U/s) are in world space, and so are
## `targets` and the enemy `missiles`: [{"pos", "vel"}]. Returns the shots fired, in world space:
## [{"gun": index, "from", "vel", "life", "damage", "type", "pierce", "splash_u",
## "splash_damage", "splash_type", "airburst", "homing", "rocket", "target"}], where `target`
## indexes `targets` then `missiles` (-1 for none).
func step(delta: float, ship_pos: Vector2, ship_rotation: float, ship_vel: Vector2, targets: Array,
		fire_held: bool, missiles: Array = []) -> Array[Dictionary]:
	var shots: Array[Dictionary] = []
	var everything := targets + missiles if not missiles.is_empty() else targets
	for i in layout.guns.size():
		var gun := layout.guns[i]
		var pivot := ship_pos + gun.pivot.rotated(ship_rotation)
		var muzzle := pivot + Vector2.from_angle(angles[i] + ship_rotation) * gun.muzzle
		var aim := _choose(gun, muzzle, ship_rotation, ship_vel, everything if gun.stats["anti_missile"] else targets)
		aims[i] = aim[0]
		var want: float = aim[1] if aim[0] >= 0 else gun.facing
		angles[i] = _turn(gun, angles[i], want, delta)
		cooldowns[i] -= delta
		var firing: bool
		var mine: bool = gun.stats["proximity_u"] > 0.0
		if mine:
			firing = fire_held if not (gun.auto or all_auto) else _any_within(pivot, targets, gun.stats["range_u"])
		elif gun.auto or all_auto:
			firing = aim[0] >= 0 and absf(angle_difference(angles[i], want)) <= fire_within
		else:
			firing = fire_held
		firing = firing and (mine or gun.clear(angles[i]))
		if gun.stats["beam"]:
			firing = _heat(i, gun, firing, delta)
			beaming[i] = firing
		var rate := _spin(i, gun, firing, delta)
		if not firing:
			cooldowns[i] = maxf(cooldowns[i], 0.0)
			continue
		while cooldowns[i] <= 0.0:
			fired[i] += 1
			for p in int(gun.stats["pellets"]):
				shots.append(_shot(i, gun, pivot, ship_rotation, ship_vel, aim[0], aim[2]))
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


## [target index, ship-local angle to its lead point, seconds to get there] for the nearest
## target this gun can reach, in range and with a clear line; [-1, 0, 0] if none. The lead is
## worked out from where the muzzle is now, which is where the shot will start once the barrel
## is on.
func _choose(gun: GunLayout.Gun, muzzle: Vector2, ship_rotation: float, ship_vel: Vector2, targets: Array) -> Array:
	var speed := float(gun.stats["speed_u"])
	var reach_s := float(gun.stats["range_u"]) / speed
	var best := [-1, 0.0, 0.0]
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
			best = [t, angle, time]
	return best


## Heats a beam while it fires and cools it while it doesn't; returns whether it may fire.
func _heat(index: int, gun: GunLayout.Gun, wants: bool, delta: float) -> bool:
	var firing := wants and not overheated[index]
	if firing:
		heats[index] = minf(heats[index] + delta / float(gun.stats["heat_s"]), 1.0)
		if heats[index] >= 1.0:
			overheated[index] = true
	else:
		heats[index] = maxf(heats[index] - delta / float(gun.stats["cool_s"]), 0.0)
		if overheated[index] and heats[index] <= float(gun.stats["heat_resume"]):
			overheated[index] = false
	return firing


static func _any_within(point: Vector2, targets: Array, reach: float) -> bool:
	for target: Dictionary in targets:
		if (target["pos"] as Vector2).distance_to(point) <= reach:
			return true
	return false


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


## Turns a homing shot's velocity toward `toward` (the way to its target) by at most
## `turn_rate` × `delta`, keeping its speed.
static func steer(vel: Vector2, toward: Vector2, turn_rate: float, delta: float) -> Vector2:
	var step := turn_rate * delta
	return vel.rotated(clampf(angle_difference(vel.angle(), toward.angle()), -step, step))


## One shot (or one flak pellet) at `target` (-1 for none), which the aim reaches in `time` s.
func _shot(index: int, gun: GunLayout.Gun, pivot: Vector2, ship_rotation: float, ship_vel: Vector2,
		target: int, time: float) -> Dictionary:
	var stats := gun.stats
	var barrel := Vector2.from_angle(angles[index] + ship_rotation)
	var spread := gun.spread
	var heading := Vector2.from_angle(angles[index] + ship_rotation + rng.randf_range(-spread, spread))
	var speed := float(stats["speed_u"])
	var life := float(stats["range_u"]) / speed if stats["life_s"] <= 0.0 else float(stats["life_s"])
	if stats["airburst"] and target >= 0:
		life = minf(time, life)  # the fuse: burst where the target will be
	return {
		"gun": index, "from": pivot + barrel * gun.muzzle, "vel": ship_vel + heading * speed,
		"life": life, "damage": stats["damage"], "type": stats["damage_type"], "pierce": stats["pierce"],
		"splash_u": stats["splash_u"], "splash_damage": stats["splash_damage"], "splash_type": stats["splash_type"],
		"airburst": stats["airburst"], "homing": stats["homing"], "rocket": stats["rocket"], "target": target,
		"beam": stats["beam"], "proximity_u": stats["proximity_u"], "drag": stats["drag"],
	}

class_name GunLayout
extends RefCounted
## Where a ship's guns sit and which way they can shoot (PLAN.md 4.4, Phase 4.3).
##
## Ship-local, in U and radians: 0 is forward (+x) and angles grow toward +y (the ship's right),
## as Godot's do. A side-mounted gun never fires through its own ship: `blocked` holds the
## directions in which a shot from its pivot would cross another of the ship's tiles (its host is
## left out; the gun points away from it). A mount type with `over_hull` (the turret, on top of
## the ship) fires over its own tiles and has nothing blocked.

## One mounted gun.
class Gun:
	## Index in the blueprint's mounts.
	var mount: int
	## Its place on the ship ("tile:edge:port" or "tile:face"), which stays the same when the
	## ship loses other tiles, so aim and cooldown can carry over.
	var key: String
	var weapon: StringName
	var mount_type: StringName
	var auto: bool
	var host: int
	var pivot: Vector2
	## Where it points at rest, and how far it turns either side of that (PI for a turret).
	var facing: float
	var arc: float
	var turn_rate: float
	## Pivot to muzzle, in U.
	var muzzle: float
	## The weapon's numbers (WeaponLib.weapon()) at its level.
	var stats: Dictionary
	## The inventory gun fitted here (`"gun"` on the mount, PLAN.md 5.4), or "" (Creative, enemies).
	var item := ""
	## Its level (L1-L999), and the scatter that gives it (rad either side of the aim).
	var level := 1
	var spread := 0.0
	## Each blocked direction range as (centre, half-width).
	var blocked := PackedVector2Array()

	## Whether the gun can turn to `angle` (give or take `slack`).
	func reaches(angle: float, slack := 0.0) -> bool:
		return absf(angle_difference(facing, angle)) <= arc + slack

	## `angle` pulled into the gun's arc.
	func clamp_to_arc(angle: float) -> float:
		if arc >= PI:
			return wrapf(angle, -PI, PI)
		return facing + clampf(angle_difference(facing, angle), -arc, arc)

	## Whether a shot at `angle` misses the ship's own tiles.
	func clear(angle: float) -> bool:
		for range_ in blocked:
			if absf(angle_difference(range_.x, angle)) < range_.y:
				return false
		return true

	## The share of its arc it can shoot into (sampled every 2°; a fixed gun is 0 or 1).
	func clear_share() -> float:
		if arc <= 0.0:
			return 1.0 if clear(facing) else 0.0
		var steps := maxi(roundi(arc * 2.0 / deg_to_rad(2.0)), 1)
		var open := 0
		for i in steps + 1:
			if clear(facing - arc + arc * 2.0 * i / steps):
				open += 1
		return float(open) / (steps + 1)


var guns: Array[Gun] = []
## [{"code": &"gun_blocked", "text"}]: shown amber in the hangar, never blocking (like 4.10's).
var warnings: Array[Dictionary] = []


## Every gun at `level`, except a fitted inventory gun named in `levels` (item id -> level),
## which is at its own (Phase 4.8b), and with `own_levels`, a Creative gun with a `level` on its
## mount (7.1). `damage_share` scales every gun's damage (an encounter's enemies, 5.3).
static func compute(bp: Blueprint, placement: Placement, level := 1, levels := {}, damage_share := 1.0,
		own_levels := false) -> GunLayout:
	var layout := GunLayout.new()
	if placement.weapons == null:
		return layout
	for i in bp.mounts.size():
		var gun := _gun(bp, placement, i)
		if gun != null:
			gun.item = str(bp.mounts[i].get("gun", ""))
			var fallback := int(bp.mounts[i].get("level", level)) if own_levels else level
			gun.level = clampi(int(levels.get(gun.item, fallback)), 1, placement.weapons.xp.max_level)
			gun.stats = placement.weapons.xp.scaled(gun.stats, gun.level, damage_share)
			gun.spread = WeaponLib.spread_for(gun.stats, gun.level)
			layout.guns.append(gun)
	for gun in layout.guns:
		if gun.clear_share() <= 0.0:
			layout.warnings.append({"code": &"gun_blocked",
					"text": "the %s on tile %d can't fire past the hull" % [String(gun.stats["name"]).to_lower(), gun.host]})
	return layout


func manual_count() -> int:
	return guns.filter(func(g: Gun) -> bool: return not g.auto).size()


## Total damage per second with every gun firing at its top rate, every pellet and splash
## landing (before armor and shields).
func dps() -> float:
	var total := 0.0
	for gun in guns:
		var stats := gun.stats
		total += (float(stats["damage"]) + float(stats["splash_damage"])) * int(stats["pellets"]) * float(stats["rate"])
	return total


static func _gun(bp: Blueprint, placement: Placement, index: int) -> Gun:
	var mount := bp.mounts[index]
	var weapon_id := WeaponLib.type_of_part(str(mount.get("part", "")))
	var type := StringName(mount.get("mount", ""))
	if not placement.weapons.allows(weapon_id, type):
		return null
	var rules := placement.weapons.mount_type(type)
	var gun := Gun.new()
	gun.mount = index
	gun.weapon = weapon_id
	gun.mount_type = type
	gun.stats = placement.weapons.weapon(weapon_id)
	gun.host = int(mount["tile"])
	gun.auto = placement.weapons.mode_for(type, StringName(mount.get("mode", ""))) == &"auto"
	gun.arc = rules["arc"]
	gun.turn_rate = rules["turn_rate"]
	if Mounting.is_face(mount):
		var at := Mounting.face_frame(placement, bp, mount)
		if at.is_empty():
			return null
		gun.key = "%d:face" % gun.host
		gun.pivot = at["center"]
		gun.facing = 0.0
		gun.muzzle = float(at["radius"]) + float(gun.stats["length_u"])
	else:
		var at := Mounting.frame(placement, bp, mount)
		if at.is_empty():
			return null
		gun.key = "%d:%d:%d" % [gun.host, int(mount["edge"]), int(mount["port"])]
		gun.pivot = at["center"]
		gun.facing = (at["normal"] as Vector2).angle()
		gun.muzzle = at["depth"]
	if not rules["over_hull"]:
		gun.blocked = _blocked(bp, placement, gun.pivot, gun.host)
	return gun


## The directions from `pivot` that cross a tile other than `host`, merged into as few ranges
## as possible. A convex tile seen from outside covers one range of directions, from its
## vertices' smallest to largest angle.
static func _blocked(bp: Blueprint, placement: Placement, pivot: Vector2, host: int) -> PackedVector2Array:
	var spans: Array[Vector2] = []  # (start, end), start in [-PI, PI), end > start
	for tile in bp.tiles:
		if tile.id == host or placement.tiles.tile(tile.type) == null:
			continue
		var polygon := placement.tile_polygon(tile)
		var toward := (ShipStats.polygon_centroid(polygon) - pivot).angle()
		var low := INF
		var high := -INF
		for p in polygon:
			var off := angle_difference(toward, (p - pivot).angle())
			low = minf(low, off)
			high = maxf(high, off)
		var start := wrapf(toward + low, -PI, PI)
		var end := start + (high - low)
		if end > PI:  # split at the wrap so every span sorts by its start
			spans.append(Vector2(start, PI))
			spans.append(Vector2(-PI, end - TAU))
		else:
			spans.append(Vector2(start, end))
	spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var out := PackedVector2Array()
	var current := Vector2(NAN, NAN)
	for s in spans:
		if not is_nan(current.x) and s.x <= current.y:
			current.y = maxf(current.y, s.y)
			continue
		if not is_nan(current.x):
			out.append(Vector2((current.x + current.y) * 0.5, (current.y - current.x) * 0.5))
		current = s
	if not is_nan(current.x):
		out.append(Vector2((current.x + current.y) * 0.5, (current.y - current.x) * 0.5))
	return out

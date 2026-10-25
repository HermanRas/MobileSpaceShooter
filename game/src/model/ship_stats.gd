class_name ShipStats
extends RefCounted
## Totals computed from a blueprint (PLAN.md 4.2, Phase 1.5). Never stored; always recomputed.
##
## Each tile's mass is spread evenly over its polygon, so the centre of mass and moment of
## inertia come from the real shapes. Units are U and mass units; Phase 3 converts to pixels.

var tile_count: int = 0
var hp: float = 0.0
## Armor averaged over the ship's HP: how much a typical hit is reduced.
var armor_avg: float = 0.0
var shield_cap: float = 0.0
var shield_regen: float = 0.0
var mass: float = 0.0
var center_of_mass: Vector2 = Vector2.ZERO
## Polar moment of inertia about the centre of mass.
var inertia: float = 0.0
## Material -> total, for every tile.
var cost: Dictionary = {}
## Thrusters that resolved (known part, size, level, and a place on the ship).
var thruster_count: int = 0


## Tiles with unknown types or shapes are skipped; run `Placement.validate()` first.
static func compute(bp: Blueprint, placement: Placement) -> ShipStats:
	var stats := ShipStats.new()
	var parts: Array = []  # [mass, centroid, inertia about own centroid]
	var armor_weighted := 0.0
	for tile in bp.tiles:
		var def := placement.tiles.tile(tile.type)
		if def == null or placement.shapes.shape(tile.shape) == null:
			continue
		var tile_stats := def.stats(tile.size)
		var polygon := placement.tile_polygon(tile)
		var area := polygon_area(polygon)
		var tile_mass: float = tile_stats[&"mass"]
		stats.tile_count += 1
		stats.hp += tile_stats[&"hp"]
		armor_weighted += tile_stats[&"armor"] * tile_stats[&"hp"]
		stats.shield_cap += tile_stats[&"shield_cap"]
		stats.shield_regen += tile_stats[&"shield_regen"]
		stats.mass += tile_mass
		var tile_cost := def.cost(tile.size)
		for material: StringName in tile_cost:
			stats.cost[material] = stats.cost.get(material, 0) + tile_cost[material]
		var centroid := polygon_centroid(polygon)
		var own_inertia := tile_mass * polygon_polar_moment(polygon, centroid) / area if area > 0.0 else 0.0
		parts.append([tile_mass, centroid, own_inertia])
		stats.center_of_mass += centroid * tile_mass

	# Thrusters weigh something too, as a point mass where they're mounted (3.2).
	if placement.thrusters != null:
		for mount in bp.mounts:
			var spec := placement.thrusters.spec(ThrusterLib.type_of_part(str(mount.get("part", ""))),
					StringName(mount.get("size", "")), int(mount.get("level", 0)))
			var mount_frame := Mounting.frame(placement, bp, mount)
			if spec.is_empty() or mount_frame.is_empty():
				continue
			var thruster_mass: float = spec["mass"]
			stats.thruster_count += 1
			stats.mass += thruster_mass
			parts.append([thruster_mass, mount_frame["center"], 0.0])
			stats.center_of_mass += mount_frame["center"] * thruster_mass

	if stats.mass > 0.0:
		stats.center_of_mass /= stats.mass
	if stats.hp > 0.0:
		stats.armor_avg = armor_weighted / stats.hp
	for part: Array in parts:
		var offset: Vector2 = part[1] - stats.center_of_mass
		stats.inertia += part[2] + part[0] * offset.length_squared()
	return stats


static func polygon_area(polygon: PackedVector2Array) -> float:
	var sum := 0.0
	for i in polygon.size():
		var p := polygon[i]
		var q := polygon[(i + 1) % polygon.size()]
		sum += p.cross(q)
	return absf(sum) * 0.5


static func polygon_centroid(polygon: PackedVector2Array) -> Vector2:
	var weighted := Vector2.ZERO
	var twice_area := 0.0
	for i in polygon.size():
		var p := polygon[i]
		var q := polygon[(i + 1) % polygon.size()]
		var c := p.cross(q)
		weighted += (p + q) * c
		twice_area += c
	return weighted / (3.0 * twice_area)


## The polygon's polar second moment of area about `about` (multiply by mass / area for inertia).
static func polygon_polar_moment(polygon: PackedVector2Array, about: Vector2) -> float:
	var sum := 0.0
	for i in polygon.size():
		var p := polygon[i] - about
		var q := polygon[(i + 1) % polygon.size()] - about
		sum += p.cross(q) * (p.dot(p) + p.dot(q) + q.dot(q))
	return absf(sum) / 12.0

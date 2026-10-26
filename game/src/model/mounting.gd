class_name Mounting
extends RefCounted
## Where parts sit on hardpoints (PLAN.md 4.3, 4.4, 5.4): the geometry of a mount, the free
## slots for a new one, and what makes an existing one invalid. Static helpers over a
## Placement, which carries the rules (`placement.thrusters`, `placement.weapons`).
##
## An edge mount is {"tile", "edge", "port", "part", ...}: it covers consecutive ports of that
## edge, starting at `port`. A thruster ({"size", "level"}) covers 1/2/4 ports for S/M/L and
## sticks out depth_factor × its length; its exhaust points along the edge's outward normal,
## and it pushes the ship the other way. An edge gun ({"mount": fixed|swivel, "mode"}) covers
## its weapon's edge_u and its barrel sticks out length_u.
##
## A face mount is {"tile", "face": true, "part", "mount": "turret", "mode"}: a turret on the
## middle of a hardpoint, one per tile, which needs a circle of turret_radius_u to fit.
## A rear_only gun (mines) goes only on an edge facing back: its normal within REAR_DOT of -x.

const REAR_DOT := 0.7


## An edge mount's place on its host, in ship units, or {} if the reference is broken (or it's
## a face mount):
##   a, b      the covered stretch of the edge (a → b follows the edge's own direction)
##   center    its midpoint: where a thruster's force is applied, and an edge gun's pivot
##   normal    outward: the exhaust direction, or the way the gun points at rest
##   length    |b - a|
##   depth     how far the part sticks out
##   ports     the covered port positions
static func frame(placement: Placement, bp: Blueprint, mount: Dictionary) -> Dictionary:
	if is_face(mount):
		return {}
	var tile := _host(placement, bp, mount)
	if tile == null:
		return {}
	var edges := placement.tile_edges(tile)
	var edge_index := int(mount.get("edge", -1))
	if edge_index < 0 or edge_index >= edges.size():
		return {}
	var edge := edges[edge_index]
	var count := span(placement, mount)
	var first := int(mount.get("port", -1))
	if not edge.attachable or count < 1 or first < 0 or first + count > edge.ports.size():
		return {}
	var along := (edge.b - edge.a).normalized()
	var half := placement.shapes.port_pitch * 0.5
	var a := edge.ports[first] - along * half
	var b := edge.ports[first + count - 1] + along * half
	var length := a.distance_to(b)
	return {
		"a": a, "b": b, "center": (a + b) * 0.5, "normal": edge.normal, "length": length,
		"depth": _depth(placement, mount, length), "ports": edge.ports.slice(first, first + count),
	}


## A turret's place: {"center": the host tile's centroid, "radius"}, or {} if the reference is
## broken, it isn't a face mount, or the turret doesn't fit the face.
static func face_frame(placement: Placement, bp: Blueprint, mount: Dictionary) -> Dictionary:
	var tile := _host(placement, bp, mount) if is_face(mount) else null
	var radius := float(_weapon_def(placement, mount).get("turret_radius_u", 0.0))
	if tile == null or radius <= 0.0 or not face_fits(placement, tile, radius):
		return {}
	return {"center": ShipStats.polygon_centroid(placement.tile_polygon(tile)), "radius": radius}


## Where a mount sits, whatever kind it is: an edge mount's centre or a turret's: the point
## its mass is added at, and a gun's pivot. Vector2.INF if the reference is broken.
static func anchor(placement: Placement, bp: Blueprint, mount: Dictionary) -> Vector2:
	var at := face_frame(placement, bp, mount) if is_face(mount) else frame(placement, bp, mount)
	return at["center"] if not at.is_empty() else Vector2.INF


static func is_face(mount: Dictionary) -> bool:
	return bool(mount.get("face", false))


static func is_weapon(mount: Dictionary) -> bool:
	return WeaponLib.type_of_part(str(mount.get("part", ""))) != &""


static func is_thruster(mount: Dictionary) -> bool:
	return str(mount.get("part", "")).begins_with(ThrusterLib.PART_PREFIX)


## Whether two mounts sit in the same place (the same face, or the same edge and first port).
static func same_place(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty() or int(a.get("tile", -1)) != int(b.get("tile", -2)) or is_face(a) != is_face(b):
		return false
	return is_face(a) or (int(a.get("edge", -1)) == int(b.get("edge", -2)) and int(a.get("port", -1)) == int(b.get("port", -2)))


## The place keys of a mount: {"tile", "face"} or {"tile", "edge", "port"}.
static func place_of(mount: Dictionary) -> Dictionary:
	if is_face(mount):
		return {"tile": int(mount["tile"]), "face": true}
	return {"tile": int(mount["tile"]), "edge": int(mount["edge"]), "port": int(mount["port"])}


## A copy of `mount` moved to `slot` (a place from the slot lists).
static func moved_to(mount: Dictionary, slot: Dictionary) -> Dictionary:
	var out := mount.duplicate()
	for key in ["tile", "face", "edge", "port"]:
		out.erase(key)
	out.merge(place_of(slot), true)
	return out


## How many ports an edge part covers, or 0 for an unknown size or gun.
static func span(placement: Placement, mount: Dictionary) -> int:
	if is_thruster(mount):
		return port_count(placement, StringName(mount.get("size", "")))
	var edge_u := float(_weapon_def(placement, mount).get("edge_u", 0.0))
	return roundi(edge_u / placement.shapes.port_pitch) if edge_u > 0.0 else 0


## How many ports a thruster of this size covers, or 0 for an unknown size.
static func port_count(placement: Placement, size_code: StringName) -> int:
	var edge_u := placement.shapes.edge_u(size_code)
	return roundi(edge_u / placement.shapes.port_pitch) if edge_u > 0.0 else 0


## Whether a circle of `radius` around the tile's centroid stays inside the tile.
static func face_fits(placement: Placement, tile: Blueprint.Tile, radius: float) -> bool:
	var polygon := placement.tile_polygon(tile)
	var center := ShipStats.polygon_centroid(polygon)
	for i in polygon.size():
		var a := polygon[i]
		var along := (polygon[(i + 1) % polygon.size()] - a).normalized()
		if absf((center - a).cross(along)) < radius - Placement.POINT_EPSILON:
			return false
	return true


## The space an edge part takes up: a box on the covered edge stretch, its depth deep, outward.
static func footprint(mount_frame: Dictionary) -> PackedVector2Array:
	var out: Vector2 = mount_frame["normal"] * float(mount_frame["depth"])
	return PackedVector2Array([mount_frame["a"], mount_frame["b"], mount_frame["b"] + out, mount_frame["a"] + out])


## The thruster's drawn outline: a nozzle that narrows away from the hull.
static func nozzle(mount_frame: Dictionary) -> PackedVector2Array:
	var box := footprint(mount_frame)
	var inset: Vector2 = (box[1] - box[0]) * 0.15
	return PackedVector2Array([box[0], box[1], box[2] - inset, box[3] + inset])


## A part's outline on the ship, for picking and highlighting it: a thruster's nozzle, an edge
## gun's footprint, a turret's base circle. Empty if the reference is broken.
static func outline(placement: Placement, bp: Blueprint, mount: Dictionary) -> PackedVector2Array:
	if is_face(mount):
		var at := face_frame(placement, bp, mount)
		return circle(at["center"], at["radius"]) if not at.is_empty() else PackedVector2Array()
	var mount_frame := frame(placement, bp, mount)
	if mount_frame.is_empty():
		return PackedVector2Array()
	return nozzle(mount_frame) if is_thruster(mount) else footprint(mount_frame)


static func circle(center: Vector2, radius: float, sides := 16) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in sides:
		out.append(center + Vector2.from_angle(TAU * i / sides) * radius)
	return out


## Every edge part's footprint on the ship, tagged with its host tile, for overlap checks.
## Turrets sit on top of their tile and take no space beside it.
static func footprints(placement: Placement, bp: Blueprint) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in bp.mounts.size():
		var mount_frame := frame(placement, bp, bp.mounts[i])
		if not mount_frame.is_empty():
			out.append({"mount": i, "tile": int(bp.mounts[i]["tile"]), "polygon": footprint(mount_frame)})
	return out


## Every free place a thruster of `size_code` could go: [{"tile", "edge", "port"}].
static func thruster_slots(placement: Placement, bp: Blueprint, size_code: StringName) -> Array[Dictionary]:
	return edge_slots(placement, bp, {"part": ThrusterLib.PART_PREFIX, "size": String(size_code)})


## Every free place for `weapon_id` on a `mount_type` mount: [{"tile", "edge", "port"}] for an
## edge mount, [{"tile", "face": true}] for a turret.
static func weapon_slots(placement: Placement, bp: Blueprint, weapon_id: StringName, mount_type: StringName) -> Array[Dictionary]:
	var part := {"part": WeaponLib.part_id(weapon_id), "mount": String(mount_type)}
	if placement.weapons == null or not placement.weapons.allows(weapon_id, mount_type):
		return [] as Array[Dictionary]
	if not placement.weapons.mount_type(mount_type)["face"]:
		var slots := edge_slots(placement, bp, part)
		if placement.weapons.weapon(weapon_id)["rear_only"]:
			slots = slots.filter(func(s: Dictionary) -> bool: return _faces_rear(placement, bp, s))
		return slots
	var out: Array[Dictionary] = []
	for tile in bp.tiles:
		var def := placement.tiles.tile(tile.type)
		if def == null or not def.has_mounts:
			continue
		var slot := {"tile": tile.id, "face": true}
		if not face_frame(placement, bp, moved_to(part, slot)).is_empty() and _face_free(bp, tile.id, -1):
			out.append(slot)
	return out


## Every free edge place for a part shaped like `part` (its part id and size or mount type): on
## a hardpoint's attachable edge, its ports not shared with another tile, and its footprint
## hitting no tile or other part.
static func edge_slots(placement: Placement, bp: Blueprint, part: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var count := span(placement, part)
	if count < 1:
		return out
	var free := {}
	for port in placement.free_ports(bp):
		free[port] = true
	var parts := footprints(placement, bp)
	for tile in bp.tiles:
		var def := placement.tiles.tile(tile.type)
		if def == null or not def.has_mounts:
			continue
		for edge in placement.tile_edges(tile):
			if not edge.attachable:
				continue
			for first in edge.ports.size() - count + 1:
				var slot := {"tile": tile.id, "edge": edge.index, "port": first}
				if _fits(placement, bp, moved_to(part, slot), free, parts, -1):
					out.append(slot)
	return out


## Problems with the ship's mounts, in Placement.Problem form (code &"mount", the host tile).
## `free_ports` is Placement.free_ports(bp), which analyze() already has.
static func problems(placement: Placement, bp: Blueprint, free_ports: PackedVector2Array) -> Array[Placement.Problem]:
	var out: Array[Placement.Problem] = []
	if bp.mounts.is_empty():
		return out
	var free := {}
	for port in free_ports:
		free[port] = true
	var parts := footprints(placement, bp)
	for i in bp.mounts.size():
		var mount := bp.mounts[i]
		if is_weapon(mount) and placement.weapons == null:
			continue  # without the gun data there's no size to check
		var host := int(mount.get("tile", -1))
		var ids := PackedInt32Array([host]) if bp.tile_by_id(host) != null else PackedInt32Array()
		var reason := _part_problem(placement, mount)
		if reason.is_empty():
			var tile := bp.tile_by_id(host)
			var def := placement.tiles.tile(tile.type) if tile != null else null
			if def == null or not def.has_mounts:
				reason = "isn't on a hardpoint"
			elif is_face(mount):
				if face_frame(placement, bp, mount).is_empty():
					reason = "doesn't fit its tile"
				elif not _face_free(bp, host, i):
					reason = "shares its tile with another turret"
			elif frame(placement, bp, mount).is_empty():
				reason = "doesn't fit its edge"
			elif not _fits(placement, bp, mount, free, parts, i):
				reason = "is blocked"
			elif _weapon_def(placement, mount).get("rear_only", false) and not _faces_rear(placement, bp, mount):
				reason = "has to face the rear"
		if not reason.is_empty():
			out.append(Placement.Problem.new(&"mount", ids, "the %s on tile %d %s"
					% [str(mount.get("part", "part")).get_slice(".", 1), host, reason]))
	return out


## The mount's mirror image on `twin_id` across y = `axis_y`, or {} if the twin has no place
## that matches.
static func mirrored(placement: Placement, bp: Blueprint, mount: Dictionary, twin_id: int, axis_y: float) -> Dictionary:
	if is_face(mount):
		return moved_to(mount, {"tile": twin_id, "face": true}) if bp.tile_by_id(twin_id) != null else {}
	var mount_frame := frame(placement, bp, mount)
	var twin := bp.tile_by_id(twin_id)
	if mount_frame.is_empty() or twin == null:
		return {}
	var flip := func(p: Vector2) -> Vector2: return Vector2(p.x, 2.0 * axis_y - p.y)
	var want_normal := Vector2(mount_frame["normal"].x, -mount_frame["normal"].y)
	var want_ports: Array = []
	for p: Vector2 in mount_frame["ports"]:
		want_ports.append(flip.call(p))
	for edge in placement.tile_edges(twin):
		if not edge.attachable or edge.normal.dot(want_normal) < 0.999:
			continue
		for first in edge.ports.size() - want_ports.size() + 1:
			var covered := edge.ports.slice(first, first + want_ports.size())
			if want_ports.all(func(p: Vector2) -> bool: return _contains_near(covered, p)):
				return moved_to(mount, {"tile": twin_id, "edge": edge.index, "port": first})
	return {}


static func _faces_rear(placement: Placement, bp: Blueprint, place: Dictionary) -> bool:
	var tile := bp.tile_by_id(int(place["tile"]))
	return tile != null and placement.tile_edges(tile)[int(place["edge"])].normal.dot(Vector2.LEFT) >= REAR_DOT


static func _host(placement: Placement, bp: Blueprint, mount: Dictionary) -> Blueprint.Tile:
	var tile := bp.tile_by_id(int(mount.get("tile", -1)))
	if tile == null or placement.tiles.tile(tile.type) == null or placement.shapes.shape(tile.shape) == null:
		return null
	return tile


static func _fits(placement: Placement, bp: Blueprint, mount: Dictionary, free: Dictionary,
		parts: Array[Dictionary], skip_mount: int) -> bool:
	var mount_frame := frame(placement, bp, mount)
	if mount_frame.is_empty():
		return false
	for port: Vector2 in mount_frame["ports"]:
		if not free.has(port):
			return false
	var box := footprint(mount_frame)
	var bounds := Placement._bounds(box).grow(-Placement.POINT_EPSILON)
	for tile in bp.tiles:
		var polygon := placement.tile_polygon(tile)
		if bounds.intersects(Placement._bounds(polygon)) and Placement._overlap_area(box, polygon) > Placement.AREA_EPSILON:
			return false
	for part in parts:
		if part["mount"] != skip_mount and Placement._overlap_area(box, part["polygon"]) > Placement.AREA_EPSILON:
			return false
	return true


## No turret but `skip_mount` sits on this tile.
static func _face_free(bp: Blueprint, tile_id: int, skip_mount: int) -> bool:
	for i in bp.mounts.size():
		if i != skip_mount and is_face(bp.mounts[i]) and int(bp.mounts[i].get("tile", -1)) == tile_id:
			return false
	return true


static func _part_problem(placement: Placement, mount: Dictionary) -> String:
	if is_thruster(mount):
		if placement.thrusters != null and placement.thrusters.spec(ThrusterLib.type_of_part(str(mount["part"])),
				StringName(mount.get("size", "")), int(mount.get("level", 0))).is_empty():
			return "has an unknown type, size or level"
		return "can't sit on a face" if is_face(mount) else ""
	if not is_weapon(mount):
		return "isn't a known part"
	if placement.weapons == null:
		return ""
	var weapon_id := WeaponLib.type_of_part(str(mount["part"]))
	var type := StringName(mount.get("mount", ""))
	var rules := placement.weapons.mount_type(type)
	if not placement.weapons.has_weapon(weapon_id):
		return "isn't a known gun"
	if not placement.weapons.allows(weapon_id, type):
		return "can't go on a '%s' mount" % type
	if bool(rules["face"]) != is_face(mount):
		return "needs a hardpoint's %s" % ("face" if rules["face"] else "edge")
	if not (rules["modes"] as Array).has(StringName(mount.get("mode", ""))):
		return "can't be '%s' on a %s" % [mount.get("mode", ""), type]
	return ""


static func _weapon_def(placement: Placement, mount: Dictionary) -> Dictionary:
	if placement.weapons == null:
		return {}
	return placement.weapons.weapon(WeaponLib.type_of_part(str(mount.get("part", ""))))


static func _depth(placement: Placement, mount: Dictionary, length: float) -> float:
	if is_thruster(mount):
		return length * (placement.thrusters.depth_factor if placement.thrusters != null else 0.5)
	return float(_weapon_def(placement, mount).get("length_u", 0.0))


static func _contains_near(points: PackedVector2Array, p: Vector2) -> bool:
	for q in points:
		if q.distance_to(p) < Placement.POINT_EPSILON:
			return true
	return false

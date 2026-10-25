class_name Mounting
extends RefCounted
## Where parts sit on hardpoint edges (PLAN.md 4.3, 5.4): the geometry of a mount, the free
## slots for a new one, and what makes an existing one invalid. Static helpers over a
## Placement, which carries the rules (`placement.thrusters`).
##
## An edge mount is {"tile", "edge", "port", "part", "size", "level"}: it covers
## `edge_u(size) / port_pitch` consecutive ports of that edge, starting at `port` (S 1, M 2, L 4).
## A thruster sits flush on those ports and sticks out along the edge's outward normal, which
## is also its exhaust direction; it pushes the ship the other way.


## A mount's place on its host, in ship units, or {} if the reference is broken:
##   a, b      the covered stretch of the edge (a → b follows the edge's own direction)
##   center    its midpoint: where the thruster's force is applied
##   normal    outward, the exhaust direction
##   length    |b - a|
##   ports     the covered port positions
static func frame(placement: Placement, bp: Blueprint, mount: Dictionary) -> Dictionary:
	var tile := bp.tile_by_id(int(mount.get("tile", -1)))
	if tile == null or placement.tiles.tile(tile.type) == null or placement.shapes.shape(tile.shape) == null:
		return {}
	var edges := placement.tile_edges(tile)
	var edge_index := int(mount.get("edge", -1))
	if edge_index < 0 or edge_index >= edges.size():
		return {}
	var edge := edges[edge_index]
	var count := port_count(placement, StringName(mount.get("size", "")))
	var first := int(mount.get("port", -1))
	if not edge.attachable or count < 1 or first < 0 or first + count > edge.ports.size():
		return {}
	var along := (edge.b - edge.a).normalized()
	var half := placement.shapes.port_pitch * 0.5
	var a := edge.ports[first] - along * half
	var b := edge.ports[first + count - 1] + along * half
	return {
		"a": a, "b": b, "center": (a + b) * 0.5, "normal": edge.normal, "length": a.distance_to(b),
		"ports": edge.ports.slice(first, first + count),
	}


## How many ports a part of this size covers, or 0 for an unknown size.
static func port_count(placement: Placement, size_code: StringName) -> int:
	var edge_u := placement.shapes.edge_u(size_code)
	return roundi(edge_u / placement.shapes.port_pitch) if edge_u > 0.0 else 0


## The space a mounted part takes up: a box on the covered edge stretch, `depth_factor` × its
## length deep, outward.
static func footprint(placement: Placement, mount_frame: Dictionary) -> PackedVector2Array:
	var depth: float = mount_frame["length"] * _depth_factor(placement)
	var out: Vector2 = mount_frame["normal"] * depth
	return PackedVector2Array([mount_frame["a"], mount_frame["b"], mount_frame["b"] + out, mount_frame["a"] + out])


## The thruster's drawn outline: a nozzle that narrows away from the hull.
static func nozzle(placement: Placement, mount_frame: Dictionary) -> PackedVector2Array:
	var box := footprint(placement, mount_frame)
	var inset: Vector2 = (box[1] - box[0]) * 0.15
	return PackedVector2Array([box[0], box[1], box[2] - inset, box[3] + inset])


## Every footprint on the ship, tagged with its host tile, for overlap checks.
static func footprints(placement: Placement, bp: Blueprint) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in bp.mounts.size():
		var mount_frame := frame(placement, bp, bp.mounts[i])
		if not mount_frame.is_empty():
			out.append({"mount": i, "tile": int(bp.mounts[i]["tile"]), "polygon": footprint(placement, mount_frame)})
	return out


## Every free place a thruster of `size_code` could go: [{"tile", "edge", "port"}]. A slot is on
## a hardpoint's attachable edge, its ports aren't shared with another tile, and its footprint
## hits no tile or other part.
static func thruster_slots(placement: Placement, bp: Blueprint, size_code: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var count := port_count(placement, size_code)
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
				var mount := {"tile": tile.id, "edge": edge.index, "port": first, "size": String(size_code)}
				if _fits(placement, bp, mount, free, parts, -1):
					out.append({"tile": tile.id, "edge": edge.index, "port": first})
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
		var host := int(mount.get("tile", -1))
		var ids := PackedInt32Array([host]) if bp.tile_by_id(host) != null else PackedInt32Array()
		var reason := _part_problem(placement, mount)
		if reason.is_empty():
			var tile := bp.tile_by_id(host)
			var def := placement.tiles.tile(tile.type) if tile != null else null
			if def == null or not def.has_mounts:
				reason = "isn't on a hardpoint"
			elif frame(placement, bp, mount).is_empty():
				reason = "doesn't fit its edge"
			elif not _fits(placement, bp, mount, free, parts, i):
				reason = "is blocked"
		if not reason.is_empty():
			out.append(Placement.Problem.new(&"mount", ids, "the %s on tile %d %s"
					% [str(mount.get("part", "part")).get_slice(".", 1), host, reason]))
	return out


## The mount's mirror image on `twin_id` across y = `axis_y`, or {} if the twin has no edge
## stretch that matches.
static func mirrored(placement: Placement, bp: Blueprint, mount: Dictionary, twin_id: int, axis_y: float) -> Dictionary:
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
				var image := mount.duplicate()
				image["tile"] = twin_id
				image["edge"] = edge.index
				image["port"] = first
				return image
	return {}


static func _fits(placement: Placement, bp: Blueprint, mount: Dictionary, free: Dictionary,
		parts: Array[Dictionary], skip_mount: int) -> bool:
	var mount_frame := frame(placement, bp, mount)
	if mount_frame.is_empty():
		return false
	for port: Vector2 in mount_frame["ports"]:
		if not free.has(port):
			return false
	var box := footprint(placement, mount_frame)
	var bounds := Placement._bounds(box).grow(-Placement.POINT_EPSILON)
	for tile in bp.tiles:
		var polygon := placement.tile_polygon(tile)
		if bounds.intersects(Placement._bounds(polygon)) and Placement._overlap_area(box, polygon) > Placement.AREA_EPSILON:
			return false
	for part in parts:
		if part["mount"] != skip_mount and Placement._overlap_area(box, part["polygon"]) > Placement.AREA_EPSILON:
			return false
	return true


static func _part_problem(placement: Placement, mount: Dictionary) -> String:
	var type_id := ThrusterLib.type_of_part(str(mount.get("part", "")))
	if type_id == &"":
		return "isn't a known part"
	if placement.thrusters == null:
		return ""
	if placement.thrusters.spec(type_id, StringName(mount.get("size", "")), int(mount.get("level", 0))).is_empty():
		return "has an unknown type, size or level"
	return ""


static func _depth_factor(placement: Placement) -> float:
	return placement.thrusters.depth_factor if placement.thrusters != null else 0.5


static func _contains_near(points: PackedVector2Array, p: Vector2) -> bool:
	for q in points:
		if q.distance_to(p) < Placement.POINT_EPSILON:
			return true
	return false

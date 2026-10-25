class_name Placement
extends RefCounted
## Where tiles may snap, and whether a blueprint is buildable (PLAN.md 4.1, Phase 1.4).
##
## Two tiles are CONNECTED when they share at least one port: a port midpoint at the same
## spot on two edges facing opposite ways. That's the only kind of contact that counts.
## Touching at a corner, or along an edge that's off the port grid, doesn't connect.

const AREA_EPSILON := 0.0001
const POINT_EPSILON := 0.001

## One place a new tile can go.
class Snap:
	var pos: Vector2
	var rot: int
	## The existing tile and edge it sits against.
	var target_tile: int
	var target_edge: int
	## Which edge of the new tile touches it.
	var edge: int


## One reason a blueprint can't be built.
class Problem:
	var code: StringName
	var tile_ids: PackedInt32Array
	var message: String

	func _init(problem_code: StringName, ids: PackedInt32Array, text: String) -> void:
		code = problem_code
		tile_ids = ids
		message = text


var shapes: ShapeLib
var tiles: TileLib
var max_tiles: int
var area_u: float


static func create(shape_lib: ShapeLib, tile_lib: TileLib, tiles_table: Dictionary) -> Placement:
	var placement := Placement.new()
	placement.shapes = shape_lib
	placement.tiles = tile_lib
	var build: Dictionary = tiles_table.get("build", {})
	placement.max_tiles = int(build.get("max_tiles", 150))
	placement.area_u = float(build.get("area_u", 16.0))
	return placement


func tile_polygon(tile: Blueprint.Tile) -> PackedVector2Array:
	return shapes.polygon(tile.shape, tile.size, tile.rot, tile.pos)


func tile_edges(tile: Blueprint.Tile) -> Array[Shape.Edge]:
	return shapes.edges(tile.shape, tile.size, tile.rot, tile.pos)


## Every distinct place a tile of this type, shape and size can snap onto `bp` without
## overlapping anything. With `near` set, only edges with a port within `radius` of it are
## tried, which is what keeps the hangar fast on a big ship.
func candidate_snaps(bp: Blueprint, type: StringName, shape_id: StringName, size: StringName,
		near: Variant = null, radius: float = 1.5) -> Array[Snap]:
	var out: Array[Snap] = []
	var tile_def := tiles.tile(type)
	if tile_def == null or shapes.shape(shape_id) == null or shapes.edge_u(size) <= 0.0:
		return out
	if tile_def.unique and _count_type(bp, type) > 0:
		return out
	if bp.tiles.is_empty():
		# The first tile is the core, at the origin.
		if type == tiles.core_id():
			var first := Snap.new()
			first.target_tile = -1
			first.target_edge = -1
			first.edge = -1
			out.append(first)
		return out

	var steps := shapes.rotation_steps()
	var pitch := shapes.port_pitch
	var new_edges_at_zero := shapes.edges(shape_id, size, 0)
	var placed := _placed_polygons(bp)
	var seen := {}

	for target in bp.tiles:
		for target_edge in tile_edges(target):
			if not target_edge.attachable or target_edge.ports.is_empty():
				continue
			if near != null and not _has_port_near(target_edge, near, radius):
				continue
			var target_dir := (target_edge.b - target_edge.a).normalized()
			for new_edge0 in new_edges_at_zero:
				if not new_edge0.attachable:
					continue
				# Turn the new tile so this edge runs opposite the target edge.
				var turn := rad_to_deg((-target_dir).angle() - (new_edge0.b - new_edge0.a).angle())
				var rot := posmod(roundi(turn / shapes.rotation_step_deg), steps)
				var new_edge := shapes.edges(shape_id, size, rot)[new_edge0.index]
				var count_new := new_edge.ports.size()
				var count_old := target_edge.ports.size()
				# Port k of the new edge meets port m of the target where m + k == shift.
				for shift in count_old + count_new - 1:
					var m := mini(shift, count_old - 1)
					var k := shift - m
					var pos := target_edge.ports[m] - new_edge.ports[k]
					var polygon := shapes.polygon(shape_id, size, rot, pos)
					var key := _polygon_key(polygon)
					if seen.has(key) or _overlaps_any(polygon, placed):
						continue
					seen[key] = true
					var snap := Snap.new()
					snap.pos = pos
					snap.rot = rot
					snap.target_tile = target.id
					snap.target_edge = target_edge.index
					snap.edge = new_edge0.index
					out.append(snap)
	return out


## Tile id -> the ids of every tile it shares a port with.
func neighbours(bp: Blueprint) -> Dictionary:
	var index := _PortIndex.new()
	var out := {}
	for tile in bp.tiles:
		out[tile.id] = PackedInt32Array()
		for edge in tile_edges(tile):
			for port in edge.ports:
				index.add(port, edge.normal, tile.id)
	for pair in index.facing_pairs():
		if not out[pair.x].has(pair.y):
			out[pair.x].append(pair.y)
			out[pair.y].append(pair.x)
	return out


## Ids of every tile reachable from the core through shared ports (empty with no core).
func connected_to_core(bp: Blueprint) -> Dictionary:
	var core := _core_tile(bp)
	var reached := {}
	if core == null:
		return reached
	var links := neighbours(bp)
	var queue: Array[int] = [core.id]
	reached[core.id] = true
	while not queue.is_empty():
		for next: int in links[queue.pop_back()]:
			if not reached.has(next):
				reached[next] = true
				queue.append(next)
	return reached


func validate(bp: Blueprint) -> Array[Problem]:
	var problems: Array[Problem] = []
	var known: Array[Blueprint.Tile] = []
	for tile in bp.tiles:
		if tiles.tile(tile.type) == null:
			problems.append(Problem.new(&"unknown_type", [tile.id], "tile %d: unknown type '%s'" % [tile.id, tile.type]))
		elif shapes.shape(tile.shape) == null:
			problems.append(Problem.new(&"unknown_shape", [tile.id], "tile %d: unknown shape '%s'" % [tile.id, tile.shape]))
		elif shapes.edge_u(tile.size) <= 0.0:
			problems.append(Problem.new(&"unknown_size", [tile.id], "tile %d: unknown size '%s'" % [tile.id, tile.size]))
		else:
			known.append(tile)
	if not problems.is_empty():
		return problems

	var cores := known.filter(func(t: Blueprint.Tile) -> bool: return t.type == tiles.core_id())
	if cores.is_empty():
		problems.append(Problem.new(&"no_core", [], "the ship has no core"))
	elif cores.size() > 1:
		var ids := PackedInt32Array(cores.map(func(t: Blueprint.Tile) -> int: return t.id))
		problems.append(Problem.new(&"multiple_cores", ids, "the ship has %d cores; it needs exactly one" % cores.size()))

	if bp.tiles.size() > max_tiles:
		problems.append(Problem.new(&"over_cap", [], "%d tiles; the limit is %d" % [bp.tiles.size(), max_tiles]))

	var placed := _placed_polygons(bp)
	var bounds := Rect2()
	for i in placed.size():
		bounds = placed[i].bounds if i == 0 else bounds.merge(placed[i].bounds)
		for j in range(i + 1, placed.size()):
			if placed[i].bounds.intersects(placed[j].bounds) \
					and _overlap_area(placed[i].polygon, placed[j].polygon) > AREA_EPSILON:
				problems.append(Problem.new(&"overlap", [placed[i].id, placed[j].id],
						"tiles %d and %d overlap" % [placed[i].id, placed[j].id]))
	if bounds.size.x > area_u + POINT_EPSILON or bounds.size.y > area_u + POINT_EPSILON:
		problems.append(Problem.new(&"over_cap", [], "the ship is %.2f x %.2f U; the limit is %d x %d"
				% [bounds.size.x, bounds.size.y, area_u, area_u]))

	if cores.size() == 1:
		var reached := connected_to_core(bp)
		var loose := PackedInt32Array()
		for tile in bp.tiles:
			if not reached.has(tile.id):
				loose.append(tile.id)
		if not loose.is_empty():
			problems.append(Problem.new(&"disconnected", loose,
					"%d tile(s) aren't connected to the core" % loose.size()))
	return problems


func _count_type(bp: Blueprint, type: StringName) -> int:
	return bp.tiles.filter(func(t: Blueprint.Tile) -> bool: return t.type == type).size()


func _core_tile(bp: Blueprint) -> Blueprint.Tile:
	for tile in bp.tiles:
		if tile.type == tiles.core_id():
			return tile
	return null


func _has_port_near(edge: Shape.Edge, point: Vector2, radius: float) -> bool:
	for port in edge.ports:
		if port.distance_to(point) <= radius:
			return true
	return false


class _Placed:
	var id: int
	var polygon: PackedVector2Array
	var bounds: Rect2


func _placed_polygons(bp: Blueprint) -> Array[_Placed]:
	var out: Array[_Placed] = []
	for tile in bp.tiles:
		var placed := _Placed.new()
		placed.id = tile.id
		placed.polygon = tile_polygon(tile)
		placed.bounds = _bounds(placed.polygon)
		out.append(placed)
	return out


func _overlaps_any(polygon: PackedVector2Array, placed: Array[_Placed]) -> bool:
	var bounds := _bounds(polygon).grow(-POINT_EPSILON)
	for other in placed:
		if bounds.intersects(other.bounds) and _overlap_area(polygon, other.polygon) > AREA_EPSILON:
			return true
	return false


static func _overlap_area(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var area := 0.0
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(a, b):
		area += absf(_signed_area(piece))
	return area


static func _signed_area(polygon: PackedVector2Array) -> float:
	var sum := 0.0
	for i in polygon.size():
		var p := polygon[i]
		var q := polygon[(i + 1) % polygon.size()]
		sum += p.x * q.y - q.x * p.y
	return sum * 0.5


static func _bounds(polygon: PackedVector2Array) -> Rect2:
	var rect := Rect2(polygon[0], Vector2.ZERO)
	for p in polygon:
		rect = rect.expand(p)
	return rect


## Identifies a footprint regardless of which rotation produced it (a hex turned 60° is the
## same hex), so the builder doesn't offer the same placement twice.
static func _polygon_key(polygon: PackedVector2Array) -> String:
	var parts: PackedStringArray = []
	for p in polygon:
		parts.append("%d,%d" % [roundi(p.x * 1000.0), roundi(p.y * 1000.0)])
	parts.sort()
	return ";".join(parts)


## Finds ports that sit on top of each other, facing opposite ways. A spatial hash with a
## neighbourhood search, so floating-point error near a cell boundary can't split a pair.
class _PortIndex:
	const CELL := 0.1

	var _cells: Dictionary = {}
	var _entries: Array = []

	func add(point: Vector2, normal: Vector2, tile_id: int) -> void:
		var cell := Vector2i(floori(point.x / CELL), floori(point.y / CELL))
		if not _cells.has(cell):
			_cells[cell] = []
		_cells[cell].append(_entries.size())
		_entries.append([point, normal, tile_id])

	## Unordered (tile, tile) pairs that share a port.
	func facing_pairs() -> Array[Vector2i]:
		var out: Array[Vector2i] = []
		for i in _entries.size():
			var point: Vector2 = _entries[i][0]
			var cell := Vector2i(floori(point.x / CELL), floori(point.y / CELL))
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					for j: int in _cells.get(cell + Vector2i(dx, dy), []):
						if j <= i or _entries[j][2] == _entries[i][2]:
							continue
						if (_entries[j][0] as Vector2).distance_to(point) < POINT_EPSILON \
								and (_entries[j][1] as Vector2).dot(_entries[i][1]) < -0.999:
							out.append(Vector2i(_entries[i][2], _entries[j][2]))
		return out

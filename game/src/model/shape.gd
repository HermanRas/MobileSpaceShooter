class_name Shape
extends RefCounted
## One tile shape at edge length 1, and its geometry at any size and rotation (PLAN.md 4.1).
##
## Coordinates are in U, y down (Godot's 2D convention). Vertices wind around the shape's
## origin, and every edge's outward normal is computed rather than assumed from the winding.

## One edge of a placed shape. `ports` are the midpoints of each port-pitch segment, in order
## from `a` to `b`; an edge that can't attach has none.
class Edge:
	var index: int
	var a: Vector2
	var b: Vector2
	var normal: Vector2
	var attachable: bool
	var ports: PackedVector2Array

	func length() -> float:
		return a.distance_to(b)

	func midpoint() -> Vector2:
		return (a + b) * 0.5


const LENGTH_EPSILON := 0.0001

var id: StringName
## Vertices at edge length 1, rotation 0.
var unit_vertices: PackedVector2Array
## Indices of edges (edge i runs from vertex i to vertex i+1) that have no ports.
var dead_edges: PackedInt32Array


func edge_count() -> int:
	return unit_vertices.size()


func is_attachable(edge_index: int) -> bool:
	return not dead_edges.has(edge_index)


## The shape's outline at `edge_u` (the size's edge length in U), turned `rot_steps` steps
## of `step_deg` degrees clockwise, then moved to `offset`.
func polygon(edge_u: float, rot_steps: int, step_deg: float, offset := Vector2.ZERO) -> PackedVector2Array:
	var angle := deg_to_rad(step_deg * rot_steps)
	var out := PackedVector2Array()
	for v in unit_vertices:
		out.append((v * edge_u).rotated(angle) + offset)
	return out


func edges(edge_u: float, rot_steps: int, step_deg: float, pitch: float,
		offset := Vector2.ZERO) -> Array[Edge]:
	var points := polygon(edge_u, rot_steps, step_deg, offset)
	var center := Vector2.ZERO
	for p in points:
		center += p
	center /= points.size()

	var out: Array[Edge] = []
	for i in points.size():
		var edge := Edge.new()
		edge.index = i
		edge.a = points[i]
		edge.b = points[(i + 1) % points.size()]
		var along := (edge.b - edge.a).normalized()
		edge.normal = Vector2(along.y, -along.x)
		if edge.normal.dot(edge.midpoint() - center) < 0.0:
			edge.normal = -edge.normal
		edge.attachable = is_attachable(i)
		if edge.attachable:
			var count := roundi(edge.length() / pitch)
			for k in count:
				edge.ports.append(edge.a + along * pitch * (k + 0.5))
		out.append(edge)
	return out


## Builds a shape from its `shapes.json` entry. Returns null and fills `errors` on a bad entry.
static func from_def(shape_id: StringName, def: Dictionary, errors: PackedStringArray) -> Shape:
	var shape := Shape.new()
	shape.id = shape_id
	match def.get("kind", ""):
		"box":
			var w: float = def.get("w", 0.0)
			var h: float = def.get("h", 0.0)
			shape.unit_vertices = PackedVector2Array([
				Vector2(-w, -h) * 0.5, Vector2(w, -h) * 0.5, Vector2(w, h) * 0.5, Vector2(-w, h) * 0.5])
		"regular":
			var sides: int = def.get("sides", 0)
			if sides < 3:
				errors.append("%s: a regular shape needs at least 3 sides" % shape_id)
				return null
			# Circumradius for side 1, with edge 0 lying flat along the bottom (+y).
			var radius := 0.5 / sin(PI / sides)
			var start := PI * 0.5 - PI / sides
			for k in sides:
				var theta := start + TAU * k / sides
				shape.unit_vertices.append(Vector2(cos(theta), sin(theta)) * radius)
		"polygon":
			for v: Array in def.get("vertices", []):
				shape.unit_vertices.append(Vector2(v[0], v[1]))
		_:
			errors.append("%s: unknown kind '%s'" % [shape_id, def.get("kind", "")])
			return null
	if shape.unit_vertices.size() < 3:
		errors.append("%s: fewer than 3 vertices" % shape_id)
		return null
	for e: float in def.get("dead_edges", []):
		shape.dead_edges.append(int(e))
	return shape

class_name Arena
extends RefCounted
## A square play area (PLAN.md Phase 3.5): how close a point is to its edge, and the push that
## steers a ship back once it's past it. In U, centred on the origin.

var half_size_u := 120.0
var warn_margin_u := 25.0
## U/s² of push per U past the edge.
var push_back := 3.0


static func from_table(table: Dictionary) -> Arena:
	var arena := Arena.new()
	arena.half_size_u = float(table.get("half_size_u", arena.half_size_u))
	arena.warn_margin_u = float(table.get("warn_margin_u", arena.warn_margin_u))
	arena.push_back = float(table.get("push_back", arena.push_back))
	return arena


## 0 well inside, rising to 1 at the edge (and staying 1 beyond it).
func warning(point_u: Vector2) -> float:
	var to_edge := half_size_u - maxf(absf(point_u.x), absf(point_u.y))
	if warn_margin_u <= 0.0:
		return 1.0 if to_edge <= 0.0 else 0.0
	return clampf(1.0 - to_edge / warn_margin_u, 0.0, 1.0)


## The acceleration (U/s²) pulling a point past the edge back in; zero inside.
func push(point_u: Vector2) -> Vector2:
	var out := Vector2.ZERO
	for axis in 2:
		var depth := absf(point_u[axis]) - half_size_u
		if depth > 0.0:
			out[axis] = -signf(point_u[axis]) * depth * push_back
	return out


func contains(point_u: Vector2) -> bool:
	return absf(point_u.x) <= half_size_u and absf(point_u.y) <= half_size_u

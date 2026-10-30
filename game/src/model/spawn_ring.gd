class_name SpawnRing
extends RefCounted
## Where a fight's ships appear (PLAN.md 5.5): just off screen around the player, in groups of
## up to `ships_per_side` coming from different sides, lined up abreast, clear of each other and
## inside the arena, each facing the player. In U. Tuning is `flight.json` `spawner`.

## How far beyond the view's corner the nearest ship's edge is.
var margin_u := 6.0
var ships_per_side := 3
## Space between neighbours in a group.
var gap_u := 1.5
## Keep spawns this far inside the arena's edge.
var inside_u := 10.0
## How finely a side turns to find room inside the arena, and how many tries it gets.
var turn_step_deg := 20.0
var turns := 18


static func from_table(table: Dictionary) -> SpawnRing:
	var ring := SpawnRing.new()
	ring.margin_u = float(table.get("ring_margin_u", ring.margin_u))
	ring.ships_per_side = maxi(int(table.get("ships_per_side", ring.ships_per_side)), 1)
	ring.gap_u = float(table.get("ring_gap_u", ring.gap_u))
	ring.inside_u = float(table.get("arena_inside_u", ring.inside_u))
	return ring


## A spot for each ship of `sizes` (each ship's longest side, U) round `center`, outside a view
## reaching `view_half` from it: [{"pos": Vector2, "heading": radians}], in `sizes` order. The
## sides' directions come from `rng`.
func place(center: Vector2, view_half: Vector2, sizes: Array[float], arena: Arena, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.resize(sizes.size())
	if sizes.is_empty():
		return out
	var sides := ceili(float(sizes.size()) / ships_per_side)
	var start := rng.randf() * TAU
	var reach := view_half.length() + margin_u
	for side in sides:
		var members: Array[int] = []
		for i in range(side, sizes.size(), sides):
			members.append(i)
		var spots := _side(members, sizes, center, reach, start + TAU * side / sides, arena)
		for k in members.size():
			out[members[k]] = {"pos": spots[k], "heading": (center - spots[k]).angle()}
	return out


## The spots of one side's `members`, turned from `angle` until they all fit inside the arena
## (or clamped into it if no turn fits).
func _side(members: Array[int], sizes: Array[float], center: Vector2, reach: float, angle: float, arena: Arena) -> PackedVector2Array:
	var spots := PackedVector2Array()
	for attempt in turns:
		var turn := deg_to_rad(turn_step_deg) * ceili(attempt / 2.0) * (1.0 if attempt % 2 == 1 else -1.0)
		spots = _abreast(members, sizes, center, reach, angle + turn)
		if Array(spots).all(func(p: Vector2) -> bool: return _fits(p, arena)):
			return spots
	spots = _abreast(members, sizes, center, reach, angle)
	var limit := arena.half_size_u - inside_u
	for k in spots.size():
		spots[k] = spots[k].clamp(Vector2(-limit, -limit), Vector2(limit, limit))
	return spots


## `members` side by side across the direction `angle`, the first in the middle and the rest
## alternately right and left, each with its near edge `reach` from `center`.
func _abreast(members: Array[int], sizes: Array[float], center: Vector2, reach: float, angle: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var out_dir := Vector2.from_angle(angle)
	var across := out_dir.orthogonal()
	var right := 0.0
	var left := 0.0
	for k in members.size():
		var size := sizes[members[k]]
		var offset := 0.0
		if k == 0:
			right = size * 0.5
			left = -size * 0.5
		elif k % 2 == 1:
			offset = right + gap_u + size * 0.5
			right = offset + size * 0.5
		else:
			offset = left - gap_u - size * 0.5
			left = offset - size * 0.5
		out.append(center + out_dir * (reach + size * 0.5) + across * offset)
	return out


func _fits(point: Vector2, arena: Arena) -> bool:
	var limit := arena.half_size_u - inside_u
	return absf(point.x) <= limit and absf(point.y) <= limit


## Whether any part of a ship at `pos` reaching `reach` from it is inside the view: `view_half`
## round `center` (8.7: an enemy holds its fire until it has been in view).
static func in_view(center: Vector2, view_half: Vector2, pos: Vector2, reach: float) -> bool:
	var off := (pos - center).abs()
	return off.x <= view_half.x + reach and off.y <= view_half.y + reach

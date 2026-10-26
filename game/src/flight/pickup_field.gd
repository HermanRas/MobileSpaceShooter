class_name PickupField
extends Node2D
## Loot floating in space (PLAN.md 5.4): what a kill drops scatters from the wreck, drifts to a
## stop, and flies to the player's ship once it's within the magnet radius; touching the ship
## collects it. All pickups live in arrays and draw in one `_draw`, like the shot pool.
##
## A pickup is a piece of loot: {resource: amount} (Economy.loot_pieces), or a part from
## Economy.part_drop ({"gun", "mount", "xp"} or {"thruster"}). Placeholder shapes until art
## lands: Hull a scrap of plate (pentagon, so it isn't taken for a tile of debris), Alloy a steel hexagon, Crystal a cyan shard, Tech a bundle of
## wires, GC a gold coin, a part a crate.

signal collected(piece: Dictionary)

const PX := ShipMesh.PX_PER_U
const RADIUS_U := 0.35

## Tuning (flight.json pickups): U, U/s, seconds.
var magnet_u := 8.0
var collect_u := 0.6
var pull_u_s := 14.0
var pull_accel_u_s2 := 60.0
var scatter_u_s := 4.0
var drift_damp := 1.5
var life_s := 45.0
var blink_s := 5.0

## The ship pickups fly to, and how far its hull reaches from its centre, in U.
var target: ShipBody
var reach_u := 1.0

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _age := PackedFloat32Array()
var _spin := PackedFloat32Array()
var _piece: Array[Dictionary] = []


func configure(table: Dictionary) -> void:
	for key in ["magnet_u", "collect_u", "pull_u_s", "pull_accel_u_s2", "scatter_u_s", "drift_damp", "life_s", "blink_s"]:
		if table.has(key):
			set(key, float(table[key]))


func count() -> int:
	return _piece.size()


## Scatters `pieces` from `at` (world px), each flung at up to scatter_u_s on top of `velocity`.
func drop(at: Vector2, velocity: Vector2, pieces: Array[Dictionary]) -> void:
	for piece in pieces:
		var fling := Vector2.from_angle(randf() * TAU) * randf_range(0.4, 1.0) * scatter_u_s * PX
		_pos.append(at + fling * 0.1)
		_vel.append(velocity + fling)
		_age.append(0.0)
		_spin.append(randf() * TAU)
		_piece.append(piece)


func clear() -> void:
	_pos.clear()
	_vel.clear()
	_age.clear()
	_spin.clear()
	_piece.clear()


func _physics_process(delta: float) -> void:
	var live := is_instance_valid(target) and not target.is_wreck()
	for i in range(_piece.size() - 1, -1, -1):
		_age[i] += delta
		if _age[i] > life_s:
			_remove(i)
			continue
		_pos[i] += _vel[i] * delta
		_spin[i] += delta * 1.5
		var pulled := false
		if live:
			var to_ship := target.global_position - _pos[i]
			var distance_u := to_ship.length() / PX
			if distance_u <= reach_u + collect_u:
				var piece := _piece[i]
				_remove(i)
				collected.emit(piece)
				continue
			if distance_u <= reach_u + magnet_u:
				var wanted := to_ship.normalized() * (pull_u_s * PX + target.linear_velocity.length())
				_vel[i] = _vel[i].move_toward(wanted, pull_accel_u_s2 * PX * delta)
				pulled = true
		if not pulled:
			_vel[i] *= maxf(1.0 - drift_damp * delta, 0.0)
	queue_redraw()


func _remove(i: int) -> void:
	var last := _piece.size() - 1
	_pos[i] = _pos[last]
	_vel[i] = _vel[last]
	_age[i] = _age[last]
	_spin[i] = _spin[last]
	_piece[i] = _piece[last]
	_pos.resize(last)
	_vel.resize(last)
	_age.resize(last)
	_spin.resize(last)
	_piece.resize(last)


func _draw() -> void:
	var r := RADIUS_U * PX
	for i in _piece.size():
		var left := life_s - _age[i]
		if left < blink_s and fmod(left, 0.4) < 0.15:
			continue  # about to vanish: it blinks
		var at := _pos[i]
		var piece := _piece[i]
		var kind: StringName = &"part" if piece.has("gun") or piece.has("thruster") else piece.keys()[0]
		draw_circle(at, r * 1.7, Color(_colour(kind), 0.18))
		match kind:
			&"hull":
				_draw_shape(at, 5, r, _spin[i], Color(0.78, 0.8, 0.84))
			&"alloy":
				_draw_shape(at, 6, r, _spin[i], Color(0.55, 0.68, 0.85))
			&"crystal":
				var shard := PackedVector2Array([Vector2(0, -1.3), Vector2(0.6, 0), Vector2(0, 1.3), Vector2(-0.6, 0)])
				_draw_points(at, shard, r, _spin[i], Color(0.45, 0.95, 1.0))
			&"tech":
				_draw_wires(at, r, _spin[i])
			&"gc":
				draw_circle(at, r, Color(1.0, 0.8, 0.25))
				draw_arc(at, r * 0.65, 0.0, TAU, 16, Color(0.75, 0.55, 0.1), 2.0, true)
			_:
				_draw_shape(at, 4, r * 1.3, PI * 0.25, Color(0.95, 0.55, 0.2) if piece.has("gun") else Color(0.3, 0.8, 0.75))
				draw_line(at - Vector2(r * 0.6, 0), at + Vector2(r * 0.6, 0), Color.WHITE, 2.0)
				draw_line(at - Vector2(0, r * 0.6), at + Vector2(0, r * 0.6), Color.WHITE, 2.0)


func _colour(kind: StringName) -> Color:
	match kind:
		&"alloy": return Color(0.55, 0.68, 0.85)
		&"crystal": return Color(0.45, 0.95, 1.0)
		&"tech": return Color(0.5, 1.0, 0.4)
		&"gc": return Color(1.0, 0.8, 0.25)
		&"part": return Color(1.0, 0.6, 0.25)
	return Color(0.8, 0.8, 0.85)


func _draw_shape(at: Vector2, sides: int, radius: float, turn: float, colour: Color) -> void:
	var points := PackedVector2Array()
	for k in sides:
		points.append(Vector2.from_angle(turn + TAU * k / sides))
	_draw_points(at, points, radius, 0.0, colour)


func _draw_points(at: Vector2, unit: PackedVector2Array, radius: float, turn: float, colour: Color) -> void:
	var points := PackedVector2Array()
	for p in unit:
		points.append(at + p.rotated(turn) * radius)
	draw_colored_polygon(points, colour)
	points.append(points[0])
	draw_polyline(points, colour.darkened(0.45), 2.0, true)


## Tech: three wires, red, yellow and green, bound in the middle (PLAN.md 4.6).
func _draw_wires(at: Vector2, radius: float, turn: float) -> void:
	var colours := [Color(1.0, 0.35, 0.3), Color(1.0, 0.85, 0.3), Color(0.45, 1.0, 0.4)]
	for k in 3:
		var points := PackedVector2Array()
		for step in 7:
			var t := step / 6.0 * 2.0 - 1.0
			points.append(at + Vector2(t * radius * 1.3, (k - 1) * radius * 0.35 + sin(t * 3.0 + k) * radius * 0.25).rotated(turn))
		draw_polyline(points, colours[k], 2.5, true)
	draw_line(at + Vector2(0, -radius * 0.6).rotated(turn), at + Vector2(0, radius * 0.6).rotated(turn),
			Color(0.2, 0.2, 0.22), 5.0)

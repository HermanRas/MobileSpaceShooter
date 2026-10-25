class_name ShipView
extends Node2D
## Draws the hangar: the grid and build area, the ship mesh, the ghost tile or thruster, and
## overlays (selection, tiles with problems, free ports or thruster slots while carrying, and
## the thrust rose at the centre of mass).
##
## Everything is in world pixels (ShipMesh.PX_PER_U per U). Overlay line widths are divided by
## the camera zoom so they stay the same thickness on screen at any zoom.

const PX := ShipMesh.PX_PER_U
const GRID_MINOR := Color(1, 1, 1, 0.04)
const GRID_MAJOR := Color(1, 1, 1, 0.09)
const BUILD_AREA := Color(0.4, 0.75, 1.0, 0.35)
const SELECTED := Color(1.0, 0.85, 0.2)
const PROBLEM := Color(1.0, 0.2, 0.2)
const FREE_PORT := Color(1, 1, 1, 0.7)
const GHOST_OK := Color(0.3, 1.0, 0.45)
const GHOST_BAD := Color(1.0, 0.3, 0.3)
const ROSE := Color(1.0, 0.75, 0.3, 0.75)
const TURN := Color(0.6, 0.85, 1.0, 0.75)
## The rose's longest spoke, in U.
const ROSE_REACH_U := 1.6

var placement: Placement
var area_u: float = 16.0

var _ship := MeshInstance2D.new()
var _ghost := MeshInstance2D.new()
var _overlay := Node2D.new()
var _ghost_material: ShaderMaterial

var _blueprint: Blueprint
var _selected: PackedInt32Array = []
var _problem_ids := {}
var _ghost_polygon := PackedVector2Array()
var _ghost_ok := false
var _show_ports := false
var _free_ports := PackedVector2Array()
var _pulse := 0.0
var _selected_mount := -1
var _slot_marks := PackedVector2Array()
var _envelope: ThrustEnvelope
var _center_of_mass := Vector2.ZERO


func _ready() -> void:
	_ship.material = ShipMesh.make_material()
	_ghost_material = ShipMesh.make_material()
	_ghost_material.set_shader_parameter(&"opacity", 0.7)
	_ghost.material = _ghost_material
	add_child(_ship)
	add_child(_ghost)
	add_child(_overlay)
	_overlay.draw.connect(_draw_overlay)


func show_blueprint(bp: Blueprint, analysis: Placement.Analysis) -> void:
	_blueprint = bp
	_ship.mesh = ShipMesh.build(bp.tiles, placement, bp)
	_free_ports = analysis.free_ports
	_problem_ids.clear()
	for problem in analysis.problems:
		for tile_id in problem.tile_ids:
			_problem_ids[tile_id] = true
	_overlay.queue_redraw()


func set_selected(tile_ids: PackedInt32Array) -> void:
	_selected = tile_ids
	_overlay.queue_redraw()


func set_selected_mount(index: int) -> void:
	_selected_mount = index
	_overlay.queue_redraw()


## The thrust rose and turn arcs, drawn at the centre of mass. Null hides them.
func set_envelope(envelope: ThrustEnvelope, center_of_mass: Vector2) -> void:
	_envelope = envelope
	_center_of_mass = center_of_mass
	_overlay.queue_redraw()


## A carried thruster: its nozzle outline (in U; empty hides it), whether it has a slot, and
## the centres of every free slot to show while carrying.
func set_thruster_ghost(nozzle: PackedVector2Array, ok: bool, slot_centers: PackedVector2Array) -> void:
	_ghost.mesh = null
	_ghost_polygon = nozzle
	_ghost_ok = ok
	_slot_marks = slot_centers
	_show_ports = false
	_overlay.queue_redraw()


## Shows a ghost tile, green when it has a valid snap, red when it doesn't. Pass null to hide.
func set_ghost(tile: Blueprint.Tile, ok: bool) -> void:
	_show_ports = tile != null
	_slot_marks = PackedVector2Array()
	if tile == null:
		_ghost.mesh = null
		_ghost_polygon = PackedVector2Array()
	else:
		_ghost.mesh = ShipMesh.build([tile], placement)
		_ghost_polygon = placement.tile_polygon(tile)
		_ghost_ok = ok
		var tint := GHOST_OK if ok else GHOST_BAD
		_ghost_material.set_shader_parameter(&"tint", Color(tint, 0.35))
	_overlay.queue_redraw()


func _process(delta: float) -> void:
	if not _problem_ids.is_empty():
		_pulse += delta
		_overlay.queue_redraw()


func _draw() -> void:
	var half := area_u * 0.5
	var px_width := _px(1.0)
	for i in range(-int(half * 4), int(half * 4) + 1):
		var at := i * 0.25 * PX
		var color := GRID_MAJOR if i % 4 == 0 else GRID_MINOR
		draw_line(Vector2(at, -half * PX), Vector2(at, half * PX), color, px_width)
		draw_line(Vector2(-half * PX, at), Vector2(half * PX, at), color, px_width)
	draw_rect(Rect2(Vector2(-half, -half) * PX, Vector2(area_u, area_u) * PX), BUILD_AREA, false, _px(2.0))


func _draw_overlay() -> void:
	if _blueprint == null:
		return
	var alpha := 0.35 + 0.25 * sin(_pulse * 6.0)
	for tile in _blueprint.tiles:
		var polygon := _to_px(placement.tile_polygon(tile))
		if _problem_ids.has(tile.id):
			_overlay.draw_colored_polygon(polygon, Color(PROBLEM, alpha))
		if _selected.has(tile.id):
			_overlay.draw_polyline(_closed(polygon), SELECTED, _px(3.0), true)
	if _show_ports:
		var radius := _px(3.0)
		for port in _free_ports:
			_overlay.draw_circle(port * PX, radius, FREE_PORT)
	for mark in _slot_marks:
		_overlay.draw_circle(mark * PX, _px(5.0), Color(GHOST_OK, 0.6))
	if not _ghost_polygon.is_empty():
		if _ghost.mesh == null:
			_overlay.draw_colored_polygon(_to_px(_ghost_polygon), Color(GHOST_OK if _ghost_ok else GHOST_BAD, 0.45))
		_overlay.draw_polyline(_closed(_to_px(_ghost_polygon)), GHOST_OK if _ghost_ok else GHOST_BAD, _px(2.0), true)
	if _selected_mount >= 0 and _selected_mount < _blueprint.mounts.size():
		var mount_frame := Mounting.frame(placement, _blueprint, _blueprint.mounts[_selected_mount])
		if not mount_frame.is_empty():
			_overlay.draw_polyline(_closed(_to_px(Mounting.nozzle(placement, mount_frame))), SELECTED, _px(3.0), true)
	_draw_envelope()
	# The forward arrow, from the core.
	for tile in _blueprint.tiles:
		if tile.type == placement.tiles.core_id():
			var from := ShipStats.polygon_centroid(placement.tile_polygon(tile)) * PX
			var tip := from + Vector2.RIGHT * PX * 0.9
			_overlay.draw_line(from, tip, Color(0.3, 0.9, 0.4, 0.8), _px(3.0), true)
			var s := _px(9.0)
			_overlay.draw_colored_polygon(PackedVector2Array([tip + Vector2(s, 0), tip + Vector2(-s * 0.6, -s * 0.8), tip + Vector2(-s * 0.6, s * 0.8)]), Color(0.3, 0.9, 0.4, 0.8))


## Spokes for the rose (scaled to its strongest direction) and an arc each way for turning,
## thicker for the stronger turn.
func _draw_envelope() -> void:
	if _envelope == null or _envelope.thrusters.is_empty():
		return
	var center := _center_of_mass * PX
	var strongest := 0.0
	for force in _envelope.rose:
		strongest = maxf(strongest, force)
	if strongest > 0.0:
		for i in ThrustEnvelope.DIRECTIONS.size():
			var reach := _envelope.rose[i] / strongest * ROSE_REACH_U * PX
			if reach > 0.5:
				_overlay.draw_line(center, center + ThrustEnvelope.direction(i) * reach, ROSE, _px(4.0), true)
	var radius := ROSE_REACH_U * 0.55 * PX
	var turn_max := maxf(_envelope.turn_left, _envelope.turn_right)
	for side: Array in [[_envelope.turn_right, 1.0], [_envelope.turn_left, -1.0]]:
		if side[0] <= ThrustEnvelope.NONE:
			continue
		# Both arcs start just off the nose: the right turn sweeps down (+y), the left up.
		var width := _px(2.0 + 4.0 * side[0] / turn_max)
		_overlay.draw_arc(center, radius, side[1] * 0.12, side[1] * 1.3, 20, TURN, width, true)
	_overlay.draw_circle(center, _px(5.0), ROSE)


## A width of `screen_px` on screen, at the current zoom.
func _px(screen_px: float) -> float:
	var camera := get_viewport().get_camera_2d()
	return screen_px / (camera.zoom.x if camera != null else 1.0)


func _to_px(polygon: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in polygon:
		out.append(p * PX)
	return out


func _closed(polygon: PackedVector2Array) -> PackedVector2Array:
	return polygon + PackedVector2Array([polygon[0]])

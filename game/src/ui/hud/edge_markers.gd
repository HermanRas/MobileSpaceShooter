class_name EdgeMarkers
extends Control
## Marks at the screen's edge pointing at ships off screen (owner, 2026-10-26: the carrier is
## hard to find once it flies off). Far off, a small arrow; it grows as the ship nears the view,
## and just before the ship comes on screen it's a full-size dot. An enemy you've seen is a solid
## dot of fixed size (5.5); arrows for every enemy come with radar tech (v2). Full-rect and
## click-through; the owner hands it the ships each frame.

const INSET := 36.0
const SIZE := 28.0

## Tuning (flight.json edge_markers): a dot within dot_within_u of the screen's edge; the arrow
## shrinks from full size there to smallest_share at smallest_at_u. The owner forgets a seen
## enemy beyond sight_range_u.
var dot_within_u := 4.0
var smallest_at_u := 120.0
var smallest_share := 0.45
var sight_range_u := 60.0

## [screen position, colour, U beyond the screen's edge, always a dot]
var _marks: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(table: Dictionary) -> void:
	for key in ["dot_within_u", "smallest_at_u", "smallest_share", "sight_range_u"]:
		if table.has(key):
			set(key, float(table[key]))


## `marks`: [[world position, colour, always a dot (optional)], ...]. `camera` maps them to the
## screen.
func point_at(camera: Camera2D, marks: Array) -> void:
	var to_screen := camera.get_canvas_transform()
	var per_u := camera.zoom.x * ShipMesh.PX_PER_U
	_marks.clear()
	for mark: Array in marks:
		var at: Vector2 = to_screen * (mark[0] as Vector2)
		var edge: Variant = edge_point(at, size, 0.0)
		_marks.append([at, mark[1], 0.0 if edge == null else at.distance_to(edge) / per_u, mark.size() > 2 and mark[2]])
	queue_redraw()


## Whether `world_point` is in `camera`'s view.
func on_screen(camera: Camera2D, world_point: Vector2) -> bool:
	return edge_point(camera.get_canvas_transform() * world_point, size, 0.0) == null


## The mark's size share for a ship `beyond_u` off screen: 1 near the edge, smallest_share far off.
func size_share(beyond_u: float) -> float:
	var t := clampf((beyond_u - dot_within_u) / maxf(smallest_at_u - dot_within_u, 0.001), 0.0, 1.0)
	return lerpf(1.0, smallest_share, t)


## Where a mark for screen point `point` sits on the inset edge, or null when it's on screen.
static func edge_point(point: Vector2, screen: Vector2, inset: float = INSET) -> Variant:
	if Rect2(Vector2.ZERO, screen).has_point(point):
		return null
	var center := screen * 0.5
	var half := center - Vector2(inset, inset)
	var along := point - center
	var reach := minf(half.x / maxf(absf(along.x), 0.001), half.y / maxf(absf(along.y), 0.001))
	return center + along * minf(reach, 1.0)


func _draw() -> void:
	var started := Time.get_ticks_usec()
	for mark: Array in _marks:
		var spot: Variant = edge_point(mark[0], size)
		if spot == null:
			continue
		var tip := spot as Vector2
		var beyond: float = mark[2]
		var outline := Color(0, 0, 0, 0.6)
		if beyond <= dot_within_u or mark[3]:
			draw_circle(tip, SIZE * 0.7, mark[1])
			draw_arc(tip, SIZE * 0.7, 0.0, TAU, 24, outline, 2.0, true)
			continue
		var length := SIZE * size_share(beyond)
		var facing := (mark[0] as Vector2 - size * 0.5).normalized()
		var side := facing.orthogonal()
		var points := PackedVector2Array([tip + facing * length, tip - facing * length * 0.6 + side * length * 0.8,
				tip - facing * length * 0.6 - side * length * 0.8])
		draw_colored_polygon(points, mark[1])
		draw_polyline(points + PackedVector2Array([points[0]]), outline, 2.0, true)
	BenchRun.spent(&"markers", started)

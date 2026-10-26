class_name PortraitView
extends Control
## A pilot's portrait (PLAN.md 6.2, §6.5, D3): their character in one of four moods. Until
## the painted portraits and their recolour shader (A.7) it draws a placeholder bust in the
## chosen colours: hair (short for the male base, long for the female), eyes, outfit and its
## trim, with brows and mouth for the mood. With no character it's a helmet (no pilot yet).
## `cycle_s` > 0 steps through the moods (the character screen's preview).

const MOODS: Array[StringName] = [&"idle", &"happy", &"sad", &"angry"]
const SKIN := Color("#e2b48c")
const BACK := Color(0.1, 0.16, 0.26)

## {"base", "hair", "eyes", "outfit", "trim"} (ProfileRecord.character), or {} for a helmet.
var character := {}:
	set(value):
		character = value
		queue_redraw()
var mood: StringName = &"idle":
	set(value):
		mood = value
		queue_redraw()
var cycle_s := 0.0
## The frame round it, or transparent for none.
var frame := Color(1.0, 0.62, 0.25)

var _clock := 0.0


func _process(delta: float) -> void:
	if cycle_s <= 0.0:
		return
	_clock += delta
	if _clock >= cycle_s:
		_clock = 0.0
		mood = MOODS[(MOODS.find(mood) + 1) % MOODS.size()]


func _draw() -> void:
	var side := minf(size.x, size.y)
	var box := Rect2((size - Vector2.ONE * side) * 0.5 + Vector2.ONE * 6.0, Vector2.ONE * (side - 12.0))
	draw_rect(box, BACK)
	if character.is_empty():
		_helmet(box)
	else:
		_bust(box)
	if frame.a > 0.0:
		draw_rect(box, frame, false, 3.0)


## A point in the box from unit coordinates (0..1 across and down).
func _at(box: Rect2, u: Vector2) -> Vector2:
	return box.position + u * box.size


## An oval (or part of one, `from`..`to`), clipped to the portrait's box.
func _oval(box: Rect2, center: Vector2, radii: Vector2, colour: Color, from := 0.0, to := TAU) -> void:
	var points := PackedVector2Array()
	for k in 33:
		var a := lerpf(from, to, k / 32.0)
		points.append(_at(box, center + Vector2(cos(a) * radii.x, sin(a) * radii.y)))
	var frame_points := PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), box.end,
			Vector2(box.position.x, box.end.y)])
	for part in Geometry2D.intersect_polygons(points, frame_points):
		draw_colored_polygon(part, colour)


func _bust(box: Rect2) -> void:
	var hair := Color(str(character.get("hair", "#5a3a22")))
	var eyes := Color(str(character.get("eyes", "#3b6fb0")))
	var outfit := Color(str(character.get("outfit", "#2f4f7f")))
	var trim := Color(str(character.get("trim", "#ffd27a")))
	var female: bool = character.get("base", "male") == "female"
	if female:
		_oval(box, Vector2(0.5, 0.55), Vector2(0.26, 0.32), hair.darkened(0.15))  # long hair, behind
	_oval(box, Vector2(0.5, 1.08), Vector2(0.44, 0.32), outfit)  # shoulders
	draw_rect(Rect2(_at(box, Vector2(0.44, 0.62)), box.size * Vector2(0.12, 0.16)), SKIN.darkened(0.12))  # neck
	var collar := PackedVector2Array([_at(box, Vector2(0.36, 0.78)), _at(box, Vector2(0.5, 0.9)), _at(box, Vector2(0.64, 0.78))])
	draw_polyline(collar, trim, maxf(box.size.x * 0.03, 2.0), true)
	draw_line(_at(box, Vector2(0.5, 0.9)), _at(box, Vector2(0.5, 0.995)), trim, maxf(box.size.x * 0.02, 2.0))
	_oval(box, Vector2(0.5, 0.45), Vector2(0.165, 0.205), SKIN)  # head
	_oval(box, Vector2(0.5, 0.36), Vector2(0.18, 0.13), hair, PI, TAU)  # the top of the hair
	if female:
		_oval(box, Vector2(0.35, 0.47), Vector2(0.045, 0.16), hair)
		_oval(box, Vector2(0.65, 0.47), Vector2(0.045, 0.16), hair)
	else:
		_oval(box, Vector2(0.345, 0.42), Vector2(0.025, 0.07), hair)
		_oval(box, Vector2(0.655, 0.42), Vector2(0.025, 0.07), hair)
	for x in [0.435, 0.565]:
		_oval(box, Vector2(x, 0.465), Vector2(0.032, 0.02), Color(0.97, 0.97, 0.95))
		_oval(box, Vector2(x, 0.465), Vector2(0.016, 0.018), eyes)
		_oval(box, Vector2(x, 0.465), Vector2(0.007, 0.008), Color(0.05, 0.05, 0.08))
	draw_line(_at(box, Vector2(0.5, 0.48)), _at(box, Vector2(0.495, 0.525)), SKIN.darkened(0.3), 2.0)  # nose
	_face(box, hair.darkened(0.2))


## Brows and mouth for the mood.
func _face(box: Rect2, brow: Color) -> void:
	var width := maxf(box.size.x * 0.012, 2.0)
	var lift := {&"idle": [0.0, 0.0], &"happy": [-0.012, -0.012], &"sad": [0.008, -0.022], &"angry": [-0.012, 0.016]}
	var ends: Array = lift.get(mood, [0.0, 0.0])  # [outer end, inner end] in unit y
	for side in [-1.0, 1.0]:
		var outer := Vector2(0.5 + side * 0.105, 0.425 + float(ends[0]))
		var inner := Vector2(0.5 + side * 0.03, 0.425 + float(ends[1]))
		draw_line(_at(box, outer), _at(box, inner), brow, width, true)
	var mouth := PackedVector2Array()
	var curve := {&"idle": 0.0, &"happy": 0.025, &"sad": -0.02, &"angry": -0.01}
	var bend: float = curve.get(mood, 0.0)
	var half := 0.05 if mood != &"angry" else 0.04
	for k in 9:
		var t := k / 8.0 * 2.0 - 1.0
		mouth.append(_at(box, Vector2(0.5 + t * half, 0.57 + bend * (1.0 - t * t) - bend * 0.5)))
	draw_polyline(mouth, Color(0.55, 0.22, 0.2), width, true)


## No pilot yet: a helmet.
func _helmet(box: Rect2) -> void:
	_oval(box, Vector2(0.5, 1.0), Vector2(0.36, 0.22), Color(0.75, 0.78, 0.85))
	_oval(box, Vector2(0.5, 0.52), Vector2(0.3, 0.3), Color(0.86, 0.88, 0.92))
	_oval(box, Vector2(0.5, 0.55), Vector2(0.22, 0.15), Color(0.08, 0.12, 0.22))
	draw_line(_at(box, Vector2(0.36, 0.5)), _at(box, Vector2(0.44, 0.45)), Color(0.35, 0.8, 1.0, 0.9), 4.0)
	draw_line(_at(box, Vector2(0.55, 0.46)), _at(box, Vector2(0.62, 0.51)), Color(1.0, 0.62, 0.25, 0.9), 4.0)

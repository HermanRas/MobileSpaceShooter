class_name LaunchBay
extends Node2D
## The hangar bay a WaveTime (and Story) flight launches from and docks into (PLAN.md 8.1): a
## station block with an open mouth facing +x, floor lamps chasing out to it, a glowing field
## across the mouth and a shutter that closes over it. Sized round a ship of `ship_u` (its longest
## side).
##
## With A.14's art (`vis.world.launch_bay`) it's that picture, scaled so its deck is `inner_w`
## across, with the lamps lit over the painted ones and the doors (`vis.world.bay_shutter`) sliding
## in from the walls. Without it, rectangles in `vis.fx.launch_bay`'s colours.

const PX := ShipMesh.PX_PER_U
const META_ID := &"vis.fx.launch_bay"
const ART_ID := &"vis.world.launch_bay"
const SHUTTER_ID := &"vis.world.bay_shutter"
## U/s the floor lights chase toward the mouth.
const CHASE_U_S := 6.0

## 0 open .. 1 shut.
var shutter := 0.0:
	set(value):
		shutter = clampf(value, 0.0, 1.0)
		queue_redraw()
## Inside the bay, in U: across, and from the back wall to the mouth (at x = 0).
var inner_w := 6.0
var depth := 8.0

var _colors := {}
var _age := 0.0
## The art, and how to place it: its picture's pixels per U, the mouth's and the deck's middle in
## the picture, and the lamps in U.
var _art: Texture2D
var _door: Texture2D
var _art_px_per_u := 1.0
var _art_origin := Vector2.ZERO
var _lamps_u := PackedVector2Array()
var _lamp_u := 0.3


static func create(ship_u: float) -> LaunchBay:
	var bay := LaunchBay.new()
	bay.name = "LaunchBay"
	bay.inner_w = maxf(ship_u, 2.0) + 3.0
	bay.depth = maxf(ship_u, 2.0) + 5.0
	bay._use_art()
	return bay


## Where a ship waits inside, in the bay's frame (U): halfway in, nose to the mouth.
func berth_u() -> Vector2:
	return Vector2(-depth * 0.5, 0.0)


## The picture's deck sets the depth for the width the ship needs.
func _use_art() -> void:
	if not Assets.has_real_art(ART_ID):
		return
	var meta := Assets.meta(ART_ID)
	var deck: Array = meta.get("deck_px", [])
	if deck.size() != 4:
		return
	_art = Assets.tex(ART_ID)
	_door = Assets.tex(SHUTTER_ID) if Assets.has_real_art(SHUTTER_ID) else null
	var deck_h := float(deck[3]) - float(deck[1])
	_art_px_per_u = deck_h / inner_w
	_art_origin = Vector2(float(deck[2]), (float(deck[1]) + float(deck[3])) * 0.5)
	depth = (float(deck[2]) - float(deck[0])) / _art_px_per_u
	var lamps: Dictionary = meta.get("lamps_px", {})
	for y: Variant in lamps.get("y", []):
		for x: Variant in lamps.get("x", []):
			_lamps_u.append(_u_of(Vector2(float(x), float(y))))
	_lamp_u = float(meta.get("lamp_px", 22)) / _art_px_per_u


## A point in the picture's pixels, in the bay's frame (U).
func _u_of(picture_px: Vector2) -> Vector2:
	return (picture_px - _art_origin) / _art_px_per_u


func _ready() -> void:
	z_index = -1  # under the ships
	var meta := Assets.meta(META_ID)
	for key: String in ["hull", "trim", "floor", "lights", "mouth", "shutter"]:
		_colors[key] = Color.from_string(str(meta.get(key, "#808080")), Color.GRAY)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _draw() -> void:
	if _art != null:
		_draw_art()
	else:
		_draw_blocks()


func _draw_art() -> void:
	var top_left := _u_of(Vector2.ZERO) * PX
	draw_texture_rect(_art, Rect2(top_left, Vector2(_art.get_size()) / _art_px_per_u * PX), false)
	var lights: Color = _colors["lights"]
	var side := _lamp_u * PX
	for at in _lamps_u:
		var pulse := pow(0.5 + 0.5 * cos((at.x - _age * CHASE_U_S) * 0.9), 6.0)
		draw_rect(Rect2(at * PX - Vector2(side, side) * 0.5, Vector2(side, side)), Color(lights, 0.85 * pulse))
		draw_circle(at * PX, side * 0.9, Color(lights, 0.25 * pulse))
	var half := inner_w * 0.5
	var mouth: Color = _colors["mouth"]
	mouth.a = 0.3 + 0.15 * sin(_age * 4.0)
	_rect(Vector2(-0.15, -half), Vector2(0.0, half), mouth)
	if shutter > 0.0:
		_draw_doors(half)


## The two door halves sliding in from the walls over the mouth, the second mirrored.
func _draw_doors(half: float) -> void:
	var shown := half * shutter
	if _door == null:
		for side in [-1.0, 1.0]:
			_rect(Vector2(-half * 0.6, side * half), Vector2(0.0, side * (half - shown)), _colors["shutter"])
		return
	var size := Vector2(_door.get_size())
	var width := half * size.x / size.y  # the slab keeps its shape, half the mouth tall
	var cut := size.y * shutter  # the part of the slab out of the wall, its leading edge first
	for side in [-1.0, 1.0]:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, side))
		draw_texture_rect_region(_door, Rect2(Vector2(-width, -half) * PX, Vector2(width, shown) * PX),
				Rect2(0.0, size.y - cut, size.x, cut))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_blocks() -> void:
	var half := inner_w * 0.5
	var lip := 0.6
	# The station behind, then the bay's block, its floor and the trim round the mouth.
	_rect(Vector2(-depth - 10.0, -half - 7.0), Vector2(-depth - 2.0, half + 7.0), _colors["hull"].darkened(0.25))
	_rect(Vector2(-depth - 3.0, -half - 3.0), Vector2(lip, half + 3.0), _colors["hull"])
	_rect(Vector2(-depth, -half), Vector2(lip, half), _colors["floor"])
	for side in [-1.0, 1.0]:
		_rect(Vector2(-depth - 3.0, side * (half + 3.0)), Vector2(lip, side * (half + 2.6)), _colors["trim"])
		_rect(Vector2(-0.4, side * half), Vector2(lip, side * (half + 3.0)), _colors["trim"])
	# Floor lights, two rows, a pulse running out to the mouth.
	var lights: Color = _colors["lights"]
	var x := -depth + 0.6
	while x < 0.0:
		var pulse := pow(0.5 + 0.5 * cos((x - _age * CHASE_U_S) * 0.9), 6.0)
		for side in [-1.0, 1.0]:
			var at := Vector2(x, side * (half - 0.5)) * PX
			draw_rect(Rect2(at - Vector2(5, 5), Vector2(10, 10)), lights.darkened(0.7).lerp(lights, pulse))
		x += 1.0
	# The field across the open mouth, and the shutter closing over it from both sides.
	var mouth: Color = _colors["mouth"]
	mouth.a = 0.35 + 0.15 * sin(_age * 4.0)
	_rect(Vector2(lip - 0.15, -half), Vector2(lip, half), mouth)
	if shutter > 0.0:
		for side in [-1.0, 1.0]:
			_rect(Vector2(-0.4, side * half), Vector2(lip, side * half * (1.0 - shutter)), _colors["shutter"])


## A filled rectangle between two corners, in U.
func _rect(a: Vector2, b: Vector2, color: Color) -> void:
	var low := Vector2(minf(a.x, b.x), minf(a.y, b.y))
	draw_rect(Rect2(low * PX, (Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) - low) * PX), color)

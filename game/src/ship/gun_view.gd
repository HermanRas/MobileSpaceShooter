class_name GunView
extends Node2D
## Draws a ship's guns (PLAN.md 4.4). With the gun atlas (A.3), each gun is its painted head
## (housing and barrels) turning about the housing's centre, scaled so the barrel tip meets the
## muzzle; the trim band is tinted per weapon. Without it (the placeholder), a turret's round
## base, an edge gun's mounting block, and each barrel at its current angle, drawn in code.
## Turrets and swivels turn, so guns can't be part of the ship's one static mesh; they're one
## more canvas item per ship, above the hull. The hangar draws with `draw_gun()` too. Each shot
## flashes at the muzzle for `flash_s` (4.5). A laser draws its beam to where it ends and a heat
## arc round its base that turns red as it nears overheating (4.6b).

const PX := ShipMesh.PX_PER_U
const LOOK_ID := &"vis.weapons"
const ATLAS_ID := &"vis.weapons.atlas"

var _gunnery: Gunnery
var _controller: WeaponController
var _look: Dictionary
## Per gun: the shot count last frame, and the flash time left.
var _seen := PackedInt32Array()
var _flash := PackedFloat32Array()


func attach(controller: WeaponController) -> void:
	_gunnery = controller.gunnery
	_controller = controller
	_look = Assets.meta(LOOK_ID)
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _process(delta: float) -> void:
	if _gunnery == null or _gunnery.layout.guns.is_empty():
		return
	var count := _gunnery.layout.guns.size()
	if _seen.size() != count:  # the ship lost guns: start the counts afresh
		_seen = _gunnery.fired.duplicate()
		_flash.resize(count)
		_flash.fill(0.0)
	for i in count:
		_flash[i] = maxf(_flash[i] - delta, 0.0)
		if _gunnery.fired[i] != _seen[i]:
			_flash[i] = float(_look.get("flash_s", 0.05))
			_seen[i] = _gunnery.fired[i]
	queue_redraw()


func _draw() -> void:
	if _gunnery == null:
		return
	for i in _gunnery.layout.guns.size():
		var gun := _gunnery.layout.guns[i]
		if _controller.beam_ends.has(i):
			_draw_beam(gun, _gunnery.angles[i], to_local(_controller.beam_ends[i]))
		draw_gun(self, gun, _gunnery.angles[i], _look)
		if gun.stats["beam"] and _gunnery.heats[i] > 0.0:
			_draw_heat(gun, _gunnery.heats[i], _gunnery.overheated[i])
		if i < _flash.size() and _flash[i] > 0.0 and not gun.stats["beam"]:
			_draw_flash(gun, _gunnery.angles[i], _flash[i] / float(_look.get("flash_s", 0.05)))


## A star of light at the muzzle, `share` (1 → 0) of the way through its flash.
func _draw_flash(gun: GunLayout.Gun, angle: float, share: float) -> void:
	var dir := Vector2.from_angle(angle)
	var tip := (gun.pivot + dir * gun.muzzle) * PX
	var size := float(_own(gun, _look).get("flash_u", _look.get("flash_u", 0.28))) * PX * (0.6 + 0.4 * share)
	var color := Color(Color.from_string(str(_look.get("flash", "#fff2c0")), Color.WHITE), share)
	var side := dir.orthogonal() * size * 0.3
	draw_colored_polygon(PackedVector2Array([tip - dir * size * 0.15, tip + side, tip + dir * size, tip - side]), color)
	draw_circle(tip, size * 0.25, color)


## The beam from the muzzle to `end` (ship-local pixels): a wide glow and a bright core.
func _draw_beam(gun: GunLayout.Gun, angle: float, end: Vector2) -> void:
	var tip := (gun.pivot + Vector2.from_angle(angle) * gun.muzzle) * PX
	var color := Color.from_string(str(_own(gun, _look).get("beam_color", "#ff4060")), Color.RED)
	var flicker := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.05)
	draw_line(tip, end, Color(color, 0.35 * flicker), 0.22 * PX)
	draw_line(tip, end, Color(color.lightened(0.6), 0.9), 0.07 * PX)
	draw_circle(end, 0.14 * PX * flicker, Color(color.lightened(0.5), 0.8))


## How hot a beam gun is: an arc round its pivot, yellow to red, blinking once it overheats.
func _draw_heat(gun: GunLayout.Gun, heat: float, over: bool) -> void:
	if over and int(Time.get_ticks_msec() / 150) % 2 == 0:
		return
	var radius := (float(gun.stats["turret_radius_u"]) + 0.08) * PX
	var color := Color(1.0, 0.9, 0.2).lerp(Color(1.0, 0.15, 0.1), heat)
	draw_arc(gun.pivot * PX, radius, -PI * 0.5, -PI * 0.5 + TAU * heat, 24, color, 0.06 * PX, true)


## A weapon's own overrides of the gun look (`guns` in vis.weapons).
static func _own(gun: GunLayout.Gun, look: Dictionary) -> Dictionary:
	return look.get("guns", {}).get(String(gun.weapon), {})


## One gun on `canvas`, in the ship's pixels, its barrel at ship-local `angle`.
static func draw_gun(canvas: CanvasItem, gun: GunLayout.Gun, angle: float, look: Dictionary) -> void:
	var base := Color.from_string(str(look.get("base", "#59616b")), Color.DIM_GRAY)
	var barrel := Color.from_string(str(look.get("barrel", "#2a2e34")), Color.BLACK)
	var rim := Color.from_string(str(look.get("rim", "#9aa3ad")), Color.GRAY)
	var own := _own(gun, look)
	var width := float(own.get("barrel_width_u", look.get("barrel_width_u", 0.12))) * PX
	var barrels := int(own.get("barrels", 1))
	var pivot := gun.pivot * PX
	var cell := (look.get("atlas_cells", []) as Array).find(str(own.get("art", gun.weapon)))
	if cell >= 0 and Assets.has_real_art(ATLAS_ID):
		_draw_head(canvas, pivot, angle, gun.muzzle * PX, cell,
				Color.from_string(str(own.get("trim", look.get("trim", "#c3cad2"))), Color.WHITE))
		return
	var dir := Vector2.from_angle(angle)
	var tip := pivot + dir * gun.muzzle * PX
	if gun.arc >= PI:
		var radius := float(gun.stats["turret_radius_u"]) * PX
		canvas.draw_circle(pivot, radius, base)
		canvas.draw_arc(pivot, radius, 0.0, TAU, 24, rim, 1.5, true)
		_draw_barrels(canvas, pivot, tip, dir, barrels, width, barrel)
		canvas.draw_circle(pivot, radius * 0.45, rim)
		return
	# An edge gun: a block along its stretch of edge, and the barrel from the middle of it.
	var out := Vector2.from_angle(gun.facing)
	var along := out.orthogonal() * float(gun.stats["edge_u"]) * 0.5 * PX
	var depth := out * float(look.get("block_depth_u", 0.14)) * PX
	var block := PackedVector2Array([pivot - along, pivot + along, pivot + along + depth, pivot - along + depth])
	canvas.draw_colored_polygon(block, base)
	canvas.draw_polyline(block + PackedVector2Array([block[0]]), rim, 1.5, true)
	_draw_barrels(canvas, pivot + depth * 0.5, tip, dir, barrels, width, barrel)
	canvas.draw_line(tip - dir * width, tip, rim, width * (barrels + 0.2))


## A gun's painted head from the atlas: turned to `angle` about `pivot` (pixels), scaled so its
## barrel tip is `muzzle_px` out, with its trim band drawn over it in `trim`. The atlas geometry
## comes from tools/slice_sheets.py, via the atlas's entry in visuals.json.
static func _draw_head(canvas: CanvasItem, pivot: Vector2, angle: float, muzzle_px: float, cell: int, trim: Color) -> void:
	var meta := Assets.meta(ATLAS_ID)
	var size := float(meta.get("cell_px", 256))
	var pad := float(meta.get("pad_px", 16))
	var at: Array = meta.get("pivot_px", [96, 128])
	var cell_pivot := Vector2(float(at[0]), float(at[1]))
	var k := muzzle_px / (float(meta.get("tip_x_px", 248)) - cell_pivot.x)
	var stride := size + 2.0 * pad
	var art := Rect2(cell * stride + pad, pad, size, size)
	var drawn := Rect2(-cell_pivot * k, Vector2(size, size) * k)
	var atlas := Assets.tex(ATLAS_ID)
	canvas.draw_set_transform(pivot, angle, Vector2.ONE)
	canvas.draw_texture_rect_region(atlas, drawn, art)
	canvas.draw_texture_rect_region(atlas, drawn, Rect2(art.position + Vector2(0, stride), art.size), trim)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


## `count` barrels side by side from `from` to `tip`.
static func _draw_barrels(canvas: CanvasItem, from: Vector2, tip: Vector2, dir: Vector2, count: int, width: float,
		color: Color) -> void:
	for k in count:
		var offset := dir.orthogonal() * width * 1.2 * (k - (count - 1) * 0.5)
		canvas.draw_line(from + offset, tip + offset, color, width)

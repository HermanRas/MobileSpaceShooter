class_name GunView
extends Node2D
## Draws a ship's guns (PLAN.md 4.4). With the gun atlas (A.3), each gun is its painted picture
## for its mount type (a turret on its round base, a fixed gun on a flat bracket, a swivel on a
## bracket with a pivot; A.3c) turning about its pivot, scaled so the barrel tip meets the
## muzzle; the trim band is tinted per weapon. Without it (the placeholder), a turret's round
## base, an edge gun's mounting block, and each barrel at its current angle, drawn in code.
## Turrets and swivels turn, so guns can't be part of the ship's one static mesh; they're one
## more canvas item per ship, above the hull. The hangar draws with `draw_gun()` too. Each shot
## flashes at the muzzle for `flash_s` (4.5). A laser draws its beam to where it ends and a heat
## arc round its base that turns red as it nears overheating (4.6b).
##
## Off screen it isn't redrawn (7.5: every ship's guns every frame was 4.3 ms of a 40-ship frame
## on the phone); the flashes are still counted, so it's right the frame it comes into view. A
## beam reaches far, so a gun view with one on always draws.

const PX := ShipMesh.PX_PER_U
const LOOK_ID := &"vis.weapons"
const ATLAS_ID := &"vis.weapons.atlas"

var _gunnery: Gunnery
var _controller: WeaponController
var _look: Dictionary
## Per gun: the shot count last frame, and the flash time left.
var _seen := PackedInt32Array()
var _flash := PackedFloat32Array()
## How far its guns reach from the ship's origin, in pixels, beams aside.
var _reach_px := 0.0


func attach(controller: WeaponController) -> void:
	_gunnery = controller.gunnery
	_controller = controller
	_look = Assets.meta(LOOK_ID)
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for gun in _gunnery.layout.guns:  # losing tiles only takes guns away, so this stays enough
		_reach_px = maxf(_reach_px, (gun.pivot.length() + gun.muzzle + 0.5) * PX)


func _process(delta: float) -> void:
	var started := Time.get_ticks_usec()
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
	if on_screen():
		queue_redraw()
	BenchRun.spent(&"gun_views", started)


## Whether any of it can be seen: its reach overlaps the view, or a beam is on.
func on_screen() -> bool:
	if not _controller.beam_ends.is_empty():
		return true
	var view := get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	return view.grow(_reach_px).has_point(global_position)


func _draw() -> void:
	var started := Time.get_ticks_usec()
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
	BenchRun.spent(&"gun_views", started)


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
	var art := str(own.get("art", gun.weapon))
	var cell := (look.get("atlas_cells", []) as Array).find(art)
	if cell >= 0 and Assets.has_real_art(ATLAS_ID):
		_draw_head(canvas, pivot, angle, gun.muzzle * PX, cell, _art_mount(gun.mount_type, art),
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


## The atlas row a gun of `art` on a `mount_type` mount is drawn from: its own, or the turret's
## when that cell is empty (`empty` in the atlas's visuals.json entry) or the type has no row.
static func _art_mount(mount_type: StringName, art: String) -> String:
	var meta := Assets.meta(ATLAS_ID)
	var mounts: Dictionary = meta.get("mounts", {})
	if not mounts.has(String(mount_type)) or "%s:%s" % [mount_type, art] in (meta.get("empty", []) as Array):
		return "turret"
	return String(mount_type)


## A gun's painted picture from the atlas, in `mount`'s row: turned to `angle` about `pivot`
## (pixels), scaled so its barrel tip is `muzzle_px` out, with its trim band drawn over it in
## `trim`. The atlas geometry comes from tools/slice_sheets.py, via the atlas's entry in
## visuals.json.
static func _draw_head(canvas: CanvasItem, pivot: Vector2, angle: float, muzzle_px: float, cell: int, mount: String,
		trim: Color) -> void:
	var meta := Assets.meta(ATLAS_ID)
	var row_info: Dictionary = meta.get("mounts", {}).get(mount, {"row": 0, "pivot_px": [96, 128]})
	var at: Array = row_info["pivot_px"]
	var cell_pivot := Vector2(float(at[0]), float(at[1]))
	var k := muzzle_px / (float(meta.get("tip_x_px", 248)) - cell_pivot.x)
	var art := _cell_rect(cell, mount)
	canvas.draw_set_transform(pivot, angle, Vector2.ONE)
	_draw_cell(canvas, Rect2(-cell_pivot * k, art.size * k), art, trim)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


## A gun as an icon (the hangar's palette): its picture for `mount_type`, pointing right, fitted
## into `rect`. False when there's no atlas or no cell for it, so the caller draws its own.
static func draw_icon(canvas: CanvasItem, weapon: StringName, mount_type: StringName, rect: Rect2, alpha := 1.0) -> bool:
	var look := Assets.meta(LOOK_ID)
	var own: Dictionary = look.get("guns", {}).get(String(weapon), {})
	var art := str(own.get("art", weapon))
	var cell := (look.get("atlas_cells", []) as Array).find(art)
	if cell < 0 or not Assets.has_real_art(ATLAS_ID):
		return false
	var side := minf(rect.size.x, rect.size.y)
	var trim := Color.from_string(str(own.get("trim", look.get("trim", "#c3cad2"))), Color.WHITE)
	_draw_cell(canvas, Rect2(rect.get_center() - Vector2.ONE * side * 0.5, Vector2.ONE * side),
			_cell_rect(cell, _art_mount(mount_type, art)), trim, alpha)
	return true


## Where `cell` of `mount`'s row is in the atlas, in its pixels.
static func _cell_rect(cell: int, mount: String) -> Rect2:
	var meta := Assets.meta(ATLAS_ID)
	var row := int(meta.get("mounts", {}).get(mount, {"row": 0})["row"])
	var size := float(meta.get("cell_px", 256))
	var pad := float(meta.get("pad_px", 16))
	var stride := size + 2.0 * pad
	return Rect2(cell * stride + pad, row * stride + pad, size, size)


## A cell drawn into `drawn`, then its trim mask (the same cell in the rows below) in `trim`.
static func _draw_cell(canvas: CanvasItem, drawn: Rect2, art: Rect2, trim: Color, alpha := 1.0) -> void:
	var meta := Assets.meta(ATLAS_ID)
	var stride := float(meta.get("cell_px", 256)) + 2.0 * float(meta.get("pad_px", 16))
	var atlas := Assets.tex(ATLAS_ID)
	canvas.draw_texture_rect_region(atlas, drawn, art, Color(1, 1, 1, alpha))
	canvas.draw_texture_rect_region(atlas, drawn,
			Rect2(art.position + Vector2(0, stride * (meta.get("mounts", {}) as Dictionary).size()), art.size),
			Color(trim, alpha))


## `count` barrels side by side from `from` to `tip`.
static func _draw_barrels(canvas: CanvasItem, from: Vector2, tip: Vector2, dir: Vector2, count: int, width: float,
		color: Color) -> void:
	for k in count:
		var offset := dir.orthogonal() * width * 1.2 * (k - (count - 1) * 0.5)
		canvas.draw_line(from + offset, tip + offset, color, width)

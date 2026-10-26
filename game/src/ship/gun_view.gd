class_name GunView
extends Node2D
## Draws a ship's guns (PLAN.md 4.4): a turret's round base, an edge gun's mounting block, and
## each barrel at its current angle. Drawn in code from `vis.weapons` until gun art lands.
## Turrets and swivels turn, so guns can't be part of the ship's one static mesh; they're one
## more canvas item per ship, above the hull. The hangar draws with `draw_gun()` too. Each shot
## flashes at the muzzle for `flash_s` (4.5). A laser draws its beam to where it ends and a heat
## arc round its base that turns red as it nears overheating (4.6b).

const PX := ShipMesh.PX_PER_U
const LOOK_ID := &"vis.weapons"

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


## `count` barrels side by side from `from` to `tip`.
static func _draw_barrels(canvas: CanvasItem, from: Vector2, tip: Vector2, dir: Vector2, count: int, width: float,
		color: Color) -> void:
	for k in count:
		var offset := dir.orthogonal() * width * 1.2 * (k - (count - 1) * 0.5)
		canvas.draw_line(from + offset, tip + offset, color, width)

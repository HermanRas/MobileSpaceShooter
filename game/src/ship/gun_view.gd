class_name GunView
extends Node2D
## Draws a ship's guns (PLAN.md 4.4): a turret's round base, an edge gun's mounting block, and
## each barrel at its current angle. Drawn in code from `vis.weapons` until gun art lands.
## Turrets and swivels turn, so guns can't be part of the ship's one static mesh; they're one
## more canvas item per ship, above the hull. The hangar draws with `draw_gun()` too.

const PX := ShipMesh.PX_PER_U
const LOOK_ID := &"vis.weapons"

var _gunnery: Gunnery
var _look: Dictionary


func attach(controller: WeaponController) -> void:
	_gunnery = controller.gunnery
	_look = Assets.meta(LOOK_ID)
	z_index = 1


func _process(_delta: float) -> void:
	if _gunnery != null and not _gunnery.layout.guns.is_empty():
		queue_redraw()


func _draw() -> void:
	if _gunnery == null:
		return
	for i in _gunnery.layout.guns.size():
		draw_gun(self, _gunnery.layout.guns[i], _gunnery.angles[i], _look)


## One gun on `canvas`, in the ship's pixels, its barrel at ship-local `angle`.
static func draw_gun(canvas: CanvasItem, gun: GunLayout.Gun, angle: float, look: Dictionary) -> void:
	var base := Color.from_string(str(look.get("base", "#59616b")), Color.DIM_GRAY)
	var barrel := Color.from_string(str(look.get("barrel", "#2a2e34")), Color.BLACK)
	var rim := Color.from_string(str(look.get("rim", "#9aa3ad")), Color.GRAY)
	var width := float(look.get("barrel_width_u", 0.12)) * PX
	var pivot := gun.pivot * PX
	var tip := pivot + Vector2.from_angle(angle) * gun.muzzle * PX
	if gun.arc >= PI:
		var radius := float(gun.stats["turret_radius_u"]) * PX
		canvas.draw_circle(pivot, radius, base)
		canvas.draw_arc(pivot, radius, 0.0, TAU, 24, rim, 1.5, true)
		canvas.draw_line(pivot, tip, barrel, width)
		canvas.draw_circle(pivot, radius * 0.45, rim)
		return
	# An edge gun: a block along its stretch of edge, and the barrel from the middle of it.
	var out := Vector2.from_angle(gun.facing)
	var along := out.orthogonal() * float(gun.stats["edge_u"]) * 0.5 * PX
	var depth := out * float(look.get("block_depth_u", 0.14)) * PX
	var block := PackedVector2Array([pivot - along, pivot + along, pivot + along + depth, pivot - along + depth])
	canvas.draw_colored_polygon(block, base)
	canvas.draw_polyline(block + PackedVector2Array([block[0]]), rim, 1.5, true)
	canvas.draw_line(pivot + depth * 0.5, tip, barrel, width)
	canvas.draw_line(tip - Vector2.from_angle(angle) * width, tip, rim, width * 1.2)

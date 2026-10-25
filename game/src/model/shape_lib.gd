class_name ShapeLib
extends RefCounted
## Every tile shape and size from `data/shapes.json`, plus the rules they share.
##
## Built from the table Dictionary rather than reading the `Data` autoload, so model code
## stays free of the scene tree (PLAN.md 5.1).

var port_pitch: float
var rotation_step_deg: float
## Size code ("S", "M", "L") -> edge length in U.
var sizes: Dictionary = {}
var errors: PackedStringArray = []

var _shapes: Dictionary = {}


static func from_table(table: Dictionary) -> ShapeLib:
	var lib := ShapeLib.new()
	lib.port_pitch = table.get("port_pitch", 0.0)
	lib.rotation_step_deg = table.get("rotation_step_deg", 0.0)
	if lib.port_pitch <= 0.0 or lib.rotation_step_deg <= 0.0:
		lib.errors.append("port_pitch and rotation_step_deg must be positive")
	for code: String in table.get("sizes", {}):
		lib.sizes[StringName(code)] = float(table["sizes"][code])
	for shape_id: String in table.get("shapes", {}):
		var shape := Shape.from_def(StringName(shape_id), table["shapes"][shape_id], lib.errors)
		if shape != null:
			lib._shapes[shape.id] = shape
	lib._check_edges_fit_the_pitch()
	return lib


func shape(shape_id: StringName) -> Shape:
	return _shapes.get(shape_id)


func shape_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_shapes.keys())
	# StringName.sort() orders by interned pointer, not alphabetically.
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


## How many rotation steps make a full turn (24 at 15°).
func rotation_steps() -> int:
	return roundi(360.0 / rotation_step_deg)


func edge_u(size_code: StringName) -> float:
	return sizes.get(size_code, 0.0)


func polygon(shape_id: StringName, size_code: StringName, rot_steps: int,
		offset := Vector2.ZERO) -> PackedVector2Array:
	return shape(shape_id).polygon(edge_u(size_code), rot_steps, rotation_step_deg, offset)


func edges(shape_id: StringName, size_code: StringName, rot_steps: int,
		offset := Vector2.ZERO) -> Array[Shape.Edge]:
	return shape(shape_id).edges(edge_u(size_code), rot_steps, rotation_step_deg, port_pitch, offset)


## Every attachable edge, at every size, has to be a whole number of ports long, or snapping
## can't line ports up.
func _check_edges_fit_the_pitch() -> void:
	if port_pitch <= 0.0:
		return
	for shape_id: StringName in _shapes:
		for size_code: StringName in sizes:
			for edge in edges(shape_id, size_code, 0):
				if not edge.attachable:
					continue
				var count := edge.length() / port_pitch
				if count < 1.0 - Shape.LENGTH_EPSILON or absf(count - roundf(count)) > Shape.LENGTH_EPSILON:
					errors.append("%s %s edge %d is %.4f U, not a whole number of %.2f U ports"
							% [shape_id, size_code, edge.index, edge.length(), port_pitch])

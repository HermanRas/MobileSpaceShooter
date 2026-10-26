class_name ShipMesh
extends RefCounted
## Builds one ArrayMesh for a whole ship (PLAN.md 5.5: one draw call per ship), in the
## vertex layout `ship.gdshader` expects. Rebuild it when a tile is added, removed or painted.

const PX_PER_U := 64.0
## UV packs an atlas cell and a coordinate as cell * PACK + LOCAL_OFFSET + coordinate.
## LOCAL_OFFSET keeps a tile left of or above the origin from rounding down into the previous
## cell (a ship spans at most 16 U, so coordinates stay within +-8), and PACK is small so the
## packed value keeps its precision on the phone's GPU. The extra half repeat lines the texture up
## with Large tiles, which sit centred on whole-U positions, so each one shows a whole texture
## cell instead of four quarters. Both must match ship.gdshader.
const PACK := 100.0
const LOCAL_OFFSET := 50.5
## Damage shows in this many steps (4.2): scorched, cracked, ... nearly gone. Packed into UV.y
## in thousands, so changing a tile's step means a mesh rebuild; steps keep those rare.
const WEAR_STEPS := 4
const SHADER := preload("res://src/ship/ship.gdshader")
const ATLAS_ID := &"vis.tiles.material_atlas"
const DAMAGE_ID := &"vis.tiles.damage"


## A material for MeshInstance2D, with the tile atlas and damage overlays from the asset seam.
static func make_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"atlas", Assets.tex(ATLAS_ID))
	material.set_shader_parameter(&"damage", Assets.tex(DAMAGE_ID))
	material.set_shader_parameter(&"columns", float(_cell_names().size()))
	material.set_shader_parameter(&"variants", float(_variants()))
	material.set_shader_parameter(&"core_column", float(maxi(_cell_names().find("core"), 0)))
	return material


## The mesh for `tiles` (all of a blueprint's, or one ghost tile). Positions are in pixels,
## relative to the ship origin. With `bp`, the thrusters mounted on those tiles are drawn too,
## in the same mesh, so the whole ship stays one draw call. `wear` maps tile id -> damage step
## (0..WEAR_STEPS, from `wear_step()`).
static func build(tiles: Array, placement: Placement, bp: Blueprint = null, wear: Dictionary = {}) -> ArrayMesh:
	var cells := _cell_names()
	var variants := _variants()
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var on_ship := {}
	for tile: Blueprint.Tile in tiles:
		on_ship[tile.id] = true
		var polygon := placement.tile_polygon(tile)
		_add_fan(vertices, colors, uvs, polygon, maxi(cells.find(String(tile.type)), 0), tile.paint,
				wear.get(tile.id, 0) * variants + variant_of(polygon, variants), tile.type == placement.tiles.core_id())
	if bp != null and not bp.mounts.is_empty():
		var thruster_cell := maxi(cells.find("thruster"), 0)
		var tints: Dictionary = Assets.meta(ATLAS_ID).get("thruster_tints", {})
		for mount in bp.mounts:
			var type_id := ThrusterLib.type_of_part(str(mount.get("part", "")))
			var mount_frame := Mounting.frame(placement, bp, mount) if on_ship.has(int(mount.get("tile", -1))) else {}
			if type_id != &"" and not mount_frame.is_empty():
				_add_fan(vertices, colors, uvs, Mounting.nozzle(mount_frame), thruster_cell,
						Color.from_string(str(tints.get(String(type_id), "#888888")), Color.GRAY))
	var mesh := ArrayMesh.new()
	if vertices.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## The damage step for a tile with `hp_share` (0..1) of its HP left. A scratch doesn't show.
static func wear_step(hp_share: float) -> int:
	return clampi(int((1.0 - hp_share) * (WEAR_STEPS + 1)), 0, WEAR_STEPS)


## Which of the atlas's variants a tile shows: picked from where it sits, so it's the same every
## time the ship is built and neighbours mostly differ.
static func variant_of(polygon: PackedVector2Array, variants: int) -> int:
	var at := (ShipStats.polygon_centroid(polygon) * 4.0).round()
	return posmod(int(at.x) * 7 + int(at.y) * 13 + int(at.x * at.y), maxi(variants, 1))


## One convex polygon as a triangle fan from its centroid; vertex alpha carries the distance
## to the nearest edge for the shader's bevel and outline. `code` is the wear step and variant,
## packed as the shader reads them. A `local` polygon (the core) is textured in its own box,
## so its design is drawn once whatever its size.
static func _add_fan(vertices: PackedVector2Array, colors: PackedColorArray, uvs: PackedVector2Array,
		polygon: PackedVector2Array, cell: int, paint: Color, code := 0, local := false) -> void:
	var center := ShipStats.polygon_centroid(polygon)
	var box := Rect2(polygon[0], Vector2.ZERO)
	for p in polygon:
		box = box.expand(p)
	var box_center := box.get_center()
	var box_size := maxf(box.size.x, box.size.y)
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		var to_edge := _distance_to_line(center, a, b)
		for corner: Array in [[center, to_edge], [a, 0.0], [b, 0.0]]:
			var p: Vector2 = corner[0]
			vertices.append(p * PX_PER_U)
			colors.append(Color(paint.r, paint.g, paint.b, corner[1]))
			var at := (p - box_center) / box_size if local else p
			uvs.append(Vector2(cell * PACK + LOCAL_OFFSET + at.x, code * PACK + LOCAL_OFFSET + at.y))


static func _distance_to_line(p: Vector2, a: Vector2, b: Vector2) -> float:
	var along := (b - a).normalized()
	return absf((p - a).cross(along))


static func _variants() -> int:
	return int(Assets.meta(ATLAS_ID).get("variants", 1))


static func _cell_names() -> Array:
	return Assets.meta(ATLAS_ID).get("cells", ["core", "hull", "armor", "shield", "hardpoint", "thruster"])

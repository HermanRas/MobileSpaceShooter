class_name ShipMesh
extends RefCounted
## Builds one ArrayMesh for a whole ship (PLAN.md 5.5: one draw call per ship), in the
## vertex layout `ship.gdshader` expects. Rebuild it when a tile is added, removed or painted.

const PX_PER_U := 64.0
## Added to ship-local coordinates before packing them into UV.x beside the atlas cell, so a
## tile left of or above the origin can't round down into the previous cell. The extra half
## repeat lines the texture up with Large tiles, which sit centred on whole-U positions, so each
## one shows a whole texture cell instead of four quarters. Must match the shader's LOCAL_OFFSET.
const LOCAL_OFFSET := 100.5
const SHADER := preload("res://src/ship/ship.gdshader")
const ATLAS_ID := &"vis.tiles.material_atlas"


## A material for MeshInstance2D, with the tile atlas from the asset seam.
static func make_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"atlas", Assets.tex(ATLAS_ID))
	material.set_shader_parameter(&"cells", float(_cell_names().size()))
	return material


## The mesh for `tiles` (all of a blueprint's, or one ghost tile). Positions are in pixels,
## relative to the ship origin. With `bp`, the thrusters mounted on those tiles are drawn too,
## in the same mesh, so the whole ship stays one draw call.
static func build(tiles: Array, placement: Placement, bp: Blueprint = null) -> ArrayMesh:
	var cells := _cell_names()
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var on_ship := {}
	for tile: Blueprint.Tile in tiles:
		on_ship[tile.id] = true
		_add_fan(vertices, colors, uvs, placement.tile_polygon(tile), maxi(cells.find(String(tile.type)), 0), tile.paint)
	if bp != null and not bp.mounts.is_empty():
		var thruster_cell := maxi(cells.find("thruster"), 0)
		var tints: Dictionary = Assets.meta(ATLAS_ID).get("thruster_tints", {})
		for mount in bp.mounts:
			var type_id := ThrusterLib.type_of_part(str(mount.get("part", "")))
			var mount_frame := Mounting.frame(placement, bp, mount) if on_ship.has(int(mount.get("tile", -1))) else {}
			if type_id != &"" and not mount_frame.is_empty():
				_add_fan(vertices, colors, uvs, Mounting.nozzle(placement, mount_frame), thruster_cell,
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


## One convex polygon as a triangle fan from its centroid; vertex alpha carries the distance
## to the nearest edge for the shader's bevel and outline.
static func _add_fan(vertices: PackedVector2Array, colors: PackedColorArray, uvs: PackedVector2Array,
		polygon: PackedVector2Array, cell: int, paint: Color) -> void:
	var center := ShipStats.polygon_centroid(polygon)
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		var to_edge := _distance_to_line(center, a, b)
		for corner: Array in [[center, to_edge], [a, 0.0], [b, 0.0]]:
			var p: Vector2 = corner[0]
			vertices.append(p * PX_PER_U)
			colors.append(Color(paint.r, paint.g, paint.b, corner[1]))
			uvs.append(Vector2(cell * 1000.0 + LOCAL_OFFSET + p.x, LOCAL_OFFSET + p.y))


static func _distance_to_line(p: Vector2, a: Vector2, b: Vector2) -> float:
	var along := (b - a).normalized()
	return absf((p - a).cross(along))


static func _cell_names() -> Array:
	return Assets.meta(ATLAS_ID).get("cells", ["core", "hull", "armor", "shield", "hardpoint", "thruster"])

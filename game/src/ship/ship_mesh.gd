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
## relative to the ship origin.
static func build(tiles: Array, placement: Placement) -> ArrayMesh:
	var cells := _cell_names()
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	for tile: Blueprint.Tile in tiles:
		var polygon := placement.tile_polygon(tile)
		var center := ShipStats.polygon_centroid(polygon)
		var cell := maxi(cells.find(String(tile.type)), 0)
		for i in polygon.size():
			var a := polygon[i]
			var b := polygon[(i + 1) % polygon.size()]
			var to_edge := _distance_to_line(center, a, b)
			for corner: Array in [[center, to_edge], [a, 0.0], [b, 0.0]]:
				var p: Vector2 = corner[0]
				vertices.append(p * PX_PER_U)
				colors.append(Color(tile.paint.r, tile.paint.g, tile.paint.b, corner[1]))
				uvs.append(Vector2(cell * 1000.0 + LOCAL_OFFSET + p.x, LOCAL_OFFSET + p.y))
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


static func _distance_to_line(p: Vector2, a: Vector2, b: Vector2) -> float:
	var along := (b - a).normalized()
	return absf((p - a).cross(along))


static func _cell_names() -> Array:
	return Assets.meta(ATLAS_ID).get("cells", ["core", "hull", "armor", "shield", "hardpoint"])

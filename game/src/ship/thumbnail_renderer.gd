class_name ThumbnailRenderer
extends Node
## Renders a ship to a PNG once, off screen, for the library's cards (Phase 2.6).
##
## Add it to the tree, then `await render(bp, placement, path)`. Each call renders one frame
## of a private SubViewport, so it never shows on screen.

const SIZE := 256
const MARGIN := 0.88

var _viewport := SubViewport.new()
var _mesh := MeshInstance2D.new()


func _ready() -> void:
	_viewport.size = Vector2i(SIZE, SIZE)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_mesh.material = ShipMesh.make_material()
	_viewport.add_child(_mesh)
	add_child(_viewport)


func render(bp: Blueprint, placement: Placement, path: String) -> Error:
	if bp.tiles.is_empty():
		return ERR_INVALID_DATA
	var bounds := Rect2(placement.tile_polygon(bp.tiles[0])[0], Vector2.ZERO)
	for tile in bp.tiles:
		for p in placement.tile_polygon(tile):
			bounds = bounds.expand(p)
	var span := maxf(bounds.size.x, bounds.size.y) * ShipMesh.PX_PER_U
	var fit := SIZE * MARGIN / maxf(span, 1.0)
	_mesh.mesh = ShipMesh.build(bp.tiles, placement)
	_mesh.scale = Vector2(fit, fit)
	_mesh.position = Vector2(SIZE, SIZE) * 0.5 - bounds.get_center() * ShipMesh.PX_PER_U * fit
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	return image.save_png(path)

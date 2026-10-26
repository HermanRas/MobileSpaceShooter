extends Node2D
## The tile art up close (A.1): one ship at each wear step 0-4, left to right, over the arena's
## background colour. `tools/preview.sh res://dev_preview/art_tiles.tscn 1600x900 --ship=gunboat
## --zoom=1.5` (ship is a sample in data/blueprints or an enemy in data/enemies).

const PX := ShipMesh.PX_PER_U

var _placement: Placement
var _camera := Camera2D.new()
var _ships := Node2D.new()


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#020b15"))
	var tiles_table := Data.table(&"tiles")
	_placement = Placement.create(ShapeLib.from_table(Data.table(&"shapes")), TileLib.from_table(tiles_table), tiles_table)
	_placement.thrusters = ThrusterLib.from_table(Data.table(&"thrusters"))
	add_child(_ships)
	add_child(_camera)
	_camera.make_current()
	_show("gunboat", 1.0)


func preview_setup(args: Dictionary) -> void:
	_show(str(args.get("ship", "gunboat")), float(args.get("zoom", "1.0")))


func _show(ship_id: String, zoom: float) -> void:
	for child in _ships.get_children():
		child.queue_free()
	var data: Dictionary = Data.json_dir("blueprints").get(ship_id, Data.json_dir("enemies").get(ship_id, {}))
	var errors: PackedStringArray = []
	var bp := Blueprint.from_dict(data.get("blueprint", data), errors)
	if bp == null:
		push_error("art_tiles: no ship %s (%s)" % [ship_id, ", ".join(errors)])
		return
	var width := 0.0
	for tile in bp.tiles:
		for p in _placement.tile_polygon(tile):
			width = maxf(width, absf(p.x))
	var step := (width * 2.0 + 1.5) * PX
	for wear in range(ShipMesh.WEAR_STEPS + 1):
		var worn := {}
		for tile in bp.tiles:
			worn[tile.id] = wear
		var mesh := MeshInstance2D.new()
		mesh.mesh = ShipMesh.build(bp.tiles, _placement, bp, worn)
		mesh.material = ShipMesh.make_material()
		mesh.position = Vector2((wear - 2) * step, 0)
		_ships.add_child(mesh)
	_camera.zoom = Vector2(zoom, zoom)

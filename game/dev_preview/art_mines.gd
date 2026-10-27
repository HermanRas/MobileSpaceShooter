extends Node2D
## Mines in space up close (A.3d): a few dropped in a row, as ProjectilePool draws them, over
## the arena's background colour, beside the starter ship for scale. `tools/preview.sh res://dev_preview/art_mines.tscn 900x300 --frames=20`

const PX := ShipMesh.PX_PER_U


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#020b15"))
	var pool := ProjectilePool.new()
	add_child(pool)
	for i in 4:
		pool.fire({"from": Vector2(i * 1.5, 0.0), "vel": Vector2.ZERO, "life": 30.0 + i, "damage": 1.0,
				"type": "explosive", "proximity_u": 0.5}, 1, &"mines")
	var tiles_table := Data.table(&"tiles")
	var placement := Placement.create(ShapeLib.from_table(Data.table(&"shapes")), TileLib.from_table(tiles_table), tiles_table)
	placement.thrusters = ThrusterLib.from_table(Data.table(&"thrusters"))
	var bp := Blueprint.from_dict(Data.json_dir("blueprints")["starter"], [])
	var ship := MeshInstance2D.new()
	ship.mesh = ShipMesh.build(bp.tiles, placement, bp)
	ship.material = ShipMesh.make_material()
	ship.position = Vector2(-4.5, 0) * PX
	add_child(ship)
	var camera := Camera2D.new()
	camera.zoom = Vector2(2.0, 2.0)
	add_child(camera)
	camera.make_current()

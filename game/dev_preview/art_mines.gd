extends Node2D
## Mines in space up close (A.3d): a few dropped in a row, as ProjectilePool draws them, over
## the arena's background colour. `tools/preview.sh res://dev_preview/art_mines.tscn 900x300 --frames=20`

const PX := ShipMesh.PX_PER_U


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#020b15"))
	var pool := ProjectilePool.new()
	add_child(pool)
	for i in 4:
		pool.fire({"from": Vector2(i - 1.5, 0.0) * 1.5, "vel": Vector2.ZERO, "life": 30.0 + i, "damage": 1.0,
				"type": "explosive", "proximity_u": 0.5}, 1, &"mines")
	var camera := Camera2D.new()
	camera.zoom = Vector2(2.0, 2.0)
	add_child(camera)
	camera.make_current()

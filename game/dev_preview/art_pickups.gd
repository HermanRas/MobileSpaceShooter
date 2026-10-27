extends Node2D
## The loot art up close (A.4): one pickup of each kind in a row, as PickupField draws them in
## flight, over the arena's background colour. `tools/preview.sh res://dev_preview/art_pickups.tscn
## 1200x300 --frames=5`

const PX := ShipMesh.PX_PER_U


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#020b15"))
	var field := PickupField.new()
	field.scatter_u_s = 0.0
	field.scatter_per_blast_u = 0.0
	add_child(field)
	var pieces: Array[Dictionary] = [{&"hull": 1}, {&"alloy": 1}, {&"crystal": 1}, {&"tech": 1}, {&"gc": 1},
			{"gun": &"cannon", "mount": "fixed", "xp": 0}]
	for i in pieces.size():
		var piece: Array[Dictionary] = [pieces[i]]
		field.drop(PackedVector2Array([Vector2((i - 2.5) * 1.6 * PX, 0)]), Vector2.ZERO, piece)
	var camera := Camera2D.new()
	camera.zoom = Vector2(1.5, 1.5)
	add_child(camera)
	camera.make_current()

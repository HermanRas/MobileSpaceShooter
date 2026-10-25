class_name Starfield
extends CanvasLayer
## The flight background (Phase 3.5): a full-screen rect with starfield.gdshader, behind the
## world, fed the camera's position and zoom each frame so its layers scroll at their own
## parallax rates.

const SHADER := preload("res://src/flight/starfield.gdshader")

var camera: Camera2D

var _rect := ColorRect.new()
var _material := ShaderMaterial.new()


func _ready() -> void:
	layer = -10
	_material.shader = SHADER
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


func _process(_delta: float) -> void:
	if camera == null:
		return
	_material.set_shader_parameter(&"camera_position", camera.get_screen_center_position())
	_material.set_shader_parameter(&"camera_zoom", camera.zoom.x)
	_material.set_shader_parameter(&"screen_size", _rect.size)

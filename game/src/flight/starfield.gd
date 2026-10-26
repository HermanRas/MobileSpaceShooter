class_name Starfield
extends CanvasLayer
## The flight background (Phase 3.5): a full-screen rect with starfield.gdshader, behind the
## world, fed the camera's position and zoom each frame so its layers scroll at their own
## parallax rates. Without a camera (the menus, 6.1) it scrolls to `scroll` instead.

const SHADER := preload("res://src/flight/starfield.gdshader")

var camera: Camera2D
## Where the view is, in world px, when there's no camera.
var scroll := Vector2.ZERO

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
	_material.set_shader_parameter(&"camera_position", camera.get_screen_center_position() if camera != null else scroll)
	_material.set_shader_parameter(&"camera_zoom", camera.zoom.x if camera != null else 1.0)
	_material.set_shader_parameter(&"screen_size", _rect.size)

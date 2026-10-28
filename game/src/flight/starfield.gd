class_name Starfield
extends CanvasLayer
## The flight background (Phase 3.5): a full-screen rect with starfield.gdshader, behind the
## world, fed the camera's position and zoom each frame so its layers scroll at their own
## parallax rates. Without a camera (the menus, 6.1) it scrolls to `scroll` instead. `use_nebula()`
## puts one of the A.9 nebulae (visuals.json vis.space) behind the stars.

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


## Draws nebula `index` (1..count, wrapping) behind the stars, at the strength and scale in
## visuals.json vis.space; nothing while it's the placeholder.
func use_nebula(index: int) -> void:
	var look := Assets.meta(&"vis.space")
	var count := int(look.get("nebulae", 0))
	if count <= 0:
		return
	var id := StringName("vis.space.nebula_%d" % (posmod(index - 1, count) + 1))
	_material.set_shader_parameter(&"nebula", Assets.tex(id))
	_material.set_shader_parameter(&"nebula_strength", float(look.get("strength", 0.7)) if Assets.has_real_art(id) else 0.0)
	_material.set_shader_parameter(&"nebula_tile_px", float(look.get("tile_px", 2048.0)))


func _process(_delta: float) -> void:
	var started := Time.get_ticks_usec()
	_material.set_shader_parameter(&"camera_position", camera.get_screen_center_position() if camera != null else scroll)
	_material.set_shader_parameter(&"camera_zoom", camera.zoom.x if camera != null else 1.0)
	_material.set_shader_parameter(&"screen_size", _rect.size)
	BenchRun.spent(&"stars", started)

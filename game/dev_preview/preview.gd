extends Node
## Loads one real scene, lets it settle, and saves a screenshot. Driven by tools/preview.sh.
##
##     ... res://dev_preview/preview.tscn -- --scene=res://scenes/menu/main_menu.tscn
##         [--out=/abs/path.png] [--frames=30]
##
## Exits 0 when the PNG is written, 1 otherwise.

const DEFAULT_FRAMES := 30


func _ready() -> void:
	var args := _user_args()
	var scene_path: String = args.get("scene", "")
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		printerr("preview: --scene=<res:// path> is required and must exist (got '%s')" % scene_path)
		get_tree().quit(1)
		return
	var out: String = args.get("out", ProjectSettings.globalize_path(
			"res://dev_preview/out/%s.png" % scene_path.get_file().get_basename()))
	var frames := int(args.get("frames", DEFAULT_FRAMES))

	add_child((load(scene_path) as PackedScene).instantiate())
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(out)
	if error != OK:
		printerr("preview: cannot write %s (%s)" % [out, error_string(error)])
		get_tree().quit(1)
		return
	print("preview: wrote %s (%dx%d)" % [out, image.get_width(), image.get_height()])
	get_tree().quit(0)


func _user_args() -> Dictionary:
	var parsed := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var pair := arg.trim_prefix("--").split("=", true, 1)
			parsed[pair[0]] = pair[1]
	return parsed

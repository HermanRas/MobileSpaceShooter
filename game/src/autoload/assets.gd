extends Node
## The asset seam. Gameplay code asks for a visual by ID, never by path.
##
## `data/visuals.json` maps each ID to `{"path": ..., "placeholder": ...}`. `tex()` is total:
## the real art if it exists, else the declared placeholder, else a loud magenta square.
## It never returns null, so no phase ever blocks on missing art. It also merges the chrome
## theme (UiTheme) into Godot's default theme, the one every Control falls back to: a theme on
## the root window doesn't reach past a CanvasLayer.

const MISSING_SIZE := 16
const MISSING_COLOR := Color(1.0, 0.0, 1.0)

var _cache: Dictionary = {}
var _missing: Texture2D


func _ready() -> void:
	ThemeDB.get_default_theme().merge_with(UiTheme.build())


func tex(id: StringName) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var texture := _resolve(id)
	_cache[id] = texture
	return texture


## True when `id` resolves to its real art (not a placeholder or the magenta square).
func has_real_art(id: StringName) -> bool:
	var entry := _entry(id)
	return entry.has("path") and ResourceLoader.exists(entry["path"])


## The whole `visuals.json` entry for `id` (extra fields such as an atlas's cell order), or {}.
func meta(id: StringName) -> Dictionary:
	return _entry(id)


func clear_cache() -> void:
	_cache.clear()


func _resolve(id: StringName) -> Texture2D:
	var entry := _entry(id)
	for key in ["path", "placeholder"]:
		var path: String = entry.get(key, "")
		if not path.is_empty() and ResourceLoader.exists(path):
			var loaded := load(path) as Texture2D
			if loaded != null:
				return loaded
	if entry.is_empty():
		push_warning("Assets: unknown visual id '%s'" % id)
	return missing_texture()


func _entry(id: StringName) -> Dictionary:
	var visuals: Dictionary = Data.table(&"visuals").get("visuals", {})
	return visuals.get(String(id), {})


func missing_texture() -> Texture2D:
	if _missing == null:
		var image := Image.create(MISSING_SIZE, MISSING_SIZE, false, Image.FORMAT_RGBA8)
		image.fill(MISSING_COLOR)
		_missing = ImageTexture.create_from_image(image)
	return _missing

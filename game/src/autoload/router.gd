extends Node
## Scene changes and the Android back button.
##
## `application/config/quit_on_go_back` is off, so the back button arrives here and is passed
## to the current scene's `on_back()` if it has one. A scene without it ignores the button,
## which is what stops the back button from quitting by accident. Esc (the `back` action) does
## the same on a keyboard, so every screen goes back one way (owner, 2026-10-26).

const MAIN_MENU := "res://scenes/menu/main_menu.tscn"


func goto(scene_path: String) -> void:
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Router: cannot open %s (%s)" % [scene_path, error_string(error)])


func goto_main_menu() -> void:
	goto(MAIN_MENU)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # back resumes a paused flight


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"back"):
		get_viewport().set_input_as_handled()
		back()


func back() -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method(&"on_back"):
		scene.on_back()

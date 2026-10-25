extends Node
## First scene. The autoloads have loaded by the time this runs, so hand straight on.


func _ready() -> void:
	Router.goto_main_menu.call_deferred()

class_name MenuBackdrop
extends Node
## The menus' background (PLAN.md 6.1): the flight Starfield, slowly drifting. No camera: a
## current Camera2D would shift the menu's controls too.

## How fast the view drifts, px/s.
const DRIFT := Vector2(18, -6)

var _stars := Starfield.new()


func _ready() -> void:
	add_child(_stars)


func _process(delta: float) -> void:
	_stars.scroll += DRIFT * delta

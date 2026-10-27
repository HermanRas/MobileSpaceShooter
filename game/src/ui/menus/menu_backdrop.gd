class_name MenuBackdrop
extends Node
## The menus' background (PLAN.md 6.1): the flight Starfield with a nebula (A.9), slowly drifting.
## No camera: a current Camera2D would shift the menu's controls too.

## How fast the view drifts, px/s.
const DRIFT := Vector2(18, -6)
const NEBULA := 2

var _stars := Starfield.new()


func _ready() -> void:
	add_child(_stars)
	_stars.use_nebula(NEBULA)


func _process(delta: float) -> void:
	_stars.scroll += DRIFT * delta

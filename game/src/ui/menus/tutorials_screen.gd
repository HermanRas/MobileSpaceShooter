extends Control
## Tutorials (owner, 2026-10-26): the WaveTime and Story tutorials (15.2; locked until they
## exist) and the enemy gallery, every ship of the roster to look at. Back (the gesture, or Esc) goes to the
## main menu.

const GALLERY := "res://scenes/debug/enemy_gallery.tscn"
const TILE := Vector2(300, 140)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(MenuBackdrop.new())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 24)
	center.add_child(column)
	column.add_child(MenuKit.label("Tutorials", 48))
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override(&"separation", 16)
	tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(tiles)
	tiles.add_child(MenuKit.tile("WaveTime", "Locked: arrives in 15.2", Callable(), "WaveTimeTutorial", TILE))
	tiles.add_child(MenuKit.tile("Story", "Locked: arrives in 15.2", Callable(), "StoryTutorial", TILE))
	tiles.add_child(MenuKit.tile("Enemy gallery", "Every enemy ship, by tier", func() -> void: Router.goto(GALLERY),
			"EnemyGallery", TILE))


func on_back() -> void:
	Router.goto_main_menu()

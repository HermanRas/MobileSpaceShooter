extends Control
## Settings (PLAN.md 6.1, filled out in 6.4): for now the Controls panel the flight sandbox
## opens, over the menu backdrop, and the Sound test (14.1) under it. Back (the gesture, or Esc)
## goes to the main menu.

const SOUND_TEST := "res://scenes/menu/sound_test.tscn"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(MenuBackdrop.new())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	center.add_child(column)
	var panel := ControlsPanel.new()
	panel.name = "Controls"
	column.add_child(panel)
	var sounds := MenuKit.button("Sound test", func() -> void: Router.goto(SOUND_TEST), Vector2(220, 56))
	sounds.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(sounds)


func on_back() -> void:
	Router.goto_main_menu()

extends Control
## Settings (PLAN.md 6.1, filled out in 6.4): for now the Controls panel the flight sandbox
## opens, over the menu backdrop. Back (the gesture, or Esc) goes to
## the main menu.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(MenuBackdrop.new())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := ControlsPanel.new()
	panel.name = "Controls"
	center.add_child(panel)


func on_back() -> void:
	Router.goto_main_menu()

extends Control
## Settings (PLAN.md 6.1, filled out in 6.4): for now the Controls panel the flight sandbox
## opens, over the menu backdrop. Done or the back button goes back to the main menu.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(MenuBackdrop.new())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := ControlsPanel.new()
	panel.name = "Controls"
	panel.closed.connect(on_back)
	center.add_child(panel)


func on_back() -> void:
	Router.goto_main_menu()

class_name ConfirmPanel
extends ColorRect
## "Are you sure?" over a dimmed screen (PLAN.md 6.2, 6.5): a question, Cancel, and a button
## that does it. Used before deleting a pilot and before quitting. Runs while paused.

var _text := Label.new()
var _yes := Button.new()
var _action := Callable()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	color = Color(0, 0, 0, 0.7)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ChromePanel"
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 20)
	panel.add_child(column)
	_text.add_theme_font_size_override(&"font_size", 24)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_text)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	buttons.add_child(MenuKit.button("Cancel", close))
	_yes.custom_minimum_size = Vector2(200, 60)
	_yes.add_theme_font_size_override(&"font_size", 22)
	_yes.theme_type_variation = &"DangerButton"
	_yes.pressed.connect(func() -> void:
		close()
		_action.call())
	buttons.add_child(_yes)


## Shows `question`; the button `yes_text` (node `yes_name`) runs `action`.
func ask(question: String, yes_text: String, action: Callable, yes_name := "Confirm") -> void:
	_text.text = question
	_yes.text = yes_text
	_yes.name = yes_name
	_action = action
	visible = true


func close() -> void:
	visible = false

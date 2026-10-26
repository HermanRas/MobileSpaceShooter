extends Control
## The pilots on this device (PLAN.md 6.2, D2): a card each (portrait, name, record) to select,
## edit or delete (after a confirmation), and a New pilot card. Back goes to the main menu.

const CHARACTER := "res://scenes/menu/character.tscn"
const CARD := Vector2(280, 340)
const PORTRAIT := 190.0

var _row := HBoxContainer.new()
var _confirm := ColorRect.new()
var _confirm_text := Label.new()
var _deleting := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(MenuBackdrop.new())
	var frame := MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		frame.add_theme_constant_override("margin_" + side, 40)
	add_child(frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 20)
	frame.add_child(column)
	var bar := HBoxContainer.new()
	column.add_child(bar)
	var title := MenuKit.label("Pilots", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	bar.add_child(MenuKit.button("Back", on_back, Vector2(160, 60)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_row.add_theme_constant_override(&"separation", 16)
	scroll.add_child(_row)
	_build_confirm()
	_refresh()


func on_back() -> void:
	if _confirm.visible:
		_confirm.visible = false
		return
	Router.goto_main_menu()


func _refresh() -> void:
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	for pilot in Profiles.list():
		_row.add_child(_card(pilot))
	var add := MenuKit.tile("+ New pilot", "Name, look and colours", _new_pilot, "NewPilot", CARD)
	_row.add_child(add)


func _card(pilot: ProfileRecord) -> Control:
	var chosen := pilot.id == Profiles.selected_id
	var panel := PanelContainer.new()
	panel.name = "Pilot_" + pilot.id
	panel.custom_minimum_size = CARD
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.1, 0.92)
	style.border_color = ProfileCard.FRAME if chosen else Color(1, 1, 1, 0.15)
	style.set_border_width_all(3 if chosen else 1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override(&"panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	panel.add_child(column)
	var portrait := PortraitView.new()
	portrait.character = pilot.character
	portrait.custom_minimum_size = Vector2(0, PORTRAIT)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(portrait)
	var name_label := MenuKit.label(pilot.name, 26)
	name_label.clip_text = true
	column.add_child(name_label)
	var stats := pilot.stats
	column.add_child(MenuKit.label("Best %s  ·  K %d / D %d" % [ProfileCard.clock(int(stats["best_wave_s"])), int(stats["kills"]),
			int(stats["deaths"])], 16, Color(1, 1, 1, 0.65)))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 6)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	var select := MenuKit.button("Selected" if chosen else "Select", Callable() if chosen else _select.bind(pilot.id),
			Vector2(96, 52), 18)
	select.name = "Select"
	buttons.add_child(select)
	buttons.add_child(MenuKit.button("Edit", _edit.bind(pilot.id), Vector2(70, 52), 18))
	var delete := MenuKit.button("Delete", _ask_delete.bind(pilot.id), Vector2(80, 52), 18)
	delete.add_theme_color_override(&"font_color", Color(1.0, 0.5, 0.45))
	buttons.add_child(delete)
	return panel


func _select(id: String) -> void:
	Profiles.select(id)
	_refresh()


func _edit(id: String) -> void:
	Profiles.editing_id = id
	Router.goto(CHARACTER)


func _new_pilot() -> void:
	Profiles.editing_id = ""
	Router.goto(CHARACTER)


func _ask_delete(id: String) -> void:
	_deleting = id
	_confirm_text.text = "Delete %s?\nTheir ship, parts and progress are gone for good." % Profiles.record(id).name
	_confirm.visible = true


func _build_confirm() -> void:
	_confirm.name = "ConfirmDelete"
	_confirm.color = Color(0, 0, 0, 0.7)
	_confirm.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.visible = false
	add_child(_confirm)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1)
	style.border_color = Color(1.0, 0.5, 0.45)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override(&"panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 20)
	panel.add_child(column)
	_confirm_text.add_theme_font_size_override(&"font_size", 24)
	_confirm_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_confirm_text)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	buttons.add_child(MenuKit.button("Cancel", func() -> void: _confirm.visible = false))
	var yes := MenuKit.button("Delete", _delete)
	yes.name = "DeleteConfirm"
	yes.add_theme_color_override(&"font_color", Color(1.0, 0.5, 0.45))
	buttons.add_child(yes)


func _delete() -> void:
	_confirm.visible = false
	Profiles.delete(_deleting)
	_refresh()

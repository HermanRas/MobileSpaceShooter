class_name LibraryPanel
extends PanelContainer
## The ship library screen (Phase 2.6): a grid of thumbnail cards, plus New, Save, Save As,
## Load, Rename and Delete, and Publish, which puts a ship up for sale in every pilot's shop (7.3).
##
## The panel owns the dialogs; the hangar owns the ship being edited and does the actual
## save and load, so this only emits what the player asked for.

signal load_requested(id: String)
signal new_requested
signal save_requested
signal save_as_requested(new_name: String)
signal publish_requested(id: String, on: bool)

const CARD := Vector2(180, 232)
const FOR_SALE := Color(1, 0.85, 0.5)

var library: BlueprintLibrary

var _grid := GridContainer.new()
var _selected_id: String = ""
var _load_button: Button
var _rename_button: Button
var _delete_button: Button
var _publish_button: Button
var _note := Label.new()
## The listed ships by id, as BlueprintLibrary.list() gives them.
var _entries := {}
var _name_dialog := AcceptDialog.new()
var _name_edit := LineEdit.new()
var _name_action: Callable
var _confirm := ConfirmationDialog.new()


func _ready() -> void:
	# The offsets have to be reset too; anchors alone left the panel collapsed to its minimum.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme_type_variation = &"ChromePanel"
	var column := VBoxContainer.new()
	add_child(column)

	var bar := HBoxContainer.new()
	column.add_child(bar)
	var title := Label.new()
	title.text = "Ships"
	title.add_theme_font_size_override(&"font_size", 28)
	bar.add_child(title)
	_note.add_theme_color_override(&"font_color", FOR_SALE)
	_note.add_theme_font_size_override(&"font_size", 18)
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bar.add_child(_note)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_button(bar, "New", func() -> void: new_requested.emit())
	_button(bar, "Save", func() -> void: save_requested.emit())
	_button(bar, "Save As", func() -> void: _ask_name("Save as", "", func(text: String) -> void: save_as_requested.emit(text)))
	_load_button = _button(bar, "Load", func() -> void: load_requested.emit(_selected_id))
	_rename_button = _button(bar, "Rename", _rename_selected)
	_publish_button = _button(bar, "Publish", func() -> void:
		publish_requested.emit(_selected_id, not _entries.get(_selected_id, {}).get("published", false)))
	_publish_button.name = "Publish"
	_delete_button = _button(bar, "Delete", func() -> void:
		_confirm.dialog_text = "Delete this ship? This can't be undone."
		_confirm.popup_centered())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_grid.columns = 7
	scroll.add_child(_grid)

	_name_edit.custom_minimum_size = Vector2(360, 48)
	_name_dialog.add_child(_name_edit)
	_name_dialog.register_text_enter(_name_edit)
	_name_dialog.confirmed.connect(func() -> void:
		var text := _name_edit.text.strip_edges()
		if not text.is_empty():
			_name_action.call(text))
	add_child(_name_dialog)
	_confirm.confirmed.connect(func() -> void:
		library.delete(_selected_id)
		_selected_id = ""
		refresh())
	add_child(_confirm)


func refresh() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_entries.clear()
	for entry in library.list():
		_entries[entry["id"]] = entry
		_grid.add_child(_card(entry))
	_update_buttons()


func _card(entry: Dictionary) -> Control:
	var card := Button.new()
	card.custom_minimum_size = CARD
	card.toggle_mode = true
	card.button_pressed = entry["id"] == _selected_id
	card.tooltip_text = entry["id"]
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var picture := TextureRect.new()
	picture.custom_minimum_size = Vector2(CARD.x, CARD.x - 20)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := library.thumbnail_path(entry["id"])
	if FileAccess.file_exists(path):
		picture.texture = ImageTexture.create_from_image(Image.load_from_file(path))
	column.add_child(picture)
	var label := Label.new()
	label.text = "%s  (%d)" % [entry["name"], entry["tiles"]]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(label)
	var byline := Label.new()
	byline.text = ("For sale · " if entry["published"] else "") + ("by %s" % entry["author"] if entry["author"] != "" else "")
	byline.add_theme_font_size_override(&"font_size", 14)
	byline.add_theme_color_override(&"font_color", FOR_SALE if entry["published"] else Color(1, 1, 1, 0.6))
	byline.add_theme_color_override(&"font_outline_color", UiTheme.TEXT_OUTLINE)
	byline.add_theme_constant_override(&"outline_size", UiTheme.OUTLINE_PX)
	byline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	byline.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	byline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(byline)
	card.pressed.connect(func() -> void:
		_selected_id = entry["id"]
		for other in _grid.get_children():
			(other as Button).button_pressed = other == card
		_update_buttons())
	return card


func _rename_selected() -> void:
	var bp := library.load_ship(_selected_id)
	if bp == null:
		return
	_ask_name("Rename", bp.name, func(text: String) -> void:
		library.rename(_selected_id, text)
		refresh())


func _ask_name(title: String, current: String, action: Callable) -> void:
	_name_dialog.title = title
	_name_edit.text = current
	_name_action = action
	_name_dialog.popup_centered()
	_name_edit.grab_focus()
	_name_edit.select_all()


func _update_buttons() -> void:
	var has := not _selected_id.is_empty() and library.has(_selected_id)
	_load_button.disabled = not has
	_rename_button.disabled = not has
	_delete_button.disabled = not has
	_publish_button.disabled = not has
	_publish_button.text = "Unpublish" if has and _entries.get(_selected_id, {}).get("published", false) else "Publish"


## A line beside the title: what Publish did, or why it didn't.
func show_note(text: String) -> void:
	_note.text = text


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(110, 56)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

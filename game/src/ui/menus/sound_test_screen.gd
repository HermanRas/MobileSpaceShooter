extends Control
## Sound test (PLAN.md 14.1): every sound and track in `data/audio.json`, a button each, so the
## owner can hear them on the phone and say which to swap. Opened from Settings. A loop plays
## until its button is tapped again; a track plays until another is picked.

const SETTINGS := "res://scenes/menu/settings.tscn"
const COLUMNS := 4
const BUTTON_SIZE := Vector2(250, 56)

var _loops := {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(MenuBackdrop.new())
	var frame := MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		frame.add_theme_constant_override("margin_" + side, 32)
	add_child(frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 10)
	frame.add_child(column)
	var bar := HBoxContainer.new()
	column.add_child(bar)
	var title := MenuKit.label("Sound test", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	bar.add_child(title)
	bar.add_child(MenuKit.button("Back", on_back, Vector2(160, 56)))

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 8)
	scroll.add_child(body)

	var music := _section(body, "Music")
	for id: StringName in Audio.bank.music:
		music.add_child(_button(String(id), func() -> void: Audio.play_music(id)))
	music.add_child(_button("(silence)", func() -> void: Audio.play_music(&"")))
	var groups := {}
	var ids: Array = Audio.bank.entries.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for id: StringName in ids:
		var group := String(id).get_slice(".", 0)
		if not groups.has(group):
			groups[group] = _section(body, group.capitalize())
		var button := _button(String(id), Callable() if Audio.bank.entry(id).loop else Audio.play_sfx.bind(id))
		button.name = String(id).replace(".", "_")
		if Audio.bank.entry(id).loop:
			button.disabled = false
			button.pressed.connect(_toggle_loop.bind(id, button))
		groups[group].add_child(button)


func on_back() -> void:
	Router.goto(SETTINGS)


func _toggle_loop(id: StringName, button: Button) -> void:
	if _loops.has(id):
		(_loops[id] as Node).queue_free()
		_loops.erase(id)
		button.text = String(id)
		return
	var player := Audio.loop(id, self) as AudioStreamPlayer
	if player == null:
		return
	player.play()
	_loops[id] = player
	button.text = String(id) + "  ■"


func _section(body: VBoxContainer, heading: String) -> GridContainer:
	body.add_child(MenuKit.label(heading, 24, Color(1, 0.85, 0.5)))
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	body.add_child(grid)
	return grid


## A test button: it plays its own sound, without the usual click on top.
func _button(text: String, action: Callable) -> Button:
	var button := MenuKit.button(text, action, BUTTON_SIZE, 18)
	button.set_meta(&"clicks", true)
	return button

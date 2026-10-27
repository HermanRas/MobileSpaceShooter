extends Control
## The UI chrome up close (A.5): every UiTheme piece at the sizes the screens use, over the
## arena's background colour. `tools/preview.sh res://dev_preview/art_chrome.tscn 1560x720`


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#020b15"))
	var row := HBoxContainer.new()
	row.position = Vector2(24, 24)
	row.add_theme_constant_override(&"separation", 24)
	add_child(row)

	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ChromePanel"
	panel.custom_minimum_size = Vector2(460, 0)
	row.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	panel.add_child(column)
	var header := PanelContainer.new()
	header.theme_type_variation = &"HeaderPanel"
	header.add_child(MenuKit.label("Hangar", 30))
	column.add_child(header)
	column.add_child(MenuKit.label("A dialog on the chrome panel", 22))
	column.add_child(MenuKit.button("Free flight", func() -> void: pass, Vector2(380, 64), 24))
	var go := MenuKit.button("Test fight", func() -> void: pass, Vector2(380, 64), 24)
	go.theme_type_variation = &"GoButton"
	column.add_child(go)
	var danger := MenuKit.button("Delete pilot", func() -> void: pass, Vector2(380, 64), 24)
	danger.theme_type_variation = &"DangerButton"
	column.add_child(danger)
	column.add_child(MenuKit.button("Locked", Callable(), Vector2(380, 64), 24))
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(380, 48)
	slider.value = 40
	column.add_child(slider)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(380, 24)
	bar.value = 65
	bar.show_percentage = false
	column.add_child(bar)

	var side := VBoxContainer.new()
	side.add_theme_constant_override(&"separation", 16)
	row.add_child(side)
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"FramePanel"
	frame.custom_minimum_size = Vector2(240, 240)
	var picture := ColorRect.new()
	picture.color = Color(0.2, 0.35, 0.55)
	frame.add_child(picture)
	side.add_child(frame)
	var tabs := HBoxContainer.new()
	for text in ["Hull", "Weapons", "Paint"]:
		var tab := MenuKit.button(text, func() -> void: pass, Vector2(150, 56), 20)
		tab.toggle_mode = true
		tab.button_pressed = text == "Weapons"
		tabs.add_child(tab)
	side.add_child(tabs)
	side.add_child(MenuKit.button("Fly", func() -> void: pass, Vector2(110, 56), 20))
	var tile := MenuKit.tile("WaveTime", "Endless waves", func() -> void: pass, "Tile", Vector2(300, 180))
	side.add_child(tile)

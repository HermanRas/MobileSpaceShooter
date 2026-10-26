class_name WeaponPicker
extends PanelContainer
## SWITCH (PLAN.md 4.7): the game pauses and this lists the ship's manual weapons, one card each
## with its icon and how many the ship carries. Picking one makes it what FIRE fires and resumes.
## It runs while the tree is paused (process_mode ALWAYS); whoever opens it pauses and resumes.

signal picked(weapon_id: StringName)
signal closed

const CARD := Vector2(150, 130)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.05, 0.06, 0.09, 0.95)
	background.set_content_margin_all(20)
	background.set_corner_radius_all(8)
	add_theme_stylebox_override(&"panel", background)


## Lists `gunnery`'s manual weapons, the active one marked.
func open(gunnery: Gunnery) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 14)
	add_child(column)
	var title := Label.new()
	title.text = "Choose the weapon FIRE fires"
	title.add_theme_font_size_override(&"font_size", 24)
	column.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	column.add_child(row)
	for weapon_id in gunnery.manual_weapons():
		var gun: GunLayout.Gun = gunnery.layout.guns.filter(func(g: GunLayout.Gun) -> bool: return g.weapon == weapon_id)[0]
		var card := Button.new()
		card.name = String(weapon_id)
		card.custom_minimum_size = CARD
		card.toggle_mode = true
		card.button_pressed = weapon_id == gunnery.active
		card.pressed.connect(func() -> void: picked.emit(weapon_id))
		var icon := _Icon.new()
		icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		icon.custom_minimum_size = Vector2(0, CARD.y - 40)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		var label := Label.new()
		label.text = "%s ×%d" % [gun.stats["name"], gunnery.manual_count(weapon_id)]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		label.offset_top = -36
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(label)
		row.add_child(card)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(160, 56)
	back.pressed.connect(func() -> void: closed.emit())
	column.add_child(back)


## A gun from above, as the hangar's palette draws it.
class _Icon extends Control:
	func _draw() -> void:
		var points := PackedVector2Array()
		for p: Vector2 in HangarPalette.GUN:
			points.append(size * 0.5 + p * minf(size.x, size.y) * 0.6)
		draw_colored_polygon(points, Color(0.55, 0.6, 0.66))
		draw_polyline(points + PackedVector2Array([points[0]]), Color(0, 0, 0, 0.8), 2.0, true)

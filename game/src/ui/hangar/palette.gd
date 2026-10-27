class_name HangarPalette
extends PanelContainer
## The tile palette (Phase 2.2): type tabs, a row of shapes to drag out, and the S/M/L size.
##
## Pressing a shape emits `drag_started`; from then on the hangar controller follows the finger
## and handles the release, so the palette doesn't need to know where the tile lands.
##
## The tabs sit under the shapes on purpose. Android keeps the bottom strip of the screen for
## its home gesture even in immersive mode (130 px on the reference phone, ~78 canvas px), and a
## drag that starts there sends the game to the background. Taps there are fine, so the
## tap-only tabs fill that strip and every drag starts above it.

signal drag_started(type: StringName, shape: StringName, size: StringName)
signal thruster_drag_started(type_id: StringName, size: StringName, level: int)
signal weapon_drag_started(weapon_id: StringName, mount_type: StringName, mode: StringName)
## Creative: the level slider moved (new guns, and the selected one, go to it).
signal gun_level_changed(level: int)
## A loose part from the Inventory tab: a mount without a place, with `"gun": <item id>` for a
## gun or `"stock": true` for a thruster.
signal stock_drag_started(part: Dictionary)

const TYPES: Array[StringName] = [&"hull", &"armor", &"shield", &"hardpoint"]
const TYPE_COLORS := {
	&"hull": Color(0.55, 0.59, 0.63), &"armor": Color(0.45, 0.38, 0.27),
	&"shield": Color(0.25, 0.5, 0.78), &"hardpoint": Color(0.24, 0.26, 0.29),
}
## The tab for thrusters (Phase 3.2); its row holds thruster types and L1-3 instead of shapes.
const THRUSTERS := &"thrusters"
## The tab for guns (Phase 4.3): a button that steps through the gun families (Guns, Rockets,
## Special; 4.6b), that family's guns, then the mount type and the fire mode.
const WEAPONS := &"weapons"
## The tab for loose guns and thrusters (Phase 4.8a), only outside Creative. Its row holds a
## card per loose gun (level and XP bar) and per kind of loose thruster (× count), and a button
## that picks the mount type a gun goes on (another than it had is a paid refit).
const INVENTORY := &"inventory"
const CARDS_PER_PAGE := 9
## A nozzle, wide end up against the hull, for the thruster swatches.
const NOZZLE := [Vector2(-0.5, -0.25), Vector2(0.5, -0.25), Vector2(0.35, 0.25), Vector2(-0.35, 0.25)]
## A gun from above: a round base with a barrel to the right, for the gun swatches.
const GUN := [Vector2(-0.35, -0.3), Vector2(0.1, -0.3), Vector2(0.1, -0.08), Vector2(0.65, -0.08),
		Vector2(0.65, 0.08), Vector2(0.1, 0.08), Vector2(0.1, 0.3), Vector2(-0.35, 0.3)]
const BUTTON := Vector2(76, 76)
## At least the phone's bottom gesture strip, in canvas pixels (see the note above).
const GESTURE_STRIP := 80.0

var shapes: ShapeLib
var thrusters: ThrusterLib
var weapons: WeaponLib
var mount_type: StringName = &"turret"
var family := ""
var mode: StringName = &"auto"
var type: StringName = &"hull"
var tile_size: StringName = &"L"
var level: int = 1
## Creative: the level new guns get (7.1), L1 to the XP curve's top.
var gun_level: int = 1
## The profile's stock and the ship it's building (for which guns are loose); null in Creative.
var stock: Inventory
var ship: Blueprint
## The mount type an inventory gun goes on, or &"" for the one it had.
var refit_to: StringName = &""
var _page := 0

var _shape_row := HBoxContainer.new()
var _size_buttons: Array[Button] = []


func _ready() -> void:
	var column := VBoxContainer.new()
	add_child(column)
	column.add_child(_shape_row)
	var tabs := HBoxContainer.new()
	column.add_child(tabs)
	var type_group := ButtonGroup.new()
	var tab_ids: Array[StringName] = []
	tab_ids.assign(TYPES + [THRUSTERS, WEAPONS])
	if stock != null:
		tab_ids.append(INVENTORY)
	for tile_type: StringName in tab_ids:
		var tab := Button.new()
		tab.text = String(tile_type).capitalize()
		tab.toggle_mode = true
		tab.button_group = type_group
		tab.button_pressed = tile_type == type
		tab.custom_minimum_size = Vector2(120, GESTURE_STRIP)
		tab.toggled.connect(func(on: bool) -> void:
			if on:
				type = tile_type
				_refresh_shapes())
		tabs.add_child(tab)
	tabs.add_child(_spacer())
	var size_group := ButtonGroup.new()
	for size_code: StringName in [&"S", &"M", &"L"]:
		var size_button := Button.new()
		size_button.text = String(size_code)
		size_button.toggle_mode = true
		size_button.button_group = size_group
		size_button.button_pressed = size_code == tile_size
		size_button.custom_minimum_size = Vector2(72, GESTURE_STRIP)
		size_button.toggled.connect(func(on: bool) -> void:
			if on:
				tile_size = size_code
				_refresh_shapes())
		tabs.add_child(size_button)
		_size_buttons.append(size_button)
	_refresh_shapes()


func _refresh_shapes() -> void:
	for child in _shape_row.get_children():
		child.queue_free()
	for size_button in _size_buttons:
		size_button.visible = type != WEAPONS and type != INVENTORY  # guns come in one size
	if type == INVENTORY:
		_stock_row()
		return
	if type == THRUSTERS:
		_thruster_row()
		return
	if type == WEAPONS:
		_weapon_row()
		return
	for shape_id in shapes.shape_ids():
		var swatch := _ShapeSwatch.new()
		swatch.custom_minimum_size = BUTTON
		swatch.polygon = shapes.polygon(shape_id, &"L", 0)
		swatch.fill = TYPE_COLORS.get(type, Color.GRAY)
		swatch.mesh = ShipMesh.swatch_mesh(swatch.polygon, type, HangarEditor.DEFAULT_PAINT)
		swatch.scale_hint = {&"S": 0.45, &"M": 0.7, &"L": 1.0}[tile_size]
		swatch.tooltip_text = String(shape_id)
		swatch.gui_input.connect(func(event: InputEvent) -> void:
			if _is_press(event):
				drag_started.emit(type, shape_id, tile_size)
				accept_event())
		_shape_row.add_child(swatch)


func _thruster_row() -> void:
	var tints: Dictionary = Assets.meta(ShipMesh.ATLAS_ID).get("thruster_tints", {})
	for type_id in thrusters.type_ids():
		var swatch := _ShapeSwatch.new()
		swatch.custom_minimum_size = Vector2(96, BUTTON.y)
		swatch.polygon = PackedVector2Array(NOZZLE)
		swatch.fill = Color.from_string(str(tints.get(String(type_id), "#888888")), Color.GRAY)
		swatch.mesh = _nozzle(type_id, level)
		swatch.scale_hint = {&"S": 0.45, &"M": 0.7, &"L": 1.0}[tile_size]
		swatch.caption = thrusters.display_name(type_id)
		swatch.tooltip_text = String(type_id)
		if stock != null:
			swatch.corner = "%d GC" % thrusters.spec(type_id, tile_size, level)["price_gc"]
		swatch.gui_input.connect(func(event: InputEvent) -> void:
			if _is_press(event):
				thruster_drag_started.emit(type_id, tile_size, level)
				accept_event())
		_shape_row.add_child(swatch)
	_shape_row.add_child(_spacer())
	var level_group := ButtonGroup.new()
	for n in range(1, 4):
		var level_button := Button.new()
		level_button.text = "L%d" % n
		level_button.toggle_mode = true
		level_button.button_group = level_group
		level_button.button_pressed = n == level
		level_button.custom_minimum_size = Vector2(64, BUTTON.y)
		level_button.toggled.connect(func(on: bool) -> void:
			if on:
				level = n
				if stock != null:
					_refresh_shapes())  # the prices
		_shape_row.add_child(level_button)


func _weapon_row() -> void:
	var families := weapons.families()
	if not families.has(family):
		family = families[0] if not families.is_empty() else ""
	var family_button := Button.new()
	family_button.text = family + " ▸"
	family_button.custom_minimum_size = Vector2(110, BUTTON.y)
	family_button.pressed.connect(func() -> void:
		family = families[(families.find(family) + 1) % families.size()]
		_refresh_shapes())
	_shape_row.add_child(family_button)
	for weapon_id in weapons.weapon_ids():
		if weapons.weapon(weapon_id)["family"] != family:
			continue
		var swatch := _ShapeSwatch.new()
		swatch.custom_minimum_size = Vector2(90, BUTTON.y)
		swatch.polygon = PackedVector2Array(GUN)
		swatch.fill = Color(0.35, 0.38, 0.42)
		swatch.weapon = weapon_id
		swatch.mount = mount_type
		swatch.caption = weapons.weapon(weapon_id)["name"]
		swatch.tooltip_text = String(weapon_id)
		swatch.disabled = not weapons.allows(weapon_id, mount_type)
		if stock != null:
			swatch.corner = "%d GC" % weapons.weapon(weapon_id)["price_gc"]
		swatch.gui_input.connect(func(event: InputEvent) -> void:
			if _is_press(event) and weapons.allows(weapon_id, mount_type):
				weapon_drag_started.emit(weapon_id, mount_type, weapons.mode_for(mount_type, mode))
				accept_event())
		_shape_row.add_child(swatch)
	_shape_row.add_child(_spacer())
	var mount_group := ButtonGroup.new()
	for each: StringName in WeaponLib.MOUNT_TYPES:
		var button := _toggle(weapons.mount_type(each)["name"], each == mount_type, mount_group)
		button.toggled.connect(func(on: bool) -> void:
			if on:
				mount_type = each
				_refresh_shapes())
	var mode_group := ButtonGroup.new()
	var modes: Array = weapons.mount_type(mount_type)["modes"]
	for each: StringName in WeaponLib.MODES:
		var button := _toggle(String(each).capitalize(), each == weapons.mode_for(mount_type, mode), mode_group)
		button.disabled = not modes.has(each)
		button.toggled.connect(func(on: bool) -> void:
			if on:
				mode = each)
	if stock == null:
		_shape_row.add_child(_spacer())
		_shape_row.add_child(_gun_level_slider())


## Creative's gun level: a slider from L1 to the top on a log scale, so the low levels, which
## change the most, get most of its length.
func _gun_level_slider() -> Control:
	var box := HBoxContainer.new()
	var label := Label.new()
	label.text = "L%d" % gun_level
	label.custom_minimum_size = Vector2(70, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var slider := HSlider.new()
	slider.name = "GunLevel"
	slider.min_value = 1
	slider.max_value = weapons.xp.max_level
	slider.exp_edit = true
	slider.step = 1
	slider.value = gun_level
	slider.custom_minimum_size = Vector2(260, BUTTON.y)
	# A drag moves the selected gun once, when it ends, so it's one undo step.
	var dragging := [false]
	slider.drag_started.connect(func() -> void: dragging[0] = true)
	slider.drag_ended.connect(func(_moved: bool) -> void:
		dragging[0] = false
		gun_level_changed.emit(gun_level))
	slider.value_changed.connect(func(value: float) -> void:
		gun_level = int(value)
		label.text = "L%d" % gun_level
		if not dragging[0]:
			gun_level_changed.emit(gun_level))
	box.add_child(label)
	box.add_child(slider)
	return box


## Creative: shows `to` on the slider (a gun was selected) without moving any gun.
func show_gun_level(to: int) -> void:
	if gun_level == to:
		return
	gun_level = to
	_refresh_shapes()


## Shows the stock now (after an edit); the Inventory tab is redrawn if it's open.
func show_stock(new_stock: Inventory, new_ship: Blueprint) -> void:
	stock = new_stock
	ship = new_ship
	if type == INVENTORY:
		_refresh_shapes()


func _stock_row() -> void:
	var cards: Array[Control] = []
	for item in stock.loose_guns(ship):
		var gun := weapons.weapon(item.weapon)
		if gun.is_empty():
			continue
		var swatch := _swatch(PackedVector2Array(GUN), Color(0.35, 0.38, 0.42),
				"%s L%d" % [gun["name"], weapons.xp.level_for(item.xp)])
		swatch.weapon = item.weapon
		swatch.mount = item.mount
		swatch.bar = weapons.xp.progress(item.xp)
		swatch.corner = weapons.mount_type(item.mount).get("name", "")
		swatch.name = item.id
		swatch.gui_input.connect(func(event: InputEvent) -> void:
			if _is_press(event):
				var on := refit_to if refit_to != &"" and weapons.allows(item.weapon, refit_to) else item.mount
				stock_drag_started.emit({"part": WeaponLib.part_id(item.weapon), "mount": String(on),
						"mode": String(weapons.mode_for(on, mode)), "gun": item.id})
				accept_event())
		cards.append(swatch)
	var tints: Dictionary = Assets.meta(ShipMesh.ATLAS_ID).get("thruster_tints", {})
	var keys: Array = stock.thrusters.keys()
	keys.sort()
	for key: String in keys:
		var parts := Inventory.thruster_parts(key)
		var swatch := _swatch(PackedVector2Array(NOZZLE), Color.from_string(str(tints.get(String(parts[0]), "#888888")), Color.GRAY),
				"%s %s L%d" % [thrusters.display_name(parts[0]), parts[1], parts[2]])
		swatch.scale_hint = {&"S": 0.45, &"M": 0.7, &"L": 1.0}[parts[1]]
		swatch.mesh = _nozzle(parts[0], parts[2])
		swatch.corner = "×%d" % stock.thrusters[key]
		swatch.name = key.replace(":", "_")
		swatch.gui_input.connect(func(event: InputEvent) -> void:
			if _is_press(event):
				stock_drag_started.emit({"part": ThrusterLib.part_id(parts[0]), "size": String(parts[1]),
						"level": parts[2], "stock": true})
				accept_event())
		cards.append(swatch)
	if cards.is_empty():
		var empty := Label.new()
		empty.text = "Nothing loose. Guns and thrusters you take off the ship land here."
		empty.custom_minimum_size = Vector2(0, BUTTON.y)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_shape_row.add_child(empty)
	var pages := maxi(ceili(cards.size() / float(CARDS_PER_PAGE)), 1)
	_page = clampi(_page, 0, pages - 1)
	if pages > 1:
		_page_button("◂", -1, pages)
	for i in range(_page * CARDS_PER_PAGE, mini((_page + 1) * CARDS_PER_PAGE, cards.size())):
		_shape_row.add_child(cards[i])
	for i in cards.size():
		if cards[i].get_parent() == null:
			cards[i].free()
	if pages > 1:
		_page_button("▸", 1, pages)
	_shape_row.add_child(_spacer())
	var refit := Button.new()
	refit.text = "Mount: %s ▸" % ("as was" if refit_to == &"" else weapons.mount_type(refit_to)["name"])
	refit.custom_minimum_size = Vector2(170, BUTTON.y)
	refit.pressed.connect(func() -> void:
		var options: Array[StringName] = [&""]
		options.append_array(WeaponLib.MOUNT_TYPES)
		refit_to = options[(options.find(refit_to) + 1) % options.size()]
		_refresh_shapes())
	_shape_row.add_child(refit)


## A nozzle of `type_id` at `level`, one unit long, flange up (as NOZZLE), for a swatch.
func _nozzle(type_id: StringName, level: int) -> ArrayMesh:
	return ShipMesh.nozzle_mesh(type_id, {"center": Vector2(0, -0.25), "normal": Vector2.DOWN, "length": 1.0,
			"depth": thrusters.depth_factor}, level)


func _swatch(polygon: PackedVector2Array, fill: Color, caption: String) -> _ShapeSwatch:
	var swatch := _ShapeSwatch.new()
	swatch.custom_minimum_size = Vector2(96, BUTTON.y)
	swatch.polygon = polygon
	swatch.fill = fill
	swatch.caption = caption
	return swatch


func _page_button(text: String, step: int, pages: int) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(48, BUTTON.y)
	button.pressed.connect(func() -> void:
		_page = posmod(_page + step, pages)
		_refresh_shapes())
	_shape_row.add_child(button)


func _toggle(text: String, on: bool, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	button.button_pressed = on
	button.custom_minimum_size = Vector2(88, BUTTON.y)
	_shape_row.add_child(button)
	return button


static func _is_press(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT


func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer


## A palette cell that shows its part: a gun's picture (`weapon` on `mount`, GunView.draw_icon),
## or `mesh` (a tile or a nozzle, ShipMesh) in the ship's material, scaled as `polygon` would be;
## without the art, `polygon` filled with `fill`.
class _ShapeSwatch extends PanelContainer:
	static var _ship_material: ShaderMaterial

	var polygon: PackedVector2Array
	var fill: Color
	var scale_hint: float = 1.0
	var weapon: StringName = &""
	var mount: StringName = &"turret"
	var mesh: Mesh
	var caption: String = ""
	## Small text in the top-left corner (a price, a mount type, a count).
	var corner: String = ""
	## An XP bar along the top (0..1), or none when negative.
	var bar := -1.0
	var disabled := false
	var _mesh_view: MeshInstance2D

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if mesh == null or not Assets.has_real_art(ShipMesh.ATLAS_ID):
			return
		if _ship_material == null:
			_ship_material = ShipMesh.make_material()
		_mesh_view = MeshInstance2D.new()
		_mesh_view.mesh = mesh
		_mesh_view.material = _ship_material
		_mesh_view.modulate.a = 0.35 if disabled else 1.0
		add_child(_mesh_view)
		resized.connect(_place_mesh)
		_place_mesh()

	func _place_mesh() -> void:
		_mesh_view.position = size * 0.5
		_mesh_view.scale = Vector2.ONE * _px_per_u() / ShipMesh.PX_PER_U

	## How big a unit of `polygon` is drawn, so the part fills the cell as its size says.
	func _px_per_u() -> float:
		var extent := 0.0
		for p in polygon:
			extent = maxf(extent, maxf(absf(p.x), absf(p.y)))
		return (minf(size.x, size.y) * 0.4 / maxf(extent, 0.01)) * scale_hint

	func _draw() -> void:
		var side := minf(size.x, size.y)
		var icon := Rect2((size - Vector2.ONE * side) * 0.5, Vector2.ONE * side)
		var art := _mesh_view != null or (weapon != &"" and GunView.draw_icon(self, weapon, mount, icon,
				0.35 if disabled else 1.0))
		if not art:
			var s := _px_per_u()
			var points := PackedVector2Array()
			for p in polygon:
				points.append(size * 0.5 + p * s)
			draw_colored_polygon(points, Color(fill, 0.35) if disabled else fill)
			draw_polyline(points + PackedVector2Array([points[0]]), Color(0, 0, 0, 0.8), 2.0, true)
		if not caption.is_empty():
			var font := get_theme_default_font()
			var font_size := 14
			while font_size > 9 and font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > size.x - 4:
				font_size -= 1
			draw_string(font, Vector2(0, size.y - 6), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size)
		if not corner.is_empty():
			draw_string(get_theme_default_font(), Vector2(4, 16), corner, HORIZONTAL_ALIGNMENT_LEFT, size.x - 8, 12,
					Color(1, 0.85, 0.5))
		if bar >= 0.0:
			draw_rect(Rect2(4, 20, size.x - 8, 4), Color(1, 1, 1, 0.15))
			draw_rect(Rect2(4, 20, (size.x - 8) * clampf(bar, 0.0, 1.0), 4), Color(0.45, 0.85, 1.0))

class_name FlightControls
extends Control
## The on-screen flight controls (PLAN.md 4.7, Phase 3.4), laid out from Settings:
##   2-stick: the floating stick on one side, FIRE and SWITCH on the other.
##   1-stick: the stick only; every weapon fires on its own (Phase 4).
##   left_handed swaps the sides. stick_size and stick_opacity apply to everything.
## Keyboard and gamepad work alongside (move_*, fire, switch_weapon).
##
## Weapons arrive in Phase 4: until then FIRE and SWITCH only report themselves.

signal switch_pressed

## The share of the screen's width where a touch starts the stick.
const STICK_ZONE := 0.4
## FIRE's diameter at stick size 1, and SWITCH's; canvas pixels.
const FIRE_SIZE := 150.0
const SWITCH_SIZE := 96.0
const MARGIN := 40.0
## Keeps FIRE and SWITCH above Android's bottom gesture strip (see HangarPalette).
const BOTTOM_CLEAR := 80.0

var stick := TouchStick.new()
var fire := TouchButton.new()
var switch_button := TouchButton.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stick.name = "Stick"
	fire.name = "Fire"
	fire.text = "FIRE"
	switch_button.name = "Switch"
	switch_button.text = "SWITCH"
	switch_button.pressed.connect(func() -> void: switch_pressed.emit())
	for pair: Array in [[fire, &"vis.icon.fire"], [switch_button, &"vis.icon.switch"]]:
		if Assets.has_real_art(pair[1]):
			(pair[0] as TouchButton).icon = Assets.tex(pair[1])
			(pair[0] as TouchButton).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(stick)
	add_child(fire)
	add_child(switch_button)
	Settings.changed.connect(func(_key: StringName) -> void: apply_settings())
	resized.connect(apply_settings)
	apply_settings()


## World-space stick: the touch stick while a thumb is on it, else keyboard or gamepad.
func stick_value() -> Vector2:
	return stick.value if stick.is_active() \
			else Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")


func is_firing() -> bool:
	return (fire.visible and fire.held) or Input.is_action_pressed(&"fire")


func apply_settings() -> void:
	var two_stick: bool = Settings.get_value(&"control_scheme") == "2-stick"
	var left_handed: bool = Settings.get_value(&"left_handed")
	var scale: float = clampf(float(Settings.get_value(&"stick_size")), 0.5, 2.0)
	var opacity: float = clampf(float(Settings.get_value(&"stick_opacity")), 0.1, 1.0)
	stick.reset()
	fire.reset()
	switch_button.reset()

	# The stick's zone: the left (or right) STICK_ZONE of the screen, full height.
	stick.anchor_top = 0.0
	stick.anchor_bottom = 1.0
	stick.anchor_left = 1.0 - STICK_ZONE if left_handed else 0.0
	stick.anchor_right = 1.0 if left_handed else STICK_ZONE
	stick.offset_left = 0.0
	stick.offset_right = 0.0
	stick.offset_top = 0.0
	stick.offset_bottom = 0.0
	stick.size_scale = scale
	stick.opacity = opacity

	fire.visible = two_stick
	switch_button.visible = two_stick
	var fire_d := FIRE_SIZE * scale
	var switch_d := SWITCH_SIZE * scale
	var fire_center := Vector2(size.x - MARGIN - fire_d * 0.5, size.y - BOTTOM_CLEAR - fire_d * 0.5)
	var switch_center := fire_center + Vector2(-fire_d * 0.5 - switch_d * 0.6, -fire_d * 0.35)
	if left_handed:
		fire_center.x = size.x - fire_center.x
		switch_center.x = size.x - switch_center.x
	_place(fire, fire_center, fire_d, opacity)
	_place(switch_button, switch_center, switch_d, opacity)


func _place(button: TouchButton, center: Vector2, diameter: float, opacity: float) -> void:
	button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	button.size = Vector2(diameter, diameter)
	button.position = center - button.size * 0.5
	button.fill = Color(1, 1, 1, 0.18 * opacity / 0.6)
	button.outline = Color(1, 1, 1, opacity)
	button.queue_redraw()

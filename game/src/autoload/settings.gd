extends Node
## Device-wide settings, saved to `user://settings.json`, plus the input actions.
##
## Input actions are registered here in code rather than in project.godot, so the bindings
## stay readable and reviewable in one place.

signal changed(key: StringName)

const PATH := "user://settings.json"
const FORMAT := 1

const DEFAULTS := {
	"control_scheme": "2-stick",
	"left_handed": false,
	"stick_size": 1.0,
	"stick_opacity": 0.6,
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"vibration": true,
	"screen_shake": true,
	"recent_colors": [],
}

## action -> keyboard keycodes. Gamepad bindings are added alongside in _register_inputs().
const KEY_BINDINGS := {
	&"move_up": [KEY_W, KEY_UP],
	&"move_down": [KEY_S, KEY_DOWN],
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"fire": [KEY_SPACE],
	&"switch_weapon": [KEY_Q],
	&"pause": [KEY_ESCAPE, KEY_P],
}

var _values: Dictionary = DEFAULTS.duplicate()


func _ready() -> void:
	_register_inputs()
	var saved := Save.read_json(PATH)
	for key in DEFAULTS:
		if saved.has(key) and typeof(saved[key]) == typeof(DEFAULTS[key]):
			_values[key] = saved[key]


func get_value(key: StringName) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


func set_value(key: StringName, value: Variant) -> void:
	_values[key] = value
	var data := _values.duplicate()
	data["format"] = FORMAT
	Save.write_json(PATH, data)
	changed.emit(key)


func _register_inputs() -> void:
	for action: StringName in KEY_BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for keycode: Key in KEY_BINDINGS[action]:
			var key := InputEventKey.new()
			key.physical_keycode = keycode
			InputMap.action_add_event(action, key)
	_add_axis(&"move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis(&"move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis(&"move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis(&"move_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_button(&"fire", JOY_BUTTON_A)
	_add_button(&"switch_weapon", JOY_BUTTON_Y)
	_add_button(&"pause", JOY_BUTTON_START)


func _add_axis(action: StringName, axis: JoyAxis, direction: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.axis = axis
	motion.axis_value = direction
	InputMap.action_add_event(action, motion)


func _add_button(action: StringName, button: JoyButton) -> void:
	var press := InputEventJoypadButton.new()
	press.button_index = button
	InputMap.action_add_event(action, press)

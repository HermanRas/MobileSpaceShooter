class_name LaunchPanel
extends ColorRect
## Fly, in Creative (PLAN.md 7.2): free flight in the sandbox as before, a test fight (a generated
## encounter at the level on the slider, 1 to the top of data/levels.json), or the performance
## test (7.5). The back gesture closes it (the hangar's on_back). It keeps the level between flights.

## 0 for free flight, FlightSandbox.BENCH for the performance test, else the test fight's level.
signal launched(level: int)

var level := 1
var max_level := 100

var _level_label := MenuKit.label("", 28)
var _slider := HSlider.new()


func _ready() -> void:
	color = Color(0, 0, 0, 0.6)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ChromePanel"
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 16)
	panel.add_child(column)
	column.add_child(MenuKit.label("Fly", 44))
	var size := Vector2(420, 64)
	column.add_child(MenuKit.button("Free flight", func() -> void: launched.emit(0), size, 24))
	column.add_child(_level_label)
	_slider.name = "TestLevel"
	_slider.min_value = 1
	_slider.max_value = max_level
	_slider.step = 1
	_slider.value = level
	_slider.custom_minimum_size = Vector2(420, 56)
	_slider.value_changed.connect(func(value: float) -> void:
		level = int(value)
		_show_level())
	column.add_child(_slider)
	var fight := MenuKit.button("Test fight", func() -> void: launched.emit(level), size, 24)
	fight.theme_type_variation = &"GoButton"
	column.add_child(fight)
	var bench := MenuKit.button("Performance test", func() -> void: launched.emit(FlightSandbox.BENCH), size, 24)
	bench.name = "PerformanceTest"
	column.add_child(bench)
	_show_level()


func open() -> void:
	_slider.max_value = max_level
	_slider.value = clampi(level, 1, max_level)
	visible = true


func _show_level() -> void:
	_level_label.text = "Test fight at level %d" % level

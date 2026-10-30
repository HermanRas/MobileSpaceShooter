class_name LaunchPanel
extends ColorRect
## Fly, in Creative (PLAN.md 7.2): free flight in the sandbox as before, a test fight (a generated
## encounter at the level on the slider, 1 to the top of data/levels.json), or the performance
## test (7.5). In WaveTime (8.1): Start run, or free flight. The back gesture closes it (the
## hangar's on_back). It keeps the level between flights.

## 0 for free flight, FlightSandbox.BENCH for the performance test, FlightSandbox.WAVETIME for a
## WaveTime run, else the test fight's level.
signal launched(level: int)

var level := 1
var max_level := 100

var _level_label := MenuKit.label("", 28)
var _slider := HSlider.new()
## What only Creative offers, and what only WaveTime does.
var _creative: Array[Control] = []
var _run: Button


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
	_run = MenuKit.button("Start run", func() -> void: launched.emit(FlightSandbox.WAVETIME), size, 24)
	_run.name = "StartRun"
	_run.theme_type_variation = &"GoButton"
	column.add_child(_run)
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
	_creative.assign([_level_label, _slider, fight, bench])
	_show_level()


## Creative's choices, or with `wave_time` a run's.
func open(wave_time := false) -> void:
	_slider.max_value = max_level
	_slider.value = clampi(level, 1, max_level)
	for control in _creative:
		control.visible = not wave_time
	_run.visible = wave_time
	visible = true


func _show_level() -> void:
	_level_label.text = "Test fight at level %d" % level

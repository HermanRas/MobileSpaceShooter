extends Node2D
## Phase 4.4's check: how many shots in flight the ProjectilePool can carry (PLAN.md 5.5 budgets
## 600). Shots stream out from the centre at a ring of practice barges, topped up every tick to
## hold each stage's count, and every stage logs its frame rate and the pool's own cost.
## Debug builds reach it from the main menu ("Shot stress test"); back returns to the menu.
##   tools/drive.sh res://dev_preview/drive_shots.tscn      (one ramp on the PC, then quits)
##   tools/android.sh perf                                  (the phone's stage lines)

## The ramp finished once; `results` holds one row per stage.
signal finished

const PX := ShipMesh.PX_PER_U
const STAGES: Array[int] = [150, 300, 600, 900]
const STAGE_S := 10.0
## Each stage's first second is left out of its numbers, while the count settles.
const SETTLE_S := 1.0
const RING_U := 14.0
const BARGES := 8
const SPEED_U := 40.0
const RANGE_U := 24.0

var pool := ProjectilePool.new()
## [{"shots", "fps", "frame_ms", "worst_ms", "step_ms", "step_max_ms", "draw_ms", "dropped"}]
var results: Array[Dictionary] = []

var _stage := 0
var _clock := 0.0
var _angle := 0.0
var _frames := 0
var _frame_usec := 0
var _worst_usec := 0
var _steps := 0
var _step_usec := 0
var _step_max_usec := 0
var _draw_usec := 0
var _last_tick := 0
var _dropped_at_start := 0
var _mask := ShipBody.enemy_mask(0)
var _hud := Label.new()


func _ready() -> void:
	var tiles_table := Data.table(&"tiles")
	var placement := Placement.create(ShapeLib.from_table(Data.table(&"shapes")),
			TileLib.from_table(tiles_table), tiles_table)
	var errors: PackedStringArray = []
	var barge := Blueprint.from_dict(Data.json_dir("enemies")["target_barge"], errors)
	for i in BARGES:
		var at := Vector2.from_angle(TAU * i / BARGES)
		var ship := ShipBody.create(barge, placement)
		ship.team = 1
		ship.position = at * RING_U * PX
		ship.rotation = at.angle()  # the long side faces the centre
		add_child(ship)
	pool.name = "Shots"
	add_child(pool)
	var camera := Camera2D.new()
	camera.zoom = Vector2.ONE * (360.0 / ((RING_U + 3.0) * PX))
	add_child(camera)
	var ui := CanvasLayer.new()
	ui.add_child(_hud)
	_hud.position = Vector2(16, 12)
	_hud.add_theme_font_size_override(&"font_size", 20)
	add_child(ui)


func on_back() -> void:
	Router.goto_main_menu()


func perf_note() -> String:
	return "  shots %d (stage %d)  pool step %.2f ms  draw %.2f ms  dropped %d" % [
		pool.count, STAGES[_stage], pool.step_usec / 1000.0, pool.draw_usec / 1000.0, pool.dropped]


func _physics_process(delta: float) -> void:
	# Top up to the stage's count, spraying round the circle.
	var want := STAGES[_stage]
	while pool.count < want:
		_angle = fmod(_angle + 2.39996, TAU)  # the golden angle spreads them evenly
		pool.fire(Vector2.ZERO, Vector2.from_angle(_angle) * SPEED_U, RANGE_U / SPEED_U, 1.0, &"kinetic", 0.0,
				_mask, &"default")
	if _clock >= SETTLE_S:
		_steps += 1
		_step_usec += pool.step_usec
		_step_max_usec = maxi(_step_max_usec, pool.step_usec)
	_clock += delta


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_tick > 0 and _clock >= SETTLE_S:
		_frames += 1
		_frame_usec += now - _last_tick
		_worst_usec = maxi(_worst_usec, now - _last_tick)
		_draw_usec += pool.draw_usec
	_last_tick = now
	_hud.text = "%d shots  ·  stage %d of %d  ·  %d fps" % [pool.count, _stage + 1, STAGES.size(), Engine.get_frames_per_second()]
	if _clock >= STAGE_S:
		_end_stage()


func _end_stage() -> void:
	var row := {
		"shots": STAGES[_stage],
		"fps": _frames / maxf(_frame_usec / 1000000.0, 0.001),
		"frame_ms": _frame_usec / 1000.0 / maxi(_frames, 1),
		"worst_ms": _worst_usec / 1000.0,
		"step_ms": _step_usec / 1000.0 / maxi(_steps, 1),
		"step_max_ms": _step_max_usec / 1000.0,
		"draw_ms": _draw_usec / 1000.0 / maxi(_frames, 1),
		"dropped": pool.dropped - _dropped_at_start,
	}
	results.append(row)
	Perf.log_line("stress: %4d shots  %5.1f fps  frame %.2f ms (worst %.1f)  pool step %.2f ms (max %.2f)  draw %.2f ms  dropped %d" % [
		row["shots"], row["fps"], row["frame_ms"], row["worst_ms"], row["step_ms"], row["step_max_ms"], row["draw_ms"], row["dropped"]])
	_stage += 1
	if _stage >= STAGES.size():
		_stage = 0
		finished.emit()
	_clock = 0.0
	_frames = 0
	_frame_usec = 0
	_worst_usec = 0
	_steps = 0
	_step_usec = 0
	_step_max_usec = 0
	_draw_usec = 0
	_dropped_at_start = pool.dropped

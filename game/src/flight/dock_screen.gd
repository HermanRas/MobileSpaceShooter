class_name DockScreen
extends Control
## Coming home from a WaveTime (or Story) flight (PLAN.md 8.1): the bay, mouth down, and the
## ship, or the escape pod if the ship was lost, gliding up into it; the shutter closes, the
## screen fades to black and `docked` is emitted. Runs while the game under it is paused. Timings
## are `flight.json` → `cinematics`.

signal docked

const PX := ShipMesh.PX_PER_U
const STARS := 90
## The pod is under a unit long, a speck beside a bay sized for ships: drawn this much bigger here.
const POD_SCALE := 2.5

## Whether it's under way (or done).
var running := false

var _bay: LaunchBay
var _craft: Node2D
var _stage := Node2D.new()
var _title := MenuKit.label("", 30)
## "Pod recovered" gets A.16's pod badge beside it.
var _badge: TextureRect
var _black := ColorRect.new()
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _age := 0.0
var _glide_s := 2.4
var _shutter_s := 0.5
var _fade_s := 0.35
var _pod := false
## The sounds played so far: 1 the clamps (the craft settled), 2 the shutter.
var _sounded := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	add_child(_stage)
	var caption := HBoxContainer.new()
	caption.alignment = BoxContainer.ALIGNMENT_CENTER
	caption.add_theme_constant_override(&"separation", 12)
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_top = -120
	caption.offset_bottom = -56
	add_child(caption)
	if Assets.has_real_art(&"vis.icon.pod"):
		_badge = RunHud._icon(&"vis.icon.pod", 56)
		caption.add_child(_badge)
	caption.add_child(_title)
	_black.color = Color.BLACK
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)


## Docks `bp` (drawn with `placement`), or the escape pod when `bp` is null.
func play(bp: Blueprint, placement: Placement, tuning: Dictionary) -> void:
	_glide_s = float(tuning.get("dock_s", _glide_s))
	_shutter_s = float(tuning.get("shutter_s", _shutter_s))
	_fade_s = float(tuning.get("fade_s", _fade_s))
	_pod = bp == null
	var ship_u := Spawner.extent_u(bp, placement) if bp != null else 1.0
	_bay = LaunchBay.create(maxf(ship_u, 3.0))
	_stage.add_child(_bay)
	_bay.z_index = 0  # over this screen's backdrop, not under it as in flight
	if _pod:
		_craft = _PodView.new()
		_craft.scale = Vector2.ONE * POD_SCALE
	else:
		var mesh := MeshInstance2D.new()
		mesh.mesh = ShipMesh.build(bp.tiles, placement, bp)
		mesh.material = ShipMesh.make_material()
		_craft = mesh
	_stage.add_child(_craft)
	# The bay's mouth faces down, a little below the middle, the station above it filling most of
	# the screen's height; the craft comes up from below, nose first.
	var screen := get_viewport_rect().size
	var scale_by := screen.y * 0.55 / ((_bay.depth + 10.0) * PX)
	_stage.scale = Vector2.ONE * scale_by
	_bay.rotation = PI * 0.5
	_bay.position = Vector2(screen.x * 0.5, screen.y * 0.62) / scale_by
	_to = _bay.position + _bay.berth_u().rotated(_bay.rotation) * PX
	_from = Vector2(_to.x, (screen.y + ship_u * PX * scale_by) / scale_by)
	_craft.rotation = -PI * 0.5
	_craft.position = _from
	_title.text = "Pod recovered" if _pod else "Docking"
	if _badge != null:
		_badge.visible = _pod
	_black.modulate.a = 1.0
	_age = 0.0
	_sounded = 0
	running = true
	visible = true


func _process(delta: float) -> void:
	if not running:
		return
	_age += delta
	var glide := clampf((_age - _fade_s) / _glide_s, 0.0, 1.0)
	_craft.position = _from.lerp(_to, 1.0 - pow(1.0 - glide, 3.0))  # eases to a stop
	var shut := clampf((_age - _fade_s - _glide_s) / _shutter_s, 0.0, 1.0)
	_bay.shutter = shut
	if _sounded == 0 and glide >= 0.85:
		_sounded = 1
		Audio.play_sfx(&"dock.clamp")
	elif _sounded == 1 and shut > 0.0:
		_sounded = 2
		Audio.play_sfx(&"dock.shutter")
	var end := _fade_s + _glide_s + _shutter_s
	_black.modulate.a = clampf(1.0 - _age / _fade_s, 0.0, 1.0) if _age < end else clampf((_age - end) / _fade_s, 0.0, 1.0)
	queue_redraw()
	if _age >= end + _fade_s:
		running = false
		docked.emit()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.06))
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	for i in STARS:
		var at := Vector2(rng.randf() * size.x, fposmod(rng.randf() * size.y + _age * 30.0 * rng.randf(), size.y))
		draw_circle(at, rng.randf_range(0.8, 2.0), Color(1, 1, 1, rng.randf_range(0.3, 0.9)))


class _PodView extends Node2D:
	var _age := 0.0

	func _process(delta: float) -> void:
		_age += delta
		queue_redraw()

	func _draw() -> void:
		EscapePod.draw_pod(self, _age)

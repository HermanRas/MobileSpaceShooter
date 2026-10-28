class_name FollowCamera
extends Camera2D
## Follows a ship (PLAN.md Phase 3.5): leads it along its velocity so you see where you're
## going, and zooms out as it speeds up so going fast feels fast. Sized so the ship's longest
## side takes a fixed share of the screen at rest, whatever the ship's size. The player scales all
## of that by `view_zoom` (pinch, mouse wheel or +/-; owner, 2026-10-26), kept in Settings.

const PX := ShipMesh.PX_PER_U

var target: ShipBody
var ship_screen_share := 0.22
## Zoom-out per U/s of speed, down to min_zoom_share of the resting zoom.
var speed_zoom_out := 0.025
var min_zoom_share := 0.6
var look_ahead_s := 0.45
## 1/s: how quickly the camera catches up with where it wants to be, and with the zoom.
var follow_rate := 6.0
var zoom_rate := 2.0
## The player's zoom, times the resting zoom, within view_zoom_min..view_zoom_max; zoom_step is
## one key press or wheel notch.
var view_zoom := 1.0
var view_zoom_min := 0.35
var view_zoom_max := 2.5
var zoom_step := 1.15

var _rest_zoom := 1.0
## Screen shake (4.7): how far the view jolts now, in screen pixels, and how fast it settles.
var _shake := 0.0
var _shake_decay := 10.0


func _ready() -> void:
	Settings.changed.connect(func(key: StringName) -> void:
		if key == &"view_zoom":  # the Controls panel's slider
			zoom_by(float(Settings.get_value(&"view_zoom")) / view_zoom, false))


## Jolts the view by up to `pixels` on screen, settling at `decay` per second.
func shake(pixels: float, decay: float) -> void:
	_shake = maxf(_shake, pixels)
	_shake_decay = decay


func configure(table: Dictionary, ship: ShipBody, extent_u: float) -> void:
	for key in ["ship_screen_share", "speed_zoom_out", "min_zoom_share", "look_ahead_s", "follow_rate", "zoom_rate",
			"view_zoom_min", "view_zoom_max", "zoom_step"]:
		if table.has(key):
			set(key, float(table[key]))
	target = ship
	var screen_h := get_viewport_rect().size.y
	_rest_zoom = clampf(screen_h * ship_screen_share / (maxf(extent_u, 1.0) * PX), 0.15, 3.0)
	view_zoom = clampf(float(Settings.get_value(&"view_zoom")), view_zoom_min, view_zoom_max)
	zoom = Vector2.ONE * _rest_zoom * view_zoom
	position = ship.global_position


## Zooms the view by `factor` (above 1 closer), at once rather than eased, so a pinch tracks the
## fingers. `save` writes it to Settings; a pinch saves once, when the fingers lift.
func zoom_by(factor: float, save := true) -> void:
	var before := view_zoom
	view_zoom = clampf(view_zoom * factor, view_zoom_min, view_zoom_max)
	zoom *= view_zoom / before
	if save:
		save_zoom()


func save_zoom() -> void:
	if not is_equal_approx(float(Settings.get_value(&"view_zoom")), view_zoom):
		Settings.set_value(&"view_zoom", view_zoom)


func _process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	_shake = maxf(_shake - _shake * _shake_decay * delta - delta, 0.0)
	offset = Vector2.from_angle(randf() * TAU) * _shake / zoom.x if _shake > 0.0 else Vector2.ZERO
	if not is_instance_valid(target):
		return  # destroyed (4.2): hold still until the next ship is configured
	var speed_u := target.linear_velocity.length() / PX
	var wanted_zoom := _rest_zoom * view_zoom * maxf(1.0 / (1.0 + speed_zoom_out * speed_u), min_zoom_share)
	zoom = Vector2.ONE * lerpf(zoom.x, wanted_zoom, minf(zoom_rate * delta, 1.0))
	var wanted := target.global_position + target.linear_velocity * look_ahead_s
	# A jump (respawn, teleport) further than a screen away snaps instead of sliding across.
	if position.distance_to(wanted) > get_viewport_rect().size.x / zoom.x:
		position = wanted
	else:
		position = position.lerp(wanted, minf(follow_rate * delta, 1.0))
	BenchRun.spent(&"camera", started)

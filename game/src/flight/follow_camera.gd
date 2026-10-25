class_name FollowCamera
extends Camera2D
## Follows a ship (PLAN.md Phase 3.5): leads it along its velocity so you see where you're
## going, and zooms out as it speeds up so going fast feels fast. Sized so the ship's longest
## side takes a fixed share of the screen at rest, whatever the ship's size.

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

var _rest_zoom := 1.0


func configure(table: Dictionary, ship: ShipBody, extent_u: float) -> void:
	for key in ["ship_screen_share", "speed_zoom_out", "min_zoom_share", "look_ahead_s", "follow_rate", "zoom_rate"]:
		if table.has(key):
			set(key, float(table[key]))
	target = ship
	var screen_h := get_viewport_rect().size.y
	_rest_zoom = clampf(screen_h * ship_screen_share / (maxf(extent_u, 1.0) * PX), 0.15, 3.0)
	zoom = Vector2.ONE * _rest_zoom
	position = ship.global_position


func _process(delta: float) -> void:
	if target == null:
		return
	var speed_u := target.linear_velocity.length() / PX
	var wanted_zoom := _rest_zoom * maxf(1.0 / (1.0 + speed_zoom_out * speed_u), min_zoom_share)
	zoom = Vector2.ONE * lerpf(zoom.x, wanted_zoom, minf(zoom_rate * delta, 1.0))
	var wanted := target.global_position + target.linear_velocity * look_ahead_s
	# A jump (respawn, teleport) further than a screen away snaps instead of sliding across.
	if position.distance_to(wanted) > get_viewport_rect().size.x / zoom.x:
		position = wanted
	else:
		position = position.lerp(wanted, minf(follow_rate * delta, 1.0))

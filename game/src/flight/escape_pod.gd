class_name EscapePod
extends Node2D
## The escape pod that leaves a ship destroyed in a run and flies home (PLAN.md 8.1): it's thrown
## clear of the wreck and burns away, nose first. Not a body: nothing can hit it. It's A.15's
## pod (`vis.world.escape_pod`) with a flame drawn in code, or without the art a capsule in
## `vis.fx.escape_pod`'s colours; the dock screen draws one too (`draw_pod`).

const PX := ShipMesh.PX_PER_U
const META_ID := &"vis.fx.escape_pod"
const ART_ID := &"vis.world.escape_pod"
## Long gone off screen by then.
const LIFE_S := 8.0

## In px/s, and how hard it speeds up along its heading, in px/s².
var velocity := Vector2.ZERO
var accel := 0.0

var _age := 0.0


## A pod at `at` (px) moving off at `speed_u` from the wreck's `drift` (px/s), heading `heading`.
static func launch(at: Vector2, drift: Vector2, heading: float, speed_u: float, accel_u: float) -> EscapePod:
	var pod := EscapePod.new()
	pod.name = "EscapePod"
	pod.position = at
	pod.rotation = heading
	pod.velocity = drift + Vector2.from_angle(heading) * speed_u * PX
	pod.accel = accel_u * PX
	return pod


func _ready() -> void:
	z_index = 2  # over the wreck


func _process(delta: float) -> void:
	_age += delta
	if _age > LIFE_S:
		queue_free()
		return
	velocity += Vector2.from_angle(rotation) * accel * delta
	position += velocity * delta
	queue_redraw()


func _draw() -> void:
	draw_pod(self, _age)


## A pod on `canvas` at its origin, nose along +x, its flame flickering by `age`.
static func draw_pod(canvas: CanvasItem, age: float) -> void:
	var meta := Assets.meta(META_ID)
	var length := float(meta.get("length_u", 0.9)) * PX
	var body := Color.from_string(str(meta.get("body", "#d9dde3")), Color.WHITE)
	var flame := Color.from_string(str(meta.get("flame", "#ffb347")), Color.ORANGE)
	var flicker := 0.75 + 0.25 * sin(age * 40.0)
	if Assets.has_real_art(ART_ID):
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-length * 0.45, -length * 0.12),
				Vector2(-length * (0.8 + 0.35 * flicker), 0), Vector2(-length * 0.45, length * 0.12)]), flame)
		var side := length / float(Assets.meta(ART_ID).get("art_share", 1.0))
		canvas.draw_texture_rect(Assets.tex(ART_ID), Rect2(-side * 0.5, -side * 0.5, side, side), false)
		return
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-length * 0.45, -length * 0.18),
			Vector2(-length * (0.9 + 0.35 * flicker), 0), Vector2(-length * 0.45, length * 0.18)]), flame)
	canvas.draw_circle(Vector2(length * 0.15, 0), length * 0.32, body)
	canvas.draw_rect(Rect2(-length * 0.5, -length * 0.25, length * 0.65, length * 0.5), body)
	canvas.draw_circle(Vector2(length * 0.22, 0), length * 0.14,
			Color.from_string(str(meta.get("window", "#7fd4ff")), Color.SKY_BLUE))

class_name Explosion
extends Node2D
## A ship blowing up (PLAN.md 4.2): a white flash, an expanding ring and a burst of sparks,
## sized by the ship. Frees itself when done. Drawn in code (`vis.fx.explosion` has the colours).

const META_ID := &"vis.fx.explosion"

## The ship's size in pixels.
var size_px := 128.0

var _duration := 0.9
var _age := 0.0
var _colors: Array[Color] = []


static func create(ship_size_px: float) -> Explosion:
	var blast := Explosion.new()
	blast.name = "Explosion"
	blast.size_px = maxf(ship_size_px, 32.0)
	return blast


func _ready() -> void:
	var meta := Assets.meta(META_ID)
	_duration = float(meta.get("duration_s", _duration))
	for hex: String in meta.get("colors", ["#ffffff", "#ffd27a", "#ff7a1a", "#802000"]):
		_colors.append(Color.from_string(hex, Color.WHITE))
	material = ThrusterFx._additive()
	z_index = 1
	var sparks := CPUParticles2D.new()
	sparks.amount = int(meta.get("sparks", 96))
	sparks.lifetime = _duration
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.spread = 180.0
	sparks.gravity = Vector2.ZERO
	sparks.initial_velocity_min = size_px * 0.6
	sparks.initial_velocity_max = size_px * 1.8
	sparks.damping_min = size_px * 0.5
	sparks.damping_max = size_px * 1.2
	sparks.texture = ThrusterFx._dot()
	var spark_size: Array = meta.get("spark_size", [0.09, 0.24])
	sparks.scale_amount_min = size_px * float(spark_size[0]) / 32.0
	sparks.scale_amount_max = size_px * float(spark_size[1]) / 32.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.6, 1.0])
	ramp.colors = PackedColorArray([_colors[0], _colors[1], _colors[2], Color(_colors[3], 0.0)])
	sparks.color_ramp = ramp
	sparks.material = ThrusterFx._additive()
	sparks.emitting = true
	add_child(sparks)


func _process(delta: float) -> void:
	_age += delta
	if _age >= _duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / _duration
	# The flash: big and white at once, shrinking and cooling fast.
	var flash := 1.0 - smoothstep(0.0, 0.45, t)
	if flash > 0.0:
		var r := size_px * (0.6 + 0.5 * t)
		draw_texture_rect(ThrusterFx._dot(), Rect2(-r, -r, r * 2.0, r * 2.0), false, Color(_colors[1], flash))
		r *= 0.5
		draw_texture_rect(ThrusterFx._dot(), Rect2(-r, -r, r * 2.0, r * 2.0), false, Color(_colors[0], flash))
	# The ring: racing outward and thinning.
	var ring := 1.0 - t
	draw_arc(Vector2.ZERO, size_px * (0.3 + 1.2 * sqrt(t)), 0.0, TAU, 64,
			Color(_colors[1], ring * ring * 0.5), maxf(size_px * 0.025 * ring, 2.0), true)

class_name ThrusterFx
extends Node2D
## One thruster's exhaust (PLAN.md Phase 3.6). Local +x is the exhaust direction; the origin
## sits on the middle of the thruster's edge, so the nozzle sticks out along +x first.
##   pulse  an orange puff on every kick
##   jet    a fire trail whose length follows the throttle
##   ion    a long tapered blue plume that grows and brightens as the ramp builds
## Bigger for larger sizes (via the width) and higher levels (level_scale in visuals.json).
## CPUParticles2D for now; GPUParticles2D gets measured against it on the phone later.

const META_ID := &"vis.fx.thrusters"
## The nozzle sticks out depth_factor × its width (ThrusterLib); the exhaust starts past it.
const NOZZLE_DEPTH := 0.5

var type: StringName
## The thruster's width in pixels (its edge stretch).
var width_px := 64.0
var level := 1

var _particles: CPUParticles2D
var _scale := 1.0
var _colors: Array[Color] = []
var _torch := 0.0  # ion: 0..1


static func create(type_id: StringName, width: float, thruster_level: int) -> ThrusterFx:
	var fx := ThrusterFx.new()
	fx.type = type_id
	fx.width_px = width
	fx.level = thruster_level
	return fx


func _ready() -> void:
	var meta := Assets.meta(META_ID)
	var scales: Array = meta.get("level_scale", [1.0, 1.3, 1.6])
	_scale = float(scales[clampi(level - 1, 0, scales.size() - 1)])
	for hex: String in meta.get(String(type), ["#ffffff", "#ffaa55", "#ff5500", "#aa2200"]):
		_colors.append(Color.from_string(hex, Color.WHITE))
	match type:
		&"jet":
			_particles = _make_particles(90, 0.4, 0.0)
			_particles.spread = 4.0
			_particles.damping_min = width_px * 0.5
			_particles.damping_max = width_px * 1.0
			_particles.scale_amount_min *= 0.9
			_particles.emitting = false
		&"pulse":
			_particles = _make_particles(16, 0.45, 1.0)
			_particles.one_shot = true
			_particles.spread = 38.0
			# A puff rides along with the ship. Left in world space it fell off the bottom of
			# the screen within a fraction of a second at cruise (the camera leads the ship).
			_particles.local_coords = true
			_particles.emitting = false
	if _particles != null:
		_particles.position = Vector2(width_px * NOZZLE_DEPTH, 0)
		add_child(_particles)
	if type == &"ion":
		material = _additive()


## Called every frame with this thruster's throttle (0..1) and, for ion, its ramp (0..1).
func set_state(throttle: float, ramp: float) -> void:
	match type:
		&"jet":
			_particles.emitting = throttle > 0.02
			var reach := (0.3 + 0.7 * throttle)
			_particles.initial_velocity_min = width_px * 6.0 * _scale * reach
			_particles.initial_velocity_max = width_px * 8.0 * _scale * reach
		&"ion":
			var wanted := throttle * (0.3 + 0.7 * ramp)
			# Every frame while lit (the shimmer), and once more as it goes out.
			if _torch > 0.01 or not is_equal_approx(wanted, _torch):
				_torch = wanted
				queue_redraw()


## A pulse thruster's kick: one puff, sized by the throttle.
func kick(throttle: float) -> void:
	if _particles == null:
		return
	_particles.initial_velocity_min = width_px * 1.6 * _scale * (0.5 + 0.5 * throttle)
	_particles.initial_velocity_max = width_px * 2.8 * _scale * (0.5 + 0.5 * throttle)
	_particles.restart()


func _draw() -> void:
	var started := Time.get_ticks_usec()
	if type != &"ion" or _torch <= 0.01:
		return
	# A long tapered plume: soft glows anchored at the nozzle, wide and deep blue outside
	# to short, thin and white-hot inside. It grows with the ramp and shimmers a little.
	var seconds := Time.get_ticks_msec() / 1000.0
	var shimmer := 1.0 + 0.04 * sin(seconds * 31.0 + width_px) + 0.03 * sin(seconds * 53.0)
	var length := width_px * (1.5 + 5.5 * _torch) * _scale * shimmer
	var half_width := width_px * 0.4 * sqrt(_scale) * (0.7 + 0.3 * _torch)  # length grows with level more than width
	var start := width_px * NOZZLE_DEPTH
	var count := _colors.size()
	for i in range(count - 1, -1, -1):
		var share := float(i + 1) / count
		var half := Vector2(length * share, half_width * (0.25 + 0.75 * share))
		draw_texture_rect(_plume(), Rect2(Vector2(start, -half.y), Vector2(half.x, half.y * 2.0)), false,
				Color(_colors[i], _torch * (0.5 + 0.5 * (1.0 - share))))
	BenchRun.spent(&"exhaust", started)


func _make_particles(amount: int, lifetime: float, explosiveness: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = lifetime * _scale
	p.explosiveness = explosiveness
	p.local_coords = false  # a jet's trail stays where it was left, so it bends as the ship turns
	p.direction = Vector2.RIGHT
	p.gravity = Vector2.ZERO
	p.damping_min = width_px * 1.5
	p.damping_max = width_px * 2.5
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(1.0, width_px * 0.3)
	p.texture = _dot()
	var dot_px := 32.0
	p.scale_amount_min = width_px * 0.35 * _scale / dot_px
	p.scale_amount_max = width_px * 0.6 * _scale / dot_px
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.6))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1.0, 0.3))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.18, 0.55, 1.0])
	# Not fully opaque: additive blending saturates to white where puffs overlap.
	ramp.colors = PackedColorArray([Color(_colors[0], 0.8), Color(_colors[1], 0.65), Color(_colors[2], 0.45), Color(_colors[3], 0.0)])
	p.color_ramp = ramp
	p.material = _additive()
	return p


static var _dot_texture: GradientTexture2D
static var _plume_texture: ImageTexture
static var _add_material: CanvasItemMaterial


## A soft round dot, made in code (no asset file).
static func _dot() -> GradientTexture2D:
	if _dot_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
		_dot_texture = GradientTexture2D.new()
		_dot_texture.gradient = gradient
		_dot_texture.fill = GradientTexture2D.FILL_RADIAL
		_dot_texture.fill_from = Vector2(0.5, 0.5)
		_dot_texture.fill_to = Vector2(1.0, 0.5)
		_dot_texture.width = 32
		_dot_texture.height = 32
	return _dot_texture


## A plume made in code: bright at the left edge, tapering to a point on the right and soft
## at the sides. Stretched long, it reads as a torch.
static func _plume() -> ImageTexture:
	if _plume_texture == null:
		var w := 128
		var h := 32
		var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for x in w:
			var along := float(x) / (w - 1)
			var reach := 1.0 - 0.75 * along  # the half-width tapers to a quarter at the tip
			var fade := pow(1.0 - along, 1.4)
			for y in h:
				var across := absf((y + 0.5) / h * 2.0 - 1.0) / reach
				image.set_pixel(x, y, Color(1, 1, 1, fade * clampf(1.0 - across * across, 0.0, 1.0)))
		_plume_texture = ImageTexture.create_from_image(image)
	return _plume_texture


static func _additive() -> CanvasItemMaterial:
	if _add_material == null:
		_add_material = CanvasItemMaterial.new()
		_add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_material

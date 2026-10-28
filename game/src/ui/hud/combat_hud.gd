class_name CombatHud
extends Control
## The flight HUD's combat part (PLAN.md 4.7): shield and hull bars, the manual weapon FIRE
## fires, and what a hit on the player feels like: a screen flash (red for hull, blue when only
## the shield took it), a camera jolt and a buzz, the last two as Settings allow. Tuning is in
## `flight.json` → `combat_hud`.

const BAR := Vector2(240, 12)
const SHIELD := Color(0.35, 0.65, 1.0)
const HULL_FULL := Color(0.35, 0.95, 0.5)
const HULL_LOW := Color(1.0, 0.3, 0.25)
const BACK := Color(1, 1, 1, 0.12)

## The bar's top-left corner, in canvas pixels.
var bars_at := Vector2(16, 80)
## Hull left as a share of what the ship has now (0..1), and the flash's colour and time left.
var hull_share := 1.0
var flash_left := 0.0
var flash_color := Color.RED

var _ship: ShipBody
var _weapons: WeaponController
var _camera: FollowCamera
var _tuning: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Follows `ship` (again after a respawn); hits jolt `camera`.
func attach(ship: ShipBody, weapons: WeaponController, camera: FollowCamera, tuning: Dictionary) -> void:
	_ship = ship
	_weapons = weapons
	_camera = camera
	_tuning = tuning
	ship.damaged.connect(_on_damaged)
	ship.rebuilt.connect(_count_hull)
	_count_hull()


func _process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	flash_left = maxf(flash_left - delta, 0.0)
	if Engine.get_process_frames() % 2 == 0:  # the bars on the HUD's frames (FlightSandbox._process)
		queue_redraw()
	BenchRun.spent(&"hud", started)


func _draw() -> void:
	var started := Time.get_ticks_usec()
	if is_instance_valid(_ship) and _ship.damage != null:
		var damage := _ship.damage
		var shield_share := damage.shield / damage.shield_cap if damage.shield_cap > 0.0 else 0.0
		if damage.shield_cap > 0.0:
			_bar(bars_at, shield_share, SHIELD.darkened(0.5) if damage.is_disabled() else SHIELD)
		_bar(bars_at + Vector2(0, BAR.y + 6), hull_share, HULL_LOW.lerp(HULL_FULL, hull_share))
		var font := get_theme_default_font()
		var line := bars_at + Vector2(0, BAR.y * 2 + 28)
		if _weapons != null and _weapons.gunnery.active != &"" and not _weapons.all_auto:
			var gun := _weapons.gunnery.layout.guns.filter(func(g: GunLayout.Gun) -> bool: return g.weapon == _weapons.gunnery.active)
			var label := "FIRE: %s ×%d" % [gun[0].stats["name"] if not gun.is_empty() else _weapons.gunnery.active,
					_weapons.gunnery.manual_count(_weapons.gunnery.active)]
			draw_string(font, line, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.85, 0.5))
	if flash_left > 0.0:
		var alpha := float(_tuning.get("flash_alpha", 0.28)) * flash_left / float(_tuning.get("flash_s", 0.3))
		_vignette(Color(flash_color, alpha))
	BenchRun.spent(&"hud", started)


func _on_damaged(result: ShipDamage.Result) -> void:
	_count_hull()
	flash_color = Color(1.0, 0.15, 0.1) if result.hull > 0.0 else Color(0.3, 0.6, 1.0)
	flash_left = float(_tuning.get("flash_s", 0.3))
	var amount := result.hull + result.shield * 0.5
	if Settings.get_value(&"screen_shake") and _camera != null:
		_camera.shake(minf(amount * float(_tuning.get("shake_px_per_damage", 0.2)), float(_tuning.get("shake_max_px", 14))),
				float(_tuning.get("shake_decay", 9)))
	if Settings.get_value(&"vibration") and result.hull >= float(_tuning.get("vibrate_min_damage", 12)):
		Input.vibrate_handheld(int(_tuning.get("vibrate_ms", 45)))


## Hull left on the tiles the ship still has, as a share of their full HP.
func _count_hull() -> void:
	if not is_instance_valid(_ship) or _ship.damage == null:
		return
	var left := 0.0
	var full := 0.0
	for tile_id: int in _ship.damage.hp:
		if _ship.damage.is_attached(tile_id):
			left += _ship.damage.hp[tile_id]
			full += _ship.damage.max_hp[tile_id]
	hull_share = left / full if full > 0.0 else 0.0


func _bar(at: Vector2, share: float, color: Color) -> void:
	draw_rect(Rect2(at, BAR), BACK)
	draw_rect(Rect2(at, Vector2(BAR.x * clampf(share, 0.0, 1.0), BAR.y)), color)


## A glow round the screen's edge, strongest at the rim.
func _vignette(color: Color) -> void:
	const BANDS := 6
	const DEPTH := 120.0
	for i in BANDS:
		var inset := DEPTH * i / BANDS
		draw_rect(Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0),
				Color(color, color.a * (1.0 - float(i) / BANDS)), false, DEPTH / BANDS)

class_name DamageNumbers
extends Control
## Floating numbers over the fight (PLAN.md 8.3): the damage each hit on an enemy does, rising and
## fading where it struck, bigger and hotter the harder the hit, and a gold score pop where a kill
## falls. Hits on one ship within `merge_s` add up into one number, so a gatling doesn't bury the
## screen. Drawn on the HUD layer, at the world point's place on screen, so they're the same size
## at any zoom. All of them live in arrays and draw in one `_draw`. Tuning is `flight.json` →
## `damage_numbers`.

const GOLD := Color(1.0, 0.82, 0.3)

var camera: Camera2D
var merge_s := 0.15
var life_s := 0.9
var rise_px := 70.0
var min_px := 18.0
var max_px := 54.0
## A hit of this much damage gets the biggest, hottest number.
var big_hit := 1000.0
var max_live := 60
var pop_px := 46.0

## Live numbers: world position, text, font size, colour, age.
var _at := PackedVector2Array()
var _text := PackedStringArray()
var _size := PackedFloat32Array()
var _colour := PackedColorArray()
var _age := PackedFloat32Array()
## Ship instance id -> {"at": world px of its last hit, "amount", "age"}: hits still adding up.
var _pending := {}
## The latest shot hit: the ship's instance id and where (world px).
var _aim_id := 0
var _aim_at := Vector2.ZERO
## Numbers were showing at the last draw (one more draw clears them).
var _drawn := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(table: Dictionary) -> void:
	for key in ["merge_s", "life_s", "rise_px", "min_px", "max_px", "big_hit", "pop_px"]:
		if table.has(key):
			set(key, float(table[key]))
	max_live = int(table.get("max_live", max_live))


## `body` took `amount` (shield and hull): at the shot's hit point if one just landed on it
## (`aim`), else at its middle (a blast's splash).
func hit(body: Node2D, amount: float) -> void:
	if amount < 0.5:
		return
	var id := body.get_instance_id()
	var where: Vector2 = _aim_at if _aim_id == id else body.global_position
	if _pending.has(id):
		_pending[id]["amount"] += amount
		_pending[id]["at"] = where
	else:
		_pending[id] = {"at": where, "amount": amount, "age": 0.0}


## Where the next hit on `body` landed (the shot pool's `hit` comes just before the damage).
func aim(body: Node2D, at: Vector2) -> void:
	_aim_id = body.get_instance_id()
	_aim_at = at


## A gold "+points" where a kill fell.
func pop(at: Vector2, points: int) -> void:
	_add(at, "+%d" % points, pop_px, GOLD)


func live() -> int:
	return _text.size()


func _process(delta: float) -> void:
	for id: int in _pending.keys():
		var entry: Dictionary = _pending[id]
		entry["age"] += delta
		if entry["age"] >= merge_s:
			_pending.erase(id)
			var amount: float = entry["amount"]
			var heat := clampf(log(maxf(amount, 1.0)) / log(maxf(big_hit, 2.0)), 0.0, 1.0)
			_add(entry["at"], str(roundi(amount)), lerpf(min_px, max_px, heat),
					Color.WHITE.lerp(Color(1.0, 0.85, 0.3), minf(heat * 2.0, 1.0)).lerp(Color(1.0, 0.35, 0.2), maxf(heat * 2.0 - 1.0, 0.0)))
	for i in range(_age.size() - 1, -1, -1):
		_age[i] += delta
		if _age[i] >= life_s:
			_remove(i)
	if not _age.is_empty() or _drawn:
		queue_redraw()


func _draw() -> void:
	_drawn = not _text.is_empty()
	if camera == null or _text.is_empty():
		return
	var font := get_theme_default_font()
	var view := camera.get_canvas_transform()
	for i in _text.size():
		var t := _age[i] / life_s
		var size := roundi(_size[i] * (1.0 + 0.3 * maxf(0.15 - t, 0.0) / 0.15))  # a little punch as it appears
		var colour := _colour[i]
		colour.a = 1.0 - maxf(t - 0.6, 0.0) / 0.4
		var width := font.get_string_size(_text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at := view * _at[i] + Vector2(-width * 0.5, -rise_px * t)
		draw_string_outline(font, at, _text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0, 0, 0, colour.a * 0.8))
		draw_string(font, at, _text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)


func _add(at: Vector2, text: String, size: float, colour: Color) -> void:
	if _text.size() >= max_live:
		_remove(0)
	_at.append(at + Vector2(randf_range(-12, 12), randf_range(-8, 8)))
	_text.append(text)
	_size.append(size)
	_colour.append(colour)
	_age.append(0.0)


func _remove(i: int) -> void:
	_at.remove_at(i)
	_text.remove_at(i)
	_size.remove_at(i)
	_colour.remove_at(i)
	_age.remove_at(i)

class_name RunHud
extends Control
## The flight's big readouts (PLAN.md 8.2), sized to read at arm's length on a phone:
## - in a WaveTime run, a big clock top centre with the wave and the time to the next one under it,
##   and the score top right;
## - in every flight, the loot in the hold under the score: an icon and a count for each resource
##   picked up, counting up to what's there and flashing as it comes in;
## - a banner across the middle when a part is found (`found`);
## - while a power-up runs (8.3), its multiplier and countdown under the wave.
## The flight calls `show_run` and `show_cargo` on its HUD frames.

## How fast a count climbs to its new value (a share of the gap a second), and how long a flash
## and a banner last.
const COUNT_RATE := 8.0
const FLASH_S := 0.6
const BANNER_S := 2.6
const GOLD := Color(1.0, 0.82, 0.3)
const ICON := 34
const RESOURCES: Array[StringName] = [&"hull", &"alloy", &"crystal", &"tech", &"gc", &"parts"]

var clock := MenuKit.label("", 60)
var wave := MenuKit.label("", 26)
var score := MenuKit.label("", 38, GOLD)
var power := MenuKit.label("", 40, Color(1.0, 0.45, 0.95))
var banner := PanelContainer.new()

var _banner_text := MenuKit.label("", 32, GOLD)
var _top: VBoxContainer
var _banner_left := 0.0
var _loot := HBoxContainer.new()
## Resource -> {"box", "count": Label, "shown": float, "target": int, "flash": seconds left}.
var _rows := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := VBoxContainer.new()
	_top = top
	top.name = "Clock"
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.add_theme_constant_override(&"separation", -6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	for label: Label in [clock, wave, power]:
		_outline(label)
		top.add_child(label)
	var right := VBoxContainer.new()
	right.name = "Tally"
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -104  # clear of the Pause button
	right.offset_top = 8
	right.alignment = BoxContainer.ALIGNMENT_BEGIN
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_outline(score)
	right.add_child(score)
	_loot.alignment = BoxContainer.ALIGNMENT_END
	_loot.add_theme_constant_override(&"separation", 14)
	_loot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_loot)
	for resource in RESOURCES:
		_add_row(resource)
	banner.name = "Banner"
	banner.theme_type_variation = &"ChromePanel"
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(_banner_text)
	banner.visible = false
	add_child(banner)
	clock.visible = false
	wave.visible = false
	score.visible = false
	power.visible = false


## The run's clock, wave and score.
func show_run(run: WaveRun) -> void:
	for label: Label in [clock, wave, score]:
		label.visible = true
	clock.text = TestFlight.clock(run.seconds)
	wave.text = "WAVE %d   ·   next %s" % [run.wave, TestFlight.clock(ceilf(run.next_in()))]
	score.text = _thousands(run.score())


## The power-up running: "×5 FIREPOWER 0:07", or nothing.
func show_power(running: PowerUps) -> void:
	power.visible = running != null and running.shots() > 1
	if power.visible:
		power.text = "×%d FIREPOWER  %s" % [running.shots(), TestFlight.clock(ceilf(running.left))]


## The hold's loot: each resource and the parts found, as counts that climb to it.
func show_cargo(cargo: Inventory) -> void:
	for resource in RESOURCES:
		var have := cargo.guns.size() + _thrusters(cargo) if resource == &"parts" else cargo.amount(resource)
		var row: Dictionary = _rows[resource]
		if have > int(row["target"]):
			row["flash"] = FLASH_S
		row["target"] = have
		(row["box"] as Control).visible = have > 0


## A part was found: a banner across the middle for a few seconds.
func found(text: String) -> void:
	_banner_text.text = text
	banner.visible = true
	banner.modulate.a = 1.0
	_banner_left = BANNER_S
	banner.reset_size()


## A count as the HUD shows it now (for drives).
func shown(resource: StringName) -> int:
	return roundi(float(_rows[resource]["shown"]))


func _process(delta: float) -> void:
	for resource: StringName in _rows:
		var row: Dictionary = _rows[resource]
		var target := float(row["target"])
		var shown_now := float(row["shown"])
		if shown_now != target:
			shown_now = move_toward(shown_now, target, maxf(absf(target - shown_now) * COUNT_RATE * delta, 1.0))
			row["shown"] = shown_now
			(row["count"] as Label).text = str(roundi(shown_now))
		if float(row["flash"]) <= 0.0 and not row.get("lit", false):
			continue
		var flash := maxf(float(row["flash"]) - delta, 0.0)
		row["flash"] = flash
		row["lit"] = flash > 0.0  # one more pass after the flash, to settle back to white
		var glow := flash / FLASH_S
		(row["count"] as Label).add_theme_color_override(&"font_color", Color.WHITE.lerp(GOLD, glow))
		(row["box"] as Control).scale = Vector2.ONE * (1.0 + 0.25 * glow)
	if banner.visible:
		_banner_left -= delta
		banner.modulate.a = clampf(_banner_left / 0.5, 0.0, 1.0)
		banner.visible = _banner_left > 0.0
		# Under the clock (and a power-up's countdown), above the ship.
		var under := _top.get_rect().end.y + 8.0 if clock.visible else size.y * 0.12
		banner.position = Vector2((size.x - banner.size.x) * 0.5, under)


func _add_row(resource: StringName) -> void:
	var box := HBoxContainer.new()
	box.name = String(resource).capitalize()
	box.add_theme_constant_override(&"separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.visible = false
	var id := StringName("vis.icon.%s" % resource)
	if resource != &"parts" and Assets.has_real_art(id):
		var icon := TextureRect.new()
		icon.texture = Assets.tex(id)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(ICON, ICON)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		box.add_child(icon)
	else:
		var name_label := MenuKit.label("parts" if resource == &"parts" else "GC" if resource == &"gc" else String(resource), 22)
		_outline(name_label)
		box.add_child(name_label)
	var count := MenuKit.label("0", 30)
	_outline(count)
	box.add_child(count)
	_loot.add_child(box)
	box.resized.connect(func() -> void: box.pivot_offset = box.size * 0.5)
	_rows[resource] = {"box": box, "count": count, "shown": 0.0, "target": 0, "flash": 0.0}


static func _thrusters(cargo: Inventory) -> int:
	var out := 0
	for key: String in cargo.thrusters:
		out += int(cargo.thrusters[key])
	return out


## 12345 -> "12,345".
static func _thousands(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out


## A dark outline so the text reads over bright explosions and nebulae.
static func _outline(label: Label) -> void:
	label.add_theme_constant_override(&"outline_size", 8)
	label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

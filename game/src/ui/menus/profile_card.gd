class_name ProfileCard
extends PanelContainer
## The active profile on the main menu (PLAN.md 6.1; owner's layout, 2026-10-26): a wide card,
## its left 30% a square portrait (the character builder's, 6.2; a helmet until then), the rest
## the pilot's name over two halves: a stopwatch with the best WaveTime and kills / deaths, and
## a path with Story progress and jobs done ("S2% / J26"). Icons are drawn here until the icon
## sheet (A.4).

const NAME_SIZE := 44
const STAT_SIZE := 20
const FRAME := Color(0.35, 0.8, 1.0)
const ACCENT := Color(1.0, 0.62, 0.25)

var _name := Label.new()
var _wave := Label.new()
var _record := Label.new()
var _story := Label.new()
var _portrait := _Portrait.new()
var _edit := Button.new()


func _ready() -> void:
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.04, 0.06, 0.1, 0.92)
	frame.border_color = FRAME
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(10)
	frame.shadow_color = Color(FRAME, 0.25)
	frame.shadow_size = 8
	frame.set_content_margin_all(0)
	add_theme_stylebox_override(&"panel", frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 0)
	add_child(row)
	_portrait.name = "Portrait"
	row.add_child(_portrait)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", 0)
	row.add_child(right)

	var top := HBoxContainer.new()
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(top)
	_name.name = "PlayerName"
	_name.add_theme_font_size_override(&"font_size", NAME_SIZE)
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.clip_text = true
	var name_pad := MarginContainer.new()
	name_pad.add_theme_constant_override(&"margin_left", 24)
	name_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_pad.add_child(_name)
	top.add_child(name_pad)
	_edit.name = "EditProfile"
	_edit.text = "Edit (6.2)"
	_edit.disabled = true
	_edit.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_edit.custom_minimum_size = Vector2(130, 44)
	var edit_pad := MarginContainer.new()
	edit_pad.add_theme_constant_override(&"margin_top", 12)
	edit_pad.add_theme_constant_override(&"margin_right", 12)
	edit_pad.add_child(_edit)
	top.add_child(edit_pad)

	var bottom := HBoxContainer.new()
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom.add_theme_constant_override(&"separation", 0)
	right.add_child(bottom)
	bottom.add_child(_half(_Icon.new(&"stopwatch"), [_wave, _record], "WaveTimeStats"))
	bottom.add_child(_half(_Icon.new(&"path"), [_story], "StoryStats"))


## Fills the card from Profiles.summary().
func show_profile(info: Dictionary) -> void:
	_name.text = str(info.get("name", "Pilot"))
	_wave.text = "Best %s" % _clock(int(info.get("best_wave_s", 0)))
	_record.text = "K %d / D %d" % [int(info.get("kills", 0)), int(info.get("deaths", 0))]
	_story.text = "S%d%% / J%d" % [int(info.get("story_pct", 0)), int(info.get("jobs", 0))]


## The card `width` wide; its height is the portrait's, 30% of the width.
func size_to(width: float) -> void:
	custom_minimum_size = Vector2(width, roundf(width * 0.3))
	_portrait.custom_minimum_size = Vector2.ONE * roundf(width * 0.3)


static func _clock(seconds: int) -> String:
	if seconds <= 0:
		return "--:--"
	return "%d:%02d:%02d" % [seconds / 3600, seconds / 60 % 60, seconds % 60] if seconds >= 3600 \
			else "%d:%02d" % [seconds / 60, seconds % 60]


func _half(icon: Control, lines: Array, node_name: String) -> Control:
	var box := HBoxContainer.new()
	box.name = node_name
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override(&"separation", 12)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override(&"margin_left", 24)
	pad.add_theme_constant_override(&"margin_bottom", 14)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(box)
	icon.custom_minimum_size = Vector2(56, 56)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(text)
	for label: Label in lines:
		label.add_theme_font_size_override(&"font_size", STAT_SIZE)
		text.add_child(label)
	return pad


## The pilot's picture: the character builder's portrait in 6.2; a helmet until then.
class _Portrait extends Control:
	func _draw() -> void:
		var side := minf(size.x, size.y)
		var box := Rect2(Vector2.ONE * 10.0, Vector2.ONE * (side - 20.0))
		draw_rect(box, Color(0.1, 0.16, 0.26))
		draw_rect(box, ProfileCard.ACCENT, false, 3.0)
		var c := box.get_center() + Vector2(0, side * 0.04)
		var r := side * 0.3
		draw_rect(Rect2(c + Vector2(-r * 1.1, r * 0.75), Vector2(r * 2.2, r * 0.6)), Color(0.75, 0.78, 0.85))
		draw_circle(c, r, Color(0.86, 0.88, 0.92))
		var visor := PackedVector2Array()
		for k in 17:
			var a := PI + PI * k / 16.0
			visor.append(c + Vector2(cos(a) * r * 0.78, sin(a) * r * 0.62 + r * 0.12))
		visor.append(c + Vector2(r * 0.6, r * 0.38))
		visor.append(c + Vector2(-r * 0.6, r * 0.38))
		draw_colored_polygon(visor, Color(0.08, 0.12, 0.22))
		draw_line(c + Vector2(-r * 0.45, -r * 0.2), c + Vector2(-r * 0.1, -r * 0.42), Color(ProfileCard.FRAME, 0.9), 4.0)
		draw_line(c + Vector2(r * 0.15, -r * 0.35), c + Vector2(r * 0.45, -r * 0.1), Color(ProfileCard.ACCENT, 0.9), 4.0)


## A stat icon, drawn: `stopwatch` (WaveTime) or `path` (Story).
class _Icon extends Control:
	var kind: StringName

	func _init(icon: StringName) -> void:
		kind = icon
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.4
		var line := ProfileCard.FRAME
		if kind == &"stopwatch":
			draw_arc(c + Vector2(0, r * 0.1), r * 0.85, 0.0, TAU, 32, line, 3.0, true)
			draw_rect(Rect2(c + Vector2(-r * 0.18, -r * 1.05), Vector2(r * 0.36, r * 0.22)), line)
			draw_line(c + Vector2(0, r * 0.1), c + Vector2(r * 0.45, -r * 0.3), ProfileCard.ACCENT, 3.0, true)
			draw_circle(c + Vector2(0, r * 0.1), 3.0, line)
		else:
			var path := PackedVector2Array()
			for k in 25:
				var t := k / 24.0
				path.append(c + Vector2(lerpf(-r, r, t), sin(t * TAU) * r * 0.45))
			draw_polyline(path, line, 3.0, true)
			draw_circle(path[0], r * 0.2, ProfileCard.ACCENT)
			draw_circle(path[path.size() - 1], r * 0.2, line)

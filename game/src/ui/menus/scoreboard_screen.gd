extends Control
## WaveTime's scoreboard (PLAN.md 8.4, `[D2]` `[D20]`): every pilot on the device, best first by
## kills ÷ deaths (ties by kills), with their best score and furthest wave. The selected pilot's
## row is gold, and the leader has a trophy. Columns carry A.16's icons when the art is in. Back
## (the gesture, or Esc) goes to the main menu.

const COLUMNS: Array[String] = ["#", "Pilot", "Kills", "Deaths", "K / D", "Best score", "Best wave"]
const GOLD := Color(1.0, 0.82, 0.3)
## The icon over each heading (none for "" ).
const HEADING_ICONS: Array[StringName] = [&"", &"", &"vis.icon.kills", &"vis.icon.skull", &"", &"vis.icon.score",
		&"vis.icon.wave"]

## The rows shown, best first (Scoreboard.rank), for drives.
var rows: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(MenuBackdrop.new())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 24)
	center.add_child(column)
	column.add_child(MenuKit.label("Scoreboard", 48))
	rows = Scoreboard.rank(Profiles.list())
	if rows.is_empty():
		column.add_child(MenuKit.label("No pilots yet: WaveTime makes one.", 26))
		return
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ChromePanel"
	column.add_child(panel)
	var grid := GridContainer.new()
	grid.name = "Table"
	grid.columns = COLUMNS.size()
	grid.add_theme_constant_override(&"h_separation", 36)
	grid.add_theme_constant_override(&"v_separation", 10)
	panel.add_child(grid)
	for c in COLUMNS.size():
		var heading := VBoxContainer.new()
		heading.alignment = BoxContainer.ALIGNMENT_END
		if HEADING_ICONS[c] != &"" and Assets.has_real_art(HEADING_ICONS[c]):
			var icon := RunHud._icon(HEADING_ICONS[c], 34)
			icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			heading.add_child(icon)
		heading.add_child(MenuKit.label(COLUMNS[c], 22, Color(1, 1, 1, 0.6)))
		grid.add_child(heading)
	for i in rows.size():
		var row := rows[i]
		var colour := GOLD if row["id"] == Profiles.selected_id else Color.WHITE
		var flown: bool = row["runs"] > 0
		if i == 0 and flown and Assets.has_real_art(&"vis.icon.trophy"):
			var first := RunHud._icon(&"vis.icon.trophy", 34)
			first.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			grid.add_child(first)
		else:
			grid.add_child(MenuKit.label(str(i + 1), 28, colour))
		for text in [row["name"], str(row["kills"]), str(row["deaths"]),
				Scoreboard.ratio_text(row["ratio"]) if flown else "–", RunHud._thousands(row["best_score"]) if flown else "–",
				str(row["best_wave"]) if flown else "–"]:
			grid.add_child(MenuKit.label(text, 28, colour))


func on_back() -> void:
	Router.goto_main_menu()

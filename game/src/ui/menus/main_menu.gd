extends Control
## The main menu (PLAN.md 6.1), in placeholder chrome over a drifting starfield.
##
## - The profile card (owner's layout, 2026-10-26): the pilot, their best WaveTime, kills /
##   deaths and Story progress. Editing arrives with profiles (6.2); WaveTime uses the dev
##   profile until then.
## - Creative: the hangar with everything free (no profile stock).
## - WaveTime: the hangar building from the profile's stock (4.8); the run loop is Phase 8, so
##   for now Fly is the test flight. (Debug builds can reset the stock from that hangar.)
## - Story: locked until Phase 9.
## - Tutorials (the WaveTime and Story tutorials, and the enemy gallery), Settings and Credits:
##   their screens.
##
## Built in code rather than authored in the editor, so the editor cannot silently reformat it.

const HANGAR := "res://scenes/hangar/hangar.tscn"
const TUTORIALS := "res://scenes/menu/tutorials.tscn"
const SETTINGS := "res://scenes/menu/settings.tscn"
const CREDITS := "res://scenes/menu/credits.tscn"
## The profile WaveTime builds from until 6.2 lets the player pick one.
const DEV_PROFILE := "dev"
## Heading sizes: the title (H1), the pilot's name on the card (H3, ProfileCard), the modes (H4).
const TITLE_SIZE := 72
const MODE_TITLE_SIZE := 32
const MODE_SIZE := Vector2(250, 120)
const MODE_GAP := 16
const BUTTON_SIZE := Vector2(200, 60)
const BUTTON_GAP := 12


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(MenuBackdrop.new())

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 14)
	center.add_child(column)

	column.add_child(MenuKit.label("MSS", TITLE_SIZE))
	column.add_child(MenuKit.label("Mobile Space Shooter  v%s" % ProjectSettings.get_setting("application/config/version"),
			20, Color(1, 1, 1, 0.6)))
	if not Data.errors.is_empty():
		column.add_child(MenuKit.label("%d data file error(s), see the log" % Data.errors.size(), 20, Color(1.0, 0.35, 0.35)))

	var card := ProfileCard.new()
	card.name = "ProfileCard"
	column.add_child(card)
	card.size_to(MODE_SIZE.x * 3 + MODE_GAP * 2)
	card.show_profile(Profiles.summary(DEV_PROFILE))

	var modes := _row(column, MODE_GAP)
	modes.add_child(MenuKit.tile("Creative", "Build anything, free", func() -> void: _enter(""), "Creative",
			MODE_SIZE, MODE_TITLE_SIZE))
	modes.add_child(MenuKit.tile("WaveTime", "Build from what you earn", func() -> void: _enter(DEV_PROFILE), "WaveTime",
			MODE_SIZE, MODE_TITLE_SIZE))
	modes.add_child(MenuKit.tile("Story", "Locked: arrives in Phase 9", Callable(), "Story", MODE_SIZE, MODE_TITLE_SIZE))

	_row(column, BUTTON_GAP).add_child(MenuKit.button("Tutorials", func() -> void: Router.goto(TUTORIALS),
			Vector2(BUTTON_SIZE.x * 2 + BUTTON_GAP, BUTTON_SIZE.y)))
	var more := _row(column, BUTTON_GAP)
	more.add_child(MenuKit.button("Settings", func() -> void: Router.goto(SETTINGS), BUTTON_SIZE))
	more.add_child(MenuKit.button("Credits", func() -> void: Router.goto(CREDITS), BUTTON_SIZE))


## Into the hangar: Creative with no profile, WaveTime building from `profile_id`'s stock.
func _enter(profile_id: String) -> void:
	Profiles.active_id = profile_id
	Router.goto(HANGAR)


func _row(parent: Control, gap: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", gap)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	return row

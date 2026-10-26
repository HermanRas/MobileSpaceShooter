extends Control
## The main menu (PLAN.md 6.1), in placeholder chrome over a drifting starfield.
##
## - The profile card (owner's layout, 2026-10-26): the selected pilot, their best WaveTime,
##   kills / deaths and Story progress; its Pilots button opens the pilots (6.2).
## - Creative: the hangar with everything free (no profile stock).
## - WaveTime: the hangar building from the selected pilot's stock (4.8); with no pilot yet, the
##   character screen makes one first. The run loop is Phase 8, so for now Fly is the test
##   flight. (Debug builds can reset the stock from that hangar.)
## - Story: locked until Phase 9.
## - Tutorials (the WaveTime and Story tutorials, and the enemy gallery), Settings and Credits:
##   their screens.
##
## The back button asks before quitting.
##
## Built in code rather than authored in the editor, so the editor cannot silently reformat it.

const HANGAR := "res://scenes/hangar/hangar.tscn"
const TUTORIALS := "res://scenes/menu/tutorials.tscn"
const SETTINGS := "res://scenes/menu/settings.tscn"
const CREDITS := "res://scenes/menu/credits.tscn"
const CHARACTER := "res://scenes/menu/character.tscn"
## Heading sizes: the title (H1), the pilot's name on the card (H3, ProfileCard), the modes (H4).
const TITLE_SIZE := 72
const MODE_TITLE_SIZE := 32
const MODE_SIZE := Vector2(250, 120)
const MODE_GAP := 16
const BUTTON_SIZE := Vector2(200, 60)
const BUTTON_GAP := 12

var _quit := ConfirmPanel.new()


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
	var pilot := Profiles.selected()
	card.show_profile(Profiles.summary(Profiles.selected_id), pilot.character if pilot != null else {})

	var modes := _row(column, MODE_GAP)
	modes.add_child(MenuKit.tile("Creative", "Build anything, free", func() -> void: _enter(""), "Creative",
			MODE_SIZE, MODE_TITLE_SIZE))
	modes.add_child(MenuKit.tile("WaveTime", "Build from what you earn", _wave_time, "WaveTime",
			MODE_SIZE, MODE_TITLE_SIZE))
	modes.add_child(MenuKit.tile("Story", "Locked: arrives in Phase 9", Callable(), "Story", MODE_SIZE, MODE_TITLE_SIZE))

	_row(column, BUTTON_GAP).add_child(MenuKit.button("Tutorials", func() -> void: Router.goto(TUTORIALS),
			Vector2(BUTTON_SIZE.x * 2 + BUTTON_GAP, BUTTON_SIZE.y)))
	var more := _row(column, BUTTON_GAP)
	more.add_child(MenuKit.button("Settings", func() -> void: Router.goto(SETTINGS), BUTTON_SIZE))
	more.add_child(MenuKit.button("Credits", func() -> void: Router.goto(CREDITS), BUTTON_SIZE))
	_quit.name = "ConfirmQuit"
	add_child(_quit)


## The Android back button asks before quitting, so it never quits by accident (6.5).
func on_back() -> void:
	if _quit.visible:
		_quit.close()
	else:
		_quit.ask("Quit MSS?", "Quit", func() -> void: get_tree().quit(), "QuitConfirm")


## WaveTime builds from the selected pilot's stock; with no pilot yet, make one first.
func _wave_time() -> void:
	if Profiles.selected() == null:
		Profiles.editing_id = ""
		Profiles.edit_return = Router.MAIN_MENU
		Router.goto(CHARACTER)
		return
	_enter(Profiles.selected_id)


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

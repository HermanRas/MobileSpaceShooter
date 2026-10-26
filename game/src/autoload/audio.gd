extends Node
## SFX and music by ID, through `data/audio.json`. The sounds arrive in Phase 14.
##
## Calls are safe before any audio exists: an unknown ID is a no-op, not an error. The Music and
## SFX buses exist from the start, at the volumes in Settings (6.4), so every player made later
## only needs to name its bus.

const MUSIC := &"Music"
const SFX := &"SFX"


func _ready() -> void:
	for bus in [MUSIC, SFX]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, &"Master")
	_apply(&"music_volume")
	_apply(&"sfx_volume")
	Settings.changed.connect(_apply)


func play_sfx(_id: StringName) -> void:
	pass


func play_music(_id: StringName) -> void:
	pass


## A volume setting (0..1) onto its bus; 0 mutes it.
func _apply(key: StringName) -> void:
	var bus := {&"music_volume": MUSIC, &"sfx_volume": SFX}.get(key, &"") as StringName
	if bus == &"":
		return
	var index := AudioServer.get_bus_index(bus)
	var level := clampf(float(Settings.get_value(key)), 0.0, 1.0)
	AudioServer.set_bus_mute(index, level <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.001)))

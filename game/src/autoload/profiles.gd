extends Node
## The profile list and the active profile. Filled in by Phase 6.2.
##
## Each profile owns `user://profiles/<id>/`; the device-wide blueprint library lives outside
## that, in `user://library/` (D6).

const ROOT := "user://profiles"
## A profile's name and record (6.1's profile card reads it; 6.2 and the modes write it).
const SUMMARY_FILE := "profile.json"
const SUMMARY_DEFAULTS := {
	"name": "Pilot",
	"best_wave_s": 0,
	"kills": 0,
	"deaths": 0,
	"story_pct": 0,
	"jobs": 0,
}

var active_id: String = ""


func profile_dir(id: String) -> String:
	return ROOT.path_join(id)


## What the profile card shows for profile `id`: SUMMARY_DEFAULTS, overlaid with what its
## `profile.json` holds.
func summary(id: String) -> Dictionary:
	var out := SUMMARY_DEFAULTS.duplicate()
	var saved := Save.read_json(profile_dir(id).path_join(SUMMARY_FILE))
	for key: String in SUMMARY_DEFAULTS:
		if saved.has(key) and typeof(saved[key]) in [TYPE_STRING, TYPE_INT, TYPE_FLOAT]:
			out[key] = saved[key]
	return out

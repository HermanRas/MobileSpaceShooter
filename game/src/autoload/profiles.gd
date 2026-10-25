extends Node
## The profile list and the active profile. Filled in by Phase 6.2.
##
## Each profile owns `user://profiles/<id>/`; the device-wide blueprint library lives outside
## that, in `user://library/` (D6).

const ROOT := "user://profiles"

var active_id: String = ""


func profile_dir(id: String) -> String:
	return ROOT.path_join(id)

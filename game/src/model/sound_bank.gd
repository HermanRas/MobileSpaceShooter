class_name SoundBank
extends RefCounted
## The sound table (PLAN.md 14.1, `data/audio.json`): every sound ID with its files and how it
## plays, and the rules that stop a gatling burying the mix. The Audio autoload plays what this
## allows; this decides, so it can be tested headless.
##
## A sound plays at `db`, its pitch jittered by up to ±`pitch` (0.05 = 5%), cycling its files
## without playing one twice running. At most `voices` of it sound at once, and a new one waits
## `gap_s` after the last: shots fired faster than that fold into the one already playing.

## One sound ID's row.
class Entry:
	var files: PackedStringArray = []
	var db := 0.0
	var pitch := 0.0
	var voices := 4
	var gap_s := 0.0
	var loop := false
	var next := 0
	var live := 0
	var last_s := -INF


var entries := {}
var music := {}
## Shots from enemy ships play this much quieter than the player's own.
var enemy_db := -6.0
## Positional sounds fade to nothing this far from the camera (U), along this curve.
var max_distance_u := 40.0
var attenuation := 1.5
var music_fade_s := 1.2
## A ship at least this long (U) blows up with `boom.big`, not `boom.small`.
var big_boom_u := 6.0
## Scene path -> the music it plays; any other scene plays `default_music`.
var music_for_scene := {}
var default_music := &""
## Rows that couldn't be read, as messages.
var errors: PackedStringArray = []


static func from_table(table: Dictionary) -> SoundBank:
	var bank := SoundBank.new()
	bank.enemy_db = float(table.get("enemy_db", bank.enemy_db))
	bank.max_distance_u = float(table.get("max_distance_u", bank.max_distance_u))
	bank.attenuation = float(table.get("attenuation", bank.attenuation))
	bank.music_fade_s = float(table.get("music_fade_s", bank.music_fade_s))
	bank.big_boom_u = float(table.get("big_boom_u", bank.big_boom_u))
	bank.default_music = StringName(table.get("default_music", ""))
	var scenes: Dictionary = table.get("music_for_scene", {})
	for path: String in scenes:
		bank.music_for_scene[path] = StringName(scenes[path])
	var sounds: Dictionary = table.get("sounds", {})
	for id: String in sounds:
		if id.begins_with("_"):
			continue
		var row: Variant = sounds[id]
		if not row is Dictionary or not (row as Dictionary).get("files") is Array or (row["files"] as Array).is_empty():
			bank.errors.append("sound %s: needs a list of files" % id)
			continue
		var entry := Entry.new()
		for file: Variant in row["files"]:
			entry.files.append(str(file))
		entry.db = float(row.get("db", 0.0))
		entry.pitch = clampf(float(row.get("pitch", 0.0)), 0.0, 0.5)
		entry.voices = maxi(int(row.get("voices", entry.voices)), 1)
		entry.gap_s = maxf(float(row.get("gap_s", 0.0)), 0.0)
		entry.loop = bool(row.get("loop", false))
		bank.entries[StringName(id)] = entry
	var tracks: Dictionary = table.get("music", {})
	for id: String in tracks:
		if id.begins_with("_"):
			continue
		var track: Variant = tracks[id]
		if not track is Dictionary or str((track as Dictionary).get("file", "")).is_empty():
			bank.errors.append("music %s: needs a file" % id)
			continue
		bank.music[StringName(id)] = {"file": str(track["file"]), "db": float(track.get("db", 0.0))}
	return bank


func has(id: StringName) -> bool:
	return entries.has(id)


func entry(id: StringName) -> Entry:
	return entries.get(id) as Entry


## Whether `id` may start at `now_s`: known, under its voice cap and past its gap.
func may_play(id: StringName, now_s: float) -> bool:
	var e := entry(id)
	return e != null and e.live < e.voices and now_s - e.last_s >= e.gap_s


## `id` started at `now_s`: counts its voice and returns which of its files to play, the next in
## turn (so none plays twice running).
func started(id: StringName, now_s: float) -> String:
	var e := entry(id)
	e.live += 1
	e.last_s = now_s
	var file := e.files[e.next % e.files.size()]
	e.next = (e.next + 1) % e.files.size()
	return file


## A voice of `id` stopped.
func finished(id: StringName) -> void:
	var e := entry(id)
	if e != null:
		e.live = maxi(e.live - 1, 0)


## The pitch scale for a play of `id`, from a roll in 0..1.
func pitch_for(id: StringName, roll: float) -> float:
	var e := entry(id)
	return 1.0 + (roll * 2.0 - 1.0) * e.pitch if e != null else 1.0


## The music for a scene.
func music_for(scene_path: String) -> StringName:
	return music_for_scene.get(scene_path, default_music)

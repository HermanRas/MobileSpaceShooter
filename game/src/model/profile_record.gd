class_name ProfileRecord
extends RefCounted
## One pilot (PLAN.md 6.2, D2): a name, a character (D3: a base and four colours), and the
## record the menus show (best WaveTime, kills, deaths, Story %, jobs). Saved as
## `<profile dir>/profile.json`; the profile's stock is beside it (StockStore).

const FORMAT := 1
const REGIONS: Array[String] = ["hair", "eyes", "outfit", "trim"]
const STATS := {"best_wave_s": 0, "kills": 0, "deaths": 0, "story_pct": 0, "jobs": 0}

var id := ""
var name := ""
## {"base": "male" | "female", "hair", "eyes", "outfit", "trim": "#rrggbb"}
var character := {}
var stats := STATS.duplicate()
## Unix seconds; the pilots list in this order.
var created := 0


## A new pilot: `raw_name` cleaned, the first base and the first swatch of each region from
## `table` (data/characters.json).
static func create(raw_name: String, table: Dictionary, taken: Array, now: int) -> ProfileRecord:
	var record := ProfileRecord.new()
	record.name = clean_name(raw_name, int(table.get("name_max", 16)))
	record.id = make_id(record.name, taken)
	record.character = default_character(table)
	record.created = now
	return record


static func default_character(table: Dictionary) -> Dictionary:
	var bases: Array = table.get("bases", ["male"])
	var out := {"base": str(bases[0])}
	for region in REGIONS:
		var swatches: Array = table.get("swatches", {}).get(region, ["#ffffff"])
		out[region] = str(swatches[0])
	return out


## Trimmed, inner runs of spaces made one, no control characters, at most `max_length`.
static func clean_name(raw: String, max_length: int) -> String:
	var kept := ""
	for c in raw.strip_edges():
		if c in ["\t", "\n", "\r"]:
			kept += " "
		elif c.unicode_at(0) >= 32:
			kept += c
	var words := kept.split(" ", false)
	return " ".join(words).left(max_length).strip_edges()


## A folder-safe id from `name` (a–z, 0–9 and dashes), "pilot" if nothing is left, made unique
## against `taken` with -2, -3…
static func make_id(from_name: String, taken: Array) -> String:
	var slug := ""
	for c in from_name.to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			slug += c
		elif not slug.is_empty() and not slug.ends_with("-"):
			slug += "-"
	slug = slug.trim_suffix("-")
	if slug.is_empty():
		slug = "pilot"
	var out := slug
	var n := 2
	while taken.has(out):
		out = "%s-%d" % [slug, n]
		n += 1
	return out


## The menus' view of it: the name and the record (ProfileCard.show_profile).
func summary() -> Dictionary:
	var out := stats.duplicate()
	out["name"] = name
	return out


func to_dict() -> Dictionary:
	return {"format": FORMAT, "id": id, "name": name, "character": character.duplicate(), "stats": stats.duplicate(),
			"created": created}


## A saved pilot; anything missing or of the wrong type falls back to a default (noted in `errors`).
static func from_dict(data: Dictionary, table: Dictionary, errors: PackedStringArray) -> ProfileRecord:
	var record := ProfileRecord.new()
	record.id = str(data.get("id", ""))
	record.name = clean_name(str(data.get("name", "")), int(table.get("name_max", 16)))
	if record.id.is_empty() or record.name.is_empty():
		errors.append("profile: no id or name")
	record.character = default_character(table)
	var saved_character: Variant = data.get("character", {})
	if typeof(saved_character) == TYPE_DICTIONARY:
		if (table.get("bases", []) as Array).has(saved_character.get("base")):
			record.character["base"] = saved_character["base"]
		for region in REGIONS:
			var colour: Variant = saved_character.get(region)
			if typeof(colour) == TYPE_STRING and Color.html_is_valid(colour):
				record.character[region] = colour
	var saved_stats: Variant = data.get("stats", {})
	if typeof(saved_stats) == TYPE_DICTIONARY:
		for key: String in STATS:
			if typeof(saved_stats.get(key)) in [TYPE_INT, TYPE_FLOAT]:
				record.stats[key] = int(saved_stats[key])
	record.created = int(data.get("created", 0))
	return record

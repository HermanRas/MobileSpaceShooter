class_name Blueprint
extends RefCounted
## A ship design: tiles, mounts and paint (PLAN.md 5.4). Player ships, enemies, VIPs, bosses
## and stations are all blueprints.
##
## This class only reads, writes and structurally checks the format. Whether the design is
## buildable (overlaps, connectivity, one core) is `Placement.validate()` (Phase 1.4). Cost
## and stats are always computed, never stored.

const FORMAT := 1

## One placed tile.
class Tile:
	var id: int
	var type: StringName
	var shape: StringName
	var size: StringName
	## Position of the shape's origin, in U.
	var pos: Vector2
	## Rotation in steps of `rotation_step_deg` (15°).
	var rot: int
	var paint: Color

	func to_dict() -> Dictionary:
		return {
			"id": id, "type": String(type), "shape": String(shape), "size": String(size),
			"pos": [pos.x, pos.y], "rot": rot, "paint": "#" + paint.to_html(false),
		}


var id: String = ""
var name: String = ""
var author: String = ""
var tags: PackedStringArray = []
var tiles: Array[Tile] = []
## Thruster and weapon mounts. Kept as plain dictionaries until Phases 3.2 and 4.3 define them.
var mounts: Array[Dictionary] = []


func tile_by_id(tile_id: int) -> Tile:
	for tile in tiles:
		if tile.id == tile_id:
			return tile
	return null


func next_tile_id() -> int:
	var highest := -1
	for tile in tiles:
		highest = maxi(highest, tile.id)
	return highest + 1


func to_dict() -> Dictionary:
	var tile_dicts: Array = []
	for tile in tiles:
		tile_dicts.append(tile.to_dict())
	return {
		"format": FORMAT, "id": id, "name": name, "author": author,
		"tags": Array(tags), "tiles": tile_dicts, "mounts": mounts.duplicate(true),
	}


## Parses a blueprint. Returns null and appends readable messages to `errors` when the data
## is malformed; never crashes on bad input.
static func from_dict(data: Dictionary, errors: PackedStringArray) -> Blueprint:
	var migrated := migrate(data, errors)
	if migrated.is_empty():
		return null
	var bp := Blueprint.new()
	bp.id = str(migrated.get("id", ""))
	bp.name = str(migrated.get("name", ""))
	bp.author = str(migrated.get("author", ""))
	for tag: Variant in migrated.get("tags", []):
		bp.tags.append(str(tag))
	if bp.id.is_empty():
		errors.append("blueprint has no id")

	var raw_tiles: Variant = migrated.get("tiles")
	if typeof(raw_tiles) != TYPE_ARRAY:
		errors.append("%s: `tiles` must be a list" % bp.id)
		return null
	var seen_ids := {}
	for i in raw_tiles.size():
		var tile := _parse_tile(raw_tiles[i], "%s tile #%d" % [bp.id, i], errors)
		if tile == null:
			continue
		if seen_ids.has(tile.id):
			errors.append("%s: duplicate tile id %d" % [bp.id, tile.id])
			continue
		seen_ids[tile.id] = true
		bp.tiles.append(tile)

	for mount: Variant in migrated.get("mounts", []):
		if typeof(mount) == TYPE_DICTIONARY:
			bp.mounts.append(_whole_numbers_as_ints(mount))
		else:
			errors.append("%s: every mount must be an object" % bp.id)
	return null if not errors.is_empty() else bp


## Brings older formats up to FORMAT. Returns {} (and an error) for a format this build
## doesn't understand. Add one step per format bump; never edit an old step.
static func migrate(data: Dictionary, errors: PackedStringArray) -> Dictionary:
	var format: Variant = data.get("format")
	if typeof(format) not in [TYPE_INT, TYPE_FLOAT]:
		errors.append("blueprint has no `format` field")
		return {}
	if int(format) > FORMAT:
		errors.append("blueprint format %d is newer than this game (%d); update the game" % [format, FORMAT])
		return {}
	if int(format) < 1:
		errors.append("blueprint format %d is not supported" % format)
		return {}
	return data


## JSON reads every number as a float, so an untyped mount's `"edge": 2` would come back as
## 2.0 and drift on every save. Tiles don't need this: they're parsed into typed fields.
static func _whole_numbers_as_ints(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			return int(value) if value == floorf(value) else value
		TYPE_DICTIONARY:
			var out := {}
			for key: Variant in value:
				out[key] = _whole_numbers_as_ints(value[key])
			return out
		TYPE_ARRAY:
			return (value as Array).map(_whole_numbers_as_ints)
	return value


static func _parse_tile(raw: Variant, where: String, errors: PackedStringArray) -> Tile:
	if typeof(raw) != TYPE_DICTIONARY:
		errors.append("%s: must be an object" % where)
		return null
	var d: Dictionary = raw
	for key in ["id", "rot"]:
		if typeof(d.get(key)) not in [TYPE_INT, TYPE_FLOAT] or float(d[key]) != floorf(float(d[key])):
			errors.append("%s: `%s` must be a whole number" % [where, key])
			return null
	for key in ["type", "shape", "size"]:
		if typeof(d.get(key)) != TYPE_STRING or (d[key] as String).is_empty():
			errors.append("%s: `%s` must be a name" % [where, key])
			return null
	var pos: Variant = d.get("pos")
	if typeof(pos) != TYPE_ARRAY or pos.size() != 2 \
			or typeof(pos[0]) not in [TYPE_INT, TYPE_FLOAT] or typeof(pos[1]) not in [TYPE_INT, TYPE_FLOAT]:
		errors.append("%s: `pos` must be [x, y]" % where)
		return null
	var paint := str(d.get("paint", "#808080"))
	if not Color.html_is_valid(paint):
		errors.append("%s: `paint` '%s' is not a colour" % [where, paint])
		return null
	var tile := Tile.new()
	tile.id = int(d["id"])
	tile.type = StringName(d["type"])
	tile.shape = StringName(d["shape"])
	tile.size = StringName(d["size"])
	tile.pos = Vector2(pos[0], pos[1])
	tile.rot = int(d["rot"])
	tile.paint = Color.html(paint)
	return tile

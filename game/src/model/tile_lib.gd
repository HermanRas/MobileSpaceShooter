class_name TileLib
extends RefCounted
## Every tile type from `data/tiles.json` (PLAN.md 4.2).

var materials: Array[StringName] = []
var errors: PackedStringArray = []

var _tiles: Dictionary = {}


static func from_table(table: Dictionary) -> TileLib:
	var lib := TileLib.new()
	for material: String in table.get("materials", []):
		lib.materials.append(StringName(material))
	var stat_factor := _factors(table.get("size_stat_factor", {}))
	var cost_factor := _factors(table.get("size_cost_factor", {}))
	if stat_factor.is_empty() or cost_factor.is_empty():
		lib.errors.append("size_stat_factor and size_cost_factor are required")
	for tile_id: String in table.get("tiles", {}):
		var tile := TileDef.from_def(StringName(tile_id), table["tiles"][tile_id],
				stat_factor, cost_factor, lib.materials, lib.errors)
		if tile != null:
			lib._tiles[tile.id] = tile
	var unique_count := lib._tiles.values().filter(func(t: TileDef) -> bool: return t.unique).size()
	if unique_count != 1:
		lib.errors.append("exactly one tile type must be unique (the core), found %d" % unique_count)
	return lib


func tile(tile_id: StringName) -> TileDef:
	return _tiles.get(tile_id)


func tile_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_tiles.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


## The one tile type a ship must have exactly one of.
func core_id() -> StringName:
	for tile: TileDef in _tiles.values():
		if tile.unique:
			return tile.id
	return &""


static func _factors(raw: Dictionary) -> Dictionary:
	var out := {}
	for code: String in raw:
		out[StringName(code)] = float(raw[code])
	return out

class_name HangarEditor
extends RefCounted
## Every edit the hangar can make to a blueprint, with undo/redo and mirror mode (Phase 2.3).
##
## The hangar UI only calls this; it never touches the blueprint directly, so every rule here
## is tested headless. Undo stores a whole-blueprint snapshot per step, which at 150 tiles is
## small and makes "undo restores exactly" true by construction.

signal changed

const UNDO_DEPTH := 100
const DEFAULT_PAINT := Color(0.55, 0.59, 0.63)

var placement: Placement
var blueprint: Blueprint
## Every placement, removal, move and paint is mirrored across the horizontal line through the
## core's centre (the ship's forward axis).
var mirror: bool = false

var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []


static func create(shared_placement: Placement, bp: Blueprint = null) -> HangarEditor:
	var editor := HangarEditor.new()
	editor.placement = shared_placement
	if bp != null:
		editor.blueprint = bp
	else:
		editor.new_ship("New ship")
	return editor


## A fresh blueprint holding only a Large square core at the origin.
func new_ship(ship_name: String) -> void:
	var bp := Blueprint.new()
	bp.id = "ship_%d" % Time.get_unix_time_from_system()
	bp.name = ship_name
	var core := Blueprint.Tile.new()
	core.id = 0
	core.type = placement.tiles.core_id()
	core.shape = &"square"
	core.size = &"L"
	core.paint = Color(0.85, 0.85, 0.85)
	bp.tiles.append(core)
	load_blueprint(bp)


func load_blueprint(bp: Blueprint) -> void:
	blueprint = bp
	_undo.clear()
	_redo.clear()
	changed.emit()


func core_tile() -> Blueprint.Tile:
	for tile in blueprint.tiles:
		if tile.type == placement.tiles.core_id():
			return tile
	return null


func axis_y() -> float:
	var core := core_tile()
	return ShipStats.polygon_centroid(placement.tile_polygon(core)).y if core != null else 0.0


## Adds a tile (and its mirror image when mirror mode is on and the image fits). The caller is
## expected to pass a position from `Placement.candidate_snaps()`. Returns the new tile ids,
## or an empty array if the tile overlaps something.
func place(type: StringName, shape: StringName, size: StringName, pos: Vector2, rot: int,
		paint: Color = DEFAULT_PAINT) -> PackedInt32Array:
	var tile := _make_tile(type, shape, size, pos, rot, paint)
	if not placement.footprint_free(blueprint, placement.tile_polygon(tile)):
		return PackedInt32Array()
	_checkpoint()
	blueprint.tiles.append(tile)
	var added := PackedInt32Array([tile.id])
	var twin := _mirror_twin(tile)
	if twin != null:
		blueprint.tiles.append(twin)
		added.append(twin.id)
	changed.emit()
	return added


## Removes a tile (and its mirror image). The core can't be removed. Tiles left disconnected
## stay, and validation flags them, so nothing vanishes without the player seeing why.
func remove(tile_id: int) -> bool:
	var tile := blueprint.tile_by_id(tile_id)
	if tile == null or tile.type == placement.tiles.core_id():
		return false
	_checkpoint()
	var twin_id := _existing_twin_id(tile)
	blueprint.tiles.erase(tile)
	if twin_id >= 0:
		blueprint.tiles.erase(blueprint.tile_by_id(twin_id))
	changed.emit()
	return true


## Moves a tile to a new snapped spot in one undo step. Its mirror image is moved with it.
func move(tile_id: int, pos: Vector2, rot: int) -> bool:
	var tile := blueprint.tile_by_id(tile_id)
	if tile == null or tile.type == placement.tiles.core_id():
		return false
	var twin_id := _existing_twin_id(tile)
	var moved := _make_tile(tile.type, tile.shape, tile.size, pos, rot, tile.paint)
	moved.id = tile.id
	var ignore := PackedInt32Array([tile.id, twin_id])
	if not placement.footprint_free(blueprint, placement.tile_polygon(moved), ignore):
		return false
	_checkpoint()
	tile.pos = pos
	tile.rot = rot
	if twin_id >= 0:
		var image := placement.mirrored(tile, axis_y())
		var twin := blueprint.tile_by_id(twin_id)
		if not image.is_empty() and _footprint_key(tile) != _footprint_key_at(twin, image):
			twin.pos = image["pos"]
			twin.rot = image["rot"]
		else:
			blueprint.tiles.erase(twin)
	changed.emit()
	return true


func paint_tiles(tile_ids: PackedInt32Array, color: Color) -> void:
	var ids := tile_ids.duplicate()
	if mirror:
		for tile_id in tile_ids:
			var tile := blueprint.tile_by_id(tile_id)
			if tile != null:
				var twin_id := _existing_twin_id(tile)
				if twin_id >= 0 and not ids.has(twin_id):
					ids.append(twin_id)
	_paint(blueprint.tiles.filter(func(t: Blueprint.Tile) -> bool: return ids.has(t.id)), color)


func paint_type(type: StringName, color: Color) -> void:
	_paint(blueprint.tiles.filter(func(t: Blueprint.Tile) -> bool: return t.type == type), color)


func paint_all(color: Color) -> void:
	_paint(blueprint.tiles, color)


## The id of `tile_id`'s mirror image while mirror mode is on, or -1.
func twin_of(tile_id: int) -> int:
	var tile := blueprint.tile_by_id(tile_id)
	return _existing_twin_id(tile) if tile != null else -1


## A copy of the blueprint without the given tiles, for computing where they could go instead.
func blueprint_without(tile_ids: PackedInt32Array) -> Blueprint:
	var errors: PackedStringArray = []
	var copy := Blueprint.from_dict(blueprint.to_dict(), errors)
	copy.tiles = copy.tiles.filter(func(t: Blueprint.Tile) -> bool: return not tile_ids.has(t.id))
	return copy


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func undo() -> bool:
	if _undo.is_empty():
		return false
	_redo.append(blueprint.to_dict())
	_restore(_undo.pop_back())
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	_undo.append(blueprint.to_dict())
	_restore(_redo.pop_back())
	return true


func _paint(tiles: Array, color: Color) -> void:
	if tiles.is_empty():
		return
	_checkpoint()
	for tile: Blueprint.Tile in tiles:
		tile.paint = color
	changed.emit()


func _checkpoint() -> void:
	_undo.append(blueprint.to_dict())
	if _undo.size() > UNDO_DEPTH:
		_undo.pop_front()
	_redo.clear()


func _restore(snapshot: Dictionary) -> void:
	var errors: PackedStringArray = []
	var restored := Blueprint.from_dict(snapshot, errors)
	assert(restored != null, "undo snapshot failed to parse: %s" % ", ".join(errors))
	blueprint = restored
	changed.emit()


func _make_tile(type: StringName, shape: StringName, size: StringName, pos: Vector2, rot: int,
		paint: Color) -> Blueprint.Tile:
	var tile := Blueprint.Tile.new()
	tile.id = blueprint.next_tile_id()
	tile.type = type
	tile.shape = shape
	tile.size = size
	tile.pos = pos
	tile.rot = posmod(rot, placement.shapes.rotation_steps())
	tile.paint = paint
	return tile


## The mirror image of a just-added tile, or null when mirror is off, the tile sits on the axis
## (it is its own image), or the image would overlap something.
func _mirror_twin(tile: Blueprint.Tile) -> Blueprint.Tile:
	if not mirror:
		return null
	var image := placement.mirrored(tile, axis_y())
	if image.is_empty():
		return null
	var twin := _make_tile(tile.type, tile.shape, tile.size, image["pos"], image["rot"], tile.paint)
	twin.id = tile.id + 1
	var polygon := placement.tile_polygon(twin)
	if Placement._polygon_key(polygon) == _footprint_key(tile):
		return null
	if not placement.footprint_free(blueprint, polygon):
		return null
	return twin


func _existing_twin_id(tile: Blueprint.Tile) -> int:
	if not mirror:
		return -1
	var image := placement.mirrored(tile, axis_y())
	if image.is_empty():
		return -1
	var polygon := placement.shapes.polygon(tile.shape, tile.size, image["rot"], image["pos"])
	var twin_id := placement.tile_with_footprint(blueprint, polygon)
	return twin_id if twin_id != tile.id else -1


func _footprint_key(tile: Blueprint.Tile) -> String:
	return Placement._polygon_key(placement.tile_polygon(tile))


func _footprint_key_at(tile: Blueprint.Tile, at: Dictionary) -> String:
	return Placement._polygon_key(placement.shapes.polygon(tile.shape, tile.size, at["rot"], at["pos"]))

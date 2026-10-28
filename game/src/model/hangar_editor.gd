class_name HangarEditor
extends RefCounted
## Every edit the hangar can make to a blueprint, with undo/redo and mirror mode (Phase 2.3).
##
## The hangar UI only calls this; it never touches the blueprint directly, so every rule here
## is tested headless. Undo stores a whole-blueprint snapshot per step (and the stock's, when
## building costs), which at 150 tiles is small and makes "undo restores exactly" true by
## construction.
##
## Outside Creative the editor has a `stock` (PLAN.md 4.8a), and every edit is settled with it
## as it's made: new tiles pay their materials, removed ones give them back 1:1; a part comes
## from the shop (paying its price) or the inventory (free, but a gun put on another mount type
## pays the refit); a removed part goes back in the inventory, or is sold for the sell rate. An
## edit that can't be paid for is undone, and `refusal` says why.

signal changed

const UNDO_DEPTH := 100
const DEFAULT_PAINT := Color(0.55, 0.59, 0.63)
## Where a new part comes from: bought, out of the inventory, or the inventory first and the
## shop for the rest (a bought ship, 7.3).
const SHOP := &"shop"
const STOCK := &"stock"
const EITHER := &"either"

var placement: Placement
var blueprint: Blueprint
## Every placement, removal, move and paint is mirrored across the horizontal line through the
## core's centre (the ship's forward axis).
var mirror: bool = false
## The profile's stock, or null in Creative, where everything is free. Undo replaces the object,
## so read it from here each time.
var stock: Inventory
var economy: Economy
## Why the last refused edit was refused ("Not enough alloy"), or "".
var refusal := ""

var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _redo_held: Array[Dictionary] = []


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
	if not _settle(SHOP):
		return PackedInt32Array()
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
	_drop_mounts_of(tile_id)
	if twin_id >= 0:
		blueprint.tiles.erase(blueprint.tile_by_id(twin_id))
		_drop_mounts_of(twin_id)
	_settle(&"")
	changed.emit()
	return true


## Mounts a thruster in a slot from `Mounting.thruster_slots()` (and its mirror image when
## mirror mode is on and the image's slot is free). Returns the new mount indices, or an empty
## array if the slot isn't free or it can't be paid for. `from_stock`: a loose one from the
## inventory rather than a bought one (a mirror image with none left to take is left off).
func add_thruster(type_id: StringName, size: StringName, level: int, slot: Dictionary,
		from_stock := false) -> PackedInt32Array:
	return _add_mount(Mounting.moved_to({"part": ThrusterLib.part_id(type_id), "size": String(size), "level": level}, slot),
			STOCK if from_stock else SHOP)


## Mounts a gun in a slot from `Mounting.weapon_slots()`, the same way. A mode its mount type
## doesn't allow is replaced by one it does (a turret is always auto). `item`: the loose gun from
## the inventory to fit, rather than a bought one. `level`: in Creative (no stock), the gun's own
## level (PLAN.md 7.1), kept on the mount; a stocked gun's level comes from its XP instead.
func add_weapon(weapon_id: StringName, mount_type: StringName, mode: StringName, slot: Dictionary,
		item := "", level := 0) -> PackedInt32Array:
	var resolved := placement.weapons.mode_for(mount_type, mode) if placement.weapons != null else mode
	var mount := {"part": WeaponLib.part_id(weapon_id), "mount": String(mount_type), "mode": String(resolved)}
	if not item.is_empty():
		mount["gun"] = item
	elif stock == null and level > 0:
		mount["level"] = _gun_level(level)
	return _add_mount(Mounting.moved_to(mount, slot), SHOP if item.is_empty() else STOCK)


## Switches a gun (and its mirror image) between manual and auto. False if it's not a gun, or its
## mount doesn't allow that mode.
func set_mount_mode(index: int, mode: StringName) -> bool:
	if index < 0 or index >= blueprint.mounts.size() or not Mounting.is_weapon(blueprint.mounts[index]):
		return false
	var mount := blueprint.mounts[index]
	var type := StringName(mount.get("mount", ""))
	if placement.weapons == null or placement.weapons.mode_for(type, mode) != mode or StringName(mount.get("mode", "")) == mode:
		return false
	_checkpoint()
	var host := blueprint.tile_by_id(int(mount["tile"]))
	var twin_id := _existing_twin_id(host) if host != null else -1
	if twin_id >= 0:
		var at := mount_index(Mounting.mirrored(placement, blueprint, mount, twin_id, axis_y()))
		if at >= 0 and blueprint.mounts[at]["part"] == mount["part"]:
			blueprint.mounts[at]["mode"] = String(mode)
	mount["mode"] = String(mode)
	changed.emit()
	return true


## Creative: sets a gun's (and its mirror image's) own level, clamped to L1 and the XP curve's
## top. False if it isn't a gun, the hangar is stocked, or the gun is at that level already.
func set_gun_level(index: int, level: int) -> bool:
	if stock != null or index < 0 or index >= blueprint.mounts.size() or not Mounting.is_weapon(blueprint.mounts[index]):
		return false
	var mount := blueprint.mounts[index]
	var to := _gun_level(level)
	if int(mount.get("level", 1)) == to:
		return false
	_checkpoint()
	var host := blueprint.tile_by_id(int(mount["tile"]))
	var twin_id := _existing_twin_id(host) if host != null else -1
	if twin_id >= 0:
		var at := mount_index(Mounting.mirrored(placement, blueprint, mount, twin_id, axis_y()))
		if at >= 0 and blueprint.mounts[at]["part"] == mount["part"]:
			blueprint.mounts[at]["level"] = to
	mount["level"] = to
	changed.emit()
	return true


func _gun_level(level: int) -> int:
	return clampi(level, 1, placement.weapons.xp.max_level if placement.weapons != null else 999)


## Removes a mount (and its mirror image); with a stock, the parts go in the inventory.
func remove_mount(index: int) -> bool:
	return _remove_mount(index, false)


## Sells a mount (and its mirror image) for the sell rate of its price. False in Creative.
func sell_mount(index: int) -> bool:
	return stock != null and _remove_mount(index, true)


## Buys (`amount` > 0) or sells (< 0) a material at the market (PLAN.md 4.6, 4.8c), as an undo
## step. False, with `refusal` saying why, when the wallet can't cover it.
func trade(material: StringName, amount: int) -> bool:
	refusal = ""
	var deal := economy.trade(material, amount) if stock != null and economy != null else []
	if deal.is_empty():
		return false
	var short := stock.short_of(deal[0])
	if short != &"":
		refusal = "Not enough %s" % ("GC" if short == Inventory.GC else String(short))
		return false
	_checkpoint()
	stock.pay(deal[0])
	stock.receive(deal[1])
	changed.emit()
	return true


## Sells a loose gun from the inventory.
func sell_gun(item: String) -> bool:
	if stock == null or not stock.guns.has(item) or Inventory.fitted_ids(blueprint).has(item):
		return false
	_checkpoint()
	var weapon: StringName = (stock.guns[item] as Inventory.GunItem).weapon
	stock.guns.erase(item)
	stock.receive(economy.sell_value(Economy.part_price(placement, {"part": WeaponLib.part_id(weapon)})))
	changed.emit()
	return true


## Sells one loose thruster (an `Inventory.thruster_key()`) from the inventory.
func sell_thruster(key: String) -> bool:
	if stock == null or int(stock.thrusters.get(key, 0)) <= 0:
		return false
	_checkpoint()
	var parts := Inventory.thruster_parts(key)
	stock.add_thrusters(key, -1)
	stock.receive(economy.sell_value(Economy.part_price(placement,
			{"part": ThrusterLib.part_id(parts[0]), "size": String(parts[1]), "level": parts[2]})))
	changed.emit()
	return true


func _remove_mount(index: int, selling: bool) -> bool:
	if index < 0 or index >= blueprint.mounts.size():
		return false
	_checkpoint()
	var mount := blueprint.mounts[index]
	var doomed: Array[Dictionary] = [mount]
	var host := blueprint.tile_by_id(int(mount["tile"]))
	var twin_id := _existing_twin_id(host) if host != null else -1
	if twin_id >= 0:
		var image := Mounting.mirrored(placement, blueprint, mount, twin_id, axis_y())
		var at := mount_index(image)
		if at >= 0 and at != index:
			doomed.append(blueprint.mounts[at])
	for gone in doomed:
		blueprint.mounts.erase(gone)
	_settle(&"", "", selling)
	changed.emit()
	return true


## Moves a mount (and its mirror image) to another slot, as one undo step.
func move_mount(index: int, slot: Dictionary) -> bool:
	if index < 0 or index >= blueprint.mounts.size():
		return false
	var mount := blueprint.mounts[index]
	var before := _snapshot()
	remove_mount(index)
	var added := _add_mount(Mounting.moved_to(mount, slot), STOCK)
	if added.is_empty():
		_undo.pop_back()
		_restore(before)
		return false
	_undo.pop_back()  # the in-between state; one undo goes back to before the move
	return true


## Stocked: rebuilds the ship as `design`, a library ship bought in the shop (PLAN.md 7.3), as one
## undo step. The old ship's tiles are refunded and its parts go in the inventory; the new one
## takes loose parts first (the most experienced gun of each kind) and buys the rest. Gun items
## and Creative gun levels in `design` are ignored. False, with `refusal`, if it can't be paid for.
func swap_to(design: Blueprint) -> bool:
	refusal = ""
	var errors: PackedStringArray = []
	var ship := Blueprint.from_dict(design.to_dict(), errors) if stock != null else null
	if ship == null:
		return false
	ship.tags.erase(Blueprint.PUBLISHED)
	for mount in ship.mounts:
		if Mounting.is_weapon(mount):
			mount.erase("gun")
			mount.erase("level")
	var before := _snapshot()
	# Strip the old ship first, so its guns are loose for the new one to take.
	_checkpoint()
	var stripped := Blueprint.new()
	stripped.id = blueprint.id  # an undo snapshot needs one to parse
	blueprint = stripped
	_settle(&"")
	_checkpoint()
	blueprint = ship
	if not _settle(EITHER):
		_undo.pop_back()
		var why := refusal
		_restore(before)
		refusal = why
		return false
	_undo.pop_back()  # the stripped state; one undo goes back to the old ship
	changed.emit()
	return true


## What swap_to(`design`) would cost now, without doing it: {"pay": {resource: net amount}, where
## a negative amount comes back, "refusal": why it can't be paid for, or ""}.
func quote_swap(design: Blueprint) -> Dictionary:
	var errors: PackedStringArray = []
	var trial := HangarEditor.create(placement, Blueprint.from_dict(blueprint.to_dict(), errors))
	trial.economy = economy
	trial.stock = Inventory.from_dict(stock.to_dict(), errors) if stock != null else null
	if not trial.swap_to(design):
		return {"pay": {}, "refusal": trial.refusal if not trial.refusal.is_empty() else "Can't buy it here"}
	var pay := {}
	for resource: StringName in Economy.add(stock.wallet, trial.stock.wallet):
		var spent := stock.amount(resource) - trial.stock.amount(resource)
		if spent != 0:
			pay[resource] = spent
	return {"pay": pay, "refusal": ""}


## Index of the mount in that place ({"tile", "edge", "port"} or {"tile", "face"}), or -1.
func mount_index(where: Dictionary) -> int:
	for i in blueprint.mounts.size():
		if Mounting.same_place(blueprint.mounts[i], where):
			return i
	return -1


func _add_mount(mount: Dictionary, source: StringName) -> PackedInt32Array:
	if not _slot_free(mount):
		return PackedInt32Array()
	_checkpoint()
	blueprint.mounts.append(mount)
	var first := blueprint.mounts.size() - 1
	var twin_id := _existing_twin_id(blueprint.tile_by_id(mount["tile"]))
	if twin_id >= 0:
		var image := Mounting.mirrored(placement, blueprint, mount, twin_id, axis_y())
		if not image.is_empty() and _slot_free(image):
			blueprint.mounts.append(image)
	if not _settle(source, str(mount.get("gun", ""))):
		return PackedInt32Array()
	var added := PackedInt32Array()
	for i in range(first, blueprint.mounts.size()):  # the image may have been left off
		added.append(i)
	changed.emit()
	return added


func _slot_free(mount: Dictionary) -> bool:
	var slots: Array[Dictionary]
	if Mounting.is_weapon(mount):
		slots = Mounting.weapon_slots(placement, blueprint, WeaponLib.type_of_part(str(mount["part"])),
				StringName(mount.get("mount", "")))
	else:
		slots = Mounting.thruster_slots(placement, blueprint, StringName(mount["size"]))
	return slots.any(func(s: Dictionary) -> bool: return Mounting.same_place(s, mount))


func _drop_mounts_of(tile_id: int) -> void:
	blueprint.mounts.assign(blueprint.mounts.filter(func(m: Dictionary) -> bool: return int(m.get("tile", -1)) != tile_id))


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
			_drop_mounts_of(twin_id)
	_settle(&"")
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


## A copy of the blueprint without the given tiles (and their mounts), for computing where
## they could go instead.
func blueprint_without(tile_ids: PackedInt32Array) -> Blueprint:
	var errors: PackedStringArray = []
	var copy := Blueprint.from_dict(blueprint.to_dict(), errors)
	copy.tiles = copy.tiles.filter(func(t: Blueprint.Tile) -> bool: return not tile_ids.has(t.id))
	copy.mounts.assign(copy.mounts.filter(func(m: Dictionary) -> bool: return not tile_ids.has(int(m.get("tile", -1)))))
	return copy


## Forgets undo and redo: after a flight, whose XP and pay no undo may take back.
func clear_history() -> void:
	_undo.clear()
	_redo.clear()


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func undo() -> bool:
	if _undo.is_empty():
		return false
	_redo.append(_snapshot())
	_restore(_undo.pop_back())
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	_undo.append(_snapshot())
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
	_undo.append(_snapshot())
	if _undo.size() > UNDO_DEPTH:
		_undo.pop_front()
	_redo_held = _redo
	_redo = []


func _snapshot() -> Dictionary:
	return {"bp": blueprint.to_dict(), "stock": stock.to_dict() if stock != null else {}}


func _restore(snapshot: Dictionary) -> void:
	var errors: PackedStringArray = []
	var restored := Blueprint.from_dict(snapshot["bp"], errors)
	assert(restored != null, "undo snapshot failed to parse: %s" % ", ".join(errors))
	blueprint = restored
	if stock != null:
		# XP is earned in flight, not by editing, so undo keeps what the guns have now.
		var earned := stock.guns
		stock = Inventory.from_dict(snapshot["stock"], errors)
		for id: String in stock.guns:
			if earned.has(id):
				(stock.guns[id] as Inventory.GunItem).xp = (earned[id] as Inventory.GunItem).xp
	changed.emit()


## Pays for the edit made since the last checkpoint (see the class note). `source`: where its new
## parts come from (SHOP, STOCK, or &"" for none: a part that appears is left off); `wanted`: the
## gun item to take first; `selling`: the parts it removed are sold, not kept. When it can't be
## paid for, the edit is undone, `refusal` says why, and it returns false. True in Creative.
func _settle(source: StringName, wanted := "", selling := false) -> bool:
	refusal = ""
	if stock == null:
		return true
	var errors: PackedStringArray = []
	var old := Blueprint.from_dict(_undo.back()["bp"], errors)
	var bill := Economy.add(Economy.tiles_cost(placement, blueprint), Economy.tiles_cost(placement, old), -1)
	var was_fitted := Inventory.fitted_ids(old)
	var spare: Array[Inventory.GunItem] = stock.loose_guns(old)
	var claimed := {}
	var bought: Array[Dictionary] = []
	var refits: Array[Dictionary] = []
	var left_off: Array[Dictionary] = []
	var new_parts := 0
	var old_thrusters := _thruster_counts(old)
	var seen_thrusters := {}
	var taken_thrusters := {}
	for mount in blueprint.mounts:
		if Mounting.is_weapon(mount):
			var id := str(mount.get("gun", ""))
			if id.is_empty() or not was_fitted.has(id) or claimed.has(id):
				new_parts += 1
				id = _spare_gun(spare, WeaponLib.type_of_part(str(mount["part"])), wanted, claimed) \
						if source in [STOCK, EITHER] else ""
				if not id.is_empty():
					mount["gun"] = id
				elif source in [SHOP, EITHER]:
					mount.erase("gun")
					bill = Economy.add(bill, Economy.part_price(placement, mount))
					bought.append(mount)
					continue
				else:
					left_off.append(mount)
					continue
			claimed[id] = true
			var item: Inventory.GunItem = stock.guns.get(id)
			if item != null and item.mount != StringName(mount["mount"]):
				bill = Economy.add(bill, economy.refit)
				refits.append(mount)
		elif Mounting.is_thruster(mount):
			var key := Inventory.key_of(mount)
			seen_thrusters[key] = int(seen_thrusters.get(key, 0)) + 1
			if seen_thrusters[key] <= int(old_thrusters.get(key, 0)):
				continue
			new_parts += 1
			if source in [STOCK, EITHER] and int(stock.thrusters.get(key, 0)) > int(taken_thrusters.get(key, 0)):
				taken_thrusters[key] = int(taken_thrusters.get(key, 0)) + 1
			elif source in [SHOP, EITHER]:
				bill = Economy.add(bill, Economy.part_price(placement, mount))
			else:
				left_off.append(mount)
	if new_parts > 0 and left_off.size() == new_parts:
		return _refuse("None left in the inventory")
	var due := {}
	for resource: StringName in bill:
		if int(bill[resource]) > 0:
			due[resource] = bill[resource]
	var short := stock.short_of(due)
	if short != &"":
		return _refuse("Not enough %s" % ("GC" if short == Inventory.GC else String(short)))
	# It can be paid: settle up.
	for mount in left_off:
		blueprint.mounts.erase(mount)
	for resource: StringName in bill:
		stock.wallet[resource] = stock.amount(resource) - int(bill[resource])
	for mount in bought:
		mount["gun"] = stock.new_gun(WeaponLib.type_of_part(str(mount["part"])), StringName(mount["mount"])).id
	for mount in refits:
		(stock.guns[str(mount["gun"])] as Inventory.GunItem).mount = StringName(mount["mount"])
	for key: String in taken_thrusters:
		stock.add_thrusters(key, -int(taken_thrusters[key]))
	var now_thrusters := _thruster_counts(blueprint)
	for key: String in old_thrusters:
		var gone := int(old_thrusters[key]) - int(now_thrusters.get(key, 0))
		if gone <= 0:
			continue
		if selling:
			var parts := Inventory.thruster_parts(key)
			stock.receive(Economy.add({}, economy.sell_value(Economy.part_price(placement,
					{"part": ThrusterLib.part_id(parts[0]), "size": String(parts[1]), "level": parts[2]})), gone))
		else:
			stock.add_thrusters(key, gone)
	if selling:
		var still := Inventory.fitted_ids(blueprint)
		for id: String in was_fitted:
			if not still.has(id) and stock.guns.has(id):
				var weapon: StringName = (stock.guns[id] as Inventory.GunItem).weapon
				stock.guns.erase(id)
				stock.receive(economy.sell_value(Economy.part_price(placement, {"part": WeaponLib.part_id(weapon)})))
	return true


## The loose gun of `weapon` to fit: `wanted` if it fits, or the most experienced one.
func _spare_gun(spare: Array[Inventory.GunItem], weapon: StringName, wanted: String, claimed: Dictionary) -> String:
	for item in spare:
		if item.id == wanted and item.weapon == weapon and not claimed.has(item.id):
			return item.id
	for item in spare:
		if item.weapon == weapon and not claimed.has(item.id):
			return item.id
	return ""


func _refuse(why: String) -> bool:
	refusal = why
	_restore(_undo.pop_back())
	_redo = _redo_held
	return false


static func _thruster_counts(bp: Blueprint) -> Dictionary:
	var out := {}
	for mount in bp.mounts:
		if Mounting.is_thruster(mount):
			var key := Inventory.key_of(mount)
			out[key] = int(out.get(key, 0)) + 1
	return out


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

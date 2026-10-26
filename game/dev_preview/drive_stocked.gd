extends "res://dev_preview/drive_hangar.gd"
## Drives the stocked hangar (Phase 4.8a) with synthetic touches: the wallet, Remove and Sell,
## dragging a gun off into the inventory and back on, selling a part by dropping it on Sell, a
## refused tile, and the stock surviving a reload. Uses a throwaway profile, deleted at the end.
## Run with `tools/drive.sh res://dev_preview/drive_stocked.tscn`. Exit code 0 = every step passed.

const PROFILE := "drive_stocked"


func _ready() -> void:
	OS.add_logger(_spy)
	_wipe()
	Profiles.active_id = PROFILE
	_hangar = (load("res://scenes/hangar/hangar.tscn") as PackedScene).instantiate()
	add_child(_hangar)
	await _frames(5)

	await _step_the_stocked_hangar_opens()
	await _step_a_gun_goes_off_into_the_inventory_and_back()
	await _step_a_part_dropped_on_sell_is_sold()
	await _step_building_pays_and_a_short_wallet_refuses()
	await _step_the_stock_survives_a_reload()
	await _step_a_kill_earns_the_guns_xp()

	Profiles.active_id = ""
	_wipe()
	OS.remove_logger(_spy)
	for error in _spy.seen:
		_failures.append("script error: " + error)
	if _failures.is_empty():
		print("drive_stocked: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			printerr("drive_stocked: FAIL  " + failure)
		get_tree().quit(1)


func _step_the_stocked_hangar_opens() -> void:
	var start: Dictionary = Data.table(&"economy")["dev_profile"]
	_check(_hangar.stocked(), "an active profile makes the hangar stocked")
	_check(_hangar.editor.blueprint.id == str(start["ship"]), "with the profile's starting ship")
	_check(_hangar.editor.stock.amount(&"hull") == int(start["wallet"]["hull"]), "and its starting wallet")
	_check(_hangar._wallet.visible and "Hull %d" % int(start["wallet"]["hull"]) in _hangar._wallet.text,
			"the wallet shows (%s)" % _hangar._wallet.text)
	_check(_palette_tab("Inventory") != null, "there's an Inventory tab")
	_check(_tool("Remove") != null and _tool("Delete") == null, "Delete is Remove")
	_check(_tool("Sell") != null and _tool("Sell").disabled, "Sell is there, off with nothing selected")
	_check(not _tool("Ships").visible, "no library while stocked")
	var guns: Array = _hangar.editor.blueprint.mounts.filter(Mounting.is_weapon)
	_check(guns.size() == 1 and _hangar.editor.stock.guns.has(str(guns[0].get("gun", ""))), "the starter's gun is an item")


func _step_a_gun_goes_off_into_the_inventory_and_back() -> void:
	var gc: int = _hangar.editor.stock.amount(&"gc")
	await _tap(0, _screen_of_u(Vector2(1.0, 0.0)))
	var index: int = _hangar._selected_mount
	_check(index >= 0 and Mounting.is_weapon(_hangar.editor.blueprint.mounts[index]), "a tap selects the nose turret")
	if index < 0:
		return
	var id := str(_hangar.editor.blueprint.mounts[index]["gun"])
	_check(not _tool("Sell").disabled, "Sell turns on")
	var part_line: String = _hangar._stats._part.text
	_check("L1" in part_line and "sells for 60 GC" in part_line, "the panel shows its level and sale price (%s)" % part_line)
	await _drag(0, _screen_of_u(Vector2(1.0, 0.0)), _palette_tab("Hull").get_global_rect().get_center() + Vector2(0, -60))
	_check(_hangar.editor.blueprint.mounts.filter(Mounting.is_weapon).is_empty(), "dragged onto the palette, it comes off")
	_check(_hangar.editor.stock.loose_guns(_hangar.editor.blueprint).size() == 1, "into the inventory")
	_palette_tab("Inventory").button_pressed = true
	await _frames(2)
	var card := _card(id)
	_check(card != null, "the Inventory tab shows it")
	await _frames(2)
	_save_shot("drive_stocked_inventory.png")
	if card == null:
		return
	await _drag(0, card.get_global_rect().get_center(), _screen_of_u(Vector2(1.0, 0.0)) + Vector2(0, _hangar.GHOST_LIFT_PX))
	var back: Array = _hangar.editor.blueprint.mounts.filter(Mounting.is_weapon)
	_check(back.size() == 1 and str(back[0]["gun"]) == id, "dragged back on, the same gun is fitted")
	_check(_hangar.editor.stock.amount(&"gc") == gc, "for free")
	_check(_card(id) == null, "and leaves the Inventory tab")


func _step_a_part_dropped_on_sell_is_sold() -> void:
	var gc: int = _hangar.editor.stock.amount(&"gc")
	var thrusters: int = _hangar.editor.blueprint.mounts.filter(Mounting.is_thruster).size()
	await _tap(0, _screen_of_u(Vector2(1.7, 0)))
	_check(_hangar._selected_mount >= 0 and Mounting.is_thruster(_hangar.editor.blueprint.mounts[_hangar._selected_mount]),
			"a tap selects the front thruster")
	var price: int = Economy.part_price(_hangar.placement, _hangar.editor.blueprint.mounts[_hangar._selected_mount])[&"gc"]
	await _drag(0, _screen_of_u(Vector2(1.7, 0)), _tool("Sell").get_global_rect().get_center())
	_check(_hangar.editor.blueprint.mounts.filter(Mounting.is_thruster).size() == thrusters - 1, "dropped on Sell, it's gone")
	_check(_hangar.editor.stock.amount(&"gc") == gc + floori(price * 0.75),
			"for 75%% of %d GC (%d → %d)" % [price, gc, _hangar.editor.stock.amount(&"gc")])
	_check(_hangar.editor.stock.thrusters.is_empty(), "not kept")
	_hangar.editor.undo()
	await _frames(2)
	_check(_hangar.editor.stock.amount(&"gc") == gc, "undo unsells it")


func _step_building_pays_and_a_short_wallet_refuses() -> void:
	_palette_tab("Hull").button_pressed = true
	await _frames(2)
	var hull: int = _hangar.editor.stock.amount(&"hull")
	var tiles: int = _hangar.editor.blueprint.tiles.size()
	var target := _screen_of_u(Vector2(0, -1.75)) + Vector2(0, _hangar.GHOST_LIFT_PX)
	await _drag(0, _swatch("triangle").get_global_rect().get_center(), target)
	_check(_hangar.editor.blueprint.tiles.size() == tiles + 1, "a tile is placed")
	_check(_hangar.editor.stock.amount(&"hull") < hull, "and paid for in hull (%d → %d)" % [hull, _hangar.editor.stock.amount(&"hull")])
	_hangar.editor.undo()
	await _frames(2)
	_check(_hangar.editor.stock.amount(&"hull") == hull, "undo gives the hull back")
	_hangar.editor.stock.wallet[&"hull"] = 0
	await _drag(0, _swatch("triangle").get_global_rect().get_center(), target)
	_check(_hangar.editor.blueprint.tiles.size() == tiles, "with no hull, it's refused")
	_check(_hangar._notice.text == "Not enough hull" and _hangar._notice.modulate.a > 0.5,
			"and the hangar says why (%s)" % _hangar._notice.text)
	_hangar.editor.stock.wallet[&"hull"] = hull
	_hangar._on_changed()


func _step_the_stock_survives_a_reload() -> void:
	var wallet: Dictionary = _hangar.editor.stock.wallet.duplicate()
	var ship: Dictionary = _hangar.editor.blueprint.to_dict()
	_hangar.queue_free()
	await _frames(2)
	_hangar = (load("res://scenes/hangar/hangar.tscn") as PackedScene).instantiate()
	add_child(_hangar)
	await _frames(5)
	_check(_hangar.editor.stock.wallet == wallet, "the wallet is saved")
	_check(_hangar.editor.blueprint.to_dict() == ship, "and so is the ship")


## Phase 4.8b: fly, let the nose turret hurt the target, finish it off, and the gun item that
## dealt the damage gets the kill's XP, which outlives the flight.
func _step_a_kill_earns_the_guns_xp() -> void:
	var id := str(_hangar.editor.blueprint.mounts.filter(Mounting.is_weapon)[0]["gun"])
	var sandbox: FlightSandbox = _hangar.fly()
	_check(sandbox != null, "the stocked ship flies")
	if sandbox == null:
		return
	await _frames(5)
	_check(not sandbox._level_button.visible, "no Guns L button: the guns are at their own levels")
	_check(sandbox.ship.guns.guns[0].item == id, "the flying gun is the inventory item")
	for i in 240:
		await get_tree().physics_frame
		if sandbox.target != null and sandbox.target.damage_by.has(StringName(id)):
			break
	var victim := sandbox.target
	_check(victim != null and victim.damage_by.has(StringName(id)), "the turret's hits are credited to its item")
	if victim == null:
		return
	var core: int = victim.blueprint.tiles.filter(func(t: Blueprint.Tile) -> bool: return t.type == &"core")[0].id
	victim.take_hit(core, 1.0e9, &"kinetic", 1.0, StringName(id))
	await _frames(3)
	var item: Inventory.GunItem = _hangar.editor.stock.guns[id]
	_check(sandbox.xp_earned > 0 and item.xp == sandbox.xp_earned, "the kill's XP all goes to it (%d)" % item.xp)
	_check("+%d XP" % sandbox.xp_earned in sandbox._hud.text, "the HUD says so (%s)" % sandbox._hud.text)
	_hangar.land()
	await _frames(2)
	var saved := Save.read_json(Profiles.profile_dir(PROFILE).path_join(StockStore.FILE))
	var guns: Array = saved.get("inventory", {}).get("guns", [])
	_check(guns.any(func(g: Dictionary) -> bool: return g["id"] == id and int(g["xp"]) == item.xp), "and it's saved on landing")
	_hangar.editor.undo()
	await _frames(1)
	_check(_hangar.editor.stock.guns[id].xp == item.xp, "undo doesn't take XP back")


func _tool(text: String) -> Button:
	for button in _hangar._ui.find_children("*", "Button", true, false):
		if (button as Button).text == text and button.get_parent() is VBoxContainer and not button.is_queued_for_deletion():
			return button
	return null


func _card(id: String) -> Control:
	for child in _hangar._palette._shape_row.get_children():
		if child.name == id and not child.is_queued_for_deletion():
			return child
	return null


func _wipe() -> void:
	var path := Profiles.profile_dir(PROFILE).path_join(StockStore.FILE)
	for file in [path, path + Save.BAK_SUFFIX]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)


func _check(ok: bool, what: String) -> void:
	print("drive_stocked: %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures.append(what)

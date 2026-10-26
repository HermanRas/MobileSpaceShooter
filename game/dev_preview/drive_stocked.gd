extends "res://dev_preview/drive_hangar.gd"
## Drives the stocked hangar (Phase 4.8a) with synthetic touches: the wallet, Remove and Sell,
## dragging a gun off into the inventory and back on, selling a part by dropping it on Sell, a
## refused tile, and the stock surviving a reload. Uses a throwaway profile, deleted at the end.
## Run with `tools/drive.sh res://dev_preview/drive_stocked.tscn`. Exit code 0 = every step passed.

const PROFILE := "drive_stocked"

var _note_seen := ""


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
	await _step_the_market_trades()

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
	var start: Dictionary = Data.table(&"economy")["new_pilot"]
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
	var sale := floori(int(_hangar.placement.weapons.weapon(&"gatling_single")["price_gc"]) * 0.75)
	_check("L1" in part_line and "sells for %d GC" % sale in part_line, "the panel shows its level and sale price (%s)" % part_line)
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
	sandbox.economy.part_chance = 1.0  # so this kill drops a part too
	var guns_before: int = _hangar.editor.stock.guns.size()
	var wallet_before: Dictionary = _hangar.editor.stock.wallet.duplicate()
	var wreck_at := victim.global_position
	victim.take_hit(core, 1.0e9, &"kinetic", 1.0, StringName(id))
	await _frames(3)
	var item: Inventory.GunItem = _hangar.editor.stock.guns[id]
	_check(sandbox.xp_earned > 0 and item.xp == sandbox.xp_earned, "the kill's XP all goes to it (%d)" % item.xp)
	_note_seen = sandbox._hud.text
	_check("+%d XP" % sandbox.xp_earned in _note_seen, "the HUD says so (%s)" % _note_seen)

	# 5.4: the kill drops pickups; within the magnet radius they fly to the ship.
	var dropped := sandbox.pickups.count()
	_check(dropped > 1 and sandbox.cargo.is_empty(), "the kill drops pickups (%d), not straight into the hold" % dropped)
	await _frames(90)  # the blast fades and the loot drifts to a stop
	var near := wreck_at + Vector2(0, sandbox.pickups.magnet_u * 0.6) * ShipMesh.PX_PER_U
	PhysicsServer2D.body_set_state(sandbox.ship.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, near))
	PhysicsServer2D.body_set_state(sandbox.ship.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
	get_viewport().get_camera_2d().position = near
	await _frames(4)
	_save_shot("drive_stocked_pickups.png")
	for i in 300:
		await get_tree().physics_frame
		if sandbox.pickups.count() == 0:
			break
	var first_pass := dropped - sandbox.pickups.count()
	# A big blast throws loot wide: fly over to whatever is left, as a player would.
	for sweep in 8:
		if sandbox.pickups.count() == 0:
			break
		var spot: Vector2 = sandbox.pickups._pos[0] + Vector2(0, 3) * ShipMesh.PX_PER_U
		PhysicsServer2D.body_set_state(sandbox.ship.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, spot))
		PhysicsServer2D.body_set_state(sandbox.ship.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
		for i in 120:
			await get_tree().physics_frame
			if sandbox.pickups.count() == 0:
				break
	await _frames(2)
	_check(first_pass > 0 and sandbox.pickups.count() == 0,
			"they fly to the ship (%d from beside the wreck, the rest by flying over; %d of %d left)"
			% [first_pass, sandbox.pickups.count(), dropped])
	var cargo := sandbox.cargo.to_dict()
	_check(sandbox.cargo.amount(&"gc") > 0 and sandbox.cargo.amount(&"hull") > 0, "the hold has GC and hull (%s)" % [cargo])
	# The barge has no parts to drop: one of a wasp's guns, as a kill would drop it.
	var errors: PackedStringArray = []
	var wasp := Blueprint.from_dict(Data.json_dir("enemies")["wasp"], errors)
	var gun_pick := wasp.mounts.filter(func(m: Dictionary) -> bool: return Mounting.is_weapon(m) or Mounting.is_thruster(m)) \
			.find_custom(Mounting.is_weapon)
	var part := sandbox.economy.part_drop(_hangar.placement, wasp, 0.0, gun_pick, 30)
	sandbox.pickups.drop(PackedVector2Array([sandbox.ship.global_position + Vector2(3, 0) * ShipMesh.PX_PER_U]), Vector2.ZERO, [part])
	for i in 120:
		await get_tree().physics_frame
		if sandbox.pickups.count() == 0:
			break
	await _frames(2)
	_check(sandbox.cargo.guns.size() == 1 and (sandbox.cargo.guns.values()[0] as Inventory.GunItem).xp == int(part["xp"]),
			"a dropped gun is picked up with its XP (%s)" % [part])
	_check("Found a" in sandbox._hud.text, "and the HUD says so (%s)" % sandbox._hud.text)
	_check("cargo" in sandbox._hud.text and "GC" in sandbox._hud.text, "the HUD counts the cargo (%s)" % sandbox._hud.text)
	var hold := sandbox.cargo.wallet.duplicate()
	var found_gun := not sandbox.cargo.guns.is_empty()
	_hangar.land()
	await _frames(2)
	var saved := Save.read_json(Profiles.profile_dir(PROFILE).path_join(StockStore.FILE))
	var guns: Array = saved.get("inventory", {}).get("guns", [])
	_check(guns.any(func(g: Dictionary) -> bool: return g["id"] == id and int(g["xp"]) == item.xp), "and it's saved on landing")
	_check(not _hangar.editor.can_undo(), "nothing before the flight can be undone")
	var stock: Inventory = _hangar.editor.stock
	_check(stock.amount(&"gc") == int(wallet_before.get(&"gc", 0)) + int(hold[&"gc"])
			and stock.amount(&"hull") == int(wallet_before.get(&"hull", 0)) + int(hold[&"hull"]),
			"landing banks the hold into the wallet (%s)" % [hold])
	_check(stock.guns.size() == guns_before + (1 if found_gun else 0), "and a found gun into the inventory")
	_check(int(saved.get("inventory", {}).get("wallet", {}).get("gc", 0)) == stock.amount(&"gc"),
			"and it's saved")


## 4.8c: the wallet opens the market; buying costs GC at the buy price, selling earns the sell
## price, and an unaffordable lot is greyed out.
func _step_the_market_trades() -> void:
	var stock: Inventory = _hangar.editor.stock
	var prices: Dictionary = _hangar.editor.economy.market[&"alloy"]
	await _tap(0, _hangar._wallet.get_global_rect().get_center())
	_check(_hangar._market.visible, "tapping the wallet opens the market")
	await _frames(2)
	_save_shot("drive_stocked_market.png")
	var gc := stock.amount(&"gc")
	var alloy := stock.amount(&"alloy")
	await _tap(0, _market_button("buy_alloy_10").get_global_rect().get_center())
	stock = _hangar.editor.stock
	_check(stock.amount(&"alloy") == alloy + 10 and stock.amount(&"gc") == gc - int(prices["buy"]) * 10,
			"Buy 10 alloy costs %d GC" % (int(prices["buy"]) * 10))
	await _tap(0, _market_button("sell_alloy_10").get_global_rect().get_center())
	stock = _hangar.editor.stock
	_check(stock.amount(&"alloy") == alloy and stock.amount(&"gc") == gc - (int(prices["buy"]) - int(prices["sell"])) * 10,
			"Sell 10 earns the sell price")
	stock.wallet[&"gc"] = 0
	_hangar._on_changed()
	await _frames(1)
	_check(_market_button("buy_tech_10").disabled, "with no GC, Buy is greyed out")
	await _tap(0, _hangar._market.find_children("*", "Button", true, false).filter(
			func(b: Button) -> bool: return b.text == "Done")[0].get_global_rect().get_center())
	_check(not _hangar._market.visible, "Done closes it")


func _market_button(button_name: String) -> Button:
	for button in _hangar._market.find_children(button_name, "Button", true, false):
		if not button.is_queued_for_deletion():
			return button
	return null


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

extends "res://dev_preview/drive_hangar.gd"
## Drives 7.3's "done when": pilot Ada publishes a ship from the Creative library, and pilot Bo's
## WaveTime hangar has it in its Ships shop, signed by Ada. Bo can't afford it at first, then
## buys it, and the starter is parked in Your ships (owner, 2026-10-28); Bo flies the starter
## again, then sells it, and its parts land in the inventory.
## Run with `tools/drive.sh res://dev_preview/drive_shop.tscn`. Exit code 0 = every step passed.
##
## Pilots live in a scratch folder, and the published ship is deleted at the end.

const ROOT := "user://drive_shop"
const HANGAR := "res://scenes/hangar/hangar.tscn"
const SHIP_NAME := "Drive shop gunboat"

var _real_root := ""
var _ship_id := ""


func _ready() -> void:
	OS.add_logger(_spy)
	_real_root = Profiles.root
	_wipe_dir(ROOT)
	Profiles.root = ROOT
	Profiles.reload()

	await _step_ada_publishes_from_creative()
	await _step_bo_buys_it_in_the_shop()

	if _hangar != null:
		_hangar.queue_free()
	BlueprintLibrary.new().delete(_ship_id)
	Profiles.active_id = ""
	Profiles.root = _real_root
	Profiles.reload()
	_wipe_dir(ROOT)
	OS.remove_logger(_spy)
	for error in _spy.seen:
		_failures.append("script error: " + error)
	if _failures.is_empty():
		print("drive_shop: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			printerr("drive_shop: FAIL  " + failure)
		get_tree().quit(1)


func _step_ada_publishes_from_creative() -> void:
	Profiles.create("Ada")
	Profiles.active_id = ""
	await _open_hangar()
	_check(not _hangar.stocked(), "with no active stock the hangar is Creative")
	_hangar.preview_setup({"ship": "gunboat"})
	await _hangar.save_as(SHIP_NAME)
	_ship_id = _hangar.editor.blueprint.id
	await _tap_button(_find(_hangar._ui, "Ships", VBoxContainer))
	_check(_hangar._library_panel.visible, "Ships opens the library")
	var card := _library_card(_ship_id)
	_check(card != null, "the saved ship has a card")
	if card == null:
		return
	await _tap_button(card)
	var publish := _hangar._library_panel.find_child("Publish", true, false) as Button
	_check(publish != null and not publish.disabled and publish.text == "Publish", "Publish is offered for it")
	await _tap_button(publish)
	var entry := _entry(_ship_id)
	_check(entry.get("published", false) and entry.get("author", "") == "Ada", "it's published, signed by Ada (%s)" % entry)
	_check(_labels(_library_card(_ship_id)).any(func(text: String) -> bool: return text == "For sale · by Ada"),
			"its card says so")
	_check(publish.text == "Unpublish", "and the button turns to Unpublish")
	await _hangar.save_current()
	_check(_entry(_ship_id).get("published", false), "saving the ship being edited keeps it for sale")
	_save_shot("drive_shop_library.png")


func _step_bo_buys_it_in_the_shop() -> void:
	var bo := Profiles.create("Bo")
	Profiles.active_id = bo.id
	await _open_hangar()
	_check(_hangar.stocked(), "Bo's WaveTime hangar is stocked")
	var shop_button := _find(_hangar._ui, "Ships", HBoxContainer)
	_check(shop_button != null and shop_button.visible, "Ships is up beside Undo")
	_check(not _hangar._wallet.get_global_rect().intersects(shop_button.get_global_rect()), "clear of the wallet")
	await _open_ships(shop_button)
	var flying := _shop_card("flying")
	_check(flying != null and _labels(flying).has("Flying"), "Your ships has the starter, Flying")
	await _tap_button(flying)
	_check(not _action().visible and "only ship" in _offer_text(), "your only ship can't be sold: %s" % _offer_text())
	var card := _shop_card("sale_" + _ship_id)
	_check(card != null, "Ada's ship is for sale in Bo's shop")
	if card == null:
		return
	_check(_labels(card).has("by Ada"), "signed by Ada (%s)" % ", ".join(_labels(card)))
	await _tap_button(card)
	_check(_action().text == "Buy" and _action().disabled and "Not enough" in _offer_text(),
			"a new pilot can't afford it: %s" % _offer_text())

	_hangar.editor.stock.wallet = {&"hull": 5000, &"alloy": 3000, &"crystal": 1000, &"tech": 1000, &"gc": 40000}
	var before: Dictionary = _hangar.editor.stock.wallet.duplicate()
	await _tap_button(card)
	_check(not _action().disabled and _offer_text().begins_with("You pay"), "with money it can: %s" % _offer_text())
	_save_shot("drive_shop_shop.png")
	await _tap_button(_action())
	await _tap_button(_hangar._confirm.find_child("ConfirmBuy", true, false))
	_check(_hangar.editor.blueprint.name == SHIP_NAME, "Bo flies Ada's ship now")
	_check(not _hangar._shop.visible, "and the shop closes")
	_check(_hangar.editor.stock.amount(&"gc") < int(before[&"gc"]), "it was paid for")
	var saved := StockStore.open(Profiles.profile_dir(bo.id), {}, {})
	_check(saved != null and saved.ship.name == SHIP_NAME and saved.parked.size() == 1, "it's saved, with the starter parked")

	await _open_ships(shop_button)
	var parked := _shop_card("parked_0")
	_check(parked != null and _labels(parked).has("Parked") and _labels(parked).any(func(t: String) -> bool: return t.begins_with("Starter")),
			"Your ships has the starter, Parked")
	_save_shot("drive_shop_owned.png")
	if parked == null:
		return
	await _tap_button(parked)
	_check(_action().text == "Fly this", "a parked ship offers Fly this")
	await _tap_button(_action())
	_check(_hangar.editor.blueprint.name == "Starter" and _hangar.editor.parked.size() == 1, "and Bo flies the starter again")

	await _open_ships(shop_button)
	await _tap_button(_shop_card("flying"))
	_check(_action().text == "Sell ship" and not _action().disabled, "with another ship owned, the flown one can be sold")
	var hull: int = _hangar.editor.stock.amount(&"hull")
	await _tap_button(_action())
	await _tap_button(_hangar._confirm.find_child("ConfirmSell", true, false))
	_check(_hangar.editor.blueprint.name == SHIP_NAME and _hangar.editor.parked.is_empty(), "selling the starter leaves Ada's ship")
	_check(_hangar.editor.stock.amount(&"hull") > hull, "its tiles were refunded")
	_check(_hangar.editor.stock.loose_guns(_hangar.editor.blueprint).size() == 1, "and its gun is loose in the inventory")
	await _frames(3)
	_save_shot("drive_shop_bought.png")


func _open_ships(button: Button) -> void:
	await _tap_button(button)
	await _frames(8)  # the owned ships' pictures render first
	_check(_hangar._shop.visible, "Ships opens")


func _shop_card(card_name: String) -> Button:
	for card in _hangar._shop.find_children(card_name, "Button", true, false):
		if not card.is_queued_for_deletion():
			return card
	return null


func _action() -> Button:
	return _hangar._shop.find_child("Action", true, false) as Button


func _offer_text() -> String:
	return _hangar._shop._offer.text


func _open_hangar() -> void:
	if _hangar != null:
		_hangar.queue_free()
		await _frames(1)
	_hangar = (load(HANGAR) as PackedScene).instantiate()
	add_child(_hangar)
	await _frames(5)


func _tap_button(button: Control) -> void:
	_check(button != null and button.is_visible_in_tree(), "%s is there to tap" % (button.name if button != null else "a button"))
	if button != null:
		await _tap(0, button.get_global_rect().get_center())
		await _frames(2)


func _find(root: Node, text: String, parent_type: Variant) -> Button:
	for button in root.find_children("*", "Button", true, false):
		if (button as Button).text == text and is_instance_of(button.get_parent(), parent_type) and not button.is_queued_for_deletion():
			return button
	return null


func _library_card(id: String) -> Button:
	for card in _hangar._library_panel._grid.get_children():
		if (card as Control).tooltip_text == id and not card.is_queued_for_deletion():
			return card
	return null


func _labels(node: Node) -> Array:
	return node.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text) if node != null else []


func _entry(id: String) -> Dictionary:
	for entry in _hangar._library.list():
		if entry["id"] == id:
			return entry
	return {}


func _wipe_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_wipe_dir(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


func _check(ok: bool, what: String) -> void:
	print("drive_shop: %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures.append(what)

extends "res://dev_preview/drive_hangar.gd"
## Drives 7.3's "done when": pilot Ada publishes a ship from the Creative library, and pilot Bo's
## WaveTime hangar has it in its Ships shop, signed by Ada. Bo can't afford it at first, then
## buys it: the ship is swapped, and the trade-in lands in the inventory and is saved.
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
	var starter: Blueprint = _hangar.editor.blueprint
	var shop_button := _find(_hangar._ui, "Ships", HBoxContainer)
	_check(shop_button != null and shop_button.visible, "Ships is up beside Undo")
	await _tap_button(shop_button)
	_check(_hangar._shop.visible, "it opens the shop")
	var card := _hangar._shop.find_child("ship_" + _ship_id, true, false) as Button
	_check(card != null, "Ada's ship is for sale in Bo's shop")
	if card == null:
		return
	_check(_labels(card).has("by Ada"), "signed by Ada (%s)" % ", ".join(_labels(card)))
	var buy := _hangar._shop.find_child("Buy", true, false) as Button
	await _tap_button(card)
	_check(buy.disabled and "Not enough" in _hangar._shop._quote.text,
			"a new pilot can't afford it: %s" % _hangar._shop._quote.text)

	_hangar.editor.stock.wallet = {&"hull": 5000, &"alloy": 3000, &"crystal": 1000, &"tech": 1000, &"gc": 40000}
	var before: Dictionary = _hangar.editor.stock.wallet.duplicate()
	await _tap_button(card)
	_check(not buy.disabled and _hangar._shop._quote.text.begins_with("You pay"), "with money it can: %s" % _hangar._shop._quote.text)
	_save_shot("drive_shop_shop.png")
	await _tap_button(buy)
	var confirm := _hangar._confirm.find_child("ConfirmBuy", true, false) as Button
	_check(_hangar._confirm.visible and confirm != null, "Buy asks first")
	if confirm == null:
		return
	await _tap_button(confirm)
	_check(_hangar.editor.blueprint.name == SHIP_NAME and _hangar.editor.blueprint != starter, "Bo flies Ada's ship now")
	_check(not _hangar._shop.visible, "and the shop closes")
	_check(_hangar.editor.stock.amount(&"gc") < int(before[&"gc"]), "it was paid for")
	_check(int(_hangar.editor.stock.thrusters.get(Inventory.thruster_key(&"pulse", &"L", 1), 0)) == 1,
			"the starter's spare thruster is in the inventory")
	var saved := StockStore.open(Profiles.profile_dir(bo.id), {}, {})
	_check(saved != null and saved.ship.name == SHIP_NAME, "and it's saved")
	await _frames(3)
	_save_shot("drive_shop_bought.png")


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

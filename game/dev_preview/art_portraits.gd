extends Control
## The portraits up close (A.7): each player base recoloured in three swatch sets from
## data/characters.json, as the head crop and as the whole picture, the suit beside the jacket,
## and the stand-ins. `tools/preview.sh res://dev_preview/art_portraits.tscn 1560x720 --mood=happy`
## `--big=female_jacket` shows that sheet's whole picture large instead, to inspect its masks.

const SIDE := 170.0

var _mood: StringName = &"idle"


func preview_setup(args: Dictionary) -> void:
	_mood = StringName(args.get("mood", "idle"))
	for view: PortraitView in find_children("*", "PortraitView", true, false):
		view.mood = _mood
	if args.has("big"):
		for child in get_children():
			child.queue_free()
		var parts := str(args["big"]).split("_")
		var looks: Array[Dictionary] = _looks()
		for i in looks.size():
			var view := _view(_with_base(looks[i], parts[0]), StringName(parts[1]), PortraitView.Framing.FULL)
			view.custom_minimum_size = Vector2.ONE * 512.0
			view.position = Vector2(8 + i * 516, 8)
			add_child(view)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#020b15"))
	var looks := _looks()
	var grid := GridContainer.new()
	grid.columns = 8
	grid.position = Vector2(8, 8)
	add_child(grid)
	for base in ["male", "female"]:
		for look in looks:
			var character := look.duplicate()
			character["base"] = base
			grid.add_child(_view(character, &"jacket", PortraitView.Framing.HEAD))
		grid.add_child(_view(_with_base(looks[1], base), &"jacket", PortraitView.Framing.FULL))
		grid.add_child(_view(_with_base(looks[1], base), &"suit", PortraitView.Framing.FULL))
		grid.add_child(_view(_with_base(looks[2], base), &"suit", PortraitView.Framing.HEAD))
		grid.add_child(_view({"npc": "villain" if base == "male" else "ally"}, &"jacket", PortraitView.Framing.FULL))
		grid.add_child(_view({"npc": "villain" if base == "male" else "ally"}, &"jacket", PortraitView.Framing.HEAD))
	grid.add_child(_view({}, &"jacket", PortraitView.Framing.HEAD))


## Three swatch sets from data/characters.json.
func _looks() -> Array[Dictionary]:
	var swatches: Dictionary = Data.table(&"characters")["swatches"]
	var looks: Array[Dictionary] = []
	for pick in [[0, 0, 0, 0], [4, 1, 2, 3], [5, 2, 0, 4]]:
		var look := {}
		for i in PortraitView.REGIONS.size():
			var region := PortraitView.REGIONS[i]
			look[region] = swatches[region][pick[i]]
		looks.append(look)
	return looks


func _with_base(look: Dictionary, base: String) -> Dictionary:
	var out := look.duplicate()
	out["base"] = base
	return out


func _view(character: Dictionary, outfit: StringName, framing: PortraitView.Framing) -> PortraitView:
	var view := PortraitView.new()
	view.custom_minimum_size = Vector2.ONE * SIDE
	view.outfit = outfit
	view.framing = framing
	view.mood = _mood
	view.character = character
	return view

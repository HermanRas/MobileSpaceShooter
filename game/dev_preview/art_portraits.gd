extends Control
## The portraits up close (A.7): each player base recoloured in three swatch sets from
## data/characters.json, as the head crop and as the whole picture, the suit beside the jacket,
## and the stand-ins. `tools/preview.sh res://dev_preview/art_portraits.tscn 1560x720 --mood=happy`

const SIDE := 170.0

var _mood: StringName = &"idle"


func preview_setup(args: Dictionary) -> void:
	_mood = StringName(args.get("mood", "idle"))


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#020b15"))
	var swatches: Dictionary = Data.table(&"characters")["swatches"]
	var looks: Array[Dictionary] = []
	for pick in [[0, 0, 0, 0], [4, 1, 2, 3], [6, 4, 5, 1]]:
		var look := {}
		for i in PortraitView.REGIONS.size():
			var region := PortraitView.REGIONS[i]
			look[region] = swatches[region][pick[i]]
		looks.append(look)
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

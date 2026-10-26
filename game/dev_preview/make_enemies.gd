extends Node
## Writes the roster's blueprints (PLAN.md 5.1) into `data/enemies/`: the enemies, and the Pike,
## the carrier the player protects on escort missions (12.3). It checks each one:
## no placement problems, no thrust or gun warnings. Run it again after changing a design:
##   $GODOT --headless --path game res://dev_preview/make_enemies.tscn
## Exit code 0 = every ship came out clean.
##
## A design is drawn top-down, forward to the right, one Large tile per two-character cell:
## a type (C core, H hull, A armor, S shield, P hardpoint) and a shape (# square; wedges by the
## way their slope faces: / up-front, \ down-front, { up-rear, } down-rear). ".." is empty.
## `core` is the core's cell (column, row). A mount names a cell (x, y from the core), a side
## (rear, front, top, bottom or face), then for a thruster its type, size and level, for a gun
## its weapon and mount type; `port` picks an edge's port (the middle one otherwise). Guns are all
## auto: the AI pilot (5.2) flies the ship and the guns pick their own targets.

const WEDGE_ROT := {"/": 18, "\\": 0, "{": 12, "}": 6}
const TYPES := {"C": &"core", "H": &"hull", "A": &"armor", "S": &"shield", "P": &"hardpoint"}
const SIDES := {"rear": Vector2.LEFT, "front": Vector2.RIGHT, "top": Vector2.UP, "bottom": Vector2.DOWN}
## Neutral raiders until factions (v2, PLAN.md §9): rust hulls, brown armour. Bosses run darker.
const PAINT := {&"core": "#d8d8d8", &"hull": "#7a5050", &"armor": "#6b5a3e", &"shield": "#3d5f8f", &"hardpoint": "#3a3f45"}
## The player's side: the hangar's greys and blues.
const ALLY_PAINT := {&"core": "#d8d8d8", &"hull": "#8c96a0", &"armor": "#6f7f8f", &"shield": "#3d6f9f", &"hardpoint": "#3a3f45"}
const BOSS_PAINT := {&"core": "#e0c060", &"hull": "#4a2228", &"armor": "#3e3022", &"shield": "#2f3f6f", &"hardpoint": "#2a2d33"}

const SHIPS := [
	{"id": "gnat", "name": "Gnat", "tier": 1, "role": "chaser",
		"doc": "Tier 1 chaser: a small dart with a fixed gatling on the nose; it points itself at you.",
		"core": [1, 1], "rows": ["P#H#H/", "H#C#P#", "P#H#H\\"],
		"mounts": [[-1, -1, "rear", "pulse", "L", 1], [-1, 1, "rear", "pulse", "L", 1],
			[1, 0, "front", "gatling_single", "fixed"], [1, 0, "front", "pulse", "S", 1, 0], [1, 0, "front", "pulse", "S", 1, 3]]},
	{"id": "dart", "name": "Dart", "tier": 1, "role": "kamikaze",
		"doc": "Tier 1 kamikaze: no guns, two jets and an armoured ram.",
		"core": [1, 1], "rows": ["P#P#....", "H#C#A#A#", "P#P#...."],
		"mounts": [[-1, -1, "rear", "jet", "L", 1], [-1, 1, "rear", "jet", "L", 1],
			[0, -1, "front", "pulse", "M", 1], [0, 1, "front", "pulse", "M", 1]]},
	{"id": "wasp", "name": "Wasp", "tier": 1, "role": "strafer",
		"doc": "Tier 1 strafer: gatling turrets on its wing tips, so it shoots while it circles.",
		"core": [1, 2], "rows": ["..P#..", "P#H#H/", "H#C#P#", "P#H#H\\", "..P#.."],
		"mounts": [[-1, -1, "rear", "pulse", "L", 1], [-1, 1, "rear", "pulse", "L", 1], [1, 0, "front", "pulse", "M", 1],
			[0, -2, "face", "gatling_single", "turret"], [0, 2, "face", "gatling_single", "turret"]]},
	{"id": "hornet", "name": "Hornet", "tier": 2, "role": "chaser",
		"doc": "Tier 2 chaser: an armoured nose, a fixed multi gatling and a gatling turret behind it.",
		"core": [1, 1], "rows": ["P#A#A/..", "H#C#P#P#", "P#A#A\\.."],
		"mounts": [[-1, -1, "rear", "jet", "L", 1], [-1, 1, "rear", "jet", "L", 1],
			[2, 0, "front", "gatling_multi", "fixed"], [2, 0, "front", "pulse", "S", 1, 0], [2, 0, "front", "pulse", "S", 1, 3],
			[1, 0, "face", "gatling_single", "turret"]]},
	{"id": "spinner", "name": "Spinner", "tier": 2, "role": "minelayer",
		"doc": "Tier 2 minelayer: drops mines behind it and covers itself with a flak turret.",
		"core": [1, 1], "rows": ["P#H#H/", "P#C#P#", "P#H#H\\"],
		"mounts": [[-1, -1, "rear", "pulse", "L", 1], [-1, 1, "rear", "pulse", "L", 1], [-1, 0, "rear", "mines", "fixed"],
			[1, 0, "front", "pulse", "M", 1], [1, 0, "face", "flak", "turret"]]},
	{"id": "lance", "name": "Lance", "tier": 2, "role": "sniper",
		"doc": "Tier 2 sniper: a long-nosed cannon boat that keeps its distance.",
		"core": [1, 1], "rows": ["P#H#H/..", "H#C#H#P#", "P#H#H\\.."],
		"mounts": [[-1, -1, "rear", "pulse", "L", 1], [-1, 1, "rear", "pulse", "L", 1],
			[2, 0, "front", "cannon", "fixed"], [2, 0, "front", "pulse", "S", 1, 0], [2, 0, "front", "pulse", "S", 1, 3]]},
	{"id": "pike", "name": "Pike", "tier": 2, "role": "carrier", "ally": true,
		"doc": "The carrier (owner, 2026-10-26): long, skinny and armoured, the ship the player escorts and keeps alive on escort missions (12.3). It flies its route; its three turrets fight back.",
		"core": [4, 1], "rows": ["P#................", "P#A#P#A#C#A#P#A#P#", "P#................"],
		"mounts": [[-4, -1, "rear", "pulse", "L", 1], [-4, 1, "rear", "pulse", "L", 1], [-4, 0, "rear", "pulse", "L", 1],
			[4, 0, "front", "pulse", "M", 1], [4, 0, "top", "pulse", "M", 1], [4, 0, "bottom", "pulse", "M", 1],
			[-2, 0, "face", "flak", "turret"], [2, 0, "face", "gatling_multi", "turret"],
			[4, 0, "face", "cannon", "turret"]]},
	{"id": "bulwark", "name": "Bulwark", "tier": 3, "role": "brute",
		"doc": "Tier 3 brute: armour and shields round its core, cannon turrets, flak behind.",
		"core": [2, 2], "rows": ["..P#A#A/..", "P#A#S#P#A/", "H#S#C#S#P#", "P#A#S#P#A\\", "..P#A#A\\.."],
		"mounts": [[-2, -1, "rear", "pulse", "L", 1], [-2, 1, "rear", "pulse", "L", 1], [-1, -2, "rear", "pulse", "L", 1],
			[-1, 2, "rear", "pulse", "L", 1], [2, 0, "front", "pulse", "M", 1],
			[1, -1, "face", "cannon", "turret"], [1, 1, "face", "cannon", "turret"],
			[-1, -2, "face", "flak", "turret"], [-1, 2, "face", "flak", "turret"]]},
	{"id": "harrier", "name": "Harrier", "tier": 3, "role": "strafer",
		"doc": "Tier 3 strafer: a fast delta with laser turrets and a rocket turret.",
		"core": [1, 2], "rows": ["P#H/....", "P#P#H/..", "H#C#P#P#", "P#P#H\\..", "P#H\\...."],
		"mounts": [[-1, -2, "rear", "jet", "L", 1], [-1, 2, "rear", "jet", "L", 1], [-1, -1, "rear", "jet", "L", 1],
			[-1, 1, "rear", "jet", "L", 1], [2, 0, "front", "pulse", "M", 1],
			[0, -1, "face", "laser", "turret"], [0, 1, "face", "laser", "turret"], [1, 0, "face", "rocket_ff_he", "turret"]]},
	{"id": "longbow", "name": "Longbow", "tier": 3, "role": "sniper",
		"doc": "Tier 3 sniper: a nose cannon plus Seeker AP turrets, from long range.",
		"core": [2, 1], "rows": ["P#H#H#P#A/", "P#H#C#H#P#", "P#H#H#P#A\\"],
		"mounts": [[-2, -1, "rear", "pulse", "L", 1], [-2, 1, "rear", "pulse", "L", 1], [-2, 0, "rear", "pulse", "L", 1],
			[2, 0, "front", "cannon", "fixed"], [2, 0, "front", "pulse", "S", 1, 0], [2, 0, "front", "pulse", "S", 1, 3],
			[1, -1, "face", "rocket_homing_ap", "turret"], [1, 1, "face", "rocket_homing_ap", "turret"]]},
	{"id": "mauler", "name": "Mauler", "tier": 4, "role": "brute",
		"doc": "Tier 4 brute: a slab of armour with cannon, multi gatling and Seeker turrets.",
		"core": [3, 2], "rows": ["..P#A#A#A/....", "P#A#P#S#P#A/..", "H#A#S#C#S#A#P#", "P#A#P#S#P#A\\..", "..P#A#A#A\\...."],
		"mounts": [[-3, -1, "rear", "ion", "L", 1], [-3, 1, "rear", "ion", "L", 1], [-2, -2, "rear", "pulse", "L", 1],
			[-2, 2, "rear", "pulse", "L", 1], [3, 0, "front", "pulse", "M", 1],
			[-1, -1, "face", "cannon", "turret"], [-1, 1, "face", "cannon", "turret"],
			[1, -1, "face", "gatling_multi", "turret"], [1, 1, "face", "gatling_multi", "turret"],
			[3, 0, "face", "rocket_homing_he", "turret"]]},
	{"id": "widow", "name": "Widow", "tier": 4, "role": "minelayer",
		"doc": "Tier 4 minelayer: three mine layers, EMP turrets to stop you dodging, a laser up front.",
		"core": [2, 2], "rows": ["..P#H#H/..", "P#S#P#H#H/", "P#S#C#S#P#", "P#S#P#H#H\\", "..P#H#H\\.."],
		"mounts": [[-2, -1, "rear", "jet", "L", 1], [-2, 1, "rear", "jet", "L", 1], [-2, 0, "rear", "mines", "fixed"],
			[-1, -2, "rear", "mines", "fixed"], [-1, 2, "rear", "mines", "fixed"], [2, 0, "front", "pulse", "M", 1],
			[0, -1, "face", "emp", "turret"], [0, 1, "face", "emp", "turret"], [2, 0, "face", "laser", "turret"]]},
	{"id": "meteor", "name": "Meteor", "tier": 4, "role": "kamikaze",
		"doc": "Tier 4 kamikaze: three ion engines behind a long armoured ram, flak on its fins.",
		"core": [2, 2], "rows": ["....P#......", "P#P#A#A/....", "P#H#C#A#A#A#", "P#P#A#A\\....", "....P#......"],
		"mounts": [[-2, -1, "rear", "ion", "L", 1], [-2, 1, "rear", "ion", "L", 1], [-2, 0, "rear", "ion", "L", 1],
			[0, -2, "front", "pulse", "M", 1], [0, 2, "front", "pulse", "M", 1],
			[0, -2, "face", "flak", "turret"], [0, 2, "face", "flak", "turret"]]},
	{"id": "marauder", "name": "Marauder", "tier": 1, "role": "boss", "boss": true,
		"doc": "Tier 1 boss (Kill HVT, 12.2): a raider captain's gunship, nose cannon and four turrets.",
		"core": [2, 2], "rows": ["..P#H#H/..", "P#H#P#H#H/", "P#S#C#S#P#", "P#H#P#H#H\\", "..P#H#H\\.."],
		"mounts": [[-2, -1, "rear", "pulse", "L", 1], [-2, 1, "rear", "pulse", "L", 1], [-2, 0, "rear", "pulse", "L", 1],
			[-1, -2, "rear", "pulse", "M", 1], [-1, 2, "rear", "pulse", "M", 1],
			[2, 0, "front", "cannon", "fixed"], [2, 0, "front", "pulse", "S", 1, 0], [2, 0, "front", "pulse", "S", 1, 3],
			[0, -1, "face", "gatling_multi", "turret"], [0, 1, "face", "gatling_multi", "turret"],
			[-1, -2, "face", "rocket_ff_he", "turret"], [-1, 2, "face", "rocket_ff_he", "turret"]]},
	{"id": "gorgon", "name": "Gorgon", "tier": 2, "role": "boss", "boss": true,
		"doc": "Tier 2 boss: a hammerhead with laser, flak and Seeker turrets and a nose cannon.",
		"core": [3, 3], "rows": ["......P#A/....", "....P#A#A#A/..", "P#A#S#P#S#A#..", "P#A#S#C#S#A#P#",
			"P#A#S#P#S#A#..", "....P#A#A#A\\..", "......P#A\\...."],
		"mounts": [[-3, -1, "rear", "pulse", "L", 1], [-3, 1, "rear", "pulse", "L", 1], [-3, 0, "rear", "pulse", "L", 1],
			[-1, -2, "rear", "pulse", "L", 1], [-1, 2, "rear", "pulse", "L", 1], [0, -3, "rear", "pulse", "M", 1],
			[0, 3, "rear", "pulse", "M", 1],
			[3, 0, "front", "cannon", "fixed"], [3, 0, "front", "pulse", "S", 1, 0], [3, 0, "front", "pulse", "S", 1, 3],
			[0, -1, "face", "laser", "turret"], [0, 1, "face", "laser", "turret"],
			[0, -3, "face", "flak", "turret"], [0, 3, "face", "flak", "turret"],
			[-1, -2, "face", "rocket_homing_he", "turret"], [-1, 2, "face", "rocket_homing_he", "turret"]]},
	{"id": "tyrant", "name": "Tyrant", "tier": 3, "role": "boss", "boss": true,
		"doc": "Tier 3 boss: a shielded arrowhead with nine guns: cannons, multi gatlings, Seekers, flak and a nose laser.",
		"core": [4, 3], "rows": ["....P#A#A#A/....", "..P#A#P#A#P#A/..", "P#A#S#S#S#P#A#A/", "P#A#S#H#C#H#S#A#P#",
			"P#A#S#S#S#P#A#A\\", "..P#A#P#A#P#A\\..", "....P#A#A#A\\...."],
		"mounts": [[-4, -1, "rear", "ion", "L", 1], [-4, 1, "rear", "ion", "L", 1], [-4, 0, "rear", "ion", "L", 1],
			[-3, -2, "rear", "pulse", "L", 1], [-3, 2, "rear", "pulse", "L", 1], [-2, -3, "rear", "pulse", "L", 1],
			[-2, 3, "rear", "pulse", "L", 1],
			[4, 0, "front", "laser", "fixed"], [4, 0, "front", "pulse", "S", 1, 0], [4, 0, "front", "pulse", "S", 1, 3],
			[-1, -2, "face", "cannon", "turret"], [-1, 2, "face", "cannon", "turret"],
			[1, -2, "face", "gatling_multi", "turret"], [1, 2, "face", "gatling_multi", "turret"],
			[1, -1, "face", "rocket_homing_ap", "turret"], [1, 1, "face", "rocket_homing_ap", "turret"],
			[-2, -3, "face", "flak", "turret"], [-2, 3, "face", "flak", "turret"]]},
	{"id": "leviathan", "name": "Leviathan", "tier": 4, "role": "boss", "boss": true,
		"doc": "Tier 4 boss: a 67-tile battleship ringed with turrets, shields in its heart.",
		"core": [5, 4], "rows": ["......P#A#A#A/......", "....P#A#P#A#P#A/....", "..P#A#S#S#S#S#A#A/..",
			"P#A#S#P#S#P#S#P#A#A/", "P#A#S#H#H#C#H#H#S#A#P#", "P#A#S#P#S#P#S#P#A#A\\",
			"..P#A#S#S#S#S#A#A\\..", "....P#A#P#A#P#A\\....", "......P#A#A#A\\......"],
		"mounts": [[-5, -1, "rear", "ion", "L", 1], [-5, 1, "rear", "ion", "L", 1], [-5, 0, "rear", "ion", "L", 1],
			[-4, -2, "rear", "ion", "L", 1], [-4, 2, "rear", "ion", "L", 1], [-3, -3, "rear", "pulse", "L", 1],
			[-3, 3, "rear", "pulse", "L", 1], [-2, -4, "rear", "pulse", "L", 1], [-2, 4, "rear", "pulse", "L", 1],
			[5, 0, "front", "cannon", "fixed"], [5, 0, "front", "pulse", "S", 1, 0], [5, 0, "front", "pulse", "S", 1, 3],
			[-2, -1, "face", "cannon", "turret"], [-2, 1, "face", "cannon", "turret"],
			[0, -1, "face", "laser", "turret"], [0, 1, "face", "laser", "turret"],
			[2, -1, "face", "rocket_homing_he", "turret"], [2, 1, "face", "rocket_homing_he", "turret"],
			[-1, -3, "face", "gatling_multi", "turret"], [-1, 3, "face", "gatling_multi", "turret"],
			[1, -3, "face", "flak", "turret"], [1, 3, "face", "flak", "turret"],
			[-3, -3, "face", "emp", "turret"], [-3, 3, "face", "emp", "turret"]]},
]

var placement: Placement
var _failed := false


func _ready() -> void:
	var tiles_table := Data.table(&"tiles")
	placement = Placement.create(ShapeLib.from_table(Data.table(&"shapes")), TileLib.from_table(tiles_table), tiles_table)
	placement.thrusters = ThrusterLib.from_table(Data.table(&"thrusters"))
	placement.weapons = WeaponLib.from_table(Data.table(&"weapons"), Data.table(&"weapon_xp"))
	for spec: Dictionary in SHIPS:
		_make(spec)
	get_tree().quit(1 if _failed else 0)


func _make(spec: Dictionary) -> void:
	var bp := Blueprint.new()
	bp.id = spec["id"]
	bp.name = spec["name"]
	bp.author = "mss"
	bp.tags = PackedStringArray(["ally" if spec.get("ally", false) else "enemy", "role:%s" % spec["role"], "tier:%d" % spec["tier"]]
			+ (["boss"] if spec.get("boss", false) else []))
	var paint: Dictionary = BOSS_PAINT if spec.get("boss", false) else ALLY_PAINT if spec.get("ally", false) else PAINT
	var core: Array = spec["core"]
	var at := {}  # Vector2i cell -> tile id
	var cells: Array = []
	var rows: Array = spec["rows"]
	for row in rows.size():
		var line: String = rows[row]
		for col in line.length() / 2:
			var cell := line.substr(col * 2, 2)
			if cell == "..":
				continue
			cells.append([Vector2i(col - int(core[0]), row - int(core[1])), cell])
	cells.sort_custom(func(a: Array, b: Array) -> bool: return a[1][0] == "C" and b[1][0] != "C")  # the core is tile 0
	for entry: Array in cells:
		var cell: String = entry[1]
		var tile := Blueprint.Tile.new()
		tile.id = bp.tiles.size()
		tile.type = TYPES[cell[0]]
		tile.shape = &"square" if cell[1] == "#" else &"wedge"
		tile.size = &"L"
		tile.pos = Vector2(entry[0])
		tile.rot = WEDGE_ROT.get(cell[1], 0)
		tile.paint = Color.from_string(paint[tile.type], Color.GRAY)
		bp.tiles.append(tile)
		at[entry[0]] = tile.id
	var editor := HangarEditor.create(placement, bp)
	for mount: Array in spec["mounts"]:
		if not _mount(editor, at, mount):
			_fail(spec["id"], "can't mount %s" % [mount])
	bp = editor.blueprint
	for problem in placement.validate(bp):
		_fail(spec["id"], problem.message)
	var stats := ShipStats.compute(bp, placement)
	var envelope := ThrustEnvelope.compute(bp, placement, stats)
	var guns := GunLayout.compute(bp, placement)
	for warning: Dictionary in envelope.warnings + guns.warnings:
		_fail(spec["id"], str(warning["text"]))
	print("%-10s T%d %-9s %3d tiles  mass %5.1f  accel %4.1f fwd %4.1f back  turn %5.1f  %2d guns %4d dmg/s" % [
		spec["id"], spec["tier"], spec["role"], bp.tiles.size(), stats.mass,
		envelope.accel(ThrustEnvelope.FORWARD), envelope.accel(ThrustEnvelope.BACK),
		minf(envelope.turn_left, envelope.turn_right) / maxf(envelope.inertia, 0.001), guns.guns.size(), roundi(guns.dps())])
	var out := bp.to_dict()
	out["_doc"] = str(spec["doc"]) + " Written by dev_preview/make_enemies.gd; change it there."
	var path := ProjectSettings.globalize_path("res://data/enemies/%s.json" % spec["id"])
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(_json(out))


## The blueprint as JSON with one tile or mount per line, like the hand-written ones.
static func _json(data: Dictionary) -> String:
	var lines: PackedStringArray = ["{"]
	var keys := ["format", "id", "name", "author", "tags", "_doc"]
	for key: String in keys:
		lines.append("\t%s: %s," % [JSON.stringify(key), JSON.stringify(data[key])])
	for key: String in ["tiles", "mounts"]:
		var items: PackedStringArray = []
		for item: Dictionary in data[key]:
			items.append("\t\t" + JSON.stringify(item, "", false).replace(",", ", ").replace(":", ": "))
		lines.append("\t%s: [\n%s\n\t]%s" % [JSON.stringify(key), ",\n".join(items), "," if key == "tiles" else ""])
	lines.append("}")
	return "\n".join(lines) + "\n"


## Puts one mount on the ship; false if no slot fits.
func _mount(editor: HangarEditor, at: Dictionary, mount: Array) -> bool:
	var cell := Vector2i(int(mount[0]), int(mount[1]))
	if not at.has(cell):
		return false
	var tile_id: int = at[cell]
	var side: String = mount[2]
	var part: StringName = StringName(mount[3])
	var is_thruster := placement.thrusters.has_type(part)
	if side == "face":
		return not editor.add_weapon(part, StringName(mount[4]), &"auto", {"tile": tile_id, "face": true}).is_empty()
	var slots: Array[Dictionary]
	if is_thruster:
		slots = Mounting.thruster_slots(placement, editor.blueprint, StringName(mount[4]))
	else:
		slots = Mounting.weapon_slots(placement, editor.blueprint, part, StringName(mount[4]))
	var tile := editor.blueprint.tile_by_id(tile_id)
	var edges := placement.tile_edges(tile)
	var fits := slots.filter(func(s: Dictionary) -> bool:
		return int(s["tile"]) == tile_id and not s.has("face") and edges[int(s["edge"])].normal.is_equal_approx(SIDES[side]))
	var port_index := 6 if is_thruster else 5
	if mount.size() > port_index:
		fits = fits.filter(func(s: Dictionary) -> bool: return int(s["port"]) == int(mount[port_index]))
	if fits.is_empty():
		return false
	fits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["port"]) < int(b["port"]))
	var slot: Dictionary = fits[fits.size() / 2]
	if is_thruster:
		return not editor.add_thruster(part, StringName(mount[4]), int(mount[5]), slot).is_empty()
	return not editor.add_weapon(part, StringName(mount[4]), &"auto", slot).is_empty()


func _fail(id: String, why: String) -> void:
	printerr("make_enemies: %s: %s" % [id, why])
	_failed = true

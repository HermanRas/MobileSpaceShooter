extends TestCase
## Phase 1.3: the blueprint format (PLAN.md 5.4).

const SAMPLE := {
	"format": 1,
	"id": "bp_viper_mk1",
	"name": "Viper Mk I",
	"author": "profile:herman",
	"tags": ["enemy", "role:strafer", "tier:2"],
	"tiles": [
		{"id": 0, "type": "core", "shape": "hex", "size": "L", "pos": [0, 0], "rot": 0, "paint": "#8a2be2"},
		{"id": 1, "type": "hardpoint", "shape": "square", "size": "M", "pos": [0.75, 0], "rot": 6, "paint": "#3a3a3a"},
	],
	"mounts": [
		{"tile": 1, "edge": 2, "port": 0, "part": "thruster.jet", "size": "M", "level": 1},
	],
}


func test_parses_the_plan_example() -> void:
	var errors: PackedStringArray = []
	var bp := Blueprint.from_dict(SAMPLE, errors)
	assert_eq(errors.size(), 0, ", ".join(errors))
	assert_eq(bp.name, "Viper Mk I")
	assert_eq(bp.tiles.size(), 2)
	assert_eq(bp.tile_by_id(1).shape, &"square")
	assert_eq(bp.tile_by_id(1).pos, Vector2(0.75, 0))
	assert_eq(bp.tile_by_id(1).rot, 6)
	assert_eq(bp.tile_by_id(0).paint.to_html(false), "8a2be2")
	assert_eq(bp.mounts.size(), 1)
	assert_eq(bp.next_tile_id(), 2)


func test_round_trip_through_json_is_identical() -> void:
	var errors: PackedStringArray = []
	var first := Blueprint.from_dict(SAMPLE, errors).to_dict()
	# Through text, the way a file or share code would carry it: JSON turns ints into floats.
	var reparsed: Dictionary = JSON.parse_string(JSON.stringify(first))
	var second := Blueprint.from_dict(reparsed, errors).to_dict()
	assert_eq(errors.size(), 0, ", ".join(errors))
	assert_eq(JSON.stringify(second), JSON.stringify(first))


func test_malformed_data_gives_readable_errors() -> void:
	var cases := {
		"no format": {"id": "x", "tiles": []},
		"future format": {"format": 99, "id": "x", "tiles": []},
		"tiles not a list": {"format": 1, "id": "x", "tiles": "nope"},
		"tile missing shape": {"format": 1, "id": "x", "tiles": [{"id": 0, "type": "hull", "size": "L", "pos": [0, 0], "rot": 0}]},
		"fractional rotation": {"format": 1, "id": "x", "tiles": [{"id": 0, "type": "hull", "shape": "square", "size": "L", "pos": [0, 0], "rot": 1.5}]},
		"bad pos": {"format": 1, "id": "x", "tiles": [{"id": 0, "type": "hull", "shape": "square", "size": "L", "pos": [0], "rot": 0}]},
		"bad paint": {"format": 1, "id": "x", "tiles": [{"id": 0, "type": "hull", "shape": "square", "size": "L", "pos": [0, 0], "rot": 0, "paint": "purple-ish"}]},
		"duplicate ids": {"format": 1, "id": "x", "tiles": [
			{"id": 0, "type": "hull", "shape": "square", "size": "L", "pos": [0, 0], "rot": 0},
			{"id": 0, "type": "hull", "shape": "square", "size": "L", "pos": [1, 0], "rot": 0}]},
	}
	for label: String in cases:
		var errors: PackedStringArray = []
		var bp := Blueprint.from_dict(cases[label], errors)
		assert_null(bp, "%s: should not parse" % label)
		assert_false(errors.is_empty(), "%s: should explain why" % label)


func test_future_format_says_to_update() -> void:
	var errors: PackedStringArray = []
	Blueprint.from_dict({"format": 99, "id": "x", "tiles": []}, errors)
	assert_true("update the game" in errors[0], errors[0])

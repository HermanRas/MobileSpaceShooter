extends TestCase
## A.7 (PLAN.md 6.5): every player base has its four moods in both outfits, each with a recolour
## mask, and the masks import without Godot's alpha-border fix, which would overwrite their RGB
## (hair, eyes, outfit) wherever A (trim) is 0.

const MASKS := "res://assets/portraits/masks"
const OUTFITS: Array[String] = ["jacket", "suit"]


func test_every_player_portrait_has_art_and_a_mask() -> void:
	var characters := Data.table(&"characters")
	var sheets: Dictionary = Assets.meta(&"vis.portraits").get("sheets", {})
	for base: String in characters["bases"]:
		for outfit in OUTFITS:
			var sheet := "%s_%s" % [base, outfit]
			assert_true(sheets.has(sheet), "vis.portraits has a head crop for " + sheet)
			assert_eq((sheets.get(sheet, {}).get("ref_v", []) as Array).size(), 4, sheet + " has a ref_v per region")
			for mood: String in characters["moods"]:
				assert_true(Assets.has_real_art(StringName("vis.portrait.%s_%s" % [sheet, mood])), "%s %s art" % [sheet, mood])
				assert_true(Assets.has_real_art(StringName("vis.portrait_mask.%s_%s" % [sheet, mood])), "%s %s mask" % [sheet, mood])


func test_masks_keep_their_rgb_on_import() -> void:
	var seen := 0
	for file in DirAccess.get_files_at(MASKS):
		if file.ends_with(".png.import"):
			seen += 1
			var settings := FileAccess.get_file_as_string("%s/%s" % [MASKS, file])
			assert_true(settings.contains("process/fix_alpha_border=false"), file + " has fix_alpha_border off")
	assert_true(seen > 0, "the masks have import files")

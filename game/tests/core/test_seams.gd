extends TestCase
## The data loader and the asset seam (PLAN.md 5.2, 5.3).


func test_every_shipped_data_file_loads() -> void:
	assert_eq(Data.errors.size(), 0, "data errors: %s" % ", ".join(Data.errors))
	assert_true(Data.has_table(&"visuals"))
	assert_true(Data.has_table(&"audio"))


func test_unknown_visual_is_magenta_not_null() -> void:
	var texture := Assets.tex(&"vis.does_not_exist")
	assert_not_null(texture)
	assert_eq(texture, Assets.missing_texture())
	var pixel := texture.get_image().get_pixel(0, 0)
	assert_eq(pixel, Assets.MISSING_COLOR)


func test_unknown_visual_has_no_real_art() -> void:
	assert_false(Assets.has_real_art(&"vis.does_not_exist"))

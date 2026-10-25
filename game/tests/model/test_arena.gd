extends TestCase
## Phase 3.5: the arena's edge warning and push-back.

var arena: Arena


func before_each() -> void:
	arena = Arena.from_table({"half_size_u": 100.0, "warn_margin_u": 20.0, "push_back": 2.0})


func test_the_warning_rises_across_the_margin() -> void:
	assert_eq(arena.warning(Vector2.ZERO), 0.0)
	assert_eq(arena.warning(Vector2(79, 0)), 0.0, "outside the margin: quiet")
	assert_almost_eq(arena.warning(Vector2(90, 0)), 0.5, 0.0001, "halfway through the margin")
	assert_almost_eq(arena.warning(Vector2(-50, -95)), 0.75, 0.0001, "the nearest edge counts")
	assert_eq(arena.warning(Vector2(130, 0)), 1.0, "past the edge: full")


func test_the_push_only_starts_past_the_edge_and_points_back() -> void:
	assert_eq(arena.push(Vector2(99, -99)), Vector2.ZERO)
	assert_eq(arena.push(Vector2(110, 0)), Vector2(-20, 0), "10 U past × 2")
	assert_eq(arena.push(Vector2(-105, 103)), Vector2(10, -6), "each axis on its own")
	assert_true(arena.contains(Vector2(100, -100)))
	assert_false(arena.contains(Vector2(100.1, 0)))


func test_the_sandbox_arena_loads_from_data() -> void:
	var loaded := Arena.from_table(Data.table(&"flight")["arena"])
	assert_true(loaded.half_size_u > 50.0)
	assert_true(loaded.warn_margin_u > 0.0 and loaded.warn_margin_u < loaded.half_size_u)

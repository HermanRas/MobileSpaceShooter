extends TestCase
## Phase 5.5: a fight appears just off screen round the player, in a few groups, clear of each
## other, inside the arena, facing the player.

const VIEW := Vector2(15, 7)

var ring: SpawnRing
var arena: Arena


func before_each() -> void:
	ring = SpawnRing.from_table(Data.table(&"flight").get("spawner", {}))
	arena = Arena.from_table(Data.table(&"flight").get("arena", {}))


func _place(center: Vector2, sizes: Array[float], with_seed := 7) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = with_seed
	return ring.place(center, VIEW, sizes, arena, rng)


func test_every_ship_is_off_screen_inside_the_arena_and_facing_the_player() -> void:
	var sizes: Array[float] = [3.0, 5.0, 2.0, 9.0, 4.0, 3.0, 6.0, 2.5]
	for with_seed in 20:
		var spots := _place(Vector2(10, -20), sizes, with_seed)
		for i in spots.size():
			var pos: Vector2 = spots[i]["pos"]
			var near := pos.distance_to(Vector2(10, -20)) - sizes[i] * 0.5
			assert_true(near > VIEW.length(), "seed %d ship %d: off screen (near edge %.1f U out)" % [with_seed, i, near])
			assert_true(absf(pos.x) <= arena.half_size_u - ring.inside_u and absf(pos.y) <= arena.half_size_u - ring.inside_u,
					"seed %d ship %d: inside the arena (%s)" % [with_seed, i, pos])
			assert_almost_eq(angle_difference(spots[i]["heading"], (Vector2(10, -20) - pos).angle()), 0.0, 0.001, "facing the player")


func test_no_two_ships_overlap() -> void:
	var sizes: Array[float] = [3.0, 5.0, 2.0, 9.0, 4.0, 3.0, 6.0, 2.5]
	for with_seed in 20:
		var spots := _place(Vector2.ZERO, sizes, with_seed)
		for i in spots.size():
			for j in range(i + 1, spots.size()):
				var apart := (spots[i]["pos"] as Vector2).distance_to(spots[j]["pos"])
				assert_true(apart >= (sizes[i] + sizes[j]) * 0.5, "seed %d: ships %d and %d are %.1f U apart" % [with_seed, i, j, apart])


func test_a_small_fight_comes_from_one_side_and_a_big_one_from_several() -> void:
	var three: Array[float] = [3.0, 3.0, 3.0]
	var spots := _place(Vector2.ZERO, three)
	for spot in spots:
		var off := angle_difference((spots[0]["pos"] as Vector2).angle(), (spot["pos"] as Vector2).angle())
		assert_true(absf(off) < deg_to_rad(45.0), "three ships come from one side (%.0f° apart)" % rad_to_deg(off))
	var six: Array[float] = [3.0, 3.0, 3.0, 3.0, 3.0, 3.0]
	spots = _place(Vector2.ZERO, six)
	var widest := 0.0
	for spot in spots:
		widest = maxf(widest, absf(angle_difference((spots[0]["pos"] as Vector2).angle(), (spot["pos"] as Vector2).angle())))
	assert_true(widest > deg_to_rad(120.0), "six come from two sides (%.0f° apart)" % rad_to_deg(widest))


func test_in_a_corner_the_fight_turns_to_where_there_is_room() -> void:
	var corner := Vector2(arena.half_size_u - 15.0, arena.half_size_u - 15.0)
	var sizes: Array[float] = [4.0, 4.0, 4.0]
	for with_seed in 10:
		for spot in _place(corner, sizes, with_seed):
			var pos: Vector2 = spot["pos"]
			assert_true(absf(pos.x) <= arena.half_size_u - ring.inside_u and absf(pos.y) <= arena.half_size_u - ring.inside_u,
					"seed %d: still inside the arena (%s)" % [with_seed, pos])
			assert_true(pos.distance_to(corner) - 2.0 > VIEW.length(), "and off screen")


func test_the_same_seed_places_the_same_way() -> void:
	var sizes: Array[float] = [3.0, 4.0, 5.0, 6.0]
	assert_eq(_place(Vector2.ZERO, sizes, 3), _place(Vector2.ZERO, sizes, 3))
	assert_eq(_place(Vector2.ZERO, []), [] as Array[Dictionary], "no ships, no spots")

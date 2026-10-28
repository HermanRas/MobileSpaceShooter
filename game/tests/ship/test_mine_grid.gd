extends TestCase
## Phase 7.5: the projectile pool files mines on a grid so a shot checks only the mines near its
## step (`_shoot_mines`). It must set off exactly the mines the plain every-shot-against-every-mine
## check did, wherever they are (negative coordinates and cell edges included).

const PX := ShipMesh.PX_PER_U
const DELTA := 1.0 / 60.0

var _pools: Array[ProjectilePool] = []


func after_each() -> void:
	for pool in _pools:
		pool.free()
	_pools.clear()


func test_the_grid_sets_off_the_same_mines_as_checking_every_pair() -> void:
	for round_seed in 6:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + round_seed
		var pool := _pool()
		var reference := _pool()
		for k in 40:
			var mine := _mine(rng.randf_range(-20.0, 20.0), rng.randf_range(-20.0, 20.0))
			var team := rng.randi() % 2
			pool.fire(mine, team, &"mines")
			reference.fire(mine, team, &"mines")
		for k in 500:
			var shot := _bullet(Vector2(rng.randf_range(-22.0, 22.0), rng.randf_range(-22.0, 22.0)),
					Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(5.0, 60.0))
			var team := rng.randi() % 2
			pool.fire(shot, team, &"gatling_single")
			reference.fire(shot, team, &"gatling_single")
		pool._shoot_mines(DELTA)
		_every_pair(reference, DELTA)
		var downed := 0
		for i in pool.count:
			assert_eq(pool._life[i], reference._life[i], "round %d, shot %d" % [round_seed, i])
			if pool._life[i] <= ProjectilePool.DOWNED:
				downed += 1
		assert_true(downed > 0, "round %d set some mines off (%d)" % [round_seed, downed])


func test_a_shot_straight_through_a_mine_on_a_cell_edge_sets_it_off() -> void:
	var pool := _pool()
	var edge := ProjectilePool.MINE_CELL_PX / PX  # in U
	pool.fire(_mine(-edge, 0.0), 1, &"mines")
	pool.fire(_bullet(Vector2(-edge - 0.3, 0.0), Vector2(40.0, 0.0)), 0, &"gatling_single")
	pool._shoot_mines(DELTA)
	assert_true(pool._life[0] <= ProjectilePool.DOWNED, "the mine goes off")
	assert_true(pool._life[1] <= ProjectilePool.SPENT, "and the shot is spent")


## The check as it was before the grid: every live shot against every live mine of another team.
static func _every_pair(pool: ProjectilePool, delta: float) -> void:
	var mines := PackedInt32Array()
	for k in pool.count:
		if pool._flags[k] & ProjectilePool.FUSED and pool._life[k] > 0.0:
			mines.append(k)
	for k in pool.count:
		if pool._flags[k] & ProjectilePool.FUSED or pool._life[k] <= 0.0:
			continue
		var from := pool._pos[k]
		var to := from + pool._vel[k] * delta
		for m in mines:
			if pool._team[m] == pool._team[k] or pool._life[m] <= 0.0:
				continue
			var reach: float = pool._specs[pool._spec[m]]["hit"]
			if Geometry2D.get_closest_point_to_segment(pool._pos[m], from, to).distance_squared_to(pool._pos[m]) <= reach * reach:
				pool._life[m] = ProjectilePool.DOWNED - 1.0
				pool._life[k] = ProjectilePool.SPENT - 1.0
				break


func _pool() -> ProjectilePool:
	var pool := ProjectilePool.new()
	pool._ready()
	_pools.append(pool)
	return pool


func _mine(x: float, y: float) -> Dictionary:
	return {"from": Vector2(x, y), "vel": Vector2.ZERO, "life": 25.0, "damage": 50.0, "type": &"explosive",
			"proximity_u": 1.5, "hit_u": 0.5, "rocket": true, "splash_u": 2.0, "splash_damage": 40.0}


func _bullet(from: Vector2, vel: Vector2) -> Dictionary:
	return {"from": from, "vel": vel, "life": 1.0, "damage": 10.0, "type": &"kinetic"}

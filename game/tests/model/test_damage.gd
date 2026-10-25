extends TestCase
## Phase 4.1: the PLAN.md 4.5 damage pipeline, one row of its table at a time.
## Large tiles: core 300 HP armor 5, hull 100/0, armor 150/6, shield 40/0 with +60 cap +4/s.

const EPS := 0.0001

var placement: Placement
var table: DamageTable


func before_each() -> void:
	var tiles_table := Data.table(&"tiles")
	placement = Placement.create(ShapeLib.from_table(Data.table(&"shapes")),
			TileLib.from_table(tiles_table), tiles_table)
	table = DamageTable.from_table(Data.table(&"damage_types"))


func test_the_data_has_every_type_in_the_table() -> void:
	assert_true(table.errors.is_empty(), ", ".join(table.errors))
	assert_eq(table.type_ids(), [&"emp", &"energy", &"explosive", &"kinetic"])
	assert_almost_eq(table.min_share, 0.2)


func test_each_type_drains_the_shield_by_its_multiplier() -> void:
	for row: Array in [[&"kinetic", 20.0], [&"energy", 30.0], [&"explosive", 15.0], [&"emp", 60.0]]:
		var ship := _shielded()
		var result := ship.hit(1, 20.0, row[0])
		assert_almost_eq(result.shield, row[1], EPS, "%s vs shield" % row[0])
		assert_almost_eq(ship.shield, 60.0 - row[1], EPS)
		assert_almost_eq(result.hull, 0.0, EPS, "%s: the pool soaked it all" % row[0])
		assert_almost_eq(ship.hp[1], 100.0)


func test_each_type_against_armor() -> void:
	# The armor tile (6) with no shield: full, half, full and no reduction, EMP at x0.2.
	for row: Array in [[&"kinetic", 14.0], [&"energy", 17.0], [&"explosive", 14.0], [&"emp", 4.0]]:
		var ship := _bare()
		var result := ship.hit(1, 20.0, row[0])
		assert_almost_eq(result.hull, row[1], EPS, "%s vs armor 6" % row[0])
		assert_almost_eq(ship.hp[1], 150.0 - row[1], EPS)


func test_armor_never_stops_more_than_80_percent() -> void:
	var ship := _bare()
	assert_almost_eq(ship.hit(1, 5.0, &"kinetic").hull, 1.0, EPS, "5 - 6 < 5 x 0.2")
	assert_almost_eq(ship.hit(1, 5.0, &"energy").hull, 2.0, EPS, "5 - 3 beats the floor")
	assert_almost_eq(ship.hit(0, 2.0, &"kinetic").hull, 0.4, EPS, "the core's 5 armor too")


func test_armour_piercing_ignores_part_of_the_armor() -> void:
	var ship := _bare()
	assert_almost_eq(ship.hit(1, 20.0, &"kinetic", 0.5).hull, 17.0, EPS, "20 - 6 x 0.5")


func test_what_the_shield_cant_hold_reaches_the_tile() -> void:
	var ship := _shielded()
	var result := ship.hit(1, 80.0, &"kinetic")
	assert_almost_eq(result.shield, 60.0, EPS)
	assert_almost_eq(result.hull, 20.0, EPS)
	ship = _shielded()
	result = ship.hit(1, 60.0, &"energy")
	assert_almost_eq(result.shield, 60.0, EPS, "60 energy wants 90 shield")
	assert_almost_eq(result.hull, 20.0, EPS, "the 40 raw the pool soaked leaves 20")


func test_the_shield_regenerates_only_after_a_quiet_spell() -> void:
	var ship := _shielded()
	ship.hit(1, 30.0, &"kinetic")
	ship.tick(2.9)
	assert_almost_eq(ship.shield, 30.0, EPS, "hit 2.9 s ago: no regen yet")
	ship.tick(0.2)
	assert_almost_eq(ship.shield, 30.8, EPS, "4/s once 3 s have passed")
	ship.hit(1, 1.0, &"kinetic")
	ship.tick(2.0)
	assert_almost_eq(ship.shield, 29.8, EPS, "a hit restarts the wait")
	ship.tick(100.0)
	assert_almost_eq(ship.shield, 60.0, EPS, "never past the cap")


func test_emp_knocks_out_the_shield_for_two_seconds() -> void:
	var ship := _shielded()
	var result := ship.hit(1, 10.0, &"emp")
	assert_almost_eq(result.shield, 30.0, EPS, "x3 against the shield")
	assert_true(ship.is_disabled(), "shields and thrusters are down")
	result = ship.hit(1, 20.0, &"kinetic")
	assert_almost_eq(result.shield, 0.0, EPS, "a downed shield soaks nothing")
	assert_almost_eq(result.hull, 20.0, EPS)
	assert_almost_eq(ship.shield, 30.0, EPS, "it keeps what it had")
	ship.tick(1.9)
	assert_true(ship.is_disabled())
	ship.tick(0.2)
	assert_false(ship.is_disabled(), "back after 2 s")
	ship.tick(3.0)
	assert_true(ship.shield > 30.0, "and regenerating again")


func test_emp_on_bare_tiles_does_a_fifth() -> void:
	var ship := _bare()
	assert_almost_eq(ship.hit(0, 50.0, &"emp").hull, 10.0, EPS, "armor doesn't matter")
	assert_true(ship.is_disabled())


func test_splash_hits_every_tile_in_its_radius() -> void:
	# Core at 0, hull above it at (0, -1), a far hull at (4, 0). No shield.
	var ship := ShipDamage.create(_ship([[&"core", Vector2.ZERO], [&"hull", Vector2(0, -1)],
			[&"hull", Vector2(4, 0)]]), placement, table)
	var result := ship.splash(Vector2(0, -0.3), 1.0, 40.0, &"explosive")
	assert_almost_eq(ship.hp[0], 300.0 - 35.0, EPS, "inside the core: full, less armor 5")
	assert_almost_eq(ship.hp[1], 100.0 - 36.0, EPS, "0.2 U off the hull's edge, 0.2 of the radius: x0.9")
	assert_almost_eq(ship.hp[2], 100.0, EPS, "out of reach")
	assert_almost_eq(result.hull, 71.0, EPS)


func test_the_shield_takes_a_splash_once() -> void:
	var ship := _shielded()
	var result := ship.splash(Vector2.ZERO, 3.0, 100.0, &"explosive")
	assert_almost_eq(result.shield, 60.0, EPS, "75 wanted, 60 there")
	# 100 raw - 60 / 0.75 = 20 raw left for each tile in reach.
	assert_almost_eq(ship.hp[1], 100.0 - 20.0 * lerpf(1.0, 0.5, 0.5 / 3.0), EPS)


func test_a_tile_at_zero_is_destroyed_and_takes_no_more() -> void:
	var ship := _bare()
	var result := ship.hit(2, 500.0, &"kinetic")
	assert_almost_eq(result.hull, 100.0, EPS, "only the HP it had")
	assert_eq(result.destroyed, PackedInt32Array([2]))
	assert_true(ship.is_destroyed(2))
	assert_almost_eq(ship.hit(2, 50.0, &"kinetic").hull, 0.0, EPS)
	assert_false(ship.dead)


func test_losing_a_shield_tile_shrinks_the_pool() -> void:
	var ship := _shielded()
	ship.shield = 0.0  # the pool's down, so hits reach the shield tile itself
	ship.hit(2, 100.0, &"kinetic")
	assert_true(ship.is_destroyed(2))
	assert_almost_eq(ship.shield_cap, 0.0, EPS)
	assert_almost_eq(ship.shield_regen, 0.0, EPS)
	ship.tick(10.0)
	assert_almost_eq(ship.shield, 0.0, EPS)


func test_destroying_the_core_kills_the_ship() -> void:
	var ship := _bare()
	var result := ship.hit(0, 400.0, &"kinetic")
	assert_true(result.core_destroyed)
	assert_true(ship.dead)
	assert_almost_eq(ship.hit(1, 50.0, &"kinetic").hull, 0.0, EPS, "a dead ship takes no more hits")


## Core, hull to the right (1), shield below (2): a full 60 pool.
func _shielded() -> ShipDamage:
	return ShipDamage.create(_ship([[&"core", Vector2.ZERO], [&"hull", Vector2(1, 0)],
			[&"shield", Vector2(0, 1)]]), placement, table)


## Core, armor to the right (1), hull below (2): no shield.
func _bare() -> ShipDamage:
	return ShipDamage.create(_ship([[&"core", Vector2.ZERO], [&"armor", Vector2(1, 0)],
			[&"hull", Vector2(0, 1)]]), placement, table)


func _ship(rows: Array) -> Blueprint:
	var bp := Blueprint.new()
	for row: Array in rows:
		var tile := Blueprint.Tile.new()
		tile.id = bp.next_tile_id()
		tile.type = row[0]
		tile.shape = &"square"
		tile.size = &"L"
		tile.pos = row[1]
		bp.tiles.append(tile)
	return bp

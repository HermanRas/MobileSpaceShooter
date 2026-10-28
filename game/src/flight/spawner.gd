class_name Spawner
extends Node
## Brings ships into a fight (PLAN.md 5.5), the one API the Creative test flight, WaveTime and
## Story tiles share. It owns the enemies and the carrier: builds each body, arms it, gives it
## an AI pilot (5.2), picks whom it hunts, and says when a fight is over.
##
## - `spawn_encounter()`: a generated fight at a level (5.3), just off screen round the player
##   in a few groups (SpawnRing).
## - `spawn_ship()`: one ship, `AHEAD` of the player (the sandbox's Spawn cards) or `AROUND`.
## - `spawn_carrier()`: the ally the player escorts (12.3), beside them, flying a route.
##
## The mode owns the player's ship (`player`), the camera (`view_half_u`), loot and XP; it
## listens to `enemy_destroyed`, `cleared` and `carrier_lost`. Tuning is `flight.json` `spawner`.

signal spawned(body: ShipBody)
## An enemy is destroyed; `built` is the ship as it spawned, before the damage.
signal enemy_destroyed(body: ShipBody, built: Blueprint)
## The last enemy of the fight is gone.
signal cleared
signal carrier_lost

const PX := ShipMesh.PX_PER_U
## Where a single ship appears.
const AHEAD := &"ahead"
const AROUND := &"around"
## Where a ship comes from: `data/enemies/` (the roster and the practice targets) or the
## player's ship library.
const FROM_ENEMIES := &"enemies"
const FROM_LIBRARY := &"library"

## Every enemy alive, oldest first, and the newest of them (or null when there are none).
var enemies: Array[ShipBody] = []
var target: ShipBody
## The carrier the player escorts, or null.
var carrier: ShipBody
var roster: EnemyRoster
var levels: Encounter.Rules
var arena: Arena
var ring: SpawnRing
## The player's ship now (or null between lives), and half the view's size round it, in U.
var player: Callable = func() -> ShipBody: return null
var view_half_u: Callable = func() -> Vector2: return Vector2(15, 7)

var _placement: Placement
var _flight: Dictionary
var _tuning: Dictionary
var _damage_table: DamageTable
var _pool: ProjectilePool
var _world: Node2D
var _rng := RandomNumberGenerator.new()


## Ships go into `world` and shoot through `pool`.
func setup(placement: Placement, flight: Dictionary, pool: ProjectilePool, world: Node2D) -> void:
	_placement = placement
	_flight = flight
	_tuning = flight.get("spawner", {})
	_pool = pool
	_world = world
	_damage_table = DamageTable.from_table(Data.table(&"damage_types"))
	roster = EnemyRoster.from_table(Data.table(&"enemies"), Data.json_dir("enemies"))
	levels = Encounter.Rules.from_table(Data.table(&"levels"))
	arena = Arena.from_table(flight.get("arena", {}))
	ring = SpawnRing.from_table(_tuning)
	_rng.randomize()


## A generated fight at `level` (5.3; a Kill HVT one, led by a boss, if `hvt`), off screen round
## the player. Returns it, and its ships are in `enemies`.
func spawn_encounter(level: int, hvt := false, with_seed: int = -1) -> Encounter:
	var fight := Encounter.generate(levels, roster, level, _rng.randi() if with_seed < 0 else with_seed, hvt)
	var bps: Array[Blueprint] = []
	var sizes: Array[float] = []
	for one in fight.spawns:
		var bp := blueprint(FROM_ENEMIES, String(one.id))
		bps.append(bp)
		sizes.append(reach_u(bp, _placement) * 2.0 if bp != null else 1.0)
	var spots := ring.place(_center_u(), view_half_u.call(), sizes, arena, _rng)
	for i in fight.spawns.size():
		if bps[i] != null:
			_spawn_enemy(bps[i], roster.entry(fight.spawns[i].id), level, fight.spawns[i].gun_level,
					_put.bind(spots[i]["pos"], spots[i]["heading"]))
	return fight


## Ship `id` from `from` as an enemy at encounter `level`, its guns at `gun_level` (10 × the
## level when 0), `AHEAD` of the player facing them or `AROUND` off screen; the roster's ally
## comes as the carrier instead (with no route). Null if there's no such ship.
func spawn_ship(from: StringName, id: String, level: int, gun_level := 0, where := AHEAD) -> ShipBody:
	var bp := blueprint(from, id)
	if bp == null:
		return null
	var entry := roster.entry(StringName(id)) if from == FROM_ENEMIES else null
	if entry != null and entry.ally:
		return spawn_carrier(bp, entry, [])
	return _spawn_placed(bp, entry, level, gun_level, where)


## `bp` itself (already valid) as an enemy at encounter `level`, placed as spawn_ship places one:
## the performance test's station comes this way (7.5).
func spawn_design(bp: Blueprint, level: int, where := AHEAD) -> ShipBody:
	return _spawn_placed(bp, null, level, 0, where)


func _spawn_placed(bp: Blueprint, entry: EnemyRoster.Entry, level: int, gun_level: int, where: StringName) -> ShipBody:
	var place := _place_ahead.bind(bp)
	if where == AROUND:
		var sizes: Array[float] = [reach_u(bp, _placement) * 2.0]
		var spot: Dictionary = ring.place(_center_u(), view_half_u.call(), sizes, arena, _rng)[0]
		place = _put.bind(spot["pos"], spot["heading"])
	return _spawn_enemy(bp, entry, level, gun_level if gun_level > 0 else clampi(roundi(levels.gun_per_level * level), 1, 999), place)


## The carrier (an ally from the roster) beside the player, pointing their way, flying `route`
## round and round: points in the player's frame at spawn (x ahead, y to their right), in U.
## Replaces any carrier already flying. Enemies go for it.
func spawn_carrier(bp: Blueprint, entry: EnemyRoster.Entry, route: Array) -> ShipBody:
	if is_instance_valid(carrier):
		carrier.queue_free()
	carrier = ShipBody.create(bp, _placement)
	carrier.name = "Carrier"
	carrier.team = 0
	var ship: ShipBody = player.call()
	var from := ship.global_position / PX if is_instance_valid(ship) else Vector2.ZERO
	var heading := ship.global_rotation if is_instance_valid(ship) else 0.0
	var beside := (reach_u(ship.blueprint, _placement) if is_instance_valid(ship) else 0.0) \
			+ float(_tuning.get("carrier_beside_u", 4.0))
	var at := from + Vector2.from_angle(heading + PI * 0.5) * beside
	carrier.position = at * PX
	carrier.rotation = heading
	carrier.enable_damage(_damage_table)
	_world.add_child(carrier)
	_arm(carrier, live)
	var ai := _give_pilot(carrier, entry.behaviour, 0.0)
	for point: Variant in route:
		ai.brain.route.append(at + Vector2(float(point[0]), float(point[1])).rotated(heading))
	var flying := carrier
	carrier.destroyed.connect(func() -> void:
		if carrier == flying:
			carrier = null
		carrier_lost.emit())
	spawned.emit(carrier)
	return carrier


## Every enemy, gone, and its shots in flight (without loot: it's a reset, not a kill).
func clear() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()
	target = null
	_pool.clear_team(1)


## The enemies still in play.
func live() -> Array:
	return alive([], enemies)


## The player and the carrier: what enemy guns shoot at.
func player_side() -> Array:
	return alive([player.call(), carrier])


## The ships in `a` and `b` still in play. Untyped on purpose: a freed ship can't be held in a
## ShipBody variable even to ask whether it's valid.
static func alive(a: Array, b: Array = []) -> Array:
	var out := []
	for body: Variant in a + b:
		if is_instance_valid(body) and not (body as ShipBody).is_wreck():
			out.append(body)
	return out


## A ship's blueprint from `from`, if it exists and is valid.
func blueprint(from: StringName, id: String) -> Blueprint:
	var errors: PackedStringArray = []
	var bp: Blueprint
	if from == FROM_LIBRARY:
		bp = BlueprintLibrary.new().load_ship(id)
	else:
		var raw: Dictionary = Data.json_dir("enemies").get(id, {})
		bp = Blueprint.from_dict(raw, errors) if not raw.is_empty() else null
	if bp == null or not _placement.validate(bp).is_empty():
		push_warning("spawner: no valid ship %s %s %s" % [from, id, errors])
		return null
	return bp


## How far a ship reaches from its origin (the core), in U: the radius that clears it however
## it's turned. The core needn't be in the middle, so half the longest side isn't enough.
static func reach_u(bp: Blueprint, placement: Placement) -> float:
	var reach := 0.5
	for tile in bp.tiles:
		for p in placement.tile_polygon(tile):
			reach = maxf(reach, p.length())
	return reach


## A ship's longest side, in U.
static func extent_u(bp: Blueprint, placement: Placement) -> float:
	var bounds := Rect2()
	for tile in bp.tiles:
		for p in placement.tile_polygon(tile):
			bounds = bounds.expand(p)  # starts at the origin, which the core always covers
	return maxf(bounds.size.x, bounds.size.y)


## An enemy at `level`, armed, flying itself if it has thrusters (a roster ship as its
## `entry` says; one of the player's own ships at them nose first or round them). `place` puts
## it in position before it enters the world: a body added where another already is gets flung.
func _spawn_enemy(bp: Blueprint, entry: EnemyRoster.Entry, level: int, gun_level: int, place: Callable) -> ShipBody:
	var enemy := ShipBody.create(bp, _placement)
	enemy.name = "Enemy"
	enemy.team = 1
	enemy.level = level
	enemy.gun_level = gun_level
	enemy.gun_damage = float(levels.band_for(level).get("damage", 1.0))
	enemy.guns = GunLayout.compute(bp, _placement, enemy.gun_level, {}, enemy.gun_damage)
	enemy.enable_damage(_damage_table)
	enemy.linear_damp = 0.3
	enemy.angular_damp = 0.3
	place.call(enemy)
	enemy.destroyed.connect(func() -> void:
		enemies.erase(enemy)
		target = enemies.back() if not enemies.is_empty() else null
		enemy_destroyed.emit(enemy, bp)
		if live().is_empty():
			cleared.emit())
	_world.add_child(enemy)
	enemies.append(enemy)
	target = enemy
	_arm(enemy, player_side)
	if not enemy.envelope.thrusters.is_empty():
		var behaviour := entry.behaviour if entry != null else behaviour_for(enemy)
		_give_pilot(enemy, behaviour, entry.flee_below if entry != null else 0.0).target = _pick_victim.bind(enemy)
	spawned.emit(enemy)
	return enemy


## How one of the player's own ships flies as an enemy: at you nose first if it has fixed guns,
## round you if it has only turrets and swivels.
static func behaviour_for(body: ShipBody) -> StringName:
	for gun in body.guns.guns:
		if gun.arc <= 0.0 and not gun.stats["rear_only"]:
			return &"chase"
	return &"strafe"


## Its guns, firing on their own at `foes` (nobody holds FIRE for them), and drawn.
func _arm(body: ShipBody, foes: Callable) -> void:
	if body.guns.guns.is_empty():
		return
	var guns := WeaponController.new()
	guns.name = "Weapons"
	guns.all_auto = true
	body.add_child(guns)
	guns.attach(body, _pool, _placement.weapons, foes)
	var view := GunView.new()
	body.add_child(view)
	view.attach(guns)


## An AI-flown ship (PLAN.md 5.2): a FlightController like the player's, its exhaust, and an
## AiPilot flying `behaviour` (whose target the caller sets).
func _give_pilot(body: ShipBody, behaviour: StringName, flee_below: float) -> AiPilot:
	var flier := FlightController.new()
	flier.name = "Pilot"
	body.add_child(flier)
	flier.attach(body, _flight)
	var exhaust := ThrusterFxSet.new()
	exhaust.name = "Exhaust"
	body.add_child(exhaust)
	exhaust.attach(body, flier)
	var brain := AiBrain.for_ship(Data.table(&"ai"), behaviour, body.blueprint, _placement, flier.model.linear_damp, arena)
	brain.flee_below = flee_below
	var ai := AiPilot.new()
	ai.name = "Ai"
	body.add_child(ai)
	ai.attach(body, flier, brain)
	return ai


## Whom an enemy goes after: the player or the carrier, the nearer one, counting the carrier's
## distance at `carrier_bias` so raiders make for it (an escort mission's point, 12.3).
func _pick_victim(hunter: ShipBody) -> ShipBody:
	if not is_instance_valid(hunter):
		return null
	var best: ShipBody = null
	var best_d := INF
	for body: ShipBody in player_side():
		var d := hunter.global_position.distance_to(body.global_position) \
				* (float(_tuning.get("carrier_bias", 0.6)) if body == carrier else 1.0)
		if d < best_d:
			best_d = d
			best = body
	return best


## Where the fight centres: the player, or the arena's middle between lives.
func _center_u() -> Vector2:
	var ship: ShipBody = player.call()
	return ship.global_position / PX if is_instance_valid(ship) else Vector2.ZERO


## Sets where `body`, not yet in the world, will appear.
func _put(body: ShipBody, at_u: Vector2, heading: float) -> void:
	body.position = at_u * PX
	body.rotation = heading


## Puts `body` (built as `bp`, not yet in the world) ahead of the player (or the arena's
## middle), clear of the ship and the other enemies, turned from the player's heading: to face
## them if it flies, else by target_rotation_deg (a practice target).
func _place_ahead(body: ShipBody, bp: Blueprint) -> void:
	var flies := not body.envelope.thrusters.is_empty()
	var facing := deg_to_rad(float(_tuning.get("spawn_facing_deg" if flies else "target_rotation_deg", 180.0)))
	var ship: ShipBody = player.call()
	var from := ship.global_position / PX if is_instance_valid(ship) else Vector2.ZERO
	var heading := ship.global_rotation if is_instance_valid(ship) else 0.0
	var mine := reach_u(ship.blueprint, _placement) if is_instance_valid(ship) else 0.0
	var reach := reach_u(bp, _placement)
	var at := from + Vector2.from_angle(heading) * (mine + reach + float(_tuning.get("spawn_gap_u", 6.0)))
	var side := Vector2.from_angle(heading + PI * 0.5)
	for attempt in 8:
		var clear_here := true
		for other in live():
			if (other.global_position / PX).distance_to(at) < reach + reach_u(other.blueprint, _placement) + 1.0:
				clear_here = false
		if clear_here:
			break
		at += side * (reach * 2.0 + 1.0) * (attempt + 1) * (1.0 if attempt % 2 == 0 else -1.0)
	_put(body, at, heading + facing)

class_name ShipBody
extends RigidBody2D
## A flying ship built from a blueprint (PLAN.md Phase 3.1).
##
## One convex collision shape per tile, as shape owners on the body rather than a
## CollisionPolygon2D node each, so a 150-tile ship spawns without 150 nodes. A hit reports a
## body shape index; `tile_at_shape()` turns it back into the tile that was hit. The whole ship
## draws as one ArrayMesh (one draw call, §5.5).
##
## The body's origin is the blueprint origin (the core's centre), so the mesh and shapes need
## no offset; mass, centre of mass and inertia come from ShipStats, converted to pixels.
##
## With `enable_damage()` it can be hurt (4.2): hits go to its ShipDamage, the mesh shows wear,
## lost tiles leave the shapes, mesh, mass and thrust layout, cut-off pieces drift away as
## fading wrecks, and losing the core blows it apart.

## Tiles were lost: the shapes, mass and `envelope` are new (the pilot and exhaust follow).
signal rebuilt
## The core was destroyed; the ship has blown apart and is about to be freed.
signal destroyed
## A hit took shield or hull (4.7: the HUD flashes, shakes and buzzes on it).
signal damaged(result: ShipDamage.Result)

const PX := ShipMesh.PX_PER_U
## Ships bump into each other on this layer.
const SHIP_LAYER := 1
## Wrecks sit on a physics layer of their own and collide with nothing.
const WRECK_LAYER := 1 << 2
## Each team's hulls are also on a layer of their own, TEAM_LAYER << team, so a shot's ray only
## looks for the other side (Phase 4.3).
const TEAM_LAYER := 1 << 3
const TEAMS := 4

var blueprint: Blueprint
var placement: Placement
var stats: ShipStats
## What the thrusters can do (3.2); the FlightController flies with it.
var envelope: ThrustEnvelope
## Where the guns are and where they can shoot (4.3); the WeaponController fires them.
var guns: GunLayout
## The level a gun is at unless it's an inventory gun named in `gun_levels` (item id -> level,
## PLAN.md 4.8b); `gun_level` is the sandbox's Guns button and enemies' encounter level.
var gun_level := 1
var gun_levels := {}
## The share of its guns' damage it deals (an encounter's enemies, 5.3), and the encounter level
## it was spawned at (what its kill is worth).
var gun_damage := 1.0
var level := 1
## The damage each gun item has dealt this ship (item id -> shield + hull), for splitting the
## XP its kill is worth (4.8b).
var damage_by := {}
## Which side it's on (0 is the player's). Shots only hit the other teams.
var team := 0:
	set(value):
		team = clampi(value, 0, TEAMS - 1)
		if not is_wreck():
			collision_layer = SHIP_LAYER | (TEAM_LAYER << team)
## Its fight state, once `enable_damage()` has run. Wrecks keep the ship's, for the wear.
var damage: ShipDamage
## Seconds left before a wreck is gone, or < 0 for a ship.
var wreck_left := -1.0

var _mesh := MeshInstance2D.new()
## Shape owner id -> tile id.
var _owner_tiles := {}
## Tile id -> the wear step the mesh shows.
var _wear := {}
var _mesh_stale := false
var _wreck_fade_s := 1.0


## A ship body for `bp`, ready to add to a scene. Run `Placement.validate()` first: tiles with
## unknown types or shapes are left out.
static func create(bp: Blueprint, placement_rules: Placement) -> ShipBody:
	var ship := ShipBody.new()
	ship.name = "Ship"
	ship.build(bp, placement_rules)
	return ship


func _init() -> void:
	team = 0
	gravity_scale = 0.0
	can_sleep = false
	center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	_mesh.name = "Mesh"
	_mesh.material = ShipMesh.make_material()
	add_child(_mesh)


## (Re)builds the shapes, mesh and mass properties from `bp`.
func build(bp: Blueprint, placement_rules: Placement) -> void:
	blueprint = bp
	placement = placement_rules
	for owner_id in get_shape_owners():
		remove_shape_owner(owner_id)
	_owner_tiles.clear()

	var built: Array[Blueprint.Tile] = []
	for tile in bp.tiles:
		if placement.tiles.tile(tile.type) == null or placement.shapes.shape(tile.shape) == null:
			continue
		var outline := PackedVector2Array()
		for p in placement.tile_polygon(tile):
			outline.append(p * PX)
		var shape := ConvexPolygonShape2D.new()
		shape.points = outline
		var owner_id := create_shape_owner(self)
		shape_owner_add_shape(owner_id, shape)
		_owner_tiles[owner_id] = tile.id
		built.append(tile)
	_refresh_wear()
	_mesh.mesh = ShipMesh.build(built, placement, bp, _wear)
	_mesh_stale = false

	stats = ShipStats.compute(bp, placement)
	envelope = ThrustEnvelope.compute(bp, placement, stats)
	guns = GunLayout.compute(bp, placement, gun_level, gun_levels, gun_damage)
	mass = maxf(stats.mass, 0.001)
	center_of_mass = stats.center_of_mass * PX
	inertia = maxf(stats.inertia * PX * PX, 0.001)


## The physics mask a shot from `team` looks for: every other team's hulls.
static func enemy_mask(from_team: int) -> int:
	var mask := 0
	for other in TEAMS:
		if other != from_team:
			mask |= TEAM_LAYER << other
	return mask


## The id of the tile a collision reported as `body_shape_index`, or -1.
func tile_at_shape(body_shape_index: int) -> int:
	if body_shape_index < 0 or body_shape_index >= get_shape_owners().size():
		return -1
	return _owner_tiles.get(shape_find_owner(body_shape_index), -1)


## The shape index of a tile, or -1 (the inverse of tile_at_shape, for tests and debug draw).
func shape_of_tile(tile_id: int) -> int:
	for owner_id: int in _owner_tiles:
		if _owner_tiles[owner_id] == tile_id:
			return get_shape_owners().find(owner_id)
	return -1


## Makes the ship take damage, starting at full health.
func enable_damage(table: DamageTable) -> void:
	damage = ShipDamage.create(blueprint, placement, table)


## `raw` damage of `type_id` striking `tile_id` (from `tile_at_shape`), credited to `source`.
func take_hit(tile_id: int, raw: float, type_id: StringName, pierce := 0.0, source := &"") -> ShipDamage.Result:
	if damage == null or damage.dead or is_wreck():
		return ShipDamage.Result.new()
	var result := damage.hit(tile_id, raw, type_id, pierce)
	_credit(source, result)
	_after_hit(result)
	return result


## An explosion at `world_point` reaching `radius_u`.
func take_splash(world_point: Vector2, radius_u: float, raw: float, type_id: StringName,
		source := &"") -> ShipDamage.Result:
	if damage == null or damage.dead or is_wreck():
		return ShipDamage.Result.new()
	var result := damage.splash(to_local(world_point) / PX, radius_u, raw, type_id)
	_credit(source, result)
	_after_hit(result)
	return result


func _credit(source: StringName, result: ShipDamage.Result) -> void:
	if source != &"":
		damage_by[source] = float(damage_by.get(source, 0.0)) + result.shield + result.hull


func is_wreck() -> bool:
	return wreck_left >= 0.0


## Turns this body into a drifting wreck that fades out over `fade_s` and frees itself.
func make_wreck(fade_s: float) -> void:
	wreck_left = fade_s
	_wreck_fade_s = maxf(fade_s, 0.01)
	collision_layer = WRECK_LAYER
	collision_mask = 0
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = 0.05
	angular_damp = 0.05


func _physics_process(delta: float) -> void:
	if damage != null and not is_wreck():
		damage.tick(delta)


func _process(delta: float) -> void:
	if _mesh_stale:
		_refresh_wear()
		_mesh.mesh = ShipMesh.build(blueprint.tiles, placement, blueprint, _wear)
		_mesh_stale = false
	if is_wreck():
		wreck_left -= delta
		# Full for the first half, then fading out.
		modulate.a = clampf(wreck_left / (_wreck_fade_s * 0.5), 0.0, 1.0)
		if wreck_left <= 0.0:
			queue_free()


func _after_hit(result: ShipDamage.Result) -> void:
	if result.shield > 0.0 or result.hull > 0.0:
		damaged.emit(result)
	if result.hull > 0.0:
		_mesh_stale = _mesh_stale or _wear_changed()
	if result.destroyed.is_empty():
		return
	var groups := damage.break_off()
	var wreck := damage.table.wreck
	if damage.dead:
		_blow_apart(groups, wreck)
		return
	for group in groups:
		_spawn_wreck(group, float(wreck["drift_u"]), float(wreck["spin"]), float(wreck["fade_s"]))
	build(blueprint.subset(damage.attached_ids()), placement)
	rebuilt.emit()


func _blow_apart(groups: Array[Dictionary], wreck: Dictionary) -> void:
	for group in groups:
		for chunk in damage.split(group, int(wreck["explode_chunk_tiles"])):
			_spawn_wreck(chunk, float(wreck["explode_speed_u"]) * randf_range(0.5, 1.0),
					float(wreck["spin"]) * 3.0, float(wreck["fade_s"]))
	var blast := Explosion.create(_extent_px())
	blast.global_position = global_transform * center_of_mass
	get_parent().add_child(blast)
	destroyed.emit()
	queue_free()


## A wreck of the tiles in `group`, moving as they were and pushed `drift_u` U/s away from the
## ship's centre of mass.
func _spawn_wreck(group: Dictionary, drift_u: float, spin: float, fade_s: float) -> void:
	var piece := ShipBody.create(blueprint.subset(group), placement)
	piece.name = "Wreck"
	piece.damage = damage
	piece.make_wreck(fade_s)
	piece._mesh_stale = true
	piece.transform = transform
	get_parent().add_child(piece)
	var from_center := (piece.global_transform * piece.center_of_mass) - (global_transform * center_of_mass)
	var spin_velocity := Vector2(-from_center.y, from_center.x) * angular_velocity
	var away := from_center.normalized() if from_center.length() > 0.01 else Vector2.RIGHT.rotated(randf() * TAU)
	piece.linear_velocity = linear_velocity + spin_velocity + away * drift_u * PX
	piece.angular_velocity = angular_velocity + randf_range(-spin, spin)


## Whether any tile's wear step differs from what the mesh shows.
func _wear_changed() -> bool:
	for tile in blueprint.tiles:
		if _wear.get(tile.id, 0) != _wear_step(tile.id):
			return true
	return false


func _refresh_wear() -> void:
	_wear.clear()
	if damage == null:
		return
	for tile in blueprint.tiles:
		var step := _wear_step(tile.id)
		if step > 0:
			_wear[tile.id] = step


func _wear_step(tile_id: int) -> int:
	if damage == null or not damage.max_hp.has(tile_id):
		return 0
	return ShipMesh.wear_step(damage.hp[tile_id] / damage.max_hp[tile_id])


## The ship's longest side in pixels, for sizing its explosion.
func _extent_px() -> float:
	var bounds := Rect2()
	for tile in blueprint.tiles:
		for p in placement.tile_polygon(tile):
			bounds = bounds.expand(p)
	return maxf(bounds.size.x, bounds.size.y) * PX

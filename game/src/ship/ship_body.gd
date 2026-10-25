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

const PX := ShipMesh.PX_PER_U

var blueprint: Blueprint
var placement: Placement
var stats: ShipStats

var _mesh := MeshInstance2D.new()
## Shape owner id -> tile id.
var _owner_tiles := {}


## A ship body for `bp`, ready to add to a scene. Run `Placement.validate()` first: tiles with
## unknown types or shapes are left out.
static func create(bp: Blueprint, placement_rules: Placement) -> ShipBody:
	var ship := ShipBody.new()
	ship.name = "Ship"
	ship.build(bp, placement_rules)
	return ship


func _init() -> void:
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
	_mesh.mesh = ShipMesh.build(built, placement, bp)

	stats = ShipStats.compute(bp, placement)
	mass = maxf(stats.mass, 0.001)
	center_of_mass = stats.center_of_mass * PX
	inertia = maxf(stats.inertia * PX * PX, 0.001)


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

class_name ShipDamage
extends RefCounted
## One ship's health in a fight (PLAN.md 4.5): HP per tile, the ship-wide shield pool and its
## regen, and the EMP knock-out. Hits go through `hit()` or `splash()`, time through `tick()`.
## Which tiles fall off when one is destroyed is Phase 4.2.

## What one hit did.
class Result:
	## Shield points drained.
	var shield := 0.0
	## Tile HP removed, summed over the tiles it hit.
	var hull := 0.0
	## Tiles this hit brought to 0 HP.
	var destroyed := PackedInt32Array()
	var core_destroyed := false

	func add(other: Result) -> void:
		shield += other.shield
		hull += other.hull
		destroyed.append_array(other.destroyed)
		core_destroyed = core_destroyed or other.core_destroyed


var table: DamageTable
## Tile id -> current HP. A destroyed tile stays here at 0.
var hp: Dictionary = {}
var max_hp: Dictionary = {}
var shield := 0.0
var shield_cap := 0.0
var shield_regen := 0.0
var core_id := -1
var dead := false

var _armor: Dictionary = {}
## Tile id -> [shield_cap, shield_regen] for the tiles that feed the pool.
var _shield_tiles: Dictionary = {}
## Tile id -> polygon in ship-local U, for splash.
var _polygons: Dictionary = {}
var _since_hit := INF
var _disabled_s := 0.0


static func create(bp: Blueprint, placement: Placement, damage_table: DamageTable) -> ShipDamage:
	var out := ShipDamage.new()
	out.table = damage_table
	var core_type := placement.tiles.core_id()
	for tile in bp.tiles:
		var def := placement.tiles.tile(tile.type)
		if def == null:
			continue
		var stats := def.stats(tile.size)
		out.hp[tile.id] = float(stats[&"hp"])
		out.max_hp[tile.id] = float(stats[&"hp"])
		out._armor[tile.id] = float(stats[&"armor"])
		out._polygons[tile.id] = placement.tile_polygon(tile)
		if stats[&"shield_cap"] > 0.0 or stats[&"shield_regen"] > 0.0:
			out._shield_tiles[tile.id] = [float(stats[&"shield_cap"]), float(stats[&"shield_regen"])]
		if tile.type == core_type:
			out.core_id = tile.id
	out._refresh_shield()
	out.shield = out.shield_cap
	return out


func is_destroyed(tile_id: int) -> bool:
	return hp.get(tile_id, 0.0) <= 0.0


## Shields and thrusters are knocked out (EMP).
func is_disabled() -> bool:
	return _disabled_s > 0.0


## `raw` damage of `type_id` striking `tile_id`.
func hit(tile_id: int, raw: float, type_id: StringName, pierce := 0.0) -> Result:
	var result := Result.new()
	if dead or raw <= 0.0:
		return result
	var through := _soak(raw, type_id, result)
	if through > 0.0 and not is_destroyed(tile_id):
		_hurt(tile_id, through, type_id, pierce, result)
	return result


## An explosion at `center_u` (ship-local U): the shield takes it once, then every tile within
## `radius_u` takes what got through, from full at the centre to splash_edge_share at the rim.
func splash(center_u: Vector2, radius_u: float, raw: float, type_id: StringName) -> Result:
	var result := Result.new()
	if dead or raw <= 0.0:
		return result
	var through := _soak(raw, type_id, result)
	if through <= 0.0:
		return result
	for tile_id: int in hp:
		if is_destroyed(tile_id):
			continue
		var distance := _distance_to_tile(center_u, tile_id)
		if distance > radius_u:
			continue
		var share := lerpf(1.0, table.splash_edge_share, distance / radius_u) if radius_u > 0.0 else 1.0
		_hurt(tile_id, through * share, type_id, 0.0, result)
	return result


## Advances the shield regen and the EMP timer.
func tick(delta: float) -> void:
	_since_hit += delta
	_disabled_s = maxf(_disabled_s - delta, 0.0)
	if dead or is_disabled() or _since_hit < table.regen_delay_s:
		return
	shield = minf(shield + shield_regen * delta, shield_cap)


## Drains the pool and returns the raw damage left over for the tiles.
func _soak(raw: float, type_id: StringName, result: Result) -> float:
	_since_hit = 0.0
	var knockout := table.disable_s(type_id)
	var through := raw
	var mult := table.vs_shield(type_id)
	if not is_disabled() and shield > 0.0 and mult > 0.0:
		var drained := minf(shield, raw * mult)
		shield -= drained
		result.shield += drained
		through = raw - drained / mult
	if knockout > 0.0:
		_disabled_s = maxf(_disabled_s, knockout)
	return through


func _hurt(tile_id: int, raw: float, type_id: StringName, pierce: float, result: Result) -> void:
	var lost := minf(table.tile_damage(raw, type_id, _armor[tile_id], pierce), hp[tile_id])
	hp[tile_id] -= lost
	result.hull += lost
	if hp[tile_id] > 0.0:
		return
	hp[tile_id] = 0.0
	result.destroyed.append(tile_id)
	if _shield_tiles.has(tile_id):
		_refresh_shield()
	if tile_id == core_id:
		dead = true
		result.core_destroyed = true


func _refresh_shield() -> void:
	shield_cap = 0.0
	shield_regen = 0.0
	for tile_id: int in _shield_tiles:
		if not is_destroyed(tile_id):
			shield_cap += _shield_tiles[tile_id][0]
			shield_regen += _shield_tiles[tile_id][1]
	shield = minf(shield, shield_cap)


func _distance_to_tile(point: Vector2, tile_id: int) -> float:
	var polygon: PackedVector2Array = _polygons[tile_id]
	if Geometry2D.is_point_in_polygon(point, polygon):
		return 0.0
	var nearest := INF
	for i in polygon.size():
		var on_edge := Geometry2D.get_closest_point_to_segment(point, polygon[i], polygon[(i + 1) % polygon.size()])
		nearest = minf(nearest, point.distance_to(on_edge))
	return nearest

class_name AiPilot
extends Node
## Flies an enemy ShipBody (PLAN.md 5.2): each physics tick it tells its AiBrain where the ship,
## its target, its friends and its charge are, and puts the answer on the ship's
## FlightController stick, the same stick the player's thumb moves. It runs before the
## controller in the tick (a lower process priority), so the stick is never a tick old.
##
## Whoever spawns the ship says who it fights (`target`), who it keeps clear of (`friends`) and,
## for an escort, whom it guards (`charge`). The guns aim themselves (WeaponController, all auto).

const PX := ShipMesh.PX_PER_U

var brain: AiBrain
## () -> ShipBody or null: who it's after right now.
var target: Callable = func() -> ShipBody: return null
## () -> Array of ShipBody: ships on its side.
var friends: Callable = func() -> Array: return []
## The ship an escort guards, or null.
var charge: ShipBody

var _ship: ShipBody
var _pilot: FlightController
var _hull := 1.0


func attach(ship: ShipBody, pilot: FlightController, ship_brain: AiBrain) -> void:
	_ship = ship
	_pilot = pilot
	brain = ship_brain
	process_physics_priority = pilot.process_physics_priority - 1
	ship.damaged.connect(func(_result: ShipDamage.Result) -> void: _count_hull())
	ship.rebuilt.connect(_count_hull)


func _physics_process(_delta: float) -> void:
	if _ship == null or _ship.is_wreck():
		return
	var me := {"pos": _where(_ship), "vel": _ship.linear_velocity / PX, "heading": _ship.global_rotation, "hull": _hull}
	var foe: ShipBody = target.call()
	var seen := {}
	if _alive(foe):
		seen = {"pos": _where(foe), "vel": foe.linear_velocity / PX}
	var near: Array = []
	for friend: Variant in friends.call():
		if friend != _ship and _alive(friend as ShipBody):
			near.append({"pos": _where(friend as ShipBody)})
	var guarded := {}
	if _alive(charge):
		guarded = {"pos": _where(charge), "vel": charge.linear_velocity / PX, "heading": charge.global_rotation}
	_pilot.stick = brain.think(me, seen, near, guarded)


static func _where(body: ShipBody) -> Vector2:
	return body.global_transform * body.center_of_mass / PX


static func _alive(body: ShipBody) -> bool:
	return is_instance_valid(body) and not body.is_wreck() and body.damage != null and not body.damage.dead


## The share of its hull left on the tiles it still has (what flee_below compares).
func _count_hull() -> void:
	if _ship.damage == null:
		return
	var left := 0.0
	var full := 0.0
	for tile_id: int in _ship.damage.hp:
		full += _ship.damage.max_hp[tile_id]
		if _ship.damage.is_attached(tile_id):
			left += _ship.damage.hp[tile_id]
	_hull = left / full if full > 0.0 else 0.0

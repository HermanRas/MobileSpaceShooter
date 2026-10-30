class_name PowerUps
extends RefCounted
## WaveTime's bullet multipliers (PLAN.md 8.3, `[D4]`): what a kill drops, and the one running.
## While it lasts every gun fires `shots()` times as many shots. They live only inside a run.
## Tuning is `data/powerups.json`.

## Drop rolls: the chance a kill drops one, and [{"shots", "seconds", "weight"}].
var drop_chance := 0.08
var spread_deg := 4.0
var kinds: Array[Dictionary] = []

## The multiplier running (1 for none) and the seconds it has left.
var active := 1
var left := 0.0


static func from_table(table: Dictionary) -> PowerUps:
	var out := PowerUps.new()
	out.drop_chance = clampf(float(table.get("drop_chance", out.drop_chance)), 0.0, 1.0)
	out.spread_deg = maxf(float(table.get("spread_deg", out.spread_deg)), 0.0)
	for raw: Variant in table.get("kinds", []):
		var kind: Dictionary = raw
		if int(kind.get("shots", 0)) >= 2 and float(kind.get("seconds", 0.0)) > 0.0 and float(kind.get("weight", 0.0)) > 0.0:
			out.kinds.append({"shots": int(kind["shots"]), "seconds": float(kind["seconds"]), "weight": float(kind["weight"])})
	return out


## What a kill drops for the rolls `chance_roll` and `kind_roll` (each 0..1): a multiplier
## (2..5), or 0 for nothing.
func roll(chance_roll: float, kind_roll: float) -> int:
	if kinds.is_empty() or chance_roll >= drop_chance:
		return 0
	var total := 0.0
	for kind in kinds:
		total += float(kind["weight"])
	var at := kind_roll * total
	for kind in kinds:
		at -= float(kind["weight"])
		if at < 0.0:
			return int(kind["shots"])
	return int(kinds.back()["shots"])


## Picks up a ×`shots`: it replaces whatever is running, for its full time.
func take(shots: int) -> void:
	for kind in kinds:
		if int(kind["shots"]) == shots:
			active = shots
			left = float(kind["seconds"])
			return


## Time passes. True on the tick it runs out.
func tick(delta: float) -> bool:
	if active <= 1:
		return false
	left -= delta
	if left > 0.0:
		return false
	active = 1
	left = 0.0
	return true


## The multiplier now (1 when none is running).
func shots() -> int:
	return active


## The fan of a gun's `shots` shots: each shot's turn off the aim, in radians, centred on it.
static func fan(shots: int, spread_rad: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in shots:
		out.append(spread_rad * (k - (shots - 1) * 0.5))
	return out

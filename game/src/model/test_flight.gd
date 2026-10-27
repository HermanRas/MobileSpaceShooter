class_name TestFlight
extends RefCounted
## A Creative test fight (PLAN.md 7.2): one generated encounter at a level, and how it went. The
## flight sandbox feeds it as the fight runs; the results card shows `title()` and `lines()`.
## Nothing counts once the fight is over, so the wreck's last explosions don't change the score.

enum Outcome { FLYING, CLEARED, DESTROYED }

var level := 1
## Enemies in the fight, and how many of them are down.
var enemies := 0
var kills := 0
## Shield and hull the player's ship lost.
var damage_taken := 0.0
var seconds := 0.0
var outcome := Outcome.FLYING


static func start(at_level: int, enemy_count: int) -> TestFlight:
	var flight := TestFlight.new()
	flight.level = at_level
	flight.enemies = enemy_count
	return flight


func is_over() -> bool:
	return outcome != Outcome.FLYING


func tick(delta: float) -> void:
	if not is_over():
		seconds += delta


func took(amount: float) -> void:
	if not is_over():
		damage_taken += maxf(amount, 0.0)


func killed() -> void:
	if not is_over():
		kills += 1


func cleared() -> void:
	if not is_over():
		outcome = Outcome.CLEARED


func destroyed() -> void:
	if not is_over():
		outcome = Outcome.DESTROYED


func title() -> String:
	match outcome:
		Outcome.CLEARED:
			return "Level %d cleared!" % level
		Outcome.DESTROYED:
			return "Destroyed at level %d" % level
	return "Level %d" % level


func lines() -> PackedStringArray:
	return PackedStringArray([
		"Survived: %s" % ("yes" if outcome == Outcome.CLEARED else "no"),
		"Time: %s" % clock(seconds),
		"Kills: %d of %d" % [kills, enemies],
		"Damage taken: %d" % roundi(damage_taken),
	])


## 83.4 -> "1:23".
static func clock(at_seconds: float) -> String:
	var whole := maxi(floori(at_seconds), 0)
	return "%d:%02d" % [whole / 60, whole % 60]

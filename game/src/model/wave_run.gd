class_name WaveRun
extends RefCounted
## A WaveTime run (PLAN.md 8.1, `[D4]`): waves of generated fights, each at a higher level, until
## the ship is destroyed. The next wave comes `wave_s` after the last one started, or
## `clear_pause_s` after the field is cleared, whichever is first; a wave that isn't cleared in
## time is joined by the next. The flight feeds it (`tick`, `killed`, `cleared`, `destroyed`) and
## spawns a wave whenever `tick` says so. Tuning is `levels.json` → `waves`.
##
## Score (8.2): a kill is worth its tiles × its level × `per_tile_level`, and every second alive
## `survival_per_s`, both times the wave multiplier (1 + `wave_bonus` per wave after the first).

## Encounter level of waves 1, 2, 3, … in turn; past the list, each wave adds `then_per_wave`.
var levels: Array[int] = [1]
var then_per_wave := 4
var wave_s := 60.0
var clear_pause_s := 3.0
## GC for clearing a wave, times its number (8.7).
var clear_bonus_gc := 60
var per_tile_level := 10.0
var wave_bonus := 0.25
var survival_per_s := 5.0

## The wave under way (0 before the first).
var wave := 0
## Since the run started, and since this wave came in.
var seconds := 0.0
var wave_seconds := 0.0
var kills := 0
## Waves whose every enemy went down.
var waves_cleared := 0
## Shield and hull the player's ship lost.
var damage_taken := 0.0
## Points from kills, and from staying alive (fractional until it's shown).
var kill_score := 0
var survival_score := 0.0
var over := false
## Seconds until the next wave after a clear, or -1 while there's fighting.
var _pause_left := -1.0


## The rules from `levels.json` → `waves`.
static func from_table(table: Dictionary) -> WaveRun:
	var run := WaveRun.new()
	var listed: Array[int] = []
	for level: Variant in table.get("levels", []):
		listed.append(clampi(int(level), 1, 100))
	if not listed.is_empty():
		run.levels = listed
	run.then_per_wave = maxi(int(table.get("then_per_wave", run.then_per_wave)), 0)
	run.wave_s = maxf(float(table.get("wave_s", run.wave_s)), 1.0)
	run.clear_pause_s = maxf(float(table.get("clear_pause_s", run.clear_pause_s)), 0.0)
	run.clear_bonus_gc = maxi(int(table.get("clear_bonus_gc", run.clear_bonus_gc)), 0)
	var score: Dictionary = table.get("score", {})
	run.per_tile_level = maxf(float(score.get("per_tile_level", run.per_tile_level)), 0.0)
	run.wave_bonus = maxf(float(score.get("wave_bonus", run.wave_bonus)), 0.0)
	run.survival_per_s = maxf(float(score.get("survival_per_s", run.survival_per_s)), 0.0)
	return run


## The encounter level of wave `n` (from 1), within 1-100.
func level_for(n: int) -> int:
	if n <= levels.size():
		return levels[maxi(n, 1) - 1]
	return mini(levels.back() + then_per_wave * (n - levels.size()), 100)


## The level of the wave under way.
func level() -> int:
	return level_for(wave)


## Time passes. True when the next wave is due now: the caller spawns wave `wave` at `level()`.
## The first tick starts wave 1.
func tick(delta: float) -> bool:
	if over:
		return false
	if wave == 0:
		return _next()
	seconds += delta
	wave_seconds += delta
	survival_score += survival_per_s * multiplier() * delta
	if _pause_left >= 0.0:
		_pause_left -= delta
		if _pause_left <= 0.0:
			return _next()
	if wave_seconds >= wave_s:
		return _next()
	return false


## Seconds until the next wave comes.
func next_in() -> float:
	var left := wave_s - wave_seconds
	return maxf(minf(left, _pause_left) if _pause_left >= 0.0 else left, 0.0)


## The score so far.
func score() -> int:
	return kill_score + floori(survival_score)


## What scores are multiplied by in the wave under way.
func multiplier() -> float:
	return 1.0 + wave_bonus * maxi(wave - 1, 0)


## An enemy of `tiles` tiles at encounter `at_level` is down. Returns the points it scored.
func killed(tiles := 0, at_level := 1) -> int:
	if over:
		return 0
	kills += 1
	var points := roundi(tiles * at_level * per_tile_level * multiplier())
	kill_score += points
	return points


func took(amount: float) -> void:
	if not over:
		damage_taken += maxf(amount, 0.0)


## Every enemy is down: the next wave comes after a breather. Returns the GC the clear earns
## (`clear_bonus_gc` × the wave's number), 0 if it doesn't count.
func cleared() -> int:
	if over or wave == 0 or _pause_left >= 0.0:
		return 0
	waves_cleared += 1
	_pause_left = clear_pause_s
	return clear_bonus_gc * wave


## The ship is gone: the run is over.
func destroyed() -> void:
	over = true


func title() -> String:
	return "Destroyed in wave %d" % wave


func lines() -> PackedStringArray:
	return PackedStringArray([
		"Score: %d" % score(),
		"Reached wave %d (level %d)" % [wave, level()],
		"Waves cleared: %d" % waves_cleared,
		"Time: %s" % TestFlight.clock(seconds),
		"Kills: %d" % kills,
		"Damage taken: %d" % roundi(damage_taken),
	])


func _next() -> bool:
	wave += 1
	wave_seconds = 0.0
	_pause_left = -1.0
	return true

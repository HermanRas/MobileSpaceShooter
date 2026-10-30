class_name Scoreboard
extends RefCounted
## WaveTime's scoreboard (PLAN.md 8.4, `[D2]` `[D20]`): every pilot on the device, ranked by kills
## ÷ deaths (a pilot who hasn't died counts one death, so a first good run doesn't divide by
## zero), ties broken by kills, then by name. Pilots who've never flown a run come last.


## One row a pilot, best first: {"id", "name", "kills", "deaths", "ratio", "best_score",
## "best_wave", "runs"}.
static func rank(pilots: Array[ProfileRecord]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for pilot in pilots:
		var kills := int(pilot.stats.get("kills", 0))
		var deaths := int(pilot.stats.get("deaths", 0))
		rows.append({"id": pilot.id, "name": pilot.name, "kills": kills, "deaths": deaths,
				"ratio": float(kills) / maxi(deaths, 1), "best_score": int(pilot.stats.get("best_score", 0)),
				"best_wave": int(pilot.stats.get("best_wave", 0)), "runs": int(pilot.stats.get("runs", 0))})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if (a["runs"] > 0) != (b["runs"] > 0):
			return a["runs"] > 0
		if not is_equal_approx(a["ratio"], b["ratio"]):
			return a["ratio"] > b["ratio"]
		if a["kills"] != b["kills"]:
			return a["kills"] > b["kills"]
		return String(a["name"]).naturalnocasecmp_to(b["name"]) < 0)
	return rows


## 2.5 -> "2.50"; how the ratio column reads.
static func ratio_text(ratio: float) -> String:
	return "%.2f" % ratio

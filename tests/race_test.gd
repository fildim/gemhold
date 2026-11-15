extends SceneTree
## Online races, played by the test bot (tests/bot.gd) under race conditions: the race clock
## (Defs.RACE), the lair's race hero health (Level.race_hp) and the lair's standard Dark Arts
## (Loadout.for_lair). The bot stands in for an equal rival too: every hero its kills send comes
## back onto its own roads. For each lair it prints the result at the lair's race factor, how long
## the battle took (game time at 1x), and the margin measured like tests/difficulty.gd: how many
## times tougher the heroes could be (on top of the race factor) and the bot would still win, for
## seeds 0, 101 and 202, and their geometric mean. Races should be clearly winnable (margin about
## 1.5): a lair's race factor is tuned as margin / 1.5 at factor 1.0.
## Exits 1 if any lair is lost at its race factor.
## Run: godot --headless --path . -s res://tests/race_test.gd                  (every lair, takes a while)
##      godot --headless --path . -s res://tests/race_test.gd -- --chapter 2    (one chapter of ten)
##      godot --headless --path . -s res://tests/race_test.gd -- 4 5 6          (campaign numbers)
## Add --night to play the night races instead (once each, no margin).

const MAIN := preload("res://scripts/main.gd")
const SEEDS := [0, 101, 202]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var nights := args.has("--night")
	if nights:
		args.remove_at(args.find("--night"))
	var picks: Array = Bot.pick_lairs(args)[0]
	var ok := true
	for i: int in picks:
		var sk := Loadout.for_lair(i)
		var lv := _level(i, nights)
		var sim := Bot.play(lv, sk, 0, "near", true)
		ok = ok and sim.won
		var line := "%2d %-22s race_hp=%.2f%s | %s lost=%d length=%s sent=%d" % [i + 1, lv.title, lv.race_hp, " night" if nights else "",
			sim.rank() if sim.won else "LOST", sim.lost, _clock(sim.time), sim.race_sends.length()]
		if not nights:
			var logsum := 0.0
			var each: Array[String] = []
			for seed: int in SEEDS:
				var m := _margin(i, sk, seed)
				logsum += log(m)
				each.append("%.2f" % m)
			line += " | margin=x%.2f (%s)" % [exp(logsum / SEEDS.size()), ", ".join(each)]
		print(line)
	quit(0 if ok else 1)


func _level(i: int, night := false) -> Level:
	var lv := Level.load_from(MAIN.LEVELS[i])
	lv.night = night
	return lv


static func _clock(secs: float) -> String:
	return "%d:%02d" % [int(secs) / 60, int(secs) % 60]


## Bisects the largest factor on the race hero health the bot still wins at.
func _margin(i: int, sk: Dictionary, seed: int) -> float:
	var lo := 0.25
	var hi := 6.0
	for k in 6:
		var mid := sqrt(lo * hi) if k > 0 else 1.0
		var lv := _level(i)
		lv.race_hp *= mid
		if Bot.play(lv, sk, seed, "near", true).won:
			lo = mid
		else:
			hi = mid
	return sqrt(lo * hi)

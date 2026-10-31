extends SceneTree
## Measures how hard each campaign lair is for the test bot (tests/bot.gd), playing with the Dark
## Arts points a player would have banked by then. Margin = how many times tougher the heroes could
## be (hero health) and the bot would still win: big on easy lairs, falling toward 1 on hard ones.
## One battle swings a lot on luck, so each lair is measured with SEEDS different rolls of the dice
## and the margins averaged (geometric mean). Use it to keep the campaign's difficulty rising smoothly.
## Run: godot --headless --script res://tests/difficulty.gd            (every lair, takes a while)
##      godot --headless --script res://tests/difficulty.gd -- 4 5 6   (campaign numbers)

const MAIN := preload("res://scripts/main.gd")
const SEEDS := [0, 101, 202]


func _init() -> void:
	var picks: Array[int] = []
	for a in OS.get_cmdline_user_args():
		picks.append(int(a) - 1)
	if picks.is_empty():
		picks.assign(range(MAIN.LEVELS.size()))
	for i in picks:
		var pts := Bot.points_before(i)
		var sk := Bot.skills(pts)
		var base := Level.load_from(MAIN.LEVELS[i])
		var sim := Bot.play(base, sk)
		var logsum := 0.0
		var each: Array[String] = []
		for seed: int in SEEDS:
			var m := _margin(i, sk, seed)
			logsum += log(m)
			each.append("%.2f" % m)
		print("%2d %-22s hp_mul=%.2f pts=%2d | at x1: %s lost=%d gold=%d threat=x%.2f | margin=x%.2f (%s)" % [i + 1, base.title, base.hp_mul, pts,
			sim.rank() if sim.won else "LOST", sim.lost, sim.gold, sim.threat, exp(logsum / SEEDS.size()), ", ".join(each)])
	quit(0)


## Bisects the largest hero health factor the bot still wins at.
func _margin(i: int, sk: Dictionary, seed: int) -> float:
	var lo := 0.25
	var hi := 6.0
	for k in 6:
		var mid := sqrt(lo * hi) if k > 0 else 1.0
		var lv := Level.load_from(MAIN.LEVELS[i])
		lv.hp_mul *= mid
		if Bot.play(lv, sk, seed).won:
			lo = mid
		else:
			hi = mid
	return sqrt(lo * hi)

extends SceneTree
## Can the test bot (tests/bot.gd) win each campaign lair Brilliant by day? Plays every lair with
## the standard Dark Arts (scripts/data/loadout.gd) once in each building style ("near", "far",
## "mid") and prints the rank each style got and the best of them, then totals.
## Run: godot --headless --script res://tests/brilliant.gd                  (every lair)
##      godot --headless --script res://tests/brilliant.gd -- --chapter 2   (one chapter of ten)
##      godot --headless --script res://tests/brilliant.gd -- 6 7 8        (campaign numbers)

const MAIN := preload("res://scripts/main.gd")
const STYLES := ["near", "far", "mid"]


func _init() -> void:
	var picks: Array = Bot.pick_lairs(OS.get_cmdline_user_args())[0]
	var totals := {}
	for i: int in picks:
		var best := 0
		var each: Array[String] = []
		var title := ""
		for style: String in STYLES:
			var lv := Level.load_from(MAIN.LEVELS[i])
			title = lv.title
			var sim := Bot.play(lv, Loadout.for_lair(i), 0, style)
			var r := sim.rank()
			best = maxi(best, SaveData.RANKS.find(r))
			each.append("%s=%s" % [style, r])
		var top: String = SaveData.RANKS[best]
		totals[top] = int(totals.get(top, 0)) + 1
		print("%2d %-22s %s  %s" % [i + 1, title, "  ".join(each), top.to_upper()])
	var parts: Array[String] = []
	for r: String in SaveData.RANKS:
		parts.append("%s %d" % [r, int(totals.get(r, 0))])
	print("totals: " + ", ".join(parts))
	quit(0)

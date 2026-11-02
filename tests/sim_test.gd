extends SceneTree
## Plays every campaign level headless with the test bot (tests/bot.gd) and prints the result:
## by day with no skills and with the Dark Arts points a player would have by then, and at night.
## Run: godot --headless --script res://tests/sim_test.gd
## Only some levels, by campaign number:   godot --headless --script res://tests/sim_test.gd -- 6 7 8

const MAIN := preload("res://scripts/main.gd")


func _init() -> void:
	var only := OS.get_cmdline_user_args()
	var picks: Array[int] = []
	for n in only:
		picks.append(int(n) - 1)
	if picks.is_empty():
		picks.assign(range(MAIN.LEVELS.size()))
	var ok := true
	for i in picks:
		ok = _play(Level.load_from(MAIN.LEVELS[i]), {}, i + 1, true) and ok
		ok = _play(Level.load_from(MAIN.LEVELS[i]), Bot.skills(Bot.points_before(i)), i + 1) and ok
	if only.is_empty():
		# Night missions open after a Brilliant clear, so the player has a few more points by then.
		for i in picks:
			var lv := Level.load_from(MAIN.LEVELS[i])
			lv.night = true
			ok = _play(lv, Bot.skills(Bot.points_before(i) + 3), i + 1) and ok
	quit(0 if ok else 1)


## Without skills the bot may lose a later lair (it is balanced for a player with points banked),
## so only the runs with skills must be won.
func _play(lv: Level, skills: Dictionary, number: int, may_lose := false) -> bool:
	var sim := Bot.play(lv, skills)
	var ranks := {}
	for tw: GameSim.Tower in sim.towers.values():
		ranks[tw.rank] = ranks.get(tw.rank, 0) + 1
	print("%s%s, %d skill points: won=%s rank=%s lost=%d wave=%d/%d towers=%d gold=%d threat=x%.2f ranks=%s score=%d" % [lv.title, " (night)" if lv.night else "",
		skills.values().reduce(func(a: int, b: int) -> int: return a + b, 0), sim.won, sim.rank(), sim.lost, sim.wave, lv.waves.size(), sim.towers.size(), sim.gold, sim.threat, ranks, sim.score(number)])
	# A battle with no defence at all should be lost.
	var idle := GameSim.new(lv)
	var t := 0.0
	while not idle.over and t < 1200.0:
		if idle.wave < lv.waves.size() and idle.queue.is_empty():
			idle.call_early()
		idle.update(0.05)
		t += 0.05
	if idle.won:
		printerr("  FAIL: won with no defence")
	if not sim.over or (not sim.won and not may_lose):
		printerr("  FAIL: the bot did not win")
	return sim.over and (sim.won or may_lose) and idle.over and not idle.won

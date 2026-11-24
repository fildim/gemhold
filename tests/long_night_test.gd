extends SceneTree
## The Long Night (GameSim.set_long, Defs.LONG): the waves never run out, the lair's last waves come
## round with more heroes, health grows past the lair's end, and the night always ends with the hoard
## empty. The bot plays a lair's Long Night with the Dark Arts a player would have after beating it
## and prints how many waves it held. Its best is kept apart from the campaign total.
## Run: godot --headless --script res://tests/long_night_test.gd            (every 5th lair)
## Some lairs, by campaign number:   godot --headless --script res://tests/long_night_test.gd -- 3 17 42

const MAIN := preload("res://scripts/main.gd")

var _ok := true


func _check(cond: bool, what: String) -> void:
	if not cond:
		printerr("  FAIL: " + what)
		_ok = false


func _init() -> void:
	_unit_checks()
	var picks: Array[int] = []
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			picks.append(int(a) - 1)
	if picks.is_empty():
		for i in range(0, MAIN.LEVELS.size(), 5):
			picks.append(i)
	for i in picks:
		var lv := Level.load_from(MAIN.LEVELS[i])
		var own := lv.waves.size()
		var sim := Bot.play(lv, Bot.skills(Bot.points_before(i + 1), i + 1), 0, "near", false, true)
		print("%2d %s: held %d waves (own %d, fell in wave %d), kills=%d towers=%d time=%.0fs" % [i + 1, lv.title, sim.cleared, own, sim.wave,
			sim.kills, sim.towers.size(), sim.time])
		_check(sim.over and not sim.won, "%s: the night must end with the hoard empty" % lv.title)
		_check(sim.cleared >= own, "%s: the bot should hold at least the lair's own waves" % lv.title)
	print("long_night_test: " + ("all passed" if _ok else "FAILED"))
	quit(0 if _ok else 1)


func _unit_checks() -> void:
	var lv := Level.load_from(MAIN.LEVELS[0])
	var own := lv.waves.size()
	var sim := GameSim.new(lv, {})
	sim.set_long()
	_check(lv.waves.size() == own + 1, "set_long adds the first wave past the end")
	for k in own + 6:
		sim.start_wave()
	_check(lv.waves.size() >= sim.wave + 1 and sim.wave == own + 6, "a wave is always left to come")
	for arr: Array in [lv.wave_roads, lv.wave_cargo, lv.wave_walk, lv.wave_deal, lv.wave_rivers, lv.wave_air]:
		_check(arr.is_empty() or arr.size() == lv.waves.size(), "every per-wave list grows with the waves")
	var cycle := mini(int(Defs.LONG["cycle"]), own)
	_check(lv.waves[own].size() == lv.waves[own - cycle].size() + 1 / int(Defs.LONG["extra_every"]), "the first long wave copies the lair's wave `cycle` from the end (plus its extra hero)")
	_check(lv.waves[own + 3].size() > lv.waves[own - cycle + 3].size(), "later long waves bring more heroes")
	# Health: the lair's last curve value, then compounding growth past the end.
	sim.wave = own + 10
	sim._spawn("p", -1, 0.0, own + 10)
	var e: GameSim.Enemy = sim.enemies.back()
	var want: float = Defs.ENEMIES["p"]["hp"] * lv.hp_mul * (1.0 + lv.wave_hp * (own + 9)) * lv.wave_curve(own + 10) * pow(1.0 + Defs.LONG["grow"], 10) * float(Defs.LONG["hp"])
	_check(absf(e.max_hp - want) < 0.01, "health past the end compounds (%.1f, want %.1f)" % [e.max_hp, want])
	# Restarting reuses the extended level: the Long Night still starts from the lair's own end.
	var again := GameSim.new(lv, {})
	again.set_long()
	_check(again.long_base == own, "a restart counts from the lair's own waves")
	# Score: waves held first, kills only break ties; kept out of the campaign total.
	sim.cleared = 27
	sim.kills = 812
	_check(GameSim.long_waves(sim.long_score()) == 27, "long_score keeps the waves held")
	var save := SaveData.new()
	save.record_score("level_01", 1000)
	save.record_score(SaveData.long_id("level_01"), sim.long_score())
	_check(save.total_score() == 1000, "the Long Night is not in the total score")
	_check(Online.mission_of_key(Online.score_key(SaveData.long_id("level_01"))) == SaveData.long_id("level_01"), "the online key round-trips")
	_check(not save.long_unlocked("level_01"), "the Long Night is shut before the lair is won")
	save.record(0, "level_01", "Survived", 1, true)
	_check(save.long_unlocked("level_01"), "the Long Night opens once the lair is won by day")

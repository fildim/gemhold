extends SceneTree
## The battle report (BattleReport): what a played battle records, and the settings switch.
##   godot --headless --path . -s res://tests/report_test.gd

const MAIN := preload("res://scripts/main.gd")

var _fails := 0


func _init() -> void:
	Prefs.path = "user://report_test_settings.cfg"
	# The Last Bridge with no skills: the bot loses it, so heroes grab and carry off gems.
	var sim := Bot.play(Level.load_from(MAIN.LEVELS[18]), {})
	var r := BattleReport.build(sim, 19, "lost")
	_check(r["lair"] == "level_20" and r["n"] == 19 and r["end"] == "lost" and r["rank"] == "Plundered", "the battle is named and ended: %s %s" % [r["lair"], r["rank"]])
	_check(r["wave"] >= 1 and r["per_wave"].size() == r["wave"], "one entry per wave started: %d / %d" % [r["per_wave"].size(), r["wave"]])
	var w1: Dictionary = r["per_wave"][0]
	_check(w1["w"] == 1 and w1.has("res") and w1.has("gold") and w1.has("mana") and w1.has("early"), "a wave entry: %s" % [w1])
	var ev: Array = r["gem_events"]
	_check(ev.any(func(e: Dictionary) -> bool: return e["ev"] == "grab"), "gem grabs are recorded")
	var esc := ev.filter(func(e: Dictionary) -> bool: return e["ev"] == "escape")
	var carried := 0
	for e: Dictionary in esc:
		carried += int(e["n"])
	_check(carried == sim.lost, "every gem carried off is recorded: %d / %d" % [carried, sim.lost])
	_check(ev.all(func(e: Dictionary) -> bool: return e.has("w") and e.has("hero") and e.has("road") and e.has("of")), "each gem event has wave, hero, road and own wave")
	_check(JSON.stringify(r).length() < Online.REPORT_MAX, "a lost battle's report fits: %d chars" % JSON.stringify(r).length())
	# Only campaign battles that got going.
	var fresh := GameSim.new(Level.load_from(MAIN.LEVELS[0]))
	_check(not BattleReport.worth(fresh), "no report before wave 1")
	fresh.start_wave()
	_check(BattleReport.worth(fresh), "a report once wave 1 marched")
	fresh.set_race()
	_check(not BattleReport.worth(fresh), "no report for a race")
	# The switch and the install id.
	Prefs.set_value(BattleReport.PREF, false)
	_check(not BattleReport.enabled(), "reports can be turned off")
	Prefs.set_value(BattleReport.PREF, true)
	var id := BattleReport.player_id()
	_check(id.length() == 16 and BattleReport.player_id() == id, "the install id is made once and kept")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Prefs.path))
	print("report_test: " + ("all passed" if _fails == 0 else "%d failed" % _fails))
	quit(1 if _fails > 0 else 0)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("FAIL: " + what)

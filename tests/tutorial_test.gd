extends SceneTree
## Plays the first lair through the tutorial's opening tips: build where it points, call the
## first wave, and check each tip gives way to the next. Uses its own settings file.
## Run: godot --headless --script res://tests/tutorial_test.gd

const SETTINGS := "user://tutorial_test_settings.cfg"

var fails := 0


func _init() -> void:
	DirAccess.remove_absolute(SETTINGS)
	Prefs.path = SETTINGS
	_check(Tutorial.wanted(0, false), "tips run on the first lair")
	_check(not Tutorial.wanted(0, true) and not Tutorial.wanted(1, false), "not at night or on other lairs")

	var sim := GameSim.new(Level.load_from("res://levels/level_01.json"))
	var tut := Tutorial.new()
	var tip := tut.update(sim, 0.1)
	_check(tip.contains("Warband Hut"), "first tip: build a Hut")
	_check(tut.cell.x >= 0 and sim.level.terrain_at(tut.cell) == "moss", "it points at a moss tile")
	_check(sim.do_action("build", tut.cell) == "", "a Hut can be built where it points")

	tip = tut.update(sim, 0.1)
	_check(tip.contains("First wave"), "then: call the first wave")
	_check(tut.cell.x < 0, "no tile is pointed at any more")
	sim.call_early()
	tip = tut.update(sim, 0.1)
	_check(not tip.contains("First wave"), "calling the wave moves on")

	# Play on and tick the tips; every one either shows or is skipped, and none sticks for ever.
	var seen := {}
	for i in 6000:
		sim.update(0.05)
		tip = tut.update(sim, 0.05)
		if tip != "":
			seen[tip] = seen.get(tip, 0) + 1
			if seen[tip] > 400:
				tut.dismiss()   # a player would tap it away
		if sim.over:
			break
	print("tips shown: %d, done: %d of %d" % [seen.size(), tut.done.size(), Tutorial.TIPS.size()])
	_check(seen.size() >= 3, "several tips came up while playing")

	Prefs.set_value("tutorial_done", true)
	_check(not Tutorial.wanted(0, false), "no tips once done")
	DirAccess.remove_absolute(SETTINGS)
	print("tutorial_test: %s" % ("all passed" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: " + what)

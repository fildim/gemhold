extends SceneTree
## Plays the first lair through the tutorial the way a player would: whenever a tip is up, do what
## it points at (or tap "Got it"), and check each tip gives way to the next. Uses its own settings.
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
	tut.update(sim)
	_check(tut.text().contains("Warband Hut") and not tut.has_ok(), "first tip: build a Hut, by doing it")
	var cell: Vector2i = tut.target.get("cell", Vector2i(-1, -1))
	_check(cell.x >= 0 and sim.level.terrain_at(cell) == "moss", "it points at a moss tile")
	_check(tut.target.get("action") == "build:moss", "and then at the Hut button")
	_check(sim.do_action("build:moss", cell) == "", "a Hut can be built where it points")

	tut.update(sim)
	_check(tut.text().contains("First wave") and tut.target.get("button") == "next", "then: the First wave button")
	sim.call_early()
	tut.update(sim)
	_check(not tut.text().contains("First wave"), "calling the wave moves on")

	# Play on. The battle only runs while no tip is up, as in the game.
	var seen := {}
	for i in 12000:
		tut.update(sim)
		var tip := tut.text()
		if tip == "":
			sim.update(0.05)
		else:
			seen[tut._current_id()] = true
			_follow(tut, sim)
		if sim.over:
			break
	print("tips shown: %s; done %d of %d" % [seen.keys(), tut.done.size(), Tutorial.TIPS.size()])
	_check(seen.size() >= 4, "several tips came up while playing")
	_check(not seen.has("build"), "the build tip never came back")

	tut.finish()
	_check(not Tutorial.wanted(0, false), "no tips once done")
	DirAccess.remove_absolute(SETTINGS)
	print("tutorial_test: %s" % ("all passed" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)


## Does what the current tip asks, like a player tapping the lit spot.
func _follow(tut: Tutorial, sim: GameSim) -> void:
	if tut.has_ok():
		if tut.target.has("at") and not sim.loot.is_empty() and tut._current_id() == "loot":
			sim.collect_loot(tut.target["at"])
		else:
			tut.dismiss()
		return
	var t := tut.target
	if t.has("cell"):
		var err := sim.do_action(t["action"], t["cell"])
		_check(err == "", "the %s the tip asks for works (%s)" % [t["action"], err])
		if err != "":
			tut.dismiss()
	elif t.get("button") == "next":
		sim.call_early()
	elif t.get("button") == "meteor":
		tut.update(sim, true)
		_check(tut.target.has("map"), "armed meteor lights the whole map")
		sim.cast_meteor(sim.level.lair_center)
	else:
		tut.dismiss()


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: " + what)

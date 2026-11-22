extends SceneTree
## Measures the hidden threat (dynamic difficulty) the test bot meets at every wave of every
## campaign lair, by day with the standard Dark Arts (tests/bot.gd), over seeds 0, 101 and 202.
## Prints one JSON line per lair: CURVE {"n": campaign number, "id", "waves": [mean threat per wave]}.
## Used once to turn the old dynamic difficulty into a fixed per-wave curve (2026-11-22).
## Run: godot --headless --path . -s res://tests/threat_curve.gd -- 1 2 3   (campaign numbers)

const SEEDS := [0, 101, 202]


func _init() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/main.gd")
	var start := src.find("const LEVELS")
	var block := src.substr(start, src.find("\n\n", start) - start)
	var rx := RegEx.create_from_string(r"res://levels/level_[0-9]+[.]json")
	var paths: Array[String] = []
	for m in rx.search_all(block):
		paths.append(m.get_string())
	var want: Array[int] = []
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			want.append(int(a))
	if want.is_empty():
		for n in range(1, paths.size() + 1):
			want.append(n)
	for n in want:
		var waves := {}   # wave -> [sum, count] over all seeds
		for s in SEEDS:
			var lv := Level.load_from(paths[n - 1])
			var sim: GameSim = Bot.play(lv, Bot.skills(Bot.points_before(n - 1), n - 1), s)
			for w: int in sim.threat_seen:
				var e: Array = sim.threat_seen[w]
				var acc: Array = waves.get(w, [0.0, 0])
				waves[w] = [acc[0] + e[0] / e[1], acc[1] + 1]
		var lv0 := Level.load_from(paths[n - 1])
		var curve := []
		for w in range(1, lv0.waves.size() + 1):
			var acc: Array = waves.get(w, [0.0, 0])
			curve.append(snappedf(acc[0] / acc[1], 0.001) if acc[1] > 0 else -1.0)
		print("CURVE " + JSON.stringify({"n": n, "id": lv0.id, "waves": curve}))
	quit()

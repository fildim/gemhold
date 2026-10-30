extends SceneTree
## Checks every campaign level file for layout mistakes: grid sizes, woods on roads,
## sites on roads, and roads that don't end beside the lair.
## Run: godot --headless --script res://tests/level_check.gd

const MAIN := preload("res://scripts/main.gd")

var fails := 0


func _init() -> void:
	for path in MAIN.LEVELS:
		var json: JSON = load(path)
		var d: Dictionary = json.data
		var lv := Level.load_from(path)
		for key in ["terrain", "trees"]:
			_check(d[key].size() == lv.rows, "%s: %s has %d rows, expected %d" % [lv.id, key, d[key].size(), lv.rows])
			for r in d[key].size():
				_check(String(d[key][r]).length() == lv.cols, "%s: %s row %d has %d columns" % [lv.id, key, r, String(d[key][r]).length()])
		var sites := {}
		for s in lv.sites:
			sites[s["cell"]] = true
			_check(not lv.road.has(s["cell"]), "%s: site at %s is on a road" % [lv.id, s["cell"]])
			_check(not lv.is_lair(s["cell"]), "%s: site at %s is in the lair" % [lv.id, s["cell"]])
			if s["kind"] == "camp":
				_check(s["path"] < lv.paths.size(), "%s: camp at %s names a missing road" % [lv.id, s["cell"]])
		for c: Vector2i in lv.trees:
			_check(not lv.road.has(c), "%s: woods on road at %s" % [lv.id, c])
			_check(not lv.is_lair(c), "%s: woods in lair at %s" % [lv.id, c])
			_check(not sites.has(c), "%s: woods on site at %s" % [lv.id, c])
		for c: Vector2i in lv.road:
			_check(not lv.is_lair(c), "%s: road through lair at %s" % [lv.id, c])
		for i in lv.waypoints.size():
			var last: Vector2i = lv.waypoints[i][-1]
			var touches := false
			for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if lv.is_lair(last + dd):
					touches = true
			_check(touches, "%s: road %d ends at %s, not beside the lair" % [lv.id, i, last])
			var first: Vector2i = lv.waypoints[i][0]
			_check(not lv.in_bounds(first), "%s: road %d should start off the map edge" % [lv.id, i])
		for w in lv.waves:
			for code in w:
				_check(Defs.ENEMIES.has(code), "%s: unknown hero code %s" % [lv.id, code])
		print("%s ok: %d roads, %d sites, %d waves" % [lv.id, lv.paths.size(), lv.sites.size(), lv.waves.size()])
	print("level_check: %s" % ("all passed" if fails == 0 else "%d failed" % fails))
	quit(0 if fails == 0 else 1)


func _check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		printerr("FAIL: " + what)

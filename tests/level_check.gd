extends SceneTree
## Checks every campaign level file (and the level-format fixtures in tests/fixtures) for layout
## mistakes: grid sizes, woods on roads, sites on roads, roads that don't end beside the lair, and
## the level format v2 keys (water, river and air roads, wave routes and cargo, hallowed ground,
## lair rules, gem count).
## Run: godot --headless --script res://tests/level_check.gd

const MAIN := preload("res://scripts/main.gd")
const FIXTURES := ["res://tests/fixtures/level_v2.json"]
const RULE_KINDS := ["tide", "dusk", "eclipse"]

var fails := 0


func _init() -> void:
	for path in MAIN.LEVELS + FIXTURES:
		_check_file(path)
	print("level_check: %s" % ("all passed" if fails == 0 else "%d failed" % fails))
	quit(0 if fails == 0 else 1)


func _check_file(path: String) -> void:
	var json: JSON = load(path)
	var d: Dictionary = json.data
	var lv := Level.load_from(path)
	for key in ["terrain", "trees"]:
		_check(d[key].size() == lv.rows, "%s: %s has %d rows, expected %d" % [lv.id, key, d[key].size(), lv.rows])
		for r in d[key].size():
			_check(String(d[key][r]).length() == lv.cols, "%s: %s row %d has %d columns" % [lv.id, key, r, String(d[key][r]).length()])
			for ch in String(d[key][r]):
				if key == "terrain":
					_check(d["legend"].has(ch) or Level.WATER_LEGEND.has(ch), "%s: unknown terrain letter %s" % [lv.id, ch])
				else:
					_check(ch in [".", "T", "H"], "%s: unknown mark %s in trees" % [lv.id, ch])
	_check(lv.gems >= 5 and lv.gems <= 7, "%s: start.gems is %d, must be 5 to 7" % [lv.id, lv.gems])
	var sites := {}
	for s in lv.sites:
		sites[s["cell"]] = true
		_check(Defs.SITES.has(s["kind"]), "%s: unknown site kind %s" % [lv.id, s["kind"]])
		_check(not lv.road.has(s["cell"]), "%s: site at %s is on a road" % [lv.id, s["cell"]])
		_check(not lv.is_lair(s["cell"]), "%s: site at %s is in the lair" % [lv.id, s["cell"]])
		_check(not lv.is_water(s["cell"]), "%s: site at %s is on water" % [lv.id, s["cell"]])
		if s["kind"] == "camp":
			_check(s["path"] < lv.paths.size(), "%s: camp at %s names a missing road" % [lv.id, s["cell"]])
			if s["path"] < lv.paths.size():
				_check(lv.path_kind[s["path"]] == "land", "%s: camp at %s sends troops down a road that is not land" % [lv.id, s["cell"]])
	for c: Vector2i in lv.trees:
		_check(not lv.road.has(c), "%s: woods on road at %s" % [lv.id, c])
		_check(not lv.is_lair(c), "%s: woods in lair at %s" % [lv.id, c])
		_check(not sites.has(c), "%s: woods on site at %s" % [lv.id, c])
		_check(not lv.is_water(c), "%s: woods on water at %s" % [lv.id, c])
	for c: Vector2i in lv.hallowed:
		var buildable := not lv.road.has(c) and not lv.is_lair(c) and not sites.has(c) and not lv.is_water(c)
		_check(buildable, "%s: hallowed ground at %s is not buildable ground" % [lv.id, c])
	for c: Vector2i in lv.road:
		_check(not lv.is_lair(c), "%s: road through lair at %s" % [lv.id, c])
	var info: Array = d.get("path_info", [])
	_check(info.size() <= d["paths"].size(), "%s: path_info has more entries than paths" % lv.id)
	for i in d["paths"].size():
		var kind := lv.path_kind[i]
		_check(kind in Level.PATH_KINDS, "%s: road %d has unknown kind %s" % [lv.id, i, kind])
		var last: Vector2i = lv.waypoints[i][-1]
		var touches := false
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if lv.is_lair(last + dd):
				touches = true
		_check(touches, "%s: road %d ends at %s, not beside the lair" % [lv.id, i, last])
		var first: Vector2i = lv.waypoints[i][0]
		_check(not lv.in_bounds(first), "%s: road %d should start off the map edge" % [lv.id, i])
		if kind == "river":
			var entry := Vector2i(-1, -1)
			var t := 0.0
			while t < float(lv.paths[i]["total"]):   # the first tile the river road reaches on the map
				var p := lv.path_pos(i, t)
				if lv.in_bounds(Vector2i(floori(p.x), floori(p.y))):
					entry = Vector2i(floori(p.x), floori(p.y))
					break
				t += 0.1
			_check(lv.in_bounds(entry) and lv.is_water(entry), "%s: river road %d does not enter the map on water" % [lv.id, i])
			_check(lv.landing(i) >= 0.0, "%s: river road %d never reaches a landing" % [lv.id, i])
	_check(lv.land_roads.size() > 0 and lv.path_kind[lv.land_roads[0]] == "land", "%s: no land road" % lv.id)
	var rivers: Array[int] = []
	for i in lv.path_kind.size():
		if lv.path_kind[i] == "river":
			rivers.append(i)
	for wi in lv.waves.size():
		var roads: Array = lv.wave_roads[wi]
		for r in roads:
			_check(int(r) >= 0 and int(r) < lv.paths.size(), "%s: wave %d names missing road %d" % [lv.id, wi + 1, r])
		var has_river := not rivers.is_empty() if roads.is_empty() else rivers.any(func(r: int) -> bool: return roads.has(r))
		var boats := 0
		var walkers := 0
		for code: String in lv.waves[wi]:
			_check(Defs.ENEMIES.has(code), "%s: unknown hero code %s" % [lv.id, code])
			if Defs.ENEMIES.get(code, {}).get("boat", false):
				boats += 1
			else:
				walkers += 1
		_check(boats == 0 or has_river, "%s: wave %d has boats but no river road" % [lv.id, wi + 1])
		if walkers > 0 and not roads.is_empty():
			var any_land := roads.any(func(r) -> bool: return int(r) < lv.path_kind.size() and lv.path_kind[int(r)] == "land")
			_check(any_land, "%s: wave %d sends walkers but names no land road" % [lv.id, wi + 1])
		for k: String in lv.wave_cargo[wi]:
			_check(rivers.has(int(k)) and (roads.is_empty() or roads.has(int(k))), "%s: wave %d carries cargo on road %s, which is not one of its river roads" % [lv.id, wi + 1, k])
			for code: String in lv.wave_cargo[wi][k]:
				_check(Defs.ENEMIES.has(code), "%s: unknown hero code %s in cargo" % [lv.id, code])
	for rule in lv.rules:
		_check(rule is Dictionary and String(rule.get("kind", "")) in RULE_KINDS, "%s: unknown lair rule %s" % [lv.id, rule])
	print("%s ok: %d roads, %d sites, %d waves" % [lv.id, lv.paths.size(), lv.sites.size(), lv.waves.size()])


func _check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		printerr("FAIL: " + what)

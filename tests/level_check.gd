extends SceneTree
## Checks every campaign level file (and the level-format fixtures in tests/fixtures) for layout
## mistakes: grid sizes, woods on roads, sites on roads, roads that don't end beside the lair,
## water crowding a walking road (WATER_BESIDE_ROAD), and
## the level format v2 keys (water, river and air roads, wave routes and cargo, hallowed ground,
## lair rules, gem count).
## Run: godot --headless --script res://tests/level_check.gd

const MAIN := preload("res://scripts/main.gd")
const FIXTURES := ["res://tests/fixtures/level_v2.json", "res://tests/fixtures/level_siege.json", "res://tests/fixtures/level_radiant.json"]
const RULE_KINDS := ["tide", "dusk", "eclipse"]
## Nothing is built on water, so wide water hugging a road leaves no room for towers: of the 8
## tiles around a tile of a walking road (fords and bridges included; river and air roads are
## exempt), those that are not road themselves may hold at most this many water tiles, shallows
## and deep water together.
const WATER_BESIDE_ROAD := 2
## Spots the owner decides on, where the rule cannot hold without breaking a boat road or a
## bridge: level id -> {road tile: water tiles allowed beside it}. Nothing else may exceed the cap.
## Both are walking bridges over a river two tiles wide (deep water above and below each plank).
const WATER_BESIDE_EXCEPTIONS := {
	"level_22": {Vector2i(7, 1): 4, Vector2i(8, 1): 4, Vector2i(7, 8): 4, Vector2i(8, 8): 4},   # Twin Bridges
	"level_29": {Vector2i(5, 7): 4, Vector2i(6, 7): 4},   # The Flooded Abbey, the west road's bridge
}

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
	if d.has("night_hp"):
		_check(float(d["night_hp"]) > 0.3 and float(d["night_hp"]) <= 1.0, "%s: night_hp is %s, must be over 0.3 and at most 1.0" % [lv.id, d["night_hp"]])
	if d.has("race_hp"):
		_check(float(d["race_hp"]) > 0.2 and float(d["race_hp"]) <= 1.5, "%s: race_hp is %s, must be over 0.2 and at most 1.5" % [lv.id, d["race_hp"]])
	var sites := {}
	for s in lv.sites:
		sites[s["cell"]] = true
		_check(Defs.SITES.has(s["kind"]), "%s: unknown site kind %s" % [lv.id, s["kind"]])
		_check(not lv.road.has(s["cell"]), "%s: site at %s is on a road" % [lv.id, s["cell"]])
		_check(not lv.is_lair(s["cell"]), "%s: site at %s is in the lair" % [lv.id, s["cell"]])
		_check(not lv.is_water(s["cell"]), "%s: site at %s is on water" % [lv.id, s["cell"]])
		if Defs.MUSTER_SITES.has(s["kind"]):
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
		if rule is Dictionary and rule.get("kind", "") == "dusk":
			var dw := int(rule.get("wave", 0))
			_check(dw >= 2 and dw <= lv.waves.size(), "%s: dusk falls at wave %d, which is not a later wave of the lair" % [lv.id, dw])
	if MAIN.LEVELS.has(path):
		var allowed: Dictionary = WATER_BESIDE_EXCEPTIONS.get(lv.id, {})
		for c: Vector2i in walk_tiles(lv):
			var n := water_beside(lv, c)
			var cap: int = allowed.get(c, WATER_BESIDE_ROAD)
			_check(n <= cap, "%s: road tile %s has %d water tiles beside it (at most %d)" % [lv.id, c, n, cap])
		for c: Vector2i in allowed:   # an exception that is no longer needed should go
			_check(water_beside(lv, c) > WATER_BESIDE_ROAD, "%s: the exception at %s is no longer needed" % [lv.id, c])
	print("%s ok: %d roads, %d sites, %d waves" % [lv.id, lv.paths.size(), lv.sites.size(), lv.waves.size()])


## The tiles of the walking (land) roads: river and air roads are exempt from the water rule.
static func walk_tiles(lv: Level) -> Dictionary:
	var out := {}
	for i in lv.waypoints.size():
		if lv.path_kind[i] != "land":
			continue
		var wp: Array = lv.waypoints[i]
		for k in wp.size() - 1:
			var p: Vector2i = wp[k]
			var b: Vector2i = wp[k + 1]
			while true:
				if lv.in_bounds(p):
					out[p] = true
				if p == b:
					break
				p += Vector2i(signi(b.x - p.x), signi(b.y - p.y))
	return out


## How many of the tiles around road tile c (road tiles of any road not counted) are water,
## shallows or deep.
static func water_beside(lv: Level, c: Vector2i) -> int:
	var n := 0
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var o: Vector2i = c + Vector2i(dx, dy)
			if o != c and lv.in_bounds(o) and not lv.road.has(o) and lv.is_water(o):
				n += 1
	return n


func _check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		printerr("FAIL: " + what)

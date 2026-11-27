extends SceneTree
## One-off (owner, 2026-11-27): every lair that has buildings gets at least MIN_KINDS different
## kinds of them (nothing existing is removed), and Dark Altars go where they matter most: the free
## tile whose neighbours (the tower spots within the altar's reach) cover the most road, weighted
## towards the lair. Edits the level files as text (sites and woods only) and prints what it did.
##   godot --headless --path . -s res://tools/add_buildings.gd            (write)
##   godot --headless --path . -s res://tools/add_buildings.gd -- dry     (just print)
## Woods on a chosen tile are cleared. Then check with tests/level_check.gd.

const MIN_KINDS := 5
## The kinds added, in order, until a lair has MIN_KINDS (after a mine and a well), by chapter.
const ADD := {
	1: ["altar", "camp", "beacon", "chapel"], 2: ["altar", "camp", "beacon", "chapel"],
	3: ["altar", "camp", "beacon", "chapel"], 4: ["altar", "camp", "beacon", "workshop"],
	5: ["altar", "chapel", "camp", "beacon"],
}
const TOWER_REACH := 2.5   # a typical tower's range, for scoring a tower spot
## Heroes a new barracks may muster (walkers only: no bosses, boats, flyers or engines).
const NOT_MUSTER := ["boss", "boat", "fly", "siege", "belfry", "no_send", "sapper"]


func _init() -> void:
	var dry := OS.get_cmdline_user_args().has("dry")
	var order := _campaign_order()
	for pos in order.size():
		var path: String = order[pos]
		var chapter := pos / Defs.LAIRS_PER_CHAPTER + 1
		_one(path, chapter, dry)
	quit()


## The campaign order, read from main.gd's LEVELS (loading main.gd itself needs the autoloads).
func _campaign_order() -> Array:
	var src := FileAccess.get_file_as_string("res://scripts/main.gd")
	var at := src.find("const LEVELS")
	var line := src.substr(at, src.find("]", at + 30) - at)
	var out := []
	var re := RegEx.create_from_string("res://levels/level_\\d+\\.json")
	for m in re.search_all(line):
		out.append(m.get_string())
	return out


func _one(path: String, chapter: int, dry: bool) -> void:
	var lv := Level.load_from(path)
	if lv.sites.is_empty():
		return   # a lair without buildings (the first) stays so
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var taken := {}
	var kinds := {}
	for s in lv.sites:
		taken[s["cell"]] = true
		kinds[s["kind"]] = true
	var adds := []      # new site dictionaries
	var moves := {}     # old altar cell -> new cell
	# Altars that exist move to the best tile.
	for s in lv.sites:
		if s["kind"] == "altar":
			taken.erase(s["cell"])
			var best := _best_altar(lv, taken)
			taken[best] = true
			if best != s["cell"]:
				moves[s["cell"]] = best
	var want: Array = ["mine", "well"] + ADD[chapter]
	for k: String in want:
		if kinds.size() >= MIN_KINDS:
			break
		if kinds.has(k):
			continue
		var site := _place(lv, d, k, taken, chapter)
		if site.is_empty():
			print("%s: no room for %s" % [lv.id, k])
			continue
		taken[Vector2i(site["cell"][0], site["cell"][1])] = true
		kinds[k] = true
		adds.append(site)
	if adds.is_empty() and moves.is_empty():
		print("%s (ch %d): ok, %d kinds" % [lv.id, chapter, kinds.size()])
		return
	print("%s (ch %d): %s%s" % [lv.id, chapter, ", ".join(adds.map(func(a: Dictionary) -> String: return "%s at %s" % [a["kind"], a["cell"]])),
		"" if moves.is_empty() else "  altar moved %s" % str(moves)])
	if not dry:
		_write(path, adds, moves)


## Free tiles a building may stand on.
func _free(lv: Level, c: Vector2i, taken: Dictionary) -> bool:
	return lv.in_bounds(c) and not lv.road.has(c) and not lv.is_lair(c) and not lv.is_water(c) \
		and not taken.has(c) and not lv.high.has(c) and not lv.hallowed.has(c)


func _cells(lv: Level) -> Array:
	var out := []
	for y in lv.rows:
		for x in lv.cols:
			out.append(Vector2i(x, y))
	return out


## Road tiles that matter: walked land road, closer to the lair = more important (gems are near).
func _road_weight(lv: Level, r: Vector2i) -> float:
	var dl := (Vector2(r) + Vector2(0.5, 0.5)).distance_to(lv.lair_center)
	return 1.0 + 3.0 / (1.0 + dl * 0.5)


## A tower spot's worth: the weighted road within a tower's reach.
func _spot(lv: Level, b: Vector2i, roads: Array) -> float:
	var v := 0.0
	var pb := Vector2(b) + Vector2(0.5, 0.5)
	for r: Vector2i in roads:
		if pb.distance_to(Vector2(r) + Vector2(0.5, 0.5)) <= TOWER_REACH:
			v += _road_weight(lv, r)
	return v


func _best_altar(lv: Level, taken: Dictionary) -> Vector2i:
	var roads: Array = lv.road.keys()
	var spot := {}
	for c: Vector2i in _cells(lv):
		if not lv.road.has(c) and not lv.is_lair(c) and not lv.is_water(c) and not taken.has(c):
			spot[c] = _spot(lv, c, roads)
	var best := Vector2i(-1, -1)
	var best_v := -1.0
	var reach := float(Defs.SITES["altar"]["range"])
	for c: Vector2i in _cells(lv):
		if not _free(lv, c, taken):
			continue
		var v := 0.0
		for b: Vector2i in spot:
			if b != c and (Vector2(b)).distance_to(Vector2(c)) <= reach:
				v += spot[b]
		v -= spot.get(c, 0.0) * 0.5   # the altar takes its own tile from the towers
		if v > best_v:
			best_v = v
			best = c
	return best


func _place(lv: Level, d: Dictionary, kind: String, taken: Dictionary, chapter: int) -> Dictionary:
	var cuts := {}
	match kind:
		"mine", "well", "beacon":
			# Out of the way: the free tile furthest from the lair, off the roads' edges.
			var best := Vector2i(-1, -1)
			var bv := -INF
			for c: Vector2i in _cells(lv):
				if not _free(lv, c, taken):
					continue
				var v := (Vector2(c) + Vector2(0.5, 0.5)).distance_to(lv.lair_center) - (3.0 if _by_road(lv, c) else 0.0)
				if v > bv:
					bv = v
					best = c
			if best.x < 0:
				return {}
			var out := {"kind": kind, "cell": [best.x, best.y]}
			out.merge(cuts)
			return out
		"altar":
			var c := _best_altar(lv, taken)
			return {} if c.x < 0 else {"kind": "altar", "cell": [c.x, c.y]}
		"chapel":
			# Beside a road, midway: heals the heroes walking past, away from the lair.
			var best := Vector2i(-1, -1)
			var bv := -INF
			var r := float(Defs.SITES["chapel"]["r"])
			for c: Vector2i in _cells(lv):
				if not _free(lv, c, taken) or not _by_road(lv, c):
					continue
				var pc := Vector2(c) + Vector2(0.5, 0.5)
				var dl := pc.distance_to(lv.lair_center)
				if dl < 4.0:
					continue
				var v := 0.0
				for rc: Vector2i in lv.road:
					if pc.distance_to(Vector2(rc) + Vector2(0.5, 0.5)) <= r:
						v += 1.0
				v -= absf(dl - 7.0) * 0.3
				if v > bv:
					bv = v
					best = c
			return {} if best.x < 0 else {"kind": "chapel", "cell": [best.x, best.y]}
		"camp", "workshop":
			var used := {}
			for s in lv.sites:
				if s.has("path"):
					used[s["path"]] = true
			var road_i := -1
			for i in lv.paths.size():
				if lv.path_kind[i] == "land" and not used.has(i):
					road_i = i
					break
			if road_i < 0:
				road_i = lv.land_roads[0]
			var start := _entry(lv, road_i)
			var best := Vector2i(-1, -1)
			var bv := INF
			for c: Vector2i in _cells(lv):
				if not _free(lv, c, taken) or not _by_road(lv, c):
					continue
				var v := Vector2(c).distance_to(Vector2(start))
				if v < bv:
					bv = v
					best = c
			if best.x < 0:
				return {}
			var out := {"kind": kind, "cell": [best.x, best.y], "path": road_i}
			if kind == "workshop":
				out.merge({"spawn": "1u", "every": 60})
			else:
				out.merge({"spawn": _muster(lv), "every": 32})
			out.merge(cuts)
			return out
	return {}


func _by_road(lv: Level, c: Vector2i) -> bool:
	for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if lv.road.has(c + o):
			return true
	return false


## Where a road comes onto the map: its first waypoint inside the grid (or the clamped first one).
func _entry(lv: Level, i: int) -> Vector2i:
	var wp: Array = lv.waypoints[i]
	var a: Vector2i = wp[0]
	return Vector2i(clampi(a.x, 0, lv.cols - 1), clampi(a.y, 0, lv.rows - 1))


## A small squad from the lair's own early heroes: two of the commonest walker, one of the next.
func _muster(lv: Level) -> String:
	var count := {}
	for w in range(0, mini(4, lv.waves.size())):
		for code: String in lv.waves[w]:
			var e: Dictionary = Defs.ENEMIES[code]
			var ok := true
			for k in NOT_MUSTER:
				if e.has(k):
					ok = false
			if ok and not e.has("special"):
				count[code] = int(count.get(code, 0)) + 1
	var codes: Array = count.keys()
	codes.sort_custom(func(a: String, b: String) -> bool: return count[a] > count[b])
	if codes.is_empty():
		return "2p"
	if codes.size() == 1:
		return "3%s" % codes[0]
	return "2%s,1%s" % [codes[0], codes[1]]


## Text edit: append new sites, move altars, clear woods under them.
func _write(path: String, adds: Array, moves: Dictionary) -> void:
	var lines := FileAccess.get_file_as_string(path).split("\n")
	var clear := []
	for a: Dictionary in adds:
		clear.append(Vector2i(a["cell"][0], a["cell"][1]))
	for v: Vector2i in moves.values():
		clear.append(v)
	# Sites block.
	var s0 := -1
	var s1 := -1
	for i in lines.size():
		if lines[i].strip_edges().begins_with("\"sites\": ["):
			s0 = i
		elif s0 >= 0 and s1 < 0 and lines[i].strip_edges().begins_with("]"):
			s1 = i
	for i in range(s0 + 1, s1):
		var l: String = lines[i]
		if l.contains("altar"):
			var site: Dictionary = JSON.parse_string(l.strip_edges().trim_suffix(","))
			var c := Vector2i(int(site["cell"][0]), int(site["cell"][1]))
			if moves.has(c):
				var n: Vector2i = moves[c]
				site["cell"] = [n.x, n.y]
				lines[i] = "  " + JSON.stringify(site, "", false) + ("," if l.strip_edges().ends_with(",") else "")
	if not adds.is_empty():
		if not lines[s1 - 1].strip_edges().ends_with(","):
			lines[s1 - 1] += ","
		var news := []
		for j in adds.size():
			news.append("  " + JSON.stringify(adds[j], "", false) + ("," if j < adds.size() - 1 else ""))
		for j in range(news.size() - 1, -1, -1):
			lines.insert(s1, news[j])
	# Woods.
	var t0 := -1
	for i in lines.size():
		if lines[i].strip_edges().begins_with("\"trees\": ["):
			t0 = i
			break
	if t0 >= 0:
		for c: Vector2i in clear:
			var li := t0 + 1 + c.y
			var l: String = lines[li]
			var q := l.find("\"")
			var ch := q + 1 + c.x
			if l[ch] != ".":
				lines[li] = l.substr(0, ch) + "." + l.substr(ch + 1)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()

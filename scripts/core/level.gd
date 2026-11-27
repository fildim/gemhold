class_name Level
extends RefCounted
## One map, loaded from a JSON file in res://levels/.
## To add a level: copy level_01.json, change the grids, paths and waves, and list it in main.gd.

var id := ""
var title := ""
var intro := ""          # optional story text (kept in the level files; the start card no longer shows it)
var cols := 0
var rows := 0
var terrain := {}        # Vector2i -> "moss" | "frost" | "ash" | "lair"
var high := {}           # Vector2i -> true for raised tiles (a capital letter in the terrain grid)
var trees := {}          # Vector2i -> true
var road := {}           # Vector2i -> true
var waypoints: Array = []  # Array of Array[Vector2i], one per road
var paths: Array = []    # Array of {"pts": PackedVector2Array, "len": PackedFloat32Array, "total": float}
var lair_rect := Rect2i()
var lair_center := Vector2.ZERO
var start_gold := 0
var start_mana := 0.0
var gems := 0
var first_delay := 15.0
var wave_gap := 24.0
var waves: Array = []    # Array of Array[String] hero codes
var own_waves := 0         # the lair's own wave count (the Long Night adds more: extend_long)
var wave_roads: Array = []   # parallel to waves: Array[int] of road indexes the wave may use; empty = every land road
var wave_cargo: Array = []   # parallel to waves: {road index (String) -> Array[String] hero codes} carried by boats
var wave_walk: Array = []    # parallel to waves: Array[int] of land roads its walkers are dealt over
var wave_deal: Array = []    # parallel to waves: wave_walk with the long roads twice (see deal)
var night := false       # only lit tiles can be built on (set for night missions)
var hp_mul := 1.0        # hero health multiplier, so later levels can be tougher
var night_hp := Defs.NIGHT_HP   # hero health factor on the night mission ("night_hp" in the file; most lairs keep the default)
var race_hp: float = Defs.RACE["hp"]   # hero health factor in an online race ("race_hp" in the file; most lairs keep the default)
## Hero health by wave on top of hp_mul ("curve" in the file): curve[w - 1] for wave w, 1.0 at wave 1 and
## never falling. It replaced the old dynamic difficulty (2026-11-22): its shape is the threat the test bot
## met at each wave, so late waves stay as hard as they were. Waves past its end keep its last value.
var curve: PackedFloat32Array = []
## How much tougher each wave's heroes are than the first, per wave ("wave_hp" in the file; default
## Defs.WAVE_HP_SCALE): hero health grows by 1 + wave_hp × (wave - 1), on top of the curve.
var wave_hp: float = Defs.WAVE_HP_SCALE
var sites: Array = []    # [{"kind", "cell": Vector2i, "path", "spawn": Array[String], "every"}]
var site_cuts := 1       # cuts (each paid in mana) to free a mine or well or raze a barracks; grows on later lairs
var site_mana := 1.0     # multiplies the mana of every building cut; rises through the campaign (tools/set_site_mana.gd)
var path_kind: Array[String] = []   # parallel to paths: "land" | "river" | "air"
var land_roads: Array[int] = []     # indexes of the land roads, where heroes are dealt by default
var zones: Array = []    # parallel to paths: Array of {"from", "to", "kind": "ford" | "bridge"} along the road
var hallowed := {}       # Vector2i -> true for hallowed ground (an `H` in the trees grid)
var rules: Array = []    # lair rules, e.g. [{"kind": "tide", "period": 40, "up": 14}]
var wave_rivers: Array = []  # parallel to waves: Array[int] of river roads its boats use
var wave_air: Array = []     # parallel to waves: Array[int] of air roads its flyers use
var landings: Array = []     # per road: where a river road reaches land (Level.landing), or -1
var crossings := {}          # Vector2i -> index in crossing_cells: land-road tiles over water
var crossing_cells: Array = []   # each crossing's tiles (a bridge over deep water or a ford over shallows)
var crossing_kind: Array[String] = []   # "bridge" | "ford", parallel to crossing_cells

const CORNER_RADIUS := 0.5   # tiles; roads curve through their corner tiles
const ZONE_STEP := 0.1       # tiles between samples when finding a road's zones
## Terrain letters every level understands without a legend entry.
const WATER_LEGEND := {"w": "water", "o": "shallows"}
const WATER := ["water", "shallows"]
const PATH_KINDS := ["land", "river", "air"]


static func load_from(path: String) -> Level:
	var json: JSON = load(path)
	assert(json != null, "Level file missing: " + path)
	var lv := Level.new()
	lv._parse(json.data)
	return lv


func _parse(d: Dictionary) -> void:
	id = d["id"]
	title = d["title"]
	intro = d.get("intro", "")
	cols = int(d["cols"])
	rows = int(d["rows"])
	var legend: Dictionary = d["legend"]
	for r in rows:
		var trow: String = d["terrain"][r]
		var tree_row: String = d["trees"][r]
		for c in cols:
			var kind: String = legend.get(trow[c], WATER_LEGEND.get(trow[c], "moss"))
			if kind.begins_with("high "):
				kind = kind.trim_prefix("high ")
				high[Vector2i(c, r)] = true
			terrain[Vector2i(c, r)] = kind
			if tree_row[c] == "T":
				trees[Vector2i(c, r)] = true
			elif tree_row[c] == "H":
				hallowed[Vector2i(c, r)] = true
	var lc: Array = d["lair"]["cell"]
	var ls: Array = d["lair"]["size"]
	lair_rect = Rect2i(int(lc[0]), int(lc[1]), int(ls[0]), int(ls[1]))
	lair_center = Vector2(d["lair"]["center"][0], d["lair"]["center"][1])
	start_gold = int(d["start"]["gold"])
	start_mana = float(d["start"]["mana"])
	gems = int(d["start"]["gems"])
	first_delay = float(d["first_wave_delay"])
	wave_gap = float(d["wave_gap"])
	for w in d["waves"]:
		# A wave is "6p,2f", or {"heroes": "6p,2f", "roads": [0, 2], "cargo": {"1": "2k"}}.
		var roads: Array[int] = []
		var cargo := {}
		if w is Dictionary:
			for i in w.get("roads", []):
				roads.append(int(i))
			var cg: Dictionary = w.get("cargo", {})
			for k in cg:
				cargo[str(k)] = _parse_wave(String(cg[k]))
			waves.append(_parse_wave(String(w.get("heroes", ""))))
		else:
			waves.append(_parse_wave(String(w)))
		wave_roads.append(roads)
		wave_cargo.append(cargo)
	own_waves = waves.size()
	rules = d.get("rules", []).duplicate(true)
	night = bool(d.get("night", false))
	hp_mul = float(d.get("hp_mul", 1.0))
	night_hp = float(d.get("night_hp", Defs.NIGHT_HP))
	race_hp = float(d.get("race_hp", Defs.RACE["hp"]))
	wave_hp = float(d.get("wave_hp", Defs.WAVE_HP_SCALE))
	for v in d.get("curve", []):
		curve.append(float(v))
	site_cuts = maxi(1, int(d.get("site_cuts", 1)))
	site_mana = float(d.get("site_mana", 1.0))
	for s in d.get("sites", []):
		var site := {"kind": String(s["kind"]), "cell": Vector2i(int(s["cell"][0]), int(s["cell"][1]))}
		if s.has("cuts"):
			site["cuts"] = maxi(1, int(s["cuts"]))
		if site["kind"] == "sluice":
			site["path"] = int(s.get("path", 0))
		if Defs.MUSTER_SITES.has(site["kind"]):
			site["path"] = int(s.get("path", 0))
			site["spawn"] = _parse_wave(String(s.get("spawn", "1p")))
			site["every"] = float(s.get("every", 25.0))
		sites.append(site)
	var info0: Array = d.get("path_info", [])
	for pi in d["paths"].size():
		var p: Array = d["paths"][pi]
		var wp: Array[Vector2i] = []
		for pt in p:
			wp.append(Vector2i(int(pt[0]), int(pt[1])))
		waypoints.append(wp)
		var air: bool = pi < info0.size() and info0[pi] is Dictionary and String(info0[pi].get("kind", "")) == "air"
		if not air:   # flyers pass over the ground: an air road blocks no building
			_rasterize_road(wp)
		var pts := PackedVector2Array()
		for v in wp:
			pts.append(Vector2(v) + Vector2(0.5, 0.5))
		pts.append(lair_center)
		pts = _round_corners(pts, CORNER_RADIUS)
		var lens := PackedFloat32Array([0.0])
		for i in range(1, pts.size()):
			lens.append(lens[i - 1] + pts[i].distance_to(pts[i - 1]))
		paths.append({"pts": pts, "len": lens, "total": lens[lens.size() - 1]})
	var info: Array = d.get("path_info", [])
	for i in paths.size():
		var kind := "land"
		if i < info.size() and info[i] is Dictionary:
			kind = String(info[i].get("kind", "land"))
		path_kind.append(kind)
		if kind == "land":
			land_roads.append(i)
	if land_roads.is_empty():
		land_roads.append(0)   # a level with no land road still needs somewhere to send heroes
	for roads: Array in wave_roads:
		var walk: Array[int] = []
		for r: int in roads:
			if land_roads.has(r):
				walk.append(r)
		wave_walk.append(walk if not walk.is_empty() else land_roads)
	for walk: Array[int] in wave_walk:
		wave_deal.append(deal(walk))
	var rivers: Array[int] = []
	for i in path_kind.size():
		if path_kind[i] == "river":
			rivers.append(i)
	for roads: Array in wave_roads:
		var boat: Array[int] = []
		for r: int in roads:
			if rivers.has(r):
				boat.append(r)
		wave_rivers.append(boat if not boat.is_empty() else rivers)
	_add_air_roads()
	var airs: Array[int] = []
	for i in path_kind.size():
		if path_kind[i] == "air":
			airs.append(i)
	for roads: Array in wave_roads:
		var fly: Array[int] = []
		for r: int in roads:
			if airs.has(r):
				fly.append(r)
		wave_air.append(fly if not fly.is_empty() else airs)
	for i in paths.size():
		zones.append(_find_zones(i))
	for i in paths.size():
		landings.append(landing(i) if path_kind[i] == "river" else -1.0)
	_find_crossings()


## Flyers need an air road. A level that sends flyers without one gets a straight line from the
## start of each land road to the lair centre.
func _add_air_roads() -> void:
	if path_kind.has("air"):
		return
	var flyers := false
	for w: Array in waves:
		for code: String in w:
			flyers = flyers or bool(Defs.ENEMIES.get(code, {}).get("fly", false))
	if not flyers:
		return
	for i in land_roads.duplicate():
		var a: Vector2 = paths[i]["pts"][0]
		var pts := PackedVector2Array([a, lair_center])
		var lens := PackedFloat32Array([0.0, a.distance_to(lair_center)])
		paths.append({"pts": pts, "len": lens, "total": lens[1]})
		waypoints.append(waypoints[i].duplicate())
		path_kind.append("air")


## Stretches of road i over water: a ford over shallows, a bridge over deep water. Sampled every
## ZONE_STEP tiles; air roads have none.
func _find_zones(i: int) -> Array:
	var out: Array = []
	if path_kind[i] != "land":
		return out   # boats float on rivers; flyers fly
	var total: float = paths[i]["total"]
	var cur := ""
	var start := 0.0
	var k := 0
	while true:
		var t := minf(k * ZONE_STEP, total)
		var p := path_pos(i, t)
		var kind := ""
		match terrain_at(Vector2i(floori(p.x), floori(p.y))):
			"shallows":
				kind = "ford"
			"water":
				kind = "bridge"
		if kind != cur:
			if cur != "":
				out.append({"from": start, "to": t, "kind": cur})
			cur = kind
			start = t
		if t >= total:
			break
		k += 1
	if cur != "":
		out.append({"from": start, "to": total, "kind": cur})
	return out


## The zone kind ("ford", "bridge") at distance t along road i, or "".
func zone_at(i: int, t: float) -> String:
	for z: Dictionary in zones[i]:
		if t >= z["from"] and t < z["to"]:
			return z["kind"]
	return ""


func is_water(c: Vector2i) -> bool:
	return WATER.has(terrain_at(c))


## Where a river road's boats reach land: the distance of the first sample not over water, or -1.
func landing(i: int) -> float:
	var total: float = paths[i]["total"]
	var t := 0.0
	var seen_water := false
	while t <= total:
		var p := path_pos(i, t)
		var c := Vector2i(floori(p.x), floori(p.y))
		if in_bounds(c):
			if is_water(c):
				seen_water = true
			elif seen_water:
				return t
		t += ZONE_STEP
	return -1.0


## Swaps each sharp turn for a curve that starts and ends r tiles from the corner, so roads
## bend instead of snapping at right angles. The curve stays inside the corner tile.
static func _round_corners(pts: PackedVector2Array, r: float) -> PackedVector2Array:
	var out := PackedVector2Array([pts[0]])
	for i in range(1, pts.size() - 1):
		var c := pts[i]
		var din := c - pts[i - 1]
		var dout := pts[i + 1] - c
		if din.normalized().dot(dout.normalized()) > 0.99:
			out.append(c)   # straight on, nothing to round
			continue
		var a := c - din.normalized() * minf(r, din.length() * 0.5)
		var b := c + dout.normalized() * minf(r, dout.length() * 0.5)
		out.append(a)
		for k in range(1, 8):
			var t := k / 8.0
			out.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
		out.append(b)
	out.append(pts[pts.size() - 1])
	return out


## "6p,2f" -> ["p", "p", "p", "p", "p", "p", "f", "f"]
static func _parse_wave(w: String) -> Array[String]:
	var list: Array[String] = []
	for part in w.split(","):
		var n := int(part.to_int())
		var code := part.strip_edges().right(1)
		for i in n:
			list.append(code)
	return list


## Distance along road i to the point closest to pos (used to place barracks troops).
func nearest_dist(i: int, pos: Vector2) -> float:
	var p: Dictionary = paths[i]
	var pts: PackedVector2Array = p["pts"]
	var lens: PackedFloat32Array = p["len"]
	var best := 0.0
	var best_d := INF
	for k in range(1, pts.size()):
		var q := Geometry2D.get_closest_point_to_segment(pos, pts[k - 1], pts[k])
		var dd := q.distance_to(pos)
		if dd < best_d:
			best_d = dd
			best = lens[k - 1] + pts[k - 1].distance_to(q)
	return best


func _rasterize_road(wp: Array[Vector2i]) -> void:
	for i in wp.size() - 1:
		var a := wp[i]
		var b := wp[i + 1]
		var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
		var p := a
		while true:
			if in_bounds(p):
				road[p] = true
			if p == b:
				break
			p += step


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows


func is_lair(c: Vector2i) -> bool:
	return lair_rect.has_point(c)


func terrain_at(c: Vector2i) -> String:
	return terrain.get(c, "moss")


## Position (in tiles) after travelling distance t along road number i.
func path_pos(i: int, t: float) -> Vector2:
	var p: Dictionary = paths[i]
	var pts: PackedVector2Array = p["pts"]
	var lens: PackedFloat32Array = p["len"]
	t = clampf(t, 0.0, p["total"])
	var k := 1
	while k < lens.size() - 1 and lens[k] < t:
		k += 1
	var seg := lens[k] - lens[k - 1]
	var f := 0.0 if seg == 0.0 else (t - lens[k - 1]) / seg
	return pts[k - 1].lerp(pts[k], f)


## Land-road tiles over water, grouped into crossings: each run of connected road tiles over
## deep water is one bridge (collapsed and repaired as a whole), over shallows one ford.
func _find_crossings() -> void:
	var tiles := {}
	for i in waypoints.size():
		if path_kind[i] != "land":
			continue
		var wp: Array = waypoints[i]
		for k in wp.size() - 1:
			var a: Vector2i = wp[k]
			var b: Vector2i = wp[k + 1]
			var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
			var p := a
			while true:
				if in_bounds(p) and is_water(p):
					tiles[p] = terrain_at(p)
				if p == b:
					break
				p += step
	for start: Vector2i in tiles:
		if crossings.has(start):
			continue
		var idx := crossing_cells.size()
		var kind: String = tiles[start]
		var group: Array[Vector2i] = []
		var todo: Array[Vector2i] = [start]
		crossings[start] = idx
		while not todo.is_empty():
			var c: Vector2i = todo.pop_back()
			group.append(c)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + d
				if tiles.get(n, "") == kind and not crossings.has(n):
					crossings[n] = idx
					todo.append(n)
		crossing_cells.append(group)
		crossing_kind.append("bridge" if kind == "water" else "ford")


## Land roads shorter than this (tiles, edge to den) leave towers too little room, so when a wave
## also walks longer roads, a short one gets only half a share of its heroes.
const SHORT_ROAD := 7.0


## The order heroes are dealt over `roads`: every road once, then the long ones again, so a short
## road gets one hero for every two on a long one. Only short roads: plain round-robin.
func deal(roads: Array[int]) -> Array[int]:
	var out: Array[int] = roads.duplicate()
	for r in roads:
		if float(paths[r]["total"]) >= SHORT_ROAD:
			out.append(r)
	return out if out.size() > roads.size() else roads


## The Long Night: adds one more wave after the lair's own, copied in turn from its last
## Defs.LONG["cycle"] waves (roads, boats and flyers included), with one more of the wave's most
## common hero for every Defs.LONG["extra_every"] waves past the lair's end. base: the lair's own
## wave count (the first call's waves.size()).
func extend_long(base: int) -> void:
	var cycle := mini(int(Defs.LONG["cycle"]), base)
	var past := waves.size() - base   # long waves added so far
	var src := base - cycle + past % cycle
	var list: Array[String] = waves[src].duplicate()
	var count := {}
	for code in list:
		if not Defs.ENEMIES[code].get("boss", false) and not Defs.ENEMIES[code].has("siege"):   # never more than MAX_SIEGE engines
			count[code] = int(count.get(code, 0)) + 1
	if not count.is_empty():
		var common: String = count.keys()[0]
		for code: String in count:
			if count[code] > count[common]:
				common = code
		for i in (past + 1) / int(Defs.LONG["extra_every"]):
			list.append(common)
	waves.append(list)
	for arr: Array in [wave_roads, wave_cargo, wave_walk, wave_deal, wave_rivers, wave_air]:
		if src < arr.size():
			arr.append(arr[src].duplicate(true))


## The hero health factor of wave w (1 for a level without a curve, or before the first wave).
func wave_curve(w: int) -> float:
	if curve.is_empty() or w < 1:
		return 1.0
	return curve[mini(w, curve.size()) - 1]

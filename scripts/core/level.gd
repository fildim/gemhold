class_name Level
extends RefCounted
## One map, loaded from a JSON file in res://levels/.
## To add a level: copy level_01.json, change the grids, paths and waves, and list it in main.gd.

var id := ""
var title := ""
var intro := ""          # optional story text for the start screen
var cols := 0
var rows := 0
var terrain := {}        # Vector2i -> "moss" | "frost" | "ash" | "high" | "lair"
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
var night := false       # only lit tiles can be built on (set for night missions)
var hp_mul := 1.0        # hero health multiplier, so later levels can be tougher
var sites: Array = []    # [{"kind", "cell": Vector2i, "path", "spawn": Array[String], "every"}]


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
			terrain[Vector2i(c, r)] = legend[trow[c]]
			if tree_row[c] == "T":
				trees[Vector2i(c, r)] = true
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
		waves.append(_parse_wave(String(w)))
	night = bool(d.get("night", false))
	hp_mul = float(d.get("hp_mul", 1.0))
	for s in d.get("sites", []):
		var site := {"kind": String(s["kind"]), "cell": Vector2i(int(s["cell"][0]), int(s["cell"][1]))}
		if site["kind"] == "camp":
			site["path"] = int(s.get("path", 0))
			site["spawn"] = _parse_wave(String(s.get("spawn", "1p")))
			site["every"] = float(s.get("every", 25.0))
		sites.append(site)
	for p in d["paths"]:
		var wp: Array[Vector2i] = []
		for pt in p:
			wp.append(Vector2i(int(pt[0]), int(pt[1])))
		waypoints.append(wp)
		_rasterize_road(wp)
		var pts := PackedVector2Array()
		for v in wp:
			pts.append(Vector2(v) + Vector2(0.5, 0.5))
		pts.append(lair_center)
		var lens := PackedFloat32Array([0.0])
		for i in range(1, pts.size()):
			lens.append(lens[i - 1] + pts[i].distance_to(pts[i - 1]))
		paths.append({"pts": pts, "len": lens, "total": lens[lens.size() - 1]})


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

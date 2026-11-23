extends SceneTree
## Writes level files from compact specs (tools/lair_specs.gd): ground and water as rectangles,
## raised tiles, hallowed ground ("hallowed": [[x, y], ...]), roads, buildings, waves and rules; woods are scattered from a seed, never on
## roads, water, buildings, raised tiles or next to the lair. "dry": [[letter, x, y], ...] lays open
## ground over water after the woods (where water would crowd a walking road: WATER_BESIDE_ROAD is
## checked for every lair and reported). Edit a spec and run again:
##   godot --headless --path . -s res://tools/make_lairs.gd            (every spec)
##   godot --headless --path . -s res://tools/make_lairs.gd -- 21 25   (just those numbers)
## Then check with tests/level_check.gd. hp_mul is tuned afterwards with tests/difficulty.gd and
## kept: a spec's "hp_mul" is only the starting value for a file that does not exist yet. A file's
## "night_hp" (night hero health, set by hand) and "race_hp" (race hero health, tuned with
## tests/race_test.gd) are kept too, and so is "curve" (the per-wave hero health curve).

const SPECS := preload("res://tools/lair_specs.gd")
const WATER_BESIDE_ROAD := 2
const LEGEND := {"m": "moss", "f": "frost", "a": "ash", "M": "high moss", "F": "high frost", "A": "high ash", "L": "lair"}


func _init() -> void:
	var only := OS.get_cmdline_user_args()
	for spec: Dictionary in SPECS.LAIRS:
		if not only.is_empty() and not only.has(str(spec["n"])):
			continue
		var path := "res://levels/level_%02d.json" % spec["n"]
		var d := _build(spec)
		if FileAccess.file_exists(path):   # keep a tuned hero health
			var old = JSON.parse_string(FileAccess.get_file_as_string(path))
			if old is Dictionary and old.has("hp_mul"):
				d["hp_mul"] = old["hp_mul"]
			if old is Dictionary and (old.has("night_hp") or old.has("race_hp") or old.has("curve")):   # and a tuned night and race health and the health curve, right after hp_mul
				var keep := {}
				for k: String in d:
					keep[k] = d[k]
					if k == "hp_mul":
						for extra in ["night_hp", "race_hp", "curve"]:
							if old.has(extra):
								keep[extra] = old[extra]
				d = keep
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(_pretty(d))
		print("wrote %s: %s" % [path, d["title"]])
	quit(0)


func _build(s: Dictionary) -> Dictionary:
	var cols: int = s.get("cols", 16)
	var rows: int = s.get("rows", 10)
	var grid := []
	for r in rows:
		var row := []
		for c in cols:
			row.append(s.get("base", "m"))
		grid.append(row)
	for rect: Array in s.get("ground", []) + s.get("water", []):
		for r in range(rect[2], rect[4] + 1):
			for c in range(rect[1], rect[3] + 1):
				if c >= 0 and r >= 0 and c < cols and r < rows:
					grid[r][c] = rect[0]
	for h: Array in s.get("high", []):
		grid[h[1]][h[0]] = h[2]
	var lc: Array = s["lair"]
	for r in range(lc[1], lc[1] + 2):
		for c in range(lc[0], lc[0] + 2):
			grid[r][c] = "L"
	# Road tiles, to keep woods off them.
	var road := {}
	for p: Array in s["paths"]:
		for k in p.size() - 1:
			var a := Vector2i(p[k][0], p[k][1])
			var b := Vector2i(p[k + 1][0], p[k + 1][1])
			var q := a
			while true:   # straight or diagonal (flight lines), one tile at a time
				road[q] = true
				if q == b:
					break
				q += Vector2i(signi(b.x - q.x), signi(b.y - q.y))
	var sites := {}
	for st: Dictionary in s.get("sites", []):
		sites[Vector2i(st["cell"][0], st["cell"][1])] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = int(s.get("seed", s["n"] * 977))
	var trees := []
	for r in rows:
		var line := ""
		for c in cols:
			var v := Vector2i(c, r)
			var t: String = grid[r][c]
			var near_lair := absf(c - lc[0] - 0.5) <= 2.0 and absf(r - lc[1] - 0.5) <= 2.0
			var by_road := road.has(v + Vector2i(1, 0)) or road.has(v - Vector2i(1, 0)) or road.has(v + Vector2i(0, 1)) or road.has(v - Vector2i(0, 1))
			if v in (s.get("hallowed", []) as Array).map(func(x: Array) -> Vector2i: return Vector2i(x[0], x[1])):
				line += "H"   # hallowed ground, kept clear of woods
				continue
			var ok := not road.has(v) and not sites.has(v) and t in ["m", "f", "a"] and not near_lair
			var chance: float = s.get("woods_road", 0.25) if by_road else s.get("woods", 0.45)
			if ok and (v in (s.get("woods_at", []) as Array).map(func(x: Array) -> Vector2i: return Vector2i(x[0], x[1])) or rng.randf() < chance):
				line += "T"
			else:
				line += "."
		trees.append(line)
	# Dry ground laid over water after the woods are scattered, so the woods elsewhere stay where
	# they were and the new ground is open: [letter, x, y]. Used where water crowded a road.
	for dc: Array in s.get("dry", []):
		grid[dc[2]][dc[1]] = dc[0]
	# The water rule (tests/level_check.gd, which also lists the owner's exceptions): of the tiles
	# around a walking-road tile that are not road, at most WATER_BESIDE_ROAD may be water.
	var info: Array = s.get("path_info", [])
	var walk := {}
	var on_road := {}   # land and river road tiles (air roads mark none)
	for i in s["paths"].size():
		var kind: String = info[i].get("kind", "land") if i < info.size() else "land"
		var p: Array = s["paths"][i]
		for k in p.size() - 1:
			var q := Vector2i(p[k][0], p[k][1])
			var b := Vector2i(p[k + 1][0], p[k + 1][1])
			while true:
				if kind != "air":
					on_road[q] = true
				if kind == "land":
					walk[q] = true
				if q == b:
					break
				q += Vector2i(signi(b.x - q.x), signi(b.y - q.y))
	for v: Vector2i in walk:
		if v.x < 0 or v.y < 0 or v.x >= cols or v.y >= rows:
			continue
		var n := 0
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var o: Vector2i = v + Vector2i(dx, dy)
				if o != v and o.x >= 0 and o.y >= 0 and o.x < cols and o.y < rows and not on_road.has(o) and grid[o.y][o.x] in ["o", "w"]:
					n += 1
		if n > WATER_BESIDE_ROAD:
			print("  lair %d: road tile %s has %d water tiles beside it (at most %d, unless level_check allows it)" % [s["n"], v, n, WATER_BESIDE_ROAD])
	var out := {
		"id": "level_%02d" % s["n"], "title": s["title"], "cols": cols, "rows": rows, "hp_mul": s.get("hp_mul", 2.2),
		"legend": LEGEND,
		"terrain": grid.map(func(row: Array) -> String: return "".join(row)),
		"trees": trees,
		"paths": s["paths"],
		"lair": {"cell": lc, "size": [2, 2], "center": [lc[0] + 1, lc[1] + 1]},
		"sites": s.get("sites", []),
		"start": {"gold": 230, "mana": s.get("mana", 60), "gems": s.get("gems", 5)},
		"first_wave_delay": s.get("first", 30), "wave_gap": s.get("gap", 24),
		"site_cuts": s.get("site_cuts", 2),
		"waves": s["waves"],
	}
	if s.has("path_info"):
		out["path_info"] = s["path_info"]
	if s.has("rules"):
		out["rules"] = s["rules"]
	return out


## One key per line, short arrays on one line, so the files read like the hand-made ones.
func _pretty(d: Dictionary) -> String:
	var lines := ["{"]
	var keys := d.keys()
	for i in keys.size():
		var k: String = keys[i]
		var v = d[k]
		var tail := "," if i < keys.size() - 1 else ""
		if k in ["terrain", "trees", "paths", "waves", "sites", "path_info", "rules"]:
			lines.append(' "%s": [' % k)
			for j in v.size():
				lines.append("  %s%s" % [JSON.stringify(v[j]), "," if j < v.size() - 1 else ""])
			lines.append(" ]" + tail)
		else:
			lines.append(' "%s": %s%s' % [k, JSON.stringify(v), tail])
	lines.append("}")
	return "\n".join(lines) + "\n"

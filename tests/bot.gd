class_name Bot
extends RefCounted
## A simple player for headless tests: builds on every free tile next to a road, closest to the
## lair first, then upgrades (clearing rubble first); razes barracks, workshops and Signal Fires before
## spending mana on anything else; casts the
## Meteor whenever it can and picks up all loot. In the dark, when its lit spots are full and gold
## piles up, it builds a stepping-stone tower towards the dark ones. It plays much better than a person (it never
## hesitates), so a win only shows a level is winnable.

## The Dark Arts the bot plays with are the standard ones for each lair (scripts/data/loadout.gd).
const SKILL_ORDER := Loadout.SKILL_ORDER


static func points_before(index: int) -> int:
	return Loadout.points_before(index)


static func skills(points: int, beaten := 1000) -> Dictionary:
	return Loadout.skills(points, beaten)


## Plays the battle to the end (or 1200 s) and returns the finished sim. A non-zero seed changes
## the luck (loot, Dread, Lava) for the same battle. The style sets which tiles it builds on first:
## "near" closest to the lair, "far" earliest along a land road, "mid" halfway along one.
static func play(lv: Level, skill_ranks: Dictionary, seed := 0, style := "near") -> GameSim:
	var sim := GameSim.new(lv, skill_ranks)
	if OS.has_environment("BOT_TRACE"):   # print what the battle announces, for debugging a lair
		sim.toast.connect(func(t: String) -> void: print("%.1f w%d %s" % [sim.time, sim.wave, t]))
	if seed != 0:
		sim.rng.seed = hash(lv.id) + seed
	var spots: Array[Vector2i] = []
	for c in lv.cols:
		for r in lv.rows:
			var v := Vector2i(c, r)
			if lv.road.has(v) or lv.is_lair(v):
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if lv.road.has(v + d):
					spots.append(v)
					break
	if style == "near":
		spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_to(lv.lair_center) < Vector2(b).distance_to(lv.lair_center))
	else:
		# How far along a land road each spot lies, as a share of that road (the earliest road wins).
		var share := {}
		for v in spots:
			var best := INF
			for r: int in lv.land_roads:
				best = minf(best, lv.nearest_dist(r, Vector2(v) + Vector2(0.5, 0.5)) / float(lv.paths[r]["total"]))
			share[v] = best if style == "far" else absf(best - 0.5)
		spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return share[a] < share[b])
	var t := 0.0
	var dt := 0.05
	while not sim.over and t < 1200.0:
		# Take the first thing each tile offers (cut, build, upgrade); never sell.
		var uncut := sim.sites.values().any(func(s: GameSim.Site) -> bool: return not s.owned and Defs.HERO_SITES.has(s.kind))
		var grew := false   # built or upgraded something this pass
		for v in sim.sites.keys() + spots:
			var acts: Array = sim.cell_info(v)["actions"]
			for a: Dictionary in acts:
				if a["id"] == "clear" and uncut:
					break   # save mana to raze barracks first
				if a["id"] == "flood" and not _flood_worth(sim, sim.sites[v]):
					break   # open a sluice only on boats or a crowd in the water
				if a["id"].begins_with("master:"):
					# Take a mastery when offered, alternating A and B from tile to tile.
					var opts := acts.filter(func(x: Dictionary) -> bool: return x["id"].begins_with("master:"))
					if sim.do_action(opts[(v.x + v.y) % opts.size()]["id"], v) == "":
						grew = true
					break
				if a["id"] != "sell":
					if sim.do_action(a["id"], v) == "" and (a["id"].begins_with("build:") or a["id"] == "upgrade"):
						grew = true
					break
		if sim.dark and not grew and sim.gold >= 250:
			_step_into_dark(sim, spots)
		_collapse(sim)
		if sim.can_meteor() and not sim.enemies.is_empty():
			sim.cast_meteor(sim.enemies[0].pos)
		for l: GameSim.Loot in sim.loot.duplicate():
			sim.collect_loot(l.pos)
		sim.update(dt)
		t += dt
	return sim


## Which campaign lairs a test should play, from its command-line arguments: `--chapter N` for
## the ten lairs of chapter N, campaign numbers ("6 7 8"), or nothing for every lair. Returns
## [0-based indexes, whether the whole set (every lair or a chapter) was asked for].
static func pick_lairs(args: PackedStringArray, per_chapter := 10) -> Array:
	var count: int = load("res://scripts/main.gd").LEVELS.size()
	var picks: Array[int] = []
	var k := 0
	var whole := true
	while k < args.size():
		if args[k] == "--chapter" and k + 1 < args.size():
			var ch := int(args[k + 1])
			for i in range((ch - 1) * per_chapter, mini(ch * per_chapter, count)):
				picks.append(i)
			k += 2
			continue
		picks.append(int(args[k]) - 1)
		whole = false
		k += 1
	if picks.is_empty() and args.is_empty():
		picks.assign(range(count))
	return [picks, whole]


## In the dark, with gold to spare and nothing left to build or upgrade on its lit spots: build one
## stepping-stone tower on the buildable tile closest to the first spot (in the bot's order) that
## is still dark and free, so its light reaches further.
static func _step_into_dark(sim: GameSim, spots: Array[Vector2i]) -> void:
	var goal := Vector2i(-1, -1)
	for v in spots:
		if not sim.is_lit(v) and not sim.towers.has(v) and not sim.sites.has(v):
			goal = v
			break
	if goal.x < 0:
		return
	var best_id := ""
	var best_cell := Vector2i(-1, -1)
	var best_d := INF
	for c in sim.level.cols:
		for r in sim.level.rows:
			var v := Vector2i(c, r)
			var d := Vector2(v).distance_to(Vector2(goal))
			if d >= best_d:
				continue
			for a: Dictionary in sim.cell_info(v)["actions"]:
				if a["id"].begins_with("build:"):
					best_id = a["id"]
					best_cell = v
					best_d = d
					break
	if best_id != "":
		sim.do_action(best_id, best_cell)


## A sluice is worth opening when a boat or at least three heroes are in the water on its road.
static func _flood_worth(sim: GameSim, s: GameSim.Site) -> bool:
	var n := 0
	for e: GameSim.Enemy in sim.enemies:
		if e.path == s.path and sim.in_water(e):
			if e.d.has("boat"):
				return true
			n += 1
	return n >= 3


## Bring a bridge down while heroes are coming, unless Divers are about (they hide in the gap).
static func _collapse(sim: GameSim) -> void:
	if sim.enemies.is_empty() or sim.level.crossing_cells.is_empty():
		return
	for e: GameSim.Enemy in sim.enemies:
		if e.d.has("diver"):
			return
	for code: String in sim.queue:
		if Defs.ENEMIES[code].has("diver"):
			return
	for i in sim.level.crossing_cells.size():
		var c: Vector2i = sim.level.crossing_cells[i][0]
		if sim.level.crossing_kind[i] == "bridge" and not sim.collapsed.has(c) and sim.mana >= sim.collapse_cost(i):
			sim.do_action("collapse", c)


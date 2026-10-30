extends SceneTree
## Plays every campaign level headless with a simple build order and prints the result.
## Run: godot --headless --script res://tests/sim_test.gd

const MAIN := preload("res://scripts/main.gd")


func _init() -> void:
	var ok := true
	for path in MAIN.LEVELS:
		ok = _play(Level.load_from(path), {}) and ok
	# Later levels and night missions assume a player who has banked some skill points.
	var mid := {"moss_dmg": 3, "ash_dmg": 3, "ash_ability": 2, "frost_ability": 1}
	ok = _play(Level.load_from(MAIN.LEVELS[2]), mid) and ok
	# Levels 4 and 5 expect roughly the 14 stars a player has after levels 1-3 and a night mission or two.
	var late := {"moss_dmg": 3, "ash_dmg": 3, "ash_ability": 2, "frost_ability": 1, "den_charge": 2, "ash_rate": 2, "moss_rate": 1}
	for i in [3, 4]:
		ok = _play(Level.load_from(MAIN.LEVELS[i]), late) and ok
	for path in MAIN.LEVELS:
		var lv := Level.load_from(path)
		lv.night = true
		ok = _play(lv, mid) and ok
	quit(0 if ok else 1)


func _play(lv: Level, skills: Dictionary) -> bool:
	print("Loaded %s%s: %dx%d, %d roads, %d waves, %d trees, skills %s" % [lv.title, " (night)" if lv.night else "", lv.cols, lv.rows, lv.paths.size(), lv.waves.size(), lv.trees.size(), skills])
	var sim := GameSim.new(lv, skills)
	# Build order: every free tile next to a road, closest to the lair first, then upgrades.
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
	spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_to(lv.lair_center) < Vector2(b).distance_to(lv.lair_center))
	var t := 0.0
	var dt := 0.05
	var looted := 0
	while not sim.over and t < 1200.0:
		# Take the first thing each tile offers (cut, build, upgrade); never sell.
		var uncut := sim.sites.values().any(func(s: GameSim.Site) -> bool: return not s.owned)
		for v in sim.sites.keys() + spots:
			for a: Dictionary in sim.cell_info(v)["actions"]:
				if a["id"] == "clear" and uncut:
					break   # save mana for mines, wells and barracks first
				if a["id"] != "sell":
					sim.do_action(a["id"], v)
					break
		if sim.can_meteor() and not sim.enemies.is_empty():
			sim.cast_meteor(sim.enemies[0].pos)
		for l: GameSim.Loot in sim.loot.duplicate():
			if sim.collect_loot(l.pos):
				looted += 1
		sim.update(dt)
		t += dt
	var ranks := {}
	for tw: GameSim.Tower in sim.towers.values():
		ranks[tw.rank] = ranks.get(tw.rank, 0) + 1
	print("  Bot finished at %.0fs: over=%s won=%s wave=%d lost=%d towers=%d gold=%d rank=%s loot=%d tower ranks=%s" % [t, sim.over, sim.won, sim.wave, sim.lost, sim.towers.size(), sim.gold, sim.rank(), looted, ranks])
	# A battle with no defence at all should be lost.
	var idle := GameSim.new(lv)
	var t2 := 0.0
	while not idle.over and t2 < 1200.0:
		idle.call_early() if idle.wave < lv.waves.size() and idle.queue.is_empty() else null
		idle.update(dt)
		t2 += dt
	print("  Undefended: over=%s won=%s lost=%d at %.0fs" % [idle.over, idle.won, idle.lost, t2])
	return sim.over and idle.over and not idle.won

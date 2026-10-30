extends SceneTree
## Plays every campaign level headless with a simple build order and prints the result.
## Run: godot --headless --script res://tests/sim_test.gd
## Only some levels, by number:   godot --headless --script res://tests/sim_test.gd -- 6 7 8

const MAIN := preload("res://scripts/main.gd")

# Later levels and night missions assume a player who has banked some skill points.
const MID := {"moss_dmg": 3, "ash_dmg": 3, "ash_ability": 2, "frost_ability": 1}
# Levels 4 and 5 expect roughly the 14 stars a player has after levels 1-3 and a night mission or two.
const LATE := {"moss_dmg": 3, "ash_dmg": 3, "ash_ability": 2, "frost_ability": 1, "den_charge": 2, "ash_rate": 2, "moss_rate": 1}
# Levels 6 and up: about 21 stars, after levels 1-5 and a few night missions.
const LATER := {"moss_dmg": 3, "moss_rate": 2, "moss_range": 1, "frost_dmg": 2, "frost_ability": 1, "ash_dmg": 3,
	"ash_rate": 2, "ash_range": 1, "ash_ability": 2, "den_charge": 2, "hoard_gold": 2}


func _init() -> void:
	var only := OS.get_cmdline_user_args()
	if not only.is_empty():
		for n in only:
			var i := int(n) - 1
			_play(Level.load_from(MAIN.LEVELS[i]), {})
			_play(Level.load_from(MAIN.LEVELS[i]), _skills_for(i))
		quit(0)
		return
	var ok := true
	for path in MAIN.LEVELS:
		ok = _play(Level.load_from(path), {}) and ok
	ok = _play(Level.load_from(MAIN.LEVELS[2]), MID) and ok
	for i in range(3, MAIN.LEVELS.size()):
		ok = _play(Level.load_from(MAIN.LEVELS[i]), _skills_for(i)) and ok
	for path in MAIN.LEVELS:
		var lv := Level.load_from(path)
		lv.night = true
		ok = _play(lv, MID) and ok
	quit(0 if ok else 1)


func _skills_for(i: int) -> Dictionary:
	return LATER if i >= 5 else (LATE if i >= 3 else MID)


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

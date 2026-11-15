extends SceneTree
## Level format v2 and road zones, on tests/fixtures/level_v2.json: water and shallows, river roads,
## wave routes and cargo, hallowed ground, lair rules, six gems; fords, bridges, tide and paving
## slowing or speeding heroes; Soaked; Dark Arts tier gates; the test lair picker. Also checks
## that the campaign lairs read as before (every road land, every wave over every road).
## Run: godot --headless --script res://tests/level_v2_test.gd

const MAIN := preload("res://scripts/main.gd")
const FIXTURE := "res://tests/fixtures/level_v2.json"

var fails := 0


func _init() -> void:
	_loader()
	_routes()
	_zones()
	_old_levels()
	_skills()
	_picker()
	print("level_v2_test: %s" % ("all passed" if fails == 0 else "%d failed" % fails))
	quit(0 if fails == 0 else 1)


func _loader() -> void:
	var lv := Level.load_from(FIXTURE)
	_check(lv.terrain_at(Vector2i(5, 0)) == "water" and lv.terrain_at(Vector2i(5, 1)) == "shallows", "w and o read as water and shallows")
	_check(lv.is_water(Vector2i(5, 3)) and not lv.is_water(Vector2i(4, 3)), "is_water")
	_check(lv.path_kind == ["land", "land", "river"], "path kinds: %s" % [lv.path_kind])
	_check(lv.land_roads == [0, 1], "land roads: %s" % [lv.land_roads])
	_check(lv.gems == 6, "six gems")
	_check(lv.hallowed.has(Vector2i(2, 2)) and lv.hallowed.size() == 1, "hallowed ground")
	_check(lv.trees.has(Vector2i(0, 0)) and lv.trees.size() == 1, "woods still read")
	_check(lv.rules.size() == 1 and lv.rules[0]["kind"] == "tide", "lair rules")
	_check(lv.waves.size() == 3 and lv.waves[1].size() == 4 and lv.waves[2] == ["f", "f", "l"], "wave objects give their heroes")
	_check(lv.wave_roads[0].is_empty() and lv.wave_roads[1] == [1], "wave roads")
	_check(lv.wave_walk[0] == [0, 1] and lv.wave_walk[1] == [1] and lv.wave_walk[2] == [0], "walkers keep to land roads: %s" % [lv.wave_walk])
	_check(lv.wave_cargo[2].has("2") and lv.wave_cargo[2]["2"] == ["p"], "cargo")
	_check(lv.landing(2) > 0.0 and lv.zone_at(2, lv.landing(2)) == "", "river road has a landing")
	var sim := GameSim.new(lv)
	var info := sim.cell_info(Vector2i(5, 0))
	_check(info["title"] == "Deep water" and info["actions"].is_empty(), "nothing builds on deep water")
	_check(sim.cell_info(Vector2i(5, 2))["title"] == "Shallows", "shallows tile panel")
	_check(sim.preview_range(Vector2i(5, 2)) == 0.0, "no range preview on water")
	_check(sim.do_action("build:moss", Vector2i(5, 2)) != "", "building on water fails")


func _routes() -> void:
	var lv := Level.load_from(FIXTURE)
	var sim := GameSim.new(lv)
	sim.start_wave()
	for k in 2:
		sim.update(Defs.SPAWN_INTERVAL + 0.01)
	var first := sim.enemies.map(func(e: GameSim.Enemy) -> int: return e.path)
	first.sort()
	_check(first == [0, 1], "wave 1 is dealt over both land roads: %s" % [first])
	sim.enemies.clear()
	sim.call_early()
	for k in 4:
		sim.update(Defs.SPAWN_INTERVAL + 0.01)
	_check(sim.enemies.size() == 4 and sim.enemies.all(func(e: GameSim.Enemy) -> bool: return e.path == 1), "wave 2 keeps to road 1")
	sim.race_receive("p")
	_check(sim.enemies[-1].path in lv.land_roads, "a race hero walks a land road")


func _zones() -> void:
	var lv := Level.load_from(FIXTURE)
	var z0: Array = lv.zones[0]
	_check(z0.size() == 1 and z0[0]["kind"] == "ford", "road 0 has one ford: %s" % [z0])
	var z1: Array = lv.zones[1]
	_check(z1.size() == 1 and z1[0]["kind"] == "bridge", "road 1 has one bridge: %s" % [z1])
	var ford: float = (z0[0]["from"] + z0[0]["to"]) * 0.5
	var bridge: float = (z1[0]["from"] + z1[0]["to"]) * 0.5
	_check(lv.zone_at(0, ford) == "ford" and lv.zone_at(0, 1.0) == "", "zone_at")
	_check(absf(lv.path_pos(0, ford).x - 5.5) < 0.6, "the ford lies on the shallows")

	var sim := GameSim.new(lv)
	var e := _hero(sim, "p", 0, 1.0)
	_check(is_equal_approx(sim._zone_mul(e, 0.05), 1.0) and not sim.is_soaked(e), "dry road: normal speed")
	e.dist = ford
	_check(is_equal_approx(sim._zone_mul(e, 0.05), Defs.ZONE_SPEED["ford"]) and sim.is_soaked(e), "ford: slower and soaked")
	e.dist = 1.0
	sim._zone_mul(e, 1.0)
	_check(sim.is_soaked(e), "still soaked just after the ford")
	sim._zone_mul(e, Defs.SOAK_TIME)
	_check(not sim.is_soaked(e), "dry again after SOAK_TIME")
	sim.tide_up = true
	e.dist = ford
	_check(is_equal_approx(sim._zone_mul(e, 0.05), Defs.ZONE_SPEED["swim"]) and e.swim, "tide in: the ford is swum")
	sim.tide_up = false

	var b := _hero(sim, "p", 1, bridge)
	_check(is_equal_approx(sim._zone_mul(b, 0.05), 1.0) and not b.swim, "a standing bridge is normal road")
	sim.collapsed[Vector2i(5, 5)] = true
	_check(is_equal_approx(sim._zone_mul(b, 0.05), Defs.ZONE_SPEED["swim"]) and b.swim and sim.is_soaked(b), "a collapsed bridge is swum, soaked")
	# A Herald cannot haste a swimmer.
	var h := _hero(sim, "h", 1, bridge)
	sim.enemies = [b, h]
	var before := b.dist
	sim._update_enemies(0.1)
	_check(is_equal_approx(b.dist - before, float(Defs.ENEMIES["p"]["spd"]) * Defs.ZONE_SPEED["swim"] * 0.1), "no haste while swimming: moved %.4f" % (b.dist - before))
	sim.collapsed.clear()

	var p := _hero(sim, "p", 1, 1.0)
	sim.paved[1].append({"from": 0.5, "to": 2.0, "until": INF})
	_check(is_equal_approx(sim._zone_mul(p, 0.05), Defs.ZONE_SPEED["paved"]), "paved road is faster")
	sim.paved[1].clear()

	# Soaked heroes chill longer and heat slower.
	var tw := GameSim.Tower.new()
	tw.type = "ash"
	tw.pos = p.pos
	tw.beam = p
	p.soak = 1.0
	sim.enemies = [p]
	sim._update_beam(tw, 0.5)
	_check(is_equal_approx(tw.heat, 0.5 / Defs.HEAT_TIME * Defs.SOAK_HEAT), "a soaked hero heats slower: %.3f" % tw.heat)
	# Lava does not form on water.
	var pools := sim.pools.size()
	sim._lava(tw, Vector2(5.5, 3.5))
	_check(sim.pools.size() == pools, "no lava on water")
	sim._lava(tw, Vector2(3.5, 3.5))
	_check(sim.pools.size() == pools + 1, "lava on land")


func _hero(sim: GameSim, code: String, path: int, dist: float) -> GameSim.Enemy:
	var e := GameSim.Enemy.new()
	e.code = code
	e.d = Defs.ENEMIES[code]
	e.hp = 100.0
	e.max_hp = 100.0
	e.path = path
	e.dist = dist
	e.pos = sim.level.path_pos(path, dist)
	return e


func _old_levels() -> void:
	for path: String in MAIN.LEVELS.slice(0, 20):   # Chapters I and II: made before the water rules
		var lv := Level.load_from(path)
		var all: Array[int] = []
		all.assign(range(lv.paths.size()))
		_check(lv.path_kind.all(func(k: String) -> bool: return k == "land"), "%s: every road is land" % lv.id)
		_check(lv.land_roads == all, "%s: land roads are every road" % lv.id)
		_check(lv.wave_walk.all(func(w: Array) -> bool: return w == all), "%s: every wave uses every road" % lv.id)
		_check(lv.zones.all(func(z: Array) -> bool: return z.is_empty()), "%s: no water zones" % lv.id)
		_check(lv.hallowed.is_empty() and lv.rules.is_empty(), "%s: no hallowed ground or rules" % lv.id)


func _skills() -> void:
	_check(Defs.skill_points_all() == 133, "tiers I, II and III and The Land hold 133 points: %d" % Defs.skill_points_all())
	_check(Achievements.goal_of(Achievements.find("arts59")) == Defs.skill_points_all(), "Omniscient counts the real total")
	_check(Defs.skill_gate("moss_dmg") == 0, "tier I is open from the start")
	_check(Defs.TIER_BEATEN[2] == 20 and Defs.TIER_BEATEN[3] == 40 and Defs.TREE_BEATEN["land"] == 10, "tier gates: chapters III and V, The Land with II")
	_check(Defs.gate_chapter(20) == 3 and Defs.gate_chapter(40) == 5 and Defs.gate_chapter(10) == 2, "gate_chapter")
	var s := SaveData.new()
	s.best["level_01"] = {"rank": "Survived"}
	_check(s.can_buy("moss_dmg"), "a tier I skill can be bought with one star")
	s.unlocked = 21
	_check(s.lairs_beaten() == 20, "21 lairs open = 20 beaten, Chapter III reached")
	_check(Bot.skills(Bot.points_before(19), 19).values().reduce(func(a: int, b: int) -> int: return a + b, 0) == 46, "the bot spends 46 points before lair 20")
	_check(Bot.points_before(49) == 118, "points_before is not capped")


func _picker() -> void:
	var p: Array = Bot.pick_lairs(PackedStringArray(["--chapter", "2"]))
	_check(p[0] == range(10, 20) and p[1], "--chapter 2 picks lairs 11-20: %s" % [p])
	p = Bot.pick_lairs(PackedStringArray(["6", "7"]))
	_check(p[0] == [5, 6] and not p[1], "numbers pick single lairs")
	p = Bot.pick_lairs(PackedStringArray())
	_check(p[0].size() == MAIN.LEVELS.size() and p[1], "no arguments: every lair")


func _check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		printerr("FAIL: " + what)

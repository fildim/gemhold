extends SceneTree
## Chapter III rules on tests/fixtures/level_v2.json: boats land their crew or drown it, bridges
## collapse and Engineers rebuild them, Fenwalkers wade, Divers hide, rain keeps beams cool, the
## Tidecaller's surge, the Tide, Sluice Gates and Dark Altars.
## Run: godot --headless --script res://tests/water_test.gd

const FIXTURE := "res://tests/fixtures/level_v2.json"

var fails := 0


func _init() -> void:
	_boats()
	_bridges()
	_waders_divers()
	_rain_surge()
	_tide()
	_sites()
	print("water_test: %s" % ("all passed" if fails == 0 else "%d failed" % fails))
	quit(0 if fails == 0 else 1)


func _sim() -> GameSim:
	return GameSim.new(Level.load_from(FIXTURE))


func _hero(sim: GameSim, code: String, path: int, dist: float, w := 0) -> GameSim.Enemy:
	sim._spawn(code, path, dist, w)
	var e: GameSim.Enemy = sim.enemies[-1]
	return e


func _run(sim: GameSim, secs: float) -> void:
	var t := 0.0
	while t < secs and not sim.over:
		sim.update(0.05)
		t += 0.05


func _boats() -> void:
	# Wave 3 sends a Longboat down the river with one Peasant aboard.
	var sim := _sim()
	sim.wave = 2
	sim.timer = 0.0
	sim.update(0.05)
	var boats: Array = []
	for i in 200:
		sim.update(0.05)
		boats = sim.enemies.filter(func(e: GameSim.Enemy) -> bool: return e.code == "l")
		if not boats.is_empty():
			break
	_check(boats.size() == 1 and boats[0].path == 2, "the boat sails the river road")
	_check(boats.size() == 1 and boats[0].crew == ["p"], "its crew comes from the wave's cargo")
	var left_before: int = sim.wave_left[3]
	for i in 400:
		sim.update(0.05)
		if sim.boats_landed > 0:
			break
	sim.update(0.05)
	_check(sim.boats_landed == 1, "the boat lands: %d" % sim.boats_landed)
	_check(sim.enemies.any(func(e: GameSim.Enemy) -> bool: return e.code == "p" and e.path == 2), "its crew walks on from the landing")
	_check(sim.wave_left.get(3, 0) == left_before or sim.wave_left.get(3, 0) <= left_before, "the crew counts toward the wave")
	# Sunk on the water, the crew drowns and pays.
	var s2 := _sim()
	var b := _hero(s2, "l", 2, 0.5)
	b.crew = ["f", "f"]
	var gold := s2.gold
	s2.hurt(b, 99999.0, true)
	_check(s2.boats_sunk == 1 and s2.drowned == 2 and s2.kills == 3, "a sunk boat drowns its crew: kills %d" % s2.kills)
	_check(s2.gold == gold + 20 + 7 + 7, "bounties for boat and crew: %d" % (s2.gold - gold))
	# Beached, the crew steps off one by one; sunk halfway, the rest drown.
	var s4 := _sim()
	var land := float(s4.level.landings[2])
	var b4 := _hero(s4, "l", 2, land - 0.05)
	b4.crew = ["f", "f", "f", "f"]
	s4.update(0.1)
	_check(b4.crew.size() == 3 and s4.enemies.has(b4), "the first steps off, the boat waits: %d aboard" % b4.crew.size())
	_run(s4, Defs.LAND_GAP + 0.05)
	_check(b4.crew.size() == 2, "the next one follows: %d aboard" % b4.crew.size())
	var g4 := s4.gold
	s4.hurt(b4, 99999.0, true)
	_check(s4.drowned == 2 and s4.gold == g4 + 20 + 7 + 7, "the two still aboard drown and pay: %d" % (s4.gold - g4))
	_check(s4.boats_landed == 0, "a boat sunk while unloading has not landed")
	# Empty, it waits on the shore: a hero walking back rows away in it; sink it and they must go by land.
	var s5 := _sim()
	var land5 := float(s5.level.landings[2])
	var b5 := _hero(s5, "l", 2, land5 - 0.05)
	b5.crew = ["f"]
	_run(s5, 0.5)
	_check(b5.beached and s5.enemies.has(b5), "the empty boat stays on the shore")
	var c5 := _hero(s5, "f", 2, land5 + 0.2)
	c5.dir = -1
	c5.carry = 1
	var lost5 := s5.lost
	_run(s5, 1.0)
	_check(c5.gone and b5.dir == -1 and b5.carry == 1 and not b5.beached, "a hero with a gem boards and the boat rows away")
	var tt := 0.0
	while not b5.gone and b5.hp > 0.0 and tt < 60.0:
		b5.hp = b5.max_hp   # no tower may sink it here
		s5.update(0.05)
		tt += 0.05
	_check(b5.gone and s5.lost >= lost5 + 1, "the boat escapes with the gem")
	s5 = _sim()
	b5 = _hero(s5, "l", 2, land5 - 0.05)
	b5.crew = ["f"]
	_run(s5, 0.5)
	s5.hurt(b5, 99999.0, true)
	s5.update(0.05)
	var c6 := _hero(s5, "f", 2, land5 + 0.5)
	c6.dir = -1
	c6.carry = 1
	var d6 := c6.dist
	s5.update(0.2)
	_check(c6.dist > d6, "with the boat sunk he turns back toward the cave")
	c6.dist = float(s5.level.paths[2]["total"]) - 0.01
	s5.update(0.2)
	_check(s5.level.path_kind[c6.path] == "land" and c6.dir == -1, "and leaves by a land road")
	# Boats shrug off chill.
	var s3 := _sim()
	var b3 := _hero(s3, "l", 2, 0.5)
	var tw := GameSim.Tower.new()
	tw.type = "frost"
	tw.pos = b3.pos
	var shot := s3._make_shot(tw, b3)
	shot.pos = b3.pos
	s3.shots.append(shot)
	s3._update_shots(0.05)
	_check(b3.slow <= 0.0, "chill does not work on a boat")


func _bridges() -> void:
	var sim := _sim()
	var lv := sim.level
	var cell := Vector2i(5, 5)
	_check(lv.crossings.has(cell) and lv.crossing_kind[lv.crossings[cell]] == "bridge", "road 1 crosses deep water on a bridge")
	_check(lv.crossings.has(Vector2i(5, 1)) and lv.crossing_kind[lv.crossings[Vector2i(5, 1)]] == "ford", "road 0 crosses shallows at a ford")
	var info := sim.cell_info(cell)
	_check(info["title"] == "Bridge" and info["actions"][0]["id"] == "collapse", "a bridge can be collapsed from its panel")
	sim.mana = 100
	_check(sim.do_action("collapse", cell) == "" and sim.collapsed.has(cell), "collapsing it")
	_check(sim.mana == 85, "it cost 15 mana")
	_check(sim.cell_info(cell)["title"] == "Broken bridge", "now it shows broken")
	# An Engineer walks up, stands at the bank, and rebuilds it.
	var z: Dictionary = lv.zones[1][0]
	var eng := _hero(sim, "e", 1, z["from"] - 0.6)
	_run(sim, 2.0)
	_check(eng.work > 0.0 and eng.dist < z["from"], "the Engineer stops at the bank to work")
	_run(sim, 4.0)
	_check(not sim.collapsed.has(cell), "and rebuilds the bridge")
	sim.mana = 100
	sim.do_action("collapse", cell)
	_check(sim.mana == 85, "a second collapse costs the same 15: %d left" % sim.mana)


func _waders_divers() -> void:
	var sim := _sim()
	var z: Dictionary = sim.level.zones[0][0]
	var ford: float = (z["from"] + z["to"]) * 0.5
	var fen := _hero(sim, "m", 0, ford)
	_check(is_equal_approx(sim._zone_mul(fen, 0.05), 1.0) and not sim.is_soaked(fen), "a Fenwalker wades through the ford")
	var dv := _hero(sim, "d", 0, ford)
	sim._zone_mul(dv, 0.05)
	_check(dv.hidden, "a Diver in the ford is hidden")
	var tw := GameSim.Tower.new()
	tw.type = "moss"
	tw.pos = dv.pos
	sim.enemies = [dv]
	_check(sim._pick_target(tw) == null, "towers can't see him")
	dv.dist = 1.0
	sim._zone_mul(dv, 0.05)
	_check(not dv.hidden and sim._pick_target(tw) == dv, "out of the water he is seen")
	# Planks laid by an Engineer leaving the ford keep it dry.
	var eng := _hero(sim, "e", 0, ford)
	sim._zone_mul(eng, 0.05)
	eng.dist = z["to"] + 0.2
	eng.pos = sim.level.path_pos(0, eng.dist)
	sim._zone_mul(eng, 0.05)
	_check(sim.planks.size() == 1, "an Engineer lays planks over the ford he crossed")
	var p := _hero(sim, "p", 0, ford)
	_check(is_equal_approx(sim._zone_mul(p, 0.05), 1.0) and not sim.is_soaked(p), "planks: no slow, no soak")


func _rain_surge() -> void:
	var sim := _sim()
	var q := _hero(sim, "q", 1, 2.0)
	var k := _hero(sim, "k", 1, 2.1)
	sim._update_enemies(0.0)
	var tw := GameSim.Tower.new()
	tw.type = "ash"
	tw.pos = k.pos
	tw.beam = k
	tw.heat = 0.9
	sim._update_beam(tw, 0.1)
	_check(tw.heat <= Defs.RAIN_HEAT + 0.001, "under the rain a beam stays cool: %.2f" % tw.heat)
	var pl := GameSim.Pool.new()
	pl.pos = q.pos
	pl.dur = 3.0
	sim.pools.append(pl)
	sim._update_pools(0.05)
	_check(sim.pools.is_empty(), "rain puts out Lava")
	var t := _hero(sim, "T", 1, 1.0)
	var near := _hero(sim, "f", 1, 1.5)
	near.slow = 2.0
	t.surge_t = 0.01
	sim._update_enemies(0.05)
	_check(near.slow <= 0.0 and near.wade > 0.0, "the Tidecaller's surge clears chill and lets heroes wade")


func _tide() -> void:
	var sim := _sim()
	_check(sim.tide == Vector2(40, 14), "the fixture has a tide")
	_run(sim, 1.0)
	_check(not sim.tide_up, "low tide at first")
	sim.time = 30.0
	sim.update(0.05)
	_check(sim.tide_up, "high tide 26 s into each 40 s")
	var z: Dictionary = sim.level.zones[0][0]
	var p := _hero(sim, "p", 0, (z["from"] + z["to"]) * 0.5)
	_check(is_equal_approx(sim._zone_mul(p, 0.05), Defs.ZONE_SPEED["swim"]), "fords are swum at high tide")


func _sites() -> void:
	var sim := _sim()
	var sl: GameSim.Site = sim.sites[Vector2i(4, 2)]
	_check(sl.owned and sim.cell_info(sl.cell)["actions"][0]["id"] == "flood", "the sluice is yours and ready")
	var z: Dictionary = sim.level.zones[0][0]
	var p := _hero(sim, "f", 0, (z["from"] + z["to"]) * 0.5)
	sim._zone_mul(p, 0.05)
	var hp := p.hp
	var d0 := p.dist
	sim.mana = 100
	_check(sim.do_action("flood", sl.cell) == "", "opening the sluice")
	_check(p.hp <= hp - 120.0 + 0.01 or p.hp <= 0.0, "the surge hurts heroes in the water through armour")
	_check(p.hp <= 0.0 or p.dist < d0, "and sweeps them back")
	_check(sim.do_action("flood", sl.cell) != "", "it must refill first")
	var al: GameSim.Site = sim.sites[Vector2i(6, 2)]
	sim.gold = 500
	sim.do_action("build:moss", Vector2i(6, 3))
	var tw: GameSim.Tower = sim.towers[Vector2i(6, 3)]
	var plain := tw.stat("dmg")
	sim.mana = 100
	sim.do_action("cut", al.cell)
	_check(al.owned and is_equal_approx(tw.stat("dmg"), plain * 1.1), "a freed altar: +10%% damage (%.2f -> %.2f)" % [plain, tw.stat("dmg")])


func _check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		printerr("FAIL: " + what)

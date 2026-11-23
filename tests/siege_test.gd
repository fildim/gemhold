extends SceneTree
## Chapter IV rules on tests/fixtures/level_siege.json: Sappers stun towers (not on raised tiles) and
## their kegs, Paviors pave, Inquisitors silence, Trebuchets bury towers under Rubble and retreat,
## the Iron Belfry's cover, Sappers, unloading and spill, Sturdy Foundations, the Signal Fire, the
## Siege Workshop and Dusk, and the support heroes (Herald, Cleric, Shieldbearer, Warden) not
## reaching siege engines or flyers.
## Run: godot --headless --script res://tests/siege_test.gd

const FIXTURE := "res://tests/fixtures/level_siege.json"

var fails := 0


func _init() -> void:
	_sapper()
	_pavior()
	_inquisitor()
	_trebuchet()
	_belfry()
	_sites_and_dusk()
	_aloof()
	print("siege_test: %s" % ("all passed" if fails == 0 else "%d failed" % fails))
	quit(0 if fails == 0 else 1)


func _sim(skills := {}) -> GameSim:
	var sim := GameSim.new(Level.load_from(FIXTURE), skills)
	sim.gold = 5000
	sim.mana = 100.0
	return sim


func _hero(sim: GameSim, code: String, dist: float, w := 0) -> GameSim.Enemy:
	sim._spawn(code, 0, dist, w)
	return sim.enemies[-1]


func _build(sim: GameSim, c: Vector2i, type := "moss") -> GameSim.Tower:
	var err := sim.do_action("build:" + type, c)
	_check(err == "", "build at %s: %s" % [c, err])
	return sim.towers.get(c)


func _run(sim: GameSim, secs: float, until := Callable()) -> void:
	var t := 0.0
	while t < secs and not sim.over:
		sim.update(0.05)
		t += 0.05
		if until.is_valid() and until.call():
			return


func _sapper() -> void:
	var sim := _sim()
	var high := _build(sim, Vector2i(6, 2))     # raised: out of his reach
	var low := _build(sim, Vector2i(8, 2))
	var sp := _hero(sim, "a", 4.0)
	sp.hp = 99999.0
	sp.max_hp = 99999.0
	_run(sim, 12.0, func() -> bool: return low.stun > 0.0)
	_check(low.stun > 0.0, "a Sapper stuns a tower beside the road")
	_check(high.stun <= 0.0, "a tower on a raised tile is out of his reach")
	_check(not sim.enemies.has(sp) and sim.kills == 0, "he dies in his own blast, unslain")
	_check(sim.stuns == 1, "the stun is counted")
	# A stunned tower does not fire.
	var shots := sim.shots.size()
	_hero(sim, "p", 7.5)
	sim._update_towers(0.05)
	_check(sim.shots.size() == shots, "a stunned tower holds its fire")
	# Sturdy Foundations shortens the stun.
	var s2 := _sim({"sturdy": 3})
	var t2 := _build(s2, Vector2i(8, 2))
	var sp2 := _hero(s2, "a", 4.0)
	sp2.hp = 99999.0
	_run(s2, 12.0, func() -> bool: return t2.stun > 0.0)
	_check(absf(t2.stun - Defs.STUN_TIME * (1.0 - 3 * Defs.STURDY)) < 0.1, "Sturdy Foundations: stun %.2f" % t2.stun)
	# Slain with the fuse lit, the keg hurts the heroes around him.
	var s3 := _sim()
	_build(s3, Vector2i(9, 2), "frost")
	var sp3 := _hero(s3, "a", 4.0)
	sp3.hp = 99999.0
	_run(s3, 12.0, func() -> bool: return sp3.fuse >= 0.0)
	_check(sp3.fuse >= 0.0, "the fuse is lit")
	var p := _hero(s3, "p", 0.0)
	p.pos = sp3.pos + Vector2(0.3, 0.0)
	var hp := p.hp
	s3.hurt(sp3, 999999.0, true)
	_check(p.hp < hp, "the keg hurts a hero beside him")
	s3.update(0.05)
	_check(sp3.sap == null and s3.towers[Vector2i(9, 2)].sapped == null, "his tower is let go")


func _pavior() -> void:
	var sim := _sim()
	var v := _hero(sim, "v", 0.0)
	v.hp = 99999.0
	_run(sim, 6.0)
	var paved: Array = sim.paved[0]
	_check(paved.size() == 1 and float(paved[0]["to"]) > 3.0, "the road behind him is paved")
	var p := _hero(sim, "p", 1.0)
	var speed := sim._zone_mul(p, 0.0)
	_check(is_equal_approx(speed, Defs.ZONE_SPEED["paved"]), "heroes walk faster on paving: %.2f" % speed)
	sim.hurt(v, 999999.0, true)
	sim.update(0.05)
	_check(float(paved[0]["until"]) < INF, "the paving starts to fade when he falls")
	_run(sim, Defs.PAVE_FADE + 1.0)
	_check(sim.paved[0].is_empty(), "and it is gone %d s later" % int(Defs.PAVE_FADE))


func _inquisitor() -> void:
	var sim := _sim()
	var tw := _build(sim, Vector2i(9, 2), "frost")
	tw.rank = 3
	tw.lvl = 3
	var base_rate := tw.stat("rate")
	var base_dmg := tw.stat("dmg")
	_check(tw.has_ability(), "a hardened level III tower has its ability")
	var i := _hero(sim, "i", 9.0)
	i.hp = 99999.0
	sim._update_towers(0.01)
	_check(tw.silence > 0.0 and not tw.has_ability(), "his censer silences it: no ability")
	_check(tw.stat("rate") > base_rate and tw.stat("dmg") < base_dmg, "slower, and no battle-hardened bonus")
	sim.hurt(i, 999999.0, true, tw)
	_check(sim.silence_proof == 1, "slain by a tower he was silencing")
	sim.update(0.05)
	sim._update_towers(0.01)
	_check(tw.silence == 0.0 and tw.has_ability(), "the silence lifts when he falls")


func _trebuchet() -> void:
	var sim := _sim()
	var near := _build(sim, Vector2i(8, 2))
	sim.do_action("upgrade", Vector2i(8, 2))
	var cheap := _build(sim, Vector2i(10, 4))
	var u := _hero(sim, "u", 0.0)
	u.hp = 999999.0
	u.max_hp = u.hp
	_run(sim, 60.0, func() -> bool: return u.deployed)
	_check(u.deployed and u.pos.distance_to(near.pos) <= Defs.TREBUCHET["reach"] + 0.1, "it stops once a tower is in reach")
	_run(sim, 6.0, func() -> bool: return near.rubble > 0.0 or cheap.rubble > 0.0)
	_check(near.rubble > 0.0 and cheap.rubble <= 0.0, "it buries the strongest tower first")
	var gold := sim.gold
	_check(sim.do_action("rubble", near.cell) == "" and near.rubble == 0.0 and sim.gold == gold - sim.rubble_price(), "rubble can be cleared for gold")
	# Each tower is hit once: the next stone goes to the other one, rubble stays until paid for,
	# and with nothing left to hit in reach it rolls on.
	var held := u.dist
	_run(sim, 6.0, func() -> bool: return not u.deployed)
	_check(not u.deployed and near.rubble == 0.0, "with every tower in reach hit, it rolls on (and never hits one twice)")
	_run(sim, 60.0, func() -> bool: return cheap.rubble > 0.0)
	_check(cheap.rubble > 0.0 and u.dist > held, "further on, it stops again for a tower not hit yet")
	_run(sim, 30.0)
	_check(cheap.rubble > 0.0, "rubble stays until it is cleared")
	_check(near.rubble == 0.0, "it never hits the same tower twice")
	# A second Trebuchet has its own list: it may bury the tower the first one hit.
	var u3 := _hero(sim, "u", 0.0)
	u3.hp = 999999.0
	u3.max_hp = u3.hp
	_run(sim, 60.0, func() -> bool: return near.rubble > 0.0)
	_check(near.rubble > 0.0 and not u.deployed, "another Trebuchet may hit it again")
	# Once the last wave is out and only engines are left, it rolls away, and the lair is won.
	sim.wave = sim.level.waves.size()
	sim.queue.clear()
	for e: GameSim.Enemy in sim.enemies.duplicate():
		if e != u:
			sim.enemies.erase(e)
	_run(sim, 200.0)
	_check(u.retreat, "it retreats")
	_check(sim.over and sim.won and sim.lost == 0, "the battle ends won when it is gone")
	# Destroyed before its first stone.
	var s2 := _sim()
	var u2 := _hero(s2, "u", 1.0)
	s2.hurt(u2, 999999.0, true, null, 0, true)   # the Meteor
	_check(s2.treb_fast == 1, "a Trebuchet destroyed before its first stone is counted")
	# Only fire hurts it: a Cinder Shrine and the Meteor, not a Hut, a Crypt, the den or a keg.
	var s4 := _sim()
	var u4 := _hero(s4, "u", 1.0)
	var hut := _build(s4, Vector2i(2, 2))
	var hp := u4.hp
	s4.hurt(u4, 500.0, true)
	s4.hurt(u4, 500.0, false, hut)
	_check(u4.hp == hp, "arrows, bolts and kegs don't hurt a Trebuchet")
	u4.pos = hut.pos
	_check(s4._pick_target(hut) != u4, "a Hut doesn't aim at it")
	var shrine: GameSim.Tower = null
	for y in 12:
		for x in 16:
			if shrine == null and s4.cell_info(Vector2i(x, y))["actions"].any(func(a: Dictionary) -> bool: return a["id"] == "build:ash"):
				shrine = _build(s4, Vector2i(x, y), "ash")
	u4.pos = shrine.pos
	_check(s4._pick_target(shrine) == u4, "a Cinder Shrine aims at it")
	s4.hurt(u4, 100.0, true, shrine)
	_check(u4.hp == hp - 100.0, "a Cinder Shrine burns it")
	# A Meteor smashes it outright, however tough it has grown.
	u4.hp = 99999.0
	u4.max_hp = u4.hp
	s4.mana = 100
	s4.update(0.05)   # back on its road (the checks above moved it by hand)
	s4.cast_meteor(u4.pos)
	_run(s4, 2.0)
	_check(u4.hp <= 0.0, "a Meteor smashes it at once")


func _belfry() -> void:
	var sim := _sim()
	var tw := _build(sim, Vector2i(5, 4))
	var b := _hero(sim, "I", 5.0, 1)
	b.hp = 9999999.0
	var p := _hero(sim, "p", 4.2, 1)
	sim.wave_left[1] = 2
	sim.update(0.01)
	_check(p.covered, "a hero just behind the Belfry is covered")
	_check(sim._pick_target(tw) == b, "towers can't pick him; the Belfry itself they can")
	_run(sim, Defs.BELFRY["sapper"] + 0.5)
	_check(sim.enemies.any(func(e: GameSim.Enemy) -> bool: return e.code == "a"), "a Sapper jumps out")
	# At the den it unloads its Footmen and rolls away.
	var s2 := _sim()
	var b2 := _hero(s2, "I", float(s2.level.paths[0]["total"]) - 0.2, 1)
	b2.hp = 9999999.0
	s2.wave_left[1] = 1
	_run(s2, 1.0, func() -> bool: return b2.unloaded)
	s2.update(0.05)
	var feet := s2.enemies.filter(func(e: GameSim.Enemy) -> bool: return e.code == "f").size()
	_check(b2.unloaded and b2.retreat and feet == 6, "it unloads six Footmen at the den: %d" % feet)
	_check(s2.home == s2.level.gems, "it takes no gems")
	# Broken open early, its garrison spills out.
	var s3 := _sim()
	var b3 := _hero(s3, "I", 3.0, 1)
	s3.wave_left[1] = 1
	s3.hurt(b3, 99999999.0, true)
	s3.update(0.05)
	var spilt := s3.enemies.map(func(e: GameSim.Enemy) -> String: return e.code)
	_check(spilt.count("f") == 4 and spilt.count("k") == 2 and spilt.count("i") == 1, "it spills 4 Footmen, 2 Knights and an Inquisitor: %s" % [spilt])


func _sites_and_dusk() -> void:
	var sim := _sim()
	_check(sim.beacon_lit(), "the Signal Fire burns")
	sim.start_wave()
	_check(is_equal_approx(sim.timer, sim.level.wave_gap - Defs.SITES["beacon"]["sooner"]), "waves come sooner while it burns")
	var beacon := Vector2i(2, 6)
	var gold := sim.gold
	_check(sim.do_action("cut", beacon) == "" and sim.sites[beacon].owned, "it can be razed")
	_check(sim.gold == gold + int(Defs.SITES["beacon"]["bounty"]), "for its bounty")
	_check(not sim.beacon_lit(), "and then it is out")
	# The workshop musters Trebuchets while waves are coming.
	var ws: GameSim.Site = sim.sites[Vector2i(4, 6)]
	ws.t = 0.01
	sim._update_sites(0.05)
	_check(sim.enemies.any(func(e: GameSim.Enemy) -> bool: return e.code == "u") and sim.engines_built == 1, "the Siege Workshop rolls out a Trebuchet")
	# Dusk: night falls as wave 2 starts, and only lit tiles can be built on after.
	_check(not sim.dark and sim.is_lit(Vector2i(0, 0)), "day at first")
	sim.start_wave()
	_check(sim.dark and not sim.is_lit(Vector2i(0, 0)), "night falls at wave 2")
	_check(sim.is_lit(Vector2i(13, 2)), "the den lights the ground around it")
	var lv := Level.load_from(FIXTURE)
	lv.night = true
	var night := GameSim.new(lv)
	_check(night.dark and night.dusk_wave == 0, "the night mission is dark from the start")


## A Trebuchet (steady), a Skylancer (in the air) and a Peasant stand by a support hero: only the
## Peasant gets the help.
func _aloof() -> void:
	# Herald: the Peasant marches faster than without him; the engine and the flyer do not.
	var plain := _sim()
	var hasted := _sim()
	var before := {}
	var after := {}
	for s: GameSim in [plain, hasted]:
		if s == hasted:
			_hero(s, "h", 3.0).hp = 99999.0
		for code: String in ["u", "y", "p"]:
			_hero(s, code, 3.0)
		s._update_enemies(0.2)
	for e: GameSim.Enemy in plain.enemies:
		before[e.code] = e.dist
	for e: GameSim.Enemy in hasted.enemies:
		after[e.code] = e.dist
	_check(after["p"] > before["p"] + 0.01, "a Herald hastes a Peasant")
	_check(is_equal_approx(after["u"], before["u"]), "but not a Trebuchet")
	_check(is_equal_approx(after["y"], before["y"]), "nor a flyer")
	# Cleric: heals the Peasant only.
	var sim := _sim()
	_hero(sim, "c", 3.0).hp = 99999.0
	var hurt := {}
	for code: String in ["u", "y", "p"]:
		var e := _hero(sim, code, 3.0)
		e.hp = e.max_hp * 0.5
		hurt[code] = e
	sim._update_enemies(0.2)
	_check(hurt["p"].hp > hurt["p"].max_hp * 0.5, "a Cleric heals a Peasant")
	_check(is_equal_approx(hurt["u"].hp, hurt["u"].max_hp * 0.5), "but not a Trebuchet")
	_check(is_equal_approx(hurt["y"].hp, hurt["y"].max_hp * 0.5), "nor a flyer")
	# Shieldbearer: guards the Peasant only.
	var s2 := _sim()
	_hero(s2, "b", 3.0)
	var u := _hero(s2, "u", 3.0)
	var y := _hero(s2, "y", 3.0)
	var p := _hero(s2, "p", 3.0)
	_check(s2._guard(p) > 0.0, "a Shieldbearer guards a Peasant")
	_check(s2._guard(u) == 0.0, "but not a Trebuchet")
	_check(s2._guard(y) == 0.0, "nor a flyer")
	# Warden: clears the Peasant's slow and Dread only.
	var s3 := _sim()
	_hero(s3, "w", 3.0).hp = 99999.0
	var chilled := {}
	for code: String in ["u", "y", "p"]:
		var e := _hero(s3, code, 3.0)
		e.slow = 5.0
		e.fear = 5.0
		chilled[code] = e
	s3._update_enemies(0.05)
	_check(chilled["p"].slow == 0.0 and chilled["p"].fear == 0.0, "a Warden clears a Peasant's slow and Dread")
	_check(chilled["u"].slow > 0.0 and chilled["u"].fear > 0.0, "but not a Trebuchet's")
	_check(chilled["y"].slow > 0.0 and chilled["y"].fear > 0.0, "nor a flyer's")
	# The Seraph, once come down onto a road, is no longer aloof.
	var s4 := _sim()
	var sr := _hero(s4, "S", 3.0)
	_check(s4.aloof(sr), "the Seraph in the air is aloof")
	sr.grounded = true
	_check(not s4.aloof(sr), "and not once she has come down")


func _check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		printerr("FAIL: " + what)

extends SceneTree
## Chapter V rules on tests/fixtures/level_radiant.json: flyers on air roads (no road tiles, half
## chill, over Lava, gems falling to the nearest road), the Justicar's shield, the Spiriter's chant,
## the Seraph's landings, the Chapel and hallowed ground, the Eclipse, seven gems and tier III skills.
## Run: godot --headless --script res://tests/radiant_test.gd

const FIXTURE := "res://tests/fixtures/level_radiant.json"

var fails := 0


func _init() -> void:
	_flyers()
	_justicar()
	_spiriter()
	_seraph()
	_chapel()
	_eclipse()
	_tier3()
	print("radiant_test: %s" % ("all passed" if fails == 0 else "%d failed" % fails))
	quit(0 if fails == 0 else 1)


func _sim(skills := {}) -> GameSim:
	var sim := GameSim.new(Level.load_from(FIXTURE), skills)
	sim.gold = 5000
	sim.mana = 100.0
	return sim


func _hero(sim: GameSim, code: String, path: int, dist: float, w := 0) -> GameSim.Enemy:
	sim._spawn(code, path, dist, w)
	return sim.enemies[-1]


func _flyers() -> void:
	var sim := _sim()
	var lv := sim.level
	_check(lv.path_kind[1] == "air" and not lv.road.has(Vector2i(5, 7)), "an air road blocks no building")
	_check(lv.gems == 7 and sim.home == 7, "seven gems")
	# Wave 2 sends a Skylancer: he takes the air road.
	sim.wave = 1
	sim.timer = 0.0
	sim.update(0.05)
	sim.update(0.05)
	var y: Array = sim.enemies.filter(func(e: GameSim.Enemy) -> bool: return e.code == "y")
	_check(y.size() == 1 and y[0].path == 1 and sim.flying(y[0]), "a Skylancer flies the air road")
	# Half chill, and Lava does not reach him.
	var e: GameSim.Enemy = _hero(sim, "y", 1, 4.0)
	var tw := GameSim.Tower.new()
	tw.type = "frost"
	tw.pos = e.pos
	var s := sim._make_shot(tw, e)
	sim._strike(s, e, 1.0)
	_check(is_equal_approx(e.slow_amt, s.slow * Defs.FLY_CHILL), "chill holds a flyer half as well: %.2f" % e.slow_amt)
	var pl := GameSim.Pool.new()
	pl.pos = e.pos
	pl.r = 1.0
	pl.dps = 1000.0
	pl.dur = 3.0
	sim.pools.append(pl)
	var hp := e.hp
	sim._update_pools(0.1)
	_check(e.hp == hp, "Lava does not burn a flyer")
	sim.pools.clear()
	# Slain with a gem, it falls to the nearest land road.
	e.carry = 1
	sim.hurt(e, 1e9, true)
	_check(sim.drops.size() == 1 and sim.drops[0].path == 0, "his gem falls to a land road")


func _justicar() -> void:
	var sim := _sim()
	var j := _hero(sim, "j", 0, 3.0)
	sim.hurt(j, j.max_hp * 0.7, true)
	_check(j.shielded and j.untouch > 0.0 and is_equal_approx(j.hp, j.max_hp * Defs.JUSTICAR["heal"]), "his shield: untouchable and healed")
	_check(sim.shield_waste == 1, "spent where no tower reaches him")
	var hp := j.hp
	sim.hurt(j, 99999.0, true)
	_check(j.hp == hp, "untouchable while it lasts")
	j.untouch = 0.0
	sim.hurt(j, j.max_hp * 0.5, true)
	_check(j.hp < j.max_hp * 0.35 and j.untouch <= 0.0, "only once")
	var tw := GameSim.Tower.new()
	tw.type = "frost"
	tw.lvl = 3
	tw.rank = 3
	tw.ability_rank = 30
	var s := sim._make_shot(tw, j)
	s.fear = 1.0
	sim._strike(s, j, 0.0)
	_check(j.fear <= 0.0, "Dread does not touch him")


func _spiriter() -> void:
	var sim := _sim()
	var total: float = sim.level.paths[0]["total"]
	var n := _hero(sim, "n", 0, total - 0.05)
	sim.update(0.05)
	_check(n.carry == 1 and n.chant > 0.0, "he takes a gem and chants")
	for i in int(Defs.CHANT_TIME / 0.05) + 4:
		sim.update(0.05)
	_check(not sim.enemies.has(n) and sim.lost == 1 and sim.chants_done == 1, "and vanishes with it")
	# Dread breaks the chant.
	var s2 := _sim()
	var n2 := _hero(s2, "n", 0, total - 0.05)
	s2.update(0.05)
	n2.fear = 1.0
	s2.update(0.05)
	_check(n2.chant == 0.0 and s2.chants_broken == 1, "Dread breaks the chant")


func _seraph() -> void:
	var sim := _sim()
	for code in ["p", "p", "f", "k", "c", "b", "w", "h"]:
		var o := _hero(sim, code, 0, 1.0)
		sim.hurt(o, 1e9, true)
	sim.update(0.05)
	var sr := _hero(sim, "S", 1, 5.0)
	sim.hurt(sr, sr.max_hp * 0.4, true)
	_check(sr.phase == 1 and sr.grounded and sim.level.path_kind[sr.path] == "land", "at 66% she lands on a road")
	sim.update(0.05)
	var raised: Array = sim.enemies.filter(func(e: GameSim.Enemy) -> bool: return e != sr)
	_check(raised.size() == 6, "and raises the last six slain: %d" % raised.size())
	_check(raised.all(func(e: GameSim.Enemy) -> bool: return e.hp <= e.max_hp * 0.6), "at about half health (the Chapel nearby heals a little)")
	_check(sr.untouch > 0.0, "untouchable a moment")
	sr.untouch = 0.0
	sim.hurt(sr, 1e9, true)
	_check(sim.seraph_phase == 1, "slain before her second rising")


func _chapel() -> void:
	var sim := _sim()
	var c := Vector2i(5, 2)
	_check(sim.hallow_on(), "hallowed while the Chapel stands")
	sim.do_action("build", c)
	var tw: GameSim.Tower = sim.towers[c]
	sim._update_towers(0.01)
	_check(tw.holy and is_equal_approx(tw.stat("range"), float(Defs.TOWERS["moss"]["range"][0]) * Defs.HALLOW_RANGE), "a tower on it has less range")
	_check(sim.built_hallowed == 1, "built on hallowed ground is counted")
	var p := _hero(sim, "p", 0, 9.0)
	p.pos = Vector2(8.5, 5.0)
	p.hp = 1.0
	sim._update_sites(1.0)
	_check(p.hp > 1.0, "the Chapel heals heroes near it")
	sim.wave = 2
	_check(sim.do_action("cut", Vector2i(8, 5)) == "", "it can be razed")
	sim._update_towers(0.01)
	_check(not sim.hallow_on() and not tw.holy and sim.chapels_razed_wave == 2, "then the ground is no longer holy")


func _eclipse() -> void:
	var sim := _sim()
	_check(not sim.dark and sim.is_lit(Vector2i(0, 0)), "light at first")
	for i in int(13.0 / 0.05):
		sim.update(0.05)
	_check(sim.dark and not sim.is_lit(Vector2i(0, 0)), "the sun goes dark")
	for i in int(8.0 / 0.05):
		sim.update(0.05)
	_check(not sim.dark, "and the light returns")


func _tier3() -> void:
	var sim := GameSim.new(Level.load_from(FIXTURE), {"moss_legend": 5, "den_fury": 5, "dragon_patience": 3, "renown": 50})
	_check(is_equal_approx(sim.mana, sim.level.start_mana + 30.0), "Dragon's Patience: more starting mana")
	sim.do_action("build", Vector2i(3, 4))
	var tw: GameSim.Tower = sim.towers[Vector2i(3, 4)]
	_check(is_equal_approx(tw.dmg_mul, 1.25), "Legend: +25% damage")
	sim.won = true
	sim.gold = 300
	var plain := _sim()
	plain.won = true
	plain.gold = 300
	_check(sim.score(1) == roundi(plain.score(1) * 1.5) or absi(sim.score(1) - roundi(plain.score(1) * 1.5)) <= 1, "Renown: +50% score")
	_check(Defs.skill_gate("moss_legend") == 40, "tier III opens with Chapter V")


func _check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		printerr("FAIL: " + what)

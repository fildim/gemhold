extends SceneTree
## Checks the save file: unlocking, best ratings, round trips and damaged files.
## Uses its own file, so your real progress is untouched.
## Run: godot --headless --script res://tests/save_test.gd

const FILE := "user://save_test.json"

var fails := 0


func _init() -> void:
	DirAccess.remove_absolute(FILE)
	var s := SaveData.load_from(FILE)
	_check(s.unlocked == 1 and s.best.is_empty(), "fresh save has only level 1")
	_check(not s.is_unlocked(1), "level 2 starts locked")

	_check(not s.record(0, "level_01", "Plundered", 0, false), "a loss is not a best")
	_check(s.unlocked == 1, "a loss unlocks nothing")
	_check(s.record(0, "level_01", "Survived", 12, true), "first win is a best")
	_check(s.is_unlocked(1), "winning level 1 unlocks level 2")
	_check(s.record(0, "level_01", "Survived", 14, true), "more gems kept at the same rating is a best")
	_check(s.record(0, "level_01", "Brilliant", 20, true), "a higher rating is a best")
	_check(not s.record(0, "level_01", "Wicked", 18, true), "a lower rating is not a best")
	_check(s.best_rank("level_01") == "Brilliant" and s.stars("level_01") == 3, "best rating kept")
	_check(s.stars("level_02") == 0, "unplayed level has no stars")

	_check(s.save(), "save writes")
	var back := SaveData.load_from(FILE)
	_check(back.unlocked == 2 and back.best_rank("level_01") == "Brilliant" and int(back.best["level_01"]["kept"]) == 20, "save round trips")

	var f := FileAccess.open(FILE, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var broken := SaveData.load_from(FILE)
	_check(broken.unlocked == 1 and broken.best.is_empty(), "a damaged file starts fresh")

	# Stars are the skill points: 1 Survived, 2 Wicked, 3 Brilliant, best result per mission.
	var p := SaveData.load_from(FILE + ".none")
	_check(p.points_total() == 0 and p.points_free() == 0, "new player has no stars")
	_check(not p.buy("moss_dmg"), "can't buy without points")
	p.record(0, "level_01", "Plundered", 0, false)
	_check(p.points_total() == 0, "a loss gives no stars")
	p.record(0, "level_01", "Survived", 3, true)
	_check(p.points_total() == 1, "Survived gives 1 star")
	p.record(0, "level_01", "Wicked", 5, true)
	_check(p.points_total() == 2, "Wicked gives 2 stars, replacing the old best")
	p.record(0, "level_01", "Survived", 4, true)
	_check(p.points_total() == 2, "a worse replay keeps the best stars")
	p.record(0, "level_01", "Brilliant", 5, true)
	p.record(0, SaveData.mission_id("level_01", true), "Wicked", 5, true)
	p.record(1, "level_02", "Survived", 2, true)
	_check(p.points_total() == 6, "stars add up across missions, night included")
	_check(p.buy("moss_dmg") and p.buy("moss_dmg") and p.buy("moss_dmg"), "buy three ranks")
	_check(not p.buy("moss_dmg"), "can't go past a skill's max rank")
	_check(not p.buy("nonsense"), "unknown skills can't be bought")
	_check(p.points_free() == 3, "three points left")
	p.path = FILE
	p.save()
	var q := SaveData.load_from(FILE)
	_check(q.points_total() == 6 and q.skill_rank("moss_dmg") == 3, "stars and skills round trip")
	q.reset_skills()
	_check(q.points_spent() == 0 and q.points_free() == 6, "refund returns every point")
	var g := FileAccess.open(FILE, FileAccess.WRITE)
	g.store_string('{"unlocked": 1, "best": {"level_01": {"rank": "Survived", "kept": 3}}, "skills": {"moss_dmg": 3}}')
	g.close()
	_check(SaveData.load_from(FILE).points_spent() == 0, "skills beyond earned stars are refunded")
	var old := FileAccess.open(FILE, FileAccess.WRITE)
	old.store_string('{"unlocked": 2, "xp": 900, "best": {"level_01": {"rank": "Wicked", "kept": 5}}, "skills": {"ash_dmg": 2}}')
	old.close()
	var o := SaveData.load_from(FILE)
	_check(o.points_total() == 2 and o.skill_rank("ash_dmg") == 2, "an old save with XP loads, XP ignored")

	# Loot never expires.
	var lv := Level.load_from("res://levels/level_01.json")
	var lt := GameSim.new(lv)
	var coin := GameSim.Loot.new()
	coin.kind = "coin"
	coin.amount = 5
	lt.loot.append(coin)
	for i in 2000:
		lt.update(0.05)   # 100 s
	_check(lt.loot.has(coin), "loot stays until it is tapped")
	_check(lv.gems == 5, "levels hold 5 gems")

	# The den: 1 charge to start, +1 per Den skill point; fires at heroes near it and refills.
	var dn := GameSim.new(lv)
	_check(dn.den_max == 1 and dn.den_charges == 1, "den starts with one charge")
	var dn3 := GameSim.new(lv, {"den_charge": 3})
	_check(dn3.den_max == 4, "each Den point adds a charge")
	dn3.timer = 9999.0
	var foe := GameSim.Enemy.new()
	foe.code = "k"
	foe.d = Defs.ENEMIES["k"]
	foe.hp = 1000.0
	foe.max_hp = 1000.0
	foe.path = 0
	foe.dist = lv.paths[0]["total"] - 1.0
	foe.pos = lv.path_pos(0, foe.dist)
	foe.dir = -1   # standing near the den, walking away slowly
	dn3.enemies.append(foe)
	for i in 30:
		dn3.update(0.05)   # 1.5 s: enough for 3 bolts at 0.5 s apart
	_check(dn3.den_charges <= 1 and foe.hp < 1000.0, "den spends charges on a nearby hero")
	dn3.enemies.clear()
	for i in int(Defs.DEN["refill"] / 0.05) + 2:
		dn3.update(0.05)
	_check(dn3.den_charges >= 1, "den charges refill over time")
	var sv := SaveData.load_from(FILE + ".none")
	sv.record(0, "level_01", "Brilliant", 5, true)
	_check(sv.buy("den_charge") and sv.skill_rank("den_charge") == 1, "Den skill can be bought with stars")

	# Calling a wave early gathers every coin and potion on the map.
	var ga := GameSim.new(lv)
	for k in ["coin", "potion", "coin"]:
		var it := GameSim.Loot.new()
		it.kind = k
		it.amount = 5
		ga.loot.append(it)
	var gold0 := ga.gold
	ga.mana = 0.0
	ga.call_early()
	_check(ga.loot.is_empty(), "early call gathers all loot")
	_check(ga.gold >= gold0 + 10 and ga.mana >= 5.0, "gathered coins and potions pay out")

	# Dropped gems roll home along the road, never cutting across the map.
	var rd := GameSim.new(lv)
	rd.home -= 1
	rd.timer = 9999.0   # no heroes, so nobody picks the gem up on the way
	var gem := GameSim.Drop.new()
	gem.n = 1
	gem.path = 0
	gem.dist = 2.0
	gem.pos = lv.path_pos(0, 2.0)
	rd.drops.append(gem)
	var on_road := true
	var steps := 0
	while not rd.drops.is_empty() and steps < 5000:
		rd.update(0.05)
		steps += 1
		if not rd.drops.is_empty() and gem.pos.distance_to(lv.path_pos(0, gem.dist)) > 0.001:
			on_road = false
	_check(on_road, "a dropped gem stays on the road")
	_check(rd.drops.is_empty() and rd.home == lv.gems, "a dropped gem reaches the lair")

	# Three tiers of clearance.
	var rk := GameSim.new(lv)
	rk.won = true
	_check(rk.rank() == "Brilliant", "untouched hoard is Brilliant")
	rk.touched = true
	_check(rk.rank() == "Wicked", "touched but nothing lost is Wicked")
	rk.lost = 1
	_check(rk.rank() == "Survived", "any gem lost is Survived")
	rk.won = false
	_check(rk.rank() == "Plundered", "a loss is Plundered")
	var ns := SaveData.load_from(FILE + ".none")
	ns.record(0, "level_01", "Wicked", 20, true)
	_check(not ns.night_unlocked("level_01"), "Wicked does not unlock night")
	ns.record(0, "level_01", "Brilliant", 20, true)
	_check(ns.night_unlocked("level_01"), "Brilliant unlocks night")
	ns.record(0, SaveData.mission_id("level_01", true), "Survived", 15, true)
	_check(ns.best_rank("level_01") == "Brilliant" and ns.best_rank("level_01:night") == "Survived", "night best is kept apart")
	# A hero grabbing from the hoard marks the gems as touched.
	var tg := GameSim.new(lv)
	while not tg.over and tg.home == lv.gems:
		tg.call_early()
		tg.update(0.05)
	_check(tg.touched, "grabbing a gem marks it touched")

	# Each slain hero drops at most one piece of loot: a coin or a potion, never both.
	var ls := GameSim.new(lv)
	var coins := 0
	var potions := 0
	for i in 2000:
		var e := GameSim.Enemy.new()
		e.code = "p"
		e.d = Defs.ENEMIES["p"]
		e.hp = 1.0
		e.max_hp = 1.0
		var before := ls.loot.size()
		ls.hurt(e, 999.0, true)
		_check(ls.loot.size() - before <= 1, "one kill drops at most one item")
		for l: GameSim.Loot in ls.loot.slice(before):
			if l.kind == "coin":
				coins += 1
			else:
				potions += 1
	print("loot from 2000 kills: %d coins (%.0f%%), %d potions (%.0f%%)" % [coins, coins / 20.0, potions, potions / 20.0])
	_check(absf(coins / 2000.0 - 0.35) < 0.04 and absf(potions / 2000.0 - 0.15) < 0.03, "drop rates near 35% coins, 15% potions")

	back.reset()
	_check(back.unlocked == 1 and back.best.is_empty() and back.points_total() == 0, "reset clears progress")
	DirAccess.remove_absolute(FILE)
	print("save_test: %s" % ("all passed" if fails == 0 else "%d failed" % fails))
	quit(0 if fails == 0 else 1)


func _check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		printerr("FAIL: " + what)

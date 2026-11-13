class_name Bot
extends RefCounted
## A simple player for headless tests: builds on every free tile next to a road, closest to the
## lair first, then upgrades; razes barracks before spending mana on anything else; casts the
## Meteor whenever it can and picks up all loot. It plays much better than a person (it never
## hesitates), so a win only shows a level is winnable.

## Dark Arts points the bot spends, in this order, as the campaign goes on.
const SKILL_ORDER := ["moss_dmg", "ash_dmg", "ash_dmg", "moss_dmg", "ash_ability", "frost_ability", "ash_dmg", "moss_dmg",
	"den_charge", "ash_rate", "moss_rate", "ash_ability", "den_charge", "hoard_gold", "ash_rate", "moss_rate", "moss_range",
	"ash_range", "frost_dmg", "hoard_gold", "frost_dmg", "frost_rate", "frost_range", "den_charge", "moss_vet", "ash_vet",
	"frost_vet", "meteor_dmg", "frost_ability", "moss_ability", "ash_ability", "hoard_mana", "hoard_gold", "frost_dmg",
	"moss_rate", "ash_rate", "frost_rate", "moss_range", "ash_range", "frost_range", "den_charge", "meteor_dmg",
	"moss_ability", "frost_ability", "hoard_mana", "moss_vet", "ash_vet", "frost_vet", "frost_rate", "den_charge",
	"hoard_gold", "meteor_dmg", "moss_ability", "hoard_mana", "hoard_mana", "hoard_gold",
	# Chapter III onward (tier II opens with Chapter III, The Land with Chapter II):
	"mastery_longhouse", "mastery_ossuary", "mastery_twin", "land_axes", "spell_nightmare", "moss_bodkin",
	"frost_freeze", "ash_memory", "mastery_lodge", "mastery_mausoleum", "mastery_sunlance", "spell_frenzy",
	"land_veins", "ash_core", "frost_cold", "moss_keen", "land_springs", "land_flood", "land_rites", "gem_magnet",
	"land_axes", "nightmare_dur", "frenzy_dur", "moss_bodkin", "frost_freeze", "ash_memory", "land_heights", "land_spoils",
	"ash_core", "frost_cold", "moss_keen", "land_veins", "land_springs", "frost_dread", "ash_cooling", "land_lantern"]


## Skill points a player has banked before campaign lair `index` (0-based): about 2.4 stars a lair
## beaten (a mix of Wicked and Brilliant, plus a few night missions). Not capped: skills() spends
## only as many as SKILL_ORDER lists, so new skills just need adding to it.
static func points_before(index: int) -> int:
	return roundi(2.4 * index)


## points to spend, with `beaten` campaign lairs behind the player: skills whose tier has not opened
## yet (Defs.skill_gate) are passed over. Before campaign lair i (0-based) the player has beaten i.
static func skills(points: int, beaten := 1000) -> Dictionary:
	var s := {}
	var spent := 0
	for id: String in SKILL_ORDER:
		if spent >= points:
			break
		if Defs.skill_gate(id) > beaten:
			continue
		s[id] = int(s.get(id, 0)) + 1
		spent += 1
	return s


## Plays the battle to the end (or 1200 s) and returns the finished sim. A non-zero seed changes
## the luck (loot, Dread, Lava) for the same battle.
static func play(lv: Level, skill_ranks: Dictionary, seed := 0) -> GameSim:
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
	spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_to(lv.lair_center) < Vector2(b).distance_to(lv.lair_center))
	var t := 0.0
	var dt := 0.05
	while not sim.over and t < 1200.0:
		# Take the first thing each tile offers (cut, build, upgrade); never sell.
		var uncut := sim.sites.values().any(func(s: GameSim.Site) -> bool: return not s.owned and s.kind == "camp")
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
					sim.do_action(opts[(v.x + v.y) % opts.size()]["id"], v)
					break
				if a["id"] != "sell":
					sim.do_action(a["id"], v)
					break
		_collapse(sim)
		_spells(sim)
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


## Nightmare on a gem carrier near the den or a crowd; Frenzy where most heroes are in reach of towers.
static func _spells(sim: GameSim) -> void:
	if sim.can_cast("nightmare"):
		for e: GameSim.Enemy in sim.enemies:
			if e.carry > 0 or e.pos.distance_to(sim.level.lair_center) < 2.0:
				var n := sim.enemies.filter(func(o: GameSim.Enemy) -> bool: return o.pos.distance_to(e.pos) <= Defs.NIGHTMARE["radius"]).size()
				if n >= 3 or e.carry > 0:
					sim.cast("nightmare", e.pos)
					break
	if sim.can_cast("frenzy") and sim.enemies.size() >= 8:
		var best: GameSim.Tower = null
		var most := 5
		for tw: GameSim.Tower in sim.towers.values():
			var n := sim.enemies.filter(func(o: GameSim.Enemy) -> bool: return o.pos.distance_to(tw.pos) <= tw.stat("range")).size()
			if n > most:
				most = n
				best = tw
		if best != null:
			sim.cast("frenzy", best.pos)

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
	"hoard_gold", "meteor_dmg", "moss_ability", "hoard_mana", "hoard_mana", "hoard_gold"]


## Skill points a player has banked before campaign lair `index` (0-based): about 2.4 stars a lair
## beaten (a mix of Wicked and Brilliant, plus a few night missions).
static func points_before(index: int) -> int:
	return mini(SKILL_ORDER.size(), roundi(2.4 * index))


static func skills(points: int) -> Dictionary:
	var s := {}
	for i in mini(points, SKILL_ORDER.size()):
		s[SKILL_ORDER[i]] = int(s.get(SKILL_ORDER[i], 0)) + 1
	return s


## Plays the battle to the end (or 1200 s) and returns the finished sim. A non-zero seed changes
## the luck (loot, Dread, Lava) for the same battle.
static func play(lv: Level, skill_ranks: Dictionary, seed := 0) -> GameSim:
	var sim := GameSim.new(lv, skill_ranks)
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
			for a: Dictionary in sim.cell_info(v)["actions"]:
				if a["id"] == "clear" and uncut:
					break   # save mana to raze barracks first
				if a["id"] != "sell":
					sim.do_action(a["id"], v)
					break
		if sim.can_meteor() and not sim.enemies.is_empty():
			sim.cast_meteor(sim.enemies[0].pos)
		for l: GameSim.Loot in sim.loot.duplicate():
			sim.collect_loot(l.pos)
		sim.update(dt)
		t += dt
	return sim

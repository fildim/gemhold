class_name Loadout
extends RefCounted
## The standard Dark Arts a player is taken to have at each point of the campaign: about 2.4 stars
## a lair, spent in a set order. Every lair's hero health (hp_mul) is tuned for a player holding
## these skills, so they are what the test bot plays with (tests/bot.gd) and what both racers get
## in an online race, whatever their own skills, so a race is fair and winnable on any lair.

## Dark Arts points spent, in this order, as the campaign goes on.
const SKILL_ORDER := ["moss_dmg", "ash_dmg", "ash_dmg", "moss_dmg", "ash_ability", "frost_ability", "ash_dmg", "moss_dmg",
	"den_charge", "ash_rate", "moss_rate", "ash_ability", "den_charge", "hoard_gold", "ash_rate", "moss_rate", "moss_range",
	"ash_range", "frost_dmg", "hoard_gold", "frost_dmg", "frost_rate", "frost_range", "den_charge", "moss_vet", "ash_vet",
	"frost_vet", "meteor_dmg", "frost_ability", "moss_ability", "ash_ability", "hoard_mana", "hoard_gold", "frost_dmg",
	"moss_rate", "ash_rate", "frost_rate", "moss_range", "ash_range", "frost_range", "den_charge", "meteor_dmg",
	"moss_ability", "frost_ability", "hoard_mana", "moss_vet", "ash_vet", "frost_vet", "frost_rate", "den_charge",
	"hoard_gold", "meteor_dmg", "moss_ability", "hoard_mana", "hoard_mana", "hoard_gold",
	# Chapter III onward (tier II opens with Chapter III, The Land with Chapter II):
	"mastery_longhouse", "mastery_ossuary", "mastery_twin", "land_axes", "moss_bodkin",
	"frost_freeze", "ash_memory", "mastery_lodge", "mastery_mausoleum", "mastery_sunlance",
	"hoard_gold", "ash_core", "frost_cold", "moss_keen", "hoard_regen", "land_flood", "land_rites", "gem_magnet",
	"land_axes", "moss_bodkin", "frost_freeze", "ash_memory", "land_heights", "land_spoils",
	"ash_core", "frost_cold", "moss_keen", "hoard_gold", "hoard_regen", "frost_dread", "ash_cooling", "land_lantern",
	# Chapter IV onward:
	"sturdy", "sturdy", "land_heights", "sturdy", "moss_keen", "ash_memory", "frost_freeze", "hoard_gold", "hoard_regen",
	"land_axes", "gem_magnet", "land_spoils", "land_lantern", "land_flood", "land_rites", "frost_dread", "ash_cooling", "gem_magnet", "land_lantern",
	# Chapter V onward (tier III):
	"moss_legend", "ash_legend", "den_fury", "frost_legend", "dragon_patience", "moss_legend", "ash_legend", "den_fury", "frost_legend",
	"dragon_patience", "moss_legend", "ash_legend", "den_fury", "frost_legend", "moss_legend", "ash_legend", "frost_legend", "den_fury"]


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
	for want: String in SKILL_ORDER:
		if spent >= points:
			break
		# A tiered skill that is full goes on to its next tier (Buried Gold -> Buried Gold II), as the
		# 9-rank skills did before they were split by tier.
		var id := want
		while id != "" and int(s.get(id, 0)) >= Defs.skill_cap(id, beaten):
			id = str(Defs.skill_def(id).get("next", ""))
		if id == "" or Defs.skill_gate(id) > beaten:
			continue
		s[id] = int(s.get(id, 0)) + 1
		spent += 1
	return s


## The skills both racers play campaign lair `index` (0-based) with.
static func for_lair(index: int) -> Dictionary:
	return skills(points_before(index), index)

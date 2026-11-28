class_name BattleReport
extends RefCounted
## One short report per campaign battle, for balance work: sent to Firestore (reports/<id>) when the
## battle ends or the player leaves or restarts it (Online.send_report). The player can turn it off
## (Prefs "reports"). It holds no personal data: only a random id for this install ("player"), so one
## player's battles can be grouped without knowing who it is. tools/reports.gd downloads and sums them.

const VERSION := 1     # of this layout, so the summary tool can tell old reports apart
const PREF := "reports"


## Whether reports are sent (on unless the player turned them off).
static func enabled() -> bool:
	return bool(Prefs.get_value(PREF, true))


## This install's random id, made once and kept in the settings. Not tied to the account.
static func player_id() -> String:
	var id := str(Prefs.get_value("report_id", ""))
	if id.length() != 16:
		id = ""
		for i in 16:
			id += "abcdefghijklmnopqrstuvwxyz0123456789"[randi() % 36]
		Prefs.set_value("report_id", id)
	return id


## The report of a battle. end: "won", "lost", "quit" (left for the map) or "restart".
## number counts lairs from 1 in campaign order.
static func build(sim: GameSim, number: int, end: String) -> Dictionary:
	var lv := sim.level
	var towers := []
	for tw: GameSim.Tower in sim.towers.values():
		towers.append("%s%d r%d%s" % [tw.type, tw.lvl, tw.rank, (" " + tw.mastery) if tw.mastery != "" else ""])
	towers.sort()
	var left := 0
	for l: GameSim.Loot in sim.loot:
		if l.kind == "potion":
			left += 1
	var skills := {}
	for k: String in sim.skills:
		if int(sim.skills[k]) > 0:
			skills[k] = int(sim.skills[k])
	return {
		"v": VERSION,
		"lair": lv.id, "n": number, "title": lv.title, "night": lv.night,
		"end": end, "rank": sim.rank() if sim.over else "", "lost": sim.lost, "gems": lv.gems,
		"wave": sim.wave, "waves": lv.waves.size(), "time": roundi(sim.time),
		"res": snappedf(sim.threat, 0.01), "gold": sim.gold, "mana": roundi(sim.mana),
		"kills": sim.kills, "early": sim.early_calls, "skipped": sim.skipped,
		"meteors": sim.meteors, "meteor_kills": sim.meteor_kills,
		"potions": sim.potions, "potions_left": left, "coins": sim.coins,
		"built": sim.towers_built, "sold": sim.sold, "upgrades": sim.upgrades, "woods": sim.woods_cut,
		"towers": towers, "skills": skills,
		"per_wave": sim.log_waves.slice(0, 40), "gem_events": sim.log_gems, "sites": sim.log_sites,
	}


## Whether a battle is worth a report: a campaign battle (no race, no Long Night) that got going.
static func worth(sim: GameSim) -> bool:
	return sim != null and not sim.race_on and not sim.long_on and sim.wave >= 1

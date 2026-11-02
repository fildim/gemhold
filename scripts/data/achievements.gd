class_name Achievements
extends RefCounted
## The achievements: badges with no effect on play. LIST is the order they are shown in.
## check_battle() runs when a battle ends, check_progress() whenever the campaign changes;
## both mark new ones in the save and return their ids so the game can announce them.

const LIST: Array[Dictionary] = [
	{"id": "first_win", "name": "First Blood", "text": "Defend your first lair."},
	{"id": "brilliant", "name": "Untouched", "text": "Win a lair Brilliant: no hero lays a hand on a gem."},
	{"id": "night_win", "name": "Creature of the Night", "text": "Win a night mission."},
	{"id": "last_gem", "name": "By a Thread", "text": "Win with a single gem left."},
	{"id": "meteor5", "name": "Rain of Fire", "text": "Slay 5 heroes with one meteor."},
	{"id": "only_moss", "name": "Warband Only", "text": "Win lair 3 or later with Warband Huts as your only towers."},
	{"id": "only_frost", "name": "Crypt Keeper", "text": "Win lair 3 or later with Bone Crypts as your only towers."},
	{"id": "only_ash", "name": "Fire Worshipper", "text": "Win lair 3 or later with Cinder Shrines as your only towers."},
	{"id": "ability", "name": "Battle-Hardened", "text": "Have a tower learn its ability."},
	{"id": "raze", "name": "Barracks Breaker", "text": "Raze a hero barracks."},
	{"id": "landlord", "name": "Lord of the Land", "text": "Free or raze every building in a lair that has three or more."},
	{"id": "early8", "name": "Impatient", "text": "Call 8 waves early in one battle."},
	{"id": "rich", "name": "Dragon's Hoard", "text": "Win with 1,000 gold or more left over."},
	{"id": "few", "name": "Few but Fierce", "text": "Win lair 5 or later with never more than 5 towers standing."},
	{"id": "champion", "name": "Kingslayer", "text": "Slay a Champion."},
	{"id": "score", "name": "High Roller", "text": "Score 6,000 points in one battle."},
	{"id": "kills1000", "name": "Hero Bane", "text": "Slay 1,000 heroes in all."},
	{"id": "kills10000", "name": "Legend Eater", "text": "Slay 10,000 heroes in all."},
	{"id": "arts20", "name": "Dark Scholar", "text": "Spend 20 skill points in Dark Arts."},
	{"id": "chapter1", "name": "Lowland Lord", "text": "Defend every lair of Chapter I."},
	{"id": "chapter2", "name": "Crusade Crushed", "text": "Defend all twenty lairs."},
	{"id": "all_brilliant", "name": "Perfectionist", "text": "Win every lair Brilliant."},
	{"id": "all_night", "name": "Eternal Night", "text": "Win every night mission."},
]

const SCORE_GOAL := 6000


static func find(id: String) -> Dictionary:
	for a in LIST:
		if a["id"] == id:
			return a
	return {}


## After a battle (already recorded in the save, stats included). number is the lair's place in
## the campaign, from 1. Returns the ids earned just now.
static func check_battle(save: SaveData, sim: GameSim, number: int) -> Array[String]:
	var got: Array[String] = []
	var kills := int(save.stats.get("kills", 0))
	_try(save, got, "kills1000", kills >= 1000)
	_try(save, got, "kills10000", kills >= 10000)
	_try(save, got, "meteor5", sim.best_meteor >= 5)
	_try(save, got, "ability", sim.abilities > 0)
	_try(save, got, "champion", int(sim.kills_by.get("x", 0)) > 0)
	var razed := 0
	var owned := 0
	for s: GameSim.Site in sim.sites.values():
		if s.owned:
			owned += 1
			if s.kind == "camp":
				razed += 1
	_try(save, got, "raze", razed > 0)
	_try(save, got, "early8", sim.early_calls >= 8)
	if sim.won:
		_try(save, got, "first_win", true)
		_try(save, got, "brilliant", sim.rank() == "Brilliant")
		_try(save, got, "night_win", sim.level.night)
		_try(save, got, "last_gem", sim.level.gems - sim.lost == 1)
		_try(save, got, "landlord", sim.sites.size() >= 3 and owned == sim.sites.size())
		_try(save, got, "rich", sim.gold >= 1000)
		_try(save, got, "few", number >= 5 and sim.most_towers <= 5)
		_try(save, got, "score", sim.score(number) >= SCORE_GOAL)
		if number >= 3 and sim.built.size() == 1:
			_try(save, got, "only_" + str(sim.built.keys()[0]), true)
	return got


## Campaign-wide ones. ids is every lair's level id in campaign order; chapters hold `per_chapter` lairs.
static func check_progress(save: SaveData, ids: Array, per_chapter := 10) -> Array[String]:
	var got: Array[String] = []
	var beaten := 0
	var brilliant := 0
	var nights := 0
	for i in ids.size():
		var id: String = ids[i]
		if save.stars(id) > 0 and i == beaten:
			beaten += 1   # counted only while the run of beaten lairs from the start holds
		if save.best_rank(id) == "Brilliant":
			brilliant += 1
		if save.stars(SaveData.mission_id(id, true)) > 0:
			nights += 1
	# Also battle ones the save proves, for players who won before achievements existed.
	_try(save, got, "first_win", save.points_total() > 0)
	_try(save, got, "brilliant", brilliant > 0)
	_try(save, got, "night_win", nights > 0)
	_try(save, got, "chapter1", beaten >= mini(per_chapter, ids.size()))
	_try(save, got, "chapter2", beaten >= ids.size())
	_try(save, got, "all_brilliant", brilliant >= ids.size())
	_try(save, got, "all_night", nights >= ids.size())
	_try(save, got, "arts20", save.points_spent() >= 20)
	return got


static func _try(save: SaveData, got: Array[String], id: String, ok: bool) -> void:
	if ok and save.earn(id):
		got.append(id)

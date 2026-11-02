class_name SaveData
extends RefCounted
## Campaign progress: unlocked levels, the best result on each (its stars are the skill points)
## and skill tree ranks; also the best score on each mission, lifetime stats and achievements,
## which outlive a progress reset and are shared with the online account (see Online).
## Stored as JSON in user:// (on Android that is the app's private storage).

const PATH := "user://save.json"
const VERSION := 4
## Ratings from worst to best, as returned by GameSim.rank().
const RANKS: Array[String] = ["Plundered", "Survived", "Wicked", "Brilliant"]

var path := PATH
var unlocked := 1        # number of campaign levels the player may start
var best := {}           # level id -> {"rank": String, "kept": int}
var skills := {}         # skill id -> rank
var scores := {}         # mission id -> best score (GameSim.score)
var stats := {}          # lifetime counters: "kills", "battles", "wins"
var achievements := {}   # achievement id -> unix time it was earned


## Reads the save file, or starts fresh if it is missing or unreadable.
static func load_from(file_path := PATH) -> SaveData:
	var s := SaveData.new()
	s.path = file_path
	if not FileAccess.file_exists(file_path):
		return s
	var text := FileAccess.get_file_as_string(file_path)
	var d = JSON.parse_string(text)
	if typeof(d) != TYPE_DICTIONARY:
		push_warning("Save file unreadable, starting fresh: " + file_path)
		return s
	s.unlocked = maxi(1, int(d.get("unlocked", 1)))
	var b = d.get("best", {})
	if typeof(b) == TYPE_DICTIONARY:
		for id in b:
			var r = b[id]
			if typeof(r) == TYPE_DICTIONARY and RANKS.has(str(r.get("rank", ""))):
				s.best[str(id)] = {"rank": str(r["rank"]), "kept": int(r.get("kept", 0))}
	var sk = d.get("skills", {})
	if typeof(sk) == TYPE_DICTIONARY:
		for id in sk:
			var m := s._skill_max(str(id))
			if m > 0:
				s.skills[str(id)] = clampi(int(sk[id]), 0, m)
	for key in ["scores", "stats", "achievements"]:
		var m = d.get(key, {})
		if typeof(m) == TYPE_DICTIONARY:
			var into: Dictionary = s.get(key)
			for id in m:
				into[str(id)] = maxi(0, int(m[id]))
	if s.points_free() < 0:
		s.skills.clear()   # damaged or edited file: refund everything
	return s


## Writes to a temporary file first, so a crash mid-write never leaves a broken save.
func save() -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify({"version": VERSION, "unlocked": unlocked, "best": best, "skills": skills,
		"scores": scores, "stats": stats, "achievements": achievements}, "\t"))
	f.close()
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_warning("Could not replace save: %s" % error_string(err))
		return false
	return true


func is_unlocked(index: int) -> bool:
	return index < unlocked


## Key for a mission's best result: the level id, plus ":night" for its night mission.
static func mission_id(level_id: String, night: bool) -> String:
	return level_id + (":night" if night else "")


## A level's night mission opens once the day mission is cleared Brilliant.
func night_unlocked(level_id: String) -> bool:
	return best_rank(level_id) == "Brilliant"


func best_rank(level_id: String) -> String:
	return best[level_id]["rank"] if best.has(level_id) else ""


## Stars shown on the level map: 0 for unbeaten, 1 Survived, 2 Wicked, 3 Brilliant.
func stars(level_id: String) -> int:
	return maxi(0, RANKS.find(best_rank(level_id)))


## Records a finished battle. A win unlocks the next level. Returns true if this beat the old best.
func record(index: int, level_id: String, rank: String, kept: int, won: bool) -> bool:
	if won:
		unlocked = maxi(unlocked, index + 2)
	var old := RANKS.find(best_rank(level_id))
	var now := RANKS.find(rank)
	var improved := now > old or (now == old and best.has(level_id) and kept > int(best[level_id]["kept"]))
	if won and improved:
		best[level_id] = {"rank": rank, "kept": kept}
	return won and improved


## Scores, stats and achievements stay: they belong to the player, not to this run of the campaign.
func reset() -> void:
	unlocked = 1
	best.clear()
	skills.clear()


# ---------------------------------------------------------------- stars and skills

## Skill points are stars: the sum of every mission's best rating (day and night count separately).
func points_total() -> int:
	var n := 0
	for id in best:
		n += stars(id)
	return n


func points_spent() -> int:
	var n := 0
	for id in skills:
		n += int(skills[id])
	return n


func points_free() -> int:
	return points_total() - points_spent()


func skill_rank(id: String) -> int:
	return int(skills.get(id, 0))


func can_buy(id: String) -> bool:
	return points_free() > 0 and skill_rank(id) < _skill_max(id)


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	skills[id] = skill_rank(id) + 1
	return true


func reset_skills() -> void:
	skills.clear()


func _skill_max(id: String) -> int:
	for tree in Defs.SKILLS.values():
		for sk: Dictionary in tree:
			if sk["id"] == id:
				return int(sk["max"])
	return 0


# ---------------------------------------------------------------- scores, stats, achievements

## Keeps a mission's score if it beats the best. Returns true if it did.
func record_score(mission: String, score: int) -> bool:
	if score <= int(scores.get(mission, 0)):
		return false
	scores[mission] = score
	return true


## The leaderboard total: every mission's best score added up.
func total_score() -> int:
	var n := 0
	for id in scores:
		n += int(scores[id])
	return n


func add_stat(key: String, n: int) -> void:
	stats[key] = int(stats.get(key, 0)) + n


func has_achievement(id: String) -> bool:
	return achievements.has(id)


## Marks an achievement earned. Returns true if it is new.
func earn(id: String) -> bool:
	if achievements.has(id):
		return false
	achievements[id] = int(Time.get_unix_time_from_system())
	return true


## Takes in what an online account remembers (best scores, achievements) without losing anything here.
func merge_online(online_scores: Dictionary, online_achievements: Array) -> void:
	for id in online_scores:
		record_score(str(id), int(online_scores[id]))
	for id in online_achievements:
		if not achievements.has(str(id)):
			achievements[str(id)] = int(Time.get_unix_time_from_system())

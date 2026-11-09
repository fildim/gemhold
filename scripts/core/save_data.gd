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
var skills_t := 0        # unix time the ranks last changed: the newest set wins when devices merge
var reset_t := 0         # unix time the campaign was last erased (0 if never): it spreads to the player's other devices
var scores := {}         # mission id -> best score (GameSim.score)
var stats := {}          # lifetime counters: "kills", "battles", "wins", "race_wins", "race_losses", "race_draws"
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
	s.skills_t = maxi(0, int(d.get("skills_t", 0)))
	s.reset_t = maxi(0, int(d.get("reset_t", 0)))
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
		"skills_t": skills_t, "reset_t": reset_t, "scores": scores, "stats": stats, "achievements": achievements}, "\t"))
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
	skills_t = _stamp(skills_t)
	reset_t = _stamp(reset_t)


## A different account signs in on this device: this progress is set aside for its owner, and the
## new account gets what it left here earlier or a clean slate. Not an Erase: nothing spreads online.
func switch_owner(old_owner: String, new_owner: String) -> void:
	var live := path
	path = _owner_file(old_owner)
	save()
	path = live
	var kept := _owner_file(new_owner)
	var s := SaveData.load_from(kept)
	unlocked = s.unlocked
	best = s.best
	skills = s.skills
	skills_t = s.skills_t
	reset_t = s.reset_t
	scores = s.scores
	stats = s.stats
	achievements = s.achievements
	save()
	if FileAccess.file_exists(kept):
		DirAccess.remove_absolute(kept)


func _owner_file(owner: String) -> String:
	return "%s_%s.json" % [path.get_basename(), owner]


## The time now, always later than `previous` even if this device's clock is behind.
static func _stamp(previous: int) -> int:
	return maxi(int(Time.get_unix_time_from_system()), previous + 1)


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
	skills_t = _stamp(skills_t)
	return true


func reset_skills() -> void:
	skills.clear()
	skills_t = _stamp(skills_t)


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


## Takes in what an online account remembers without losing anything here: best scores,
## achievements, lifetime stats (the higher of each counter) and, if the account holds it, the
## campaign `progress` (see Online.progress_of). Returns true if anything here changed.
func merge_online(online_scores: Dictionary, online_achievements: Array, online_stats := {}, progress := {}) -> bool:
	var before := _fingerprint()
	for id in online_scores:
		record_score(str(id), int(online_scores[id]))
	for key in online_stats:
		var n := int(str(online_stats[key])) if str(online_stats[key]).is_valid_int() else 0
		stats[key] = maxi(int(stats.get(key, 0)), n)
	for id in online_achievements:
		if not achievements.has(str(id)):
			achievements[str(id)] = int(Time.get_unix_time_from_system())
	if not progress.is_empty():
		_merge_campaign(progress)
	return _fingerprint() != before


func _fingerprint() -> String:
	return JSON.stringify([unlocked, best, skills, skills_t, reset_t, scores, stats, achievements.keys()])


## The highest unlocked level and the better result on each mission. The one thing that may lower
## them is the player's own Erase progress, which spreads: the side with the older reset_t is the
## one that was erased, so its campaign is not taken in again.
func _merge_campaign(p: Dictionary) -> void:
	var their_reset := int(p.get("reset_t", 0))
	if their_reset < reset_t:
		return   # the account still holds the campaign this device erased
	if their_reset > reset_t:
		reset_t = their_reset
		unlocked = 1
		best.clear()
		skills.clear()
		skills_t = 0
	unlocked = maxi(unlocked, int(p.get("unlocked", 1)))
	var theirs: Dictionary = p.get("best", {})
	for id in theirs:
		var r = theirs[id]
		if typeof(r) != TYPE_DICTIONARY or not RANKS.has(str(r.get("rank", ""))):
			continue
		var old := RANKS.find(best_rank(str(id)))
		var now := RANKS.find(str(r["rank"]))
		if now > old or (now == old and int(r.get("kept", 0)) > int(best[str(id)]["kept"])):
			best[str(id)] = {"rank": str(r["rank"]), "kept": int(r.get("kept", 0))}
	_merge_skills(p.get("skills", {}), int(p.get("skills_t", 0)))


## Skill ranks are a build the player chose, not a record to beat, so they are never mixed: the
## set changed most recently wins whole (equal times: the one with more points spent, then the
## account's). Taking the highest rank of each skill would add two builds together past the
## player's stars and bring refunded ranks back. A whole set always fits, because stars only rise
## in a merge; only a damaged account could break that, and then it is ignored.
func _merge_skills(theirs: Dictionary, t: int) -> void:
	var clean := {}
	var spent := 0
	for id in theirs:
		var rank := clampi(int(theirs[id]), 0, _skill_max(str(id)))
		if rank > 0:
			clean[str(id)] = rank
			spent += rank
	var wins := t > skills_t or (t == skills_t and spent >= points_spent())
	if wins and spent <= points_total():
		skills = clean
		skills_t = t
	if points_free() < 0:
		skills.clear()

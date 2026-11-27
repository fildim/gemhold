class_name Online
extends Node
## The optional online account: Firebase email/password sign-in and the leaderboard in Firestore,
## both over their REST APIs so it works the same on every platform, the web included.
## A signed-in player has one document, players/<uid>: {name, total, stars, rw, rl, scores, ach, updated}
## plus the campaign, {unlocked, best, skills, skills_t, reset_t, stats} (rules in firestore.rules).
## Anyone may read the leaderboard; only signed-in players appear on it. Every upload first pulls
## the document and merges it into the save (SaveData.merge_online), so devices add up instead of
## overwriting each other.
## Calls are coroutines: `var err := await online.sign_in(...)`, "" on success.

signal changed   # signed in or out, or the player's name changed on another device
signal merged    # the account brought new progress into the save

## Upload the campaign fields too. Needs firestore.rules deployed: rules without these fields
## refuse the upload, which would stop the leaderboard updating as well.
const SYNC_PROGRESS := true

const API_KEY := "AIzaSyAdWN9fBo3FQ0xfY6Z_YHnuAb9VSG5G42E"   # public web key; Firestore rules guard the data
const PROJECT := "gemhold"
const PATH := "user://account.cfg"
const AUTH_HOST := "https://identitytoolkit.googleapis.com"
const TOKEN_HOST := "https://securetoken.googleapis.com"
const DOCS_HOST := "https://firestore.googleapis.com"

## Firebase only deletes an account soon after a password sign-in (about five minutes).
const DELETE_WINDOW := 240.0
const SIGN_IN_AGAIN := "For your safety, sign out and sign in again, then delete straight away"
const NAME_MIN := 2
const NAME_MAX := 16

var uid := ""
var player_name := ""
var email := ""
var path := PATH        # tests point this elsewhere
var sync_progress := SYNC_PROGRESS   # tests turn this on
var _owner := ""        # the account this device's save belongs to, kept after signing out ("" = nobody's yet)
var _password_at := 0.0 # unix time of this session's last password sign-in (0 after a restart)
var _refresh := ""
var _token := ""
var _token_until := 0.0   # unix time the id token runs out
var _syncing := false
var _sync_again: SaveData
var _auth := AUTH_HOST + "/v1/accounts:"
var _token_url := TOKEN_HOST + "/v1/token"
var _docs := DOCS_HOST + "/v1/projects/" + PROJECT + "/databases/(default)/documents"


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		uid = cfg.get_value("account", "uid", "")
		player_name = cfg.get_value("account", "name", "")
		email = cfg.get_value("account", "email", "")
		_refresh = cfg.get_value("account", "refresh", "")
		_owner = cfg.get_value("account", "owner", uid)
	if _refresh == "":
		uid = ""


func signed_in() -> bool:
	return uid != ""


## Talks to the local Firebase emulators instead (tests/online_test.gd).
func use_emulators(auth_port := 9099, firestore_port := 8080) -> void:
	_auth = "http://127.0.0.1:%d/identitytoolkit.googleapis.com/v1/accounts:" % auth_port
	_token_url = "http://127.0.0.1:%d/securetoken.googleapis.com/v1/token" % auth_port
	_docs = "http://127.0.0.1:%d/v1/projects/%s/databases/(default)/documents" % [firestore_port, PROJECT]


## Leaderboard keys can't hold ":", so a night mission "level_01:night" is stored as "level_01_night".
static func score_key(mission: String) -> String:
	return mission.replace(":", "_")


static func mission_of_key(key: String) -> String:
	return key.replace("_night", ":night").replace("_long", ":long")


static func check_name(n: String) -> String:
	n = n.strip_edges()
	if n.length() < NAME_MIN or n.length() > NAME_MAX:
		return "Pick a name of %d to %d letters" % [NAME_MIN, NAME_MAX]
	return ""


# ---------------------------------------------------------------- account

func sign_up(mail: String, password: String, name: String, save: SaveData) -> String:
	var bad := check_name(name)
	if bad != "":
		return bad
	var r := await _call("POST", _auth + "signUp?key=" + API_KEY, {"email": mail.strip_edges(), "password": password, "returnSecureToken": true})
	if not r["ok"]:
		return r["error"]
	_take_tokens(r["data"])
	_password_at = Time.get_unix_time_from_system()
	_claim_save(save)
	email = mail.strip_edges()
	player_name = name.strip_edges()
	_store()
	changed.emit()
	sync(save)
	return ""


## Signs in and brings back what the account remembers: merged into save, which is then saved and uploaded.
func sign_in(mail: String, password: String, save: SaveData) -> String:
	var r := await _call("POST", _auth + "signInWithPassword?key=" + API_KEY, {"email": mail.strip_edges(), "password": password, "returnSecureToken": true})
	if not r["ok"]:
		return r["error"]
	_take_tokens(r["data"])
	_password_at = Time.get_unix_time_from_system()
	_claim_save(save)
	email = mail.strip_edges()
	await pull(save)
	if player_name == "":
		player_name = email.get_slice("@", 0).left(NAME_MAX)
	_store()
	changed.emit()
	sync(save)
	return ""


## Progress played on this device goes to the first account that signs in here, and only that one:
## another account must neither copy it to the leaderboard nor mix its own progress into it.
func _claim_save(save: SaveData) -> void:
	if _owner != "" and _owner != uid:
		save.switch_owner(_owner, uid)
		merged.emit()
	_owner = uid


func reset_password(mail: String) -> String:
	var r := await _call("POST", _auth + "sendOobCode?key=" + API_KEY, {"requestType": "PASSWORD_RESET", "email": mail.strip_edges()})
	return "" if r["ok"] else r["error"]


func sign_out() -> void:
	uid = ""
	player_name = ""
	email = ""
	_refresh = ""
	_token = ""
	_store()
	changed.emit()


## Takes the player off the leaderboard and deletes the account. Progress on this device stays.
func delete_account() -> String:
	if Time.get_unix_time_from_system() - _password_at > DELETE_WINDOW:
		return SIGN_IN_AGAIN   # asked before anything is removed, so a refusal can't leave it half done
	if not await _fresh_token():
		return "Could not reach the server"
	var r := await _call("DELETE", _docs + "/players/" + uid, null, true)
	if not r["ok"]:
		return r["error"]
	await presence_leave()
	r = await _call("POST", _auth + "delete?key=" + API_KEY, {"idToken": _token})
	if not r["ok"]:
		return r["error"]
	_owner = ""   # the progress stays and is free for the next account
	sign_out()
	return ""


func rename(name: String, save: SaveData) -> String:
	var bad := check_name(name)
	if bad != "":
		return bad
	var err := await upload(save, name.strip_edges())
	if err != "":
		return err
	player_name = name.strip_edges()
	_store()
	changed.emit()
	return ""


# ---------------------------------------------------------------- leaderboard

## Merges the account's document into save (and writes the save if that changed it). "" on success,
## which includes an account with no document yet. On any failure save is left alone.
func pull(save: SaveData, take_name := true) -> String:
	var who := uid
	var me := await _call("GET", _docs + "/players/" + who, null, true)
	if uid != who:
		return "Not signed in"
	if not me["ok"]:
		return "" if me.get("code", 0) == 404 else str(me["error"])
	var f: Dictionary = me["data"].get("fields", {})
	if take_name and str(_value(f.get("name", {}))) not in ["", player_name]:
		player_name = str(_value(f["name"]))
		_store()
		changed.emit()
	var sc := _map(f.get("scores", {}))
	var scores := {}
	for k: String in sc:
		scores[mission_of_key(k)] = sc[k]
	var stats := _map(f.get("stats", {}))
	for pair in [["race_wins", "rw"], ["race_losses", "rl"]]:
		stats[pair[0]] = maxi(int(stats.get(pair[0], 0)), int(_value(f.get(pair[1], {}))))
	if save.merge_online(scores, _list(f.get("ach", {})), stats, progress_of(f)):
		save.save()
		merged.emit()
	# A full-game code entered on any device of this account unlocks the demo builds here too.
	var full: Variant = _value(f.get("full", {}))
	if full is bool and full and not Prefs.get_value("full", false):
		Edition.unlock()
		merged.emit()
	return ""


## Merges the account into the save, then puts the result online (does nothing when signed out).
## Overlapping calls collapse into one more upload once the current one finishes.
func sync(save: SaveData) -> void:
	if not signed_in():
		return
	if _syncing:
		_sync_again = save
		return
	_syncing = true
	var err := await upload(save)
	if err != "":
		push_warning("Leaderboard upload failed: " + err)
	_syncing = false
	if _sync_again:
		var s := _sync_again
		_sync_again = null
		sync(s)


## Never writes without pulling first: if the pull fails, this device's copy stays here until the
## next try. new_name: the name to store instead of the current one (a rename not yet confirmed).
func upload(save: SaveData, new_name := "") -> String:
	if not signed_in():
		return "Not signed in"
	if not await _fresh_token():
		return "Could not reach the server"
	var pulled := await pull(save, new_name == "")
	if pulled != "":
		return pulled
	if not signed_in():
		return "Not signed in"
	var scores := {}
	for id: String in save.scores:
		scores[score_key(id)] = {"integerValue": str(save.scores[id])}
	var ach := []
	for id: String in save.achievements:
		ach.append({"stringValue": id})
	var fields := {
		"name": {"stringValue": new_name if new_name != "" else player_name},
		"total": {"integerValue": str(save.total_score())},
		"stars": {"integerValue": str(save.points_total())},
		"rw": {"integerValue": str(save.stats.get("race_wins", 0))},
		"rl": {"integerValue": str(save.stats.get("race_losses", 0))},
		"scores": {"mapValue": {"fields": scores}},
		"ach": {"arrayValue": {"values": ach}},
	}
	if Prefs.get_value("full", false):
		fields["full"] = {"booleanValue": true}
	if sync_progress:
		fields.merge(progress_fields(save))
	var doc := {"name": "projects/%s/databases/(default)/documents/players/%s" % [PROJECT, uid], "fields": fields}
	var body := {"writes": [{"update": doc, "updateTransforms": [{"fieldPath": "updated", "setToServerValue": "REQUEST_TIME"}]}]}
	var r := await _call("POST", _docs + ":commit", body, true)
	return "" if r["ok"] else r["error"]


## The campaign part of the player's document, as Firestore typed fields.
static func progress_fields(save: SaveData) -> Dictionary:
	var best := {}
	for id: String in save.best:
		best[score_key(id)] = save.best[id]
	return _typed_fields({"unlocked": save.unlocked, "best": best, "skills": save.skills,
		"skills_t": save.skills_t, "reset_t": save.reset_t, "stats": save.stats})


## The campaign held in a player's document (Firestore typed fields), for SaveData.merge_online;
## {} for a document from before campaigns were kept online.
static func progress_of(f: Dictionary) -> Dictionary:
	if not f.has("unlocked"):
		return {}
	var theirs := _map(f.get("best", {}))
	var best := {}
	for k: String in theirs:
		best[mission_of_key(k)] = theirs[k]
	return {"unlocked": int(_value(f["unlocked"])), "best": best, "skills": _map(f.get("skills", {})),
		"skills_t": int(_value(f.get("skills_t", {}))), "reset_t": int(_value(f.get("reset_t", {})))}


## The top players by `field` ("total", "rw" for race wins, or "scores.<score_key>" for one mission), best first:
## [{"uid", "name", "value", "stars", "ach", "rw", "rl", "scores"}]. Returns {"error": String} on failure.
func top(field: String, limit := 50) -> Variant:
	var q := {"structuredQuery": {
		"from": [{"collectionId": "players"}],
		"orderBy": [{"field": {"fieldPath": field}, "direction": "DESCENDING"}],
		"limit": limit,
	}}
	var r := await _call("POST", _docs + ":runQuery", q)
	if not r["ok"]:
		return {"error": r["error"]}
	var rows := []
	for item in r["data"]:
		if typeof(item) != TYPE_DICTIONARY or not item.has("document"):
			continue
		var f: Dictionary = item["document"].get("fields", {})
		var sc := _map(f.get("scores", {}))
		var value: Variant = sc.get(field.get_slice(".", 1), 0) if field.begins_with("scores.") else _value(f.get(field, {}))
		var scores := {}
		for k: String in sc:
			scores[k] = int(sc[k])
		rows.append({
			"scores": scores,
			"uid": str(item["document"]["name"]).get_file(),
			"name": str(_value(f.get("name", {}))),
			"value": int(value),
			"stars": int(_value(f.get("stars", {}))),
			"ach": _list(f.get("ach", {})).size(),
			"rw": int(_value(f.get("rw", {}))),
			"rl": int(_value(f.get("rl", {}))),
		})
	return rows


# ---------------------------------------------------------------- feedback
# A player's message from the Info page: feedback/<random id> {text, version, platform, created},
# plus name and uid when signed in. Anyone may write one, nobody can read them back from the game
# (the owner reads them in the Firebase console). Limits are in firestore.rules.

const FEEDBACK_MAX := 2000   # characters in one message

## Sends a feedback message. Returns "" when it arrived, or a message for the player.
func send_feedback(text: String) -> String:
	text = text.strip_edges()
	if text == "":
		return "Write something first"
	text = text.left(FEEDBACK_MAX)
	var id := ""
	for i in 20:
		id += "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"[randi() % 62]
	var f := {"text": text, "version": str(ProjectSettings.get_setting("application/config/version", "")).left(20),
		"platform": OS.get_name().left(20)}
	if signed_in():
		f["name"] = player_name
		f["uid"] = uid
	var doc := {"name": "projects/%s/databases/(default)/documents/feedback/%s" % [PROJECT, id], "fields": _typed_fields(f)}
	var body := {"writes": [{"update": doc, "currentDocument": {"exists": false},
		"updateTransforms": [{"fieldPath": "created", "setToServerValue": "REQUEST_TIME"}]}]}
	var r := await _call("POST", _docs + ":commit", body, signed_in())
	return "" if r["ok"] else str(r["error"])


# ---------------------------------------------------------------- races
# A race is one document, races/<code>: {host, host_name, level, state, created, h} from the host,
# then {guest, guest_name, g} when a rival joins and state turns "on". h and g are each racer's
# progress ({wave, gems, kills, score, done, won, time, out}), which only that racer may write (firestore.rules).

const RACE_LETTERS := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"   # no I, L, O, 0 or 1 to misread
const RACE_CODE_LEN := 5
## Races are played by the rules of this version (the race clock, race hero health), so a race only
## pairs clients of the same one: the host stores the lair as "<level id>@<RACE_VERSION>". Clients
## from before version 2 cannot find such a lair and ask to update; this one refuses older races.
const RACE_VERSION := 2
const RACE_TIMEOUT := 6.0   # seconds a race request may take: a slow one must never hold a race up
const RACE_OLDER := "Your friend's game is an older version: ask them to update."
const RACE_NEWER := "That lair is not in this version of the game: update it"


## Opens a race on level_id (its night mission if night). quick: a Quick race, open to anyone who taps
## Quick race (races_quick). Returns {"code": String}, or {"error": String}.
func race_host(level_id: String, night := false, quick := false) -> Dictionary:
	if not signed_in():
		return {"error": "Sign in first"}
	var fields := {"host": uid, "host_name": player_name, "level": race_level_field(level_id), "night": night, "state": "open", "h": race_progress()}
	if quick:
		fields["quick"] = true
	for attempt in 4:   # a code already taken: try another
		var code := ""
		for i in RACE_CODE_LEN:
			code += RACE_LETTERS[randi() % RACE_LETTERS.length()]
		var doc := {
			"name": "projects/%s/databases/(default)/documents/races/%s" % [PROJECT, code],
			"fields": _typed_fields(fields),
		}
		var body := {"writes": [{"update": doc, "currentDocument": {"exists": false},
			"updateTransforms": [{"fieldPath": "created", "setToServerValue": "REQUEST_TIME"}]}]}
		var r := await _call("POST", _docs + ":commit", body, true, RACE_TIMEOUT)
		if r["ok"]:
			return {"code": code}
		if not str(r["error"]).contains("exists") and not str(r["error"]).contains("ALREADY"):
			return {"error": r["error"]}
	return {"error": "Could not open a race: try again"}


## The race document's "level" for a lair: its id tagged with this version's rules.
static func race_level_field(level_id: String) -> String:
	return "%s@%d" % [level_id, RACE_VERSION]


## A race document's "level" split into [level id, rules version]: 1 for an untagged one (an old host).
static func race_level(stored: String) -> Array:
	var at := stored.rfind("@")
	if at < 0:
		return [stored, 1]
	return [stored.left(at), int(stored.substr(at + 1))]


## Why this player may not join a race (as race_get returns it), or "" if they may.
static func race_refusal(race: Dictionary, me: String) -> String:
	if int(race.get("version", 1)) < RACE_VERSION:
		return RACE_OLDER
	if int(race.get("version", 1)) > RACE_VERSION:
		return RACE_NEWER
	if race.get("host", "") == me:
		return "That is your own race: give the code to your rival"
	if race.get("state", "") != "open":
		return "That race has already begun"
	return ""


## Joins the open race with this code. It reads the race first and writes only if this player may
## join it (race_refusal): never a race from another version. Returns the race (see race_get), or {"error": String}.
func race_join(code: String) -> Dictionary:
	code = code.strip_edges().to_upper()
	var race := await race_get(code)
	if race.has("error"):
		return race
	var refused := race_refusal(race, uid)
	if refused != "":
		return {"error": refused}
	var doc := {
		"name": "projects/%s/databases/(default)/documents/races/%s" % [PROJECT, code],
		"fields": _typed_fields({"guest": uid, "guest_name": player_name, "state": "on", "g": race_progress()}),
	}
	var body := {"writes": [{"update": doc, "updateMask": {"fieldPaths": ["guest", "guest_name", "state", "g"]},
		"currentDocument": {"exists": true}}]}
	var r := await _call("POST", _docs + ":commit", body, true, RACE_TIMEOUT)
	if not r["ok"]:
		return {"error": r["error"]}
	return await race_get(code)


## The race with this code: {code, host, host_name, guest, guest_name, level, version, state, h, g}, or {"error"}.
## level is the plain lair id; version the rules version it was hosted with (race_level).
func race_get(code: String) -> Dictionary:
	if code.length() != RACE_CODE_LEN:
		return {"error": "A race code has %d letters" % RACE_CODE_LEN}
	var r := await _call("GET", _docs + "/races/" + code, null, true, RACE_TIMEOUT)
	if not r["ok"]:
		return {"error": "No race with that code" if str(r["error"]).contains("NOT_FOUND") or str(r["error"]).contains("not found") else r["error"]}
	var f: Dictionary = r["data"].get("fields", {})
	var out := {"code": code, "guest": "", "guest_name": "", "g": race_progress()}
	for k: String in f:
		out[k] = _value(f[k])
	var lv := race_level(str(out.get("level", "")))
	out["level"] = lv[0]
	out["version"] = lv[1]
	return out


const QUICK_AGE := 600   # a Quick race waiting longer than this is taken for abandoned

## Quick races waiting for a rival: open, this version, hosted by someone else in the last
## QUICK_AGE seconds, oldest first (it has waited longest). [race as race_get returns it], or {"error"}.
func races_quick() -> Variant:
	var q := {"structuredQuery": {
		"from": [{"collectionId": "races"}],
		"where": {"compositeFilter": {"op": "AND", "filters": [
			{"fieldFilter": {"field": {"fieldPath": "state"}, "op": "EQUAL", "value": {"stringValue": "open"}}},
			{"fieldFilter": {"field": {"fieldPath": "quick"}, "op": "EQUAL", "value": {"booleanValue": true}}},
		]}},
		"limit": 50,
	}}
	var r := await _call("POST", _docs + ":runQuery", q, true, RACE_TIMEOUT)
	if not r["ok"]:
		return {"error": r["error"]}
	var now := int(Time.get_unix_time_from_system())
	var out := []
	for item in r["data"]:
		if typeof(item) != TYPE_DICTIONARY or not item.has("document"):
			continue
		var f: Dictionary = item["document"].get("fields", {})
		var made: String = f.get("created", {}).get("timestampValue", "")
		if made == "":
			continue
		var age := now - int(Time.get_unix_time_from_datetime_string(made.get_slice(".", 0).trim_suffix("Z")))
		if age < -30 or age > QUICK_AGE:
			continue
		var race := {"code": str(item["document"]["name"]).get_file(), "age": age}
		for k: String in f:
			if k != "created":
				race[k] = _value(f[k])
		var lv := race_level(str(race.get("level", "")))
		race["level"] = lv[0]
		race["version"] = lv[1]
		if race_refusal(race, uid) == "":
			out.append(race)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["age"] > b["age"])
	return out


const WATCH_AGE := 20 * 60   # races begun longer ago than this are not offered to watch

## Races being played right now, newest first, for spectators: [race as race_get returns it, plus
## "age" in seconds], or {"error"}. Only races both racers are still in.
func races_live() -> Variant:
	var q := {"structuredQuery": {
		"from": [{"collectionId": "races"}],
		"where": {"fieldFilter": {"field": {"fieldPath": "state"}, "op": "EQUAL", "value": {"stringValue": "on"}}},
		"limit": 100,
	}}
	var r := await _call("POST", _docs + ":runQuery", q, true, RACE_TIMEOUT)
	if not r["ok"]:
		return {"error": r["error"]}
	var now := int(Time.get_unix_time_from_system())
	var out := []
	for item in r["data"]:
		if typeof(item) != TYPE_DICTIONARY or not item.has("document"):
			continue
		var f: Dictionary = item["document"].get("fields", {})
		var made: String = f.get("created", {}).get("timestampValue", "")
		if made == "":
			continue
		var age := now - int(Time.get_unix_time_from_datetime_string(made.get_slice(".", 0).trim_suffix("Z")))
		if age < 0 or age > WATCH_AGE:
			continue
		var race := {"code": str(item["document"]["name"]).get_file(), "guest_name": "", "g": race_progress(), "age": age}
		for k: String in f:
			if k != "created":
				race[k] = _value(f[k])
		if race["h"].get("done", false) or race["g"].get("done", false):
			continue
		var lv := race_level(str(race.get("level", "")))
		race["level"] = lv[0]
		race["version"] = lv[1]
		out.append(race)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["age"] < b["age"])
	return out


## Reports this racer's progress: side is "h" (host) or "g" (guest).
func race_report(code: String, side: String, progress: Dictionary) -> String:
	var doc := {
		"name": "projects/%s/databases/(default)/documents/races/%s" % [PROJECT, code],
		"fields": _typed_fields({side: progress}),
	}
	var body := {"writes": [{"update": doc, "updateMask": {"fieldPaths": [side]}, "currentDocument": {"exists": true}}]}
	var r := await _call("POST", _docs + ":commit", body, true, RACE_TIMEOUT)
	return "" if r["ok"] else r["error"]


## The host calls off a race nobody joined.
func race_cancel(code: String) -> void:
	await _call("DELETE", _docs + "/races/" + code, null, true, RACE_TIMEOUT)


# ---------------------------------------------------------------- challenges
# A challenge is a race booked for a time: challenges/<id> {from, from_name, to, to_name, level
# (race_level_field), night, at (unix seconds), by (who proposed the current time), state, created},
# plus code (the race the challenger opened at that time). state: "sent" (waiting for the one who
# did not propose `at` to answer), "accepted", "declined" or "cancelled". Either player may propose
# another time (at, by = themself, state back to "sent"). Only the two players can read or change it.
# No server sends anything: each game looks for its challenges (challenges()).

const CHALLENGE_EARLY := 10 * 60    # Ready opens this many seconds before the agreed time
const CHALLENGE_LATE := 30 * 60     # and stays open this long after it
const CHALLENGE_KEEP := 24 * 3600   # a challenge whose time passed this long ago is cleared away

## Sends a challenge to player `to` for a race on `level_id` at unix time `at`. "" when sent.
func challenge_send(to: String, to_name: String, level_id: String, night: bool, at: int) -> String:
	var r := await challenge_create(to, to_name, level_id, night, at)
	return str(r.get("error", ""))


## As challenge_send, but returns {"id"} of the new challenge, or {"error"}.
func challenge_create(to: String, to_name: String, level_id: String, night: bool, at: int) -> Dictionary:
	if not signed_in():
		return {"error": "Sign in first"}
	if to == uid:
		return {"error": "You can't challenge yourself"}
	var id := ""
	for i in 20:
		id += "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"[randi() % 62]
	var f := {"from": uid, "from_name": player_name, "to": to, "to_name": to_name.left(16), "level": race_level_field(level_id),
		"night": night, "at": at, "by": uid, "state": "sent"}
	var doc := {"name": "projects/%s/databases/(default)/documents/challenges/%s" % [PROJECT, id], "fields": _typed_fields(f)}
	var body := {"writes": [{"update": doc, "currentDocument": {"exists": false},
		"updateTransforms": [{"fieldPath": "created", "setToServerValue": "REQUEST_TIME"}]}]}
	var r := await _call("POST", _docs + ":commit", body, true)
	return {"id": id} if r["ok"] else {"error": str(r["error"])}


## This player's challenges, sent and received, soonest first: [{id, from, from_name, to, to_name,
## level, version, night, at, by, state, code, mine (true if this player sent it)}], or {"error"}.
## Ones whose time is long past are deleted on the way.
func challenges() -> Variant:
	if not signed_in():
		return []
	var out := []
	var now := int(Time.get_unix_time_from_system())
	for side: String in ["to", "from"]:
		var q := {"structuredQuery": {
			"from": [{"collectionId": "challenges"}],
			"where": {"fieldFilter": {"field": {"fieldPath": side}, "op": "EQUAL", "value": {"stringValue": uid}}},
			"limit": 50,
		}}
		var r := await _call("POST", _docs + ":runQuery", q, true)
		if not r["ok"]:
			return {"error": r["error"]}
		for item in r["data"]:
			if typeof(item) != TYPE_DICTIONARY or not item.has("document"):
				continue
			var c := {"id": str(item["document"]["name"]).get_file(), "code": ""}
			var f: Dictionary = item["document"].get("fields", {})
			for k: String in f:
				c[k] = _value(f[k])
			c["at"] = int(c.get("at", 0))
			var lv := race_level(str(c.get("level", "")))
			c["level"] = lv[0]
			c["version"] = lv[1]
			c["mine"] = c.get("from") == uid
			if now - int(c["at"]) > CHALLENGE_KEEP:
				challenge_delete(c["id"])
				continue
			out.append(c)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"] < b["at"])
	return out


## Changes a challenge: {"state": ...}, {"at": ..., "by": uid, "state": "sent"} or {"code": ...}. "" when done.
func challenge_update(id: String, fields: Dictionary) -> String:
	var doc := {"name": "projects/%s/databases/(default)/documents/challenges/%s" % [PROJECT, id], "fields": _typed_fields(fields)}
	var body := {"writes": [{"update": doc, "updateMask": {"fieldPaths": fields.keys()}, "currentDocument": {"exists": true}}]}
	var r := await _call("POST", _docs + ":commit", body, true)
	return "" if r["ok"] else str(r["error"])


func challenge_delete(id: String) -> void:
	await _call("DELETE", _docs + "/challenges/" + id, null, true)


## One challenge (as challenges() lists them), or {"error"}.
func challenge_get(id: String) -> Dictionary:
	var r := await _call("GET", _docs + "/challenges/" + id, null, true, RACE_TIMEOUT)
	if not r["ok"]:
		return {"error": r["error"]}
	var c := {"id": id, "code": ""}
	var f: Dictionary = r["data"].get("fields", {})
	for k: String in f:
		c[k] = _value(f[k])
	c["at"] = int(c.get("at", 0))
	var lv := race_level(str(c.get("level", "")))
	c["level"] = lv[0]
	c["version"] = lv[1]
	c["mine"] = c.get("from") == uid
	return c


## Where an accepted challenge stands at unix time `now`: "soon" (before Ready opens), "now"
## (Ready is open) or "missed".
static func challenge_when(c: Dictionary, now: int) -> String:
	var at := int(c["at"])
	if now < at - CHALLENGE_EARLY:
		return "soon"
	if now <= at + CHALLENGE_LATE:
		return "now"
	return "missed"


# ---------------------------------------------------------------- who is online
# presence/<uid> {name, where ("map", "battle" or "race"), seen (server time)}: each signed-in game
# rewrites its own every PRESENCE_BEAT seconds (and when `where` changes). Nothing removes it when a
# game closes: a player last seen more than ONLINE_WINDOW seconds ago simply no longer counts.

const PRESENCE_BEAT := 60.0
const ONLINE_WINDOW := 150

## Tells others this player is online and where: "map", "battle" or "race". "" when done.
func presence_beat(where: String) -> String:
	if not signed_in():
		return "Sign in first"
	var doc := {"name": "projects/%s/databases/(default)/documents/presence/%s" % [PROJECT, uid],
		"fields": _typed_fields({"name": player_name, "where": where})}
	var body := {"writes": [{"update": doc, "updateTransforms": [{"fieldPath": "seen", "setToServerValue": "REQUEST_TIME"}]}]}
	var r := await _call("POST", _docs + ":commit", body, true, RACE_TIMEOUT)
	return "" if r["ok"] else str(r["error"])


func presence_leave() -> void:
	if signed_in():
		await _call("DELETE", _docs + "/presence/" + uid, null, true, RACE_TIMEOUT)


## Other players online right now, most recently seen first: [{uid, name, where, age}], or {"error"}.
func online_now() -> Variant:
	if not signed_in():
		return []
	var now := int(Time.get_unix_time_from_system())
	var since := Time.get_datetime_string_from_unix_time(now - ONLINE_WINDOW) + "Z"
	var q := {"structuredQuery": {
		"from": [{"collectionId": "presence"}],
		"where": {"fieldFilter": {"field": {"fieldPath": "seen"}, "op": "GREATER_THAN", "value": {"timestampValue": since}}},
		"orderBy": [{"field": {"fieldPath": "seen"}, "direction": "DESCENDING"}],
		"limit": 50,
	}}
	var r := await _call("POST", _docs + ":runQuery", q, true, RACE_TIMEOUT)
	if not r["ok"]:
		return {"error": r["error"]}
	var out := []
	for item in r["data"]:
		if typeof(item) != TYPE_DICTIONARY or not item.has("document"):
			continue
		var id := str(item["document"]["name"]).get_file()
		if id == uid:
			continue
		var f: Dictionary = item["document"].get("fields", {})
		var seen: String = f.get("seen", {}).get("timestampValue", "")
		var age := now - int(Time.get_unix_time_from_datetime_string(seen.get_slice(".", 0).trim_suffix("Z"))) if seen != "" else 0
		out.append({"uid": id, "name": str(_value(f.get("name", {}))), "where": str(_value(f.get("where", {}))), "age": maxi(0, age)})
	return out


## A racer's progress record; with no sim, the one for a battle not begun. secs: seconds since the
## race began (frozen at the finish); out: the heroes sent to the rival so far (GameSim.race_sends).
static func race_progress(sim: GameSim = null, done := false, secs := 0) -> Dictionary:
	if sim == null:
		return {"wave": 0, "gems": 0, "kills": 0, "score": 0, "done": false, "won": false, "stopped": false, "time": 0, "out": ""}
	return {"wave": sim.wave, "gems": sim.gems_left(), "kills": sim.kills, "score": sim.score(1) if sim.won else 0,
		"done": done or sim.over, "won": sim.won, "stopped": sim.stopped, "time": secs, "out": sim.race_sends}


## Race points of a finished survivor: the score, plus Defs.RACE_TIME_BONUS for every second they
## finished before the rival (who may have fallen, or not be done yet: then there is no bonus).
static func race_points(me: Dictionary, rival: Dictionary) -> int:
	var pts := int(me.get("score", 0))
	if rival.get("done", false) and rival.get("won", false):
		pts += Defs.RACE_TIME_BONUS * maxi(0, int(rival.get("time", 0)) - int(me.get("time", 0)))
	return pts


## Who won between two finished racers' progress: 1 if a, -1 if b, 0 for a draw. The race ends for
## both as soon as one finishes or falls, so: surviving beats everything; one left standing when
## the rival fell (stopped) beats the fallen; two who survived almost together (each finished
## before hearing of the other) go by race points (score plus the time bonus), then gems and kills;
## otherwise more waves, then more kills.
static func race_compare(a: Dictionary, b: Dictionary) -> int:
	if a.get("won", false) != b.get("won", false):
		return 1 if a.get("won", false) else -1
	if not a.get("won", false) and a.get("stopped", false) != b.get("stopped", false):
		return 1 if a.get("stopped", false) else -1
	var pa := [race_points(a, b), int(a.get("gems", 0)), int(a.get("kills", 0))] if a.get("won", false) else [int(a.get("wave", 0)), int(a.get("kills", 0))]
	var pb := [race_points(b, a), int(b.get("gems", 0)), int(b.get("kills", 0))] if a.get("won", false) else [int(b.get("wave", 0)), int(b.get("kills", 0))]
	for i in pa.size():
		if pa[i] != pb[i]:
			return 1 if pa[i] > pb[i] else -1
	return 0


## Plain values as Firestore typed fields (strings, ints, floats, bools and nested dictionaries).
static func _typed_fields(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = _typed(d[k])
	return out


static func _typed(v: Variant) -> Dictionary:
	match typeof(v):
		TYPE_BOOL:
			return {"booleanValue": v}
		TYPE_INT:
			return {"integerValue": str(v)}
		TYPE_FLOAT:
			return {"doubleValue": v}
		TYPE_DICTIONARY:
			return {"mapValue": {"fields": _typed_fields(v)}}
	return {"stringValue": str(v)}


# ---------------------------------------------------------------- plumbing

func _take_tokens(d: Dictionary) -> void:
	uid = str(d.get("localId", d.get("user_id", uid)))
	_token = str(d.get("idToken", d.get("id_token", "")))
	_refresh = str(d.get("refreshToken", d.get("refresh_token", _refresh)))
	_token_until = Time.get_unix_time_from_system() + float(d.get("expiresIn", d.get("expires_in", "3600"))) - 60.0


## An id token lasts an hour; trade the stored refresh token for a new one when it has run out.
## wait: seconds the request may take.
func _fresh_token(wait := 15.0) -> bool:
	if _token != "" and Time.get_unix_time_from_system() < _token_until:
		return true
	var http := HTTPRequest.new()
	http.timeout = wait
	http.accept_gzip = false   # on web the browser has already unpacked the reply; Godot would fail unpacking it again
	add_child(http)
	http.request(_token_url + "?key=" + API_KEY,
		PackedStringArray(["Content-Type: application/x-www-form-urlencoded"]), HTTPClient.METHOD_POST,
		"grant_type=refresh_token&refresh_token=" + _refresh.uri_encode())
	var res: Array = await http.request_completed
	http.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		if res[1] == 400:
			sign_out()   # the account was deleted or its password changed elsewhere
		return false
	var d = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if typeof(d) != TYPE_DICTIONARY:
		return false
	_take_tokens(d)
	_store()
	return true


## One JSON request, never blocking a frame (HTTPRequest works in the background). Returns
## {"ok": bool, "data": parsed body, "error": friendly message}. wait: seconds before it gives up
## (the token refresh it may need included), after which it fails like an unreachable server.
func _call(method: String, url: String, body: Variant, auth := false, wait := 15.0) -> Dictionary:
	var headers := PackedStringArray(["Content-Type: application/json"])
	if auth:
		var t0 := Time.get_ticks_msec()
		if not await _fresh_token(wait):
			return {"ok": false, "data": {}, "error": "Signed out: please sign in again"}
		wait = maxf(1.0, wait - (Time.get_ticks_msec() - t0) / 1000.0)
		headers.append("Authorization: Bearer " + _token)
	var http := HTTPRequest.new()
	http.timeout = wait
	http.accept_gzip = false   # see _fresh_token
	add_child(http)
	var m := {"GET": HTTPClient.METHOD_GET, "POST": HTTPClient.METHOD_POST, "DELETE": HTTPClient.METHOD_DELETE}
	var err := http.request(url, headers, m[method], "" if body == null else JSON.stringify(body))
	if err != OK:
		http.queue_free()
		return {"ok": false, "data": {}, "error": "Could not reach the server"}
	var res: Array = await http.request_completed
	http.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "data": {}, "error": "Could not reach the server. Are you online?"}
	var data = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if data == null:
		data = {}
	if res[1] >= 200 and res[1] < 300:
		return {"ok": true, "data": data, "error": ""}
	var msg := ""
	if typeof(data) == TYPE_DICTIONARY and data.has("error"):
		msg = str(data["error"].get("message", "")) if typeof(data["error"]) == TYPE_DICTIONARY else str(data["error"])
	elif typeof(data) == TYPE_ARRAY and not data.is_empty() and typeof(data[0]) == TYPE_DICTIONARY and data[0].has("error"):
		msg = str(data[0]["error"].get("message", ""))
	return {"ok": false, "data": data, "error": friendly(msg, res[1]), "code": res[1]}


## Firebase error codes in words a player understands.
static func friendly(msg: String, code := 0) -> String:
	var key := msg.get_slice(" ", 0)
	match key:
		"EMAIL_EXISTS":
			return "That email already has an account: sign in instead"
		"INVALID_EMAIL", "MISSING_EMAIL":
			return "That doesn't look like an email address"
		"WEAK_PASSWORD", "MISSING_PASSWORD":
			return "Password must be at least 6 characters"
		"INVALID_LOGIN_CREDENTIALS", "INVALID_PASSWORD", "EMAIL_NOT_FOUND":
			return "Wrong email or password"
		"USER_DISABLED":
			return "This account has been disabled"
		"TOO_MANY_ATTEMPTS_TRY_LATER":
			return "Too many tries: wait a little and try again"
		"OPERATION_NOT_ALLOWED", "CONFIGURATION_NOT_FOUND":
			return "Accounts aren't switched on yet"
		"CREDENTIAL_TOO_OLD_LOGIN_AGAIN":
			return SIGN_IN_AGAIN
	if code == 403 or code == 401:
		return "Not allowed: try signing in again"
	return msg if msg != "" else "Something went wrong (%d)" % code


static func _map(v: Dictionary) -> Dictionary:
	var x: Variant = _value(v)
	return x if typeof(x) == TYPE_DICTIONARY else {}


static func _list(v: Dictionary) -> Array:
	var x: Variant = _value(v)
	return x if typeof(x) == TYPE_ARRAY else []


## A Firestore typed value as a plain one.
static func _value(v: Dictionary) -> Variant:
	if v.has("stringValue"):
		return v["stringValue"]
	if v.has("integerValue"):
		return int(v["integerValue"])
	if v.has("doubleValue"):
		return float(v["doubleValue"])
	if v.has("booleanValue"):
		return v["booleanValue"]
	if v.has("arrayValue"):
		var out := []
		for x: Dictionary in v["arrayValue"].get("values", []):
			out.append(_value(x))
		return out
	if v.has("mapValue"):
		var out := {}
		var f: Dictionary = v["mapValue"].get("fields", {})
		for k in f:
			out[k] = _value(f[k])
		return out
	return ""


func _store() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("account", "uid", uid)
	cfg.set_value("account", "name", player_name)
	cfg.set_value("account", "email", email)
	cfg.set_value("account", "refresh", _refresh)
	cfg.set_value("account", "owner", _owner)
	cfg.save(path)

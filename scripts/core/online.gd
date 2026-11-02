class_name Online
extends Node
## The optional online account: Firebase email/password sign-in and the leaderboard in Firestore,
## both over their REST APIs so it works the same on every platform, the web included.
## A signed-in player has one document, players/<uid>: {name, total, stars, scores, ach, updated}
## (rules in firestore.rules). Anyone may read the leaderboard; only signed-in players appear on it.
## Calls are coroutines: `var err := await online.sign_in(...)`, "" on success.

signal changed   # signed in or out

const API_KEY := "AIzaSyAdWN9fBo3FQ0xfY6Z_YHnuAb9VSG5G42E"   # public web key; Firestore rules guard the data
const PROJECT := "gemhold"
const PATH := "user://account.cfg"
const AUTH_HOST := "https://identitytoolkit.googleapis.com"
const TOKEN_HOST := "https://securetoken.googleapis.com"
const DOCS_HOST := "https://firestore.googleapis.com"

const NAME_MIN := 2
const NAME_MAX := 16

var uid := ""
var player_name := ""
var email := ""
var path := PATH        # tests point this elsewhere
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
	email = mail.strip_edges()
	var me := await _call("GET", _docs + "/players/" + uid, null, true)
	if me["ok"]:
		var f: Dictionary = me["data"].get("fields", {})
		player_name = _value(f.get("name", {}))
		var ach := _list(f.get("ach", {}))
		var sc := _map(f.get("scores", {}))
		var scores := {}
		for k: String in sc:
			scores[k.replace("_night", ":night")] = sc[k]
		save.merge_online(scores, ach)
		save.save()
	if player_name == "":
		player_name = email.get_slice("@", 0).left(NAME_MAX)
	_store()
	changed.emit()
	sync(save)
	return ""


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
	if not await _fresh_token():
		return "Could not reach the server"
	var r := await _call("DELETE", _docs + "/players/" + uid, null, true)
	if not r["ok"]:
		return r["error"]
	r = await _call("POST", _auth + "delete?key=" + API_KEY, {"idToken": _token})
	if not r["ok"]:
		return r["error"]
	sign_out()
	return ""


func rename(name: String, save: SaveData) -> String:
	var bad := check_name(name)
	if bad != "":
		return bad
	var old := player_name
	player_name = name.strip_edges()
	var err := await upload(save)
	if err != "":
		player_name = old
		return err
	_store()
	changed.emit()
	return ""


# ---------------------------------------------------------------- leaderboard

## Puts the player's scores, stars and achievements on the leaderboard (does nothing when signed out).
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


func upload(save: SaveData) -> String:
	if not signed_in():
		return "Not signed in"
	if not await _fresh_token():
		return "Could not reach the server"
	var scores := {}
	for id: String in save.scores:
		scores[score_key(id)] = {"integerValue": str(save.scores[id])}
	var ach := []
	for id: String in save.achievements:
		ach.append({"stringValue": id})
	var doc := {
		"name": "projects/%s/databases/(default)/documents/players/%s" % [PROJECT, uid],
		"fields": {
			"name": {"stringValue": player_name},
			"total": {"integerValue": str(save.total_score())},
			"stars": {"integerValue": str(save.points_total())},
			"scores": {"mapValue": {"fields": scores}},
			"ach": {"arrayValue": {"values": ach}},
		},
	}
	var body := {"writes": [{"update": doc, "updateTransforms": [{"fieldPath": "updated", "setToServerValue": "REQUEST_TIME"}]}]}
	var r := await _call("POST", _docs + ":commit", body, true)
	return "" if r["ok"] else r["error"]


## The top players by `field` ("total", or "scores.<score_key>" for one mission), best first:
## [{"uid", "name", "value", "stars", "ach"}]. Returns {"error": String} on failure.
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
		var value: Variant = _value(f.get("total", {})) if field == "total" else _map(f.get("scores", {})).get(field.get_slice(".", 1), 0)
		rows.append({
			"uid": str(item["document"]["name"]).get_file(),
			"name": str(_value(f.get("name", {}))),
			"value": int(value),
			"stars": int(_value(f.get("stars", {}))),
			"ach": _list(f.get("ach", {})).size(),
		})
	return rows


# ---------------------------------------------------------------- plumbing

func _take_tokens(d: Dictionary) -> void:
	uid = str(d.get("localId", d.get("user_id", uid)))
	_token = str(d.get("idToken", d.get("id_token", "")))
	_refresh = str(d.get("refreshToken", d.get("refresh_token", _refresh)))
	_token_until = Time.get_unix_time_from_system() + float(d.get("expiresIn", d.get("expires_in", "3600"))) - 60.0


## An id token lasts an hour; trade the stored refresh token for a new one when it has run out.
func _fresh_token() -> bool:
	if _token != "" and Time.get_unix_time_from_system() < _token_until:
		return true
	var http := HTTPRequest.new()
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


## One JSON request. Returns {"ok": bool, "data": parsed body, "error": friendly message}.
func _call(method: String, url: String, body: Variant, auth := false) -> Dictionary:
	var headers := PackedStringArray(["Content-Type: application/json"])
	if auth:
		if not await _fresh_token():
			return {"ok": false, "data": {}, "error": "Signed out: please sign in again"}
		headers.append("Authorization: Bearer " + _token)
	var http := HTTPRequest.new()
	http.timeout = 15.0
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
	return {"ok": false, "data": data, "error": friendly(msg, res[1])}


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
	cfg.save(path)

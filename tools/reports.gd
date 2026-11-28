extends SceneTree
## Downloads the battle reports players sent (Firestore reports/, see BattleReport) and prints a balance
## summary per lair. Uses the Firebase CLI's login on this computer (run tools/firebase/firebase.exe login
## once); the token is never printed. Reports are kept in ../reports/reports.json beside the project, so
## later runs only add new ones.
##   godot --headless --path . -s res://tools/reports.gd                    # download, then sum every lair
##   godot --headless --path . -s res://tools/reports.gd -- --local         # sum what is saved, no download
##   godot --headless --path . -s res://tools/reports.gd -- level_20        # one lair (its file id)
##   godot --headless --path . -s res://tools/reports.gd -- --version 0.9.14   # only that game version

const DOCS := "https://firestore.googleapis.com/v1/projects/gemhold/databases/(default)/documents/reports"
# The Firebase CLI's public OAuth client (the same values ship inside firebase-tools).
const CLIENT_ID := "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com"
const CLIENT_SECRET := "j9iVZfS8kkCEFUPaAeJV0sAi"

var _http: HTTPRequest


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	var args := OS.get_cmdline_user_args()
	var store := ProjectSettings.globalize_path("res://").path_join("../reports").simplify_path()
	DirAccess.make_dir_recursive_absolute(store)
	var file := store.path_join("reports.json")
	var all := {}   # document id -> report row
	if FileAccess.file_exists(file):
		var was = JSON.parse_string(FileAccess.get_file_as_string(file))
		if was is Dictionary:
			all = was
	if not args.has("--local"):
		_http = HTTPRequest.new()
		root.add_child(_http)
		var token := await _token()
		if token == "":
			quit(1)
			return
		var added := await _download(token, all)
		var fa := FileAccess.open(file, FileAccess.WRITE)
		fa.store_string(JSON.stringify(all))
		fa.close()
		print("%d new reports, %d in all (%s)\n" % [added, all.size(), file])
	var only := ""
	var version := ""
	var k := 0
	while k < args.size():
		if args[k] == "--version" and k + 1 < args.size():
			version = args[k + 1]
			k += 1
		elif args[k].begins_with("level_"):
			only = args[k]
		k += 1
	_summary(all.values(), only, version)
	quit()


## An access token from the Firebase CLI's saved login.
func _token() -> String:
	var path := OS.get_environment("USERPROFILE").path_join(".config/configstore/firebase-tools.json")
	var cfg = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not (cfg is Dictionary) or not cfg.has("tokens") or not cfg["tokens"].has("refresh_token"):
		printerr("No Firebase login on this computer: run tools/firebase/firebase.exe login")
		return ""
	var body := "grant_type=refresh_token&client_id=%s&client_secret=%s&refresh_token=%s" % [
		CLIENT_ID, CLIENT_SECRET, str(cfg["tokens"]["refresh_token"]).uri_encode()]
	_http.request("https://oauth2.googleapis.com/token", ["Content-Type: application/x-www-form-urlencoded"], HTTPClient.METHOD_POST, body)
	var r: Array = await _http.request_completed
	var d = JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())
	if r[1] != 200 or not (d is Dictionary) or not d.has("access_token"):
		printerr("Could not get a token (HTTP %d): run tools/firebase/firebase.exe login again" % r[1])
		return ""
	return d["access_token"]


## Pages through reports/ and adds the ones not saved yet. Returns how many were new.
func _download(token: String, all: Dictionary) -> int:
	var added := 0
	var page := ""
	while true:
		var url := DOCS + "?pageSize=300" + ("&pageToken=" + page.uri_encode() if page != "" else "")
		_http.request(url, ["Authorization: Bearer " + token])
		var r: Array = await _http.request_completed
		var d = JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())
		if r[1] != 200 or not (d is Dictionary):
			printerr("Download failed (HTTP %d)" % r[1])
			break
		for doc: Dictionary in d.get("documents", []):
			var id := str(doc["name"]).get_file()
			if all.has(id):
				continue
			var f: Dictionary = doc.get("fields", {})
			var rep = JSON.parse_string(str(f.get("data", {}).get("stringValue", "")))
			if not (rep is Dictionary):
				continue
			rep["_version"] = str(f.get("version", {}).get("stringValue", ""))
			rep["_platform"] = str(f.get("platform", {}).get("stringValue", ""))
			rep["_player"] = str(f.get("player", {}).get("stringValue", ""))
			rep["_created"] = str(f.get("created", {}).get("timestampValue", ""))
			all[id] = rep
			added += 1
		page = str(d.get("nextPageToken", ""))
		if page == "":
			break
	return added


func _summary(rows: Array, only: String, version: String) -> void:
	var by := {}   # "lair|night" -> reports
	for r: Dictionary in rows:
		if (only != "" and r.get("lair", "") != only) or (version != "" and r.get("_version", "") != version):
			continue
		var key := "%03d|%s|%s" % [int(r.get("n", 0)), "night" if r.get("night", false) else "day", r.get("title", r.get("lair", "?"))]
		if not by.has(key):
			by[key] = []
		by[key].append(r)
	if by.is_empty():
		print("No reports match.")
		return
	var keys := by.keys()
	keys.sort()
	for key: String in keys:
		var list: Array = by[key]
		var parts := key.split("|")
		var ends := _count(list, func(r: Dictionary) -> String: return r.get("end", "?"))
		var ranks := _count(list.filter(func(r: Dictionary) -> bool: return r.get("end", "") == "won"), func(r: Dictionary) -> String: return r.get("rank", "?"))
		var players := _count(list, func(r: Dictionary) -> String: return r.get("_player", "?")).size()
		print("== %d %s (%s): %d battles, %d players" % [int(parts[0]), parts[2], parts[1], list.size(), players])
		print("   ends: %s   wins: %s" % [_fmt(ends), _fmt(ranks)])
		var left := list.filter(func(r: Dictionary) -> bool: return r.get("end", "") in ["quit", "restart", "lost"])
		if not left.is_empty():
			print("   lost / quit / restarted on wave: %s" % _fmt(_count(left, func(r: Dictionary) -> String: return str(int(r.get("wave", 0)))), true))
		# Brilliant lost: the first hand laid on a gem in each battle.
		var first := []
		var escapes := []
		for r: Dictionary in list:
			var ev: Array = r.get("gem_events", [])
			for e: Dictionary in ev:
				if e.get("ev", "") in ["grab", "pick"]:
					first.append(e)
					break
			for e: Dictionary in ev:
				if e.get("ev", "") == "escape":
					escapes.append(e)
		if not first.is_empty():
			print("   Brilliant lost on wave: %s" % _fmt(_count(first, func(e: Dictionary) -> String: return str(int(e["w"]))), true))
			print("      by hero: %s   road: %s" % [_fmt(_count(first, func(e: Dictionary) -> String: return _hero(e))), _fmt(_count(first, func(e: Dictionary) -> String: return str(int(e["road"]))))])
		if not escapes.is_empty():
			print("   gems escaped on wave: %s" % _fmt(_count(escapes, func(e: Dictionary) -> String: return str(int(e["w"]))), true))
			print("      by hero: %s   road: %s" % [_fmt(_count(escapes, func(e: Dictionary) -> String: return _hero(e))), _fmt(_count(escapes, func(e: Dictionary) -> String: return str(int(e["road"]))))])
		print("   at the end, on average: Resolve x%.2f, gold %d, potions left %.1f, meteors %.1f, towers %.1f" % [
			_avg(list, "res"), roundi(_avg(list, "gold")), _avg(list, "potions_left"), _avg(list, "meteors"),
			_avg_f(list, func(r: Dictionary) -> float: return float((r.get("towers", []) as Array).size()))])
		var sites := []
		for r: Dictionary in list:
			sites.append_array(r.get("sites", []))
		if not sites.is_empty():
			print("   buildings taken: %s" % _fmt(_count(sites, func(s: Dictionary) -> String: return s.get("kind", "?"))))
		print("")


static func _hero(e: Dictionary) -> String:
	var code := str(e.get("hero", "?"))
	var name := str(Defs.ENEMIES.get(code, {}).get("name", code))
	return name + (" (barracks)" if int(e.get("of", 1)) == 0 else "")


static func _count(list: Array, key: Callable) -> Dictionary:
	var out := {}
	for x in list:
		var k: String = key.call(x)
		out[k] = int(out.get(k, 0)) + 1
	return out


## "a 3, b 2" from most to least, or in key order (waves) when by_key.
static func _fmt(d: Dictionary, by_key := false) -> String:
	var ks := d.keys()
	if by_key:
		ks.sort_custom(func(a: String, b: String) -> bool: return int(a) < int(b))
	else:
		ks.sort_custom(func(a: String, b: String) -> bool: return d[a] > d[b])
	return ", ".join(ks.map(func(k: String) -> String: return "%s %d" % [k, d[k]]))


static func _avg(list: Array, key: String) -> float:
	return _avg_f(list, func(r: Dictionary) -> float: return float(r.get(key, 0)))


static func _avg_f(list: Array, f: Callable) -> float:
	var t := 0.0
	for r in list:
		t += f.call(r)
	return t / maxf(1.0, list.size())

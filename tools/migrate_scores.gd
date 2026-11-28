extends SceneTree
## One-time conversion of the online leaderboard to the score scale of 2026-11-28: every player's
## mission scores divided by Defs.SCORE_SCALE (Long Night values kept), total recomputed, score_v set.
## Uses the Firebase CLI's login on this computer (owner access, past the security rules).
## Always saves a full backup of players/ first, to ../reports/players_backup_<time>.json.
##   godot --headless --path . -s res://tools/migrate_scores.gd               # dry run: backup + before/after
##   godot --headless --path . -s res://tools/migrate_scores.gd -- --write    # also writes the converted records
## A record whose updateTime changed since it was read (the player synced meanwhile) is skipped and listed;
## run again to pick it up. Records already on the new scale (score_v >= 2) are left alone.

const DOCS := "https://firestore.googleapis.com/v1/projects/gemhold/databases/(default)/documents"
const CLIENT_ID := "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com"
const CLIENT_SECRET := "j9iVZfS8kkCEFUPaAeJV0sAi"

var _http: HTTPRequest
var _token := ""


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	_http = HTTPRequest.new()
	root.add_child(_http)
	var write := OS.get_cmdline_user_args().has("--write")
	_token = await _get_token()
	if _token == "":
		quit(1)
		return
	var docs := await _all_players()
	if docs.is_empty():
		printerr("No players read")
		quit(1)
		return
	var store := ProjectSettings.globalize_path("res://").path_join("../reports").simplify_path()
	DirAccess.make_dir_recursive_absolute(store)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var backup := store.path_join("players_backup_%s.json" % stamp)
	var fa := FileAccess.open(backup, FileAccess.WRITE)
	fa.store_string(JSON.stringify(docs, "\t"))
	fa.close()
	print("Backup of %d records: %s\n" % [docs.size(), backup])
	var rows := []
	for d: Dictionary in docs:
		var f: Dictionary = d.get("fields", {})
		var name := str(f.get("name", {}).get("stringValue", "?"))
		var v := int(f.get("score_v", {}).get("integerValue", "1"))
		var old_total := int(f.get("total", {}).get("integerValue", "0"))
		if v >= Defs.SCORE_V:
			rows.append({"doc": d, "name": name, "old": old_total, "new": old_total, "skip": true})
			continue
		var sc: Dictionary = f.get("scores", {}).get("mapValue", {}).get("fields", {})
		var out := {}
		var total := 0
		for k: String in sc:
			var val := int(sc[k].get("integerValue", "0"))
			if not k.ends_with("_long") and val > 0:
				val = maxi(1, roundi(float(val) / Defs.SCORE_SCALE))
			if not k.ends_with("_long"):
				total += val
			out[k] = {"integerValue": str(val)}
		rows.append({"doc": d, "name": name, "old": old_total, "new": total, "scores": out, "skip": false})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["old"] > b["old"])
	print("%-18s %14s %10s" % ["player", "total before", "after"])
	for r: Dictionary in rows.slice(0, 15):
		print("%-18s %14d %10d%s" % [r["name"], r["old"], r["new"], "  (already converted)" if r["skip"] else ""])
	var todo := rows.filter(func(r: Dictionary) -> bool: return not r["skip"])
	print("\n%d records to convert, %d already on the new scale." % [todo.size(), rows.size() - todo.size()])
	if not write:
		print("Dry run: nothing written. Add -- --write to convert.")
		quit()
		return
	var done := 0
	var missed := []
	for r: Dictionary in todo:
		var d: Dictionary = r["doc"]
		var url := "https://firestore.googleapis.com/v1/" + str(d["name"]) + "?updateMask.fieldPaths=scores&updateMask.fieldPaths=total&updateMask.fieldPaths=score_v&currentDocument.updateTime=" + str(d["updateTime"]).uri_encode()
		var body := {"fields": {"scores": {"mapValue": {"fields": r["scores"]}}, "total": {"integerValue": str(r["new"])}, "score_v": {"integerValue": str(Defs.SCORE_V)}}}
		_http.request(url, ["Authorization: Bearer " + _token, "Content-Type: application/json"], HTTPClient.METHOD_PATCH, JSON.stringify(body))
		var res: Array = await _http.request_completed
		if res[1] == 200:
			done += 1
		else:
			missed.append("%s (HTTP %d)" % [r["name"], res[1]])
	print("Converted %d records." % done)
	if not missed.is_empty():
		print("Not converted (changed meanwhile or refused), run again: " + ", ".join(missed))
	quit(0 if missed.is_empty() else 1)


func _all_players() -> Array:
	var out := []
	var page := ""
	while true:
		var url := DOCS + "/players?pageSize=300" + ("&pageToken=" + page.uri_encode() if page != "" else "")
		_http.request(url, ["Authorization: Bearer " + _token])
		var r: Array = await _http.request_completed
		var d = JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())
		if r[1] != 200 or not (d is Dictionary):
			printerr("Reading players failed (HTTP %d)" % r[1])
			return []
		out.append_array(d.get("documents", []))
		page = str(d.get("nextPageToken", ""))
		if page == "":
			break
	return out


func _get_token() -> String:
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
		printerr("Could not get a token (HTTP %d)" % r[1])
		return ""
	return d["access_token"]

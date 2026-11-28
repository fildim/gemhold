extends SceneTree
## Uploads a signed AAB to Google Play and releases it on a track (Alpha by default), through the Play
## Developer API with the play-publisher service account. Its key file lives outside the project:
## Desktop\Gemhold\Play key\play-publisher.json (or set PLAY_KEY). Never commit it.
##   godot --headless --path . -s res://tools/play_upload.gd -- --check
##       only checks access: signs in, opens an edit, lists the tracks, throws the edit away
##   godot --headless --path . -s res://tools/play_upload.gd -- build/gemhold-1.0.0.aab --notes notes.txt [--track alpha] [--draft]
##       uploads the bundle, makes it the track's release (full rollout, or a draft with --draft) with the
##       notes (en-US), and commits. With managed publishing off, committing sends it to Google for review.

const PACKAGE := "com.filthemaglin.gemhold"
const API := "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/" + PACKAGE
const UPLOAD := "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/" + PACKAGE
const SCOPE := "https://www.googleapis.com/auth/androidpublisher"
const KEY := "C:/Users/fil/Desktop/Gemhold/Play key/play-publisher.json"

var _http: HTTPRequest
var _token := ""


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 900.0
	root.add_child(_http)
	var args := OS.get_cmdline_user_args()
	var ok := await _sign_in()
	if ok:
		if args.has("--check"):
			ok = await _check()
		else:
			ok = await _release(args)
	quit(0 if ok else 1)


## An access token for the service account: a JWT signed with its private key (RS256).
func _sign_in() -> bool:
	var path := OS.get_environment("PLAY_KEY") if OS.get_environment("PLAY_KEY") != "" else KEY
	if not FileAccess.file_exists(path) and FileAccess.file_exists(KEY + ".json"):   # Windows often saves it as .json.json
		path = KEY + ".json"
	if not FileAccess.file_exists(path):
		printerr("No key file at %s" % path)
		return false
	var k = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (k is Dictionary) or not k.has("private_key") or not k.has("client_email"):
		printerr("The key file is not a service account key")
		return false
	var key := CryptoKey.new()
	if key.load_from_string(k["private_key"]) != OK:
		printerr("Could not read the private key")
		return false
	var now := int(Time.get_unix_time_from_system())
	var uri: String = k.get("token_uri", "https://oauth2.googleapis.com/token")
	var head := _b64(JSON.stringify({"alg": "RS256", "typ": "JWT"}).to_utf8_buffer())
	var claims := _b64(JSON.stringify({"iss": k["client_email"], "scope": SCOPE, "aud": uri, "iat": now, "exp": now + 3600}).to_utf8_buffer())
	var signing := head + "." + claims
	var digest := signing.sha256_buffer()
	var sig := Crypto.new().sign(HashingContext.HASH_SHA256, digest, key)
	var body := "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=" + signing + "." + _b64(sig)
	var r := await _call(HTTPClient.METHOD_POST, uri, body, "application/x-www-form-urlencoded", false)
	if not r["ok"] or not r["data"].has("access_token"):
		printerr("Sign-in failed: %s" % r["text"])
		return false
	_token = r["data"]["access_token"]
	print("Signed in as %s" % k["client_email"])
	return true


func _check() -> bool:
	var edit := await _call(HTTPClient.METHOD_POST, API + "/edits", "{}")
	if not edit["ok"]:
		printerr("Opening an edit failed: %s" % edit["text"])
		return false
	var id: String = edit["data"]["id"]
	var tracks := await _call(HTTPClient.METHOD_GET, API + "/edits/%s/tracks" % id)
	if tracks["ok"]:
		for t: Dictionary in tracks["data"].get("tracks", []):
			var rel := []
			for r: Dictionary in t.get("releases", []):
				rel.append("%s %s %s" % [r.get("name", "?"), r.get("versionCodes", []), r.get("status", "?")])
			print("  %s: %s" % [t["track"], ", ".join(rel) if not rel.is_empty() else "(empty)"])
	else:
		printerr("Listing tracks failed: %s" % tracks["text"])
	await _call(HTTPClient.METHOD_DELETE, API + "/edits/" + id)
	print("Access works; nothing was changed." if tracks["ok"] else "")
	return tracks["ok"]


func _release(args: PackedStringArray) -> bool:
	var aab := ""
	var track := "alpha"
	var notes := ""
	var draft := args.has("--draft")
	var i := 0
	while i < args.size():
		match args[i]:
			"--track":
				track = args[i + 1]
				i += 1
			"--notes":
				notes = FileAccess.get_file_as_string(args[i + 1]).strip_edges()
				i += 1
			_:
				if args[i].ends_with(".aab"):
					aab = args[i]
		i += 1
	if aab == "" or not FileAccess.file_exists(aab):
		printerr("Give the .aab to upload")
		return false
	if notes == "":
		printerr("Give release notes with --notes <file>")
		return false
	var edit := await _call(HTTPClient.METHOD_POST, API + "/edits", "{}")
	if not edit["ok"]:
		printerr("Opening an edit failed: %s" % edit["text"])
		return false
	var id: String = edit["data"]["id"]
	print("Uploading %s (%d MB)..." % [aab.get_file(), FileAccess.get_file_as_bytes(aab).size() / 1048576])
	var up := await _call(HTTPClient.METHOD_POST, UPLOAD + "/edits/%s/bundles?uploadType=media" % id, FileAccess.get_file_as_bytes(aab), "application/octet-stream")
	if not up["ok"]:
		printerr("Upload failed: %s" % up["text"])
		await _call(HTTPClient.METHOD_DELETE, API + "/edits/" + id)
		return false
	var code := str(int(up["data"]["versionCode"]))
	print("Uploaded version code %s" % code)
	var rel := {"versionCodes": [code], "status": "draft" if draft else "completed",
		"releaseNotes": [{"language": "en-US", "text": notes.left(500)}]}
	var tr := await _call(HTTPClient.METHOD_PUT, API + "/edits/%s/tracks/%s" % [id, track], JSON.stringify({"track": track, "releases": [rel]}))
	if not tr["ok"]:
		printerr("Setting the %s release failed: %s" % [track, tr["text"]])
		await _call(HTTPClient.METHOD_DELETE, API + "/edits/" + id)
		return false
	var done := await _call(HTTPClient.METHOD_POST, API + "/edits/%s:commit" % id, "{}")
	if not done["ok"]:
		printerr("Commit failed: %s" % done["text"])
		return false
	print("Released version code %s on %s (%s)." % [code, track, "draft" if draft else "sent for review, full rollout"])
	return true


func _call(method: int, url: String, body: Variant = "", type := "application/json", auth := true) -> Dictionary:
	var headers := PackedStringArray(["Content-Type: " + type])
	if auth:
		headers.append("Authorization: Bearer " + _token)
	var err: int
	if body is PackedByteArray:
		err = _http.request_raw(url, headers, method, body)
	else:
		err = _http.request(url, headers, method, str(body))
	if err != OK:
		return {"ok": false, "text": "request error %d" % err, "data": {}}
	var r: Array = await _http.request_completed
	var text := (r[3] as PackedByteArray).get_string_from_utf8()
	var data = JSON.parse_string(text) if text != "" else {}
	return {"ok": r[0] == HTTPRequest.RESULT_SUCCESS and r[1] >= 200 and r[1] < 300, "text": "HTTP %d %s" % [r[1], text.left(600)],
		"data": data if data is Dictionary else {}}


static func _b64(b: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(b).replace("+", "-").replace("/", "_").replace("=", "")

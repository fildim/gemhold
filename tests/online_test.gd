extends SceneTree
## The online account and leaderboard against the local Firebase emulators (never the real project).
## Needs Java for the emulators. Run from the project folder:
##   firebase emulators:exec --only auth,firestore "godot --headless --path . -s res://tests/online_test.gd"

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := _client("a")
	var b := _client("b")
	var save_a := SaveData.load_from("user://online_test_a.json")
	save_a.record_score("level_01", 2000)
	save_a.record_score("level_01:night", 3000)
	save_a.earn("first_win")
	var mail := "tester%d@example.com" % (Time.get_ticks_usec() % 1000000)

	_check(await a.sign_up(mail, "secret123", "X", save_a) != "", "a one-letter name is refused")
	_check(await a.sign_up(mail, "123", "Alpha", save_a) != "", "a short password is refused")
	_check(await a.sign_up(mail, "secret123", "Alpha", save_a) == "", "sign up")
	_check(a.signed_in() and a.player_name == "Alpha", "signed in after sign up")
	_check(await a.upload(save_a) == "", "upload scores")
	_check(await a.sign_up(mail, "secret123", "Alpha", save_a) == "That email already has an account: sign in instead", "the same email can't sign up twice")

	var save_b := SaveData.load_from("user://online_test_b.json")
	save_b.record_score("level_01", 2500)
	_check(await b.sign_up("b" + mail, "secret123", "Beta", save_b) == "", "second player signs up")
	_check(await b.upload(save_b) == "", "second player uploads")

	var total: Variant = await a.top("total")
	_check(typeof(total) == TYPE_ARRAY and total.size() >= 2 and total[0]["name"] == "Alpha" and total[0]["value"] == 5000, "total board, best first: %s" % [total])
	var lair: Variant = await a.top("scores.level_01")
	_check(typeof(lair) == TYPE_ARRAY and lair[0]["name"] == "Beta" and lair[0]["value"] == 2500, "lair board: %s" % [lair])
	var night: Variant = await a.top("scores." + Online.score_key("level_01:night"))
	_check(typeof(night) == TYPE_ARRAY and night.size() == 1 and night[0]["value"] == 3000, "night board only lists who has a score")

	# Firestore rules: nobody writes another player's document.
	b.uid = a.uid
	_check(await b.upload(save_b) != "", "can't write someone else's scores")
	b.uid = (lair[0]["uid"])
	_check(await a.rename("Alpha Prime", save_a) == "", "rename")

	# Online races: the host tags the lair with the rules version, a guest reads before joining and
	# refuses a race from an older host; each racer then reports their own progress.
	var hosted := await a.race_host("level_03")
	_check(hosted.has("code"), "host a race: %s" % [hosted])
	var raw := await a._call("GET", a._docs + "/races/" + str(hosted.get("code", "")), null, true)
	_check(raw["ok"] and Online._value(raw["data"]["fields"]["level"]) == "level_03@%d" % Online.RACE_VERSION, "the race document's lair carries the version: %s" % [raw["data"]])
	var seen := await b.race_get(str(hosted.get("code", "")))
	_check(seen.get("level") == "level_03" and seen.get("version") == Online.RACE_VERSION and seen.get("state") == "open", "a new client reads the plain lair: %s" % [seen])
	var old_code := "QLDR" + Online.RACE_LETTERS[randi() % Online.RACE_LETTERS.length()]
	var old_doc := {"name": "projects/%s/databases/(default)/documents/races/%s" % [Online.PROJECT, old_code],
		"fields": Online._typed_fields({"host": a.uid, "host_name": a.player_name, "level": "level_03", "night": false, "state": "open", "h": Online.race_progress()})}
	var made := await a._call("POST", a._docs + ":commit", {"writes": [{"update": old_doc,
		"updateTransforms": [{"fieldPath": "created", "setToServerValue": "REQUEST_TIME"}]}]}, true)
	_check(made["ok"], "an old client's race (no version on the lair): %s" % [made])
	var refused := await b.race_join(old_code)
	_check(refused.get("error") == Online.RACE_OLDER, "a new client won't join an old host's race: %s" % [refused])
	var untouched := await b.race_get(old_code)
	_check(untouched.get("state") == "open" and untouched.get("guest") == "", "and wrote nothing to it: %s" % [untouched])
	await a.race_cancel(old_code)
	_check((await a.race_join(str(hosted["code"]))).has("error"), "a host can't join their own race")
	var joined := await b.race_join(str(hosted["code"]))
	_check(joined.get("state") == "on" and joined.get("guest") == b.uid and joined.get("level") == "level_03", "the guest joins: %s" % [joined])
	var mine := Online.race_progress()
	mine["wave"] = 3
	_check(await b.race_report(str(hosted["code"]), "g", mine) == "", "the guest reports their progress")
	_check(await b.race_report(str(hosted["code"]), "h", mine) != "", "but not the host's")
	_check(await a.race_report(str(hosted["code"]), "h", mine) == "", "the host reports theirs")
	var both := await a.race_get(str(hosted["code"]))
	_check(int(both["g"]["wave"]) == 3 and int(both["h"]["wave"]) == 3, "both progresses are there: %s" % [both])

	# Signing in elsewhere brings scores and achievements back.
	a.sign_out()
	_check(not a.signed_in(), "signed out")
	_check(await a.sign_in(mail, "wrong-pass", save_a) == "Wrong email or password", "wrong password")
	var other := SaveData.load_from("user://online_test_c.json")
	_check(await a.sign_in(mail, "secret123", other) == "", "sign in")
	_check(a.player_name == "Alpha Prime" and int(other.scores.get("level_01:night", 0)) == 3000 and other.has_achievement("first_win"), "the account's progress comes back")

	var reload := _client("a")   # a restart: the stored refresh token keeps the player signed in
	_check(reload.signed_in() and reload.player_name == "Alpha Prime", "stays signed in across restarts")
	reload._token = ""
	_check(await reload.upload(other) == "", "a fresh token from the refresh token")

	# The campaign crosses devices, and the rules accept its fields.
	reload.sync_progress = true
	other.record(0, "level_01", "Brilliant", 5, true)
	other.record(0, "level_01:night", "Survived", 2, true)
	other.buy("moss_dmg")
	_check(await reload.upload(other) == "", "the rules accept campaign progress")
	var device_two := SaveData.load_from("user://online_test_d.json")
	device_two.record(1, "level_02", "Wicked", 4, true)
	_check(await reload.upload(device_two) == "", "a second device pulls before it uploads")
	_check(device_two.unlocked == 3 and device_two.best_rank("level_01:night") == "Survived" and device_two.skill_rank("moss_dmg") == 1, "the campaign reaches the second device")
	_check(await reload.pull(other) == "" and other.best_rank("level_02") == "Wicked", "and the first device gets the second's results")

	# A second account on the same device neither inherits the first one's progress nor adds to it.
	var shared := _client("e")
	var device := SaveData.load_from("user://online_test_e.json")
	device.record_score("level_01", 9000)
	device.record(0, "level_01", "Brilliant", 5, true)
	_check(await shared.sign_up("e" + mail, "secret123", "Gamma", device) == "", "the device's first account")
	_check(await shared.upload(device) == "", "it takes the device's progress online")
	shared.sign_out()
	_check(int(device.scores.get("level_01", 0)) == 9000, "signing out keeps the progress")
	_check(await shared.sign_up("f" + mail, "secret123", "Delta", device) == "", "another account on the device")
	_check(device.scores.is_empty() and device.unlocked == 1 and device.best.is_empty(), "it starts clean")
	_check(await shared.upload(device) == "", "the clean account uploads")
	device.record_score("level_02", 111)
	_check(await shared.upload(device) == "", "the second account plays")
	var delta: Array = (await shared.top("total")).filter(func(row: Dictionary) -> bool: return row["name"] == "Delta")
	_check(delta.size() == 1 and delta[0]["value"] == 111, "only its own score reaches the board: %s" % [delta])
	var reopened := _client("e")   # a restart must remember who the save belongs to
	reopened.sign_out()
	_check(await reopened.sign_in("e" + mail, "secret123", device) == "", "the first account comes back")
	_check(int(device.scores.get("level_01", 0)) == 9000 and device.best_rank("level_01") == "Brilliant" and not device.scores.has("level_02"), "with its own progress only")
	reopened.sign_out()
	_check(await reopened.sign_in("f" + mail, "secret123", device) == "", "and the second account again")
	_check(int(device.scores.get("level_02", 0)) == 111 and not device.scores.has("level_01"), "with its own progress only too")
	while reopened._syncing:   # the upload that follows a sign-in
		await create_timer(0.05).timeout
	_check(await reopened.delete_account() == "", "deleting frees the device's progress")
	_check(await reopened.sign_in("e" + mail, "secret123", device) == "", "sign in after a delete")
	_check(int(device.scores.get("level_01", 0)) == 9000 and int(device.scores.get("level_02", 0)) == 111, "the next account takes the freed progress")
	while reopened._syncing:   # the upload that follows a sign-in
		await create_timer(0.05).timeout
	_check(await reopened.delete_account() == "", "clean up the first account")

	# A full-game code entered on one device follows the account to the others.
	Prefs.path = "user://online_test_prefs.cfg"
	Prefs.set_value("full", true)
	_check(await a.upload(other) == "", "the rules accept the unlock")
	Prefs.set_value("full", false)   # another device, still a demo
	Edition.demo = true
	_check(await a.pull(other) == "" and not Edition.demo and Prefs.get_value("full", false), "the account unlocks the other device")
	Prefs.set_value("full", false)
	_check(await b.pull(save_b) == "" and not Prefs.get_value("full", false), "an account without a code unlocks nothing")
	Edition.demo = false

	# Firebase refuses to delete after an old sign-in, so the game asks first and removes nothing.
	var signed_in_at := a._password_at
	a._password_at = 0.0
	_check(await a.delete_account() == Online.SIGN_IN_AGAIN and a.signed_in(), "an old sign-in is asked to sign in again")
	total = await b.top("total")
	_check(total.any(func(row: Dictionary) -> bool: return row["name"] == "Alpha Prime"), "and stays on the board: %s" % [total])
	_check(Online.friendly("CREDENTIAL_TOO_OLD_LOGIN_AGAIN") == Online.SIGN_IN_AGAIN, "Firebase's refusal is put in words")
	a._password_at = signed_in_at

	_check(await a.delete_account() == "", "delete account")
	total = await b.top("total")
	_check(total.size() == 1 and total[0]["name"] == "Beta", "a deleted player leaves the board: %s" % [total])
	_check(await b.delete_account() == "", "delete second account")
	for f in DirAccess.get_files_at("user://"):
		if f.begins_with("online_test_"):
			DirAccess.remove_absolute("user://" + f)
	print("online_test: %s" % ("all passed" if fails == 0 else "%d failed" % fails))
	quit(0 if fails == 0 else 1)


func _client(tag: String) -> Online:
	var o := Online.new()
	o.path = "user://online_test_%s.cfg" % tag
	o.use_emulators()
	root.add_child(o)
	return o


func _check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		printerr("FAIL: " + what)

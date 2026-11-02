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

	_check(await a.delete_account() == "", "delete account")
	total = await b.top("total")
	_check(total.size() == 1 and total[0]["name"] == "Beta", "a deleted player leaves the board")
	_check(await b.delete_account() == "", "delete second account")
	for f in ["a", "b", "c"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://online_test_%s.json" % f))
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://online_test_%s.cfg" % f))
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

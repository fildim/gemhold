extends SceneTree
## The ad rules (scripts/core/ads.gd) without the AdMob plugin: an interstitial on every
## campaign win, none in races, a rewarded ad buys Ads.REWARD_WINS ad-free wins, Prefs no_ads stops
## everything, and nothing at all happens in a build without the "ads" feature. Uses its own settings.
## Run: godot --headless --script res://tests/ads_test.gd

const SETTINGS := "user://ads_test_settings.cfg"

var fails := 0


func _init() -> void:
	DirAccess.remove_absolute(SETTINGS)
	Prefs.path = SETTINGS

	# Off: this run has no "ads" feature and no plugin, so every call is a no-op.
	_check(not Ads.enabled(), "no ads without the feature")
	_check(not Ads.on_win() and Prefs.get_value("ad_wins", -1) == -1, "a win counts nothing")
	_check(not Ads.rewarded_ready() and not Ads.privacy_options_required(), "no rewarded ad, no privacy button")
	var calls := [0]
	Ads.show_interstitial(func() -> void: calls[0] += 1)
	Ads.show_rewarded(func(earned: bool) -> void: calls[0] += 1 if not earned else 100)
	_check(calls[0] == 2, "show_* carry on at once, exactly once, nothing earned")

	# The pure rule.
	var r := Ads.count_win(0, 0)
	_check(r == {"wins": 1, "free": 0, "due": true}, "first win: ad")
	r = Ads.count_win(1, 0)
	_check(r["due"] and r["wins"] == 2, "second win: ad")
	r = Ads.count_win(5, 2)
	_check(r == {"wins": 5, "free": 1, "due": false}, "an ad-free win uses one up and is not counted")

	# On, as in the Android Play build with an ad loaded.
	Ads.testing = true
	Ads.test_loaded = true
	_check(Ads.enabled(), "ads on")
	_check(_wins(6) == [true, true, true, true, true, true], "an ad on every win")
	_check(not Ads.on_win(true) and int(Prefs.get_value("ad_wins", 0)) == 6, "races: no ad, not counted")
	_check(_wins(2) == [true, true], "and on the wins after a race")

	# No ad loaded (offline): the win still counts, but nothing shows.
	Ads.test_loaded = false
	_check(_wins(2) == [false, false], "no ad loaded: none shown")
	Ads.test_loaded = true
	_check(_wins(2) == [true, true], "loaded again: every win as before")

	# The reward: exactly REWARD_WINS wins without ads, then every win again.
	Ads.on_win()   # one counted win before watching, which the reward resets
	Ads.grant_reward()
	_check(Ads.ad_free_wins() == Ads.REWARD_WINS and Ads.REWARD_WINS == 2, "reward: 2 ad-free wins")
	_check(_wins(Ads.REWARD_WINS) == [false, false], "2 wins without an ad")
	_check(Ads.ad_free_wins() == 0, "all used up")
	_check(_wins(3) == [true, true, true], "then an ad on every win again")

	# Bought off: Prefs no_ads blocks everything.
	Prefs.set_value("no_ads", true)
	var before: int = Prefs.get_value("ad_wins", 0)
	_check(not Ads.enabled() and _wins(4) == [false, false, false, false], "no_ads: never an ad")
	_check(int(Prefs.get_value("ad_wins", 0)) == before, "no_ads: nothing counted")
	_check(not Ads.rewarded_ready(), "no_ads: no rewarded ad")
	Prefs.set_value("no_ads", false)

	# The count survives closing the game (it lives in the settings file).
	Ads.on_win()
	var kept: int = Prefs.get_value("ad_wins", 0)
	Prefs.path = SETTINGS   # drops the cached file: read again from disk
	_check(int(Prefs.get_value("ad_wins", 0)) == kept and kept > 0, "the count is saved")

	_check(Ads.retry_delay(1) == Ads.RETRY_MIN and Ads.retry_delay(2) == Ads.RETRY_MIN * 2 and Ads.retry_delay(20) == Ads.RETRY_MAX,
		"loading again waits longer after each failure, up to a cap")

	Ads.testing = false
	DirAccess.remove_absolute(SETTINGS)
	print("ads_test: %s" % ("all passed" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)


## Plays n campaign wins; whether each would bring an interstitial.
func _wins(n: int) -> Array:
	var out := []
	for i in n:
		out.append(Ads.on_win())
	return out


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: " + what)

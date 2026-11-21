class_name Ads
extends Node
## Ads in the free Android build for Google Play, and nowhere else: only an export with the custom
## feature "ads" (the "Android Play" preset) that also carries the AdMob plugin shows any. Everywhere
## else (desktop, web, demo builds, headless tests) every call here is a silent no-op.
##
## The only place that talks to the AdMob plugin (addons/AdmobPlugin, godot-admob v6.0). The rules:
## - one interstitial after every EVERY-th campaign win (day or night; not the tutorial, losses or
##   races), shown when the player leaves the win card; the count is kept in Prefs (ad_wins);
## - a rewarded ad on the win card buys REWARD_WINS wins without interstitials (Prefs ad_free_wins);
## - nothing waits for an ad: no network or no ad loaded means the game just carries on;
## - Prefs no_ads (set by the Remove ads purchase, scripts/core/shop.gd) turns everything off (enabled()).
## Before any ad is requested Google's UMP asks for consent where the law needs it (EEA, UK,
## Switzerland, US states); Settings can open the choices again (show_privacy_options).

const EVERY := 1          # an interstitial after every counted win
const REWARD_WINS := 2    # wins without interstitials after watching a rewarded ad (plus the win just had)

const SINGLETON := "AdmobPlugin"
const PLUGIN_SCRIPT := "res://addons/AdmobPlugin/Admob.gd"
## Real ad units: only ever handed to the plugin in release builds.
const INTERSTITIAL_REAL := "ca-app-pub-6183422079800649/3835174239"
const REWARDED_REAL := "ca-app-pub-6183422079800649/2138949187"
## Google's test ad units, used by every debug build.
const INTERSTITIAL_TEST := "ca-app-pub-3940256099942544/1033173712"
const REWARDED_TEST := "ca-app-pub-3940256099942544/5224354917"
const RATING_T := 2       # AdmobConfig.ContentRating.T, as set in AdMob (teens; MA blocked)
## Debug builds only: hashed ids of test phones (logcat prints a phone's id on the first consent
## request) and a pretend location (ConsentRequestParameters.DebugGeography: 1 EEA, 3 a regulated
## US state; -1 off) to see the consent forms while testing.
const TEST_DEVICES: Array[String] = []
const DEBUG_GEOGRAPHY := -1

const RETRY_MIN := 30.0   # seconds before loading again after a failure, doubling each time
const RETRY_MAX := 600.0
const SHOW_TIMEOUT := 8.0 # if an ad has not opened by then, carry on without it

static var _node: Ads     # the running instance (Android Play builds only)
static var testing := false        # tests: act as if the feature and plugin were here
static var test_loaded := true     # tests: whether an interstitial is "loaded"

var _admob: Node
var _sdk_started := false
var _form := ""           # why a consent form is loading: "start" or "privacy"
var _consent_fails := 0
var _fails := {"interstitial": 0, "rewarded": 0}
var _done := Callable()   # who to tell when the full-screen ad is gone
var _kind := ""           # "interstitial" or "rewarded" while one is up
var _opened := false
var _earned := false
var _muted := false


# ---------------------------------------------------------------- rules (pure, tested)

## Ads can show in this build: the "ads" export feature, the plugin present, and not bought off.
static func enabled() -> bool:
	if not testing and not (OS.has_feature("ads") and Engine.has_singleton(SINGLETON)):
		return false
	return not Prefs.get_value("no_ads", false)


## One counted win: wins is the counter, free the ad-free wins left. An ad-free win uses one up and
## is not counted; otherwise the counter goes up and every EVERY-th win is due an interstitial.
## Returns {"wins", "free", "due"}.
static func count_win(wins: int, free: int) -> Dictionary:
	if free > 0:
		return {"wins": wins, "free": free - 1, "due": false}
	wins += 1
	return {"wins": wins, "free": 0, "due": wins % EVERY == 0}


## A campaign win (not the tutorial: the caller skips it). Counts it and says whether an
## interstitial should show when the player leaves the win card.
static func on_win(race := false) -> bool:
	if race or not enabled():
		return false
	var r := count_win(int(Prefs.get_value("ad_wins", 0)), ad_free_wins())
	Prefs.set_value("ad_wins", r["wins"])
	Prefs.set_value("ad_free_wins", r["free"])
	return r["due"] and _loaded("interstitial")


static func ad_free_wins() -> int:
	return int(Prefs.get_value("ad_free_wins", 0))


## The rewarded ad was watched to the end.
static func grant_reward() -> void:
	Prefs.set_value("ad_free_wins", REWARD_WINS)
	Prefs.set_value("ad_wins", 0)


## Seconds to wait before loading again after `fails` failures in a row.
static func retry_delay(fails: int) -> float:
	return minf(RETRY_MAX, RETRY_MIN * pow(2.0, maxi(0, fails - 1)))


# ---------------------------------------------------------------- what the game calls

## Called once from main.gd: starts consent and the SDK when this build has ads.
static func start(host: Node) -> void:
	if _node != null or testing or not enabled():
		return
	_node = Ads.new()
	_node.name = "Ads"
	host.add_child(_node)


static func rewarded_ready() -> bool:
	return enabled() and _loaded("rewarded")


## Shows the interstitial if one is loaded; `done` is called exactly once, when it closes or fails
## (or at once when there is none).
static func show_interstitial(done: Callable) -> void:
	if not enabled() or _node == null or not _loaded("interstitial") or _node._kind != "":
		done.call()
		return
	_node._show("interstitial", func(_got: bool) -> void: done.call())


## Shows the rewarded ad; `done(earned)` is called exactly once. Earning it grants the reward.
static func show_rewarded(done: Callable) -> void:
	if not enabled() or _node == null or not _loaded("rewarded") or _node._kind != "":
		done.call(false)
		return
	_node._show("rewarded", done)


## Settings shows "Privacy choices" when UMP has a consent form for this player (EEA, UK,
## Switzerland, regulated US states). godot-admob v6.0 has no call for UMP's privacy options
## status, so a form being available stands in for "privacy options required".
static func privacy_options_required() -> bool:
	if not enabled() or _node == null or _node._admob == null:
		return false
	return _node._admob.is_consent_form_available()


## Opens the consent form again so the player can change their choices.
static func show_privacy_options() -> void:
	if not privacy_options_required() or _node._form != "":
		return
	_node._form = "privacy"
	_node._admob.load_consent_form()


static func _loaded(kind: String) -> bool:
	if testing:
		return test_loaded
	if _node == null or _node._admob == null or not _node._sdk_started:
		return false
	return _node._admob.is_interstitial_ad_loaded() if kind == "interstitial" else _node._admob.is_rewarded_ad_loaded()


# ---------------------------------------------------------------- the plugin

func _ready() -> void:
	var script: Script = load(PLUGIN_SCRIPT)
	if script == null:
		return
	_admob = script.new()
	var real := not OS.is_debug_build()
	_admob.is_real = real
	_admob.max_ad_content_rating = RATING_T
	_admob.remove_interstitial_ads_after_displayed = true   # one show each, then load a fresh one
	_admob.remove_rewarded_ads_after_displayed = true
	if real:
		_admob.android_real_interstitial_id = INTERSTITIAL_REAL
		_admob.android_real_rewarded_id = REWARDED_REAL
	else:
		_admob.android_debug_interstitial_id = INTERSTITIAL_TEST
		_admob.android_debug_rewarded_id = REWARDED_TEST
		_admob.debug_geography = DEBUG_GEOGRAPHY
		_admob.test_device_hashed_ids = TEST_DEVICES
	add_child(_admob)
	_admob.consent_info_updated.connect(_on_consent_info)
	_admob.consent_info_update_failed.connect(func(_e: Variant) -> void: _consent_retry())
	_admob.consent_form_loaded.connect(func() -> void: _admob.show_consent_form())
	_admob.consent_form_failed_to_load.connect(func(_e: Variant) -> void: _form_closed())
	_admob.consent_form_dismissed.connect(func(_e: Variant) -> void: _form_closed())
	_admob.initialization_completed.connect(_on_initialized)
	for kind: String in ["interstitial", "rewarded"]:
		_admob.connect(kind + "_ad_loaded", func(_a: Variant, _r: Variant) -> void: _fails[kind] = 0)
		_admob.connect(kind + "_ad_failed_to_load", func(_a: Variant, _e: Variant) -> void: _load_later(kind))
		_admob.connect(kind + "_ad_showed_full_screen_content", func(_a: Variant) -> void: _opened = true)
		_admob.connect(kind + "_ad_failed_to_show_full_screen_content", func(_a: Variant, _e: Variant) -> void:
			_admob.call("remove_%s_ad" % kind)
			_finish(kind)
			_load_later(kind))
		_admob.connect(kind + "_ad_dismissed_full_screen_content", func(_a: Variant) -> void:
			_finish(kind)
			_load(kind))
	_admob.rewarded_ad_user_earned_reward.connect(func(_a: Variant, _r: Variant) -> void:
		if _kind == "rewarded":
			_earned = true)
	_admob.update_consent_info()


## UMP knows where the player is: ask for consent first if it is needed, else start the SDK.
func _on_consent_info() -> void:
	_consent_fails = 0
	var status: Variant = _admob.get_consent_status()
	var required: bool = status != null and status.status == 2   # UserConsent.Status.REQUIRED
	if required and _admob.is_consent_form_available():
		_form = "start"
		_admob.load_consent_form()
	else:
		_start_sdk()


## No network (or UMP failed): try again later, with a growing pause.
func _consent_retry() -> void:
	_consent_fails += 1
	get_tree().create_timer(retry_delay(_consent_fails)).timeout.connect(_admob.update_consent_info)


func _form_closed() -> void:
	_form = ""
	var status: Variant = _admob.get_consent_status()
	if status != null and status.status == 2:   # still REQUIRED (the form failed): ask again later
		_consent_retry()
	else:
		_start_sdk()


func _start_sdk() -> void:
	if _sdk_started:
		return
	_sdk_started = true
	_admob.initialize()


func _on_initialized(_status: Variant) -> void:
	_load("interstitial")
	_load("rewarded")


func _load(kind: String) -> void:
	if not enabled():
		return
	if kind == "interstitial":
		if not _admob.is_interstitial_ad_loaded():
			_admob.load_interstitial_ad()
	elif not _admob.is_rewarded_ad_loaded():
		_admob.load_rewarded_ad()


func _load_later(kind: String) -> void:
	_fails[kind] += 1
	get_tree().create_timer(retry_delay(_fails[kind])).timeout.connect(_load.bind(kind))


func _show(kind: String, done: Callable) -> void:
	_kind = kind
	_done = done
	_opened = false
	_earned = false
	_muted = AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, true)   # music and sound stop while the ad is up
	if kind == "interstitial":
		_admob.show_interstitial_ad()
	else:
		_admob.show_rewarded_ad()
	get_tree().create_timer(SHOW_TIMEOUT).timeout.connect(func() -> void:
		if _kind == kind and not _opened:
			_finish(kind))


## The ad is gone (closed, failed or never opened): sound back on, tell the caller once.
func _finish(kind: String) -> void:
	if _kind != kind:
		return
	var done := _done
	var earned := _earned
	_kind = ""
	_done = Callable()
	AudioServer.set_bus_mute(0, _muted)
	if earned:
		grant_reward()
	if done.is_valid():
		done.call(earned)

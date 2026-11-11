class_name Edition
extends RefCounted
## Which edition of the game this build is. Demo builds (export presets with the "demo" feature)
## stop after the first DEMO_LAIRS lairs and point to the full game. The save keeps any progress
## past that, so buying the full game later loses nothing.

const DEMO_LAIRS := 5
## Fill these in when each store page exists. An empty one shows "coming soon" instead of a button.
const STEAM_URL := ""
const PLAY_URL := ""
const APP_STORE_URL := ""

## A demo build plays as the full game once a full-game code was entered on the device (Info).
static var demo_build: bool = OS.has_feature("demo")   # exported as a demo, unlocked or not
static var demo: bool = demo_build and not Prefs.get_value("full", false)


static func unlock() -> void:
	Prefs.set_value("full", true)
	demo = false


## Unlocks the full game if `text` is one of the codes made by tools/make_codes.gd. Spaces,
## dashes and letter case don't matter.
static func try_code(text: String) -> bool:
	var code := normalize_code(text)
	if code.length() < 8 or not UnlockCodes.HASHES.has(code_hash(code)):
		return false
	unlock()
	return true


static func normalize_code(text: String) -> String:
	var out := ""
	for ch in text.to_upper():
		if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9"):
			out += ch
	return out


static func code_hash(code: String) -> String:
	return ("gemhold-full:" + normalize_code(code)).sha256_text()


static func locked(index: int) -> bool:
	return demo and index >= DEMO_LAIRS


## The store that sells the full game on this device: {"name", "url"}.
static func store() -> Dictionary:
	if OS.has_feature("android") or OS.has_feature("web_android"):
		return {"name": "Google Play", "url": PLAY_URL}
	if OS.has_feature("ios") or OS.has_feature("web_ios"):
		return {"name": "the App Store", "url": APP_STORE_URL}
	return {"name": "Steam", "url": STEAM_URL}

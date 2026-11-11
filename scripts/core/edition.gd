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

## A demo build plays as the full game on a device where an unlocked account once signed in
## (Online checks `unlocks/<uid>`, which only the developer can write, in the Firebase console).
static var demo: bool = OS.has_feature("demo") and not Prefs.get_value("full", false)


static func unlock() -> void:
	Prefs.set_value("full", true)
	demo = false


static func locked(index: int) -> bool:
	return demo and index >= DEMO_LAIRS


## The store that sells the full game on this device: {"name", "url"}.
static func store() -> Dictionary:
	if OS.has_feature("android") or OS.has_feature("web_android"):
		return {"name": "Google Play", "url": PLAY_URL}
	if OS.has_feature("ios") or OS.has_feature("web_ios"):
		return {"name": "the App Store", "url": APP_STORE_URL}
	return {"name": "Steam", "url": STEAM_URL}

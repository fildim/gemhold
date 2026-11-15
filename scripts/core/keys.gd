class_name Keys
extends RefCounted
## Keyboard shortcuts for the battle, which the player can change in Settings. Each is stored as a
## physical key (Prefs "key_<action>"), so it stays on the same key whatever keyboard layout
## (English, Greek, ...) is switched on.

## [action, name shown in Settings, default key], in the order Settings lists them.
const ACTIONS := [
	["pause", "Pause", KEY_SPACE],
	["speed", "Speed 1× / 2×", KEY_F],
	["next", "Next wave", KEY_N],
	["meteor", "Meteor", KEY_M],
	["cut", "Cut woods", KEY_C],
]


## Shortcuts only make sense with a keyboard: not on phones (app or web).
static func available() -> bool:
	return not (OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"))


static func default_of(action: String) -> int:
	for a: Array in ACTIONS:
		if a[0] == action:
			return a[2]
	return KEY_NONE


## The physical key for an action (KEY_NONE if it has none).
static func key_of(action: String) -> int:
	return int(Prefs.get_value("key_" + action, default_of(action)))


## Gives `action` this key. If another action had it, the two swap, so no key does two things.
static func assign(action: String, code: int) -> void:
	var old := key_of(action)
	for a: Array in ACTIONS:
		if a[0] != action and key_of(a[0]) == code:
			Prefs.set_value("key_" + a[0], old)
	Prefs.set_value("key_" + action, code)


static func reset() -> void:
	for a: Array in ACTIONS:
		Prefs.set_value("key_" + a[0], a[2])


## The action a key press stands for, or "".
static func action_of(event: InputEvent) -> String:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return ""
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return ""
	var code := code_of(event)
	if code == KEY_NONE:
		return ""
	for a: Array in ACTIONS:
		if key_of(a[0]) == code:
			return a[0]
	return ""


## The physical key of a key event (the plain keycode when the platform gives no physical one).
static func code_of(event: InputEventKey) -> int:
	return int(event.physical_keycode) if event.physical_keycode != KEY_NONE else int(event.keycode)


## A key's name for buttons and hints: "Space", "M".
static func name_of(action: String) -> String:
	var code := key_of(action)
	return OS.get_keycode_string(code) if code != KEY_NONE else "none"

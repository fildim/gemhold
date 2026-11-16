class_name Quality
extends RefCounted
## How much detail the battle is drawn with (Settings > Graphics, Prefs "graphics"):
##   "detailed"  everything, baked sharp enough for a big monitor
##   "light"     the same game and the same information, a cheaper picture for phones: pictures
##               baked at the screen's own size or less, fewer animation frames, fewer particles,
##               no purely decorative shimmer or water ripples
##   "auto"      (default) Detailed on desktop, Light on phones and phone browsers; and on any
##               platform it steps down to Light for the rest of the session if a battle stays
##               slow (never back up mid-battle)
## Anything that depends on it reads Quality.light() and redraws when `version` changes.

const AUTO := "auto"
const DETAILED := "detailed"
const LIGHT := "light"
const CHOICES := [AUTO, DETAILED, LIGHT]
const SLOW_MS := 22.0      # Auto steps down when a battle averages slower than this...
const SLOW_WINDOW := 5.0   # ...over this many seconds

static var version := 0    # bumps whenever the effective quality changes
static var stepped := false   # Auto stepped down to Light this session
static var _acc := 0.0
static var _frames := 0


static func choice() -> String:
	var c := str(Prefs.get_value("graphics", AUTO))
	return c if CHOICES.has(c) else AUTO


static func set_choice(c: String) -> void:
	if not CHOICES.has(c) or c == choice():
		return
	var was := light()
	Prefs.set_value("graphics", c)
	if c != AUTO:
		stepped = false
	_acc = 0.0
	_frames = 0
	if light() != was:
		version += 1


static func phone() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


static func light() -> bool:
	match choice():
		LIGHT:
			return true
		DETAILED:
			return false
	return phone() or stepped


## Pixels per board pixel to bake pictures at, for a board shown at `screen` screen pixels per
## board pixel: Detailed bakes at least at board size and up to 2.5x (sharp on a 1440p monitor),
## Light at the screen's own size, capped at 1.5x.
static func bake_scale(screen: float) -> float:
	var s := ceilf(screen * 20.0 - 0.01) / 20.0   # the screen's own size, so pictures land pixel for pixel
	if light():
		return clampf(s, 0.5, 1.5)
	return clampf(s, 1.0, 2.5)


## Screen pixels per local pixel of canvas item `ci`: the map's fit on screen times the window's
## stretch (a 1720x720 window shows the 1024 px wide board about 1.1x, a 3440x1440 one 2.2x).
static func screen_scale(ci: CanvasItem) -> float:
	if not ci.is_inside_tree():
		return 1.0
	var s := ci.get_global_transform_with_canvas().get_scale().x
	return absf(s * ci.get_viewport().get_final_transform().get_scale().x)


## Widest atlas page: 4096 on desktop at Detailed, 2048 elsewhere (every phone GPU takes that).
static func page_size() -> int:
	return 2048 if light() or phone() else 4096


## Fed every frame of a running battle (main.gd). In Auto, a battle that averages slower than
## SLOW_MS over SLOW_WINDOW seconds steps down to Light, once. True when it just did.
static func watch(delta: float) -> bool:
	if choice() != AUTO or light() or delta > 0.25:   # a hitch or a hidden window says nothing
		return false
	_acc += delta
	_frames += 1
	if _acc < SLOW_WINDOW:
		return false
	var avg := _acc / _frames * 1000.0
	_acc = 0.0
	_frames = 0
	if avg > SLOW_MS:
		stepped = true
		version += 1
		return true
	return false


## A battle starts or ends: the slow-frame window starts again (the first seconds bake pictures).
static func reset_watch() -> void:
	_acc = 0.0
	_frames = 0

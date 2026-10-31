class_name Sfx
extends Node
## Plays sound effects and music. Runs as the autoload "SfxPlayer"; call the static functions
## (Sfx.play("coin")), which do nothing when it is not running, as in headless tests.
## The sounds are WAV files in assets/audio, rendered by tools/make_audio.gd.
## Every button in the game clicks when pressed.
## Sound and music can each be switched off; the choice is kept in Prefs.

const DIR := "res://assets/audio/"
## name -> [volume dB, fewest seconds between two plays, random pitch spread]
const SFX := {
	"click": [-12.0, 0.03, 0.05], "error": [-10.0, 0.2, 0.0],
	"hut": [-17.0, 0.07, 0.12], "crypt": [-11.0, 0.12, 0.08], "zap": [-12.0, 0.08, 0.1],
	"die": [-13.0, 0.06, 0.15], "grab": [-5.0, 0.4, 0.0], "lost": [-3.0, 0.5, 0.0],
	"coin": [-9.0, 0.05, 0.06], "potion": [-9.0, 0.05, 0.06], "horn": [-6.0, 0.5, 0.0],
	"build": [-6.0, 0.05, 0.05], "upgrade": [-7.0, 0.05, 0.0], "sell": [-8.0, 0.05, 0.0],
	"chop": [-6.0, 0.05, 0.05], "raze": [-5.0, 0.1, 0.0], "whoosh": [-6.0, 0.05, 0.05],
	"boom": [-3.0, 0.05, 0.08], "rank": [-9.0, 0.2, 0.0], "win": [-4.0, 1.0, 0.0], "lose": [-4.0, 1.0, 0.0],
}
const MUSIC_DB := -15.0
const BEAM_DB := -20.0       # one Shrine burning; a little louder with more (up to 3)
const VOICES := 16

static var _me: Sfx

var sound_on := true
var music_on := true

var _streams := {}
var _last := {}              # name -> time last played (s)
var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_name := ""
var _music_tween: Tween
var _beam: AudioStreamPlayer
var _beams := 0


func _ready() -> void:
	_me = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	sound_on = Prefs.get_value("sound", true)
	music_on = Prefs.get_value("music", true)
	for bus in ["Sfx", "Music"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for n in SFX.keys() + ["beam", "map", "battle"]:
		var p: String = DIR + n + ".wav"
		if ResourceLoader.exists(p):
			_streams[n] = load(p)
	for i in VOICES:
		var v := AudioStreamPlayer.new()
		v.bus = "Sfx"
		add_child(v)
		_voices.append(v)
	_beam = _player("Sfx")
	_beam.stream = _streams.get("beam")
	_music = _player("Music")
	get_tree().node_added.connect(_on_node_added)


func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		(n as BaseButton).pressed.connect(_play.bind("click"))


static func play(sound: String) -> void:
	if _me:
		_me._play(sound)


func _play(sound: String) -> void:
	if not sound_on or not _streams.has(sound):
		return
	var cfg: Array = SFX.get(sound, [-10.0, 0.05, 0.0])
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(sound, -10.0)) < cfg[1]:
		return
	_last[sound] = now
	# Take a free voice; if all are busy, cut off the oldest.
	var v := _voices[_next]
	for i in VOICES:
		var c := _voices[(_next + i) % VOICES]
		if not c.playing:
			v = c
			_next = (_next + i) % VOICES
			break
	_next = (_next + 1) % VOICES
	v.stream = _streams[sound]
	v.volume_db = cfg[0]
	v.pitch_scale = 1.0 + randf_range(-cfg[2], cfg[2])
	v.play()


## How many Cinder Shrine beams are burning right now; the crackle loops while any are.
static func set_beams(n: int) -> void:
	if _me:
		_me._set_beams(n)


func _set_beams(n: int) -> void:
	_beams = n
	var on := sound_on and n > 0
	if on and not _beam.playing:
		_beam.play()
	elif not on and _beam.playing:
		_beam.stop()
	if on:
		_beam.volume_db = BEAM_DB + 2.5 * (mini(n, 3) - 1)


## "map", "battle", or "" for silence. Fades from one to the other.
static func play_music(track: String) -> void:
	if _me:
		_me._play_music(track)


func _play_music(track: String) -> void:
	if track == _music_name and (_music.playing or not music_on):
		return
	_music_name = track
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	if _music.playing:
		_music_tween.tween_property(_music, "volume_db", -40.0, 0.5)
	_music_tween.tween_callback(func() -> void:
		_music.stop()
		if music_on and _streams.has(track):
			_music.stream = _streams[track]
			_music.volume_db = -40.0
			_music.play())
	_music_tween.tween_property(_music, "volume_db", MUSIC_DB, 1.0)


## Cycles all on -> music off -> everything off. Returns the new label.
static func cycle() -> String:
	return _me._cycle() if _me else label()


func _cycle() -> String:
	if sound_on and music_on:
		music_on = false
	elif sound_on:
		sound_on = false
	else:
		sound_on = true
		music_on = true
	Prefs.set_value("sound", sound_on)
	Prefs.set_value("music", music_on)
	_set_beams(_beams)
	var track := _music_name
	_music_name = ""
	if music_on:
		_play_music(track)
	else:
		_music.stop()
		_music_name = track
	return label()


static func label() -> String:
	var sound_on: bool = Prefs.get_value("sound", true)
	var music_on: bool = Prefs.get_value("music", true)
	if sound_on and music_on:
		return "Sound on"
	return "Music off" if sound_on else "Muted"

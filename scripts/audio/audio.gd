class_name Sfx
extends Node
## Plays sound effects and music. Runs as the autoload "SfxPlayer"; call the static functions
## (Sfx.play("coin")), which do nothing when it is not running, as in headless tests.
## The sounds are WAV files in assets/audio, rendered by tools/make_audio.gd.
## Every button in the game clicks when pressed.
## Effects and music each have a volume from 0 (off) to 1, set in the Sound window and kept in Prefs.

const DIR := "res://assets/audio/"
const MUSIC_DIR := "res://assets/music/"   # public-domain recordings, see CREDITS.md there
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
const SFX_BUS_DB := -14.0     # added to every effect, keeping them under the music (the SFX values are relative)
const MUSIC_DB := 0.0   # recordings are quiet; full volume over the effects
const BEAM_DB := -20.0       # one Shrine burning; a little louder with more (up to 3)
const VOICES := 16

static var _me: Sfx

var sfx_vol := 1.0     # 0..1, 0 = silent
var music_vol := 1.0

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
	# Older saves kept one on/off switch ("sound"/"music"); off becomes volume 0.
	var was_on: bool = Prefs.get_value("sound", true) and Prefs.get_value("music", true)
	sfx_vol = clampf(float(Prefs.get_value("sfx_volume", 1.0 if was_on else 0.0)), 0.0, 1.0)
	music_vol = clampf(float(Prefs.get_value("music_volume", 1.0 if was_on else 0.0)), 0.0, 1.0)
	# Everything plays on the Master bus, with the effects turned down by SFX_BUS_DB on each
	# player: on the web build, extra buses get wired in a loop that never reaches the speakers.
	for n in SFX.keys() + ["beam"]:   # music loads when first played
		var p: String = DIR + n + ".wav"
		if ResourceLoader.exists(p):
			_streams[n] = load(p)
	for i in VOICES:
		var v := AudioStreamPlayer.new()
		add_child(v)
		_voices.append(v)
	_beam = _player()
	_beam.stream = _streams.get("beam")
	_music = _player()
	get_tree().node_added.connect(_on_node_added)


func _player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	add_child(p)
	return p


func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		(n as BaseButton).pressed.connect(_play.bind("click"))


static func play(sound: String) -> void:
	if _me:
		_me._play(sound)


func _play(sound: String) -> void:
	if sfx_vol <= 0.0 or not _streams.has(sound):
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
	v.volume_db = cfg[0] + SFX_BUS_DB + linear_to_db(sfx_vol)
	v.pitch_scale = 1.0 + randf_range(-cfg[2], cfg[2])
	v.play()


## How many Cinder Shrine beams are burning right now; the crackle loops while any are.
static func set_beams(n: int) -> void:
	if _me:
		_me._set_beams(n)


func _set_beams(n: int) -> void:
	_beams = n
	var on := sfx_vol > 0.0 and n > 0
	if on:
		_beam.volume_db = BEAM_DB + SFX_BUS_DB + 2.5 * (mini(n, 3) - 1) + linear_to_db(sfx_vol)
	if on and not _beam.playing:
		_beam.play()
	elif not on and _beam.playing:
		_beam.stop()


## "map", a lair's piece (see main.gd MUSIC), or "" for silence. Fades from one to the other.
static func play_music(track: String) -> void:
	if _me:
		_me._play_music(track)


func _play_music(track: String) -> void:
	if track == _music_name and (_music.playing or music_vol <= 0.0):
		return
	_music_name = track
	if _music_tween:
		_music_tween.kill()
	var full := _music_db()
	if OS.has_feature("web"):
		# The web build keeps the volume a sound started with, so a fade would stay near silent.
		_music.stop()
		if music_vol > 0.0 and _music_stream(track):
			_music.stream = _music_stream(track)
			_music.volume_db = full
			_music.play()
		return
	_music_tween = create_tween()
	if _music.playing:
		_music_tween.tween_property(_music, "volume_db", -40.0 + minf(full, 0.0), 0.5)
	_music_tween.tween_callback(func() -> void:
		_music.stop()
		if music_vol > 0.0 and _music_stream(track):
			_music.stream = _music_stream(track)
			_music.volume_db = -40.0 + minf(full, 0.0)
			_music.play())
	_music_tween.tween_property(_music, "volume_db", full, 1.0)


func _music_db() -> float:
	return MUSIC_DB + linear_to_db(maxf(music_vol, 0.0001))


static func sfx_volume() -> float:
	return _me.sfx_vol if _me else float(Prefs.get_value("sfx_volume", 1.0))


static func music_volume() -> float:
	return _me.music_vol if _me else float(Prefs.get_value("music_volume", 1.0))


## Effects volume, 0..1, from the Sound window's slider. Saved straight away.
static func set_sfx_volume(v: float) -> void:
	Prefs.set_value("sfx_volume", clampf(v, 0.0, 1.0))
	if _me:
		_me.sfx_vol = clampf(v, 0.0, 1.0)
		_me._set_beams(_me._beams)


## Music volume, 0..1. `done` is true when the slider is let go: the web build only takes a
## new volume when a track starts, so there the music restarts then.
static func set_music_volume(v: float, done := true) -> void:
	Prefs.set_value("music_volume", clampf(v, 0.0, 1.0))
	if _me:
		_me._set_music_volume(clampf(v, 0.0, 1.0), done)


func _set_music_volume(v: float, done: bool) -> void:
	var was := music_vol
	music_vol = v
	if v <= 0.0:
		if _music_tween:
			_music_tween.kill()
		_music.stop()
		return
	if was <= 0.0 or not _music.playing:
		# Switched back on: start the track that should be playing.
		var track := _music_name
		_music_name = ""
		_play_music(track)
		return
	if OS.has_feature("web"):
		if done:
			var pos := _music.get_playback_position()
			_music.stop()
			_music.volume_db = _music_db()
			_music.play(pos)
		return
	if _music_tween:
		_music_tween.kill()
	_music.volume_db = _music_db()


## A music track by name ("map", or a lair's piece), loaded the first time it plays.
func _music_stream(track: String) -> AudioStream:
	if not _streams.has(track):
		_streams[track] = null
		for p in [MUSIC_DIR + track + ".ogg", MUSIC_DIR + track + ".mp3"]:
			if track != "" and ResourceLoader.exists(p):
				var s: AudioStream = load(p)
				s.loop = true
				_streams[track] = s
				break
	return _streams[track]

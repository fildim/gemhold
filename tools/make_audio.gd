extends SceneTree
## Renders every sound effect and the music into assets/audio as WAV files.
## All of it is synthesised here (oscillators, noise and plucked strings), so the sounds are
## original and can be re-tuned and rebuilt. From the project folder:
##   godot --headless -s res://tools/make_audio.gd             (everything)
##   godot --headless -s res://tools/make_audio.gd -- hut boom  (just those)
## Music loops wrap their tails around to the start, so they repeat without a seam.

const RATE := 22050
const OUT := "res://assets/audio/"
const SOUNDS: Array[String] = ["click", "error", "hut", "crypt", "beam", "zap", "die", "grab", "lost",
	"coin", "potion", "horn", "build", "upgrade", "sell", "chop", "raze", "whoosh", "boom", "rank",
	"win", "lose", "map", "mountain", "turca", "dies", "toccata", "valkyries", "gallop", "fate", "mars"]

var rng := RandomNumberGenerator.new()
var _wrap := false   # set while rendering a loop: writes past the end land at the start


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var only := OS.get_cmdline_user_args()
	for s in SOUNDS:
		if only.is_empty() or only.has(s):
			rng.seed = hash(s)
			_wrap = false
			var b: PackedFloat32Array = call("_" + s)
			_write(s, b)
	quit()


# ---------------------------------------------------------------- building blocks

func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	b.fill(0.0)
	return b


func _put(b: PackedFloat32Array, i: int, v: float) -> bool:
	if i >= b.size():
		if not _wrap:
			return false
		i %= b.size()
	b[i] += v
	return true


static func hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


static func _osc(wave: String, ph: float) -> float:
	var x := ph - floorf(ph)
	match wave:
		"tri":
			return 4.0 * absf(x - 0.5) - 1.0
		"saw":
			return 2.0 * x - 1.0
		"square":
			return 1.0 if x < 0.5 else -1.0
	return sin(TAU * x)


## One voice: pitch glides (exponentially) from f0 to f1 over dur. The envelope rises over
## attack, then decays with time constant decay (0 = holds), and always fades out at the end.
## lp > 0 runs it through a one-pole low-pass at that cutoff; vib is vibrato depth in semitones.
func _note(b: PackedFloat32Array, at: float, dur: float, f0: float, f1: float, amp: float,
		wave := "sine", attack := 0.005, decay := 0.0, lp := 0.0, vib := 0.0) -> void:
	var n := int(dur * RATE)
	var start := int(at * RATE)
	var ph := 0.0
	var y := 0.0
	var a := 1.0 - exp(-TAU * lp / RATE) if lp > 0.0 else 1.0
	var rel := minf(0.03, dur * 0.3)
	for i in n:
		var t := float(i) / RATE
		var f := f0 * pow(f1 / f0, t / dur)
		if vib > 0.0:
			f *= pow(2.0, vib * sin(TAU * 5.5 * t) / 12.0)
		ph += f / RATE
		var env := minf(1.0, t / attack) if attack > 0.0 else 1.0
		if decay > 0.0:
			env *= exp(-t / decay)
		env *= clampf((dur - t) / rel, 0.0, 1.0)
		y += a * (_osc(wave, ph) - y)
		if not _put(b, start + i, y * env * amp):
			return


## Filtered noise. The low-pass cutoff sweeps from lp0 to lp1; hp > 0 also removes the lows.
func _noise(b: PackedFloat32Array, at: float, dur: float, amp: float, lp0: float, lp1: float,
		attack := 0.002, decay := 0.0, hp := 0.0) -> void:
	var n := int(dur * RATE)
	var start := int(at * RATE)
	var y := 0.0
	var low := 0.0
	var ah := 1.0 - exp(-TAU * hp / RATE)
	var rel := minf(0.03, dur * 0.3)
	for i in n:
		var t := float(i) / RATE
		var fc := lp0 * pow(lp1 / lp0, t / dur)
		var a := 1.0 - exp(-TAU * fc / RATE)
		y += a * (rng.randf_range(-1.0, 1.0) - y)
		var v := y
		if hp > 0.0:
			low += ah * (y - low)
			v = y - low
		var env := minf(1.0, t / attack) if attack > 0.0 else 1.0
		if decay > 0.0:
			env *= exp(-t / decay)
		env *= clampf((dur - t) / rel, 0.0, 1.0)
		if not _put(b, start + i, v * env * amp * 2.0):
			return


## A plucked string (Karplus-Strong). damp near 1 rings longer; bright near 1 keeps more highs.
func _pluck(b: PackedFloat32Array, at: float, f: float, amp: float, dur := 1.5, damp := 0.996, bright := 0.5) -> void:
	var p := maxi(2, int(RATE / f))
	var line := PackedFloat32Array()
	line.resize(p)
	for i in p:
		line[i] = rng.randf_range(-1.0, 1.0)
	var start := int(at * RATE)
	var n := int(dur * RATE)
	var rel := minf(0.05, dur * 0.3)
	var prev := 0.0
	for i in n:
		var k := i % p
		var v := line[k]
		var nxt := damp * (bright * v + (1.0 - bright) * prev)
		prev = v
		line[k] = nxt
		var t := float(i) / RATE
		if not _put(b, start + i, v * amp * clampf((dur - t) / rel, 0.0, 1.0)):
			return


## A struck bell: a sine with the inharmonic partials that make it ring like metal.
func _bell(b: PackedFloat32Array, at: float, f: float, amp: float, decay := 0.4) -> void:
	_note(b, at, decay * 5.0, f, f, amp, "sine", 0.002, decay)
	_note(b, at, decay * 3.0, f * 2.76, f * 2.76, amp * 0.35, "sine", 0.002, decay * 0.5)
	_note(b, at, decay * 2.0, f * 5.4, f * 5.4, amp * 0.15, "sine", 0.002, decay * 0.25)


## A low drum hit: a falling sine thump with a short burst of muffled noise.
func _drum(b: PackedFloat32Array, at: float, amp: float, f := 80.0) -> void:
	_note(b, at, 0.45, f, f * 0.5, amp, "sine", 0.002, 0.13)
	_noise(b, at, 0.12, amp * 0.25, 900.0, 200.0, 0.001, 0.03)


## Echoes added on top (not fed back), so a looping buffer can echo across its seam too.
func _echo(b: PackedFloat32Array, delay: float, fb: float, taps := 4) -> void:
	var src := b.duplicate()
	var d := int(delay * RATE)
	var n := b.size()
	for k in range(1, taps + 1):
		var g := pow(fb, k)
		for i in n:
			var j := i - d * k
			if j < 0:
				if not _wrap:
					continue
				j = posmod(j, n)
			b[i] += src[j] * g


func _write(sound: String, b: PackedFloat32Array) -> void:
	var peak := 0.0001
	for v in b:
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(b.size() * 2)
	for i in b.size():
		data.encode_s16(i * 2, int(clampf(b[i] / peak * 0.89, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	var err := w.save_to_wav(OUT + sound + ".wav")
	print("%-8s %5.2f s  %s" % [sound, b.size() / float(RATE), "ok" if err == OK else error_string(err)])


# ---------------------------------------------------------------- interface

func _click() -> PackedFloat32Array:
	var b := _buf(0.07)
	_note(b, 0.0, 0.06, 1100.0, 700.0, 0.6, "sine", 0.001, 0.015)
	_noise(b, 0.0, 0.02, 0.2, 5000.0, 3000.0, 0.001, 0.005, 1500.0)
	return b


func _error() -> PackedFloat32Array:
	var b := _buf(0.3)
	_note(b, 0.0, 0.11, 150.0, 140.0, 0.5, "square", 0.004, 0.0, 900.0)
	_note(b, 0.14, 0.13, 120.0, 110.0, 0.5, "square", 0.004, 0.0, 900.0)
	return b


# ---------------------------------------------------------------- towers and battle

## Warband Hut: the snap of a bowstring and the thwip of an arrow.
func _hut() -> PackedFloat32Array:
	var b := _buf(0.16)
	_noise(b, 0.0, 0.05, 0.6, 6000.0, 1500.0, 0.001, 0.015, 800.0)
	_note(b, 0.0, 0.12, 480.0, 300.0, 0.5, "tri", 0.001, 0.035)
	return b


## Bone Crypt: a heavy, cold bolt launched with a hollow boom and a ghostly overtone.
func _crypt() -> PackedFloat32Array:
	var b := _buf(0.5)
	_note(b, 0.0, 0.4, 170.0, 60.0, 0.8, "sine", 0.002, 0.12)
	_noise(b, 0.0, 0.3, 0.35, 1200.0, 200.0, 0.005, 0.08)
	_note(b, 0.01, 0.45, 660.0, 520.0, 0.18, "sine", 0.03, 0.15, 0.0, 0.4)
	return b


## Cinder Shrine: a crackling, humming flame. One second, loops while any beam burns.
func _beam() -> PackedFloat32Array:
	_wrap = true
	var b := _buf(1.0)
	_note(b, 0.0, 1.0, 110.0, 110.0, 0.25, "saw", 0.0, 0.0, 400.0)
	_note(b, 0.0, 1.0, 165.0, 165.0, 0.15, "saw", 0.0, 0.0, 600.0)
	_noise(b, 0.0, 1.0, 0.18, 2500.0, 2500.0, 0.0, 0.0, 600.0)
	for i in 26:
		_noise(b, rng.randf(), 0.012, rng.randf_range(0.3, 0.7), 7000.0, 3000.0, 0.0005, 0.003, 2000.0)
	return b


## The den's bolt: a crackling electric zap.
func _zap() -> PackedFloat32Array:
	var b := _buf(0.3)
	_note(b, 0.0, 0.22, 1500.0, 180.0, 0.45, "square", 0.001, 0.07, 3500.0)
	_noise(b, 0.0, 0.25, 0.5, 8000.0, 2000.0, 0.001, 0.06, 1500.0)
	return b


## A hero falls: a short grunt that drops away.
func _die() -> PackedFloat32Array:
	var b := _buf(0.35)
	_note(b, 0.0, 0.28, 240.0, 120.0, 0.6, "saw", 0.008, 0.1, 900.0, 0.6)
	_note(b, 0.0, 0.28, 361.0, 180.0, 0.25, "saw", 0.008, 0.08, 1400.0)
	_noise(b, 0.0, 0.08, 0.25, 2000.0, 500.0, 0.002, 0.03)
	return b


## A hero grabs a gem: an alarm of two falling notes.
func _grab() -> PackedFloat32Array:
	var b := _buf(0.6)
	_note(b, 0.0, 0.16, 988.0, 988.0, 0.4, "tri", 0.003, 0.0)
	_note(b, 0.17, 0.3, 740.0, 720.0, 0.4, "tri", 0.003, 0.15)
	return b


## A gem is gone for good: a low, sinking toll.
func _lost() -> PackedFloat32Array:
	var b := _buf(2.0)
	_bell(b, 0.0, hz(50), 0.5, 0.5)
	_note(b, 0.0, 1.6, hz(38), hz(37), 0.5, "saw", 0.02, 0.5, 300.0)
	_bell(b, 0.35, hz(45), 0.35, 0.4)
	_echo(b, 0.23, 0.35, 3)
	return b


func _coin() -> PackedFloat32Array:
	var b := _buf(0.5)
	_bell(b, 0.0, 1318.0, 0.4, 0.06)
	_bell(b, 0.06, 1760.0, 0.5, 0.09)
	return b


func _potion() -> PackedFloat32Array:
	var b := _buf(0.45)
	for i in 5:
		var f := rng.randf_range(350.0, 500.0) * (1.0 + i * 0.25)
		_note(b, i * 0.06, 0.06, f, f * 1.8, 0.4, "sine", 0.004, 0.02)
	return b


## A wave starts: a war horn, a root and a fifth with a slow swell.
func _horn() -> PackedFloat32Array:
	var b := _buf(1.6)
	_note(b, 0.0, 1.3, hz(43) * 0.97, hz(43), 0.5, "saw", 0.18, 0.0, 700.0, 0.12)
	_note(b, 0.0, 1.3, hz(50) * 0.97, hz(50), 0.3, "saw", 0.22, 0.0, 900.0, 0.12)
	_echo(b, 0.18, 0.25, 2)
	return b


## A tower goes up: a stone thud with a little chime.
func _build() -> PackedFloat32Array:
	var b := _buf(0.6)
	_note(b, 0.0, 0.3, 110.0, 55.0, 0.8, "sine", 0.002, 0.09)
	_noise(b, 0.0, 0.18, 0.4, 1500.0, 300.0, 0.002, 0.05)
	_bell(b, 0.1, hz(74), 0.25, 0.12)
	return b


func _upgrade() -> PackedFloat32Array:
	var b := _buf(0.9)
	var notes := [62, 65, 69, 74]
	for i in notes.size():
		_bell(b, i * 0.07, hz(notes[i] + 12), 0.35, 0.12)
	return b


func _sell() -> PackedFloat32Array:
	var b := _buf(0.6)
	var notes := [86, 81, 77, 74]
	for i in notes.size():
		_bell(b, i * 0.05, hz(notes[i]), 0.3, 0.06)
	_noise(b, 0.0, 0.2, 0.15, 1200.0, 300.0, 0.002, 0.06)
	return b


## Woods are cleared: two axe chops and a rustle of falling branches.
func _chop() -> PackedFloat32Array:
	var b := _buf(0.8)
	for i in 2:
		_noise(b, i * 0.16, 0.06, 0.6, 3000.0, 1000.0, 0.001, 0.015, 400.0)
		_note(b, i * 0.16, 0.08, 330.0, 260.0, 0.4, "tri", 0.001, 0.02)
	_noise(b, 0.32, 0.45, 0.3, 4000.0, 1500.0, 0.06, 0.15, 1200.0)
	return b


## A barracks is razed (or a mine or well taken): a crack and a crash.
func _raze() -> PackedFloat32Array:
	var b := _buf(1.0)
	_noise(b, 0.0, 0.08, 0.8, 7000.0, 2000.0, 0.001, 0.02, 600.0)
	_note(b, 0.0, 0.6, 90.0, 40.0, 0.7, "sine", 0.002, 0.18)
	_noise(b, 0.05, 0.8, 0.4, 1500.0, 200.0, 0.01, 0.25)
	return b


## Meteor called: rushing air, falling and growing louder until it lands (the delay is 0.55 s).
func _whoosh() -> PackedFloat32Array:
	var b := _buf(0.6)
	_noise(b, 0.0, 0.58, 0.5, 4000.0, 600.0, 0.5, 0.0)
	_note(b, 0.0, 0.58, 900.0, 200.0, 0.12, "sine", 0.45)
	return b


func _boom() -> PackedFloat32Array:
	var b := _buf(1.6)
	_note(b, 0.0, 1.0, 70.0, 28.0, 0.9, "sine", 0.002, 0.3)
	_noise(b, 0.0, 1.4, 0.8, 3000.0, 150.0, 0.002, 0.35)
	_noise(b, 0.0, 0.05, 0.5, 8000.0, 4000.0, 0.001, 0.01)
	return b


## A tower ranks up: a rising shimmer.
func _rank() -> PackedFloat32Array:
	var b := _buf(1.0)
	var notes := [81, 86, 88, 93]
	for i in notes.size():
		_bell(b, i * 0.05, hz(notes[i]), 0.25, 0.15)
	_echo(b, 0.12, 0.3, 2)
	return b


func _win() -> PackedFloat32Array:
	var b := _buf(3.2)
	var line := [[0.0, 62, 0.3], [0.3, 65, 0.3], [0.6, 69, 0.3], [0.9, 74, 1.6]]
	for n in line:
		_note(b, n[0], n[2] + 0.3, hz(n[1]), hz(n[1]), 0.4, "saw", 0.03, 0.0, 1500.0, 0.15)
		_note(b, n[0], n[2] + 0.3, hz(n[1] - 12), hz(n[1] - 12), 0.25, "saw", 0.03, 0.0, 800.0)
	_note(b, 0.9, 1.9, hz(66), hz(66), 0.25, "saw", 0.05, 0.0, 1500.0, 0.15)   # the major third: you won
	_drum(b, 0.0, 0.6)
	_drum(b, 0.9, 0.8)
	_echo(b, 0.21, 0.3, 3)
	return b


func _lose() -> PackedFloat32Array:
	var b := _buf(3.6)
	var line := [[0.0, 62, 0.6], [0.6, 60, 0.6], [1.2, 57, 0.6], [1.8, 50, 1.4]]
	for n in line:
		_note(b, n[0], n[2] + 0.2, hz(n[1]), hz(n[1]), 0.35, "saw", 0.05, 0.0, 700.0, 0.1)
	_note(b, 0.0, 3.2, hz(38), hz(38), 0.3, "saw", 0.4, 0.0, 300.0)
	_drum(b, 1.8, 0.8, 60.0)
	_echo(b, 0.3, 0.35, 3)
	return b


# ---------------------------------------------------------------- music

## A slow, dark pad: each chord tone played on two slightly detuned saws.
func _pad(b: PackedFloat32Array, at: float, dur: float, chord: Array, amp: float, lp := 700.0) -> void:
	for m in chord:
		var f := hz(m)
		_note(b, at, dur, f, f, amp, "saw", dur * 0.3, 0.0, lp)
		_note(b, at, dur, f * 1.006, f * 1.006, amp * 0.7, "saw", dur * 0.3, 0.0, lp)


## The campaign map: a slow drone, soft chords and a few far-off bells. 8 bars at 64 bpm.
func _map() -> PackedFloat32Array:
	_wrap = true
	var beat := 60.0 / 64.0
	var bar := beat * 4.0
	var b := _buf(bar * 8.0)
	var chords := [[50, 53, 57], [43, 50, 55, 58], [46, 50, 53], [45, 49, 52, 57]]   # Dm Gm Bb A
	for i in 4:
		_pad(b, i * bar * 2.0, bar * 2.0 + 0.6, chords[i], 0.05, 600.0)
		_note(b, i * bar * 2.0, bar * 2.0 + 0.6, hz(chords[i][0] - 12), hz(chords[i][0] - 12), 0.18, "sine", 1.0)
	var bells := [[0, 74], [3, 72], [6, 70], [8, 69], [12, 70], [15, 74], [16, 77], [20, 74], [24, 73], [27, 69], [30, 76]]
	for n in bells:
		_bell(b, n[0] * beat, hz(n[1]), 0.12, 0.5)
	for i in 16:
		_pluck(b, i * beat * 2.0 + beat, hz(chords[i / 4][i % 2 + 1]), 0.06, 2.5, 0.997, 0.3)
	_echo(b, beat * 0.75, 0.4, 4)
	return b


# ---------------------------------------------------------------- lair music
# Each lair fights to its own piece: public-domain classical themes, arranged fast and loud with
# drums and bass, and played on the synth voices below. Picked per lair in main.gd (MUSIC).

## A tune written as [midi, beats, midi, beats, ...] (midi -1 is a rest), shifted by `shift`
## semitones and starting at beat `at`. Returns [[start beat, beats, midi], ...].
static func _seq(flat: Array, shift := 0, at := 0.0) -> Array:
	var out := []
	var t := at
	for i in range(0, flat.size(), 2):
		if flat[i] >= 0:
			out.append([t, float(flat[i + 1]), int(flat[i]) + shift])
		t += float(flat[i + 1])
	return out


static func _len(flat: Array) -> float:
	var t := 0.0
	for i in range(1, flat.size(), 2):
		t += float(flat[i])
	return t


## flat repeated n times.
static func _rep(flat: Array, n: int) -> Array:
	var out := []
	for i in n:
		out.append_array(flat)
	return out


## flat with every note moved by shift semitones.
static func _shifted(flat: Array, shift: int) -> Array:
	var out := flat.duplicate()
	for i in range(0, out.size(), 2):
		if out[i] >= 0:
			out[i] += shift
	return out


## One note on a lead voice: "brass", "strings", "organ" or "pluck" (piano-like).
func _voice(b: PackedFloat32Array, at: float, dur: float, m: int, amp: float, tone: String) -> void:
	var f := hz(m)
	match tone:
		"brass":
			_note(b, at, dur * 0.92, f, f, amp, "saw", 0.02, 0.0, 2200.0, 0.08)
			_note(b, at, dur * 0.92, f * 0.5, f * 0.5, amp * 0.3, "square", 0.02, 0.0, 900.0)
		"strings":
			_note(b, at, dur * 0.95, f, f, amp, "saw", 0.03, 0.0, 1900.0, 0.12)
			_note(b, at, dur * 0.95, f * 1.005, f * 1.005, amp * 0.6, "saw", 0.03, 0.0, 1900.0)
		"organ":
			_note(b, at, dur * 0.96, f, f, amp * 0.6, "square", 0.004, 0.0, 2600.0)
			_note(b, at, dur * 0.96, f * 2.0, f * 2.0, amp * 0.22, "saw", 0.004, 0.0, 3200.0)
			_note(b, at, dur * 0.96, f * 0.5, f * 0.5, amp * 0.35, "saw", 0.004, 0.0, 1200.0)
		_:
			_pluck(b, at, f, amp * 1.4, maxf(0.35, dur * 1.6), 0.995, 0.65)
			_note(b, at, dur * 0.8, f, f, amp * 0.2, "tri", 0.004, 0.2)


func _play(b: PackedFloat32Array, notes: Array, beat: float, amp: float, tone: String) -> void:
	for n in notes:
		_voice(b, n[0] * beat, n[1] * beat, n[2], amp, tone)


## Bass notes, plucked short and hard.
func _bass(b: PackedFloat32Array, notes: Array, beat: float, amp: float) -> void:
	for n in notes:
		_pluck(b, n[0] * beat, hz(n[2]), amp, maxf(0.2, n[1] * beat * 1.1), 0.99, 0.45)


func _snare(b: PackedFloat32Array, at: float, amp: float) -> void:
	_noise(b, at, 0.18, amp, 6000.0, 2500.0, 0.001, 0.05, 900.0)
	_note(b, at, 0.1, 220.0, 160.0, amp * 0.4, "tri", 0.001, 0.03)


func _hat(b: PackedFloat32Array, at: float, amp: float) -> void:
	_noise(b, at, 0.04, amp, 9000.0, 7000.0, 0.001, 0.012, 5000.0)


## A drum kit over beats from..to: kick on 1 and 3 (every beat when drive), snare on 2 and 4,
## hats on the eighths.
func _kit(b: PackedFloat32Array, from: int, to: int, beat: float, amp: float, drive := false) -> void:
	for k in range(from, to):
		if drive or k % 2 == 0:
			_drum(b, k * beat, amp, 75.0)
		if k % 2 == 1:
			_snare(b, k * beat, amp * 0.55)
		_hat(b, k * beat, amp * 0.18)
		_hat(b, (k + 0.5) * beat, amp * 0.12)


## Grieg, In the Hall of the Mountain King (B minor): plucked, then the whole band an octave up.
func _mountain() -> PackedFloat32Array:
	_wrap = true
	var beat := 60.0 / 150.0
	var a := [59, .5, 61, .5, 62, .5, 64, .5, 66, .5, 62, .5, 66, 1, 65, .5, 61, .5, 65, 1, 64, .5, 60, .5, 64, 1,
		59, .5, 61, .5, 62, .5, 64, .5, 66, .5, 62, .5, 66, .5, 71, .5, 69, .5, 66, .5, 62, .5, 66, .5, 69, 2]
	var shifts := [0, 7, 12, 7]
	var b := _buf(beat * 64.0)
	for p in 4:
		var at := p * 16.0
		_play(b, _seq(a, shifts[p], at), beat, 0.32, "pluck" if p < 2 else "brass")
		if p >= 2:
			_play(b, _seq(a, shifts[p] - 12, at), beat, 0.18, "strings")
		var root := 35 + (7 if shifts[p] == 7 else 0)
		_bass(b, _seq(_rep([root, .5, root + 12, .5], 16), 0, at), beat, 0.5)
		_kit(b, int(at), int(at) + 16, beat, 0.35 + 0.15 * p, p >= 2)
	_echo(b, beat * 0.5, 0.18, 2)
	return b


## Mozart, Rondo alla Turca (A minor): piano, then strings, then brass with drums.
func _turca() -> PackedFloat32Array:
	_wrap = true
	var beat := 60.0 / 126.0
	var t := [71, .25, 69, .25, 68, .25, 69, .25, 72, .5, -1, .5, 74, .25, 72, .25, 71, .25, 72, .25, 76, .5, -1, .5,
		77, .25, 76, .25, 75, .25, 76, .25, 83, .25, 81, .25, 80, .25, 81, .25, 83, .25, 81, .25, 80, .25, 81, .25,
		84, 1, 81, .5, 84, .5, 83, .5, 81, .5, 79, .5, 81, .5, 83, .5, 81, .5, 79, .5, 81, .5,
		83, .5, 81, .5, 79, .5, 78, .5, 76, 1]
	var b := _buf(beat * 48.0)
	var tones := ["pluck", "strings", "brass"]
	for p in 3:
		var at := p * 16.0
		_play(b, _seq(t, -12 if p == 2 else 0, at), beat, 0.3, tones[p])
		# Oom-pah: the root on the beat, the chord on the off-beat. A minor, then E, then A minor.
		for k in 16:
			var e := k >= 10 and k < 14
			_bass(b, [[at + k, 0.5, 40 if e else 45]], beat, 0.45)
			for m in ([56, 59, 64] if e else [57, 60, 64]):
				_pluck(b, (at + k + 0.5) * beat, hz(m), 0.12, beat * 0.4, 0.99, 0.5)
		_kit(b, int(at), int(at) + 16, beat, 0.25 + 0.15 * p, p == 2)
	return b


## Dies Irae, the medieval chant of the Last Judgement, over a galloping D minor bass.
func _dies() -> PackedFloat32Array:
	_wrap = true
	var beat := 60.0 / 138.0
	var l1 := [65, 1, 64, 1, 65, 1, 62, 1, 64, 1, 60, 1, 62, 2]
	var l2 := [65, 1, 65, 1, 67, 1, 65, 1, 64, 1, 62, 1, 60, 1, 62, 1]
	var l3 := [69, 1, 67, 1, 69, 1, 65, 1, 67, 1, 64, 1, 62, 2]
	var tune := l1 + l2 + l1 + l3
	var b := _buf(beat * 64.0)
	_play(b, _seq(tune, 0, 0.0), beat, 0.3, "brass")
	_play(b, _seq(tune, 12, 32.0), beat, 0.26, "strings")
	_play(b, _seq(tune, 0, 32.0), beat, 0.22, "brass")
	_bass(b, _seq(_rep([38, .5, 38, .5, 45, .5, 50, .5], 32)), beat, 0.5)
	_kit(b, 0, 32, beat, 0.4)
	_kit(b, 32, 64, beat, 0.55, true)
	_echo(b, beat * 0.75, 0.2, 2)
	return b


## Bach, Toccata in D minor: the opening flourish and the diminished run on the organ, then a
## driving passage that keeps returning to A, with drums.
func _toccata() -> PackedFloat32Array:
	_wrap = true
	var beat := 60.0 / 96.0
	var intro := [69, .125, 67, .125, 69, 1.25, -1, .5, 67, .125, 65, .125, 64, .125, 62, .125, 61, .5, 62, 1.5, -1, 1.5]
	var run := [49, .25, 52, .25, 55, .25, 58, .25, 61, .25, 64, .25, 67, .25, 70, .25, 73, .25, 76, .25, 79, .25, 82, .25,
		62, .25, 65, .25, 69, .25, 74, .25, 74, 2]
	var c1 := [76, .25, 69, .25, 74, .25, 69, .25, 73, .25, 69, .25, 74, .25, 69, .25, 77, .25, 69, .25, 76, .25, 69, .25, 74, .25, 69, .25, 73, .25, 69, .25]
	var c2 := [79, .25, 69, .25, 77, .25, 69, .25, 76, .25, 69, .25, 74, .25, 69, .25, 73, .25, 69, .25, 74, .25, 69, .25, 76, .25, 69, .25, 73, .25, 69, .25]
	var tune := intro + _shifted(intro, -12) + run + c1 + c2 + c1 + c2 + [74, 1, 73, 1, 74, 2]
	var total := _len(tune)
	var b := _buf(beat * total)
	_play(b, _seq(tune), beat, 0.3, "organ")
	var drive := int(_len(intro) * 2.0 + _len(run))   # drums come in with the driving passage
	for k in range(drive, int(total), 2):
		_voice(b, k * beat, 2.0 * beat, 38 if (k / 4) % 2 == 0 else 45, 0.25, "organ")
	_kit(b, drive, int(total), beat, 0.5, true)
	_echo(b, beat * 0.5, 0.25, 3)
	return b


## Wagner, Ride of the Valkyries (B minor): galloping short-long horn calls over tremolo strings.
func _valkyries() -> PackedFloat32Array:
	_wrap = true
	var beat := 60.0 / 112.0
	var p := []
	for cl in [[54, 59, 2], [59, 62, 2], [62, 66, 2], [66, 69, 1], [66, 62, 1], [62, 66, 2], [66, 69, 2], [69, 73, 2], [73, 71, 2]]:
		p.append_array([cl[0], 1.0 / 3.0, cl[1], cl[2] - 1.0 / 3.0])
	var shifts := [0, 5, 0, 7]
	var b := _buf(beat * 64.0)
	for i in 4:
		var at := i * 16.0
		_play(b, _seq(p, shifts[i], at), beat, 0.32, "brass")
		if i >= 2:
			_play(b, _seq(p, shifts[i] + 12, at), beat, 0.16, "strings")
		_bass(b, _seq(_rep([47 + shifts[i], .25], 64), 0, at), beat, 0.22)
		_kit(b, int(at), int(at) + 16, beat, 0.35 + 0.1 * i, i >= 2)
	_echo(b, beat * 0.5, 0.2, 2)
	return b


## Rossini, the William Tell gallop: the da-da-dum call in E, then in A.
func _gallop() -> PackedFloat32Array:
	_wrap = true
	var beat := 60.0 / 152.0
	var g1 := [64, .25, 64, .25, 64, .5, 64, .25, 64, .25, 64, .5, 64, .25, 64, .25, 69, .5, 71, .5, 73, .5]
	var g2 := [64, .25, 64, .25, 64, .5, 64, .25, 64, .25, 64, .5, 64, .25, 69, .25, 73, .5, 71, .5, 68, .5]
	var g4 := [76, .5, 73, .5, 69, .5, 71, .5, 68, .5, 64, .5, 69, 1]
	var ph := g1 + g2 + g1 + g4
	var shifts := [0, 5, 0, 7]
	var b := _buf(beat * 64.0)
	for i in 4:
		var at := i * 16.0
		_play(b, _seq(ph, shifts[i], at), beat, 0.3, "strings" if i % 2 == 0 else "brass")
		_bass(b, _seq(_rep([40 + shifts[i], .5, 47 + shifts[i], .5], 16), 0, at), beat, 0.45)
		_kit(b, int(at), int(at) + 16, beat, 0.4 + 0.05 * i, true)
	return b


## Beethoven, Symphony No. 5 (C minor): fate knocking, then the knocks climbing.
func _fate() -> PackedFloat32Array:
	_wrap = true
	var beat := 60.0 / 112.0
	var p1 := [-1, .5, 67, .5, 67, .5, 67, .5, 63, 2, -1, .5, 65, .5, 65, .5, 65, .5, 62, 2]
	var p2 := [-1, .5, 67, .5, 67, .5, 67, .5, 63, .5, 68, .5, 68, .5, 68, .5, 67, .5, 75, .5, 75, .5, 75, .5, 72, 2]
	var p3 := [-1, .5, 67, .5, 67, .5, 67, .5, 62, .5, 68, .5, 68, .5, 68, .5, 67, .5, 77, .5, 77, .5, 77, .5, 74, 2]
	var p4 := [72, .5, 72, .5, 72, .5, 67, .5, 68, .5, 68, .5, 68, .5, 65, .5, 67, .5, 67, .5, 67, .5, 63, .5, 62, 1, 55, 1]
	var tune := p1 + p2 + p3 + p4
	var b := _buf(beat * 64.0)
	_play(b, _seq(tune, -12, 0.0), beat, 0.32, "strings")
	_play(b, _seq(tune, 0, 0.0), beat, 0.18, "strings")
	_play(b, _seq(tune, 0, 32.0), beat, 0.3, "brass")
	_play(b, _seq(tune, -12, 32.0), beat, 0.25, "strings")
	_bass(b, _seq(_rep([36, .5, 36, .5, 43, .5, 36, .5], 16)), beat, 0.4)
	_bass(b, _seq(_rep([36, .5, 48, .5], 32), 0, 32.0), beat, 0.45)
	for n in _seq(tune) + _seq(tune, 0, 32.0):   # timpani on every long note
		if n[1] >= 1.0:
			_drum(b, n[0] * beat, 0.7, 60.0)
	_kit(b, 32, 64, beat, 0.45, true)
	_echo(b, beat * 0.5, 0.2, 2)
	return b


## Holst, Mars from The Planets: the five-beat battering ostinato on G, with brass rising over it.
func _mars() -> PackedFloat32Array:
	_wrap = true
	var beat := 60.0 / 168.0
	var bar := [43, 1.0 / 3.0, 43, 1.0 / 3.0, 43, 1.0 / 3.0, 43, 1, 43, 1, 43, .5, 43, .5, 43, 1]
	var ost := _rep(bar, 16)
	var b := _buf(beat * 80.0)
	_bass(b, _seq(ost), beat, 0.55)
	_bass(b, _seq(ost, 12), beat, 0.3)
	for n in _seq(ost):
		_drum(b, n[0] * beat, 0.3, 70.0)
	for k in 16:
		_snare(b, (k * 5 + 3) * beat, 0.3)
	var brass := [-1, 10, 55, 10, 56, 10, 55, 5, 62, 5, 61, 10, 67, 5, 68, 5, 70, 5, 73, 5, 72, 5, 67, 5]
	_play(b, _seq(brass), beat, 0.3, "brass")
	_play(b, _seq(brass, -12), beat, 0.2, "brass")
	_echo(b, beat * 0.5, 0.2, 2)
	return b

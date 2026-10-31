extends SceneTree
## Renders every sound effect and both music loops into assets/audio as WAV files.
## All of it is synthesised here (oscillators, noise and plucked strings), so the sounds are
## original and can be re-tuned and rebuilt. From the project folder:
##   godot --headless -s res://tools/make_audio.gd             (everything)
##   godot --headless -s res://tools/make_audio.gd -- hut boom  (just those)
## Music loops wrap their tails around to the start, so they repeat without a seam.

const RATE := 22050
const OUT := "res://assets/audio/"
const SOUNDS: Array[String] = ["click", "error", "hut", "crypt", "beam", "zap", "die", "grab", "lost",
	"coin", "potion", "horn", "build", "upgrade", "sell", "chop", "raze", "whoosh", "boom", "rank",
	"win", "lose", "map", "battle"]

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


## Battle: a marching drum, a low bass, chords and a plucked tune in D minor. 16 bars at 92 bpm;
## the first eight are quieter (arpeggios only), the tune comes in on the second eight.
func _battle() -> PackedFloat32Array:
	_wrap = true
	var beat := 60.0 / 92.0
	var bar := beat * 4.0
	var b := _buf(bar * 16.0)
	var chords := [[50, 53, 57], [46, 50, 53], [43, 46, 50], [45, 49, 52]]   # Dm Bb Gm A
	for half in 2:
		var o := half * bar * 8.0
		for i in 4:
			var at := o + i * bar * 2.0
			var ch: Array = chords[i]
			_pad(b, at, bar * 2.0 + 0.4, ch, 0.03, 650.0)
			for k in 8:   # bass: root on the beat, the octave pushing on the offbeat
				_pluck(b, at + k * beat, hz(ch[0] - 24 + (12 if k % 4 == 3 else 0)), 0.5, beat * 1.2, 0.99, 0.4)
			for k in 16:  # arpeggio of eighths
				var m: int = ch[[0, 1, 2, 1][k % 4]] + 12
				_pluck(b, at + k * beat * 0.5, hz(m), 0.12 if half == 0 else 0.08, beat, 0.993, 0.6)
		for k in 32:
			var acc := 0.55 if k % 4 == 0 else (0.4 if k % 2 == 0 else 0.22)
			_drum(b, o + k * beat, acc)
			if k % 8 == 6:
				_drum(b, o + (k + 0.5) * beat, 0.25)
			_noise(b, o + (k + 0.5) * beat, 0.05, 0.05, 6000.0, 4000.0, 0.001, 0.015, 3000.0)
	var tune := [[0, 69], [1, 74], [2, 77], [2.5, 76], [3, 74], [4, 69], [5, 70], [6, 69], [7, 65],
		[8, 70], [9, 74], [10, 77], [11, 79], [12, 77], [13, 74], [14, 70], [15, 74],
		[16, 79], [17, 77], [18, 74], [18.5, 72], [19, 70], [20, 67], [21, 70], [22, 74], [23, 70],
		[24, 73], [25, 76], [26, 79], [26.5, 77], [27, 76], [28, 73], [29, 76], [30, 73], [31, 69]]
	for n in tune:
		_pluck(b, bar * 8.0 + n[0] * beat, hz(n[1]), 0.3, beat * 2.0, 0.996, 0.5)
		_note(b, bar * 8.0 + n[0] * beat, beat * 0.9, hz(n[1]), hz(n[1]), 0.05, "tri", 0.02, 0.3)
	_echo(b, beat * 0.75, 0.3, 3)
	return b

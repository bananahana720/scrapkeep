extends RefCounted

const Harmony := preload("res://src/presentation/harmony.gd")

# The instrument rack: every sound in the game is computed here from oscillators,
# envelopes, noise and small filters. No samples, no files, no network. Buffers are
# mono float at Harmony.RATE; to_wav() turns one into a 16-bit AudioStreamWAV.
#
# The instruments are shared by the band (music_engine.gd) and the one-shot cues
# (sfx_bank.gd), so a reward chime and the lead line come from the same rack.

const RATE := Harmony.RATE
const INV_RATE := 1.0 / Harmony.RATE

# Note renderers cache by instrument and pitch: a note is rendered once at its
# longest useful length and cut short at play time with a release ramp.
static var _notes := {}
# The cache is shared with the background bake, so every read and write takes the lock.
static var _lock := Mutex.new()
# The grid a score renders on. The bank sets it to bake a stinger at the boss tempo.
static var score_step := Harmony.STEP
# Held sounds are long enough to fill a bar at the slower boss tempo.
const HOLD := 90000


static func _cached(key: String) -> Variant:
	_lock.lock()
	var hit = _notes.get(key)
	_lock.unlock()
	return hit


static func _store(key: String, buf: PackedFloat32Array) -> void:
	_lock.lock()
	_notes[key] = buf
	_lock.unlock()


static func buffer(samples: int) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(maxi(1, samples))
	return buf


static func seconds(value: float) -> int:
	return int(value * RATE)


static func add_into(dst: PackedFloat32Array, src: PackedFloat32Array, offset: int, gain := 1.0) -> void:
	var count := mini(src.size(), dst.size() - offset)
	for i in count:
		dst[offset + i] += src[i] * gain


static func peak(buf: PackedFloat32Array) -> float:
	var top := 0.0
	for value in buf:
		top = maxf(top, absf(value))
	return top


static func rms(buf: PackedFloat32Array) -> float:
	if buf.is_empty():
		return 0.0
	var sum := 0.0
	for value in buf:
		sum += value * value
	return sqrt(sum / buf.size())


static func normalize(buf: PackedFloat32Array, target := 0.9) -> PackedFloat32Array:
	var top := peak(buf)
	if top > 0.00001:
		var gain := target / top
		for i in buf.size():
			buf[i] *= gain
	return buf


# Short linear fades at both ends so no cue starts or stops with a click.
static func declick(buf: PackedFloat32Array, fade_in := 32, fade_out := 256) -> PackedFloat32Array:
	var n := buf.size()
	for i in mini(fade_in, n):
		buf[i] *= float(i) / fade_in
	for i in mini(fade_out, n):
		buf[n - 1 - i] *= float(i) / fade_out
	return buf


static func to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav


# The loudest sample of a baked stream, read back from its 16-bit data.
static func wav_peak(wav: AudioStreamWAV) -> float:
	var data := wav.data
	var top := 0
	for i in range(0, data.size() - 1, 2):
		top = maxi(top, absi(data.decode_s16(i)))
	return top / 32767.0


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# --- Drums -------------------------------------------------------------------------

static func kick() -> PackedFloat32Array:
	var n := seconds(0.34)
	var buf := buffer(n)
	var rng := _rng(11)
	var phase := 0.0
	for i in n:
		var t := i * INV_RATE
		var f := 46.0 + 120.0 * exp(-t * 32.0)
		phase += TAU * f * INV_RATE
		var body := tanh(1.8 * sin(phase)) * exp(-t * 8.0)
		var click := rng.randf_range(-1.0, 1.0) * exp(-t * 500.0) * 0.35
		buf[i] = body + click
	return declick(normalize(buf, 0.95), 8, 400)


static func snare() -> PackedFloat32Array:
	var n := seconds(0.24)
	var buf := buffer(n)
	var rng := _rng(12)
	var low := 0.0
	for i in n:
		var t := i * INV_RATE
		var tone := sin(TAU * 188.0 * t) * exp(-t * 30.0) * 0.55 + sin(TAU * 332.0 * t) * exp(-t * 45.0) * 0.2
		var noise := rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.18
		buf[i] = tone + (noise - low) * exp(-t * 17.0) * 0.85
	return declick(normalize(buf, 0.85), 8, 300)


static func hat(open := false) -> PackedFloat32Array:
	var n := seconds(0.24 if open else 0.05)
	var buf := buffer(n)
	var rng := _rng(13 if open else 14)
	var prev_x := 0.0
	var prev_y := 0.0
	var decay := 13.0 if open else 85.0
	for i in n:
		var t := i * INV_RATE
		var x := rng.randf_range(-1.0, 1.0)
		# One-pole high-pass near 7 kHz, then a metallic square partial for shimmer.
		prev_y = 0.42 * (prev_y + x - prev_x)
		prev_x = x
		var metal := signf(sin(TAU * 7040.0 * t)) * 0.12 + signf(sin(TAU * 9870.0 * t)) * 0.08
		buf[i] = (prev_y + metal) * exp(-t * decay)
	return declick(normalize(buf, 0.6 if open else 0.5), 4, 200)


static func ride() -> PackedFloat32Array:
	var n := seconds(0.5)
	var buf := buffer(n)
	var phase_c := 0.0
	var phase_m := 0.0
	for i in n:
		var t := i * INV_RATE
		phase_c += TAU * 540.0 * INV_RATE
		phase_m += TAU * 540.0 * 2.41 * INV_RATE
		var index := 2.8 * exp(-t * 5.0) + 0.6
		buf[i] = sin(phase_c + index * sin(phase_m)) * exp(-t * 4.2)
	return declick(normalize(buf, 0.45), 8, 800)


static func crash() -> PackedFloat32Array:
	var n := seconds(1.7)
	var buf := buffer(n)
	var rng := _rng(15)
	var prev_x := 0.0
	var prev_y := 0.0
	var phase_c := 0.0
	var phase_m := 0.0
	for i in n:
		var t := i * INV_RATE
		var x := rng.randf_range(-1.0, 1.0)
		prev_y = 0.55 * (prev_y + x - prev_x)
		prev_x = x
		phase_c += TAU * 410.0 * INV_RATE
		phase_m += TAU * 410.0 * 3.73 * INV_RATE
		var metal := sin(phase_c + 4.0 * exp(-t * 3.0) * sin(phase_m)) * 0.35
		buf[i] = (prev_y * 0.9 + metal) * exp(-t * 2.4)
	return declick(normalize(buf, 0.6), 8, 2000)


# --- Pitched instruments -------------------------------------------------------------
# Each takes a midi note and a length in samples and returns a note with its own
# attack and natural decay; the player adds the release when the note is cut.

static func note(instrument: String, midi: int) -> PackedFloat32Array:
	var key := "%s:%d" % [instrument, midi]
	var hit = _cached(key)
	if hit != null:
		return hit
	var buf: PackedFloat32Array
	match instrument:
		"sub":
			buf = sub(midi, HOLD)
		"reese":
			buf = reese(midi, Harmony.BAR)
		"keys":
			buf = keys(midi, Harmony.BAR)
		"lead":
			buf = lead(midi, Harmony.BEAT * 3)
		"bell":
			buf = bell(midi, seconds(1.0))
		"mallet":
			buf = mallet(midi, seconds(0.9))
		"beep":
			buf = beep(midi, seconds(0.5))
		"clav":
			buf = clav(midi, seconds(0.45))
		"brass":
			buf = brass(midi, seconds(1.0))
		"talk":
			buf = talk(midi, seconds(1.1))
		"fbass":
			buf = fbass(midi, seconds(0.5))
		_:
			buf = keys(midi, Harmony.BAR)
	_store(key, buf)
	return buf


# A whole keys voicing mixed into one buffer, so a chord stab is one voice to mix
# instead of four.
static func chord(voicing: Array) -> PackedFloat32Array:
	var key := "chord:%s" % str(voicing)
	var hit = _cached(key)
	if hit != null:
		return hit
	var buf := buffer(Harmony.BAR)
	for midi in voicing:
		add_into(buf, note("keys", midi), 0, 0.5)
	_store(key, buf)
	return buf


# A warm pad: soft sines an octave apart with a slow swell and a gentle shimmer,
# pitched an octave under the keys voicing so it sits under the band like heat.
static func pad_chord(voicing: Array) -> PackedFloat32Array:
	var key := "pad:%s" % str(voicing)
	var hit = _cached(key)
	if hit != null:
		return hit
	var n := HOLD
	var buf := buffer(n)
	for midi in voicing:
		var f := Harmony.hz(midi - 12)
		var phase := 0.0
		for i in n:
			var t := i * INV_RATE
			phase += TAU * f * INV_RATE
			var swell := minf(1.0, t * 3.0) * (0.9 + 0.1 * sin(TAU * 4.5 * t))
			buf[i] += (sin(phase) + 0.3 * sin(phase * 2.0) + 0.12 * sin(phase * 3.0)) * swell * 0.25
	declick(normalize(buf, 0.6), 64, 2000)
	_store(key, buf)
	return buf


static func sub(midi: int, n: int) -> PackedFloat32Array:
	var buf := buffer(n)
	var f := Harmony.hz(midi)
	var phase := 0.0
	for i in n:
		var t := i * INV_RATE
		phase += TAU * f * INV_RATE
		buf[i] = (sin(phase) + 0.12 * sin(phase * 2.0)) * minf(1.0, t * 180.0) * exp(-t * 0.35)
	return declick(normalize(buf, 0.8), 64, 600)


# Two detuned saws and a quiet octave through a swept resonant low-pass: the classic
# drum-and-bass growl, kept dark so it never masks the lead.
static func reese(midi: int, n: int) -> PackedFloat32Array:
	var buf := buffer(n)
	var f := Harmony.hz(midi)
	var p1 := 0.0
	var p2 := 0.37
	var p3 := 0.71
	var low := 0.0
	var band := 0.0
	for i in n:
		var t := i * INV_RATE
		p1 = fposmod(p1 + f * 1.0087 * INV_RATE, 1.0)
		p2 = fposmod(p2 + f * 0.9913 * INV_RATE, 1.0)
		p3 = fposmod(p3 + f * 2.0 * INV_RATE, 1.0)
		var x := (2.0 * p1 - 1.0) + (2.0 * p2 - 1.0) + (2.0 * p3 - 1.0) * 0.3
		var cutoff := 260.0 + 900.0 * (0.5 + 0.5 * sin(TAU * 1.4 * t - 1.2)) * exp(-t * 0.8) + 180.0
		var g := 2.0 * sin(PI * cutoff * INV_RATE)
		low += g * band
		var high := x - low - 0.55 * band
		band += g * high
		buf[i] = tanh(low * 0.9) * minf(1.0, t * 250.0)
	return declick(normalize(buf, 0.75), 64, 800)


# An electric piano: a 1:1 FM tine whose brightness falls away, plus a faint bark.
static func keys(midi: int, n: int) -> PackedFloat32Array:
	var buf := buffer(n)
	var f := Harmony.hz(midi)
	var phase := 0.0
	var bark := 0.0
	for i in n:
		var t := i * INV_RATE
		phase += TAU * f * INV_RATE
		bark += TAU * f * 14.0 * INV_RATE
		var index := 1.3 * exp(-t * 5.0) + 0.22
		var tine := sin(phase + index * sin(phase))
		buf[i] = (tine + sin(bark) * 0.05 * exp(-t * 60.0)) * minf(1.0, t * 400.0) * exp(-t * 1.1)
	return declick(normalize(buf, 0.6), 16, 1500)


# The lead is a synth saxophone, for Andrew: a scoop into the pitch, reedy self-FM
# that brightens with the breath, delayed vibrato and a little air.
static func lead(midi: int, n: int) -> PackedFloat32Array:
	var buf := buffer(n)
	var f := Harmony.hz(midi)
	var rng := _rng(midi)
	var phase := 0.0
	var reed := 0.0
	var air := 0.0
	for i in n:
		var t := i * INV_RATE
		var vibrato := 0.0
		if t > 0.16:
			vibrato = 0.0055 * sin(TAU * 5.6 * (t - 0.16)) * minf(1.0, (t - 0.16) * 5.0)
		var scoop := -0.03 * exp(-t * 28.0)
		var freq := f * (1.0 + vibrato + scoop)
		phase += TAU * freq * INV_RATE
		reed += TAU * freq * 3.0 * INV_RATE
		var breath := minf(1.0, t * 40.0)
		var index := 0.7 + 1.5 * breath - 0.35 * minf(1.0, t * 1.5)
		var tone := sin(phase + index * sin(phase) + 0.25 * breath * sin(reed))
		air += (rng.randf_range(-1.0, 1.0) - air) * 0.3
		buf[i] = (tone + air * 0.05) * breath * (0.92 + 0.08 * exp(-t * 6.0)) * exp(-t * 0.25)
	return declick(normalize(buf, 0.6), 32, 600)


# An inharmonic FM bell for rewards and chimes.
static func bell(midi: int, n: int) -> PackedFloat32Array:
	var buf := buffer(n)
	var f := Harmony.hz(midi)
	var phase := 0.0
	var mod := 0.0
	for i in n:
		var t := i * INV_RATE
		phase += TAU * f * INV_RATE
		mod += TAU * f * 3.5 * INV_RATE
		var index := 2.2 * exp(-t * 9.0) + 0.3
		buf[i] = (sin(phase + index * sin(mod)) * 0.7 + sin(phase * 2.0) * 0.2 * exp(-t * 5.0)) * minf(1.0, t * 800.0) * exp(-t * 3.2)
	return declick(normalize(buf, 0.6), 8, 1500)


# A soft mallet, the tone of the end-of-cycle melody.
static func mallet(midi: int, n: int) -> PackedFloat32Array:
	var buf := buffer(n)
	var f := Harmony.hz(midi)
	var phase := 0.0
	for i in n:
		var t := i * INV_RATE
		phase += TAU * f * INV_RATE
		buf[i] = (sin(phase) * exp(-t * 5.0) + 0.35 * sin(phase * 4.0) * exp(-t * 22.0) + 0.15 * sin(phase * 10.0) * exp(-t * 60.0)) * minf(1.0, t * 900.0)
	return declick(normalize(buf, 0.6), 8, 1200)


# A rounded appliance beep: a low-passed square, the rice cooker's own voice.
static func beep(midi: int, n: int) -> PackedFloat32Array:
	var buf := buffer(n)
	var f := Harmony.hz(midi)
	var phase := 0.0
	var low := 0.0
	for i in n:
		var t := i * INV_RATE
		phase = fposmod(phase + f * INV_RATE, 1.0)
		var square := 1.0 if phase < 0.5 else -1.0
		low += (square - low) * 0.12
		buf[i] = low * minf(1.0, t * 500.0) * exp(-t * 6.5)
	return declick(normalize(buf, 0.5), 16, 800)


# --- The level and boss palettes -----------------------------------------------------

# Clavinet: a narrow pulse through a snapping low-pass, short and percussive.
static func clav(midi: int, n: int) -> PackedFloat32Array:
	var buf := buffer(n)
	var f := Harmony.hz(midi)
	var phase := 0.0
	var low := 0.0
	var band := 0.0
	for i in n:
		var t := i * INV_RATE
		phase = fposmod(phase + f * INV_RATE, 1.0)
		var x := 1.0 if phase < 0.22 else -0.28
		var cutoff := 700.0 + 3800.0 * exp(-t * 28.0)
		var g := 2.0 * sin(PI * minf(cutoff, 6000.0) * INV_RATE)
		low += g * band
		band += g * (x - low - 0.35 * band)
		buf[i] = (low + band * 0.4) * minf(1.0, t * 1500.0) * exp(-t * 7.0)
	return declick(normalize(buf, 0.6), 8, 600)


# Brass: two detuned saws whose filter swells open with the breath, then settles.
static func brass(midi: int, n: int) -> PackedFloat32Array:
	var buf := buffer(n)
	var f := Harmony.hz(midi)
	var p1 := 0.0
	var p2 := 0.5
	var low := 0.0
	var band := 0.0
	for i in n:
		var t := i * INV_RATE
		p1 = fposmod(p1 + f * 1.004 * INV_RATE, 1.0)
		p2 = fposmod(p2 + f * 0.996 * INV_RATE, 1.0)
		var x := (2.0 * p1 - 1.0) + (2.0 * p2 - 1.0)
		var swell := minf(1.0, t * 22.0)
		var cutoff := 350.0 + 2600.0 * swell * (0.65 + 0.35 * exp(-t * 6.0))
		var g := 2.0 * sin(PI * cutoff * INV_RATE)
		low += g * band
		band += g * (x - low - 0.5 * band)
		buf[i] = tanh(low * 0.8) * swell * exp(-t * 0.6)
	return declick(normalize(buf, 0.6), 32, 800)


# Talkbox: a saw through two formant band-passes that glide "oo" to "ah" to "ee",
# with vibrato, so the lead seems to sing words.
static func talk(midi: int, n: int) -> PackedFloat32Array:
	var buf := buffer(n)
	var f := Harmony.hz(midi)
	var phase := 0.0
	var l1 := 0.0
	var b1 := 0.0
	var l2 := 0.0
	var b2 := 0.0
	for i in n:
		var t := i * INV_RATE
		var vib := 1.0 + 0.006 * sin(TAU * 5.2 * t) * minf(1.0, t * 4.0)
		phase = fposmod(phase + f * vib * INV_RATE, 1.0)
		var x := 2.0 * phase - 1.0
		var vowel := minf(1.0, t * 3.0)
		var f1 := lerpf(320.0, 750.0, minf(1.0, vowel * 2.0)) if vowel < 0.5 else lerpf(750.0, 300.0, (vowel - 0.5) * 2.0)
		var f2 := lerpf(850.0, 1150.0, minf(1.0, vowel * 2.0)) if vowel < 0.5 else lerpf(1150.0, 2200.0, (vowel - 0.5) * 2.0)
		var g1 := 2.0 * sin(PI * f1 * INV_RATE)
		var g2 := 2.0 * sin(PI * f2 * INV_RATE)
		l1 += g1 * b1
		b1 += g1 * (x - l1 - 0.18 * b1)
		l2 += g2 * b2
		b2 += g2 * (x - l2 - 0.2 * b2)
		buf[i] = (b1 + 0.7 * b2) * minf(1.0, t * 60.0) * exp(-t * 0.5)
	return declick(normalize(buf, 0.6), 32, 800)


# Funk bass: saw and square, plucked through a closing filter.
static func fbass(midi: int, n: int) -> PackedFloat32Array:
	var buf := buffer(n)
	var f := Harmony.hz(midi)
	var phase := 0.0
	var low := 0.0
	var band := 0.0
	for i in n:
		var t := i * INV_RATE
		phase = fposmod(phase + f * INV_RATE, 1.0)
		var x := (2.0 * phase - 1.0) * 0.6 + (1.0 if phase < 0.5 else -1.0) * 0.4
		var cutoff := 220.0 + 1800.0 * exp(-t * 18.0)
		var g := 2.0 * sin(PI * cutoff * INV_RATE)
		low += g * band
		band += g * (x - low - 0.45 * band)
		buf[i] = tanh(low * 1.3) * minf(1.0, t * 900.0) * exp(-t * 3.5)
	return declick(normalize(buf, 0.75), 16, 600)


# A drawbar organ chord with a key click and a rotating-speaker shimmer.
static func organ_chord(voicing: Array) -> PackedFloat32Array:
	var key := "organ:%s" % str(voicing)
	var hit = _cached(key)
	if hit != null:
		return hit
	var n := HOLD
	var buf := buffer(n)
	var bars := [[0.5, 0.5], [1.0, 1.0], [2.0, 0.6], [3.0, 0.35], [4.0, 0.25]]
	for midi in voicing:
		var f := Harmony.hz(midi)
		for bar in bars:
			var inc: float = TAU * f * bar[0] * INV_RATE
			var amp: float = bar[1] * 0.2
			var phase := 0.0
			for i in n:
				phase += inc
				buf[i] += sin(phase) * amp
	var rng := _rng(21)
	for i in n:
		var t := i * INV_RATE
		var click := rng.randf_range(-1.0, 1.0) * exp(-t * 300.0) * 0.3
		buf[i] = (buf[i] * (0.85 + 0.15 * sin(TAU * 6.3 * t)) + click) * minf(1.0, t * 300.0)
	declick(normalize(buf, 0.6), 32, 2000)
	_store(key, buf)
	return buf


# A filtered chord stab: brassy saws, dark for the build and bright for the drop.
static func stab_chord(voicing: Array, bright: bool) -> PackedFloat32Array:
	var key := "stab%s:%s" % ["B" if bright else "D", str(voicing)]
	var hit = _cached(key)
	if hit != null:
		return hit
	var n := seconds(0.6)
	var buf := buffer(n)
	var top := 3200.0 if bright else 900.0
	for midi in voicing:
		var f := Harmony.hz(midi + 12)
		var phase := 0.0
		var low := 0.0
		var band := 0.0
		for i in n:
			var t := i * INV_RATE
			phase = fposmod(phase + f * INV_RATE, 1.0)
			var cutoff := 300.0 + top * exp(-t * 9.0)
			var g := 2.0 * sin(PI * cutoff * INV_RATE)
			low += g * band
			band += g * ((2.0 * phase - 1.0) - low - 0.4 * band)
			buf[i] += low * 0.25 * exp(-t * 4.0)
	declick(normalize(buf, 0.6), 16, 800)
	_store(key, buf)
	return buf


# An anvil: a bright inharmonic clang that rings, the forge's hammer.
static func anvil() -> PackedFloat32Array:
	var n := seconds(1.1)
	var buf := buffer(n)
	var parts := [[1180.0, 1.0, 5.0], [1937.0, 0.6, 7.0], [2771.0, 0.45, 9.0], [3602.0, 0.3, 12.0], [612.0, 0.4, 6.0]]
	for part in parts:
		var inc: float = TAU * part[0] * INV_RATE
		var phase := 0.0
		for i in n:
			phase += inc
			buf[i] += sin(phase) * part[1] * exp(-i * INV_RATE * part[2])
	var rng := _rng(31)
	for i in n:
		buf[i] += rng.randf_range(-1.0, 1.0) * exp(-i * INV_RATE * 180.0) * 0.8
	return declick(normalize(buf, 0.55), 4, 1500)


static func clap() -> PackedFloat32Array:
	var n := seconds(0.22)
	var buf := buffer(n)
	var rng := _rng(32)
	var low := 0.0
	var band := 0.0
	var g := 2.0 * sin(PI * 1300.0 * INV_RATE)
	for i in n:
		var t := i * INV_RATE
		var burst := 0.0
		for tap in [0.0, 0.011, 0.023]:
			if t >= tap:
				burst += exp(-(t - tap) * (220.0 if tap < 0.02 else 18.0))
		var x := rng.randf_range(-1.0, 1.0) * burst
		low += g * band
		band += g * (x - low - 0.6 * band)
		buf[i] = band
	return declick(normalize(buf, 0.8), 4, 400)


# A deep industrial boom: a tom that falls a fifth, with grit.
static func boom() -> PackedFloat32Array:
	var n := seconds(0.6)
	var buf := buffer(n)
	var rng := _rng(33)
	var phase := 0.0
	for i in n:
		var t := i * INV_RATE
		phase += TAU * (55.0 + 45.0 * exp(-t * 9.0)) * INV_RATE
		buf[i] = tanh(2.5 * sin(phase)) * exp(-t * 5.0) + rng.randf_range(-1.0, 1.0) * exp(-t * 60.0) * 0.4
	return declick(normalize(buf, 0.95), 8, 800)


# --- Scores ---------------------------------------------------------------------------
# A score is a list of [step, midi, steps, instrument, gain]; drums use midi 0. It is
# rendered on the band's own grid, so a stinger started on a beat stays in time.

static func drum(instrument: String) -> PackedFloat32Array:
	var key := "drum:" + instrument
	var hit = _cached(key)
	if hit != null:
		return hit
	var buf: PackedFloat32Array
	match instrument:
		"kick":
			buf = kick()
		"snare":
			buf = snare()
		"hat":
			buf = hat(false)
		"open_hat":
			buf = hat(true)
		"ride":
			buf = ride()
		"anvil":
			buf = anvil()
		"clap":
			buf = clap()
		"boom":
			buf = boom()
		_:
			buf = crash()
	_store(key, buf)
	return buf


const DRUMS := ["kick", "snare", "hat", "open_hat", "ride", "crash", "anvil", "clap", "boom"]


static func render_score(score: Array, tail_seconds := 1.0) -> PackedFloat32Array:
	var step := score_step
	var last := 0
	for event in score:
		last = maxi(last, (int(event[0]) + int(event[2])) * step)
	var buf := buffer(last + seconds(tail_seconds))
	for event in score:
		var start: int = int(event[0]) * step
		var instrument: String = event[3]
		var gain: float = event[4]
		if instrument in DRUMS:
			add_into(buf, drum(instrument), start, gain)
			continue
		var source := note(instrument, int(event[1]))
		var length := mini(source.size(), int(event[2]) * step + seconds(0.25))
		var release := mini(1200, length)
		var count := mini(length, buf.size() - start)
		for i in count:
			var fade := 1.0 if i < length - release else float(length - i) / release
			buf[start + i] += source[i] * gain * fade
	return buf

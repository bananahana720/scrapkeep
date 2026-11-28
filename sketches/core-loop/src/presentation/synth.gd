extends RefCounted

const Harmony := preload("res://src/presentation/harmony.gd")


const RATE := Harmony.RATE
const INV_RATE := 1.0 / Harmony.RATE

static var _notes := {}
static var _lock := Mutex.new()
static var score_step := Harmony.STEP
static var score_transpose := 0
const HOLD := 90000


static func reset_for_tests() -> void:
	score_step = Harmony.STEP
	score_transpose = 0


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


static func kick() -> PackedFloat32Array:
	var n := seconds(0.34)
	var buf := buffer(n)
	var rng := _rng(11)
	var phase := 0.0
	var prev_x := 0.0
	var prev_y := 0.0
	for i in n:
		var t := i * INV_RATE
		var f := 44.0 + 145.0 * exp(-t * 42.0)
		phase += TAU * f * INV_RATE
		var body := tanh(2.1 * sin(phase)) * exp(-t * 9.0)
		var punch := sin(TAU * 180.0 * t) * exp(-t * 95.0) * 0.22
		var raw_n := rng.randf_range(-1.0, 1.0)
		prev_y = 0.72 * (prev_y + raw_n - prev_x)
		prev_x = raw_n
		var click := prev_y * exp(-t * 420.0) * 0.3
		buf[i] = body + punch + click
	return declick(normalize(buf, 0.95), 8, 400)


static func snare() -> PackedFloat32Array:
	var n := seconds(0.24)
	var buf := buffer(n)
	var rng := _rng(12)
	var low := 0.0
	var phase := 0.0
	for i in n:
		var t := i * INV_RATE
		var f := 165.0 + 55.0 * exp(-t * 55.0)
		phase += TAU * f * INV_RATE
		var tone := sin(phase) * exp(-t * 26.0) * 0.58 + sin(phase * 1.85) * exp(-t * 45.0) * 0.18
		var noise := rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.16
		var wire := (noise - low) * (0.55 * exp(-t * 28.0) + 0.45 * exp(-t * 14.5)) * 0.9
		buf[i] = tanh((tone + wire) * 1.25)
	return declick(normalize(buf, 0.85), 8, 300)


static func hat(open := false) -> PackedFloat32Array:
	var n := seconds(0.24 if open else 0.05)
	var buf := buffer(n)
	var rng := _rng(13 if open else 14)
	var prev_x := 0.0
	var prev_y := 0.0
	var prev_y2 := 0.0
	var decay := 12.5 if open else 85.0
	var inc1 := TAU * 6240.0 * INV_RATE
	var inc2 := TAU * 7890.0 * INV_RATE
	var inc3 := TAU * 10180.0 * INV_RATE
	var p1 := 0.0
	var p2 := 0.0
	var p3 := 0.0
	for i in n:
		var t := i * INV_RATE
		var x := rng.randf_range(-1.0, 1.0)
		var hp1 := 0.44 * (prev_y + x - prev_x)
		prev_x = x
		prev_y2 = 0.44 * (prev_y2 + hp1 - prev_y)
		prev_y = hp1
		p1 += inc1
		p2 += inc2
		p3 += inc3
		var metal := (sin(p1) * 0.1 + sin(p2) * 0.08 + sin(p3) * 0.06) * exp(-t * (decay * 1.15))
		buf[i] = (prev_y2 * 1.15 + metal) * exp(-t * decay)
	return declick(normalize(buf, 0.6 if open else 0.5), 4, 200)


static func ride() -> PackedFloat32Array:
	var n := seconds(0.5)
	var buf := buffer(n)
	var rng := _rng(16)
	var prev_x := 0.0
	var prev_y := 0.0
	var p_ping := 0.0
	var p_over1 := 0.0
	var p_over2 := 0.0
	var inc_ping := TAU * 1120.0 * INV_RATE
	var inc_o1 := TAU * 4820.0 * INV_RATE
	var inc_o2 := TAU * 7340.0 * INV_RATE
	for i in n:
		var t := i * INV_RATE
		var x := rng.randf_range(-1.0, 1.0)
		prev_y = 0.46 * (prev_y + x - prev_x)
		prev_x = x
		p_ping += inc_ping
		p_over1 += inc_o1
		p_over2 += inc_o2
		var stick := sin(p_ping) * exp(-t * 36.0) * 0.42
		var shimmer := (sin(p_over1) * 0.24 + sin(p_over2) * 0.16) * exp(-t * 5.2)
		var wash := prev_y * exp(-t * 6.8) * 0.55
		buf[i] = (stick + shimmer + wash) * minf(1.0, t * 1400.0)
	return declick(normalize(buf, 0.45), 8, 800)


static func crash() -> PackedFloat32Array:
	var n := seconds(1.7)
	var buf := buffer(n)
	var rng := _rng(15)
	var prev_x := 0.0
	var prev_y := 0.0
	var prev_y2 := 0.0
	var p1 := 0.0
	var p2 := 0.0
	var p3 := 0.0
	var inc1 := TAU * 4980.0 * INV_RATE
	var inc2 := TAU * 6710.0 * INV_RATE
	var inc3 := TAU * 8940.0 * INV_RATE
	for i in n:
		var t := i * INV_RATE
		var x := rng.randf_range(-1.0, 1.0)
		var hp1 := 0.52 * (prev_y + x - prev_x)
		prev_x = x
		prev_y2 = 0.48 * (prev_y2 + hp1 - prev_y)
		prev_y = hp1
		p1 += inc1
		p2 += inc2
		p3 += inc3
		var shimmer := (sin(p1) * 0.14 + sin(p2) * 0.11 + sin(p3) * 0.08) * exp(-t * 3.1)
		var strike := hp1 * exp(-t * 28.0) * 0.45
		buf[i] = (prev_y2 * 0.95 + shimmer + strike) * exp(-t * 2.3) * minf(1.0, t * 500.0)
	return declick(normalize(buf, 0.6), 8, 2000)


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
		"choir_ah":
			buf = choir(midi, "ah", seconds(1.0))
		"choir_oo":
			buf = choir(midi, "oo", seconds(1.0))
		"sax_lounge":
			buf = lead(midi, Harmony.BEAT * 6, 0.06, 4.3, 0.0075, 0.22)
		"tom":
			buf = tom(midi, seconds(0.8))
		"sub808":
			buf = sub808(midi, seconds(1.3))
		"buzz":
			buf = buzz(midi, seconds(2.0), 0.0)
		"buzz_loose":
			buf = buzz(midi, seconds(2.0), 0.35)
		"chime":
			buf = chime(midi, seconds(2.6))
		_:
			buf = keys(midi, Harmony.BAR)
	_store(key, buf)
	return buf


static func chord(voicing: Array) -> PackedFloat32Array:
	var key := "chord:%s" % str(voicing)
	var hit = _cached(key)
	if hit != null:
		return hit
	var buf := buffer(Harmony.BAR)
	for midi in voicing:
		add_into(buf, note("keys", midi), 0, 0.5)
	if peak(buf) > 0.85:
		normalize(buf, 0.85)
	_store(key, buf)
	return buf


static func pad_chord(voicing: Array) -> PackedFloat32Array:
	var key := "pad:%s" % str(voicing)
	var hit = _cached(key)
	if hit != null:
		return hit
	var n := HOLD
	var buf := buffer(n)
	for midi in voicing:
		var f := Harmony.hz(midi - 12)
		var inc1 := TAU * f * 0.9974 * INV_RATE
		var inc2 := TAU * f * 1.0026 * INV_RATE
		var p1 := float(midi % 7) * 0.41
		var p2 := float(midi % 5) * 0.67
		for i in n:
			var t := i * INV_RATE
			p1 += inc1
			p2 += inc2
			var swell := minf(1.0, t * 2.8) * (0.93 + 0.07 * sin(TAU * 0.6 * t))
			var s1 := sin(p1)
			var c1 := cos(p1)
			var v1 := s1 + 0.68 * s1 * c1 + 0.14 * s1 * (3.0 - 4.0 * s1 * s1)
			var s2 := sin(p2)
			var c2 := cos(p2)
			var v2 := s2 + 0.68 * s2 * c2 + 0.14 * s2 * (3.0 - 4.0 * s2 * s2)
			buf[i] += (v1 + v2) * swell * 0.14
	var low := 0.0
	var a := 1.0 - exp(-TAU * 1500.0 * INV_RATE)
	for i in n:
		low += a * (buf[i] - low)
		buf[i] = low
	declick(normalize(buf, 0.6), 64, 2000)
	_store(key, buf)
	return buf


static func sub(midi: int, n: int) -> PackedFloat32Array:
	var buf := buffer(n)
	var f := Harmony.hz(midi)
	var inc := TAU * f * INV_RATE
	var phase := 0.0
	for i in n:
		var t := i * INV_RATE
		phase += inc
		var s := sin(phase)
		var body := tanh((s + 0.14 * sin(phase * 2.0)) * 1.16)
		buf[i] = body * minf(1.0, t * 220.0) * exp(-t * 0.35)
	return declick(normalize(buf, 0.8), 64, 600)


static func reese(midi: int, n: int) -> PackedFloat32Array:
	var buf := buffer(n)
	var f := Harmony.hz(midi)
	var p1 := 0.0
	var p2 := 0.37
	var p3 := 0.71
	var psub := 0.0
	var low := 0.0
	var band := 0.0
	for i in n:
		var t := i * INV_RATE
		p1 = fposmod(p1 + f * 1.0082 * INV_RATE, 1.0)
		p2 = fposmod(p2 + f * 0.9918 * INV_RATE, 1.0)
		p3 = fposmod(p3 + f * 2.0 * INV_RATE, 1.0)
		psub += TAU * f * INV_RATE
		var x := (2.0 * p1 - 1.0) + (2.0 * p2 - 1.0) + (2.0 * p3 - 1.0) * 0.28
		var cutoff := 240.0 + 940.0 * (0.5 + 0.5 * sin(TAU * 1.4 * t - 1.2)) * exp(-t * 0.8) + 180.0
		var g := 2.0 * sin(PI * cutoff * INV_RATE)
		low += g * band
		var high := x - low - 0.52 * band
		band += g * high
		buf[i] = tanh(low * 0.95 + sin(psub) * 0.42) * minf(1.0, t * 250.0)
	return declick(normalize(buf, 0.75), 64, 800)


static func keys(midi: int, n: int) -> PackedFloat32Array:
	var buf := buffer(n)
	var f := Harmony.hz(midi)
	var inc1 := TAU * f * INV_RATE
	var inc2 := TAU * f * 1.0014 * INV_RATE
	var p1 := 0.0
	var p2 := 0.21
	for i in n:
		var t := i * INV_RATE
		p1 += inc1
		p2 += inc2
		var index := 0.85 * exp(-t * 6.5) + 0.14
		var warm := sin(p1 + index * sin(p1)) * 0.65 + sin(p2) * 0.35
		var tine := sin(p1 * 3.0) * 0.13 * exp(-t * 18.0) + sin(p1 * 7.0) * 0.04 * exp(-t * 55.0)
		var trem := 0.95 + 0.05 * sin(TAU * 4.2 * t)
		buf[i] = tanh((warm + tine) * 1.12) * trem * minf(1.0, t * 420.0) * exp(-t * 1.05)
	return declick(normalize(buf, 0.6), 16, 1500)


static func lead(midi: int, n: int, scoop_depth := 0.03, vib_rate := 5.6, vib_depth := 0.0055, vib_delay := 0.16) -> PackedFloat32Array:
	var buf := buffer(n)
	var f := Harmony.hz(midi)
	var rng := _rng(midi)
	var phase := 0.0
	var air := 0.0
	var lp_low := 0.0
	var lp_band := 0.0
	var base_cut := clampf(f * 3.0, 900.0, 2400.0)
	var peak_cut := clampf(f * 4.6, 1400.0, 3400.0)
	var scoop_e := 1.0
	var scoop_k := exp(-26.0 * INV_RATE)
	var idx_e := 1.0
	var idx_k := exp(-4.5 * INV_RATE)
	var cut_e := 1.0
	var cut_k := exp(-5.0 * INV_RATE)
	var puff_e := 1.0
	var puff_k := exp(-16.0 * INV_RATE)
	var env_e := 1.0
	var env_k := exp(-6.0 * INV_RATE)
	var tail_e := 1.0
	var tail_k := exp(-0.24 * INV_RATE)
	for i in n:
		var t := i * INV_RATE
		var vibrato := 0.0
		if t > vib_delay:
			vibrato = vib_depth * sin(TAU * vib_rate * (t - vib_delay)) * minf(1.0, (t - vib_delay) * 5.0)
		var freq := f * (1.0 + vibrato - scoop_depth * scoop_e)
		phase += TAU * freq * INV_RATE
		var breath := minf(1.0, t * 38.0)
		var index := 0.38 + 0.56 * breath * (0.72 + 0.28 * idx_e)
		var sp := sin(phase)
		var cp := cos(phase)
		var reed := sin(phase + index * sp) + 0.72 * sp * cp + 0.11 * sp * (3.0 - 4.0 * sp * sp)
		var cutoff := lerpf(base_cut, peak_cut, breath * (0.65 + 0.35 * cut_e))
		var g := 2.0 * sin(PI * cutoff * INV_RATE)
		lp_low += g * lp_band
		lp_band += g * (reed - lp_low - 0.78 * lp_band)
		air += (rng.randf_range(-1.0, 1.0) - air) * 0.22
		var puff := air * (0.015 + 0.045 * puff_e)
		var horn := tanh((lp_low + lp_band * 0.18) * 0.85)
		buf[i] = (horn + puff) * breath * (0.94 + 0.06 * env_e) * tail_e
		scoop_e *= scoop_k
		idx_e *= idx_k
		cut_e *= cut_k
		puff_e *= puff_k
		env_e *= env_k
		tail_e *= tail_k
	return declick(normalize(buf, 0.6), 32, 600)


static func bell(midi: int, n: int) -> PackedFloat32Array:
	var buf := buffer(n)
	var f := Harmony.hz(midi)
	var phase := 0.0
	var shimmer := 0.0
	var inc := TAU * f * INV_RATE
	var inc_shimmer := TAU * f * 2.0028 * INV_RATE
	for i in n:
		var t := i * INV_RATE
		phase += inc
		shimmer += inc_shimmer
		var index := 1.15 * exp(-t * 12.0) + 0.1
		var body := sin(phase + index * sin(phase * 2.0)) * 0.72
		var oct := sin(shimmer) * 0.2 * exp(-t * 4.5)
		var ping := sin(phase * 3.0) * 0.11 * exp(-t * 15.0)
		buf[i] = (body + oct + ping) * minf(1.0, t * 900.0) * exp(-t * 3.1)
	return declick(normalize(buf, 0.6), 8, 1500)


static func mallet(midi: int, n: int) -> PackedFloat32Array:
	var buf := buffer(n)
	var f := Harmony.hz(midi)
	var rng := _rng(midi + 101)
	var phase := 0.0
	var low := 0.0
	var inc := TAU * f * INV_RATE
	for i in n:
		var t := i * INV_RATE
		phase += inc
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.14
		var bar := sin(phase) * exp(-t * 4.6) + 0.16 * sin(phase * 2.0) * exp(-t * 11.0) + 0.3 * sin(phase * 4.0) * exp(-t * 22.0)
		var knock := low * exp(-t * 145.0) * 0.22
		buf[i] = (bar + knock) * minf(1.0, t * 950.0)
	return declick(normalize(buf, 0.6), 8, 1200)


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


static func clav(midi: int, n: int) -> PackedFloat32Array:
	var buf := buffer(n)
	var f := Harmony.hz(midi)
	var p1 := 0.0
	var p2 := 0.17
	var low := 0.0
	var band := 0.0
	for i in n:
		var t := i * INV_RATE
		p1 = fposmod(p1 + f * INV_RATE, 1.0)
		p2 = fposmod(p2 + f * 1.0018 * INV_RATE, 1.0)
		var x := (1.0 if p1 < 0.22 else -0.28) * 0.72 + (1.0 if p2 < 0.28 else -0.3) * 0.32
		var cutoff := 620.0 + 3400.0 * exp(-t * 26.0)
		var g := 2.0 * sin(PI * minf(cutoff, 5200.0) * INV_RATE)
		low += g * band
		band += g * (x - low - 0.44 * band)
		buf[i] = tanh((low * 1.05 + band * 0.32) * 1.15) * minf(1.0, t * 1500.0) * exp(-t * 6.8)
	return declick(normalize(buf, 0.6), 8, 600)


static func brass(midi: int, n: int) -> PackedFloat32Array:
	var buf := buffer(n)
	var f := Harmony.hz(midi)
	var p1 := 0.0
	var p2 := 0.33
	var p3 := 0.67
	var psub := 0.0
	var low := 0.0
	var band := 0.0
	for i in n:
		var t := i * INV_RATE
		p1 = fposmod(p1 + f * 1.0052 * INV_RATE, 1.0)
		p2 = fposmod(p2 + f * 0.9948 * INV_RATE, 1.0)
		p3 = fposmod(p3 + f * INV_RATE, 1.0)
		psub += TAU * f * 0.5 * INV_RATE
		var x := ((2.0 * p1 - 1.0) + (2.0 * p2 - 1.0) + (2.0 * p3 - 1.0)) * 0.45
		var swell := minf(1.0, t * 24.0)
		var bite := 1.0 + 0.28 * exp(-t * 26.0)
		var cutoff := minf((320.0 + 2150.0 * swell * (0.62 + 0.38 * exp(-t * 5.5))) * bite, 5500.0)
		var g := 2.0 * sin(PI * cutoff * INV_RATE)
		low += g * band
		band += g * (x - low - 0.58 * band)
		buf[i] = tanh((low + sin(psub) * 0.24) * 1.05) * swell * exp(-t * 0.58)
	return declick(normalize(buf, 0.6), 32, 800)


static func talk(midi: int, n: int) -> PackedFloat32Array:
	var buf := buffer(n)
	var f := Harmony.hz(midi)
	var phase := 0.0
	var psub := 0.0
	var l1 := 0.0
	var b1 := 0.0
	var l2 := 0.0
	var b2 := 0.0
	for i in n:
		var t := i * INV_RATE
		var vib := 1.0 + 0.0055 * sin(TAU * 5.2 * t) * minf(1.0, t * 4.0)
		phase = fposmod(phase + f * vib * INV_RATE, 1.0)
		psub += TAU * f * vib * INV_RATE
		var x := (2.0 * phase - 1.0) * 0.8 + sin(psub) * 0.35
		var vowel := minf(1.0, t * 2.8)
		var f1 := lerpf(340.0, 720.0, minf(1.0, vowel * 2.0)) if vowel < 0.5 else lerpf(720.0, 420.0, (vowel - 0.5) * 2.0)
		var f2 := lerpf(850.0, 1220.0, minf(1.0, vowel * 2.0)) if vowel < 0.5 else lerpf(1220.0, 1980.0, (vowel - 0.5) * 2.0)
		var g1 := 2.0 * sin(PI * f1 * INV_RATE)
		var g2 := 2.0 * sin(PI * f2 * INV_RATE)
		l1 += g1 * b1
		b1 += g1 * (x - l1 - 0.26 * b1)
		l2 += g2 * b2
		b2 += g2 * (x - l2 - 0.28 * b2)
		var voice := tanh((b1 * 0.95 + b2 * 0.62 + l1 * 0.34) * 1.15)
		buf[i] = voice * minf(1.0, t * 55.0) * exp(-t * 0.48)
	return declick(normalize(buf, 0.6), 32, 800)


static func fbass(midi: int, n: int) -> PackedFloat32Array:
	var buf := buffer(n)
	var f := Harmony.hz(midi)
	var phase := 0.0
	var psub := 0.0
	var low := 0.0
	var band := 0.0
	for i in n:
		var t := i * INV_RATE
		phase = fposmod(phase + f * INV_RATE, 1.0)
		psub += TAU * f * INV_RATE
		var x := (2.0 * phase - 1.0) * 0.62 + (1.0 if phase < 0.5 else -1.0) * 0.38
		var cutoff := 210.0 + 1950.0 * exp(-t * 17.0)
		var g := 2.0 * sin(PI * cutoff * INV_RATE)
		low += g * band
		band += g * (x - low - 0.44 * band)
		buf[i] = tanh((low * 1.15 + sin(psub) * 0.48) * 1.25) * minf(1.0, t * 900.0) * exp(-t * 3.3)
	return declick(normalize(buf, 0.75), 16, 600)


static func organ_chord(voicing: Array) -> PackedFloat32Array:
	var key := "organ:%s" % str(voicing)
	var hit = _cached(key)
	if hit != null:
		return hit
	var n := HOLD
	var buf := buffer(n)
	var bars := [[0.5, 0.52], [1.0, 1.0], [1.5, 0.22], [2.0, 0.55], [3.0, 0.28], [4.0, 0.18]]
	for midi in voicing:
		var f := Harmony.hz(midi)
		for bar in bars:
			var inc: float = TAU * f * bar[0] * INV_RATE
			var amp: float = bar[1] * 0.18
			var phase := float((midi * 13) % 17) * 0.19
			for i in n:
				phase += inc
				buf[i] += sin(phase) * amp
	var rng := _rng(21)
	var click_lp := 0.0
	for i in n:
		var t := i * INV_RATE
		click_lp += (rng.randf_range(-1.0, 1.0) - click_lp) * 0.35
		var click := click_lp * exp(-t * 260.0) * 0.24
		var leslie := 0.86 + 0.1 * sin(TAU * 6.2 * t) + 0.04 * sin(TAU * 1.15 * t)
		buf[i] = tanh((buf[i] * leslie + click) * 1.18) * minf(1.0, t * 320.0)
	declick(normalize(buf, 0.6), 32, 2000)
	_store(key, buf)
	return buf


static func stab_chord(voicing: Array, bright: bool) -> PackedFloat32Array:
	var key := "stab%s:%s" % ["B" if bright else "D", str(voicing)]
	var hit = _cached(key)
	if hit != null:
		return hit
	var n := seconds(0.6)
	var buf := buffer(n)
	var top := 3400.0 if bright else 1050.0
	for midi in voicing:
		var f := Harmony.hz(midi + 12)
		var p1 := float(midi % 5) * 0.19
		var p2 := float(midi % 7) * 0.31
		var psub := 0.0
		var low := 0.0
		var band := 0.0
		for i in n:
			var t := i * INV_RATE
			p1 = fposmod(p1 + f * 1.0042 * INV_RATE, 1.0)
			p2 = fposmod(p2 + f * 0.9958 * INV_RATE, 1.0)
			psub += TAU * f * 0.5 * INV_RATE
			var raw := ((2.0 * p1 - 1.0) + (2.0 * p2 - 1.0)) * 0.55
			var cutoff := 280.0 + top * exp(-t * 8.5)
			var g := 2.0 * sin(PI * cutoff * INV_RATE)
			low += g * band
			band += g * (raw - low - 0.45 * band)
			buf[i] += (low + sin(psub) * 0.2) * 0.24 * exp(-t * 3.8)
	for i in n:
		buf[i] = tanh(buf[i] * 1.15)
	declick(normalize(buf, 0.6), 16, 800)
	_store(key, buf)
	return buf


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
	var n := seconds(0.24)
	var buf := buffer(n)
	var rng := _rng(32)
	var low := 0.0
	var band := 0.0
	var g := 2.0 * sin(PI * 1450.0 * INV_RATE)
	var taps := [0.0, 0.009, 0.019, 0.029]
	for i in n:
		var t := i * INV_RATE
		var burst := 0.0
		for tap in taps:
			if t >= tap:
				burst += exp(-(t - tap) * (240.0 if tap < 0.025 else 16.0))
		var x := rng.randf_range(-1.0, 1.0) * burst
		low += g * band
		band += g * (x - low - 0.55 * band)
		buf[i] = tanh((band * 0.85 + x * 0.12) * 1.2)
	return declick(normalize(buf, 0.8), 4, 400)


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


static func tom(midi: int, n: int) -> PackedFloat32Array:
	var buf := buffer(n)
	var f := Harmony.hz(midi)
	var rng := _rng(41)
	var phase := 0.0
	var mode2 := 0.0
	var low := 0.0
	for i in n:
		var t := i * INV_RATE
		var bend := 1.0 + 0.38 * exp(-t * 38.0)
		phase += TAU * f * bend * INV_RATE
		mode2 += TAU * f * 1.59 * bend * INV_RATE
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.14
		var body := sin(phase) * exp(-t * 5.2) + 0.28 * sin(mode2) * exp(-t * 11.5)
		var felt := low * exp(-t * 85.0) * 0.55
		buf[i] = (tanh(1.55 * body) + felt) * minf(1.0, t * 1300.0)
	return declick(normalize(buf, 0.8), 8, 1200)


static func sub808(midi: int, n: int) -> PackedFloat32Array:
	var buf := buffer(n)
	var f := Harmony.hz(midi)
	var phase := 0.0
	for i in n:
		var t := i * INV_RATE
		phase += TAU * f * (1.0 + 1.15 * exp(-t * 34.0)) * INV_RATE
		var core := sin(phase) + 0.14 * sin(phase * 2.0) * exp(-t * 3.0)
		buf[i] = tanh(1.75 * core) * minf(1.0, t * 750.0) * exp(-t * 2.1)
	return declick(normalize(buf, 0.85), 16, 1500)


static func buzz(midi: int, n: int, loose: float) -> PackedFloat32Array:
	var buf := buffer(n)
	var rng := _rng(midi * 7 + int(loose * 100.0))
	var f := Harmony.hz(midi) * Harmony.ratio(rng.randf_range(-0.4, 0.4) * loose)
	var phase := 0.0
	var prev_x := 0.0
	var prev_y := 0.0
	var drift := 0.0
	for i in n:
		var t := i * INV_RATE
		drift += (rng.randf_range(-1.0, 1.0) - drift) * 0.0005
		phase = fposmod(phase + f * (1.0 + drift * loose * 0.2) * INV_RATE, 1.0)
		var x := 2.0 * phase - 1.0
		prev_y = 0.9 * (prev_y + x - prev_x)
		prev_x = x
		var in_step := float(posmod(i, Harmony.STEP)) / Harmony.STEP
		var gate := 1.0 if in_step < lerpf(0.62, 0.9, loose) else 0.15
		buf[i] = prev_y * gate * minf(1.0, t * 300.0)
	var smooth := 0.0
	for i in n:
		smooth += (buf[i] - smooth) * 0.35
		buf[i] = smooth
	return declick(normalize(buf, 0.5), 32, 800)


static func chime(midi: int, n: int) -> PackedFloat32Array:
	var buf := buffer(n)
	var f := Harmony.hz(midi)
	var phase := 0.0
	for i in n:
		var t := i * INV_RATE
		phase += TAU * f * (1.0 - 0.00173 * minf(1.0, t / 1.8)) * INV_RATE
		var glass := sin(phase) + 0.09 * sin(phase * 2.0) * exp(-t * 5.5) + 0.04 * sin(phase * 3.0) * exp(-t * 18.0)
		buf[i] = glass * minf(1.0, t * 240.0) * exp(-t * 1.15)
	return declick(normalize(buf, 0.6), 16, 3000)


static func wob(midi: int, period: int, vowel := "wub") -> PackedFloat32Array:
	var n := maxi(256, int(ceil(period / 128.0)) * 128)
	var key := "wob:%d:%d:%s" % [midi, n, vowel]
	var hit = _cached(key)
	if hit != null:
		return hit
	var buf := buffer(n)
	var f := Harmony.hz(midi)
	var p1 := 0.0
	var p2 := 0.31
	var p3 := 0.0
	var low := 0.0
	var band := 0.0
	var fl := 0.0
	var fb := 0.0
	var talk := vowel == "yoi"
	for i in n:
		var x := float(i) / n
		var lfo := sin(PI * x)
		lfo *= lfo
		p1 = fposmod(p1 + f * 1.009 * INV_RATE, 1.0)
		p2 = fposmod(p2 + f * 0.991 * INV_RATE, 1.0)
		p3 = fposmod(p3 + f * 0.5 * INV_RATE, 1.0)
		var raw := (2.0 * p1 - 1.0) + (2.0 * p2 - 1.0) + (0.8 if p3 < 0.5 else -0.8)
		var cutoff := 110.0 + 2900.0 * pow(lfo, 1.4)
		var g := 2.0 * sin(PI * minf(cutoff, 5000.0) * INV_RATE)
		low += g * band
		band += g * (raw - low - 0.25 * band)
		var y := low
		if talk:
			var formant := lerpf(700.0, 2200.0, x)
			var gf := 2.0 * sin(PI * formant * INV_RATE)
			fl += gf * fb
			fb += gf * (raw - fl - 0.2 * fb)
			y = low * 0.7 + fb * 0.5 * lfo
		buf[i] = tanh(y * 1.6) * (0.55 + 0.45 * lfo)
	declick(normalize(buf, 0.7), 48, 96)
	_store(key, buf)
	return buf


static func steam_whistle(midi: int, n: int) -> PackedFloat32Array:
	var buf := buffer(n)
	var phase := 0.0
	var step_hz := TAU * Harmony.hz(midi) / Harmony.RATE
	var bend := Harmony.ratio(2)
	var rng := _rng(0x57EA)
	for i in n:
		phase += step_hz * lerpf(1.0, bend, float(i) / n)
		buf[i] = sin(phase) + 0.12 * rng.randf_range(-1.0, 1.0)
	return buf


static func choir(midi: int, vowel: String, n: int) -> PackedFloat32Array:
	var buf := buffer(n)
	var f := Harmony.hz(midi)
	var rng := _rng(midi + (203 if vowel == "ah" else 211))
	var p1 := 0.0
	var p2 := 0.37
	var p3 := 0.71
	var l1 := 0.0
	var b1 := 0.0
	var l2 := 0.0
	var b2 := 0.0
	var air := 0.0
	var f1 := 760.0 if vowel == "ah" else 360.0
	var f2 := 1150.0 if vowel == "ah" else 620.0
	var g1 := 2.0 * sin(PI * f1 * INV_RATE)
	var g2 := 2.0 * sin(PI * f2 * INV_RATE)
	for i in n:
		var t := i * INV_RATE
		var vib := 1.0 + 0.0038 * sin(TAU * 5.1 * t) * minf(1.0, t * 2.5)
		p1 = fposmod(p1 + f * vib * 1.004 * INV_RATE, 1.0)
		p2 = fposmod(p2 + f * vib * 0.996 * INV_RATE, 1.0)
		p3 = fposmod(p3 + f * vib * INV_RATE, 1.0)
		var raw := ((2.0 * p1 - 1.0) + (2.0 * p2 - 1.0) + (2.0 * p3 - 1.0)) * 0.65
		l1 += g1 * b1
		b1 += g1 * (raw - l1 - 0.22 * b1)
		l2 += g2 * b2
		b2 += g2 * (raw - l2 - 0.24 * b2)
		air += (rng.randf_range(-1.0, 1.0) - air) * 0.16
		var env := minf(1.0, t / 0.14) * (1.0 - 0.28 * float(i) / n)
		buf[i] = tanh((b1 * 0.82 + b2 * 0.56 + l1 * 0.28 + air * 0.05) * 1.1) * env
	return declick(normalize(buf, 0.6), 32, 1200)


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
		"brush":
			buf = brush()
		"geiger":
			buf = geiger()
		"choke":
			buf = choke()
		_:
			buf = crash()
	_store(key, buf)
	return buf


const DRUMS := ["kick", "snare", "hat", "open_hat", "ride", "crash", "anvil", "clap", "boom", "brush", "geiger", "choke"]


static func brush() -> PackedFloat32Array:
	var n := seconds(0.22)
	var buf := buffer(n)
	var rng := _rng(51)
	var low := 0.0
	var band := 0.0
	var g := 2.0 * sin(PI * 4200.0 * INV_RATE)
	for i in n:
		var t := i * INV_RATE
		low += g * band
		band += g * (rng.randf_range(-1.0, 1.0) - low - 0.8 * band)
		buf[i] = band * minf(1.0, t / 0.03) * exp(-t * 14.0)
	return declick(normalize(buf, 0.7), 32, 600)


static func geiger() -> PackedFloat32Array:
	var n := seconds(0.03)
	var buf := buffer(n)
	var rng := _rng(52)
	for i in n:
		var t := i * INV_RATE
		buf[i] = rng.randf_range(-1.0, 1.0) * exp(-t * 900.0) + sin(TAU * 90.0 * t) * exp(-t * 120.0) * 0.4
	return declick(normalize(buf, 0.7), 2, 200)


static func choke() -> PackedFloat32Array:
	var buf := crash().slice(0, seconds(0.11))
	var n := buf.size()
	for i in n:
		var t := i * INV_RATE
		if t > 0.06:
			buf[i] *= exp(-(t - 0.06) * 90.0)
	return declick(normalize(buf, 0.7), 4, 64)


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
		var source := note(instrument, int(event[1]) + score_transpose)
		var length := mini(source.size(), int(event[2]) * step + seconds(0.25))
		var count := mini(length, buf.size() - start)
		var release := mini(1200, count)
		for i in count:
			var fade := 1.0 if i < count - release else float(count - i) / release
			buf[start + i] += source[i] * gain * fade
	return buf

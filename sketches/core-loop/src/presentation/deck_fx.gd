extends RefCounted

# Synthesized festival-deck one-shots (design-v3/SOUND-BIBLE.md, "The moves"):
# snare-roll and noise-riser builds, breath downlifter, pre-drop swell, and drop impact.
# Every buffer is deterministic (fixed seed), 44100 Hz stereo, cached by kind and tempo,
# and bandstop-filtered across 1.8 to 4.4 kHz so the 2 to 4 kHz warning lane stays clear.
# No pitched voices: the only tone is the impact's short sub sweep (125 to 40 Hz, 0.34 s).

const RATE := 44100
const RATE_F := 44100.0
const PEAK_CAP := 0.58

# Relative levels ported from the audition prototype (dj_proto.reference.py fight_arc).
const ROLL_GAIN := 0.28
const RISER_GAIN := 0.08
const DOWNLIFTER_GAIN := 0.02
const SWELL_GAIN := 0.07
const IMPACT_CRASH_GAIN := 0.13
const IMPACT_BOOM_GAIN := 0.26

# Warning-lane notch: 4th-order Butterworth bandstop across 1800 to 4400 Hz.
const NOTCH_LO_HZ := 1800.0
const NOTCH_HI_HZ := 4400.0
const NOTCH_ORDER := 4

# Build tier table: [progress_start, progress_end, riser_f0_hz, riser_f1_hz, steps]
# where steps are [beats, division] (1 quarter, 2 eighth, 4 sixteenth, 8 thirty-second).
const BUILD_TIERS := [
	{"p0": 0.0, "p1": 0.33, "f0": 350.0, "f1": 1050.0, "steps": [[4, 1]]},
	{"p0": 0.33, "p1": 0.67, "f0": 1050.0, "f1": 3100.0, "steps": [[4, 2]]},
	{"p0": 0.67, "p1": 1.0, "f0": 3100.0, "f1": 9000.0, "steps": [[3, 4], [1, 8]]},
]

static var _cache := {}
static var _notch_sos: Array = []
static var _snare_bp_sos: Array = []


static func clear_cache() -> void:
	_cache.clear()


static func build(tier: int, bar_frames: int, beat_frames: int) -> PackedVector2Array:
	var t := clampi(tier, 0, BUILD_TIERS.size() - 1)
	if bar_frames <= 0 or beat_frames <= 0:
		return PackedVector2Array()
	var key := "build:%d:%d:%d" % [t, bar_frames, beat_frames]
	if _cache.has(key):
		return _cache[key]
	var row: Dictionary = BUILD_TIERS[t]
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x17200 + t * 97 + bar_frames
	var p0 := float(row["p0"])
	var p1 := float(row["p1"])
	var out := _riser_noise(bar_frames, float(row["f0"]), float(row["f1"]), p0, p1, RISER_GAIN, rng)
	var roll_mono := _snare_roll(bar_frames, beat_frames, row["steps"], p0, p1, rng)
	for i in bar_frames:
		var s := roll_mono[i] * ROLL_GAIN
		out[i] += Vector2(s, s)
	_edge_fade(out, 48, 64)
	_apply_sos_stereo(out, _get_notch_sos())
	_cap_peak(out)
	_cache[key] = out
	return out


static func downlifter(bar_frames: int) -> PackedVector2Array:
	if bar_frames <= 0:
		return PackedVector2Array()
	var key := "down:%d" % bar_frames
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x17210 + bar_frames
	var out := _sweep_noise(bar_frames, 7000.0, 250.0, rng)
	var inv_n := 1.0 / float(bar_frames)
	for i in bar_frames:
		var u := float(i) * inv_n
		var rise := pow(u, 1.8)
		var atk := rise / maxf(rise, 0.001)
		var amp := atk * pow(1.0 - u, 1.5) * DOWNLIFTER_GAIN
		out[i] *= amp
	_edge_fade(out, 64, 128)
	_apply_sos_stereo(out, _get_notch_sos())
	_cap_peak(out)
	_cache[key] = out
	return out


static func swell(frames: int) -> PackedVector2Array:
	if frames <= 0:
		return PackedVector2Array()
	var key := "swell:%d" % frames
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x17220 + frames
	var out := PackedVector2Array()
	out.resize(frames)
	for i in frames:
		out[i] = Vector2(rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0))
	_apply_sos_stereo(out, [_highpass_biquad(2500.0)])
	var inv_n := 1.0 / float(frames)
	for i in frames:
		var u := float(i) * inv_n
		out[i] *= u * u * u * SWELL_GAIN
	_edge_fade(out, 32, 32)
	_apply_sos_stereo(out, _get_notch_sos())
	_cap_peak(out)
	_cache[key] = out
	return out


static func impact() -> PackedVector2Array:
	var key := "impact"
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x17230
	var m := int(2.2 * RATE)
	var out := PackedVector2Array()
	out.resize(m)
	for i in m:
		out[i] = Vector2(rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0))
	_apply_sos_stereo(out, [_highpass_biquad(3200.0)])
	for i in m:
		var tc := float(i) / RATE_F
		var env := exp(-tc / 0.6) * IMPACT_CRASH_GAIN
		if i < 32:
			env *= float(i) / 31.0
		out[i] *= env
	_edge_fade(out, 0, 256)
	# Short sub sweep: 125 Hz down to 40 Hz over 0.34 s (<= 0.35 s, SOUND-BIBLE rule 2).
	var n := int(0.34 * RATE)
	var phase := 0.0
	var fade_start := n - 256
	for i in n:
		var t := float(i) / RATE_F
		var freq := 40.0 + 85.0 * exp(-t / 0.035)
		phase += TAU * freq / RATE_F
		var b := sin(phase) * exp(-t / 0.11) * IMPACT_BOOM_GAIN
		if i >= fade_start:
			b *= float(n - 1 - i) / 255.0
		out[i] += Vector2(b, b)
	_apply_sos_stereo(out, _get_notch_sos())
	_cap_peak(out)
	_cache[key] = out
	return out


# --- Synthesis helpers ----------------------------------------------------------------


static func _snare_hit(pitch: float, vel: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(0.15 * RATE)
	var noise := PackedFloat32Array()
	noise.resize(n)
	for i in n:
		noise[i] = rng.randfn(0.0, 1.0)
	_apply_sos_mono(noise, _get_snare_bp_sos())
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE_F
		var freq := 185.0 * pitch * (1.0 + 0.6 * exp(-t / 0.012))
		phase += TAU * freq / RATE_F
		var body := sin(phase) * exp(-t / 0.045)
		var wire := noise[i] * exp(-t / 0.055)
		var x := 0.55 * body + 0.5 * wire
		if i < 64:
			x *= float(i) / 63.0
		out[i] = x * vel
	return out


static func _snare_roll(length: int, beat: int, steps: Array, p0: float, p1: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(length)
	var total_beats := 0.0
	for s in steps:
		total_beats += float(s[0])
	var total := maxf(total_beats * float(beat), 1.0)
	var pos := 0.0
	for s in steps:
		var beats := float(s[0])
		var div := float(s[1])
		var hits := int(round(beats * div))
		for h in hits:
			var at := int(pos + float(h) * float(beat) / div)
			if at >= length:
				continue
			var u := clampf(float(at) / total, 0.0, 1.0)
			var prog := lerpf(p0, p1, u)
			var hit := _snare_hit(1.0 + 0.45 * prog, 0.35 + 0.65 * prog, rng)
			var take := mini(hit.size(), length - at)
			for i in take:
				out[at + i] += hit[i]
		pos += beats * float(beat)
	return out


static func _riser_noise(length: int, f0: float, f1: float, p0: float, p1: float, gain: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var out := _sweep_noise(length, f0, f1, rng)
	var inv_n := 1.0 / float(maxi(length, 1))
	for i in length:
		var prog := lerpf(p0, p1, float(i) * inv_n)
		out[i] *= pow(prog, 1.8) * gain
	return out


static func _sweep_noise(length: int, f0: float, f1: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(length)
	var block := 256
	var denom := float(maxi(length - 1, 1))
	var ratio := f1 / maxf(f0, 1.0)
	var xl1 := 0.0
	var xl2 := 0.0
	var yl1 := 0.0
	var yl2 := 0.0
	var xr1 := 0.0
	var xr2 := 0.0
	var yr1 := 0.0
	var yr2 := 0.0
	var i := 0
	while i < length:
		var f := f0 * pow(ratio, float(i) / denom)
		var lo := clampf(f * 0.75, 40.0, RATE_F * 0.42)
		var hi := clampf(f * 1.35, lo + 20.0, RATE_F * 0.45)
		var c := _bandpass1_biquad(lo, hi)
		var b0 := c[0]
		var b2 := c[2]
		var a1 := c[3]
		var a2 := c[4]
		var end := mini(i + block, length)
		for k in range(i, end):
			var nl := rng.randfn(0.0, 1.0)
			var nr := rng.randfn(0.0, 1.0)
			var yl := b0 * nl + b2 * xl2 - a1 * yl1 - a2 * yl2
			var yr := b0 * nr + b2 * xr2 - a1 * yr1 - a2 * yr2
			xl2 = xl1
			xl1 = nl
			yl2 = yl1
			yl1 = yl
			xr2 = xr1
			xr1 = nr
			yr2 = yr1
			yr1 = yr
			out[k] = Vector2(yl, yr)
		i = end
	return out


static func _edge_fade(buf: PackedVector2Array, fade_in: int, fade_out: int) -> void:
	var n := buf.size()
	var fi := mini(fade_in, n)
	if fi > 1:
		var inv := 1.0 / float(fi - 1)
		for i in fi:
			buf[i] *= float(i) * inv
	var fo := mini(fade_out, n)
	if fo > 1:
		var inv := 1.0 / float(fo - 1)
		var start := n - fo
		for i in fo:
			buf[start + i] *= float(fo - 1 - i) * inv


static func _cap_peak(buf: PackedVector2Array) -> void:
	var peak := 0.0
	for v in buf:
		peak = maxf(peak, maxf(absf(v.x), absf(v.y)))
	if peak > PEAK_CAP:
		var scale := PEAK_CAP / peak
		for i in buf.size():
			buf[i] *= scale


# --- Butterworth biquad cascades ------------------------------------------------------


static func _get_notch_sos() -> Array:
	if _notch_sos.is_empty():
		_notch_sos = _butter_band_sos(NOTCH_ORDER, NOTCH_LO_HZ, NOTCH_HI_HZ, true)
	return _notch_sos


static func _get_snare_bp_sos() -> Array:
	if _snare_bp_sos.is_empty():
		_snare_bp_sos = _butter_band_sos(2, 1400.0, 9000.0, false)
	return _snare_bp_sos


static func _highpass_biquad(hz: float) -> PackedFloat64Array:
	var w := TAU * hz / RATE_F
	var cw := cos(w)
	var alpha := sin(w) / (2.0 * sqrt(0.5))
	var a0 := 1.0 + alpha
	return PackedFloat64Array([(1.0 + cw) * 0.5 / a0, -(1.0 + cw) / a0, (1.0 + cw) * 0.5 / a0, -2.0 * cw / a0, (1.0 - alpha) / a0])


static func _bandpass1_biquad(lo_hz: float, hi_hz: float) -> PackedFloat64Array:
	var wa1 := tan(PI * lo_hz / RATE_F)
	var wa2 := tan(PI * hi_hz / RATE_F)
	var bw := wa2 - wa1
	var w02 := wa1 * wa2
	var a0 := 1.0 + bw + w02
	return PackedFloat64Array([bw / a0, 0.0, -bw / a0, 2.0 * (w02 - 1.0) / a0, (1.0 - bw + w02) / a0])


# Exact bilinear-transform even-order Butterworth bandpass or bandstop cascade.
static func _butter_band_sos(order: int, lo_hz: float, hi_hz: float, bandstop: bool) -> Array:
	var wa1 := tan(PI * lo_hz / RATE_F)
	var wa2 := tan(PI * hi_hz / RATE_F)
	var bw := wa2 - wa1
	var w02 := wa1 * wa2
	var c0 := (1.0 - w02) / (1.0 + w02)
	var wc := 2.0 * atan(sqrt(w02))
	var cos_wc := cos(wc)
	var sin_wc := sin(wc)
	var cos_2wc := cos(2.0 * wc)
	var sin_2wc := sin(2.0 * wc)
	var sos: Array = []
	for k in order / 2:
		var theta := PI * float(2 * k + order + 1) / float(2 * order)
		var pr := cos(theta)
		var pi_val := sin(theta)
		var qr := bw * pr
		var qi := (-bw * pi_val) if bandstop else (bw * pi_val)
		var dr := qr * qr - qi * qi - 4.0 * w02
		var di := 2.0 * qr * qi
		var rmag := sqrt(dr * dr + di * di)
		var rr := sqrt(maxf(0.0, 0.5 * (rmag + dr)))
		var ri := sqrt(maxf(0.0, 0.5 * (rmag - dr))) * (-1.0 if di < 0.0 else 1.0)
		for sgn: float in [1.0, -1.0]:
			var sr := 0.5 * (qr + sgn * rr)
			var si := 0.5 * (qi + sgn * ri)
			var den := (1.0 - sr) * (1.0 - sr) + si * si
			var zr := (1.0 - sr * sr - si * si) / den
			var zi := (2.0 * si) / den
			var a1 := -2.0 * zr
			var a2 := zr * zr + zi * zi
			if bandstop:
				var g := (1.0 + a1 + a2) / maxf(2.0 - 2.0 * c0, 1e-12)
				sos.append(PackedFloat64Array([g, -2.0 * c0 * g, g, a1, a2]))
			else:
				var nr := 1.0 - cos_2wc
				var ni := sin_2wc
				var dr_w := 1.0 + a1 * cos_wc + a2 * cos_2wc
				var di_w := -(a1 * sin_wc + a2 * sin_2wc)
				var gain_at_wc := sqrt((nr * nr + ni * ni) / maxf(dr_w * dr_w + di_w * di_w, 1e-18))
				var g := 1.0 / maxf(gain_at_wc, 1e-12)
				sos.append(PackedFloat64Array([g, 0.0, -g, a1, a2]))
	return sos


static func _apply_sos_stereo(buf: PackedVector2Array, sos: Array) -> void:
	var n := buf.size()
	for sec in sos:
		var b0: float = sec[0]
		var b1: float = sec[1]
		var b2: float = sec[2]
		var a1: float = sec[3]
		var a2: float = sec[4]
		var xl1 := 0.0
		var xl2 := 0.0
		var yl1 := 0.0
		var yl2 := 0.0
		var xr1 := 0.0
		var xr2 := 0.0
		var yr1 := 0.0
		var yr2 := 0.0
		for i in n:
			var x := buf[i]
			var yl := b0 * x.x + b1 * xl1 + b2 * xl2 - a1 * yl1 - a2 * yl2
			var yr := b0 * x.y + b1 * xr1 + b2 * xr2 - a1 * yr1 - a2 * yr2
			xl2 = xl1
			xl1 = x.x
			yl2 = yl1
			yl1 = yl
			xr2 = xr1
			xr1 = x.y
			yr2 = yr1
			yr1 = yr
			buf[i] = Vector2(yl, yr)


static func _apply_sos_mono(buf: PackedFloat32Array, sos: Array) -> void:
	var n := buf.size()
	for sec in sos:
		var b0: float = sec[0]
		var b1: float = sec[1]
		var b2: float = sec[2]
		var a1: float = sec[3]
		var a2: float = sec[4]
		var x1 := 0.0
		var x2 := 0.0
		var y1 := 0.0
		var y2 := 0.0
		for i in n:
			var x := buf[i]
			var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
			x2 = x1
			x1 = x
			y2 = y1
			y1 = y
			buf[i] = y

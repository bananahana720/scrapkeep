extends RefCounted

const Harmony := preload("res://src/presentation/harmony.gd")
const Synth := preload("res://src/presentation/synth.gd")

# Static recipe functions for the v3 audio audition board (tools/audio_v3_board.gd).
# Everything here is built from Synth's own rack and Harmony's own grid, the same
# rules the game's band and SfxBank cues follow, so these cues stay in the family
# even though they have no SfxBank entry of their own yet.

const ROLL_SECONDS := 0.35
const HALF_STEP := Harmony.STEP / 2.0

# The hold-to-arm roll: a snare figure that accelerates from eighths (2 steps) to
# thirty-seconds (a half step) over ROLL_SECONDS, quantized to the 32nd-note grid,
# rising in gain as it tightens. n varies the seed only (bet 1 vs bet 2 get a
# slightly different roll instead of two identical hits).
static func bet_roll(n: int) -> PackedFloat32Array:
	var total := Synth.seconds(ROLL_SECONDS)
	var buf := Synth.buffer(total)
	var hit := Synth.drum("snare")
	var rng := RandomNumberGenerator.new()
	rng.seed = 907 + n
	var t := 0.0
	while t < ROLL_SECONDS:
		var frac := t / ROLL_SECONDS
		var spacing_samples := lerpf(Harmony.STEP * 2.0, HALF_STEP, pow(frac, 1.4))
		var at := int(round(Synth.seconds(t) / HALF_STEP)) * int(HALF_STEP)
		var gain_db := lerpf(-20.0, -6.0, frac) + rng.randf_range(-0.6, 0.6)
		Synth.add_into(buf, hit, mini(at, total - 1), db_to_linear(gain_db))
		t += spacing_samples / Synth.RATE
	return buf


# The slot-machine latch: an anvil hit and one eighth of fbass on D2, then 60 ms of
# silence baked into the tail so the caller can place the payoff right after it.
static func bet_clunk() -> PackedFloat32Array:
	var eighth := Harmony.STEP * 2
	var anvil := Synth.drum("anvil")
	var bass := Synth.fbass(38, eighth)
	var silence := int(0.06 * Synth.RATE)
	var total := maxi(anvil.size(), bass.size()) + silence
	var buf := Synth.buffer(total)
	Synth.add_into(buf, anvil, 0, db_to_linear(-6.0))
	Synth.add_into(buf, bass, 0, 1.0)
	return buf


# The win: a snare crack under the rice cooker's two "done" beeps, up a fifth
# (A5 then D6), 70 ms apart.
static func bet_crack() -> PackedFloat32Array:
	var snare := Synth.drum("snare")
	var beep1 := Synth.beep(81, Synth.seconds(0.5))
	var beep2 := Synth.beep(86, Synth.seconds(0.5))
	var gap := Synth.seconds(0.07)
	var total := maxi(snare.size(), gap + beep2.size())
	var buf := Synth.buffer(total)
	Synth.add_into(buf, snare, 0, 1.0)
	Synth.add_into(buf, beep1, 0, 0.8)
	Synth.add_into(buf, beep2, gap, 0.8)
	return buf


# The loss: a dry 40 ms low-passed noise click, no pitch. The bank has no cue
# named "refusal" (checked TRIM_DB), so this is a stand-in built straight from
# noise: a one-pole low-pass at 500 Hz over a fast decay.
static func bet_refusal() -> PackedFloat32Array:
	var n := Synth.seconds(0.04)
	var buf := Synth.buffer(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4913
	var low := 0.0
	var alpha := 1.0 - exp(-TAU * 500.0 / Synth.RATE)
	for i in n:
		var t := float(i) / Synth.RATE
		low += (rng.randf_range(-1.0, 1.0) - low) * alpha
		buf[i] = low * exp(-t * 90.0)
	return Synth.declick(Synth.normalize(buf, 0.5), 4, 300)


# A one-pole low-pass, used to muffle the sunken bell.
static func _lowpass(buf: PackedFloat32Array, cutoff_hz: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(buf.size())
	var alpha := 1.0 - exp(-TAU * cutoff_hz / Synth.RATE)
	var y := 0.0
	for i in buf.size():
		y += (buf[i] - y) * alpha
		out[i] = y
	return out


# The sunken bell: Synth.bell()'s own recipe (the same one note("bell", midi) wraps,
# called directly here because note() caps the buffer at 1.0 s and this cue needs
# about 2 s), muffled through a one-pole low-pass at ~900 Hz, with its own fast decay
# (bell()'s exp(-t*3.2), see synth.gd bell()) undone and replaced with a slower
# exp(-t*SLOW_DECAY) so the ring extends to about 2 s instead of dying by ~1.4 s.
const SUNKEN_TAIL_SECONDS := 2.2
const SLOW_DECAY := 1.4
const BELL_DECAY := 3.2

static func sunken_bell(midi: int) -> PackedFloat32Array:
	var n := Synth.seconds(SUNKEN_TAIL_SECONDS)
	var raw := Synth.bell(midi, n)
	var filtered := _lowpass(raw, 900.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / Synth.RATE
		var comp := 1.0 if t <= 0.05 else exp(t * (BELL_DECAY - SLOW_DECAY))
		out[i] = filtered[i] * comp
	return Synth.declick(Synth.normalize(out, 0.6), 16, 3000)


# Fades the tail of a buffer to silence over `samples`, in place on a duplicate.
static func fade_tail(buf: PackedFloat32Array, samples: int) -> PackedFloat32Array:
	var out := buf.duplicate()
	var n := mini(samples, out.size())
	for i in n:
		var g := float(n - i) / n
		out[out.size() - n + i] *= g
	return out

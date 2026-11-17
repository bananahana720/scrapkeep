extends SceneTree

const T := preload("res://tests/support/t.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")

# The five hazard families' falling warnings (wave 44) must each be told apart from every other danger sound
# in the bank (SfxBank.DANGER_SOUNDS), and from each other, by measurement, not by reading the recipes.
#
# What is measured, per sound: the pitch where its pitched part starts, the pitch where it ends (in midi
# semitones), and how long the pitched part lasts. Pitch is read by autocorrelation on 23 ms windows of the
# bake taken down to a quarter of the rate; a window counts as pitched when its best period repeats with a
# clarity of at least 0.8. The pitched part is the longest unbroken run of pitched windows that glides (under 1.5 semitones a window).
#
# The distance rule, in plain words: two warnings are apart when their starting pitches are at least 4
# semitones apart, or their ending pitches are at least 4 semitones apart, or one's pitched part lasts at
# least half as long again as the other's. A danger sound with no clear pitch anywhere (a noise, a drum,
# a ratchet) is apart from a pure tone by its texture and is listed, not measured.

const WARNINGS := ["flood_falling_pure", "fleet_falling_pure", "boiler_falling_pure", "lightning_falling_pure", "ancient_falling_pure"]
const MIN_SEMITONES := 4.0
const MIN_LENGTH_RATIO := 1.5
const CLARITY := 0.8
const DOWN := 4
const WINDOW := 256
const STEP := 256

var _t := T.new("warning_distance_test")


func _initialize() -> void:
	var reads := {}
	var others: Array = SfxBank.DANGER_SOUNDS.duplicate()
	for id in ["threat_whistle", "threat_tick"]:
		if not id in others:
			others.append(id)
	for id in others:
		reads[id] = contour(SfxBank.samples(String(id)))
		print("READ %s %s" % [id, JSON.stringify(reads[id])])
	var looped := 0
	for w in WARNINGS:
		var a: Dictionary = reads[w]
		_t.check("%s has a clear falling pitch" % w, not a.is_empty() and float(a.start) > float(a.end), JSON.stringify(a))
		if a.is_empty():
			continue
		for other in others:
			if other == w:
				continue
			looped += 1
			var b: Dictionary = reads[other]
			if b.is_empty():
				continue
			var d_start := absf(float(a.start) - float(b.start))
			var d_end := absf(float(a.end) - float(b.end))
			var ratio := maxf(float(a.seconds), float(b.seconds)) / maxf(0.001, minf(float(a.seconds), float(b.seconds)))
			_t.check("%s is apart from %s" % [w, other], d_start >= MIN_SEMITONES or d_end >= MIN_SEMITONES or ratio >= MIN_LENGTH_RATIO,
				"start %.1f st, end %.1f st, length x%.2f" % [d_start, d_end, ratio])
	_t.check("every warning was set against every other danger sound", looped == WARNINGS.size() * (others.size() - 1), str(looped))
	quit(_t.verdict())


# {start, end (midi), seconds} of a bake's pitched part, or {} when no window is pitched.
static func contour(buf: PackedFloat32Array) -> Dictionary:
	var small := PackedFloat32Array()
	small.resize(buf.size() / DOWN)
	for i in small.size():
		var s := 0.0
		for k in DOWN:
			s += buf[i * DOWN + k]
		small[i] = s / DOWN
	var rate := float(SfxBank.RATE) / DOWN
	# The pitched part is the longest run of pitched windows in a row whose pitch glides (under 1.5 semitones
	# from one window to the next), so a drum head or a held sub under the tail is not read as the tone.
	var best: Array = []
	var run: Array = []
	var at := 0
	while at + WINDOW * 2 <= small.size():
		var midi := _pitch(small, at, rate)
		if midi > 0.0 and (run.is_empty() or absf(midi - float(run[-1][1])) < 1.5):
			run.append([at, midi])
		else:
			run = [[at, midi]] if midi > 0.0 else []
		if run.size() > best.size():
			best = run.duplicate()
		at += STEP
	if best.is_empty():
		return {}
	return {"start": snappedf(float(best[0][1]), 0.1), "end": snappedf(float(best[-1][1]), 0.1),
		"seconds": snappedf(float(int(best[-1][0]) - int(best[0][0]) + WINDOW) / rate, 0.01)}


# The midi pitch of one window by normalized autocorrelation, or 0 when its clarity is under CLARITY or it is near silent.
static func _pitch(x: PackedFloat32Array, at: int, rate: float) -> float:
	var energy := 0.0
	for i in WINDOW:
		energy += x[at + i] * x[at + i]
	if energy < 0.0005 * WINDOW:
		return 0.0
	var min_lag := int(rate / 2600.0)
	var max_lag := int(rate / 70.0)
	var best := 0.0
	var best_lag := 0
	var values := {}
	var falling := true
	for lag in range(maxi(2, min_lag), max_lag):
		var num := 0.0
		var den := 0.0
		for i in WINDOW:
			var p := x[at + i]
			var q := x[at + i + lag]
			num += p * q
			den += p * p + q * q
		var r := 2.0 * num / maxf(den, 1e-9)
		values[lag] = r
		if falling and r < 0.0:
			falling = false
		if not falling and r > best:
			best = r
			best_lag = lag
	if best < CLARITY or best_lag == 0:
		return 0.0
	# The period is the first peak within 10% of the best, not a multiple of it (which would read an octave low).
	var lo := maxi(2, min_lag)
	for k in range(lo + 1, max_lag - 1):
		var v: float = values[k]
		if v >= 0.9 * best and v >= float(values[k - 1]) and v >= float(values[k + 1]) and float(values[lo]) < v:
			var dipped := false
			for m in range(lo, k):
				if float(values[m]) < 0.0:
					dipped = true
					break
			if dipped:
				best_lag = k
				break
	var lag := float(best_lag)
	if values.has(best_lag - 1) and values.has(best_lag + 1):
		var l: float = values[best_lag - 1]
		var c: float = values[best_lag]
		var rr: float = values[best_lag + 1]
		var den := l - 2.0 * c + rr
		if absf(den) > 1e-9:
			lag += 0.5 * (l - rr) / den
	return 69.0 + 12.0 * log(rate / lag / 440.0) / log(2.0)

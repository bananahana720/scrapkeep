extends SceneTree

const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const ClassDef := preload("res://src/core/class_def.gd")

# Wave 10 AU2: every pilot has a near-miss whip, pickups have their fountain, and four
# events have a short tune each. Buffers, not ears.

const CEILING := 0.95
# id: [min seconds, max seconds]. lore_found and pilot_unlocked play the event-set files (1.39 s, 2.10 s).
const TUNES := {
	"pickup_fountain": [0.3, 0.5], "synergy_fired": [0.6, 0.9], "evolution_fired": [0.6, 0.9],
	"lore_found": [1.2, 1.6], "pilot_unlocked": [1.8, 2.4], "pilot_unlocked_sable": [0.6, 0.9],
	"pilot_unlocked_rivet": [0.6, 0.9], "pilot_unlocked_kest": [0.6, 0.9], "pilot_unlocked_tarn": [0.6, 0.9],
	"pilot_unlocked_tally": [0.6, 0.9], "pilot_unlocked_cannon": [0.6, 0.9],
}
const WHIPS := ["near_miss_whip_tarn", "near_miss_whip_tally", "near_miss_whip_cannon"]
const WHIP_WINDOW := 0.1

var _failures := 0


func _initialize() -> void:
	_tunes()
	_whips_differ()
	_every_pilot_has_a_whip()
	print("audio_au2_voices_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _tunes() -> void:
	var bad: Array = []
	var ids: Array = TUNES.keys()
	ids.append_array(WHIPS)
	for id in ids:
		var buf := SfxBank.samples(id)
		var peak := 0.0
		for s in buf:
			peak = maxf(peak, absf(s))
		var seconds := buf.size() / float(SfxBank.RATE)
		var range: Array = TUNES.get(id, [0.1, 1.2])
		if peak <= 0.1 or peak >= CEILING or seconds < range[0] or seconds > range[1] or not SfxBank.has_recipe(id):
			bad.append("%s (peak %.2f, %.2fs, want %s)" % [id, peak, seconds, range])
	_check("tunes", bad.is_empty(), "%d ids in range, non-silent, under %.2f peak, own recipe; failing %s" % [ids.size(), CEILING, bad])


func _whips_differ() -> void:
	var n := int(SfxBank.RATE * WHIP_WINDOW)
	var worst := 0.0
	var pair := ""
	for i in WHIPS.size():
		for j in range(i + 1, WHIPS.size()):
			var c := absf(_correlation(SfxBank.samples(WHIPS[i]), SfxBank.samples(WHIPS[j]), n))
			if c > worst:
				worst = c
				pair = "%s/%s" % [WHIPS[i], WHIPS[j]]
	_check("whips differ", worst < 0.9, "worst first-100ms correlation %.3f (%s), need under 0.9" % [worst, pair])


func _every_pilot_has_a_whip() -> void:
	var missing: Array = []
	var classes := ClassDef.all()
	for def in classes:
		var id := "near_miss_whip_%s" % def.motif
		if not SfxBank.has_recipe(id):
			missing.append(id)
	_check("every pilot", classes.size() >= 6 and missing.is_empty(), "%d pilots, each with a near-miss whip recipe; missing %s" % [classes.size(), missing])


func _correlation(a: PackedFloat32Array, b: PackedFloat32Array, n: int) -> float:
	var dot := 0.0
	var ea := 0.0
	var eb := 0.0
	for i in mini(n, mini(a.size(), b.size())):
		dot += a[i] * b[i]
		ea += a[i] * a[i]
		eb += b[i] * b[i]
	if ea <= 0.0 or eb <= 0.0:
		return 0.0
	return dot / sqrt(ea * eb)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])

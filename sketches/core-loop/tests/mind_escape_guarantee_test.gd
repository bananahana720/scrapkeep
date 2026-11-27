extends SceneTree

const BossAttacks := preload("res://src/boss/boss_attacks.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const StubBoss := preload("res://src/boss/stub_boss.gd")
const Tuning := preload("res://src/movement/tuning.gd")

# SAFE1: MindAttacks.commit_safe, the call the Mind lays every attack through, never returns a
# set without an escape point. 400 seeds, phases 1 to phase_cap(), every family forced plus
# the phase's own choice, the ball on rings from the pad centre out past the pad rim. The
# fallback paths (drop, single, none) stay under 5% of commits, so the guarantee is not hiding
# a generator that keeps failing. "none" lays nothing and is allowed only off the pad, where
# the ball cannot reach clear floor before the warn ends whatever is laid.
#
# The band case puts the ball off the pad where the short-warn families leave no way back in
# time: the phase's own choice must still find a set with an escape by recommitting, falling
# back under 5% of the time.
#
# Evidence limit: geometry and timing only, as mind_attack_families_test.

const SEEDS := 400
const CENTER := Vector3(-4.0, 2.0, 6.0)
const RINGS := [0.0, 0.3, 0.5, 0.8, 0.9, 0.97, 1.0, 1.1, 1.2, 1.3, 1.4, 1.45]
const BAND := 1.45
const FALLBACK_CAP := 0.05

var _failures := 0


func _initialize() -> void:
	var cruise := Tuning.new().f("cruise")
	var radius := StubBoss.PAD_RADIUS
	var paths := {}
	var band_paths := {}
	var nulls := 0
	var empty_on_pad := 0
	var commits := 0
	var hit := 0
	for s in SEEDS:
		var a := TAU * float(s) / SEEDS
		var ball := _ball(a, float(RINGS[s % RINGS.size()]) * radius)
		var band_ball := _ball(a, BAND * radius)
		for phase in range(1, MindAttacks.phase_cap() + 1):
			var seed: int = s * 7919 + phase
			for family in [""] + MindAttacks.exposed(phase):
				var got := MindAttacks.commit_safe(family, seed, ball, CENTER, phase, cruise, radius)
				commits += 1
				paths[got["path"]] = int(paths.get(got["path"], 0)) + 1
				var descs: Array = got["descriptors"]
				if descs.is_empty():
					if got["path"] != "none" or _flat(ball - CENTER).length() <= radius:
						empty_on_pad += 1
				elif BossAttacks.escape_point(descs, ball, cruise, CENTER, radius) == null:
					nulls += 1
				if got["path"] == "single" and BossAttacks.covers(descs[0], ball):
					hit += 1
			var band := MindAttacks.commit_safe("", seed, band_ball, CENTER, phase, cruise, radius)
			band_paths[band["path"]] = int(band_paths.get(band["path"], 0)) + 1
			if not band["descriptors"].is_empty() and BossAttacks.escape_point(band["descriptors"], band_ball, cruise, CENTER, radius) == null:
				nulls += 1
	var rate := _fallbacks(paths) / maxf(1.0, float(commits))
	var band_rate := _fallbacks(band_paths) / float(SEEDS * MindAttacks.phase_cap())
	_report("commits ran", commits >= SEEDS * MindAttacks.phase_cap(), "%d commits" % commits)
	_report("escape point never null after commit", nulls == 0, "%d null" % nulls)
	_report("nothing is laid only when the ball is off the pad", empty_on_pad == 0, "%d on the pad" % empty_on_pad)
	_report("fallback under 5% of commits", rate < FALLBACK_CAP, "%.2f%% of %d" % [rate * 100.0, commits])
	_report("off-pad band: the phase's choice falls back under 5%", band_rate < FALLBACK_CAP and int(band_paths.get("recommit", 0)) > 0,
			"%.2f%%, %d recommits" % [band_rate * 100.0, int(band_paths.get("recommit", 0))])
	_report("the single fallback never covers the ball", hit == 0, "%d covered" % hit)
	_report("the away lane clears a ball at the centre", not BossAttacks.covers(MindAttacks.away_lane(CENTER, CENTER, 1, radius), CENTER), "")
	print("mind_escape_guarantee_test: paths %s band %s" % [paths, band_paths])
	print("mind_escape_guarantee_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _ball(a: float, r: float) -> Vector3:
	return CENTER + Vector3(cos(a) * r, 0.5, sin(a) * r)


func _fallbacks(paths: Dictionary) -> float:
	var n := 0
	for p in MindAttacks.FALLBACK_PATHS:
		n += int(paths.get(p, 0))
	return float(n)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("  %s %s%s" % ["ok  " if ok else "FAIL", label, "" if detail.is_empty() else " (%s)" % detail])


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

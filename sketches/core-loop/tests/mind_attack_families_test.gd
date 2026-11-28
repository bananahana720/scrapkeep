extends SceneTree

const BossAttacks := preload("res://src/boss/boss_attacks.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Arena := preload("res://src/boss/arena.gd")
const Tuning := preload("res://src/movement/tuning.gd")

# The Mind's attack families (src/boss/mind_attacks.gd) over 200 seeded commits across
# phases 1 to phase_cap(), the ball at seeded floor points: every warn is at least the adapt floor and
# Hazard.MIN_WARN; every region stays on the floor; escape_point is never null, and the
# real Hazards, stepped to LIVE, do not contain it; the plate's hit_mult floor holds for
# every verb; phase k never emits a family above k.
#
# Evidence limit: geometry and timing only. A straight run at cruise is assumed; the
# ball's acceleration, turning and the fight's other bodies are not modelled.

const COMMITS := 200
const CENTER := Vector3(3.0, 0.0, -2.0)

var _failures := 0


func _initialize() -> void:
	var cruise := Tuning.new().f("cruise")
	var min_warn := INF
	var min_margin := INF
	var nulls := 0
	var contained := 0
	var low_warn := 0
	var off_floor := 0
	var above_phase := 0
	var hazards := 0
	var mult_low := 0
	var ball_hit := 0
	for s in COMMITS:
		var phase := s % MindAttacks.phase_cap() + 1
		var rng := RandomNumberGenerator.new()
		rng.seed = 7919 * s + 11
		var r := sqrt(rng.randf()) * (Arena.FLOOR_R - MindAttacks.CLEAR)
		var a := rng.randf() * TAU
		var ball := CENTER + Vector3(cos(a) * r, 0.0, sin(a) * r)
		var chosen := MindAttacks.choose(s, phase)
		if MindAttacks.FAMILIES.find(chosen) + 1 > phase:
			above_phase += 1
		for d in MindAttacks.commit_any(s, ball, CENTER, phase):
			if int(d["family_index"]) > phase:
				above_phase += 1
		for family in MindAttacks.FAMILIES:
			var descs := MindAttacks.commit(family, s, ball, CENTER, phase)
			for d in descs:
				min_warn = minf(min_warn, float(d["warn"]))
				if float(d["warn"]) < MindAttacks.WARN_FLOOR or float(d["warn"]) < Hazard.MIN_WARN:
					low_warn += 1
				if not _on_floor(d):
					off_floor += 1
				if d["family"] == "plate":
					for verb in MindAttacks.VERBS:
						if MindAttacks.hit_mult(d, verb) < 1.0 / MindAttacks.BRACE_MULT - 1e-6:
							mult_low += 1
			var escape = BossAttacks.escape_point(descs, ball, cruise, CENTER, Arena.FLOOR_R)
			if escape == null:
				nulls += 1
				continue
			var shortest := INF
			for d in descs:
				shortest = minf(shortest, float(d["warn"]))
			min_margin = minf(min_margin, cruise * shortest - _flat(escape - ball).length())
			if _flat(escape - CENTER).length() > Arena.FLOOR_R:
				off_floor += 1
			var any_hit := false
			for d in descs:
				var h := Hazard.from_def(d)
				root.add_child(h)
				hazards += 1
				h.step(h.warn_seconds + 0.01)
				if not h.is_live() or h.contains(escape):
					contained += 1
				if h.contains(Vector3(ball.x, CENTER.y, ball.z)):
					any_hit = true
				root.remove_child(h)
				h.free()
			if any_hit:
				ball_hit += 1

	_report("cruise read from tuning", cruise > 0.0, "cruise %.2f" % cruise)
	_report("every warn >= %.1f and Hazard.MIN_WARN" % MindAttacks.WARN_FLOOR, low_warn == 0, "%d low, min %.2f" % [low_warn, min_warn])
	_report("every region inside FLOOR_R", off_floor == 0, "%d off the floor" % off_floor)
	_report("escape_point never null", nulls == 0, "%d null" % nulls)
	_report("no live Hazard contains the escape", contained == 0 and hazards > 0, "%d of %d hazards" % [contained, hazards])
	_report("plate hit_mult floor >= 1/%.1f for every verb" % MindAttacks.BRACE_MULT, mult_low == 0, "%d low" % mult_low)
	_report("phase k never emits a family above k", above_phase == 0, "%d above" % above_phase)
	_report("phase cap is the boss phase count", MindAttacks.exposed(99).size() == MindAttacks.phase_cap(), "")
	print("mind_attack_families_test: stats min_warn %.2f min_escape_margin %.2f m ball_threatened %d/%d hazards %d" \
			% [min_warn, min_margin, ball_hit, COMMITS * MindAttacks.FAMILIES.size(), hazards])
	print("mind_attack_families_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _on_floor(d: Dictionary) -> bool:
	var R := Arena.FLOOR_R
	match d["shape"]:
		"lane":
			var dir: Vector3 = d["dir"]
			var side := Vector3.UP.cross(dir).normalized()
			for along in [-float(d["behind"]), float(d["ahead"])]:
				for lat in [-float(d["half"]), float(d["half"])]:
					if _flat(d["from"] + dir * along + side * lat - CENTER).length() > R:
						return false
			return true
		"annulus", "sector":
			return _flat(d["at"] - CENTER).length() < 1e-4 and d["band"].x >= 0.0 and d["band"].y <= R
	return false


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("  %s %s%s" % ["ok  " if ok else "FAIL", label, "" if detail.is_empty() else " (%s)" % detail])


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

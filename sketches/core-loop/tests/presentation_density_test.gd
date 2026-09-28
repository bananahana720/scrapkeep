extends SceneTree

const Density := preload("res://src/presentation/density.gd")
const Bolts := preload("res://src/combat/bolts.gd")

# v3 F1a: the density governor (FEEL-READABILITY.md §1.2, §8, §9). Four things this unit
# must hold: the scalar rises and falls back on its own clock; P0 to P3 are never
# governed; the shed order is a fixed, ordered staircase; and a module that reads density
# for its visuals (bolts.gd) resolves hits identically whether the governor sees load or
# not, because it only ever touches `_process`'s draw.

var _failures := 0


class FakeEnemy:
	extends Node3D
	var radius := 1.0
	var half_height := 1.0
	func is_dead() -> bool:
		return false
	func weak_points() -> Array:
		return []


func _process(_delta: float) -> bool:
	_check_rise_and_fall()
	_check_priority_exemption()
	_check_shed_order()
	_check_bolts_simulation_parity()
	print("presentation_density_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _check_rise_and_fall() -> void:
	var gov := Density.Governor.new()
	# One tenth of the rise window from a cold start should land partway there, never at
	# the target in one step (a linear ramp, not a snap); a full run of the window reaches it.
	var partial_rise := gov.update_raw(Density.RISE_SECONDS * 0.1, 1.0)
	for i in 20:
		gov.update_raw(Density.RISE_SECONDS * 0.5, 1.0)
	var risen: bool = is_equal_approx(gov.value, 1.0)
	_report("density rises", partial_rise > 0.0 and partial_rise < 0.99 and risen,
		"a tenth of the rise window reaches %.3f (partial, not instant); a full run settles at %.3f" % [partial_rise, gov.value])
	# Falling uses the slower FALL_SECONDS clock: the same one-tenth-of-window step falls
	# back less in absolute terms per second, but a full run of the fall window reaches 0.
	var partial_fall := gov.update_raw(Density.FALL_SECONDS * 0.1, 0.0)
	for i in 20:
		gov.update_raw(Density.FALL_SECONDS * 0.5, 0.0)
	var fallen: bool = is_equal_approx(gov.value, 0.0)
	_report("density falls back", partial_fall < 1.0 and partial_fall > 0.0 and fallen,
		"a tenth of the fall window retreats to %.3f (still not zero); a full run settles at %.3f" % [partial_fall, gov.value])
	# The fall window (0.6 s) is longer than the rise window (0.25 s), so the same 0.1 s
	# step falls back by a smaller fraction of the way than it rose.
	var gov2 := Density.Governor.new()
	var rise_step := gov2.update_raw(0.1, 1.0)
	gov2.value = 1.0
	var fall_step := 1.0 - gov2.update_raw(0.1, 0.0)
	_report("fall is slower than rise", fall_step < rise_step,
		"a 0.1 s step rises by %.3f but only falls back by %.3f, since RISE_SECONDS %.2f < FALL_SECONDS %.2f"
			% [rise_step, fall_step, Density.RISE_SECONDS, Density.FALL_SECONDS])


func _check_priority_exemption() -> void:
	var exempt := true
	for p in ["P0", "P1", "P2", "P3"]:
		exempt = exempt and Density.is_shed_exempt(p)
	var governed := true
	for p in ["P4", "P5", "P6", "P7"]:
		governed = governed and not Density.is_shed_exempt(p)
	_report("P0 to P3 never shed", exempt and governed,
		"P0-P3 report exempt=true, P4-P7 report exempt=false")


func _check_shed_order() -> void:
	var expected := ["ambient_p7", "bolt_tails", "synergy_evolution_rings", "pin_trails_and_fountains", "drone_rack_seams"]
	var order_ok: bool = Density.SHED_ORDER == expected
	var below_floor := Density.active_shed(0.39).is_empty()
	var steps: Array = []
	var last := -1
	var monotonic := true
	var prefix_ok := true
	var d := 0.0
	while d <= 1.001:
		var active: Array = Density.active_shed(d)
		steps.append(active.size())
		if active.size() < last:
			monotonic = false
		last = active.size()
		for i in active.size():
			if active[i] != expected[i]:
				prefix_ok = false
		d += 0.05
	var full_at_one: bool = Density.active_shed(1.0) == expected
	_report("shed order holds", order_ok and below_floor and monotonic and prefix_ok and full_at_one,
		"SHED_ORDER is %s; below density 0.4 nothing sheds; every sampled density's active list is an ordered prefix of it (sizes %s); density 1.0 sheds all of it"
			% [expected, steps])


func _check_bolts_simulation_parity() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var bolts := Bolts.new()
	world.add_child(bolts)
	bolts.setup()
	var enemy := FakeEnemy.new()
	enemy.radius = 1.0
	enemy.half_height = 1.2
	world.add_child(enemy)
	enemy.global_position = Vector3(0.0, 0.0, 10.0)
	var from := Vector3(0.0, 0.0, 0.0)
	var to := Vector3(0.0, 0.0, 20.0)

	bolts.density = 0.0
	var quiet: Dictionary = bolts._first_enemy(from, to, 0.3, [enemy])
	var quiet_alpha := Bolts.crowd_alpha(1) * Density.alpha_factor(bolts.density)

	bolts.density = 1.0
	var dense: Dictionary = bolts._first_enemy(from, to, 0.3, [enemy])
	var dense_alpha := Bolts.crowd_alpha(1) * Density.alpha_factor(bolts.density)

	var same_hit: bool = not quiet.is_empty() and not dense.is_empty() \
		and quiet["enemy"] == dense["enemy"] and quiet["part"] == dense["part"] \
		and is_equal_approx(quiet["along"], dense["along"]) and (quiet["point"] as Vector3).is_equal_approx(dense["point"])
	var alpha_differs: bool = not is_equal_approx(quiet_alpha, dense_alpha)
	_report("simulation identical, visuals differ", same_hit and alpha_differs,
		"the same segment hits the same enemy at the same point (%s) whether density is %.1f or %.1f; only the drawn alpha changes (%.3f vs %.3f)"
			% [dense.get("point", Vector3.INF), 0.0, 1.0, quiet_alpha, dense_alpha])

	world.free()

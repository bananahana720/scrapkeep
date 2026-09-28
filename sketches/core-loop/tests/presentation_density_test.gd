extends SceneTree

const Density := preload("res://src/presentation/density.gd")
const Bolts := preload("res://src/combat/bolts.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Game := preload("res://src/game.gd")

# v3 F1a: the density governor (FEEL-READABILITY.md §1.2, §8, §9). Four things this unit
# must hold: the scalar rises and falls back on its own clock; P0 to P3 are never
# governed; the shed order is a fixed, ordered staircase; and a module that reads density
# for its visuals (bolts.gd) resolves hits identically whether the governor sees load or
# not, because it only ever touches `_process`'s draw.
#
# Fix round 1 (finding 6) adds the real-game load scenario §6.1 actually asks for: eight
# hostile telegraphs and six packs' worth of enemies (real threats_in_view/enemies_in_view,
# not a hand-fed target), then 30 kills and a flood of hits inside a ~200 ms window, and
# checks the real budgets (P5 glyphs <= 40, hit sparks <= 12, kill pops <= 3 / 250 ms), that
# a P2/P3-style glyph (near_miss) is never evicted by the flood, that bolts actually
# shorten only the tail once "bolt_tails" sheds (not width/alpha), and that density
# recovers once the load stops (hysteresis).

var _failures := 0
var _instant_done := false
var _game
var _vfx
var _t0 := 0
var _plan: Array = []
var _marks := {}
var _fixtures: Array = []
var _done := false


class FakeEnemy:
	extends Node3D
	var radius := 1.0
	var half_height := 1.0
	func is_dead() -> bool:
		return false
	func weak_points() -> Array:
		return []


class FlatGround:
	func height(_x: float, _z: float) -> float:
		return 0.0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if not _instant_done:
		_check_rise_and_fall()
		_check_priority_exemption()
		_check_shed_order()
		_check_bolts_simulation_parity()
		_check_bolt_tail_shed()
		_instant_done = true
		return false
	if _game == null or _game.flow == null:
		return false
	var events = _game.events
	if _vfx == null:
		_vfx = _game.presentation.vfx
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(0)
		_schedule_load_scenario(events)
		_t0 = Time.get_ticks_msec()
		return false
	var elapsed := Time.get_ticks_msec() - _t0
	while not _plan.is_empty() and elapsed >= _plan[0][0]:
		var item: Array = _plan.pop_front()
		(item[1] as Callable).call()
	if not _plan.is_empty() or _done:
		return false
	_done = true
	_check_load_scenario()
	print("presentation_density_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	for f in _fixtures:
		if is_instance_valid(f):
			f.free()
	_game.free()
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


# Fix round 1, finding 7/9: only the streak (the tail) shortens once "bolt_tails" is an
# active shed step; the head's own width never scales with density (§8). _bolt_visual is
# the same pure function _process() draws with, called here with a forced flag so the
# render path is actually exercised, not re-derived by the test.
func _check_bolt_tail_shed() -> void:
	var bolts := Bolts.new()
	var bolt := {"dir": Vector3.FORWARD, "speed": 40.0, "travelled": 5.0, "shown": Vector3.ZERO}
	var full := bolts._bolt_visual(bolt, false)
	var shed := bolts._bolt_visual(bolt, true)
	_report("bolt tail sheds, head does not", is_equal_approx(float(full["width"]), float(shed["width"]))
			and float(shed["streak"]) < float(full["streak"]) and float(full["width"]) > 0.0,
		"width stays %.3f whether or not bolt_tails is shedding; the streak shortens from %.3f m to %.3f m when it is"
			% [full["width"], full["streak"], shed["streak"]])
	var active_at_low := "bolt_tails" in Density.active_shed(0.3)
	var active_at_high := "bolt_tails" in Density.active_shed(0.9)
	_report("bolt_tails is a real shed step", not active_at_low and active_at_high,
		"bolt_tails is inactive at density 0.3 (%s) and active at 0.9 (%s), matching SHED_ORDER's own floor" % [active_at_low, active_at_high])
	bolts.free()


# --- Fix round 1, finding 6: the real-game load scenario --------------------------------

func _schedule_load_scenario(events) -> void:
	var ground := FlatGround.new()
	var at: Vector3 = _game.player.ball_position()
	# Six packs' worth of enemies (controller, punisher, two chasers each, §6.2's pack
	# shape: 4 x 6 = 24) and eight mixed hostile telegraphs, both genuinely in view, so
	# threats_in_view and enemies_in_view drive density up, not a hand-fed target.
	for i in 24:
		var enemy := FakeEnemy.new()
		enemy.add_to_group("enemy")
		root.add_child(enemy)
		enemy.global_position = at + Vector3(float(i % 4) - 1.5, 0.0, float(i / 4) - 3.0) * 0.5
		_fixtures.append(enemy)
	var kinds := [Threat.Type.INSTANT, Threat.Type.PROJECTILE, Threat.Type.INSTANT, Threat.Type.PROJECTILE,
		Threat.Type.INSTANT, Threat.Type.PROJECTILE, Threat.Type.INSTANT, Threat.Type.PROJECTILE]
	for i in 8:
		_fixtures.append(Telegraph.ring(root, ground, kinds[i], at + Vector3(0.25 * i, 0.0, 0.0), 3.0))
	var entries: Array = []
	# Warm the scalar up on the real threats/enemies before the burst, so it lands while
	# density is already in a coalescing band (§1.2's window only exists above 0.4); a
	# cold-start burst legitimately gets one pop per kill, per that table's 0.0-0.4 row.
	entries.append([350, func(): _marks["warm_density"] = _vfx.density()])
	entries.append([360, func(): events.near_miss.emit("test", at)])
	entries.append([380, func(): _marks["near_miss_alive_before"] = _vfx.kind_alive_count("near_miss")])
	for i in 60:
		entries.append([400 + i * 3, func():
			events.enemy_struck.emit(_fixtures[0], "test", 10.0)
			_marks["peak_hit_sparks"] = maxi(_marks.get("peak_hit_sparks", 0), _vfx.kind_alive_count("enemy_struck"))
			_marks["peak_p5"] = maxi(_marks.get("peak_p5", 0), _vfx.governed_glyph_count())])
	for i in 30:
		entries.append([400 + i * 6, func(): events.enemy_killed.emit("chaser", at + Vector3(0.03 * i, 0.0, 0.0), 1)])
	entries.append([650, func():
		_marks["density_at_burst"] = _vfx.density()
		_marks["hit_spark_refused"] = _vfx.spawned.get("hit_spark_refused", 0)
		_marks["p5_glyph_refused"] = _vfx.spawned.get("p5_glyph_refused", 0)
		_marks["near_miss_alive_after"] = _vfx.kind_alive_count("near_miss")
		_marks["pops_in_250ms"] = _vfx.burst_count_within("pop", 250.0)])
	# Load stops here (kills/hits done firing); recovery hysteresis (finding 6).
	entries.append([660, func():
		for f in _fixtures:
			if is_instance_valid(f):
				f.queue_free()
		_fixtures.clear()])
	entries.append([1000, func(): _marks["pops_eventually_fired"] = _vfx.spawned.get("burst_pop", 0)])
	entries.append([1700, func(): _marks["density_recovered"] = _vfx.density()])
	entries.sort_custom(func(a, b): return a[0] < b[0])
	_plan = entries


func _check_load_scenario() -> void:
	var warm: float = _marks.get("warm_density", -1.0)
	_report("real threats and enemies raise density", warm >= 0.4,
		"24 enemies and 8 telegraphs near the ball warm density to %.3f before the burst (>= 0.4 needed for §1.2's coalescing band)" % warm)
	var peak_p5: int = _marks.get("peak_p5", -1)
	var refused_p5: int = _marks.get("p5_glyph_refused", 0)
	_report("P5 glyphs stay within budget", peak_p5 >= 0 and peak_p5 <= Density.cap("p5_glyphs"),
		"peak concurrent P5 (governed) glyphs %d, cap %d, %d spawn(s) refused past it"
			% [peak_p5, Density.cap("p5_glyphs"), refused_p5])
	var peak_sparks: int = _marks.get("peak_hit_sparks", -1)
	var refused_sparks: int = _marks.get("hit_spark_refused", 0)
	_report("hit sparks stay within budget, and the cap engaged", peak_sparks >= 0 and peak_sparks <= Density.cap("hit_sparks") and refused_sparks > 0,
		"60 struck events 3 ms apart hold peak concurrent hit sparks at %d (cap %d), refusing %d spawn(s) past it"
			% [peak_sparks, Density.cap("hit_sparks"), refused_sparks])
	var before: int = _marks.get("near_miss_alive_before", 0)
	var after: int = _marks.get("near_miss_alive_after", 0)
	_report("a P2/P3-style glyph survives the P5 flood", before >= 1 and after >= 1,
		"the near_miss glyph (ungoverned, sharing the 48-slot pool) reads alive=%d right after spawning and alive=%d after the flood: the pool's 8 reserved slots hold it"
			% [before, after])
	var density_at_burst: float = _marks.get("density_at_burst", -1.0)
	var pops: int = _marks.get("pops_in_250ms", -1)
	var cap_engaged := density_at_burst >= 0.4
	_report("kill pops coalesce under load", not cap_engaged or (pops >= 0 and pops <= Density.cap("kill_pops_per_250ms")),
		"30 kills in ~180 ms at density %.3f produce %d pop burst(s) in the trailing 250 ms (cap %d; the cap only applies once density reaches a coalescing band)"
			% [density_at_burst, pops, Density.cap("kill_pops_per_250ms")])
	var eventually: int = _marks.get("pops_eventually_fired", 0)
	_report("the coalesced pop still fires, not silently dropped", eventually >= 1,
		"0.8 s after the flood, %d pop burst(s) have actually fired -- the pending coalesced burst flushes on its own gap, it does not vanish" % eventually)
	var recovered: float = _marks.get("density_recovered", -1.0)
	_report("density recovers once load stops", recovered >= 0.0 and recovered < density_at_burst - 0.05,
		"1.05 s after the fixtures are freed, density falls from %.3f at the burst to %.3f (FALL_SECONDS %.2f, so it does not snap back instantly either)"
			% [density_at_burst, recovered, Density.FALL_SECONDS])

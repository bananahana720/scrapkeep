extends SceneTree

const Game := preload("res://src/game.gd")
const Density := preload("res://src/presentation/density.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")

# The density governor through the real presentation (E1-DENSITY.md sections 3 and 4).
# Sixty kills in 200 ms never pop more than three starbursts, pops or debris bursts in
# any 250 ms, at density 0 and 1.0; the same kills sent straight to the raw calls do, so
# the counter sees the difference. Every kill is counted in some pop. At density 1.0 a
# P2 glyph and a telegraph's lines draw exactly as at 0, while a P5 glyph and the P6 fills
# are thinned; the bolt tails shed with hysteresis.

const STEP := 0.005
const KILLS := 60
const SPREAD_S := 0.2

var _game
var _vfx
var _failures := 0
var _frames := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	_frames += 1
	if _frames == 2:
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(0)
		return false
	if _frames < 10:
		return false
	_vfx = _game.presentation.vfx
	_vfx.set_process(false)
	_check_budget(0.0)
	_check_budget(1.0)
	_check_raw_control()
	_check_juice_path()
	_check_exemption()
	_check_pop_record()
	_check_shed()
	Density.live().reset()
	print("presentation_density_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _kill_at(i: int) -> Vector3:
	return _game.player.ball_position() + Vector3(-12.0 + 24.0 * float(i % 12) / 11.0, 0.0, -6.0 - 2.0 * float(i / 12))


# Steps the vfx clock by hand, sends the kills on schedule through `send`, and returns the
# most of each kill visual that landed in any 250 ms window.
func _run(send: Callable) -> Dictionary:
	var kinds := ["enemy_killed", "burst_pop", "burst_debris"]
	var events: Array = []
	var sent := 0
	var clock := 0.0
	var start: float = _vfx._clock + 10.0
	while clock <= 2.0:
		_vfx._clock = start + clock
		var before := {}
		for kind in kinds:
			before[kind] = _vfx.spawned.get(kind, 0)
		while sent < KILLS and float(sent) / KILLS * SPREAD_S <= clock:
			send.call(_kill_at(sent))
			sent += 1
		_vfx._emit_pops()
		for kind in kinds:
			for n in _vfx.spawned.get(kind, 0) - before[kind]:
				events.append([clock, kind])
		clock += STEP
	var worst := {}
	for kind in kinds:
		worst[kind] = 0
		for e in events:
			var count := 0
			for other in events:
				if other[1] == kind and other[0] >= e[0] and other[0] < e[0] + Density.KILL_POP_WINDOW - 0.0001:
					count += 1
			worst[kind] = maxi(worst[kind], count)
	return worst


func _check_budget(density: float) -> void:
	Density.live().force(density)
	_vfx.pops.clear()
	_vfx.pops.emitted.clear()
	var worst := _run(func(at: Vector3): _vfx.kill_pop(at))
	var kills := 0
	var biggest := 0.0
	for e in _vfx.pops.emitted:
		kills += int(e[1])
		biggest = maxf(biggest, float(e[2]))
	_check("pop budget at %.1f" % density, worst.values().max() <= Density.KILL_POPS_PER_WINDOW and kills == KILLS
			and is_equal_approx(biggest, Density.POP_SCALE_CAP) and _vfx.pops.pending.is_empty(),
		"%d kills in %d ms: most per 250 ms %s; %d pops carry all %d kills, the biggest at %.2fx"
			% [KILLS, int(SPREAD_S * 1000.0), worst, _vfx.pops.emitted.size(), kills, biggest])


func _check_raw_control() -> void:
	Density.live().force(0.0)
	var color := Color.WHITE
	var worst := _run(func(at: Vector3):
		_vfx.glyph("enemy_killed", at + Vector3.UP * 0.8, 0.6, 1.8, 0.3)
		_vfx.burst("pop", at + Vector3.UP * 0.8, color, 6)
		_vfx.burst("debris", at + Vector3.UP * 0.5, color, 6))
	_check("raw control", worst.values().min() > Density.KILL_POPS_PER_WINDOW,
		"the same kills sent to the raw calls put %s in one 250 ms, so the counter sees an ungated flood" % [worst])


func _check_juice_path() -> void:
	Density.live().force(0.0)
	_vfx.pops.clear()
	_vfx._clock += 10.0
	var before: int = _vfx.spawned.get("burst_debris", 0)
	for i in 10:
		_game.events.enemy_killed.emit("chaser", _kill_at(i), 1)
	_game.presentation.juice.flush()
	var popped: int = _vfx.spawned.get("burst_debris", 0) - before
	_check("juice uses the gate", popped == Density.KILL_POPS_PER_WINDOW and _vfx.pops.pending.size() == Density.KILL_POPS_PER_WINDOW,
		"ten kills through GameEvents and juice pop %d now and hold %d clusters for the next window" % [popped, _vfx.pops.pending.size()])
	_vfx.pops.clear()


# The global the shader reads, from the renderer. The dummy renderer of a headless run
# stores no globals, so there it falls back to the last value Density.publish_fill_scale
# handed the renderer; a native run reads the renderer itself.
var _fill_source := "renderer"


func _published_fill_scale() -> float:
	var value = RenderingServer.global_shader_parameter_get(Density.FILL_GLOBAL)
	if value == null:
		_fill_source = "last value handed to the renderer (dummy renderer stores no globals)"
		value = Density.last_published
	return float(value) if value != null else -1.0


func _check_exemption() -> void:
	var at: Vector3 = _game.player.ball_position() + Vector3(0.0, 1.0, -4.0)
	var quiet := {}
	var loud := {}
	# A wave and an INSTANT ring, built and stepped the same way at density 0 and 1.0: the
	# instance uniforms on their line layers (front, chevrons, curtain and their keylines)
	# must match value for value, and only the fill layers carry the governed flag.
	for density in [0.0, 1.0]:
		Density.live().force(density)
		var drawn := {}
		for kind in ["near_miss", "enemy_struck"]:
			var slot: Dictionary = _vfx.glyph(kind, at, 0.6, 1.4, 0.35, Vector3.ZERO, "", Color(0, 0, 0, 0), "P2" if kind == "near_miss" else "")
			drawn[kind] = [slot["alpha"], slot["from"], slot["to"], slot["life"]]
		_vfx._govern(0.0)
		# The shader reads the published global, not the VFX field behind it.
		drawn["fill_scale"] = _published_fill_scale()
		var wave: Node3D = Telegraph.wave(_game.ctx.root, _game.ctx.terrain, at + Vector3(0.0, 0.0, -20.0), 10.0, 6.0, 0.5)
		wave.step(1.0)
		var ring: Node3D = Telegraph.ring(_game.ctx.root, _game.ctx.terrain, Threat.Type.INSTANT, at + Vector3(20.0, 0.0, -20.0), 6.0)
		ring.set_progress(0.5)
		var uniforms: Array = []
		for pair in [[wave, "motion"], [wave, "motion_under"], [wave, "stripe_motion"], [ring, "stripe_motion"], [ring, "stripe"]]:
			var instance: GeometryInstance3D = pair[0].painter()._layers[pair[1]]
			var governed := float(instance.material_override.get_shader_parameter("governed"))
			var set_scale = instance.get_instance_shader_parameter("alpha_scale")
			var alpha_scale: float = 1.0 if set_scale == null else float(set_scale)
			# What the shader multiplies the vertex alpha by: ALPHA *= alpha_scale * mix(1, threat_fill_scale, governed).
			var effective := alpha_scale * lerpf(1.0, float(drawn["fill_scale"]), governed)
			uniforms.append([pair[1], instance.get_instance_shader_parameter("clip"), governed, effective])
		drawn["uniforms"] = uniforms
		wave.free()
		ring.free()
		if density == 0.0:
			quiet = drawn
		else:
			loud = drawn
	# The exemption, measured on what the shader would multiply the alpha by: a line layer's
	# multiplier is identical at density 0 and 1.0 (so it fails if a line layer turns governed),
	# and each fill layer's falls to the floor (so it fails if a fill stops being governed).
	var lines_same := true
	var fills_governed := true
	for i in loud["uniforms"].size():
		var was: Array = quiet["uniforms"][i]
		var now: Array = loud["uniforms"][i]
		if i < 2:
			lines_same = lines_same and now[1] is Vector4 and now[1] == was[1] and is_equal_approx(now[3], was[3])
		else:
			fills_governed = fills_governed and now[2] == 1.0 and is_equal_approx(now[3], was[3] * Density.FILL_FLOOR)
	_check("P0 to P3 exempt", quiet["near_miss"] == loud["near_miss"] and quiet["enemy_struck"] != loud["enemy_struck"]
			and lines_same and fills_governed and quiet["fill_scale"] == 1.0 and is_equal_approx(loud["fill_scale"], Density.FILL_FLOOR),
		"at density 1.0 a P2 near-miss glyph draws %s as at 0, a P5 hit glyph goes from %s to %s; a wave's line layers multiply alpha by %s at density 1.0 as at 0: %s; fill layers multiply by %s at 1.0 (floor %.2f of their 0 value): %s; global threat_fill_scale %.2f -> %.2f, read from the %s"
			% [loud["near_miss"], quiet["enemy_struck"], loud["enemy_struck"], loud["uniforms"].slice(0, 2).map(func(r): return r[3]), lines_same, loud["uniforms"].slice(2).map(func(r): return r[3]), Density.FILL_FLOOR, fills_governed, quiet["fill_scale"], loud["fill_scale"], _fill_source])


# The gate's record of emitted pops is for the tests: it keeps at most EMITTED_KEEP and
# clear() empties it, so a long run does not grow it.
func _check_pop_record() -> void:
	var pops = _vfx.pops
	pops.clear()
	var clock := 100.0
	for i in 200:
		pops.add(clock, Vector3(i * 50.0, 0.0, 0.0), 0.0)
		pops.ready(clock, 0.0)
		clock += Density.KILL_POP_WINDOW
	var kept: int = pops.emitted.size()
	pops.clear()
	_check("pop record bounded", kept == pops.EMITTED_KEEP and pops.emitted.is_empty(),
		"200 spaced pops leave %d records (cap %d); clear() leaves %d" % [kept, pops.EMITTED_KEEP, pops.emitted.size()])


func _check_shed() -> void:
	var steps: Array = []
	for density in [0.2, 0.41, 0.5, 0.39, 0.35, 0.41, 1.0]:
		Density.live().force(density)
		steps.append(Density.live().sheds("bolt_tails"))
	_check("shed hysteresis", steps == [false, false, true, true, false, false, true],
		"bolt tails shed at densities 0.2, 0.41, 0.5, 0.39, 0.35, 0.41, 1.0 (rising past 0.42, holding to 0.36): %s" % [steps])

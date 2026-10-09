extends SceneTree

# W12 P-FX probe: what GPUParticles3D with a ParticleProcessMaterial does under the
# headless dummy rendering server. The dummy server simulates nothing on a GPU, so a
# headless test can only assert node-side state: configuration, emitting flags, the
# one-shot finished signal and the restart path. Particle positions are not readable.
const T := preload("res://tests/support/t.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

var t := T.new("fx_headless_probe_test")
var finished_count := 0

func _initialize() -> void:
	_run.call_deferred()

func _make() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 45.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 8.0
	pm.gravity = Vector3(0.0, -9.0, 0.0)
	pm.color = Color(1.0, 0.5, 0.1)
	p.process_material = pm
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 0.2
	p.draw_pass_1 = box
	p.amount = 16
	p.lifetime = 0.3
	p.one_shot = true
	p.explosiveness = 1.0
	p.fixed_fps = 60
	p.emitting = false
	return p

func _run() -> void:
	t.check("dummy rendering server: no RenderingDevice", RenderingServer.get_rendering_device() == null)
	var p := _make()
	p.finished.connect(func(): finished_count += 1)
	root.add_child(p)
	await process_frame
	t.check("added idle: not emitting", not p.emitting)
	p.restart()
	t.check("restart arms emitting synchronously", p.emitting)
	p.emitting = true
	t.check("emitting = true holds within the same frame", p.emitting)
	await process_frame
	t.check("headless one-shot drops emitting on the first processed frame", not p.emitting)
	for i in 120:
		await process_frame
	t.eq("headless one-shot never emits finished (120 frames past a 0.3 s life)", finished_count, 0)
	p.restart()
	t.check("restart after the drop re-arms emitting", p.emitting)
	p.amount = 8
	p.restart()
	t.check("amount change + restart accepted", p.amount == 8 and p.emitting)
	var c := _make()
	c.one_shot = false
	c.explosiveness = 0.0
	root.add_child(c)
	c.emitting = true
	var dropped := 0
	for i in 60:
		await process_frame
		if not c.emitting:
			dropped += 1
	t.eq("continuous emitter keeps emitting for 60 frames", dropped, 0)
	var pm := p.process_material as ParticleProcessMaterial
	t.check("process material config readable", pm != null and pm.gravity.y == -9.0 and pm.spread == 45.0)
	t.check("amount and lifetime readable", p.amount == 8 and is_equal_approx(p.lifetime, 0.3))
	t.check("draw pass mesh kept", p.draw_pass_1 is BoxMesh)
	var aabb := p.capture_aabb()
	print("fx_headless_probe capture_aabb=", aabb)
	t.check("capture_aabb is empty headless (no simulated particles)", aabb.size == Vector3.ZERO, str(aabb))
	t.check("GPUParticles3D is a GeometryInstance3D (the shared base for typed casts)", p is GeometryInstance3D)
	p.free()
	c.free()
	_library()
	quit(t.verdict())

# What the real unit can pin headless: every effect builds from its spec, every JUICE fx
# entry names a spec, and nothing in an effect is a light.
func _library() -> void:
	for kind in EventKinds.JUICE:
		for id in EventKinds.juice(kind).get("fx", {}):
			t.check("%s fx names a spec: %s" % [kind, id], FxLibrary.SPECS.has(id))
	for id in FxLibrary.SPECS:
		var s: Dictionary = FxLibrary.SPECS[id]
		var e := FxLibrary.build(id)
		var pm := e.process_material as ParticleProcessMaterial
		t.check("%s built from its spec" % id, e.amount == int(s["max"]) and is_equal_approx(e.lifetime, s["life"])
			and is_equal_approx(pm.gravity.y, float(s["gravity"])) and is_equal_approx(pm.spread, s["spread"]))
		t.check("%s fixed seed, no light" % id, e.use_fixed_seed and e.seed == FxLibrary.SEED
			and e.find_children("*", "Light3D", true, false).is_empty())
		t.check("%s one-shot unless it follows the ball" % id, e.one_shot == (s["attach"] != "ball"))
		e.free()
	t.check("ceiling sums pool x max", FxLibrary.ceiling() == 1 * 64 + 10 * 24 + 2 * 72 + 2 * 28 + 3 * 16 + 3 * 32, str(FxLibrary.ceiling()))

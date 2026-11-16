extends SceneTree

# PF-53: the ball's dust and a kill's burst mark are world-space, and the chase camera flies
# through them at speed, so one puff 1 to 3 m from the lens filled the screen. The dust fades out by
# view distance, like the ball's trail (vfx.gd TRAIL_NEAR); the kill mark keeps its alpha and shrinks
# to a share of the view instead. Headless: this pins the fade's distances, the shader text that
# applies them, the parameters the materials carry and the mark's size cap.
const T := preload("res://tests/support/t.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const KillMark := preload("res://src/presentation/kill_mark.gd")

var t := T.new("lens_fade_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var lib: GDScript = FxLibrary
	var consts := lib.get_script_constant_map()
	if not t.check("FxLibrary names the lens fade distances", consts.has("LENS_FADE")):
		quit(t.verdict())
		return
	var fade: Vector2 = consts["LENS_FADE"]
	t.check("the fade is under the play distance (7.5 m at the nearest)", fade.y < 7.5 and fade.x > 0.0 and fade.x < fade.y)
	t.check("the fade function exists", lib.has_method("lens_alpha"))
	if lib.has_method("lens_alpha"):
		t.check("gone at the near distance", lib.call("lens_alpha", fade.x) < 0.001)
		t.check("gone nearer than that", lib.call("lens_alpha", 0.2) < 0.001)
		t.check("whole at the full distance", lib.call("lens_alpha", fade.y) > 0.999)
		t.check("whole at the play distance", lib.call("lens_alpha", 7.5) > 0.999)
		t.check("half-way between is between", lib.call("lens_alpha", (fade.x + fade.y) * 0.5) > 0.3
			and lib.call("lens_alpha", (fade.x + fade.y) * 0.5) < 0.7)

	var puff := FxLibrary.look_material("puff")
	t.check("the puff shader fades by view distance", puff.shader.code.contains("smoothstep(lens_fade.x, lens_fade.y, length(VERTEX))"))
	t.check("the puff shader defines its own default fade", puff.shader.code.contains("uniform vec2 lens_fade = vec2(1.5, 4.0)"))
	t.check("the puff material carries the same distances", puff.get_shader_parameter("lens_fade") == fade)
	for kind in ["glow", "bead", "star"]:
		t.check("the %s look is untouched" % kind, not FxLibrary.look_material(kind).shader.code.contains("lens_fade"))

	# The kill mark keeps its alpha and caps its size instead: a kill must never read as a hit.
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.global_position = Vector3(0.0, 0.0, 0.0)
	cam.make_current()
	var mark := KillMark.new()
	root.add_child(mark)
	t.check("the mark's fade is gone", not mark._SHADER.contains("lens_fade"))
	var drawn := {}
	for d in [2.0, 7.5, 12.0]:
		mark.clear()
		mark.fire(Vector3(0.0, 0.0, -d), 3.0, Color.WHITE)
		var slot: Dictionary = mark._slots[mark._next - 1 if mark._next > 0 else KillMark.POOL - 1]
		slot["t"] = KillMark.POP
		mark._draw(slot)
		drawn[d] = (slot["node"] as Node3D).basis.get_scale().x
		var m: ShaderMaterial = slot["mat"]
		t.check("alpha at %s m is the pop curve's, not faded" % d, is_equal_approx(float(m.get_shader_parameter("alpha")),
			float(KillMark.shape_at(KillMark.POP, 0)["alpha"])))
	var natural := 1.5 * KillMark.OVERSHOOT
	var screen_cap: float = (KillMark as GDScript).get_script_constant_map().get("SCREEN_CAP", 0.0)
	var cap_half: float = screen_cap * 2.0 * 2.0 * tan(deg_to_rad(cam.fov) * 0.5) * 0.5
	t.check("at 7.5 m the mark is today's size", is_equal_approx(drawn[7.5], natural))
	t.check("beyond that the mark is today's size", is_equal_approx(drawn[12.0], natural))
	t.check("at 2 m the mark is capped to the share of the view", is_equal_approx(drawn[2.0], cap_half) and drawn[2.0] < natural * 0.5)

	# The largest mark the game draws: a merged kill at the density cap (2.5) by a full-might build
	# (1.15), at its pop peak. The cap eases in, so crossing the edge mid-pop never snaps its size.
	var big := 1.5 * 2.5 * 1.15 * KillMark.OVERSHOOT
	var fov := 65.0
	var edge_ratio := KillMark.cap(big, 7.49, fov) / KillMark.cap(big, 7.5, fov)
	t.check("a merged mark does not snap at the edge (%.3f of its size just inside)" % edge_ratio, edge_ratio > 0.98)
	var steps := 0
	var rising := true
	var widest_step := 0.0
	var last := big * KillMark.cap(big, 1.9, fov)
	for i in range(0, 76):
		var eye := 2.0 + i * 0.1
		var size := big * KillMark.cap(big, eye, fov)
		rising = rising and size >= last - 0.0001
		widest_step = maxf(widest_step, absf(size - last) / big)
		last = size
		steps += 1
	t.check("a merged mark never shrinks as the eye backs off, 2 to 9.5 m (%d steps)" % steps, steps > 0 and rising)
	t.check("no 0.1 m step changes it by more than 6%% of its size (widest %.3f)" % widest_step, steps > 0 and widest_step < 0.06)
	t.check("a merged mark is still capped well inside the edge",
		big * KillMark.cap(big, 6.0, fov) < big * 0.6)
	quit(t.verdict())

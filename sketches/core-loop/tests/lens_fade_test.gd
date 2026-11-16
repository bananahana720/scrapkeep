extends SceneTree

# PF-53: the ball's dust and a kill's burst mark are world-space, and the chase camera flies
# through them at speed, so one puff 1 to 3 m from the lens filled the screen. Both fade out by
# view distance, like the ball's trail (vfx.gd TRAIL_NEAR). Headless: this pins the fade's
# distances, the shader text that applies them and the parameters the materials carry.
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
	t.check("the puff material carries the same distances", puff.get_shader_parameter("lens_fade") == fade)
	for kind in ["glow", "bead", "star"]:
		t.check("the %s look is untouched" % kind, not FxLibrary.look_material(kind).shader.code.contains("lens_fade"))

	var mark := KillMark.new()
	root.add_child(mark)
	mark.fire(Vector3.ZERO, 3.0, Color.WHITE)
	var mat: ShaderMaterial = mark._slots[0]["mat"]
	t.check("the kill mark shader fades by eye distance", mat.shader.code.contains("smoothstep(lens_fade.x, lens_fade.y, v_eye)"))
	t.check("the kill mark carries the same distances", mat.get_shader_parameter("lens_fade") == fade)
	t.check("the mark's own alpha is still the pop curve's", is_equal_approx(float(mat.get_shader_parameter("alpha")), 1.0))
	quit(t.verdict())

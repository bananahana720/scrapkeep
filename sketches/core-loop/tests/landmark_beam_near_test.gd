extends SceneTree

# Wave 36 beam (PF-28): near the landmark the lime beam eases out so it reads as light, never a wall; far away it is
# exactly as before. The rule is LandmarkBeam.near_alpha, the drawing holds its result in each layer's shader alpha.

const T := preload("res://tests/support/t.gd")
const LandmarkBeam := preload("res://src/presentation/landmark_beam.gd")

var t := T.new("landmark_beam_near_test")


func _initialize() -> void:
	_run.call_deferred()


# The planted wrong rule: no easing at any distance. It must fail the 50 m line.
static func _no_ease(layer_alpha: float, _distance_m: float) -> float:
	return layer_alpha


func _run() -> void:
	if not t.check("beam has the near rule", (LandmarkBeam as Script).get_script_method_list().any(func(m): return m["name"] == "near_alpha")
		and (LandmarkBeam as Script).get_script_method_list().any(func(m): return m["name"] == "fade_for")):
		quit(t.verdict())
		return
	t.eq("far alpha is exact at 300 m", LandmarkBeam.near_alpha(0.85, 300.0), 0.85)
	t.eq("full alpha at 220 m", LandmarkBeam.near_alpha(0.85, 220.0), 0.85)
	var at50: float = LandmarkBeam.near_alpha(0.85, 50.0)
	t.check("50 m is at most 0.3 and above 0", at50 <= 0.3 and at50 > 0.0, "got %s" % at50)
	t.check("planted no-ease rule fails the 50 m line", not (_no_ease(0.85, 50.0) <= 0.3))
	var last := 99.0
	var rises := 0
	for i in 20:
		var d := 20.0 + 15.0 * (19 - i)   # 305 m down to 20 m
		var a: float = LandmarkBeam.near_alpha(0.85, d)
		if i > 0 and a > last + 1e-9:
			rises += 1
		last = a
	t.eq("alpha never rises as distance falls (20 samples)", rises, 0)

	var holder := Node3D.new()
	root.add_child(holder)
	var beam = LandmarkBeam.make(holder, Vector3(0, 50, 0), 141.0, 0.0)
	var core := beam.get_node("Column/Core") as MeshInstance3D
	var veil := beam.get_node("Column/Veil") as MeshInstance3D
	var cm := core.material_override as ShaderMaterial
	var vm := veil.material_override as ShaderMaterial
	if not t.check("layers hold a shader material", cm != null and vm != null):
		quit(t.verdict())
		return
	beam.fade_for(Vector3(50, 100, 0))
	t.near("core holds the eased alpha at 50 m", float(cm.get_shader_parameter("layer_alpha")), LandmarkBeam.near_alpha(0.85, 50.0), 1e-6)
	t.near("veil holds the eased alpha at 50 m", float(vm.get_shader_parameter("layer_alpha")), LandmarkBeam.near_alpha(0.18, 50.0), 1e-6)
	t.check("core held alpha at 50 m is at most 0.3", float(cm.get_shader_parameter("layer_alpha")) <= 0.3)
	beam.fade_for(Vector3(400, 100, 0))
	t.eq("core holds 0.85 at 400 m", float(cm.get_shader_parameter("layer_alpha")), 0.85)
	t.eq("veil holds 0.18 at 400 m", float(vm.get_shader_parameter("layer_alpha")), 0.18)
	for d: float in [50.0, 100.0, 150.0, 220.0, 400.0]:
		print("alpha at %d m: core %.4f veil %.4f" % [int(d), LandmarkBeam.near_alpha(0.85, d), LandmarkBeam.near_alpha(0.18, d)])
	var eye := Vector3(0, 150, -1200)
	var xf: Transform3D = beam.impostor(eye, 700.0)
	var k := 560.0 / 1200.0
	t.check("impostor transform at 1200 m is unchanged", xf.is_equal_approx(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * k), eye + (beam.bottom - eye) * k)))
	t.check("shader keeps unshaded, fog off, no shadow", (cm.shader.code.contains("unshaded") and cm.shader.code.contains("fog_disabled")
		and core.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF))
	holder.free()
	quit(t.verdict())

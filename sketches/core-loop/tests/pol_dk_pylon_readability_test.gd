extends SceneTree

const StageMap := preload("res://src/world/stage_map.gd")
const Palette := preload("res://src/core/palette.gd")
const T := preload("res://tests/support/t.gd")
var _t := T.new("pol_dk_pylon_readability_test")

func _initialize() -> void:
	var mat := StageMap.dressed_surface(Palette.VERDIGRIS, 0, Vector3(12, 8, 2)) as ShaderMaterial
	_t.check("DK pylon material loads", mat != null)
	if mat != null:
		var code := mat.shader.code
		_t.check("DK concrete albedo gain is 1.65", code.contains("const float CONCRETE_VALUE_GAIN = 1.65;") and code.contains("finish *= CONCRETE_VALUE_GAIN;"))
		_t.check("DK pylon seams are 0.10m and 0.09m", code.contains("groove(p.y, 1.8, 0.05)") and code.contains("groove(p.x, 3.6, 0.045)"))
		_t.eq("DK pylon keeps verdigris role", mat.get_shader_parameter("base_color"), Palette.VERDIGRIS)
		_t.eq("DK shader keeps four uniforms", mat.shader.get_shader_uniform_list().size(), 4)
	quit(_t.verdict())

extends MultiMeshInstance3D

const Palette := preload("res://src/core/palette.gd")

const LENS := 0.085
const LENS_DEPTH := 0.06
const PEAK := 1.3
const REST_COLOUR := Palette.LEDGER
const FIELD_ROOM := 48


const SHADER := """
shader_type spatial;
render_mode cull_back, unshaded, fog_disabled;
uniform vec3 rest : source_color;
uniform float peak;
uniform vec3 danger : source_color;
uniform vec3 dark : source_color;
varying vec3 glow;
void vertex() {
	glow = INSTANCE_CUSTOM.xyz;
}
void fragment() {
	vec3 lit = mix(rest, danger, glow.z);
	ALBEDO = mix(dark, lit, glow.y) * clamp(glow.x / peak, 0.5, 1.0);
}
"""

static var _lens: Mesh
var _lamps: Array[Node3D] = []


static func lens() -> Mesh:
	if _lens == null:
		var dome := SphereMesh.new()
		dome.radius = LENS
		dome.height = LENS_DEPTH
		dome.is_hemisphere = true
		dome.radial_segments = 10
		dome.rings = 3
		var shader := Shader.new()
		shader.code = SHADER
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("rest", REST_COLOUR)
		mat.set_shader_parameter("danger", Palette.HAZARD)
		mat.set_shader_parameter("dark", Palette.CHARCOAL)
		mat.set_shader_parameter("peak", PEAK)
		dome.material = mat
		_lens = dome
	return _lens


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = lens()
	multimesh.instance_count = FIELD_ROOM
	multimesh.visible_instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func join(lamp: Node3D) -> void:
	if _lamps.has(lamp):
		return
	if _lamps.size() >= multimesh.instance_count:
		multimesh.instance_count *= 2
	_lamps.append(lamp)
	multimesh.visible_instance_count = _lamps.size()


func leave(lamp: Node3D) -> void:
	var at := _lamps.find(lamp)
	if at < 0:
		return
	_lamps[at] = _lamps[_lamps.size() - 1]
	_lamps.pop_back()
	multimesh.visible_instance_count = _lamps.size()


func lamps() -> int:
	return _lamps.size()


const FACE := Basis(Vector3.RIGHT, PI / 2.0)


func _process(_delta: float) -> void:
	var to_field := global_transform.affine_inverse()
	for i in _lamps.size():
		var lamp := _lamps[i]
		multimesh.set_instance_transform(i, _placed(to_field, lamp))
		multimesh.set_instance_custom_data(i, Color(lamp.energy(), lamp.tint(), lamp.danger(), 0.0))


func place(lamp: Node3D) -> Transform3D:
	return _placed(global_transform.affine_inverse(), lamp)


func _placed(to_field: Transform3D, lamp: Node3D) -> Transform3D:
	return to_field * lamp.global_transform * Transform3D(FACE.scaled(Vector3.ONE * lamp.swell()), Vector3.ZERO)

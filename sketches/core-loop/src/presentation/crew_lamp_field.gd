extends MultiMeshInstance3D

const Palette := preload("res://src/core/palette.gd")
const CrewLamp := preload("res://src/presentation/crew_lamp.gd")

# Every crew lamp in a world drawn as one MultiMesh (CrewLamp): one draw for all the lamps. Each
# frame an instance takes its lamp's place and its glow (custom data: energy, lit share, danger
# share). A lamp joins when its crew is fitted and leaves when its node leaves the tree; the last
# instance moves into the freed slot, and a full field doubles. It runs while the tree is paused,
# so a still taken on a paused frame shows each lamp on its head. The lens and its material are
# built once a session and shared, so no field compiles a shader in a fight. The lens is unshaded,
# like the telegraphs: lit glass reads as Palette.HAZARD itself at the strike, where an emissive
# lens went through the tonemapper and the sun and came out coral (PC stills, 13 Nov 2026).

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
		dome.radius = CrewLamp.LENS
		dome.height = CrewLamp.LENS_DEPTH
		dome.is_hemisphere = true
		dome.radial_segments = 10
		dome.rings = 3
		var shader := Shader.new()
		shader.code = SHADER
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("rest", CrewLamp.REST_COLOUR)
		mat.set_shader_parameter("danger", Palette.HAZARD)
		mat.set_shader_parameter("dark", Palette.CHARCOAL)
		mat.set_shader_parameter("peak", CrewLamp.PEAK)
		dome.material = mat
		_lens = dome
	return _lens


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = lens()
	multimesh.instance_count = CrewLamp.FIELD_ROOM
	multimesh.visible_instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func join(lamp: Node3D) -> void:
	if _lamps.has(lamp):
		return
	if _lamps.size() >= multimesh.instance_count:
		# Every instance is rewritten each frame, so a resize loses nothing.
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


# The hemisphere's dome is +Y; a lamp faces +Z.
const FACE := Basis(Vector3.RIGHT, PI / 2.0)


func _process(_delta: float) -> void:
	var to_field := global_transform.affine_inverse()
	for i in _lamps.size():
		var lamp := _lamps[i]
		multimesh.set_instance_transform(i, _placed(to_field, lamp))
		multimesh.set_instance_custom_data(i, Color(lamp.energy(), lamp.tint(), lamp.danger(), 0.0))


# A lamp's instance in the field's frame.
func place(lamp: Node3D) -> Transform3D:
	return _placed(global_transform.affine_inverse(), lamp)


func _placed(to_field: Transform3D, lamp: Node3D) -> Transform3D:
	return to_field * lamp.global_transform * Transform3D(FACE.scaled(Vector3.ONE * lamp.swell()), Vector3.ZERO)

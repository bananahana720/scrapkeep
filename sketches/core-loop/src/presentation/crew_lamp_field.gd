extends MultiMeshInstance3D

const Palette := preload("res://src/core/palette.gd")
const CrewLamp := preload("res://src/presentation/crew_lamp.gd")

# Every crew lamp in a world drawn as one MultiMesh (CrewLamp): one draw for all the eyes. Each
# frame an instance takes its lamp's place and its glow (custom data: energy, lit share). A lamp
# joins when its crew is fitted and leaves when its node leaves the tree; the last instance moves
# into the freed slot.

const SHADER := """
shader_type spatial;
render_mode cull_back;
uniform vec3 lit : source_color;
uniform vec3 dark : source_color;
varying vec2 glow;
void vertex() {
	glow = INSTANCE_CUSTOM.xy;
}
void fragment() {
	ALBEDO = mix(dark, lit, glow.y);
	ROUGHNESS = 0.25;
	EMISSION = lit * glow.x;
}
"""

var _lamps: Array[Node3D] = []


func _init() -> void:
	var lens := SphereMesh.new()
	lens.radius = CrewLamp.LENS
	lens.height = CrewLamp.LENS_DEPTH * 2.0
	lens.is_hemisphere = true
	lens.radial_segments = 10
	lens.rings = 3
	var shader := Shader.new()
	shader.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("lit", Palette.HAZARD)
	mat.set_shader_parameter("dark", Palette.CHARCOAL)
	lens.material = mat
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = lens
	multimesh.instance_count = CrewLamp.FIELD_ROOM
	multimesh.visible_instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func join(lamp: Node3D) -> void:
	if not _lamps.has(lamp) and _lamps.size() < multimesh.instance_count:
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
	for i in _lamps.size():
		multimesh.set_instance_transform(i, place(_lamps[i]))
		multimesh.set_instance_custom_data(i, Color(_lamps[i].energy(), _lamps[i].tint(), 0.0, 0.0))


# A lamp's instance in the field's frame.
func place(lamp: Node3D) -> Transform3D:
	return global_transform.affine_inverse() * lamp.global_transform * Transform3D(FACE, Vector3.ZERO)

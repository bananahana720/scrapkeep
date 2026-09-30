extends "res://src/combat/counter.gd"

# A reactor relic (DESIGN-V2 section 10, nuclear war): a squat cast dome with a
# cooling-tower waist and three thick vent stacks, dull petrol enamel with Cherenkov
# seams. It is slow and still, and its hazard is the ground. It opens a meltdown vent
# ahead of the ball: an instant ring that charges for CHARGE seconds while the Geiger
# tick speeds up (vent_charging carries the charge time, so presentation can pace the
# tick and the reactor pedal on it), then erupts. The eruption hurts and lifts a ball
# the ring contains, and leaves a fallout crater: the same ring, burning for CRATER
# seconds, that stings a ball each time it rolls in, without ever slowing it.

const VENT_RADIUS := 5.5
const LEAD := 1.0
const CHARGE := 2.4
const CRATER := 5.0
const ERUPT_DAMAGE := 14.0
const ERUPT_LIFT := 9.0
const BURN := 4.0
const HP := 140.0
const BODY_RADIUS := 1.6
const BODY_HALF := 1.2

var vents := 0
var eruptions_hit := 0
var burns := 0
var _inside := false
var _stacks: Array = []


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 10
	weight = 4.0
	walk_speed = 1.6
	keep_near = 14.0
	keep_far = 34.0
	attack_range = 30.0
	warn_seconds = CHARGE
	live_seconds = CRATER
	rest_seconds = 2.0
	first_rest = 2.5
	interruptible = false


# C31 cast body and three instanced vents: one cached glb, three colour draws.
# The source capsule clamps to radius 1.2 when its height is set to 2.4.
# Visual vents sit inside that footprint; their CPU pivots drive the MultiMesh.
static var _shared: Array = []
var _vent_mesh: MultiMeshInstance3D
var _vent_material: ShaderMaterial


func _build_crew() -> void:
	radius = BODY_RADIUS
	half_height = BODY_HALF
	_add_capsule(BODY_RADIUS, BODY_HALF * 2.0, Roster.ANCIENT_ENAMEL).free()
	_material.roughness = 0.72
	_material.metallic = 0.2
	for part in _parts():
		if part.name == "ReactorBody":
			var body := MeshInstance3D.new()
			body.name = "ReactorBody"
			body.mesh = part.mesh
			body.transform = part.xform
			body.set_surface_override_material(part.body, _material)
			add_child(body)
		else:
			_vent_mesh = MultiMeshInstance3D.new()
			_vent_mesh.name = "ReactorStacks"
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part.mesh
			mm.instance_count = 3
			mm.custom_aabb = AABB(Vector3(-1.19, 0.7, -1.19), Vector3(2.38, 1.8, 2.38))
			_vent_mesh.multimesh = mm
			var shader := Shader.new()
			shader.code = """shader_type spatial;
uniform float charge = 0.0;
uniform vec4 ancient_light : source_color;
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.72;
	float blue = step(COLOR.r * 1.8, COLOR.b) * step(COLOR.g * 1.4, COLOR.b);
	EMISSION = ancient_light.rgb * blue * (0.35 + 1.65 * charge);
}
"""
			_vent_material = ShaderMaterial.new()
			_vent_material.shader = shader
			_vent_material.set_shader_parameter("ancient_light", Roster.ANCIENT_LIGHT)
			_vent_mesh.material_override = _vent_material
			add_child(_vent_mesh)
			for i in 3:
				var angle := TAU * i / 3.0
				var stack := Node3D.new()
				stack.name = "ReactorStack%d" % i
				stack.position = Vector3(cos(angle) * BODY_RADIUS * 0.5, BODY_HALF + 0.4, sin(angle) * BODY_RADIUS * 0.5)
				add_child(stack)
				_stacks.append(stack)
	_pose()


static func _parts() -> Array:
	if not _shared.is_empty():
		return _shared
	var scene := (load("res://assets/models/world_one/enemy_reactor.glb") as PackedScene).instantiate()
	var painted := Palette.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mesh: Mesh = mi.mesh.duplicate()
		var body := -1
		for i in mesh.get_surface_count():
			if mesh.surface_get_material(i).resource_name == "ancient_enamel":
				body = i
			mesh.surface_set_material(i, painted)
		_shared.append({"name": String(mi.name), "mesh": mesh, "xform": mi.transform, "body": body})
	scene.free()
	return _shared


func _commit(_to_ball: Vector3) -> Node3D:
	var aim: Vector3 = _ball() + target.planar_velocity() * LEAD
	var ring := _commit_ring(Threat.Type.INSTANT, aim, VENT_RADIUS, 3.0)
	vents += 1
	if fleet != null:
		fleet.events().vent_charging.emit(ring.center, CHARGE)
	return ring


func _go_live() -> void:
	var ring := telegraph()
	if ring == null:
		return
	_inside = true
	if fleet != null:
		fleet.events().vent_erupted.emit(ring.center)
	if ring.contains(_real_ball()):
		eruptions_hit += 1
		hit_player.emit(ERUPT_DAMAGE, Vector3.UP * ERUPT_LIFT)


func _live(_delta: float) -> bool:
	var crater := telegraph()
	if crater == null:
		return false
	var inside: bool = crater.contains(_real_ball())
	if inside and not _inside:
		burns += 1
		hit_player.emit(BURN, Vector3.ZERO)
	_inside = inside
	return true


# A vent swells before it erupts: the stacks lengthen with the charge.
func _pose() -> void:
	var swell := clampf(_t / warn_seconds, 0.0, 1.0) if phase == Phase.WARN else 0.0
	for i in _stacks.size():
		var stack := _stacks[i] as Node3D
		stack.scale = Vector3(1.0 + 0.2 * swell, 1.0 + 0.5 * swell, 1.0 + 0.2 * swell)
		_vent_mesh.multimesh.set_instance_transform(i, stack.transform)
	_vent_material.set_shader_parameter("charge", swell)

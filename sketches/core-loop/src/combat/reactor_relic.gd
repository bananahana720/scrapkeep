extends "res://src/combat/counter.gd"

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


# Mesh templates are shared; flash and vent charge materials stay per enemy.
static var _warned_asset := false
static var _shared: Array = []
var _vent_mesh: MultiMeshInstance3D
var _vent_material: ShaderMaterial


class VentAssembly extends Node3D:
	var _stacks: Array = []


func _build_crew() -> void:
	radius = BODY_RADIUS
	half_height = BODY_HALF
	var parts := _parts()
	if parts.is_empty():
		_build_primitive_crew()
		return
	_add_capsule(BODY_RADIUS, BODY_HALF * 2.0, Roster.ANCIENT_ENAMEL).free()
	_material.roughness = 0.72
	_material.metallic = 0.2
	var assembly := VentAssembly.new()
	assembly.name = "ReactorAssembly"
	assembly._stacks = _stacks
	_visual_parent().add_child(assembly)
	for part in parts:
		if part.name == "ReactorBody":
			var body := MeshInstance3D.new()
			body.name = "ReactorBody"
			body.mesh = part.mesh
			body.transform = part.xform
			body.set_surface_override_material(part.body, _material)
			assembly.add_child(body)
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
			assembly.add_child(_vent_mesh)
			for i in 3:
				var angle := TAU * i / 3.0
				var stack := Node3D.new()
				stack.name = "ReactorStack%d" % i
				stack.position = Vector3(cos(angle) * BODY_RADIUS * 0.5, BODY_HALF + 0.4, sin(angle) * BODY_RADIUS * 0.5)
				assembly.add_child(stack)
				_stacks.append(stack)
	_pose()


static func _parts() -> Array:
	if not _shared.is_empty():
		return _shared
	var path := "res://assets/models/world_one/enemy_reactor.glb"
	if not ResourceLoader.exists(path):
		return []
	var packed := load(path) as PackedScene
	if packed == null:
		return []
	var scene := packed.instantiate()
	var painted := Palette.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mesh: Mesh = mi.mesh.duplicate()
		var body := -1
		for i in mesh.get_surface_count():
			var surface_material := mesh.surface_get_material(i)
			if surface_material == null and not _warned_asset:
				_warned_asset = true
				push_warning("reactor_relic: surface has no material; using default finish")
			if surface_material != null and surface_material.resource_name == "ancient_enamel":
				body = i
			mesh.surface_set_material(i, painted)
		_shared.append({"name": String(mi.name), "mesh": mesh, "xform": mi.transform, "body": body})
	scene.free()
	return _shared


func _build_primitive_crew() -> void:
	radius = BODY_RADIUS
	half_height = BODY_HALF
	_add_capsule(BODY_RADIUS, BODY_HALF * 2.0, Roster.ANCIENT_ENAMEL)
	var waist := CylinderMesh.new()
	waist.top_radius = BODY_RADIUS * 0.7
	waist.bottom_radius = BODY_RADIUS * 1.15
	waist.height = BODY_HALF * 1.2
	var skirt := MeshInstance3D.new()
	skirt.mesh = waist
	skirt.material_override = _enamel()
	skirt.position = Vector3(0.0, -BODY_HALF * 0.4, 0.0)
	_visual_parent().add_child(skirt)
	var dome := SphereMesh.new()
	dome.radius = BODY_RADIUS * 0.95
	dome.height = BODY_RADIUS * 1.2
	var cap := MeshInstance3D.new()
	cap.mesh = dome
	cap.material_override = _enamel()
	cap.position = Vector3(0.0, BODY_HALF * 0.5, 0.0)
	_visual_parent().add_child(cap)
	for i in 3:
		var angle := TAU * i / 3.0
		var at := Vector3(cos(angle) * BODY_RADIUS * 0.75, BODY_HALF + 0.4, sin(angle) * BODY_RADIUS * 0.75)
		var stack := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.top_radius = 0.28
		tube.bottom_radius = 0.34
		tube.height = 1.2
		stack.mesh = tube
		stack.material_override = _enamel()
		stack.position = at
		_visual_parent().add_child(stack)
		_stacks.append(stack)
		_seam(Vector3(0.62, 0.06, 0.62), at + Vector3.UP * 0.62)
	_seam(Vector3(BODY_RADIUS * 2.1, 0.07, 0.07), Vector3(0.0, 0.0, BODY_RADIUS * 0.02))


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


func _pose() -> void:
	var swell := clampf(_t / warn_seconds, 0.0, 1.0) if phase == Phase.WARN else 0.0
	for i in _stacks.size():
		var stack := _stacks[i] as Node3D
		stack.scale = Vector3(1.0 + 0.2 * swell, 1.0 + 0.5 * swell, 1.0 + 0.2 * swell)
		if _vent_mesh != null:
			_vent_mesh.multimesh.set_instance_transform(i, stack.transform)
	if _vent_material != null:
		_vent_material.set_shader_parameter("charge", swell)

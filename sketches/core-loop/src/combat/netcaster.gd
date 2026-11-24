extends "res://src/combat/counter.gd"

const FxLibrary := preload("res://src/presentation/fx_library.gd")

# The netcaster (DESIGN-V2 section 10): two masts with a crackling net strung between.
# It raises an electric field over where the ball is heading: an instant ring whose
# height band is tall, because only the air is its business. Live, a ball inside the
# field and airborne (at least NET_FLOOR above the ground, not touching it) is netted
# and held hanging: its fall and its drift are cancelled while the net holds. A grounded
# ball rolls under it, so a net can be baited: stay low until it drops. A double jump, a
# glide or a smash tears it.

const FIELD_RADIUS := 5.5
const FIELD_TOP := 10.0
const NET_FLOOR := 1.2
const LEAD := 0.6
const HANG := 5.0
const MAX_HOLD := 1.6
const HP := 45.0
const MAST_HEIGHT := 3.6

var _net: MeshInstance3D
var _net_mat: ShaderMaterial
static var _net_shader: Shader


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.1
	warn_seconds = 1.2
	live_seconds = 2.6
	rest_seconds = 3.5
	attack_range = 24.0


# C16 dressing (enemy_netcaster.glb). The counter's capsule crew and the two cylinder masts are
# replaced by the glb's crew, masts, crossbar, sill and stays (the collider _add_capsule laid
# stays). The net stays the runtime hazard box below, untouched: the glb frames its 2.4 x 1.6 m
# window and adds no geometry inside it. The glb is read once; every netcaster shares its mesh
# and adds only its own flashing body material as a surface override. The resting body is the
# Fleet oxide _add_capsule already set (RUST), so the hit flash and the event colour are unchanged.
static var _warned_asset := false
static var _shared: Dictionary = {}


func _build_tool() -> void:
	_crew.free()
	_crew = null
	var parts := _parts()
	var dress := Node3D.new()
	dress.name = "NetcasterBody"
	_visual_parent().add_child(dress)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = parts["body"]
	body.set_surface_override_material(parts["flash"], _material)
	dress.add_child(body)
	_net = _box(Vector3(2.4, 1.6, 0.04), Palette.HAZARD, Vector3(0.0, MAST_HEIGHT - CREW_HALF - 0.9, -0.3), 0.9)
	_net.name = "NetcasterNet"
	_net_mat = _make_net_material()
	_net.material_override = _net_mat


static func _make_net_material() -> ShaderMaterial:
	if _net_shader == null:
		_net_shader = Shader.new()
		_net_shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec3 hazard_col : source_color = vec3(0.95, 0.25, 0.14);
uniform vec3 brass_col : source_color = vec3(0.95, 0.68, 0.20);
uniform vec3 ink_col : source_color = vec3(0.11, 0.10, 0.10);
uniform float charge = 0.35;
uniform float motion = 1.0;
void fragment() {
	vec2 uv = UV * vec2(8.0, 5.0);
	float t = TIME * 2.4 * motion;
	float d1 = abs(fract(uv.x + uv.y + sin(uv.y * 2.5 + t) * 0.12) - 0.5);
	float d2 = abs(fract(uv.x - uv.y - cos(uv.x * 2.5 + t) * 0.12) - 0.5);
	float line = 1.0 - smoothstep(0.06, 0.14, min(d1, d2));
	float frame = step(0.94, max(abs(UV.x - 0.5) * 2.0, abs(UV.y - 0.5) * 2.0));
	float surge = 0.5 + 0.5 * sin(UV.x * 12.0 - t * 2.2) * motion;
	float mask = clamp(line + frame, 0.0, 1.0);
	if (mask < 0.15) discard;
	float ink_rim = smoothstep(0.15, 0.38, mask) * (1.0 - smoothstep(0.45, 0.72, mask));
	vec3 core = mix(hazard_col, brass_col, clamp(charge * 0.65 + surge * 0.25, 0.0, 1.0));
	ALBEDO = mix(core * (1.0 + charge * 0.45), ink_col, ink_rim * 0.75);
	ALPHA = clamp(mask * (0.72 + charge * 0.28), 0.0, 1.0);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = _net_shader
	mat.set_shader_parameter("hazard_col", Palette.HAZARD)
	mat.set_shader_parameter("brass_col", Palette.BRASS)
	mat.set_shader_parameter("ink_col", Palette.CHARCOAL)
	mat.set_shader_parameter("charge", 0.35)
	mat.set_shader_parameter("motion", 1.0)
	return mat


static func _parts() -> Dictionary:
	if not _shared.is_empty():
		return _shared
	var scene := (load(ModelVariants.path("res://assets/models/world_one/enemy_netcaster.glb")) as PackedScene).instantiate()
	var painted := Palette.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	var flash := 0
	var mesh: Mesh = (scene.find_child("NetcasterBody", true, false) as MeshInstance3D).mesh.duplicate()
	for i in mesh.get_surface_count():
		var surface_material := mesh.surface_get_material(i)
		if surface_material == null and not _warned_asset:
			_warned_asset = true
			push_warning("netcaster: surface has no material; using default finish")
		if surface_material != null and surface_material.resource_name == "fleet_paint":
			flash = i
		mesh.surface_set_material(i, painted)
	_shared = {"body": mesh, "flash": flash}
	scene.free()
	return _shared


func _commit(_to_ball: Vector3) -> Node3D:
	var aim: Vector3 = _ball() + target.planar_velocity() * LEAD
	_facing(aim - global_position)
	var ring := _commit_ring(Threat.Type.INSTANT, aim, FIELD_RADIUS, FIELD_TOP)
	ring.air_only = true
	if world_root != null and is_inside_tree():
		var top := _net.global_position + Vector3.UP * 0.8 if is_instance_valid(_net) else global_position + Vector3(0.0, MAST_HEIGHT - 0.5, -0.3)
		FxLibrary.burst(world_root, "brass_spark", top, 8)
	return ring


func _on_broken(_method: String) -> void:
	if world_root != null and is_inside_tree():
		FxLibrary.burst(world_root, "arc_fizz", _real_ball() + Vector3.UP * 0.6, 10)


func _live(_delta: float) -> bool:
	var field := telegraph()
	if field == null:
		return false
	var player = _player()
	var ball := _real_ball()
	var above: float = ball.y - Telegraph.ground_under(terrain, ball)
	var airborne: bool = not player.state.on_floor() and above >= NET_FLOOR
	if not field.contains(ball) or (not _holding() and not airborne):
		if _holding():
			_release("left")
		return true
	if not _holding() and (caught_live > 0 or not _catch(MAX_HOLD)):
		return true
	var v: Vector3 = player.state.velocity
	var gravity: float = player.tuning.f("gravity")
	_pull(Vector3(-v.x * HANG, gravity - v.y * HANG, -v.z * HANG))
	return true


func _pose() -> void:
	if _net != null:
		_net.visible = phase != Phase.LIVE
	if _net_mat != null:
		var charge := 0.3
		if phase == Phase.WARN:
			charge = lerpf(0.35, 1.0, clampf(_t / warn_seconds, 0.0, 1.0))
		_net_mat.set_shader_parameter("charge", charge)
		_net_mat.set_shader_parameter("motion", 0.0 if FlashGuard.on or EnemyMotion.motion_scale <= 0.0 else 1.0)

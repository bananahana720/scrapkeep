extends "res://src/combat/counter.gd"

const FxLibrary := preload("res://src/presentation/fx_library.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")

# The netcaster (DESIGN-V2 section 10): two masts with a crackling net strung between.
# It raises an electric field over where the ball is heading: an instant ring whose
# height band is tall, because only the air is its business. Live, a ball inside the
# field and airborne (at least NET_FLOOR above the ground, not touching it) is netted
# and held hanging: its fall and its drift are cancelled while the net holds. A grounded
# ball rolls under it, so a net can be baited: stay low until it drops. A double jump, a
# glide or a smash tears it.
#
# Secondary attack (W47-E2): Snap-Trap Ceiling Drop. If the player camps grounded beneath
# an active net for > CAMP_THRESHOLD (1.5 s), the netcaster primes a 0.80 s mast-lean
# crackle (Palette.HAZARD ground ring) collapsing the net onto slow grounded balls.
# Smashing or boosting through the dropping net triggers Conductive Tear: a 10 m EMP arc
# stripping nearby shields (Linker cables, Deflector braces, Brute plates) and jam fields.

const FIELD_RADIUS := 5.5
const FIELD_TOP := 10.0
const NET_FLOOR := 1.2
const LEAD := 0.6
const HANG := 5.0
const MAX_HOLD := 1.6
const HP := 45.0
const MAST_HEIGHT := 3.6

const PRIMARY_WARN := 1.2
const PRIMARY_LIVE := 2.6
const CAMP_THRESHOLD := 1.5
const DROP_WARN := 0.80
const DROP_LIVE := 1.4
const DROP_HEIGHT := 3.5
const DROP_HOLD := 1.2
const DROP_DAMAGE := 6.0
const DROP_DAMP := 4.0
const EMP_RADIUS := 10.0
const EMP_DAMAGE := 12.0
const BOOST_GRACE_S := 0.55

var ceiling_drops := 0
var emp_arcs := 0
var emp_stripped := 0

var _net: MeshInstance3D
var _net_mat: ShaderMaterial
var _body_node: Node3D
var _camp_time := 0.0
var _drop_primed := false
var _drop_at := Vector3.ZERO
var _dropping := false
var _emp_triggered := false
var _boost_grace := 0.0
static var _net_shader: Shader


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, threat: float, spec_ref := {}) -> void:
	super(target_ref, terrain_ref, root_ref, live_ref, threat, spec_ref)
	if _reaction_bus != null:
		if not _reaction_bus.boosted.is_connected(_on_boost_action):
			_reaction_bus.boosted.connect(_on_boost_action)
		if not _reaction_bus.dashed.is_connected(_on_boost_action):
			_reaction_bus.dashed.connect(_on_boost_action)
		if not _reaction_bus.sprint_started.is_connected(_on_boost_action):
			_reaction_bus.sprint_started.connect(_on_boost_action)
		if not _reaction_bus.blink_used.is_connected(_on_blink_action):
			_reaction_bus.blink_used.connect(_on_blink_action)
		if not _reaction_bus.slammed.is_connected(_on_player_slammed):
			_reaction_bus.slammed.connect(_on_player_slammed)


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.1
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE
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
	_body_node = body
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
	mat.set_shader_parameter("motion", 0.0 if FlashGuard.on or EnemyMotion.motion_scale <= 0.0 else 1.0)
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


func _physics_process(delta: float) -> void:
	_boost_grace = maxf(0.0, _boost_grace - delta)
	if _drop_primed and phase == Phase.ROAM and not recovering() and not stunned():
		_rest = minf(_rest, 0.05)
	super._physics_process(delta)


func _on_boost_action(_dir: Vector3) -> void:
	_boost_grace = BOOST_GRACE_S
	if _dropping and not _emp_triggered and (phase == Phase.LIVE or (phase == Phase.WARN and _t >= warn_seconds - 0.2)):
		var field := telegraph()
		if field != null and Vector2(_real_ball().x - field.center.x, _real_ball().z - field.center.z).length() <= FIELD_RADIUS + 0.8:
			_trigger_emp(field.center)


func _on_blink_action(_from: Vector3, _to: Vector3) -> void:
	_on_boost_action(Vector3.ZERO)


func _on_player_slammed(at: Vector3, _strength: float, _flatness: float) -> void:
	if _dropping and not _emp_triggered and (phase == Phase.LIVE or (phase == Phase.WARN and _t >= warn_seconds - 0.2)):
		var field := telegraph()
		if field != null and Vector2(at.x - field.center.x, at.z - field.center.z).length() <= FIELD_RADIUS + 1.0:
			_trigger_emp(field.center)


func _commit(_to_ball: Vector3) -> Node3D:
	var is_drop := _drop_primed
	_drop_primed = false
	_dropping = is_drop
	_emp_triggered = false
	_camp_time = 0.0
	warn_seconds = DROP_WARN if is_drop else PRIMARY_WARN
	live_seconds = DROP_LIVE if is_drop else PRIMARY_LIVE
	var aim: Vector3 = (_drop_at if _drop_at != Vector3.ZERO else _ball()) if is_drop else (_ball() + target.planar_velocity() * LEAD)
	_facing(aim - global_position)
	var ring := _commit_ring(Threat.Type.INSTANT, aim, FIELD_RADIUS, DROP_HEIGHT if is_drop else FIELD_TOP)
	ring.air_only = not is_drop
	if world_root != null and is_inside_tree():
		var top := _net.global_position + Vector3.UP * 0.8 if is_instance_valid(_net) else global_position + Vector3(0.0, MAST_HEIGHT - 0.5, -0.3)
		if is_drop:
			FxLibrary.burst(world_root, "arc_fizz", top, 12)
			FxLibrary.burst(world_root, "brass_spark", top, 10)
		else:
			FxLibrary.burst(world_root, "brass_spark", top, 8)
	return ring


func _go_live() -> void:
	if _dropping:
		ceiling_drops += 1
		if world_root != null and is_inside_tree():
			var field := telegraph()
			if field != null:
				FxLibrary.burst(world_root, "arc_fizz", field.center + Vector3.UP * 0.6, 10)


func _on_broken(method: String) -> void:
	if world_root != null and is_inside_tree():
		FxLibrary.burst(world_root, "arc_fizz", _real_ball() + Vector3.UP * 0.6, 10)
	if _dropping and not _emp_triggered and (method == "smash" or method == "boost"):
		var field := telegraph()
		_trigger_emp(field.center if field != null else _real_ball())


func _live(delta: float) -> bool:
	if _dropping:
		return _live_drop(delta)
	var field := telegraph()
	if field == null:
		return false
	var player = _player()
	var ball := _real_ball()
	var above: float = ball.y - Telegraph.ground_under(terrain, ball)
	var airborne: bool = not player.state.on_floor() and above >= NET_FLOOR
	if not _holding() and not airborne:
		var flat_dist := Vector2(ball.x - field.center.x, ball.z - field.center.z).length()
		if flat_dist <= FIELD_RADIUS:
			_camp_time += delta
			if _camp_time >= CAMP_THRESHOLD:
				_drop_primed = true
				_drop_at = field.center
				return false
		else:
			_camp_time = maxf(0.0, _camp_time - delta * 2.0)
	else:
		_camp_time = maxf(0.0, _camp_time - delta * 2.0)
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


func _live_drop(_delta: float) -> bool:
	if _emp_triggered or _dead:
		return false
	var field := telegraph()
	if field == null:
		return false
	var player = _player()
	if player == null:
		return true
	var ball := _real_ball()
	var flat_dist := Vector2(ball.x - field.center.x, ball.z - field.center.z).length()
	if flat_dist <= FIELD_RADIUS + 0.5 and absf(ball.y - field.center.y) <= DROP_HEIGHT + 1.0:
		if player.kit.slamming or player.kit.sprinting or _boost_grace > 0.0 or player.speed_tier() >= SpeedTier.BLAZING:
			_trigger_emp(field.center)
			return true
	if not field.contains(ball) or (not _holding() and not player.state.on_floor()):
		if _holding():
			_release("left")
		return true
	if not _holding() and player.speed_tier() >= SpeedTier.FAST:
		return true
	if not _holding() and caught_live == 0:
		if _catch(DROP_HOLD):
			hit_player.emit(DROP_DAMAGE, Vector3.ZERO)
	if _holding():
		_pull(-player.planar_velocity() * DROP_DAMP)
	return true


func _trigger_emp(origin: Vector3) -> void:
	if _emp_triggered or _dead:
		return
	_emp_triggered = true
	emp_arcs += 1
	broken_by = "emp"
	var player = _player()
	if player != null and player.abilities != null and player.abilities.jammed():
		player.abilities.jam_left = 0.0
		emp_stripped += 1
	if is_inside_tree():
		for node in get_tree().get_nodes_in_group("enemy"):
			if node == null or not is_instance_valid(node) or node == self:
				continue
			if node.has_method("is_dead") and node.is_dead():
				continue
			var d := Vector2(node.global_position.x - origin.x, node.global_position.z - origin.z).length()
			if d > EMP_RADIUS:
				continue
			var other_kind := String(node.get("kind"))
			if other_kind == "linker" and node.has_method("cut_cable") and not bool(node.get("cut")):
				node.cut_cable("emp")
				emp_stripped += 1
			elif other_kind == "deflector" and node.has_method("_stagger") and int(node.get("phase")) != Phase.ROAM:
				node._stagger()
				emp_stripped += 1
			elif other_kind == "plated_brute" and int(node.get("plates")) > 0:
				node.set("plates", 0)
				var p_mesh = node.get("_plate")
				if p_mesh != null and is_instance_valid(p_mesh):
					p_mesh.visible = false
				if node.has_method("_stagger"):
					node._stagger()
				emp_stripped += 1
			elif (other_kind == "jolt_layer" or other_kind == "gyro_jammer") and node.has_method("_stagger"):
				if int(node.get("phase")) != Phase.ROAM or node.get("field") != null:
					node._stagger()
					emp_stripped += 1
			if is_ordinary_kind(other_kind) and node.has_method("take_damage") and not node.is_dead():
				node.take_damage(EMP_DAMAGE)
	if world_root != null and is_inside_tree():
		FxLibrary.burst(world_root, "arc_fizz", origin + Vector3.UP * 0.8, 16)
		FxLibrary.burst(world_root, "phase_ring", origin + Vector3.UP * 0.5, 24, Palette.BRASS)
		FxLibrary.burst(world_root, "brass_spark", origin + Vector3.UP * 0.8, 12)
	if holds != null and holds.held(self):
		_release("smash")
	if phase != Phase.ROAM:
		_end()


func _on_end() -> void:
	_dropping = false
	_emp_triggered = false
	_camp_time = 0.0
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE
	if is_instance_valid(_body_node):
		_body_node.transform = Transform3D.IDENTITY


func _pose() -> void:
	if _net != null:
		_net.visible = phase != Phase.LIVE
	if is_instance_valid(_body_node):
		if _dropping:
			var lean := 0.0
			if phase == Phase.WARN:
				var u := clampf(_t / maxf(warn_seconds, 0.001), 0.0, 1.0)
				lean = 0.24 * (u * u * (3.0 - 2.0 * u))
			elif phase == Phase.LIVE:
				lean = 0.24
			_body_node.transform = Transform3D(Basis(Vector3.RIGHT, lean * EnemyMotion.motion_scale), Vector3.ZERO)
		else:
			_body_node.transform = Transform3D.IDENTITY
	if _net_mat != null:
		var charge := 0.3
		if _dropping:
			charge = 1.0
		elif phase == Phase.WARN:
			charge = lerpf(0.35, 1.0, clampf(_t / warn_seconds, 0.0, 1.0))
		_net_mat.set_shader_parameter("charge", charge)
		_net_mat.set_shader_parameter("motion", 0.0 if FlashGuard.on or EnemyMotion.motion_scale <= 0.0 else 1.0)


func _exit_tree() -> void:
	if is_instance_valid(_reaction_bus):
		if _reaction_bus.boosted.is_connected(_on_boost_action):
			_reaction_bus.boosted.disconnect(_on_boost_action)
		if _reaction_bus.dashed.is_connected(_on_boost_action):
			_reaction_bus.dashed.disconnect(_on_boost_action)
		if _reaction_bus.sprint_started.is_connected(_on_boost_action):
			_reaction_bus.sprint_started.disconnect(_on_boost_action)
		if _reaction_bus.blink_used.is_connected(_on_blink_action):
			_reaction_bus.blink_used.disconnect(_on_blink_action)
		if _reaction_bus.slammed.is_connected(_on_player_slammed):
			_reaction_bus.slammed.disconnect(_on_player_slammed)
	super._exit_tree()

extends "res://src/combat/counter.gd"

const FxLibrary := preload("res://src/presentation/fx_library.gd")

const SWEEP_RADIUS := 7.5
const SWEEP_HALF_DEG := 55.0
const PADDLE_REACH := 1.6
const BAT := 0.35
const KNOCK := 16.0
const HP := 45.0

const PRIMARY_WARN := 0.8
const PRIMARY_LIVE := BAT + 0.05

const SKY_WARN := 0.75
const SKY_LIVE := 0.45
const SKY_RADIUS := 7.0
const SKY_MIN_H := 1.1
const SKY_MAX_H := 7.0
const SKY_PRIME_S := 5.0
const SKY_SPIKE_DOWN := 14.0
const SKY_SPIKE_SIDE := 4.0
const SKY_DAMAGE := 6.0
const SKY_VAULT_BOOST := 16.0
const SKY_STUN_S := 2.0

const SWING_S := 0.09
const RETURN_S := 0.28

var swats := 0
var sky_spanks := 0
var sky_vaults := 0
var _paddle: Node3D
var _sweep_dir := Vector3.RIGHT
var _swung := false
var _return_t := 0.0
var _sky_spank := false
var _sky_primed := 0.0
var _sky_vaulted := false
var _sky_spiked := false
static var _shared: Array = []


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, threat: float, spec_ref := {}) -> void:
	super(target_ref, terrain_ref, root_ref, live_ref, threat, spec_ref)
	if _reaction_bus != null:
		if not _reaction_bus.jumped.is_connected(_on_player_jumped):
			_reaction_bus.jumped.connect(_on_player_jumped)
		if not _reaction_bus.slammed.is_connected(_on_player_slammed):
			_reaction_bus.slammed.connect(_on_player_slammed)


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.6
	walk_speed = 4.2
	keep_near = 3.0
	keep_far = 26.0
	attack_range = 7.0
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE
	rest_seconds = 2.4


func _build_tool() -> void:
	var parts := _parts()
	if not parts.is_empty():
		_crew.free()
		_crew = null
		for part in parts:
			var mi := MeshInstance3D.new()
			mi.mesh = part.mesh
			mi.transform = part.xform
			_visual_parent().add_child(mi)
			if part.paddle:
				mi.name = "SwatterPaddle"
				_paddle = mi
			else:
				mi.name = "SwatterBody"
				if part.body >= 0:
					mi.set_surface_override_material(part.body, _material)
		return
	_paddle = Node3D.new()
	_paddle.position = Vector3(0.0, -CREW_HALF + 0.5, 0.0)
	_visual_parent().add_child(_paddle)
	_box(Vector3(0.2, 0.2, 5.5), Palette.CHARCOAL, Vector3(0.0, 0.0, 2.9), 0.0, _paddle)
	_box(Vector3(0.3, 1.0, 1.6), Palette.RUST.darkened(0.2), Vector3(0.0, 0.2, 5.4), 0.0, _paddle)
	_box(Vector3(0.32, 0.18, 1.62), Palette.HAZARD, Vector3(0.0, 0.62, 5.4), 0.6, _paddle)


static var _warned_asset := false


static func _parts() -> Array:
	if not _shared.is_empty():
		return _shared
	var path := ModelVariants.path("res://assets/models/world_one/enemy_swatter.glb")
	if not ResourceLoader.exists(path):
		return _shared
	var packed := load(path) as PackedScene
	if packed == null:
		return _shared
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
				push_warning("swatter: surface has no material; using default finish")
			if surface_material != null and surface_material.resource_name == "fleet_paint":
				body = i
			mesh.surface_set_material(i, painted)
		_shared.append({"mesh": mesh, "xform": mi.transform, "body": body, "paddle": mi.name.begins_with("SwatterPaddle")})
	scene.free()
	return _shared


func _commit(to_ball: Vector3) -> Node3D:
	_facing(to_ball)
	_swung = false
	_return_t = 0.0
	var heading := to_ball.normalized() if to_ball.length() > 0.1 else Vector3.FORWARD
	_sweep_dir = heading.cross(Vector3.UP) * (1.0 if _strafe > 0.0 else -1.0)
	_clear_telegraph()
	if _should_sky_spank(to_ball):
		_sky_spank = true
		_sky_primed = 0.0
		_sky_vaulted = false
		_sky_spiked = false
		warn_seconds = SKY_WARN
		live_seconds = SKY_LIVE
		var floor_y: float = Telegraph.ground_under(terrain, global_position) if terrain != null else global_position.y
		_telegraph = Telegraph.aerial_ring(world_root, terrain, Threat.Type.INSTANT,
			Vector3(global_position.x, floor_y + SKY_MIN_H, global_position.z), SKY_RADIUS, SKY_MAX_H - SKY_MIN_H)
		_facts_begin(_telegraph)
		return _telegraph
	_sky_spank = false
	_sky_vaulted = false
	_sky_spiked = false
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE
	_telegraph = Telegraph.wedge(world_root, terrain, Threat.Type.INSTANT, global_position, heading, SWEEP_RADIUS, SWEEP_HALF_DEG, PADDLE_REACH)
	return _telegraph


func _physics_process(delta: float) -> void:
	_sky_primed = maxf(0.0, _sky_primed - delta)
	super._physics_process(delta)


func _on_player_jumped(_air: bool) -> void:
	if _dead or _sky_spank or phase == Phase.ROAM:
		return
	if _flat_to_ball().length() <= SWEEP_RADIUS + 2.0:
		_sky_primed = SKY_PRIME_S


func _on_player_slammed(at: Vector3, _strength: float, _flatness: float) -> void:
	if _dead or not _sky_spank or _sky_vaulted or phase != Phase.LIVE:
		return
	if Vector2(at.x - global_position.x, at.z - global_position.z).length() <= SKY_RADIUS + 1.0:
		_springboard_vault()


func _should_sky_spank(to_ball: Vector3) -> bool:
	var flat_len := Vector2(to_ball.x, to_ball.z).length()
	if flat_len > SWEEP_RADIUS:
		return false
	if _sky_primed > 0.0:
		return true
	var player = _player()
	if player == null or player.state.on_floor():
		return false
	var ball := _real_ball()
	if Vector2(ball.x - global_position.x, ball.z - global_position.z).length() > SWEEP_RADIUS:
		return false
	var ground_y: float = Telegraph.ground_under(terrain, ball) if terrain != null else global_position.y
	var above := ball.y - ground_y
	return above >= SKY_MIN_H and above < SKY_MAX_H


func _go_live() -> void:
	_swung = true
	if _sky_spank:
		sky_spanks += 1
		if world_root != null and is_inside_tree():
			var tip := _paddle.to_global(Vector3(0.0, 2.4, 2.2)) if is_instance_valid(_paddle) else global_position + Vector3.UP * 2.8
			FxLibrary.burst(world_root, "brass_spark", tip, 12)
			FxLibrary.burst(world_root, "steam_puff", tip, 6)
		_step_sky_spank()
		return
	swats += 1
	if world_root != null and is_inside_tree():
		var tip := _paddle.to_global(Vector3(0.0, 0.3, 3.2)) if is_instance_valid(_paddle) else global_position + _sweep_dir * 2.5 + Vector3.UP * 0.9
		FxLibrary.burst(world_root, "brass_spark", tip, 10)
		FxLibrary.burst(world_root, "steam_puff", tip, 5)
	var wedge := telegraph()
	if wedge == null or not wedge.contains(_real_ball()):
		broken_by = "missed"
		var player = _player()
		if player != null and not player.state.on_floor() and _flat_to_ball().length() <= SWEEP_RADIUS + 1.5:
			_sky_primed = SKY_PRIME_S
		return
	var step := get_physics_process_delta_time()
	_catch(BAT, _sweep_dir * KNOCK / step)


func _step_sky_spank() -> void:
	if _sky_vaulted or _dead:
		return
	var ring := telegraph()
	var player = _player()
	if ring == null or player == null:
		return
	var ball := _real_ball()
	var flat_dist := Vector2(ball.x - global_position.x, ball.z - global_position.z).length()
	var ground_y: float = Telegraph.ground_under(terrain, ball) if terrain != null else global_position.y
	var above := ball.y - ground_y
	if player.kit.slamming and flat_dist <= SKY_RADIUS + 0.8 and above <= SKY_MAX_H + 1.0:
		_springboard_vault()
		return
	if not _sky_spiked and not player.state.on_floor() and ring.contains(ball):
		_sky_spiked = true
		var away := Vector3(ball.x - global_position.x, 0.0, ball.z - global_position.z)
		var side := away.normalized() * SKY_SPIKE_SIDE if away.length() > 0.1 else _sweep_dir * SKY_SPIKE_SIDE
		hit_player.emit(SKY_DAMAGE, Vector3.DOWN * SKY_SPIKE_DOWN + side)


func _springboard_vault() -> void:
	if _sky_vaulted or _dead:
		return
	_sky_vaulted = true
	sky_vaults += 1
	var player = _player()
	if player != null:
		player.kit.slamming = false
		player.kit.slam_fall = 0.0
		var flat: Vector3 = player.planar_velocity()
		var base_speed := flat.length()
		var fwd := flat.normalized() if base_speed > 0.5 else (_flat_to_ball().normalized() if _flat_to_ball().length() > 0.1 else Vector3.FORWARD)
		var launch_dir := (fwd * 0.65 + Vector3.UP * 0.76).normalized()
		player.set_velocity_now(launch_dir * (base_speed + SKY_VAULT_BOOST), "springboard")
		player.refresh_air()
	if world_root != null and is_inside_tree():
		var at := global_position + Vector3.UP * 1.6
		FxLibrary.burst(world_root, "brass_spark", at, 14, Palette.BRASS)
		FxLibrary.burst(world_root, "steam_puff", at, 8)
		FxLibrary.burst(world_root, "slam_ring", at, 16)
	_stagger()
	stun_left = maxf(stun_left, SKY_STUN_S)
	_rest = maxf(_rest, SKY_STUN_S)


func _on_end() -> void:
	_return_t = RETURN_S if not Comfort.reduced_motion else 0.0
	_sky_spank = false
	_sky_vaulted = false
	_sky_spiked = false
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE


func _on_broken(method: String) -> void:
	if method == "boost" and fleet != null:
		fleet.discover("paddle_ride", _real_ball())
	if method == "jump":
		_sky_primed = SKY_PRIME_S


func _live(_delta: float) -> bool:
	if _sky_spank:
		_step_sky_spank()
		return true
	return _holding()


func _pose() -> void:
	if _paddle == null:
		return
	if _sky_spank:
		_paddle.rotation.y = 0.0
		var pitch := 0.0
		if phase == Phase.WARN:
			var u := clampf(_t / maxf(warn_seconds, 0.001), 0.0, 1.0)
			pitch = 0.55 * (u * u * (3.0 - 2.0 * u))
		elif phase == Phase.LIVE:
			var u := clampf(_t / SWING_S, 0.0, 1.0)
			var eased := 1.0 - pow(1.0 - u, 3.0)
			pitch = lerpf(0.55, -1.15, eased)
		_paddle.rotation.x = pitch
		return
	_paddle.rotation.x = 0.0
	var swing := 0.0
	if phase == Phase.WARN:
		var u := clampf(_t / warn_seconds, 0.0, 1.0)
		swing = -0.65 * (u * u * (3.0 - 2.0 * u))
	elif phase == Phase.LIVE:
		var u := clampf(_t / SWING_S, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - u, 3.0)
		swing = lerpf(-0.65, 1.25, eased)
	elif _return_t > 0.0:
		_return_t = maxf(0.0, _return_t - get_physics_process_delta_time())
		var r := _return_t / RETURN_S
		swing = 1.25 * (r * r) * cos((1.0 - r) * PI * 0.65 * Comfort.motion_scale())
	_paddle.rotation.y = swing * (1.0 if _strafe > 0.0 else -1.0)


func _exit_tree() -> void:
	if is_instance_valid(_reaction_bus):
		if _reaction_bus.jumped.is_connected(_on_player_jumped):
			_reaction_bus.jumped.disconnect(_on_player_jumped)
		if _reaction_bus.slammed.is_connected(_on_player_slammed):
			_reaction_bus.slammed.disconnect(_on_player_slammed)
	super._exit_tree()

extends "res://src/combat/counter.gd"

const FloorRule := preload("res://src/combat/floor_rule.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const EnemyBossCraft := preload("res://src/presentation/craft/enemy_boss_craft.gd")
const PropMotionRig := preload("res://src/presentation/prop_motion_rig.gd")

const JAW_RADIUS := 2.4
const LEAD := 0.7
const HOLD := 1.2
const STOP := 14.0
const CENTRE := 10.0
const BITE_DAMAGE := 6.0
const HP := 40.0
const PRIMARY_WARN := 1.0
const PRIMARY_LIVE := 2.0
const JAW_SPREAD := 0.35
const JAW_RISE := 0.18
const JAW_GAPE := 0.6
const SPIT_WARN := 0.85
const SPIT_LIVE := 0.70
const SPIT_RADIUS := 3.2
const SPIT_DAMAGE := 9.0
const SPIT_SHOVE := 5.0
const BENCH_SKIP_LIFT := 26.0
const CANNON_RADIUS := 3.2
const BODY := "res://assets/models/world_two/enemy_pit_jaw.glb"

var bitten := 0
var slam_kills := 0
var spits := 0
var cannon_launches := 0
var clenched := false
var next_attack := ""
var last_cannon_launch := {}
var _spring_spit := false
var _spit_hit := false
var _jaw: MeshInstance3D
var _jaw_rest := Vector3.ZERO
var _jaw_set := Vector3.ZERO
var _jaw_rig: PropMotionRig

static var _shared: Array = []


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, threat: float, spec_ref := {}) -> void:
	super(target_ref, terrain_ref, root_ref, live_ref, threat, spec_ref)
	if _reaction_bus != null:
		_reaction_bus.slammed.connect(_on_slammed)


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.2
	warn_seconds = 1.0
	live_seconds = 2.0
	rest_seconds = 4.0
	attack_range = 20.0


func _build_tool() -> void:
	var parts := _parts()
	if parts.is_empty():
		_jaw = MeshInstance3D.new()
		_jaw.name = "PitJaw"
		_jaw.mesh = EnemyBossCraft.pit_jaw_fallback_mesh(1.5, 0.12)
		_jaw.material_override = EnemyBossCraft.craft_shader_material("pit_jaw_fallback", "oil_slicked_iron", Palette.CHARCOAL, Palette.RUST, 0.64, 0.42, Palette.HAZARD, 0.85)
		_visual_parent().add_child(_jaw)
	else:
		_crew.free()
		_crew = null
		Palette.surface_grain(_material)
		for part in parts:
			var mi := MeshInstance3D.new()
			mi.name = part.name
			mi.mesh = part.mesh
			mi.transform = part.xform
			if part.flash >= 0:
				mi.set_surface_override_material(part.flash, _material)
			if part.name == "PitJaw" or part.name == "CatchCup":
				_jaw = mi
			_visual_parent().add_child(mi)
		if _jaw == null:
			_jaw = _visual_parent().get_child(-1) as MeshInstance3D
	_jaw_rest = Vector3(0.0, -half_height + 0.06, 0.0)
	_jaw.position = _jaw_rest
	_jaw_rig = PropMotionRig.new()
	if _jaw != null and PropMotionRig.is_visual_pivot(_jaw):
		_jaw_rig.add_part("jaw", _jaw, {
			"sway": true,
			"sway_stiffness": 18.0,
			"sway_damping": 5.2,
			"sway_gain": 0.014,
			"sway_max_rad": 0.12,
			"sway_ambient_amp": 0.032,
			"sway_ambient_hz": 0.72,
			"bob_amp": 0.025,
			"bob_hz": 0.85,
		})


static func _parts() -> Array:
	if _shared.is_empty():
		_shared = EnemyCasting.parts(BODY, "pit_jaw")
	return _shared


func _wants_attack(to_ball: Vector3) -> bool:
	var player = _player()
	if player == null or not FloorRule.on_floor(player.state):
		return false
	return to_ball.length() <= attack_range


func _use_spring_spit() -> bool:
	if next_attack == "spring_spit":
		return true
	if next_attack == "bite":
		return false
	return bitten > spits


func _commit(_to_ball: Vector3) -> Node3D:
	var is_spit := _use_spring_spit()
	_spring_spit = is_spit
	next_attack = ""
	if is_spit:
		warn_seconds = SPIT_WARN
		live_seconds = SPIT_LIVE
		clenched = true
		_spit_hit = false
		var aim_spit: Vector3 = _ball() + target.planar_velocity() * LEAD
		var spit_ring := _commit_ring(Threat.Type.PROJECTILE, aim_spit, SPIT_RADIUS, 3.0)
		spit_ring.set_flight(global_position + Vector3.UP * 0.5, Threat.lob_bump(GRAVITY, SPIT_WARN))
		_jaw.top_level = true
		_jaw.global_position = Vector3(global_position.x, Telegraph.ground_under(terrain, global_position) + 0.06, global_position.z)
		_jaw_set = _jaw.global_position
		return spit_ring
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE
	clenched = false
	var aim: Vector3 = _ball() + target.planar_velocity() * LEAD
	var ring := _commit_ring(Threat.Type.INSTANT, aim, JAW_RADIUS, 2.0)
	_jaw.top_level = true
	_jaw.global_position = Vector3(ring.center.x, Telegraph.ground_under(terrain, ring.center) + 0.06, ring.center.z)
	_jaw_set = _jaw.global_position
	return ring


func _go_live() -> void:
	if not _spring_spit:
		return
	spits += 1
	var ring := telegraph()
	if ring == null:
		return
	var player = _player()
	var ball := _real_ball()
	if player != null and FloorRule.on_floor(player.state) and player.speed_tier() < SpeedTier.CRUISE and ring.contains(ball):
		_spit_hit = true
		var out: Vector3 = ball - ring.center
		out.y = 0.0
		var dir := out.normalized() if out.length() > 0.1 else Vector3.FORWARD
		hit_player.emit(SPIT_DAMAGE, dir * SPIT_SHOVE + Vector3.UP * 4.0)


func _live(_delta: float) -> bool:
	var ring := telegraph()
	if ring == null:
		return false
	if _spring_spit:
		return true
	var player = _player()
	var ball := _real_ball()
	if not _holding():
		if player != null and caught_live == 0 and ring.contains(ball) and FloorRule.on_floor(player.state) and _catch(HOLD):
			bitten += 1
			hit_player.emit(BITE_DAMAGE, Vector3.ZERO)
		return true
	var to_centre: Vector3 = ring.center - ball
	to_centre.y = 0.0
	_pull(-player.planar_velocity() * STOP + to_centre * CENTRE)
	return true


func _fire_bench_skip_cannon(at: Vector3) -> void:
	cannon_launches += 1
	var launch_pos := _jaw.global_position if _jaw != null and _jaw.is_inside_tree() else global_position
	last_cannon_launch = {"at": launch_pos, "slam_at": at, "lift": BENCH_SKIP_LIFT, "frame": Engine.get_physics_frames()}
	var player = _player()
	if player != null:
		if player.has_method("body") and player.body() != null and player.has_method("set_velocity_now"):
			var v: Vector3 = player.body().linear_velocity
			var launch := Vector3(v.x, maxf(v.y, BENCH_SKIP_LIFT), v.z)
			player.set_velocity_now(launch, "bench_skip_cannon")
			player.body().linear_velocity = launch
			if "state" in player and player.state != null:
				player.state.velocity = launch
		elif player.has_method("crowd_control"):
			player.crowd_control("bench_skip_cannon", Vector3.UP * BENCH_SKIP_LIFT / maxf(get_physics_process_delta_time(), 0.001))
	if fleet != null:
		fleet.discover("jaw_slam", launch_pos)
	_end()
	stun_left = STAGGER_WINDOW


func on_struck(kind_hit: String, _part: String, _result: Dictionary) -> void:
	if kind_hit == "slam" and clenched and _spring_spit and not is_dead():
		_fire_bench_skip_cannon(global_position)


func _on_slammed(at: Vector3, _strength: float, _flatness: float) -> void:
	if is_dead() or _holding() or (phase != Phase.WARN and phase != Phase.LIVE):
		return
	if clenched and _spring_spit:
		var jaw_pos := _jaw.global_position if _jaw != null and _jaw.is_inside_tree() else global_position
		if Vector2(at.x - jaw_pos.x, at.z - jaw_pos.z).length() <= CANNON_RADIUS:
			_fire_bench_skip_cannon(at)
		return
	if phase == Phase.LIVE and caught_live > 0:
		return
	var ring := telegraph()
	if ring == null:
		return
	if Vector2(at.x - ring.center.x, at.z - ring.center.z).length() <= JAW_RADIUS:
		slam_kills += 1
		if fleet != null:
			fleet.discover("jaw_slam", at)
		take_damage(hp)


func _on_end() -> void:
	clenched = false
	_spring_spit = false
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE
	if _jaw != null:
		_jaw.top_level = false
		_jaw.position = _jaw_rest
		_jaw.scale = Vector3.ONE


func _pose() -> void:
	if _jaw == null:
		return
	if not _jaw.top_level:
		if _jaw_rig != null:
			_jaw_rig.step(get_physics_process_delta_time(), Vector3.ZERO)
		return
	if _jaw_rig != null:
		_jaw_rig.reset()
	if clenched and _spring_spit:
		var coil := clampf(_warn_progress(), 0.0, 1.0) if phase == Phase.WARN else 0.0
		_jaw.global_position = _jaw_set + Vector3.UP * (0.04 * (1.0 - coil))
		_jaw.scale = Vector3(1.0 - 0.15 * coil, 1.0 + 0.35 * coil, 1.0 - 0.15 * coil)
		return
	var part := 0.0
	if not is_dead():
		if phase == Phase.WARN:
			var t := clampf(_warn_progress(), 0.0, 1.0)
			part = t * t * (3.0 - 2.0 * t)
		elif phase == Phase.LIVE and caught_live == 0:
			part = 1.0
	_jaw.global_position = _jaw_set + Vector3.UP * JAW_RISE * part
	_jaw.scale = Vector3(1.0 + JAW_SPREAD * part, 1.0 + JAW_GAPE * part, 1.0 + JAW_SPREAD * part)

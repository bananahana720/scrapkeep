extends "res://src/combat/counter.gd"

const IslandEdge := preload("res://src/combat/island_edge.gd")
const RosterHighdraft := preload("res://src/combat/roster_highdraft.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")

const HP := 900.0
const WALK := 3.0
const DAMAGE_TAKEN := 0.1
const BEACHED_HP := 140.0
const PLANT_WEIGHT := 2.4
const BRACE_WEIGHT := 0.9
const RING_DROP := 3.0
const RIM_DROP := 4.0
const SEEK := 90.0
const POST_IN := 1.5
const POST_NEAR := 1.0
const EDGE_GUARD := 1.5
const RESCAN := 1.0
const SLAM_RADIUS := 5.0
const SLAM_REACH := 2.5
const SLAM_DAMAGE := 12.0
const SLAM_SHOVE := 16.0
const SLAM_LIFT := 5.0
const STAKE_BACK := 4.0
const STAKE_REACH := 2.2
const SLAB_SIZE := Vector3(2.2, 0.5, 1.2)
const BRAKE_DROP := 0.3
const PRIMARY_WARN := 1.1
const PRIMARY_LIVE := 0.2
const TUG_WARN := 0.90
const TUG_LIVE := 1.60
const TUG_LENGTH := 16.0
const TUG_WIDTH := 3.4
const TUG_PULL_ACCEL := 14.0
const CATAPULT_KNOCK := 36.0

var ring_outs := 0
var reeled := 0
var slams := 0
var tugs := 0
var catapults := 0
var tug_active := false
var next_attack := ""
var last_catapult := {}
var beached := false
var posted := false
var rim := {}
var perch_y := INF
var perch_at := Vector3.ZERO
var stake: Node3D
var staked := false

var _scan := 0.0
var _slab: MeshInstance3D
var _brakes: MeshInstance3D
var _brakes_y := 0.0
var _counter_tug := false
var _tug_dir := Vector3.FORWARD
var _tug_stake_temp := false
static var _shared: Array = []


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 8
	weight = PLANT_WEIGHT
	walk_speed = WALK
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE
	rest_seconds = 3.2
	first_rest = 2.0
	attack_range = SLAM_RADIUS + 2.5
	interruptible = true
	impact_resist = 0.6


func _build_tool() -> void:
	var parts := _parts()
	if not parts.is_empty():
		_crew.free()
		_crew = null
		_base_color = Color.WHITE
		_material.albedo_color = _base_color
		_material.vertex_color_use_as_albedo = true
		for part in parts:
			var mi := MeshInstance3D.new()
			mi.name = part.name
			mi.mesh = part.mesh
			mi.transform = part.xform
			if part.flash >= 0:
				mi.set_surface_override_material(part.flash, _material)
			_visual_parent().add_child(mi)
			if part.name == "BallastBrakes":
				_brakes = mi
				_brakes_y = mi.position.y
		return
	_slab = _box(SLAB_SIZE, Palette.CHARCOAL, Vector3(0.0, CREW_HALF + 0.6, 0.0), 0.0, _visual_parent())
	for side in [-1.0, 1.0]:
		_box(Vector3(0.5, 0.7, 0.5), Palette.RUST.darkened(0.3), Vector3(side * 0.75, 0.35 - CREW_HALF + 0.35, 0.0), 0.0, _visual_parent())


func _physics_process(delta: float) -> void:
	weight = BRACE_WEIGHT if phase == Phase.WARN or stunned() else PLANT_WEIGHT
	super(delta)
	if _dead or not _in_play() or target == null:
		return
	_scan -= delta
	if _scan <= 0.0:
		_scan = RESCAN
		_read_rim()
	_watch_stake()
	_watch_footing()


func _watch_footing() -> void:
	if is_on_floor() and _knocked_speed() < 1.0:
		perch_y = global_position.y
		perch_at = global_position
	elif perch_y != INF and global_position.y < perch_y - RING_DROP:
		_ring_out()


func _ring_out() -> void:
	if is_instance_valid(stake):
		_snap_stake()
		reeled += 1
		global_position = perch_at + Vector3.UP * 0.2
		velocity = Vector3.ZERO
		_knock = Vector3.ZERO
		return
	ring_outs += 1
	if fleet != null:
		fleet.discover("ring_out", global_position)
	ring_out()


func _rings_out(_grounded: bool) -> bool:
	return false


func _read_rim() -> void:
	if not rim.is_empty():
		return
	rim = IslandEdge.nearest_rim(terrain, global_position, SEEK, RIM_DROP)
	if rim.is_empty() and not beached:
		_beach()


func _beach() -> void:
	beached = true
	hp = minf(hp, BEACHED_HP * float(spec.get("stage_threat", 1.0)))
	max_hp = hp
	keep_near = 0.0
	keep_far = SLAM_RADIUS * 0.6
	if _slab != null:
		_slab.visible = false


func take_damage(amount: float) -> float:
	return super(amount if beached else amount * DAMAGE_TAKEN)


func _post() -> Vector3:
	var at: Vector3 = rim["at"]
	return at - (rim["dir"] as Vector3) * POST_IN


func _roam(to_ball: Vector3) -> Vector3:
	_facing(to_ball)
	if beached:
		return super(to_ball)
	if rim.is_empty():
		return Vector3.ZERO
	var to := _post() - global_position
	to.y = 0.0
	if posted and to.length() > POST_NEAR * 3.0:
		posted = false
	if posted:
		return Vector3.ZERO
	if to.length() <= POST_NEAR:
		posted = true
		_plant_stake()
		return Vector3.ZERO
	return to.normalized() * walk_speed


func _move(delta: float, desired: Vector3) -> void:
	if desired.length_squared() > 0.0 and IslandEdge.falls_ahead(terrain, global_position, desired, EDGE_GUARD, RING_DROP * 0.5):
		desired = Vector3.ZERO
	super(delta, desired)


func _wants_attack(to_ball: Vector3) -> bool:
	if not is_on_floor():
		return false
	if next_attack == "counter_tug" and not beached:
		return to_ball.length() <= TUG_LENGTH
	return to_ball.length() <= (TUG_LENGTH if slams > tugs and not beached else attack_range)


func _use_counter_tug() -> bool:
	if beached:
		return false
	if next_attack == "counter_tug":
		return true
	if next_attack == "slam":
		return false
	return slams > tugs


func _commit(to_ball: Vector3) -> Node3D:
	var is_tug := _use_counter_tug()
	_counter_tug = is_tug
	next_attack = ""
	if is_tug:
		warn_seconds = TUG_WARN
		live_seconds = TUG_LIVE
		tug_active = true
		var flat := Vector3(to_ball.x, 0.0, to_ball.z)
		_tug_dir = flat.normalized() if flat.length() > 0.1 else Vector3.FORWARD
		_facing(_tug_dir)
		_ensure_tug_stake()
		return _commit_lane(Threat.Type.LANE, global_position, _tug_dir, TUG_LENGTH, TUG_WIDTH, 3.0)
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE
	tug_active = false
	_facing(to_ball)
	return _commit_ring(Threat.Type.INSTANT, global_position, SLAM_RADIUS, SLAM_REACH)


func _go_live() -> void:
	if _counter_tug:
		tugs += 1
		return
	slams += 1
	var ring := telegraph()
	var ball := _real_ball()
	if ring == null or not ring.contains(ball):
		return
	var away := ball - global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else -global_transform.basis.z
	hit_player.emit(SLAM_DAMAGE, away * SLAM_SHOVE + Vector3.UP * SLAM_LIFT)


func _live(_delta: float) -> bool:
	if _counter_tug:
		if not tug_active:
			return false
		var lane := telegraph()
		var player = _player()
		var ball := _real_ball()
		if lane != null and player != null and lane.contains(ball):
			if player.state.grounded and not player.state.carving and player.speed_tier() < SpeedTier.CRUISE:
				var pull := global_position - ball
				pull.y = 0.0
				if pull.length() > 0.5:
					player.add_external_accel(pull.normalized() * TUG_PULL_ACCEL)
		return _t < live_seconds
	return _t < live_seconds


func _on_end() -> void:
	_counter_tug = false
	tug_active = false
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE
	if _tug_stake_temp:
		_tug_stake_temp = false
		_snap_stake()


func _pose() -> void:
	var lift := clampf(_t / warn_seconds, 0.0, 1.0) if phase == Phase.WARN else 0.0
	if _brakes != null:
		_brakes.position.y = _brakes_y - BRAKE_DROP * lift
	if _slab == null or beached:
		return
	_slab.position.y = CREW_HALF + 0.6 + 1.0 * lift
	_slab.rotation.x = -0.3 * lift


func _plant_stake() -> void:
	if staked or rim.is_empty() or not RosterHighdraft.grown(self):
		return
	staked = true
	_tug_stake_temp = false
	_spawn_stake_node()


func _ensure_tug_stake() -> void:
	if is_instance_valid(stake):
		return
	_tug_stake_temp = true
	_spawn_stake_node()


func _spawn_stake_node() -> void:
	if world_root == null:
		return
	var back_dir: Vector3 = (rim["dir"] as Vector3) if not rim.is_empty() else -_tug_dir
	var back := global_position - back_dir * STAKE_BACK
	stake = Node3D.new()
	stake.name = "BallastStake"
	world_root.add_child(stake)
	stake.global_position = Vector3(back.x, terrain.height(back.x, back.z) if terrain != null else back.y, back.z)
	_cylinder(0.14, 1.5, Palette.BRASS, Vector3(0.0, 0.75, 0.0), 0.9, stake)


func _watch_stake() -> void:
	if not is_instance_valid(stake):
		return
	var ball := _real_ball()
	if Vector2(ball.x - stake.global_position.x, ball.z - stake.global_position.z).length() <= STAKE_REACH \
			and absf(ball.y - stake.global_position.y) < 2.5:
		var during_tug := tug_active
		_tug_stake_temp = false
		_snap_stake()
		if during_tug:
			_catapult_off_cliff()


func _catapult_off_cliff() -> void:
	tug_active = false
	_counter_tug = false
	catapults += 1
	broken_by = "stake_catapult"
	last_catapult = {"at": global_position, "frame": Engine.get_physics_frames()}
	weight = BRACE_WEIGHT
	var out_dir: Vector3 = (rim["dir"] as Vector3) if not rim.is_empty() else -_tug_dir
	out_dir.y = 0.0
	out_dir = out_dir.normalized() if out_dir.length() > 0.1 else Vector3.FORWARD
	knock(out_dir + Vector3.UP * 0.45, CATAPULT_KNOCK)
	if fleet != null:
		fleet.discover("ring_out", global_position)


func _snap_stake() -> void:
	if is_instance_valid(stake):
		stake.queue_free()
	stake = null


static func _parts() -> Array:
	if _shared.is_empty():
		_shared = EnemyCasting.parts("res://assets/models/world_three/enemy_ballast_heavy.glb", "ballast_heavy")
	return _shared


func _exit_tree() -> void:
	_snap_stake()
	super._exit_tree()

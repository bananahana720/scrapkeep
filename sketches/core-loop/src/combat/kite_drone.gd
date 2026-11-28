extends "res://src/combat/counter.gd"

const SpeedTier := preload("res://src/core/speed_tier.gd")
const IslandEdge := preload("res://src/combat/island_edge.gd")
const RosterHighdraft := preload("res://src/combat/roster_highdraft.gd")
const SwingArc := preload("res://src/combat/swing_arc.gd")
const Tuning := preload("res://src/movement/tuning.gd")

const HOVER := 6.0
const CLIMB := 4.0
const DIVE := 0.7
const MARK_RADIUS := 2.4
const MARK_REACH := 2.0
const AIR_MIN := 2.0
const AIR_BAND := 5.0
const DIVE_DAMAGE := 9.0
const BAT_KICK := 12.0
const HP := 70.0
const RETARGET := 2.0
const THERMAL_REACH := 40.0
const RIDE_ABOVE := 11.0
const CIRCLE := 2.5
const CIRCLE_RATE := 1.2
const AIR_REACH := 2.6
const AIR_RAM_SPEED := 5.0
const AIR_CLEAR := 2.0
const GAP_REACH := 40.0
const GAP_OUT := 6.0
const RIM_DROP := 4.0
const DROP_KICK := 8.0
const FLING := 4.0
const PRIMARY_WARN := 0.8
const PRIMARY_LIVE := DIVE + 0.3
const SWOOP_WARN := 0.85
const SWOOP_LIVE := 1.0
const SWOOP_LENGTH := 26.0
const SWOOP_WIDTH := 4.2
const SWOOP_DAMAGE := 7.0
const SLIPSTREAM_DURATION := 3.0
const SLIPSTREAM_LIFT := 14.0
const SLIPSTREAM_PUSH := 28.0
const SLIPSTREAM_KICK := 12.0

var dives := 0
var batted := 0
var air_rams := 0
var swoops := 0
var slipstream_rides := 0
var slipstream_active := false
var slipstream_left := 0.0
var slipstream_origin := Vector3.ZERO
var slipstream_dir := Vector3.FORWARD
var slipstream_carry_m := 0.0
var next_attack := ""
var ride_at := Vector3.ZERO
var ride_y := INF
var riding := ""
var _retarget := 0.0
var _orbit := 0.0
var _dive_from := Vector3.ZERO
var _landed := false
var _swoop := false
var _swoop_from := Vector3.ZERO
var _swoop_to := Vector3.ZERO
var _swoop_dir := Vector3.FORWARD
var _swoop_hit := false
var _swoop_ridden := false
var _wake_mesh: Node3D = null
static var _warned_asset := false
static var _shared: Dictionary = {}
var _windup_rig: Skeleton3D
var _wing_bones: Array[int] = []
var _paw_bones: Array[int] = []
var _chin: MeshInstance3D


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 0.7
	walk_speed = 6.0
	keep_near = 6.0
	keep_far = 16.0
	attack_range = 30.0
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE
	rest_seconds = 3.0
	interruptible = false


func _build_tool() -> void:
	var parts := _parts()
	if not parts.is_empty():
		_crew.free()
		_crew = null
		_base_color = Color.WHITE
		_material.albedo_color = _base_color
		_material.vertex_color_use_as_albedo = true
		_windup_rig = parts.rig.instantiate() as Skeleton3D
		_visual_parent().add_child(_windup_rig)
		for bone_name in ["KiteWingLeft", "KiteWingRight"]:
			_wing_bones.append(_windup_rig.find_bone(bone_name))
		for bone_name in ["KitePawLeft", "KitePawRight"]:
			_paw_bones.append(_windup_rig.find_bone(bone_name))
		for part in parts.meshes:
			var mi := MeshInstance3D.new()
			mi.name = part.name
			mi.mesh = part.mesh
			mi.transform = part.xform
			_visual_parent().add_child(mi)
			if part.skin != null:
				mi.skin = part.skin
				mi.skeleton = mi.get_path_to(_windup_rig)
			for surface in part.flash:
				mi.set_surface_override_material(surface, _material)
			if part.name == "DiveChin":
				_chin = mi
		return
	var fallback := MeshInstance3D.new()
	fallback.name = "KiteChassisFallback"
	fallback.mesh = preload("res://src/presentation/world23_chunk_craft.gd").get_kite_chassis_mesh()
	fallback.position = Vector3(0.0, CREW_HALF + 0.38, 0.0)
	_crew.add_child(fallback)


static func _parts() -> Dictionary:
	if not _shared.is_empty():
		return _shared
	var path := "res://assets/models/world_three/enemy_kite_drone.glb"
	if not ResourceLoader.exists(path):
		return _shared
	var packed := load(path) as PackedScene
	if packed == null:
		return _shared
	var scene := packed.instantiate()
	var rig := scene.find_child("Skeleton3D", true, false) as Skeleton3D
	if rig == null:
		scene.free()
		return _shared
	var meshes := []
	var painted := PaletteMaterials.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	preload("res://src/presentation/craft/craft_lookdev.gd").enrich_standard_pbr(painted, 0.34, 0.35)
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var source := node as MeshInstance3D
		var mesh: Mesh = source.mesh.duplicate()
		var flash := []
		for i in mesh.get_surface_count():
			var surface_material := mesh.surface_get_material(i)
			if surface_material == null and not _warned_asset:
				_warned_asset = true
				push_warning("kite_drone: surface has no material; using default finish")
			if surface_material != null and surface_material.resource_name == "fleet_paint":
				flash.append(i)
			mesh.surface_set_material(i, painted)
		meshes.append({"name": source.name, "mesh": mesh, "skin": source.skin,
			"xform": _asset_transform(source, scene), "flash": flash})
	rig.transform = _asset_transform(rig, scene)
	for child in rig.get_children():
		child.free()
	rig.get_parent().remove_child(rig)
	var packed_rig := PackedScene.new()
	packed_rig.pack(rig)
	rig.free()
	_shared = {"rig": packed_rig, "meshes": meshes}
	scene.free()
	return _shared


static func _asset_transform(node: Node3D, scene: Node3D) -> Transform3D:
	var xform := node.transform
	var parent := node.get_parent() as Node3D
	while parent != null and parent != scene:
		xform = parent.transform * xform
		parent = parent.get_parent() as Node3D
	return xform


func _pose() -> void:
	if _windup_rig == null:
		return
	var tension := 0.0
	if phase == Phase.WARN:
		tension = clampf(_warn_progress(), 0.0, 1.0)
	elif phase == Phase.LIVE:
		tension = 1.0
	for i in _wing_bones.size():
		var rest := _windup_rig.get_bone_rest(_wing_bones[i])
		var axis := _windup_rig.basis.inverse() * Vector3.BACK
		var tilt := Basis(axis, deg_to_rad((-5.0 if i == 0 else 5.0) * tension))
		_windup_rig.set_bone_pose_rotation(_wing_bones[i],
			(tilt * rest.basis).get_rotation_quaternion())
	for bone in _paw_bones:
		var rest := _windup_rig.get_bone_rest(bone)
		_windup_rig.set_bone_pose_position(bone,
			rest.origin + _windup_rig.basis.inverse() * Vector3(0.0, 0.08, -0.08) * tension)
	if _chin != null:
		_chin.rotation.x = deg_to_rad(12.0 * tension)


func _wants_attack(to_ball: Vector3) -> bool:
	return to_ball.length() <= attack_range


func _use_swoop(_to_ball: Vector3) -> bool:
	if next_attack == "slipstream":
		return true
	if next_attack == "dive":
		return false
	var player = _player()
	if player == null or player.kit.hooked:
		return false
	var ball := _real_ball()
	var crossing_gap: bool = player.kit.gliding \
		or (terrain != null and not player.state.grounded and ball.y - Telegraph.ground_under(terrain, ball) >= 6.0)
	return dives > swoops and crossing_gap


func _commit(to_ball: Vector3) -> Node3D:
	var is_swoop := _use_swoop(to_ball)
	_swoop = is_swoop
	next_attack = ""
	if is_swoop:
		warn_seconds = SWOOP_WARN
		live_seconds = SWOOP_LIVE
		var flat := Vector3(to_ball.x, 0.0, to_ball.z)
		_swoop_dir = flat.normalized() if flat.length() > 0.1 else Vector3.FORWARD
		_facing(_swoop_dir)
		_swoop_from = global_position
		_swoop_to = _swoop_from + _swoop_dir * SWOOP_LENGTH
		_swoop_hit = false
		return _commit_lane(Threat.Type.LANE, global_position, _swoop_dir, SWOOP_LENGTH, SWOOP_WIDTH, 4.0)
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE
	var landing: Vector3 = _ball() + target.planar_velocity() * (DIVE + warn_seconds)
	_facing(to_ball)
	_dive_from = global_position
	var swing: Vector3 = SwingArc.forecast(_player(), DIVE + warn_seconds)
	if swing != Vector3.INF:
		landing = swing
		var ground: float = terrain.height(landing.x, landing.z) if terrain != null else 0.0
		if landing.y - ground > AIR_MIN:
			_clear_telegraph()
			_telegraph = Telegraph.aerial_ring(world_root, terrain, Threat.Type.INSTANT,
				landing - Vector3.UP * AIR_BAND * 0.5, MARK_RADIUS, AIR_BAND)
			_facts_begin(_telegraph)
			return _telegraph
	return _commit_ring(Threat.Type.INSTANT, landing, MARK_RADIUS, MARK_REACH)


func _go_live() -> void:
	if _swoop:
		swoops += 1
		_swoop_from = global_position
		_swoop_to = _swoop_from + _swoop_dir * SWOOP_LENGTH
		_swoop_hit = false
		_start_slipstream(_swoop_from, _swoop_dir)
		return
	dives += 1
	_landed = false


func _live(_delta: float) -> bool:
	var ring := telegraph()
	if ring == null:
		return false
	if _swoop:
		var frac := clampf(_t / maxf(SWOOP_LIVE, 0.05), 0.0, 1.0)
		var pos := _swoop_from.lerp(_swoop_to, frac)
		pos.y -= sin(frac * PI) * 2.5
		global_position = _short_of_ball(global_position, pos)
		var player = _player()
		var ball := _real_ball()
		if not _swoop_hit and player != null and player.state.grounded \
				and player.speed_tier() < SpeedTier.CRUISE and ring.contains(ball) \
				and ball.distance_to(global_position) <= 3.0:
			_swoop_hit = true
			hit_player.emit(SWOOP_DAMAGE, _swoop_dir * 4.0 + Vector3.UP * 5.0)
		return _t < SWOOP_LIVE
	if _t < DIVE:
		global_position = _short_of_ball(global_position, _dive_from.lerp(_dive_goal(ring), _t / DIVE))
		return true
	if not _landed:
		global_position = _short_of_ball(global_position, _dive_goal(ring))
		_landed = true
		var ball := _real_ball()
		if ring.contains(ball):
			var dir := ball - global_position
			dir.y = 0.0
			dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
			hit_player.emit(DIVE_DAMAGE, dir * 6.0 + Vector3.UP * 3.0)
		elif fleet != null:
			fleet.discover("thermal_dive", ball)
	return false


func _on_end() -> void:
	_swoop = false
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE


func _start_slipstream(origin: Vector3, dir: Vector3) -> void:
	_clear_wake()
	slipstream_active = true
	slipstream_left = SLIPSTREAM_DURATION
	slipstream_origin = origin
	slipstream_dir = dir
	slipstream_carry_m = 0.0
	_swoop_ridden = false
	if world_root != null:
		var craft := preload("res://src/presentation/world23_chunk_craft.gd")
		var ribbon := Node3D.new()
		ribbon.name = "SlipstreamWake"
		var mesh := MeshInstance3D.new()
		mesh.mesh = craft.get_kite_wake_mesh(SWOOP_LENGTH)
		mesh.scale = Vector3(SWOOP_WIDTH * 1.4, 1.0, 1.0)
		mesh.material_override = craft.build_slipstream_wake_material(Color(Palette.ICE, 0.34))
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ribbon.add_child(mesh)
		world_root.add_child(ribbon)
		ribbon.global_position = origin + dir * (SWOOP_LENGTH * 0.5)
		ribbon.global_basis = Basis.looking_at(dir, Vector3.UP)
		_wake_mesh = ribbon


func _step_slipstream(delta: float) -> void:
	if not slipstream_active:
		return
	slipstream_left -= delta
	if slipstream_left <= 0.0:
		_clear_wake()
		return
	var player = _player()
	if player == null:
		return
	var ball := _real_ball()
	var rel := ball - slipstream_origin
	var along := Vector3(rel.x, 0.0, rel.z).dot(slipstream_dir)
	var side := slipstream_dir.cross(Vector3.UP).normalized()
	var lateral := absf(Vector3(rel.x, 0.0, rel.z).dot(side))
	var dy := ball.y - slipstream_origin.y
	if along < -2.0 or along > SWOOP_LENGTH + 2.0 or lateral > SWOOP_WIDTH * 0.85 or dy < -6.0 or dy > 10.0:
		return
	if player.state.grounded or player.kit.hooked or player.planar_velocity().dot(slipstream_dir) < 2.0:
		return
	if not _swoop_ridden:
		_swoop_ridden = true
		slipstream_rides += 1
		var v: Vector3 = player.state.velocity
		var boosted: Vector3 = v + slipstream_dir * SLIPSTREAM_KICK + Vector3.UP * 4.5
		if player.has_method("set_velocity_now"):
			player.set_velocity_now(boosted, "slipstream")
		if fleet != null:
			fleet.discover("thermal_dive", ball)
	player.add_external_accel(slipstream_dir * SLIPSTREAM_PUSH + Vector3.UP * SLIPSTREAM_LIFT)
	slipstream_carry_m += maxf(0.0, player.planar_velocity().dot(slipstream_dir)) * delta


func _clear_wake() -> void:
	slipstream_active = false
	slipstream_left = 0.0
	if is_instance_valid(_wake_mesh):
		_wake_mesh.queue_free()
	_wake_mesh = null


func _exit_tree() -> void:
	_clear_wake()
	super._exit_tree()


func _short_of_ball(from: Vector3, to: Vector3) -> Vector3:
	var ball := _real_ball()
	if _touching(to, ball):
		if _touching(from, ball):
			return from
		var clear := 0.0
		var steps := 32
		var blocked := 1.0
		for i in range(1, steps + 1):
			var s := float(i) / steps
			if _touching(from.lerp(to, s), ball):
				blocked = s
				break
			clear = s
		for i in 10:
			var mid := (clear + blocked) * 0.5
			if _touching(from.lerp(to, mid), ball):
				blocked = mid
			else:
				clear = mid
		return from.lerp(to, clear)
	return to


func _touching(at: Vector3, ball: Vector3) -> bool:
	var spine := maxf(half_height - radius, 0.0)
	var offset := ball - at
	var along := clampf(offset.y, -spine, spine)
	var gap := Vector3(offset.x, offset.y - along, offset.z).length()
	return gap < Tuning.RADIUS + radius


func _dive_goal(ring: Node3D) -> Vector3:
	return ring.center + Vector3.UP * (ring.reach_up * 0.5 if ring.aerial else 0.5)


func _diving() -> bool:
	return phase == Phase.LIVE and not _landed


func _physics_process(delta: float) -> void:
	super(delta)
	_step_slipstream(delta)
	if _dead or not _in_play() or target == null:
		return
	_retarget -= delta
	if _retarget <= 0.0:
		_retarget = RETARGET
		_pick_ride()
	_watch_air_ram()


func _pick_ride() -> void:
	var ball := _real_ball()
	var under: float = terrain.height(ball.x, ball.z) if terrain != null else ball.y
	if RosterHighdraft.grown(self):
		var rim := IslandEdge.nearest_rim(terrain, ball, GAP_REACH, RIM_DROP)
		if not rim.is_empty():
			riding = "gap"
			ride_at = (rim["at"] as Vector3) + (rim["dir"] as Vector3) * GAP_OUT
			ride_y = (rim["at"] as Vector3).y + RIDE_ABOVE
			return
	var best := {}
	var best_d := THERMAL_REACH
	for spec in _thermals():
		var at: Vector2 = spec["at"]
		var d := Vector2(ball.x, ball.z).distance_to(at)
		if d <= best_d:
			best_d = d
			best = spec
	if best.is_empty():
		riding = ""
		ride_y = INF
		return
	var at: Vector2 = best["at"]
	var base: float = terrain.height(at.x, at.y) if terrain != null else 0.0
	riding = "thermal"
	ride_at = Vector3(at.x, base, at.y)
	ride_y = clampf(under + RIDE_ABOVE, base + 4.0, base + float(best["height"]) - 2.0)


func _thermals() -> Array:
	var out := []
	if terrain == null:
		return out
	var source = terrain if terrain.has_method("map") else (terrain.get("ctx").terrain if terrain.get("ctx") != null else null)
	if source == null or not source.has_method("map"):
		return out
	var m = source.map()
	if m == null or m.get("contraptions") == null:
		return out
	for spec in m.contraptions:
		if String(spec.get("kind", "")) == "thermal" and spec.get("at") is Vector2:
			out.append(spec)
	return out


func _watch_air_ram() -> void:
	var player = _player()
	if player == null or phase == Phase.LIVE or player.state.grounded:
		return
	if _real_ball().distance_to(global_position) > AIR_REACH or player.state.velocity.length() < AIR_RAM_SPEED:
		return
	if terrain != null and global_position.y - terrain.height(global_position.x, global_position.z) < AIR_CLEAR:
		return
	air_rams += 1
	last_damage_source = "air_ram"
	if RosterHighdraft.grown(self) and riding == "gap":
		var heading: Vector3 = player.planar_velocity()
		heading = heading.normalized() if heading.length() > 0.1 else Vector3.ZERO
		var tick := 1.0 / float(Engine.physics_ticks_per_second)
		player.add_external_accel((Vector3.DOWN * DROP_KICK + heading * FLING) / tick)
	if fleet != null:
		fleet.discover("thermal_dive", global_position)
	take_damage(hp + 1.0)


func on_struck(kind: String, _part: String, _result: Dictionary) -> void:
	if kind == "ram" and _diving() and _player().speed_tier() >= SpeedTier.CRUISE:
		batted += 1
		broken_by = "batted"
		knock(Vector3.UP + (_dive_from - global_position).normalized(), BAT_KICK)
	elif kind != "ram" and kind != "slam" and not _diving() and fleet != null:
		fleet.discover("thermal_dive", global_position)


func _move(delta: float, desired: Vector3) -> void:
	var horizontal := Vector3(_knock.x, 0.0, _knock.z)
	if horizontal.length() < 1.0:
		horizontal = desired
	if ride_y != INF and phase == Phase.ROAM and horizontal == desired:
		_orbit += CIRCLE_RATE * delta
		var goal := ride_at + Vector3(cos(_orbit), 0.0, sin(_orbit)) * CIRCLE - global_position
		goal.y = 0.0
		horizontal = goal.normalized() * minf(walk_speed, goal.length() / maxf(delta, 0.001)) if goal.length() > 0.05 else Vector3.ZERO
	if _diving():
		velocity = Vector3.ZERO
	else:
		var ground: float = terrain.height(global_position.x, global_position.z) if terrain != null else 0.0
		var height := maxf(ground + 2.0, _ball().y + HOVER) if ride_y == INF else ride_y
		velocity = Vector3(horizontal.x, (height - global_position.y) * CLIMB, horizontal.z)
		if _knock.y > 0.0:
			velocity.y = _knock.y
		_knock.y = 0.0
	move_and_slide()
	_knock = _knock.move_toward(Vector3.ZERO, KNOCK_DECAY * delta)

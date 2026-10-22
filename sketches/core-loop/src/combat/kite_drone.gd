extends "res://src/combat/counter.gd"

const SpeedTier := preload("res://src/movement/speed_tier.gd")
const IslandEdge := preload("res://src/combat/island_edge.gd")
const RosterHighdraft := preload("res://src/combat/roster_highdraft.gd")
const SwingArc := preload("res://src/combat/swing_arc.gd")

# The kite drone (roster_highdraft.gd): it marks where the ball will be in DIVE + warn seconds
# and, when the mark fills, dives onto it in DIVE seconds. A ball that meets the diving drone at
# cruise or faster bats it back up; a slower ball just takes the dive.
#
# Between dives it rides a thermal (design-v3/WORLD-ROSTERS.md): every RETARGET seconds it takes
# the map's thermal column nearest the ball within THERMAL_REACH and circles it at RIDE_ABOVE over
# the ground under the ball, held inside the column. That height is fixed while it rides, so a
# ball that glides up the same column reaches it, and an airborne ball that hits it there (an
# air ram: AIR_REACH centre to centre, at AIR_RAM_SPEED or more, while the drone is AIR_CLEAR
# off the ground, so its own dive landing on a hopping ball is no ram) kills it outright. Its pool is deep, so a ground answer
# (bolts while it circles) still works, slowly. A map with no thermal leaves it hovering HOVER
# over the ball's own height, as before.
#
# A latched ball is not on the ground, so a ground mark (MARK_REACH) would never touch it. While
# the line stands the lead follows the pendulum arc (swing_arc.gd), not the ball's straight-line
# velocity, and a forecast above AIR_MIN hangs the mark in the air: a ring at the forecast
# height, AIR_BAND tall, drawn and hit-tested as that band. The drone dives to the band's middle.
# The warn is still warn_seconds (0.8), so the telegraph stays above the 0.6 s floor.
#
# Grown remix: it circles over the nearest gap instead (GAP_OUT past the rim nearest the ball),
# and the air-ram kill drops the ball (DROP_KICK down, FLING on along its heading) toward the
# next island.

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

var dives := 0
var batted := 0
var air_rams := 0
# Where it circles and at what height while riding, or ride_y INF when it hovers by the ball.
var ride_at := Vector3.ZERO
var ride_y := INF
var riding := ""
var _retarget := 0.0
var _orbit := 0.0
var _dive_from := Vector3.ZERO
var _landed := false
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
	warn_seconds = 0.8
	live_seconds = DIVE + 0.3
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
	_box(Vector3(3.2, 0.12, 0.7), Palette.CHARCOAL, Vector3(0.0, CREW_HALF + 0.4, 0.0), 0.0, _crew)
	_cylinder(0.5, 0.9, Palette.RUST, Vector3(0.0, CREW_HALF + 0.1, 0.0), 0.0, _crew)


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
	var painted := Palette.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
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


func _commit(to_ball: Vector3) -> Node3D:
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
	dives += 1
	_landed = false


func _live(_delta: float) -> bool:
	var ring := telegraph()
	if ring == null:
		return false
	if _t < DIVE:
		global_position = _dive_from.lerp(_dive_goal(ring), _t / DIVE)
		return true
	if not _landed:
		global_position = _dive_goal(ring)
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


# Where the dive ends: just above a ground ring, the middle of an aerial one's band.
func _dive_goal(ring: Node3D) -> Vector3:
	return ring.center + Vector3.UP * (ring.reach_up * 0.5 if ring.aerial else 0.5)


func _diving() -> bool:
	return phase == Phase.LIVE and not _landed


func _physics_process(delta: float) -> void:
	super(delta)
	if _dead or not _in_play() or target == null:
		return
	_retarget -= delta
	if _retarget <= 0.0:
		_retarget = RETARGET
		_pick_ride()
	_watch_air_ram()


# The column (or, grown, the gap) it rides until the next retarget.
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


# The thermals of the stage map. Combat hands enemies its ground (combat/ground.gd), which
# carries the context; a bare terrain answers map() itself.
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


# An airborne ball that reaches it while it rides kills it outright; the dive and its landing
# are not riding, so the bat stays the dive's answer.
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

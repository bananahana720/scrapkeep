extends "res://src/combat/counter.gd"

# The winch drone (DESIGN-V2 section 10): a rotor with a winch drum slung beneath. It
# hovers HOVER metres up, out of ramming reach, so a gun or a jump is how you reach it.
# Its warning is a lane down its cable's line toward the ball; when it fills, a ball
# the lane contains is hooked and winched toward the pack (the middle of the other
# enemies near it, or the drone itself when it flies alone) at PULL for up to WINCH
# seconds, through the hold bound (holds.gd). A jump, a boost or a smash snaps the cable,
# and so does planar speed at SNAP_SPEED, which kicks the ball forward; so does killing the
# drone. It draws no cable of its own (holds.gd draws the binding), so strain() is the
# reading a cable glow would take.

const HOVER := 5.5
const CLIMB := 4.0
const LANE_LENGTH := 20.0
const LANE_WIDTH := 2.2
const PULL := 7.0
const WINCH := 1.8
const PACK_REACH := 30.0
const SNAP_SPEED := 19.0
const HP := 30.0

var winched := 0
var _rotor: MeshInstance3D


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 0.8
	walk_speed = 5.0
	keep_near = 8.0
	keep_far = 22.0
	attack_range = 18.0
	warn_seconds = 1.0
	live_seconds = WINCH + 0.1
	rest_seconds = 3.5
	row = row.duplicate()
	row["breaks"] = (row["breaks"] as Array) + ["speed"]


# C18 dressing (enemy_winch_drone.glb): a small Fleet oxide crew under one flat 16-sided rotor
# (1.6 m radius, 2.0 m up) with a cable drum hung low on a central hanger, the cable's exit
# clear ahead of it. _pose turns the rotor about its own axis each physics tick. The glb is read
# once and its meshes are shared; each drone adds only its own flashing body material, set on the
# glb's fleet_paint surface (Fleet oxide, RUST).
static var _shared: Array = []


func _build_tool() -> void:
	_crew.free()
	_crew = null
	var dressing := Node3D.new()
	dressing.name = "WinchBody"
	_visual_parent().add_child(dressing)
	for part in _parts():
		var mi := MeshInstance3D.new()
		mi.mesh = part.mesh
		mi.transform = part.xform
		if part.rotor:
			mi.name = "WinchRotor"
			_rotor = mi
			_visual_parent().add_child(mi)
		else:
			mi.name = "Body"
			mi.set_surface_override_material(part.body, _material)
			dressing.add_child(mi)


static func _parts() -> Array:
	if not _shared.is_empty():
		return _shared
	var scene := (load("res://assets/models/world_one/enemy_winch_drone.glb") as PackedScene).instantiate()
	var painted := Palette.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mesh: Mesh = mi.mesh.duplicate()
		var body := 0
		for i in mesh.get_surface_count():
			if mesh.surface_get_material(i).resource_name == "fleet_paint":
				body = i
			mesh.surface_set_material(i, painted)
		_shared.append({"mesh": mesh, "xform": mi.transform, "body": body, "rotor": mi.name.begins_with("WinchRotor")})
	scene.free()
	return _shared


func _wants_attack(to_ball: Vector3) -> bool:
	return to_ball.length() <= attack_range


func _commit(to_ball: Vector3) -> Node3D:
	_facing(to_ball)
	return _commit_lane(Threat.Type.LANE, global_position, to_ball, LANE_LENGTH, LANE_WIDTH)


func _go_live() -> void:
	var lane := telegraph()
	if lane == null or not lane.contains(_real_ball()) or not _catch(WINCH, Vector3.ZERO, global_position):
		broken_by = "missed"
		return
	winched += 1


func _live(_delta: float) -> bool:
	if not _holding():
		return false
	if strain() >= 1.0:
		holds.snap(self, "speed")
		return false
	var to := pack_centre() - _real_ball()
	to.y = 0.0
	if to.length() > 1.5:
		_pull(to.normalized() * PULL)
	return true


# How taut the cable is, 0 to 1: the ball's planar speed over the speed that snaps it.
func strain() -> float:
	var player = _player()
	if player == null:
		return 0.0
	return clampf(player.planar_velocity().length() / SNAP_SPEED, 0.0, 1.0)


# Where it winches you: the middle of the other enemies within PACK_REACH, or itself.
func pack_centre() -> Vector3:
	var sum := Vector3.ZERO
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == self or not is_instance_valid(enemy) or enemy.is_dead():
			continue
		if enemy.global_position.distance_to(global_position) <= PACK_REACH:
			sum += enemy.global_position
			count += 1
	return sum / count if count > 0 else global_position


func _move(delta: float, desired: Vector3) -> void:
	var horizontal := Vector3(_knock.x, 0.0, _knock.z)
	if horizontal.length() < 1.0:
		horizontal = desired
	var ground: float = terrain.height(global_position.x, global_position.z) if terrain != null else 0.0
	velocity = Vector3(horizontal.x, (ground + HOVER - global_position.y) * CLIMB, horizontal.z)
	move_and_slide()
	_knock = _knock.move_toward(Vector3.ZERO, KNOCK_DECAY * delta)


func _pose() -> void:
	if _rotor != null:
		_rotor.rotation.y += 0.6

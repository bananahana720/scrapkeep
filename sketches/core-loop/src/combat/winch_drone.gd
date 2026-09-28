extends "res://src/combat/counter.gd"

# The winch drone (DESIGN-V2 section 10): a rotor with a winch drum slung beneath. It
# hovers HOVER metres up, out of ramming reach, so a gun or a jump is how you reach it.
# Its warning is a lane down its cable's line toward the ball; when it fills, a ball
# the lane contains is hooked and winched toward the pack (the middle of the other
# enemies near it, or the drone itself when it flies alone) at PULL for up to WINCH
# seconds. A jump, a boost or a smash snaps the cable; so does killing the drone.

const Bolts := preload("res://src/combat/bolts.gd")

const HOVER := 5.5
const CLIMB := 4.0
const LANE_LENGTH := 20.0
const LANE_WIDTH := 2.2
const PULL := 7.0
const WINCH := 1.8
const PACK_REACH := 30.0
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


func _build_tool() -> void:
	_rotor = _cylinder(1.6, 0.08, Palette.CHARCOAL, Vector3(0.0, CREW_HALF + 0.9, 0.0))
	_cylinder(0.08, 0.9, Palette.CHARCOAL, Vector3(0.0, CREW_HALF + 0.45, 0.0))
	var drum := _cylinder(0.45, 0.9, Palette.BRASS, Vector3(0.0, -CREW_HALF - 0.2, 0.0), 0.2)
	drum.rotation.z = PI * 0.5


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
	var to := pack_centre() - _real_ball()
	to.y = 0.0
	if to.length() > 1.5:
		_pull(to.normalized() * PULL)
	return true


# Where it winches you: the middle of the other enemies within PACK_REACH, or itself.
func pack_centre() -> Vector3:
	var sum := Vector3.ZERO
	var count := 0
	for enemy in Bolts.enemy_snapshot(get_tree()):
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

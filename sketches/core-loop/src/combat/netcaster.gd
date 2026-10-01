extends "res://src/combat/counter.gd"

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


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.1
	warn_seconds = 1.2
	live_seconds = 2.6
	rest_seconds = 3.5
	attack_range = 24.0


func _build_tool() -> void:
	for side in [-1.0, 1.0]:
		_cylinder(0.1, MAST_HEIGHT, Palette.CHARCOAL, Vector3(side * 1.2, MAST_HEIGHT * 0.5 - CREW_HALF, -0.3))
	_net = _box(Vector3(2.4, 1.6, 0.04), Palette.HAZARD, Vector3(0.0, MAST_HEIGHT - CREW_HALF - 0.9, -0.3), 0.9)


func _commit(_to_ball: Vector3) -> Node3D:
	var aim: Vector3 = _ball() + target.planar_velocity() * LEAD
	_facing(aim - global_position)
	return _commit_ring(Threat.Type.INSTANT, aim, FIELD_RADIUS, FIELD_TOP)


func _live(_delta: float) -> bool:
	var field := telegraph()
	if field == null:
		return false
	var player = _player()
	var ball := _real_ball()
	var above: float = ball.y - Telegraph.ground_under(terrain, ball)
	var airborne: bool = not player.state.grounded and above >= NET_FLOOR
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

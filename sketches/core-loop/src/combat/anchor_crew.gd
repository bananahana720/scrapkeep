extends "res://src/combat/counter.gd"

# The anchor crew (DESIGN-V2 section 10, the Highdraft): a deck winch on a post. Its warning
# is a cable lane from the post toward the ball; when it fills, a ball the lane contains is
# hooked and winched down and toward the anchor at PULL for up to WINCH seconds, through
# the hold bound (holds.gd). A jump slips the hook for good. The pull is modest because
# deck_winch is not in holds.BOUNDED.

const LANE_LENGTH := 18.0
const LANE_WIDTH := 2.4
const PULL := 6.0
const DOWN := 14.0
const WINCH := 2.0
const NEAR := 1.5
const POST_HEIGHT := 1.2
const HP := 60.0

var winched := 0


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 5
	weight = 2.0
	walk_speed = 2.6
	keep_near = 6.0
	warn_seconds = 1.0
	live_seconds = WINCH + 0.1
	rest_seconds = 3.5
	attack_range = 20.0


func _build_tool() -> void:
	_cylinder(0.55, 0.9, Palette.CHARCOAL, Vector3(0.0, 0.9, -CREW_RADIUS - 0.5))
	_box(Vector3(0.3, POST_HEIGHT * 2.0, 0.3), Palette.CHARCOAL, Vector3(0.0, POST_HEIGHT, -CREW_RADIUS - 0.5))


func anchor() -> Vector3:
	return global_position + Vector3.UP * POST_HEIGHT


func _commit(to_ball: Vector3) -> Node3D:
	_facing(to_ball)
	return _commit_lane(Threat.Type.LANE, global_position, to_ball, LANE_LENGTH, LANE_WIDTH)


func _go_live() -> void:
	var lane := telegraph()
	if lane == null or not lane.contains(_real_ball()) or not _catch(WINCH, Vector3.ZERO, anchor()):
		broken_by = "missed"
		return
	winched += 1


func _live(_delta: float) -> bool:
	if not _holding():
		return false
	var to := anchor() - _real_ball()
	to.y = 0.0
	var accel := to.normalized() * PULL if to.length() > NEAR else Vector3.ZERO
	if not _player().state.grounded:
		accel.y = -DOWN
	_pull(accel)
	return true


func _on_broken(_method: String) -> void:
	if fleet != null:
		fleet.discover("deck_winch", _real_ball())

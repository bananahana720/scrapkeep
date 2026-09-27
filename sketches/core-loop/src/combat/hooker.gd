extends "res://src/combat/counter.gd"

# The hooker (DESIGN-V2 section 10): a harpoon gun on a tall anchor post. The warning is
# a lane from the post toward the ball; when it fills, a ball the lane contains is
# harpooned and tethered to the post's head. The line has the length it caught you at
# and reels in: roll away and it pulls you back toward the anchor. It snaps when you
# boost, when you outrun it (planar speed at SNAP_SPEED), or at once when your heft is
# at or above its rating. A snap slings you forward: growth and speed are the counter.

const LANE_LENGTH := 24.0
const LANE_WIDTH := 2.4
const POST_HEIGHT := 4.2
const SPRING := 5.0
const RADIAL_DAMP := 3.0
const REEL := 2.5
const MIN_ROPE := 3.0
const SNAP_SPEED := 19.0
const RATING_BASE := 2.2
const RATING_PER_THREAT := 0.5
const HP := 55.0

var rating := RATING_BASE
var rope := 0.0
var snaps := 0
var _post: MeshInstance3D


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.5
	warn_seconds = 1.0
	live_seconds = 2.2
	rest_seconds = 4.0
	attack_range = 22.0
	keep_near = 12.0
	rating = RATING_BASE + RATING_PER_THREAT * (threat - 1.0)


func _build_tool() -> void:
	_post = _cylinder(0.16, POST_HEIGHT, Palette.CHARCOAL, Vector3(0.9, POST_HEIGHT * 0.5 - CREW_HALF, 0.0))
	_box(Vector3(0.3, 0.3, 1.5), Palette.BRASS, Vector3(0.9, POST_HEIGHT - CREW_HALF, 0.4), 0.3)
	_cylinder(0.12, 0.5, Palette.HAZARD, Vector3(0.9, POST_HEIGHT - CREW_HALF, 1.2), 0.8)


func anchor() -> Vector3:
	return global_position + Vector3(0.0, POST_HEIGHT - CREW_HALF, 0.0)


func _commit(to_ball: Vector3) -> Node3D:
	_facing(to_ball)
	return _commit_lane(Threat.Type.LANE, global_position, to_ball, LANE_LENGTH, LANE_WIDTH)


func _go_live() -> void:
	var lane := telegraph()
	var ball := _real_ball()
	if lane == null or not lane.contains(ball):
		broken_by = "missed"
		return
	if not _catch(0.0, Vector3.ZERO, anchor()):
		broken_by = "ignored"
		return
	rope = maxf(MIN_ROPE, _flat(ball - anchor()).length())
	if _player().heft() >= rating:
		snaps += 1
		holds.snap(self, "speed")


func _live(delta: float) -> bool:
	if not _holding():
		return false
	var player = _player()
	if player.planar_velocity().length() >= SNAP_SPEED:
		snaps += 1
		holds.snap(self, "speed")
		return false
	rope = maxf(MIN_ROPE, rope - REEL * delta)
	var out := _flat(_real_ball() - anchor())
	var accel := Vector3.ZERO
	if out.length() > rope:
		var dir := out.normalized()
		accel -= dir * (out.length() - rope) * SPRING
		var radial: float = player.planar_velocity().dot(dir)
		if radial > 0.0:
			accel -= dir * radial * RADIAL_DAMP
	_pull(accel)
	return true


func _on_broken(method: String) -> void:
	if method == "boost":
		snaps += 1
	if fleet != null:
		fleet.discover("tether_snap", _real_ball())


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

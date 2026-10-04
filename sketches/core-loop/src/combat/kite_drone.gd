extends "res://src/combat/counter.gd"

const SpeedTier := preload("res://src/movement/speed_tier.gd")

# The kite drone (roster_highdraft.gd): it hovers HOVER metres above the ball's height, out of
# ramming reach, and marks where the ball will be in DIVE + warn seconds. When the mark fills it
# dives onto it in DIVE seconds. A ball that meets the diving drone at cruise or faster bats it
# back up to its hover; a slower ball just takes the dive. It reads no thermal: the enemy's
# terrain has no map access, so it hovers by the ball's own height.

const HOVER := 6.0
const CLIMB := 4.0
const DIVE := 0.7
const MARK_RADIUS := 2.4
const MARK_REACH := 2.0
const DIVE_DAMAGE := 9.0
const BAT_KICK := 12.0
const HP := 28.0

var dives := 0
var batted := 0
var _dive_from := Vector3.ZERO
var _landed := false


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 0.7
	walk_speed = 6.0
	keep_near = 6.0
	keep_far = 16.0
	attack_range = 22.0
	warn_seconds = 0.8
	live_seconds = DIVE + 0.3
	rest_seconds = 3.0
	interruptible = false


func _build_tool() -> void:
	_box(Vector3(3.2, 0.12, 0.7), Palette.CHARCOAL, Vector3(0.0, CREW_HALF + 0.4, 0.0), 0.0, _crew)
	_cylinder(0.5, 0.9, Palette.RUST, Vector3(0.0, CREW_HALF + 0.1, 0.0), 0.0, _crew)


func _wants_attack(to_ball: Vector3) -> bool:
	return to_ball.length() <= attack_range


func _commit(to_ball: Vector3) -> Node3D:
	var landing: Vector3 = _ball() + target.planar_velocity() * (DIVE + warn_seconds)
	_facing(to_ball)
	_dive_from = global_position
	return _commit_ring(Threat.Type.INSTANT, landing, MARK_RADIUS, MARK_REACH)


func _go_live() -> void:
	dives += 1
	_landed = false


func _live(_delta: float) -> bool:
	var ring := telegraph()
	if ring == null:
		return false
	if _t < DIVE:
		global_position = _dive_from.lerp(ring.center + Vector3.UP * 0.5, _t / DIVE)
		return true
	if not _landed:
		global_position = ring.center + Vector3.UP * 0.5
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


func _diving() -> bool:
	return phase == Phase.LIVE and not _landed


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
	if _diving():
		velocity = Vector3.ZERO
	else:
		var ground: float = terrain.height(global_position.x, global_position.z) if terrain != null else 0.0
		var height := maxf(ground + 2.0, _ball().y + HOVER)
		velocity = Vector3(horizontal.x, (height - global_position.y) * CLIMB, horizontal.z)
		if _knock.y > 0.0:
			velocity.y = _knock.y
		_knock.y = 0.0
	move_and_slide()
	_knock = _knock.move_toward(Vector3.ZERO, KNOCK_DECAY * delta)

extends SceneTree

const Lab := preload("res://src/lab.gd")
const PlayerBall := preload("res://src/player_ball.gd")
const Augments := preload("res://src/augments.gd")
const Field := preload("res://src/field.gd")

# Open sky well above the field, so a probe measures the augment and nothing else.
const SKY := Vector3(0.0, 150.0, 0.0)
const FALL_SECONDS := 1.2
const SWING_SECONDS := 3.0
const ROPE_TOLERANCE := 1.0
const DASH_SETTLE := 0.25
const DASH_WINDOW := 0.25
const SLAM_WINDOW := 1.2
const KNOCK_WINDOW := 0.35
const PAD_SPOT := Vector2(20.0, 56.0)


class ScriptedSource:
	extends RefCounted

	var hold := {}
	var boost := false

	func poll(out) -> void:
		out.clear()
		out.jump_held = hold.get("jump_held", false)
		out.brake_held = hold.get("brake_held", false)
		out.mount_pressed = hold.get("mount_pressed", false)
		out.reel_held = hold.get("reel_held", false)
		out.boost_pressed = boost
		boost = false


var _lab
var _source := ScriptedSource.new()
var _steps := []
var _index := 0
var _clock := 0.0
var _entered := false
var _started := false
var _failures := 0
var _measured := {}
var _rope_overshoot := 0.0
var _swing_peak := 0.0
var _enemy: Node3D
var _enemy_from := 0.0
var _slam_at := Vector3.ZERO
var _slam_clock := -1.0
var _enemy_after := -1.0


func _initialize() -> void:
	_lab = Lab.new()
	_lab.test_mode = true
	root.add_child(_lab)
	_steps = [
		{"enter": _enter_free_fall, "seconds": FALL_SECONDS, "exit": _record.bind("free_fall")},
		{"enter": _enter_glide, "seconds": FALL_SECONDS, "exit": _record.bind("glide")},
		{"enter": _enter_slam, "seconds": FALL_SECONDS, "exit": _record.bind("slam")},
		{"enter": _enter_all_off, "seconds": FALL_SECONDS, "exit": _record.bind("all_off")},
		{"enter": _enter_dash_ready, "seconds": DASH_SETTLE, "exit": _fire_dash},
		{"enter": _noop, "seconds": DASH_WINDOW, "exit": _record.bind("dash")},
		{"enter": _enter_swing_spot, "seconds": 0.2, "exit": _attach_rope},
		{"enter": _noop, "seconds": SWING_SECONDS, "exit": _record.bind("swing")},
		{"enter": _enter_slam_on_dummy, "seconds": SLAM_WINDOW, "exit": _noop},
	]


func _process(delta: float) -> bool:
	if not _started:
		if _lab.player == null:
			return false
		_started = true
		_lab.player.shockwave.connect(_on_shockwave)
		_lab.player.source = _source
		_lab.player.set_mode(PlayerBall.RIGID)
	if _index >= _steps.size():
		return _finish()
	var step: Dictionary = _steps[_index]
	if not _entered:
		_entered = true
		_clock = 0.0
		(step["enter"] as Callable).call()
		return false
	_clock += delta
	_watch()
	if _slam_clock >= 0.0 and _enemy_after < 0.0:
		_slam_clock += delta
		if _slam_clock >= KNOCK_WINDOW:
			_enemy_after = _enemy.global_position.distance_to(_slam_at)
	if _clock < float(step["seconds"]):
		return false
	(step["exit"] as Callable).call()
	_index += 1
	_entered = false
	return false


# The rope is only honest if it holds every tick, not just at the end of the swing.
func _watch() -> void:
	var kit = _lab.player.kit
	if not kit.hooked:
		return
	_rope_overshoot = maxf(_rope_overshoot,
		_lab.player.ball_position().distance_to(kit.anchor) - kit.rope)
	# A pendulum trades speed for height, so the swing is judged on its peak rather
	# than on whatever instant the sample happens to land in.
	_swing_peak = maxf(_swing_peak, _lab.player.state.velocity.length())


func _noop() -> void:
	pass


func _fit(only: Array) -> void:
	for spec in Augments.SPECS:
		_lab.player.kit.set_on(spec["key"], spec["key"] in only)


func _drop_at(point: Vector3, only: Array, hold: Dictionary) -> void:
	_lab.player.reset_to(point)
	_fit(only)
	_source.hold = hold
	_source.boost = false


func _record(label: String) -> void:
	var v: Vector3 = _lab.player.state.velocity
	_measured[label] = {
		"fall": -v.y,
		"flat": Vector2(v.x, v.z).length(),
		"speed": v.length(),
	}


func _enter_free_fall() -> void:
	_drop_at(SKY, [], {})


func _enter_glide() -> void:
	_drop_at(SKY, [Augments.GLIDE], {"jump_held": true})
	# Glide only answers once the double jump is gone, which is the point of it.
	_lab.player.state.air_actions = 0


func _enter_slam() -> void:
	_drop_at(SKY, [Augments.SLAM], {"brake_held": true})


func _enter_all_off() -> void:
	_drop_at(SKY, [], {"jump_held": true, "brake_held": true, "mount_pressed": true, "reel_held": true})
	_lab.player.state.air_actions = 0


func _enter_dash_ready() -> void:
	_drop_at(SKY, [Augments.DASH], {})


func _fire_dash() -> void:
	_record("pre_dash")
	_source.boost = true


func _enter_swing_spot() -> void:
	_drop_at(SKY + Vector3(14.0, 0.0, 0.0), [Augments.GRAPPLE], {})


# The rigid body only lands on a teleport at the next physics tick, so the rope has
# to be tied a step later or it would be cut to the ball's previous position.
func _attach_rope() -> void:
	_lab.player.active_body().set_velocity_now(Vector3.ZERO)
	_lab.player.grapple_to(SKY)
	_rope_overshoot = 0.0
	_swing_peak = 0.0


# The shockwave scales with how flat the landing is, so the dummy is set on the flat pad
# rather than wherever its chase left it, which may be a hillside.
func _enter_slam_on_dummy() -> void:
	_enemy = _lab.enemies[0]
	var spot := Field.drop_point(PAD_SPOT.x, PAD_SPOT.y, 1.6)
	_enemy.global_position = spot
	_slam_at = Field.drop_point(spot.x + 5.0, spot.z, 16.0)
	_drop_at(_slam_at, [Augments.SLAM], {"brake_held": true})


# The plant holds the ball where it landed, so the landing moment is the only honest
# zero for the push; a fixed delay after the drop lands before or after it by chance.
func _on_shockwave(at: Vector3, _strength: float) -> void:
	if _enemy == null or _slam_clock >= 0.0:
		return
	_slam_at = at
	_enemy_from = _enemy.global_position.distance_to(at)
	_slam_clock = 0.0


# A post you cannot hit with a ray is a post the grapple cannot catch, so the rig is
# checked against the physics world rather than against the list that built it.
func _anchors_are_solid() -> bool:
	var space: PhysicsDirectSpaceState3D = _lab.get_world_3d().direct_space_state
	for anchor in _lab.field.grapple_anchors:
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(
			anchor + Vector3(2.0, 1.0, 0.0), anchor + Vector3(0.0, -0.4, 0.0), 1))
		if hit.is_empty() or (hit["position"] as Vector3).distance_to(anchor) > 3.0:
			print("  nothing solid at grapple anchor %s" % anchor)
			return false
	return true


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _finish() -> bool:
	var kit = _lab.player.kit
	var dash_gain: float = _measured["dash"]["flat"] - _measured["pre_dash"]["flat"]
	var dash_needs: float = _lab.tuning.f("dash_impulse") * 0.6
	var rope: float = kit.rope
	var swing: float = _swing_peak
	var knock: float = _enemy_after - _enemy_from if _enemy_after >= 0.0 else 0.0

	_report("grapple", _rope_overshoot < ROPE_TOLERANCE and swing > 12.0,
		"over %.0fs on a %.1f m rope the ball stayed within %.2f m of it (needs < %.1f) and a swing from rest peaked at %.1f m/s (needs > 12.0)"
			% [SWING_SECONDS, rope, _rope_overshoot, ROPE_TOLERANCE, swing])
	_report("dash", dash_gain >= dash_needs,
		"horizontal speed %.2f -> %.2f m/s, gained %.2f (needs >= %.2f)"
			% [_measured["pre_dash"]["flat"], _measured["dash"]["flat"], dash_gain, dash_needs])
	_report("glide", _measured["glide"]["fall"] < _measured["free_fall"]["fall"],
		"fall speed after %.1fs: %.2f m/s gliding vs %.2f m/s free"
			% [FALL_SECONDS, _measured["glide"]["fall"], _measured["free_fall"]["fall"]])
	_report("slam", _measured["slam"]["fall"] > _measured["free_fall"]["fall"],
		"fall speed after %.1fs: %.2f m/s slamming vs %.2f m/s free"
			% [FALL_SECONDS, _measured["slam"]["fall"], _measured["free_fall"]["fall"]])
	_report("shockwave", knock > 1.0,
		"dummy %.2f m from the slam point was pushed %.2f m further out (needs > 1.0)"
			% [_enemy_from, knock])
	# The two falls can be sampled up to two physics ticks apart (26 m/s^2 / 90 Hz
	# = 0.29 m/s each); a leaking augment moves the fall by 10 m/s or more.
	_report("augments off", absf(_measured["all_off"]["fall"] - _measured["free_fall"]["fall"]) < 1.0,
		"every key held with nothing fitted falls at %.2f m/s against the plain %.2f m/s"
			% [_measured["all_off"]["fall"], _measured["free_fall"]["fall"]])
	_report("rig", _lab.field.grapple_anchors.size() >= 8 and _lab.field.cling_spots.size() == 2 and _anchors_are_solid(),
		"field carries %d grapple anchors and %d magnet walls, and every anchor stops a ray on the world layer"
			% [_lab.field.grapple_anchors.size(), _lab.field.cling_spots.size()])

	print("augment_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_lab.free()
	quit(0 if _failures == 0 else 1)
	return true

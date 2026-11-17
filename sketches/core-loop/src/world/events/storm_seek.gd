extends RefCounted

const Hazard := preload("res://src/boss/hazard.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const SiltBoil := preload("res://src/combat/silt_boil.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const HazardHits := preload("res://src/world/events/hazard_hits.gd")

# Lightning seeks a stalled ball (W44, ruling cu: hardness presses a ball that slows or stops, never one that keeps
# rolling and turning). natural.gd owns one per stage, feeds it the ball every physics tick (observe) and steps it
# while a storm (a lightning row) is live. When the ball is sought, the next strike commits one Hazard, a disc of
# the storm's strike radius on the ball's spot: its ring fills for TELL_S, then it strikes there and only there, so
# a ball that rolls off escapes. Sought means both of the game's existing reads at once: the silt's stall test
# (SiltBoil.stalled: ten seconds within 18 m) and below cruise (SpeedTier) for SLOW_S. A ball at cruise or above is
# never sought, however tight it turns. After a strike the storm rests REST_S before it can seek again.
#
# Plants for the pinned test only (HazardHits.plants, set by tests/hazards_hit_everyone_test.gd): no_tell strikes
# the moment it commits, seek_rolling seeks whatever the ball does. That test must go red under each.

const TELL_S := 1.2
# The fairness floor (scripts/challenge/fairness.json tellS): no sought strike tells for less.
const MIN_TELL_S := 0.6
const LIVE_S := 0.1
const SLOW_S := 1.5
const REST_S := 5.0
const REACH_M := 4.0

var tells := 0
var strikes := 0
# How long the last strike's tell stood, and where it struck.
var last_tell_s := 0.0
var last_at := Vector3.INF

var _samples: Array = []
var _sample_clock := 0.0
var _slow_s := 0.0
var _rest := 0.0
var _pending: Hazard = null


func observe(delta: float, ball: Vector3, velocity: Vector3, cruise: float) -> void:
	_sample_clock += delta
	if _sample_clock >= SiltBoil.SAMPLE_S:
		_sample_clock = 0.0
		_samples.append(ball)
		while _samples.size() > int(SiltBoil.LOOP_WINDOW / SiltBoil.SAMPLE_S) + 1:
			_samples.pop_front()
	var slow := SpeedTier.of(Vector2(velocity.x, velocity.z).length(), cruise) < SpeedTier.CRUISE
	_slow_s = _slow_s + delta if slow else 0.0
	_rest = maxf(0.0, _rest - delta)


func sought() -> bool:
	if HazardHits.planted("seek_rolling"):
		return true
	return _slow_s >= SLOW_S and SiltBoil.stalled(_samples)


# One live storm tick. parent holds the drawing, ground reads the floor, left_s is the storm's time to run (no
# strike is begun that the storm would end under). On the strike's tick hit(hazard) is called once; the caller
# tests the ball and the enemies with hazard.contains, the numbers the ring was drawn from.
func step(delta: float, parent: Node, ground: Callable, ball: Vector3, radius: float, left_s: float, hit: Callable) -> void:
	if _pending != null:
		_pending.step(delta)
		# The tick its warning ends, even if a step long enough took it past LIVE.
		if _pending.state != Hazard.WARN:
			last_tell_s = _pending.age
			last_at = _pending.centre
			strikes += 1
			_rest = REST_S
			hit.call(_pending)
			_drop()
		return
	if _rest > 0.0 or left_s < TELL_S + LIVE_S or not sought():
		return
	var at := Vector3(ball.x, float(ground.call(ball)), ball.z)
	var hazard := Hazard.new()
	hazard.ground = ground
	var tell := TELL_S
	if HazardHits.planted("no_tell"):
		hazard.warn_floor = 0.0
		tell = 0.0
	hazard.commit_annulus("storm_seek", Threat.Type.INSTANT, at, Vector2(0.0, radius), REACH_M, tell, LIVE_S)
	parent.add_child(hazard)
	_pending = hazard
	tells += 1


# The tell in flight, if any (its centre is where it will strike).
func pending() -> Hazard:
	return _pending


# A storm that ends, or a stage that leaves, takes a tell with it: it never strikes.
func clear() -> void:
	_drop()


func _drop() -> void:
	if _pending != null and is_instance_valid(_pending):
		_pending.finish()
		_pending.queue_free()
	_pending = null

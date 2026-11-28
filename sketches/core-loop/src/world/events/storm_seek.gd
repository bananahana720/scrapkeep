extends RefCounted

const Hazard := preload("res://src/boss/hazard.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const SiltBoil := preload("res://src/combat/silt_boil.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const HazardHits := preload("res://src/world/events/hazard_hits.gd")


const TELL_S := 1.2
const LIVE_S := 0.1
const SLOW_S := 1.5
const REST_S := 5.0
const REACH_M := 4.0

var tells := 0
var strikes := 0
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


func step(delta: float, parent: Node, ground: Callable, ball: Vector3, radius: float, left_s: float, hit: Callable) -> void:
	if _pending != null:
		_pending.step(delta)
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


func pending() -> Hazard:
	return _pending


func clear() -> void:
	_drop()


func stand_down() -> void:
	_drop()
	_samples.clear()
	_sample_clock = 0.0
	_slow_s = 0.0


func _drop() -> void:
	if _pending != null and is_instance_valid(_pending):
		_pending.finish()
		_pending.queue_free()
	_pending = null

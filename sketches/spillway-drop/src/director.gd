extends RefCounted

# Pure scheduling logic with no node of its own: the stage hands it a delta and
# the live enemy count and gets spawn orders back. That also lets a headless test
# step a whole stage's worth of difficulty in a loop instead of in real seconds.
enum { CHASER, LOBBER }

const KIND_NAMES := ["chaser", "lobber"]
const TIER_SECONDS := 45.0
const BASE_INTERVAL := 6.5
const MIN_INTERVAL := 1.5
const FIRST_SPAWN := 4.0
const SPIKE_TIERS := 2

var stage_time := 0.0
var spike := false
# A traversal test needs the stage without the fight in it.
var paused := false

var _timer := FIRST_SPAWN
var _rng := RandomNumberGenerator.new()


func _init(seed_value := 20260922) -> void:
	_rng.seed = seed_value


func tier() -> int:
	return int(stage_time / TIER_SECONDS)


func effective_tier() -> int:
	return tier() + (SPIKE_TIERS if spike else 0)


func cap() -> int:
	return 6 + effective_tier() * 2


func interval() -> float:
	return maxf(MIN_INTERVAL, BASE_INTERVAL - effective_tier() * 0.7)


func lobber_share() -> float:
	return clampf(0.15 + effective_tier() * 0.07, 0.0, 0.5)


func advance(delta: float, alive_count: int) -> Array[int]:
	stage_time += delta
	var orders: Array[int] = []
	if paused:
		return orders
	_timer -= delta
	while _timer <= 0.0:
		_timer += interval()
		if alive_count + orders.size() >= cap():
			continue
		orders.append(LOBBER if _rng.randf() < lobber_share() else CHASER)
	return orders


func chaser_hp() -> float:
	return 40.0 + effective_tier() * 16.0


func lobber_hp() -> float:
	return 26.0 + effective_tier() * 11.0

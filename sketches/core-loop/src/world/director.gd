extends RefCounted

# The spawn director: pure scheduling with no node of its own. The stage hands it a
# delta, the live enemy count and where the ball is going, and gets due spawns back.
# A headless test steps a whole stage in a loop instead of in real seconds.
#
# Honesty rules (demo spec, Director honesty):
# - Enemy HP comes from the stage's threat only; the clock never toughens an enemy.
# - The clock's tier is clamped at +2, and every rise, the beacon spike included, is
#   recorded for the world to announce with threat_rose. Nothing rises silently.
# - 60% of spawns land ahead of the ball, within 35 degrees of where it is rolling,
#   60 to 90 m out; the rest on the flanks. None lands within 25 m of the ball, and
#   each shows a ground ring for 1 s before its body arrives.
enum { CHASER, LOBBER }

const KIND_NAMES := ["chaser", "lobber"]
const TIER_SECONDS := 45.0
const MAX_TIME_TIERS := 2
const SPIKE_TIERS := 2
const BASE_INTERVAL := 6.5
const MIN_INTERVAL := 1.5
const FIRST_SPAWN := 4.0
const HEFT_CAP_STEP := 2
const HARD_CAP := 24
const ARRIVAL := 1.0
const AHEAD_SHARE := 0.6
const AHEAD_CONE := 0.6108652  # 35 degrees
const AHEAD_RANGE := Vector2(60.0, 90.0)
const FLANK_RANGE := Vector2(45.0, 70.0)
const MIN_GAP := 25.0
const SLOW := 3.0
const TRIES := 8

var stage_time := 0.0
var spike := false
# The stage's threat dial from stage_defs.gd: more enemies alive, arriving sooner, and
# the one input to enemy HP.
var threat := 1.0
# From run.heft_class(): a heavier ball earns a bigger crowd to roll through.
var heft_class := 1
var play_rect := Rect2(-150.0, -150.0, 300.0, 300.0)
# A traversal test needs the stage without the fight in it.
var paused := false
# Spawns whose ground ring is showing: {"kind": int, "at": Vector2, "left": float}.
var arrivals: Array[Dictionary] = []

var _timer := FIRST_SPAWN
var _rng := RandomNumberGenerator.new()
var _last_tier := 0
var _rises: Array[int] = []


func _init(seed_value := 20260922) -> void:
	_rng.seed = seed_value


func tier() -> int:
	return mini(int(stage_time / TIER_SECONDS), MAX_TIME_TIERS)


func effective_tier() -> int:
	return tier() + (SPIKE_TIERS if spike else 0)


# The multiplier combat applies to enemy HP: the stage's threat, and nothing else.
func hp_scale() -> float:
	return threat


func cap() -> int:
	var base := int(round((6 + effective_tier() * 2) * threat))
	return mini(HARD_CAP, base + HEFT_CAP_STEP * maxi(0, heft_class - 1))


func interval() -> float:
	return maxf(MIN_INTERVAL, (BASE_INTERVAL - effective_tier() * 0.7) / threat)


func lobber_share() -> float:
	return clampf(0.15 + effective_tier() * 0.07, 0.0, 0.5)


# 0 with nothing alive and nothing coming, 1 at the cap during a beacon spike.
func pressure(alive_count: int) -> float:
	var crowd := clampf(float(alive_count) / float(maxi(1, cap())), 0.0, 1.0)
	return clampf(crowd * 0.7 + (0.3 if spike else 0.0) + minf(0.2, tier() * 0.05), 0.0, 1.0)


# Every rise of the effective tier since the last call, in order.
func take_threat_rises() -> Array[int]:
	var out := _rises
	_rises = []
	return out


# Returns the spawns whose arrival ring has run its second: {"kind", "at": Vector2}.
func advance(delta: float, alive_count: int, ball := Vector2.ZERO, velocity := Vector2.ZERO,
		forward := Vector2(0.0, 1.0)) -> Array[Dictionary]:
	stage_time += delta
	var now := effective_tier()
	if now > _last_tier:
		for t in range(_last_tier + 1, now + 1):
			_rises.append(t)
	_last_tier = now
	var due: Array[Dictionary] = []
	for a in arrivals:
		a["left"] -= delta
	for a in arrivals.duplicate():
		if a["left"] <= 0.0:
			arrivals.erase(a)
			if (a["at"] as Vector2).distance_to(ball) >= MIN_GAP:
				due.append({"kind": a["kind"], "at": a["at"]})
	if paused:
		return due
	_timer -= delta
	while _timer <= 0.0:
		_timer += interval()
		if alive_count + arrivals.size() + due.size() >= cap():
			continue
		var at := spawn_spot(ball, velocity, forward)
		if at == Vector2.INF:
			continue
		arrivals.append({"kind": LOBBER if _rng.randf() < lobber_share() else CHASER, "at": at, "left": ARRIVAL})
	return due


func spawn_spot(ball: Vector2, velocity: Vector2, forward: Vector2) -> Vector2:
	var heading := velocity.normalized() if velocity.length() > SLOW else forward.normalized()
	var ahead := _rng.randf() < AHEAD_SHARE
	for i in TRIES:
		var angle: float
		var dist: float
		if ahead:
			angle = _rng.randf_range(-AHEAD_CONE, AHEAD_CONE)
			dist = _rng.randf_range(AHEAD_RANGE.x, AHEAD_RANGE.y)
		else:
			angle = _rng.randf_range(AHEAD_CONE, PI) * (1.0 if _rng.randf() < 0.5 else -1.0)
			dist = _rng.randf_range(FLANK_RANGE.x, FLANK_RANGE.y)
		var spot := ball + heading.rotated(angle) * dist
		spot.x = clampf(spot.x, play_rect.position.x, play_rect.end.x)
		spot.y = clampf(spot.y, play_rect.position.y, play_rect.end.y)
		if spot.distance_to(ball) >= MIN_GAP:
			return spot
	return Vector2.INF

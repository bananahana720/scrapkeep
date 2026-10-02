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
#
# v2 W7 enemies: pack composition (DESIGN-V2 sections 10.5 and 15.4-15.5).
# - The difficulty clock gates reinforcements. At tick 0 every spawn is a chaser or a
#   lobber; from tick 1 a share of the spawn slots become packs, PACK_PER_TICK a tick,
#   and each tick past the Warden break (while the spike is on) adds PAST_BREAK_STEP.
# - A tagged pack pairs a controller with a punisher (PACKS): the enemy synergies. Its
#   members arrive together, on one ring timer, so combat reads them as one pack and
#   publishes pack_arrived with the faction.
# - New counters unlock as the ticks rise: UNLOCK_BASE by stage, UNLOCK_PER_TICK more a
#   tick, in the roster's order (combat/roster.gd COUNTERS). A pack is drawn only once
#   both its members are unlocked.
# - The stage's ancient family arrives as its own pack, ANCIENT_SHARE of the packs.
# - Weighting tests the build: `build` is combat's build_read() (class, habit shares,
#   W3's upgrade-tree branch tags through TAG_AXES). Each pack's weight is 1 + BUILD_TILT times how
#   strongly the build leans on the axis the pack tests, so the build's own axis comes
#   up to twice as often and every other unlocked pack still comes: fair, never a hard
#   counter. With no build read every pack weighs the same.
# - HP stays the stage's threat only; the clock adds packs, never toughness.
#
# Authored packs (slice table): with `authored` set, every arrival is one whole pack from
# that list and nothing else spawns: no single draws, no unlock clock, no build tilt, no
# ancient share. Packs are drawn uniformly and never the same twice in a row; the
# `elite_arrival`-th arrival is the `elite` pack, once. Pacing stays the director's own, and
# a pack arrives only when the cap has room for all of it.
enum { CHASER, LOBBER }

const KIND_NAMES := ["chaser", "lobber", "mag_trapper", "bola_thrower", "hooker", "plated_brute", "netcaster",
	"deflector", "winch_drone", "gyro_jammer", "swatter", "ramp_flipper", "catch_trap", "reactor_relic",
	"swarm_remnant", "mind_hand"]
const COUNTERS := ["mag_trapper", "bola_thrower", "hooker", "plated_brute", "netcaster", "deflector", "winch_drone",
	"gyro_jammer", "swatter", "ramp_flipper", "catch_trap"]
const FAMILY_ANCIENT := ["reactor_relic", "swarm_remnant", "mind_hand"]
const PACKS := {
	"grounded": {"controller": "mag_trapper", "punisher": "bola_thrower", "tests": "heft"},
	"strung": {"controller": "hooker", "punisher": "plated_brute", "tests": "speed"},
	"netted": {"controller": "netcaster", "punisher": "bola_thrower", "tests": "air"},
	"rebound": {"controller": "deflector", "punisher": "chaser", "tests": "contact"},
	"reeled": {"controller": "winch_drone", "punisher": "plated_brute", "tests": "weapon"},
	"wobble": {"controller": "gyro_jammer", "punisher": "swatter", "tests": "steer"},
	"flung": {"controller": "ramp_flipper", "punisher": "lobber", "tests": "steer"},
	"cupped": {"controller": "catch_trap", "punisher": "swatter", "tests": "speed"},
}
const PACK_PER_TICK := 0.12
const PAST_BREAK_STEP := 0.08
const PACK_MAX := 0.6
const UNLOCK_BASE := [2, 4, 6]
const UNLOCK_PER_TICK := 2
const ANCIENT_SHARE := 0.25
const BUILD_TILT := 1.0
const PACK_SPREAD := 4.5
# A habit's share of play and the build axes it leans on; a class adds its own axis.
const HABIT_AXES := {"ram": ["contact", "speed", "heft"], "rebound": ["contact"], "stomp": ["contact", "air"],
	"smash": ["contact"], "vault": ["air"], "weapon": ["weapon"], "special": ["weapon"], "jump": ["air"],
	"air": ["air"], "boost": ["speed", "steer"], "grapple": ["steer"], "glide": ["air"]}
const CLASS_AXIS := {"sable": "steer", "rivet": "speed", "kest": "air"}
# W3's upgrade-tree tags (upgrade_tree.gd TAGS) and the axes each leans on.
const TAG_AXES := {"air": ["air"], "burst": ["weapon"], "close": ["contact"], "ranged": ["weapon"],
	"mobility": ["steer", "speed"], "mounted": ["weapon"], "sustain": ["heft"], "cc_immune": ["speed"],
	"traps": ["contact"], "stealth": ["weapon"]}
const CLASS_AXIS_SHARE := 0.25
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
# The stage (1 to 3), for the unlock base and the ancient family; 0 reads it from the
# threat dial, which stage_defs sets per stage.
var stage := 0
# combat's build_read(): {class, habits: {habit: share}, branch_tags: [axis]}.
var build := {}
# Every pack composed, in order: {id, kinds, tests}. For tests and the balance read.
var packs: Array[Dictionary] = []
# The stage table's authored packs ({id, kinds}), its elite pack and the arrival that is the
# elite. Empty `authored` keeps the director's own rules.
var authored: Array = []
var elite := {}
var elite_arrival := 0

var _timer := FIRST_SPAWN
var _rng := RandomNumberGenerator.new()
var _last_tier := 0
var _rises: Array[int] = []
var _spike_time := 0.0
var _pack_seq := 0
var _arrivals_made := 0
var _next_pack := {}
var _last_pack_id := ""


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


# The level threat_rose announces: the effective tier.
func level() -> int:
	return effective_tier()


# Every rise of the level since the last call, in order.
func take_threat_rises() -> Array[int]:
	var out := _rises
	_rises = []
	return out


# Returns the spawns whose arrival ring has run its second: {"kind", "at": Vector2}.
func advance(delta: float, alive_count: int, ball := Vector2.ZERO, velocity := Vector2.ZERO,
		forward := Vector2(0.0, 1.0)) -> Array[Dictionary]:
	stage_time += delta
	_spike_time = _spike_time + delta if spike else 0.0
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
		if not authored.is_empty():
			_authored_arrival(cap() - (alive_count + arrivals.size() + due.size()), ball, velocity, forward)
			continue
		var at := spawn_spot(ball, velocity, forward)
		if at == Vector2.INF:
			continue
		var room := cap() - (alive_count + arrivals.size() + due.size())
		var weight := reinforcement_weight()
		var pack := compose() if weight > 0.0 and room >= 2 and _rng.randf() < weight else []
		if pack.is_empty():
			arrivals.append({"kind": LOBBER if _rng.randf() < lobber_share() else CHASER, "at": at, "left": ARRIVAL})
			continue
		_place_pack(at, pack, ball)
	return due


# One pack's members side by side across the line from the ball, on one ring timer.
func _place_pack(at: Vector2, kinds: Array, ball: Vector2) -> void:
	var heading := (at - ball).normalized() if at.distance_to(ball) > 0.1 else Vector2.RIGHT
	var side := Vector2(-heading.y, heading.x)
	for i in kinds.size():
		var spot: Vector2 = at + side * PACK_SPREAD * (i - (kinds.size() - 1) * 0.5)
		spot.x = clampf(spot.x, play_rect.position.x, play_rect.end.x)
		spot.y = clampf(spot.y, play_rect.position.y, play_rect.end.y)
		arrivals.append({"kind": KIND_NAMES.find(kinds[i]), "at": spot, "left": ARRIVAL, "pack": _pack_seq})
	_pack_seq += 1


# An authored arrival: the pack due next waits until the cap has room for all of it.
func _authored_arrival(room: int, ball: Vector2, velocity: Vector2, forward: Vector2) -> void:
	if _next_pack.is_empty():
		_next_pack = _draw_authored()
	var kinds: Array = _next_pack["kinds"]
	if room < kinds.size():
		return
	var at := spawn_spot(ball, velocity, forward)
	if at == Vector2.INF:
		return
	packs.append({"id": _next_pack["id"], "kinds": kinds.duplicate(), "tests": ""})
	_place_pack(at, kinds, ball)
	if _next_pack != elite:
		_last_pack_id = _next_pack["id"]
	_next_pack = {}
	_arrivals_made += 1


func _draw_authored() -> Dictionary:
	if not elite.is_empty() and elite_arrival > 0 and _arrivals_made + 1 == elite_arrival:
		return elite
	var pool := authored.filter(func(p: Dictionary) -> bool: return p["id"] != _last_pack_id)
	if pool.is_empty():
		pool = authored
	return pool[_rng.randi_range(0, pool.size() - 1)]


# --- v2 W7 enemies: pack composition -------------------------------------------------

func stage_now() -> int:
	if stage > 0:
		return clampi(stage, 1, 3)
	if threat <= 1.1:
		return 1
	return 2 if threat <= 1.6 else 3


# Ticks past the Warden break: counted from the moment the spike came on, the first at
# once. 0 while the spike is off.
func past_break_ticks() -> int:
	return int(_spike_time / TIER_SECONDS) + 1 if spike else 0


# The share of spawn slots that become packs: 0 at tick 0, the clock's gate.
func reinforcement_weight() -> float:
	var ticks := effective_tier()
	if ticks <= 0:
		return 0.0
	return clampf(PACK_PER_TICK * ticks + PAST_BREAK_STEP * past_break_ticks(), 0.0, PACK_MAX)


func unlocked_counters() -> Array:
	var n := clampi(UNLOCK_BASE[stage_now() - 1] + UNLOCK_PER_TICK * effective_tier(), 0, COUNTERS.size())
	return COUNTERS.slice(0, n)


# The tagged packs whose members are all unlocked now.
func open_packs() -> Array:
	var unlocked := unlocked_counters()
	var out := []
	for id in PACKS:
		var row: Dictionary = PACKS[id]
		var ok := true
		for role in ["controller", "punisher"]:
			var kind: String = row[role]
			ok = ok and (not kind in COUNTERS or kind in unlocked)
		if ok:
			out.append(id)
	return out


# How strongly the build leans on each axis, 0 to 1 (the strongest is 1).
func build_axes() -> Dictionary:
	var axes := {}
	var habits: Dictionary = build.get("habits", {})
	for habit in habits:
		for axis in HABIT_AXES.get(habit, []):
			axes[axis] = float(axes.get(axis, 0.0)) + float(habits[habit])
	var class_axis: String = CLASS_AXIS.get(String(build.get("class", "")), "")
	if class_axis != "":
		axes[class_axis] = float(axes.get(class_axis, 0.0)) + CLASS_AXIS_SHARE
	for tag in build.get("branch_tags", []):
		for axis in TAG_AXES.get(String(tag), [String(tag)]):
			axes[axis] = float(axes.get(axis, 0.0)) + CLASS_AXIS_SHARE
	var top := 0.0
	for axis in axes:
		top = maxf(top, float(axes[axis]))
	if top > 0.0:
		for axis in axes:
			axes[axis] = float(axes[axis]) / top
	return axes


func pack_weight(id: String, axes := build_axes()) -> float:
	return 1.0 + BUILD_TILT * float(axes.get(PACKS[id]["tests"], 0.0))


# One pack's kinds: the stage's ancient, or a tagged controller-and-punisher pair drawn
# by build weight. Empty when nothing is unlocked yet.
func compose() -> Array:
	var open := open_packs()
	if open.is_empty() and effective_tier() <= 0:
		return []
	if open.is_empty() or _rng.randf() < ANCIENT_SHARE:
		var ancient: String = FAMILY_ANCIENT[stage_now() - 1]
		packs.append({"id": ancient, "kinds": [ancient], "tests": "ancient"})
		return [ancient]
	var axes := build_axes()
	var total := 0.0
	for id in open:
		total += pack_weight(id, axes)
	var pick := _rng.randf() * total
	var chosen: String = open[-1]
	for id in open:
		pick -= pack_weight(id, axes)
		if pick <= 0.0:
			chosen = id
			break
	var row: Dictionary = PACKS[chosen]
	var kinds := [row["controller"], row["punisher"]]
	packs.append({"id": chosen, "kinds": kinds, "tests": row["tests"]})
	return kinds


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

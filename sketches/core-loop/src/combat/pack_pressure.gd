extends RefCounted

# How the ball's roll is read and led, world 1. Two users share one reading of the ball (observe, once a
# physics tick): the pack pressure experiments below, and the bosses' lead on a held line (lead_aim).
#
# Pack pressure (the kiting sweep, scrapkeep#241 comment 6378906601: circling a pack costs nothing on every
# stage). Five variants, each only a preset of ChallengeDials rows, chosen on the command line with
# --pack-pressure=A, or a combination such as --pack-pressure=A+D. Without the flag every dial but A's and
# E's reads its identity. An explicit --tune of the same key wins over a preset.
#
#   A  aim: crews lead the ball's roll, along its curve, when they steer and when they lay a lunge lane.
#      A ships at half across all stages (wave 37 unit D1, inherited by W2/W3 in w45 P5,
#      ChallengeDials.LEAD_W1); the preset names the full lead on world 1.
#      --tune=pack.lead_by_stage=0/0/0/0/0/0 turns it off.
#   B  numbers: one more chaser per crew and half the re-engage gap.
#   C  flankers: every second chaser runs ahead of the ball's line, calls (a whistle, PRESSURE_CUE_S before
#      its wind-up) and lunges across the line.
#   D  churned silt (churn_ground.gd): ground the ball rolls over again within CHURN_WINDOW drags it below
#      FAST tier. Fast balls skim it.
#   E  silt boils (silt_boil.gd): where the ball loops round a roaming pack the silt boils up under a
#      telegraphed ring. E ships on: the dial defaults to strength 2 on world 1, and the preset names that
#      default. --tune=hazard.boil_by_stage=0/0/0/0/0/0 turns it off.
#
# World 1 only: each preset fills the stage 1 and 2 entries of a per-stage dial and leaves the rest at
# identity.
#
# Boss lead (MG-11): Brindle's charge, the gate crane's sweep and drop and the miniboss's slam and charge
# aim through lead_aim at their commit. See the constants above lead_aim.

const W1 := [1.0, 1.0, 0.0, 0.0, 0.0, 0.0]
const HALF_W1 := [0.5, 0.5, 1.0, 1.0, 1.0, 1.0]

const PRESETS := {
	"A": {"pack.lead_by_stage": W1},
	"B": {"pack.crew_extra_by_stage": W1, "pack.rest_by_stage": HALF_W1},
	"C": {"pack.flank_by_stage": W1},
	"D": {"ground.churn_by_stage": W1},
	"E": {"hazard.boil_by_stage": [2.0, 2.0, 0.0, 0.0, 0.0, 0.0]},
}

# The flanker's call: the whistle sounds this long before its wind-up opens (the phase-signal spec's 0.5 s
# cue ahead of a drawn tell), so the whole warning is the call plus the chaser's 0.6 s wind-up.
const PRESSURE_CUE_S := 0.5
# How far ahead (seconds) a lead may look, and the turn rate it will believe (rad/s).
const MAX_LEAD_S := 2.5
const MAX_TURN := 2.5
# The ball's turn rate is smoothed over this many seconds; below MIN_TURN_SPEED it is not read.
const TURN_SMOOTH_S := 0.3
const MIN_TURN_SPEED := 3.0
# A lead is for a ball that can be met. It is whole up to LEAD_FADE_FROM of the pilot's cruise speed and falls
# to the stage's pack.lead_cruise_by_stage share of itself at cruise and above: 0 across all stages, so a ball at
# cruise is aimed at where it is, as before wave 37, and 1 keeps the lead whole at any speed.
const LEAD_FADE_FROM := 0.85

# Bosses lead a held line (lead_aim; Andrew after his world 1 sitting: "bosses (mini or main lineup) are
# a pushover", because every boss attack aimed where the ball was at the commit). A ball whose heading has
# stayed inside STEADY_SPREAD_DEG for the whole record (about a second) while rolling at MIN_TURN_SPEED or
# more is aimed at where its roll carries it by its real velocity when the attack lands, so a slower ball is
# led a shorter way, and one that slows before the commit and then holds its line is met. A ball that stops or
# turns after the commit is not: the lead is spent by then (boss_lead_line_test prints a ball that stops 0.25 s
# in, which the aim at the ball's place hits and the lead misses). The lead fades to nothing as the spread grows to
# UNSTEADY_SPREAD_DEG, so a ball that is turning is aimed at where it is, as before, and a turn made inside
# the tell carries the ball off the mark. A boss looks at most BOSS_MAX_LEAD_S ahead.
const STEADY_SPREAD_DEG := 10.0
const UNSTEADY_SPREAD_DEG := 20.0
const BOSS_MAX_LEAD_S := 4.0
# The lead scales with the tell (coordinator's call, an assumption Andrew can overturn): whole at
# LEAD_TELL_FULL seconds from commit to hit or longer, none at LEAD_TELL_NONE or shorter, linear between. A
# short tell leaves no time to turn off a led mark, so a cued follow-up (its tell is the floor) is never led.
const LEAD_TELL_FULL := 1.0
const LEAD_TELL_NONE := 0.6
# An attack that travels to its mark (a charge, a swung hook) lands later the further it aims; lead_aim
# settles that landing time in this many passes. A ball as fast as the attack cannot be met that way, so it
# is not led.
const LEAD_SOLVE_STEPS := 3

# A planted fault for boss_lead_line_test only, which sets it directly: "full" leads every ball, turning or
# not, and "none" leads no ball. Always "" in play; nothing in the game writes it.
static var lead_plant := ""


# The ball's heading over the last second: one planar heading (radians, atan2(z, x)) every SAMPLE_S in a
# fixed ring of SAMPLES slots, NAN where the ball was below MIN_TURN_SPEED. observe_tick writes it;
# lead_aim reads it. No allocation after construction.
class HeadingRecord:
	const SAMPLE_S := 0.1
	const SAMPLES := 11
	var headings := PackedFloat32Array()
	var newest := -1
	var count := 0
	var _since := 0.0

	func _init() -> void:
		headings.resize(SAMPLES)

	func clear() -> void:
		newest = -1
		count = 0
		_since = 0.0

	# One physics tick of `dt` seconds at `heading` (NAN when slow). A sample is kept every SAMPLE_S.
	func push(heading: float, dt: float) -> void:
		_since += dt
		if count > 0 and _since < SAMPLE_S:
			return
		_since = 0.0
		newest = (newest + 1) % SAMPLES
		headings[newest] = heading
		count = mini(count + 1, SAMPLES)

	# The widest the recorded headings stray from `now` (radians); INF until the record holds a full
	# second, or when any sample in it was slow.
	func spread(now: float) -> float:
		if count < SAMPLES:
			return INF
		var widest := 0.0
		for h in headings:
			if is_nan(h):
				return INF
			widest = maxf(widest, absf(wrapf(h - now, -PI, PI)))
		return widest


static var _frame := -1
static var _heading := 0.0
static var _turn := 0.0
static var _have_heading := false
static var _cruise := 0.0
static var _record := HeadingRecord.new()


# The dial overrides a --pack-pressure value names, as a --tune payload: "A", "A+D", "" for none. Unknown
# letters are reported in `unknown`.
static func tune_spec(value: String, unknown: Array = []) -> String:
	var merged := {}
	for letter in value.to_upper().split("+", false):
		var key := letter.strip_edges()
		if not PRESETS.has(key):
			unknown.append(key)
			continue
		merged.merge(PRESETS[key], true)
	var pairs: Array[String] = []
	for k in merged:
		pairs.append("%s=%s" % [k, "/".join((merged[k] as Array).map(func(x): return str(x)))])
	return ",".join(pairs)


# What a crew spawned on `stage` reads (combat.spawn_enemy puts it in the spec as "pressure").
static func crew_row(stage: int) -> Dictionary:
	return {
		"lead": ChallengeDials.by_stage_or("pack.lead_by_stage", stage, 0.0),
		"lead_cruise": ChallengeDials.by_stage_or("pack.lead_cruise_by_stage", stage, 1.0),
		"rest": ChallengeDials.by_stage("pack.rest_by_stage", stage),
		"flank": ChallengeDials.by_stage_or("pack.flank_by_stage", stage, 0.0),
	}


# The lead a crew row gives against `target` this tick: the row's lead, faded as the ball nears cruise.
static func lead_now(pressure: Dictionary, target) -> float:
	var lead := float(pressure.get("lead", 0.0))
	var keep := float(pressure.get("lead_cruise", 1.0))
	if lead <= 0.0 or keep >= 1.0 or _cruise <= 0.0:
		return lead
	var pace: float = target.planar_velocity().length() / _cruise
	return lead * lerpf(1.0, keep, clampf((pace - LEAD_FADE_FROM) / (1.0 - LEAD_FADE_FROM), 0.0, 1.0))


static func crew_extra(stage: int) -> int:
	return maxi(0, int(round(ChallengeDials.by_stage_or("pack.crew_extra_by_stage", stage, 0.0))))


# Where the ball will be in `seconds`, carried along its present curve (the turn rate observe() read this
# tick), so a ball holding a ring is led round the ring, not off it.
static func predict(target, seconds: float) -> Vector3:
	return _carry(target.ball_position(), target.planar_velocity(), clampf(seconds, 0.0, MAX_LEAD_S))


# The arc: v * (e^{iwt} - 1) / (iw) in the (x, z) plane, heading measured as atan2(z, x).
static func _carry(at: Vector3, v: Vector3, t: float) -> Vector3:
	var w := _turn
	if absf(w) < 0.05:
		return at + v * t
	var phi := w * t
	var a := sin(phi)
	var b := 1.0 - cos(phi)
	return at + Vector3(v.x * a - v.z * b, 0.0, v.x * b + v.z * a) / w


# Where a boss attack committed now from `from` should be aimed. It hurts `tell` seconds after the commit;
# an attack that then travels to its mark (a charge, a swung hook) moves at `travel_speed` m/s and hurts
# from `reach` metres ahead of `from` at once (a hull's nose); a ring that lands all at once passes 0. `body`
# is the attacker's contact distance (see _stop_at_body). A ball
# that has held a line is aimed at where its roll carries it by the hit, scaled by the tell (LEAD_TELL_*);
# a turning, slow or stopped ball, or one as fast as the attack, is aimed at where it is. Bosses call this
# once, at the commit, and draw what it returns.
static func lead_aim(target, from: Vector3, tell: float, travel_speed := 0.0, reach := 0.0, body := 0.0) -> Vector3:
	var at: Vector3 = target.ball_position()
	var v: Vector3 = target.planar_velocity()
	if travel_speed > 0.0 and v.length() >= travel_speed:
		return at
	var share := _lead_share(v) * clampf((tell - LEAD_TELL_NONE) / (LEAD_TELL_FULL - LEAD_TELL_NONE), 0.0, 1.0)
	if share <= 0.0:
		return at
	var aim := at
	for i in LEAD_SOLVE_STEPS:
		var t := tell
		if travel_speed > 0.0:
			t += maxf(0.0, Vector2(aim.x - from.x, aim.z - from.z).length() - reach) / travel_speed
		aim = _carry(at, v, clampf(t, 0.0, BOSS_MAX_LEAD_S))
	return _stop_at_body(at.lerp(aim, share), from, at, body)


# A ball cannot roll through the attacker. `body` is how near the ball's centre can come to `from` (the
# attacker's own radius plus the ball's; 0 cuts nothing). The lead stops where the carried path first comes
# that near, so the attack meets the ball where it stops against the body, not on the far side; a ball
# already that near is aimed at where it is, as before the lead.
static func _stop_at_body(led: Vector3, from: Vector3, at: Vector3, body: float) -> Vector3:
	if body <= 0.0:
		return led
	var a := Vector2(at.x - from.x, at.z - from.z)
	var d := Vector2(led.x - at.x, led.z - at.z)
	if a.length() <= body:
		return at
	var len2 := d.length_squared()
	if len2 <= 0.0:
		return led
	# |a + d t| = body, the smaller root, with the segment's t in [0, 1].
	var b := a.dot(d)
	var disc := b * b - len2 * (a.length_squared() - body * body)
	if disc < 0.0:
		return led
	var t := (-b - sqrt(disc)) / len2
	if t < 0.0 or t > 1.0:
		return led
	return at.lerp(led, t)


# How much of the lead a boss takes: 1 on a held line, fading to 0 as the heading strays.
static func _lead_share(v: Vector3) -> float:
	if lead_plant == "full":
		return 1.0
	if lead_plant == "none":
		return 0.0
	if Vector2(v.x, v.z).length() < MIN_TURN_SPEED:
		return 0.0
	var spread := rad_to_deg(_record.spread(atan2(v.z, v.x)))
	return clampf((UNSTEADY_SPREAD_DEG - spread) / (UNSTEADY_SPREAD_DEG - STEADY_SPREAD_DEG), 0.0, 1.0)


static func turn_rate() -> float:
	return _turn


# Combat calls this once a physics tick with the player's own planar velocity (never a Sight's, which a
# cloak blanks) and cruise speed, so every crew reads the same turn rate and fades its lead on the same line.
static func observe(v: Vector3, cruise := 0.0) -> void:
	var frame := Engine.get_physics_frames()
	if frame == _frame:
		_cruise = cruise
		return
	var fresh := frame != _frame + 1
	_frame = frame
	# A tick lasts 1 / ticks_per_second of game time, scaled like the physics delta: under a hit stop
	# (Engine.time_scale 0.05) ticks keep coming at the real rate but each is a twentieth as long.
	observe_tick(v, Engine.time_scale / float(Engine.physics_ticks_per_second), cruise, fresh)


# One tick of the ball's roll, `dt` seconds long. observe() calls it once a physics tick; a headless test
# calls it on its own clock. `fresh` drops what came before (a skipped tick, a new scene).
static func observe_tick(v: Vector3, dt: float, cruise := 0.0, fresh := false) -> void:
	_cruise = cruise
	if fresh:
		_have_heading = false
		_turn = 0.0
		_record.clear()
	var speed := Vector2(v.x, v.z).length()
	var heading := atan2(v.z, v.x)
	_record.push(heading if speed >= MIN_TURN_SPEED else NAN, dt)
	if speed < MIN_TURN_SPEED:
		_have_heading = false
		_turn = move_toward(_turn, 0.0, dt * MAX_TURN)
		return
	if _have_heading:
		var raw := clampf(wrapf(heading - _heading, -PI, PI) / dt, -MAX_TURN, MAX_TURN)
		_turn = lerpf(_turn, raw, 1.0 - exp(-dt / TURN_SMOOTH_S))
	_heading = heading
	_have_heading = true

extends RefCounted

# Pack pressure experiments, world 1 (the kiting sweep, scrapkeep#241 comment 6378906601: circling a pack
# costs nothing on every stage). Five variants, each only a preset of ChallengeDials rows, chosen on the
# command line with --pack-pressure=A, or a combination such as --pack-pressure=A+D. Without the flag every
# dial but A's and E's reads its identity. An explicit --tune of the same key wins over a preset.
#
#   A  aim: crews lead the ball's roll, along its curve, when they steer and when they lay a lunge lane.
#      A ships at half on world 1 (wave 37 unit D1, ChallengeDials.LEAD_W1); the preset names the full lead.
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
# to the stage's pack.lead_cruise_by_stage share of itself at cruise and above: 0 on world 1, so a ball at
# cruise is aimed at where it is, as before wave 37, and 1 keeps the lead whole at any speed.
const LEAD_FADE_FROM := 0.85

# Bosses lead a held line (lead_aim; Andrew after his world 1 sitting: "bosses (mini or main lineup) are
# a pushover", because every boss attack aimed where the ball was at the commit). A ball whose heading has
# stayed inside STEADY_SPREAD_DEG for the whole record (about a second) at LEAD_FLOOR of cruise or more is
# aimed at where its roll carries it when the attack lands. The lead fades to nothing as the spread grows to
# UNSTEADY_SPREAD_DEG, so a ball that is turning is aimed at where it is, as before, and a turn made inside
# the tell carries the ball off the mark. A boss looks at most BOSS_MAX_LEAD_S ahead.
const STEADY_SPREAD_DEG := 10.0
const UNSTEADY_SPREAD_DEG := 20.0
const LEAD_FLOOR := 0.85
const BOSS_MAX_LEAD_S := 4.0
# An attack that travels to its mark (a charge, a swung hook) lands later the further it aims; lead_aim
# settles that landing time in this many passes.
const LEAD_SOLVE_STEPS := 3
# The plant switch for boss_lead_line_test, read only at a commit: "full" leads every ball, turning or
# not, and "none" leads no ball. Unset in play.
const PLANT_ENV := "SCRAPKEEP_PLANT_BOSS_LEAD"


# The ball's heading over the last second: one planar heading (radians, atan2(z, x)) every SAMPLE_S in a
# fixed ring of SAMPLES slots, NAN where the ball was below LEAD_FLOOR of cruise. observe_tick writes it;
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


# Where a boss attack committed now from `from` should be aimed. It lands `delay` seconds after the
# commit, plus the time to reach its mark at `travel_speed` m/s (0 for a mark that lands all at once, a
# ring). A ball that has held a line is aimed at where its roll carries it by then; a turning, slow or
# stopped ball at where it is. Bosses call this once, at the commit, and draw what it returns.
static func lead_aim(target, from: Vector3, delay: float, travel_speed := 0.0) -> Vector3:
	var at: Vector3 = target.ball_position()
	var v: Vector3 = target.planar_velocity()
	var share := _lead_share(v)
	if share <= 0.0:
		return at
	var aim := at
	for i in LEAD_SOLVE_STEPS:
		var t := delay
		if travel_speed > 0.0:
			t += Vector2(aim.x - from.x, aim.z - from.z).length() / travel_speed
		aim = _carry(at, v, clampf(t, 0.0, BOSS_MAX_LEAD_S))
	return at.lerp(aim, share)


# How much of the lead a boss takes: 1 on a held line, fading to 0 as the heading strays.
static func _lead_share(v: Vector3) -> float:
	var plant := OS.get_environment(PLANT_ENV)
	if plant == "full":
		return 1.0
	if plant == "none":
		return 0.0
	if Vector2(v.x, v.z).length() < _lead_floor():
		return 0.0
	var spread := rad_to_deg(_record.spread(atan2(v.z, v.x)))
	return clampf((UNSTEADY_SPREAD_DEG - spread) / (UNSTEADY_SPREAD_DEG - STEADY_SPREAD_DEG), 0.0, 1.0)


static func _lead_floor() -> float:
	return LEAD_FLOOR * _cruise if _cruise > 0.0 else MIN_TURN_SPEED


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
	observe_tick(v, 1.0 / float(Engine.physics_ticks_per_second), cruise, fresh)


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
	_record.push(heading if speed >= _lead_floor() else NAN, dt)
	if speed < MIN_TURN_SPEED:
		_have_heading = false
		_turn = move_toward(_turn, 0.0, dt * MAX_TURN)
		return
	if _have_heading:
		var raw := clampf(wrapf(heading - _heading, -PI, PI) / dt, -MAX_TURN, MAX_TURN)
		_turn = lerpf(_turn, raw, 1.0 - exp(-dt / TURN_SMOOTH_S))
	_heading = heading
	_have_heading = true

extends RefCounted

# Pack pressure experiments, world 1 (the kiting sweep, scrapkeep#241 comment 6378906601: circling a pack
# costs nothing on every stage). Five variants, each only a preset of ChallengeDials rows, chosen on the
# command line with --pack-pressure=A, or a combination such as --pack-pressure=A+D. Without the flag every
# dial but E's reads its identity. An explicit --tune of the same key wins over a preset.
#
#   A  aim: crews lead the ball's roll, along its curve, when they steer and when they lay a lunge lane.
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

static var _frame := -1
static var _heading := 0.0
static var _turn := 0.0
static var _have_heading := false


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
		"rest": ChallengeDials.by_stage("pack.rest_by_stage", stage),
		"flank": ChallengeDials.by_stage_or("pack.flank_by_stage", stage, 0.0),
	}


static func crew_extra(stage: int) -> int:
	return maxi(0, int(round(ChallengeDials.by_stage_or("pack.crew_extra_by_stage", stage, 0.0))))


# Where the ball will be in `seconds`, carried along its present curve (the turn rate observe() read this
# tick), so a ball holding a ring is led round the ring, not off it.
static func predict(target, seconds: float) -> Vector3:
	var at: Vector3 = target.ball_position()
	var v: Vector3 = target.planar_velocity()
	var t := clampf(seconds, 0.0, MAX_LEAD_S)
	var w := _turn
	if absf(w) < 0.05:
		return at + v * t
	# The arc: v * (e^{iwt} - 1) / (iw) in the (x, z) plane, heading measured as atan2(z, x).
	var phi := w * t
	var a := sin(phi)
	var b := 1.0 - cos(phi)
	return at + Vector3(v.x * a - v.z * b, 0.0, v.x * b + v.z * a) / w


static func turn_rate() -> float:
	return _turn


# Combat calls this once a physics tick with the player's own planar velocity (never a Sight's, which a
# cloak blanks), so every crew reads the same turn rate.
static func observe(v: Vector3) -> void:
	var frame := Engine.get_physics_frames()
	if frame == _frame:
		return
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	if frame != _frame + 1:
		_have_heading = false
		_turn = 0.0
	_frame = frame
	if Vector2(v.x, v.z).length() < MIN_TURN_SPEED:
		_have_heading = false
		_turn = move_toward(_turn, 0.0, dt * MAX_TURN)
		return
	var heading := atan2(v.z, v.x)
	if _have_heading:
		var raw := clampf(wrapf(heading - _heading, -PI, PI) / dt, -MAX_TURN, MAX_TURN)
		_turn = lerpf(_turn, raw, 1.0 - exp(-dt / TURN_SMOOTH_S))
	_heading = heading
	_have_heading = true

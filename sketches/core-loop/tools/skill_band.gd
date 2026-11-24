extends RefCounted

# Skill bands for the bot driver (Challenge lane, DECISIONS section 5): the same bot at
# three human skill levels, so a boss or stage can be read as "a Novice can't, a Learner
# can after a few tries, an Expert always does". The driver holds one of these as `band`;
# a null band is the driver exactly as it was. Every band number lives in BANDS below, so
# tuning the bands is this file and nothing else.
#
#   Novice:  late reactions, misses many tells, basic attack and ram only.
#   Learner: reads most tells, uses the base kit, and improves across attempts at a boss.
#   Expert:  fast reads and the full kit.
#
# What the bands mean, and do not:
#   - Expert is the unbanded driver. "Full kit" is every hand the driver has, including the F-key
#     item active hand (`active` verb, Intent `active_pressed`). It still has no separate carve hand
#     and no wall-grip hand, so the Expert lacks those. Novice and Learner do not have `active`.
#   - Harpoon is in the Learner's base kit because the grapple is a core verb on every pilot
#     (DECISIONS direction row: enemies "build on the core verbs (roll, ram, grapple, carve)") and
#     every park Warden is a harpoon anchor. The Expert-only harpoon play is the chain hand.
#   - The Learner model: attempt is a command-line index (--attempt=N). Reaction, read chance and
#     cadence window share move linearly with it, the kit is fixed, every attempt plays the same
#     game seed, and nothing is learned inside a run.
#   - A Novice never runs the latch arm, so its non-wins at Wardens are mostly stalls. It still runs
#     the dam's spillway sheet hand, which is a ram, but below the full kit the hand plays by sight:
#     it launches only at an open sheet it has seen for its reaction time and read this cycle, keeps
#     dodging on the way, fires freely, and only the base kit re-rams in a stagger. The pre-pulse
#     launch off the Warden's clock and the hold-fire discipline are the Expert's (timed_sheet).
#
# Reaction is the seconds from a committed telegraph appearing to the bot seeing it. The
# basis is human reaction time: a simple visual response is about 0.2-0.25 s for a
# practised player, a choice response 0.35-0.5 s, and an untrained player under load
# 0.6-0.8 s. The numbers are calibration starting points the harness checks, not final.
# read_* is the chance a given tell is read at all; an unread tell is never dodged.
# window_* is the share of weapon cadence windows hit (PILOT-CADENCE.md section 8): a missed
# window produces the weapon's plain result with no jam or lockout.
# learn_attempts is the attempt at which the *_last values are reached: the values move
# linearly from attempt 1 to that attempt and hold after.
const BANDS := {
	"expert": {"reaction_first": 0.25, "reaction_last": 0.25, "read_first": 1.0, "read_last": 1.0,
		"window_first": 0.85, "window_last": 0.85, "learn_attempts": 1, "kit": "full"},
	"learner": {"reaction_first": 0.45, "reaction_last": 0.30, "read_first": 0.65, "read_last": 0.92,
		"window_first": 0.25, "window_last": 0.45, "learn_attempts": 5, "kit": "base"},
	"novice": {"reaction_first": 0.70, "reaction_last": 0.70, "read_first": 0.35, "read_last": 0.35,
		"window_first": 0.15, "window_last": 0.15, "learn_attempts": 1, "kit": "basic"},
}

# What each kit level lets the driver's hands do. The Novice only fires its gun, rams,
# jumps and boosts, which are not verbs here because every band has them. "active" and
# "chain" are in neither list: only the full kit has them.
const BASE_VERBS := ["special", "line_cast", "plant", "harpoon", "weak_points", "ultimate"]

var name := "expert"
var attempt := 1
var reaction_s := 0.25
var read_chance := 1.0
var window_share := 0.85
var kit := "full"

var _seed := 1
var _rng := RandomNumberGenerator.new()
var _read := {}

# A refusal's message, for tests to read. With quiet set, an unknown band is recorded but not printed (tests feed bad input without an ERROR line).
static var quiet := false
static var last_refusal := ""


# An unknown name is a caller's typo: say so and play the Expert, which is the baseline.
static func make(band_name: String, attempt_number: int, seed_value: int):
	var key := band_name
	if not BANDS.has(key):
		var message := "skill_band: unknown band '%s'; use expert, learner or novice" % band_name
		last_refusal = message
		if not quiet:
			push_error(message)
		key = "expert"
	var row: Dictionary = BANDS[key]
	var band = new()
	band.name = key
	band.attempt = maxi(attempt_number, 1)
	var span := maxi(int(row["learn_attempts"]) - 1, 1)
	var t := clampf(float(band.attempt - 1) / float(span), 0.0, 1.0)
	band.reaction_s = lerpf(float(row["reaction_first"]), float(row["reaction_last"]), t)
	band.read_chance = lerpf(float(row["read_first"]), float(row["read_last"]), t)
	band.window_share = lerpf(float(row["window_first"]), float(row["window_last"]), t)
	band.kit = String(row["kit"])
	band._seed = seed_value
	band._rng.seed = hash(["band", key, band.attempt, seed_value])
	return band


# Deterministic per-window roll independent of tell-read order and band._rng.
static func roll_window(seed_value: int, index: int, share: float) -> bool:
	if share <= 0.0:
		return false
	if share >= 1.0:
		return true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["window", seed_value, index])
	return rng.randf() < share


func hits_window(index: int) -> bool:
	return roll_window(_seed, index, window_share)


# Whether this band sees the tell with this key (a hazard's instance id). The roll is made
# once per key so a tell is read or missed for its whole life. A band that reads everything
# never touches its stream, so an Expert's run cannot differ from the unbanded driver's.
func reads(key: int) -> bool:
	if read_chance >= 1.0:
		return true
	if not _read.has(key):
		_read[key] = _rng.randf() < read_chance
	return _read[key]


# Drops answers for tells that are gone, as the driver prunes its own `_seen`.
func forget(live: Dictionary) -> void:
	if _read.size() > 64:
		for key in _read.keys():
			if not live.has(key):
				_read.erase(key)


func allows(verb: String) -> bool:
	if kit == "full":
		return true
	if kit == "base":
		return verb in BASE_VERBS
	return false


# Ultimate timing (an open core, a crowd) is the Expert's. Below it the press is untimed.
func timed_ultimate() -> bool:
	return kit == "full"


# The dam sheet's pre-pulse launch (read off the Warden's charge clock) and its hold-fire near a
# full bar are the Expert's. Below it the sheet hand waits for the open sheet it can see.
func timed_sheet() -> bool:
	return kit == "full"


func describe() -> Dictionary:
	return {"name": name, "attempt": attempt, "reaction_s": snappedf(reaction_s, 0.001),
		"read_chance": snappedf(read_chance, 0.001), "window_share": snappedf(window_share, 0.001), "kit": kit}

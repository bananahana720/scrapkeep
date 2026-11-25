extends RefCounted

# The Warden's posture fight as one rule object with no scene access (LEGIBILITY section 4).
# Hits fill a posture bar; at 100 the Warden staggers for STAGGER_SECONDS and a contact
# then hits the open core; a shattering contact removes one of CHUNKS health chunks.
# judge() answers what a hit would do and changes nothing, apply() is the one place a hit
# changes state, step() runs the drain and the stagger clock.

const BASE := {"ram": 30.0, "stomp": 30.0, "slam": 30.0}
const SMASH_BASE := 45.0
const OTHER_BASE := 1.5
const OTHER_BASE_CHARGING := 3.0
const MULT_MIN := 0.2
# Overpowered pays (Andrew's tap "Lift the ceiling", 17 Oct 22:04Z): a monster build's hit counts
# up to 3x the plating it meets (MULT_MAX), so it staggers a Warden well under the 45-70 s an
# ordinary pilot takes; it was 1.5x. The hull bosses keep 1.5 in boss_rules.gd POSTURE.
# Who is a monster (coordinator ruling (B) on #222, 21 Oct): a run whose heft is strictly above the
# library's top-bucket maximum heft for that fight (monster_heft.gd, generated from lib-base; the
# Waking and the Mind have their own). A Warden tells the rule on every hit (set_monster). A rule
# never told is ordinary: it fails closed to ORDINARY_RATIO.
const MULT_MAX := 3.0
# A row's "hit_cap" caps one hit's gain while its ratio is ordinary (at most ORDINARY_RATIO);
# from there the cap climbs to FULL at mult_max, so one plain smash never fills the bar but a
# monster build's still can. Without the key a hit may fill it, as before. With
# "hit_cap_until_stagger" the cap holds only until the first stagger, so the later chunks
# fill at the row's own pace.
const ORDINARY_RATIO := 1.5
const DRAIN_DELAY := 3.0
const DRAIN_RATE := 12.0
const STAGGER_SECONDS := 4.0
const CHUNKS := 4
const HEAVY_CHUNKS := 2
const SHATTER_TIER := 2
const FULL := 100.0

# The numbers this rule runs on. A stage row's "posture" dictionary overrides any of them
# by key; a missing key keeps the constant above. "curve" is the exponent on the clamped
# ratio and "ram_shatters" says whether a ram at SHATTER_TIER shatters an open core.
var base := BASE.duplicate()
var smash_base := SMASH_BASE
var other_base := OTHER_BASE
var other_base_charging := OTHER_BASE_CHARGING
var mult_min := MULT_MIN
# The live ceiling: starts ordinary (see set_monster), the row's mult_top for a monster build.
var mult_max := ORDINARY_RATIO
# The row's own ceiling, what a monster build reaches (a row's "mult_max", else MULT_MAX).
var mult_top := MULT_MAX
var drain_delay := DRAIN_DELAY
var drain_rate := DRAIN_RATE
# Set by a mounted driver before step; zero keeps the ordinary idle clock and drain.
var contact_drain_delay := 0.0
# Multiplier on drain_rate set by a mounted driver (e.g. 0.0 while a hoisted hive is out of floor reach).
var drain_rate_scale := 1.0
var stagger_seconds := STAGGER_SECONDS
var shatter_tier := SHATTER_TIER
var curve := 1.0
var ram_shatters := true
var contact_gain_scale := 0.0
var contact_gain_floor := 0.0
var hit_cap := FULL
var hit_cap_until_stagger := false
# A row's "heavy_ratio": a stagger opened by a ram whose punch met at least this times the plating is
# heavy, and a smashing ram that shatters its core takes HEAVY_CHUNKS chunks (the stage 3 hive, Andrew's
# option 1, 23 Oct: a grown build bowls through it harder). A stagger opened any other way, a slam, stomp
# or other smash, and a crack paying off in a later stagger take one. Without the key (0) every shatter
# takes one chunk.
var heavy_ratio := 0.0

var posture := 0.0
var staggered := false
var stagger_left := 0.0
var stagger_frame := -1
var idle := 0.0
var chunks := CHUNKS
var cracked := false
# The stagger the crack was made in: it pays off only in a later one.
var crack_stagger := -1
var shattered_this_stagger := false
var shatter_frame := -1
var gain_frame := -1
var gain_in_frame := 0.0
var staggers := 0
var heavy_stagger := false
var glances := 0


func _init(numbers := {}) -> void:
	base = BASE.duplicate()
	base.merge(numbers.get("base", {}), true)
	smash_base = float(numbers.get("smash_base", SMASH_BASE))
	other_base = float(numbers.get("other_base", OTHER_BASE))
	other_base_charging = float(numbers.get("other_base_charging", OTHER_BASE_CHARGING))
	mult_min = float(numbers.get("mult_min", MULT_MIN))
	mult_top = float(numbers.get("mult_max", MULT_MAX))
	mult_max = ordinary_ceiling()
	drain_delay = float(numbers.get("drain_delay", DRAIN_DELAY))
	drain_rate = float(numbers.get("drain_rate", DRAIN_RATE))
	contact_drain_delay = float(numbers.get("contact_drain_delay", 0.0))
	stagger_seconds = float(numbers.get("stagger_seconds", STAGGER_SECONDS))
	shatter_tier = int(numbers.get("shatter_tier", SHATTER_TIER))
	curve = float(numbers.get("curve", 1.0))
	ram_shatters = bool(numbers.get("ram_shatters", true))
	contact_gain_scale = float(numbers.get("contact_gain_scale", 0.0))
	contact_gain_floor = float(numbers.get("contact_gain_floor", 0.0))
	hit_cap = float(numbers.get("hit_cap", FULL))
	hit_cap_until_stagger = bool(numbers.get("hit_cap_until_stagger", false))
	heavy_ratio = float(numbers.get("heavy_ratio", 0.0))


# The ceiling an ordinary pilot meets: the row's, but never past ORDINARY_RATIO.
func ordinary_ceiling() -> float:
	return minf(mult_top, ORDINARY_RATIO)


# Whether the pilot is a monster build for the next judge: only then does mult_max reach mult_top.
# Read per hit so a pilot who grows past the threshold mid-fight earns the lift.
func set_monster(on: bool) -> void:
	mult_max = mult_top if on else ordinary_ceiling()


# hit: {kind, punch, plating, smash, tier, charging, frame, hp, max_hp}. The answer is
# combat's resolve() shape (punch, plating, full, dealt, part) plus shred, gain, glance,
# shatter, crack and contact.
func judge(hit: Dictionary) -> Dictionary:
	var kind := String(hit.get("kind", ""))
	var punch := float(hit.get("punch", 0.0))
	var plating := float(hit.get("plating", 0.0))
	var frame := int(hit.get("frame", 0))
	var contact := base.has(kind)
	var ratio := punch / plating if plating > 0.0 else mult_max
	var glance := ratio <= mult_min
	var result := {"kind": kind, "punch": punch, "plating": plating, "full": not glance, "dealt": 0.0, "part": "", "shred": false,
			"gain": 0.0, "glance": glance, "shatter": false, "crack": false, "contact": contact}
	if staggered:
		if contact and frame > stagger_frame:
			result["part"] = String(hit.get("point", "core"))
			_judge_core(result, hit)
		return result
	if contact and frame == shatter_frame:
		return result
	var hit_base := other_base_charging if bool(hit.get("charging", false)) else other_base
	if contact:
		hit_base = smash_base if bool(hit.get("smash", false)) else float(base[kind])
	var gain := hit_base * pow(clampf(ratio, mult_min, mult_max), curve)
	if contact and contact_gain_scale > 0.0:
		gain *= 1.0 + contact_gain_scale * maxf(0.0, clampf(ratio, mult_min, mult_max) - contact_gain_floor)
	if hit_cap < FULL:
		gain = minf(gain, cap_for(ratio))
	if contact and frame == gain_frame:
		gain = maxf(0.0, gain - gain_in_frame)
	result["gain"] = gain
	return result


# The most one hit at this ratio may add (see ORDINARY_RATIO).
func cap_for(ratio: float) -> float:
	# When mult_top <= ORDINARY_RATIO (a hull boss) a row's hit_cap is disabled.
	if hit_cap >= FULL or mult_top <= ORDINARY_RATIO or (hit_cap_until_stagger and staggers > 0):
		return FULL
	# An ordinary pilot (mult_max held at the ordinary ceiling) always meets the ordinary cap.
	var t := clampf((minf(ratio, mult_max) - ORDINARY_RATIO) / (mult_top - ORDINARY_RATIO), 0.0, 1.0)
	return lerpf(hit_cap, FULL, t)


func _judge_core(result: Dictionary, hit: Dictionary) -> void:
	var smash := bool(hit.get("smash", false))
	var fast_ram := ram_shatters and String(hit.get("kind", "")) == "ram" and int(hit.get("tier", 0)) >= shatter_tier
	if smash or fast_ram or (cracked and crack_stagger < staggers):
		var max_hp := float(hit.get("max_hp", 0.0))
		var take := mini(chunks, HEAVY_CHUNKS) if heavy_stagger and String(hit.get("kind", "")) == "ram" and (smash or fast_ram) else 1
		result["shatter"] = true
		result["take"] = take
		result["dealt"] = maxf(0.0, float(hit.get("hp", 0.0)) - max_hp * (chunks - take) / CHUNKS)
	else:
		result["crack"] = true


func apply(result: Dictionary, frame: int) -> void:
	if result.get("glance", false):
		glances += 1
	if staggered:
		if result.get("shatter", false):
			chunks = maxi(0, chunks - int(result.get("take", 1)))
			cracked = false
			shattered_this_stagger = true
			shatter_frame = frame
			_end_stagger()
		elif result.get("crack", false) and not cracked:
			cracked = true
			crack_stagger = staggers
		return
	var gain := float(result.get("gain", 0.0))
	if gain <= 0.0:
		return
	posture = minf(FULL, posture + gain)
	idle = 0.0
	if result.get("contact", false):
		gain_in_frame = gain_in_frame + gain if frame == gain_frame else gain
		gain_frame = frame
	if posture >= FULL:
		staggered = true
		stagger_left = stagger_seconds
		stagger_frame = frame
		shattered_this_stagger = false
		var plating := float(result.get("plating", 0.0))
		heavy_stagger = heavy_ratio > 0.0 and result.get("kind", "") == "ram" and plating > 0.0 \
				and float(result.get("punch", 0.0)) / plating >= heavy_ratio
		staggers += 1


func step(delta: float) -> void:
	if staggered:
		stagger_left -= delta
		if stagger_left <= 0.0:
			_end_stagger()
		return
	if contact_drain_delay > 0.0:
		idle = 0.0
		return
	if drain_rate_scale <= 0.0:
		return
	idle += delta
	var draining := minf(delta, idle - drain_delay)
	if draining > 0.0:
		posture = maxf(0.0, posture - drain_rate * drain_rate_scale * draining)


func _end_stagger() -> void:
	staggered = false
	stagger_left = 0.0
	posture = 0.0
	idle = 0.0

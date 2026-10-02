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
const MULT_MAX := 1.5
const DRAIN_DELAY := 3.0
const DRAIN_RATE := 12.0
const STAGGER_SECONDS := 4.0
const CHUNKS := 4
const SHATTER_TIER := 2
const FULL := 100.0

var posture := 0.0
var staggered := false
var stagger_left := 0.0
var stagger_frame := -1
var idle := 0.0
var chunks := CHUNKS
var cracked := false
var shattered_this_stagger := false
var gain_frame := -1
var gain_in_frame := 0.0
var staggers := 0
var glances := 0


# hit: {kind, punch, plating, smash, tier, charging, frame, hp, max_hp}. The answer is
# combat's resolve() shape (punch, plating, full, dealt, part) plus shred, gain, glance,
# shatter, crack and contact.
func judge(hit: Dictionary) -> Dictionary:
	var kind := String(hit.get("kind", ""))
	var punch := float(hit.get("punch", 0.0))
	var plating := float(hit.get("plating", 0.0))
	var frame := int(hit.get("frame", 0))
	var contact := BASE.has(kind)
	var ratio := punch / plating if plating > 0.0 else MULT_MAX
	var glance := ratio <= MULT_MIN
	var result := {"punch": punch, "plating": plating, "full": not glance, "dealt": 0.0, "part": "", "shred": false,
			"gain": 0.0, "glance": glance, "shatter": false, "crack": false, "contact": contact}
	if staggered:
		if contact and frame > stagger_frame:
			result["part"] = "core"
			if not glance:
				_judge_core(result, hit)
		return result
	var base := OTHER_BASE_CHARGING if bool(hit.get("charging", false)) else OTHER_BASE
	if contact:
		base = SMASH_BASE if bool(hit.get("smash", false)) else float(BASE[kind])
	var gain := base * clampf(ratio, MULT_MIN, MULT_MAX)
	if contact and frame == gain_frame:
		gain = maxf(0.0, gain - gain_in_frame)
	result["gain"] = gain
	return result


func _judge_core(result: Dictionary, hit: Dictionary) -> void:
	var smash := bool(hit.get("smash", false))
	var fast_ram := String(hit.get("kind", "")) == "ram" and int(hit.get("tier", 0)) >= SHATTER_TIER
	if smash or fast_ram or cracked:
		var max_hp := float(hit.get("max_hp", 0.0))
		result["shatter"] = true
		result["dealt"] = maxf(0.0, float(hit.get("hp", 0.0)) - max_hp * (chunks - 1) / CHUNKS)
	else:
		result["crack"] = true


func apply(result: Dictionary, frame: int) -> void:
	if result.get("glance", false):
		glances += 1
	if staggered:
		if result.get("shatter", false):
			chunks = maxi(0, chunks - 1)
			cracked = false
			shattered_this_stagger = true
			_end_stagger()
		elif result.get("crack", false):
			cracked = true
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
		stagger_left = STAGGER_SECONDS
		stagger_frame = frame
		shattered_this_stagger = false
		staggers += 1


func step(delta: float) -> void:
	if staggered:
		stagger_left -= delta
		if stagger_left <= 0.0:
			_end_stagger()
		return
	idle += delta
	var draining := minf(delta, idle - DRAIN_DELAY)
	if draining > 0.0:
		posture = maxf(0.0, posture - DRAIN_RATE * draining)


func _end_stagger() -> void:
	staggered = false
	stagger_left = 0.0
	posture = 0.0
	idle = 0.0

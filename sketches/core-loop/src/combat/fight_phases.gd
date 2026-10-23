class_name FightPhases
extends RefCounted

# Fight phases and sound-cued attacks (Andrew, 23 Oct 19:02Z). A boss fight has up to three
# phases, a mini-boss fight two. Each later phase ratchets up: the fight's own design picks
# speed (tempo of its wind-ups, its movement), modifiers, or follow-ups, an added attack
# that comes hard on the heels of the one before and takes practice to dodge. Sound is the
# fair telegraph for those: every follow-up is CUED, its cue sounds CUE_LEAD seconds before
# the hazard is drawn, and the drawn tell may then be as short as CUED_WARN. From the
# first sound to the hit is never under CUED_TOTAL, so a cued follow-up still meets every
# "announced at least 1.0 s ahead" read, while the eyes alone get only CUED_WARN.
#
# Every turn into a later phase opens with a transition beat (Andrew, 23 Oct 19:11Z): for
# transition() seconds the fight plays its turn animation, takes no posture or damage and
# commits no new attack, so the player resets and thinks before the harder pattern. The
# music swaps anthems on the phase signal (fight_phase_changed) at the next downbeat, which
# lands inside the beat: TRANSITION_SECONDS is one bar at 120 BPM or faster. Tunable per fight
# with ChallengeDials <key>.transition_mult; nothing skips it, and it is short enough for retries.
#
# Pure numbers and one publish: the fight owns its attacks and calls in here for the
# phase it is in, the row for that phase, and the cue.

const BOSS_MAX := 3
const MINI_MAX := 2
const CUE_LEAD := 0.5
const CUED_WARN := ChallengeDials.TELL_FLOOR
const CUED_TOTAL := CUE_LEAD + CUED_WARN
const TRANSITION_SECONDS := 2.0
# A mini-boss turns to phase two at this share of its health.
const MINI_TURN := 0.5

var fight_id := ""
var phases := 1
var phase := 0
var _dial_key := ""
var _events
var _clock := 0.0
var _began := 0.0


# fight_id names the fight for the music ("brindle", "rogue_crane"); dial_key is the
# ChallengeDials prefix its ratchet reads ("brindle", "rogue"). events is the game bus or null.
func _init(id: String, count: int, dial_key: String, events = null) -> void:
	fight_id = id
	phases = count
	_dial_key = dial_key
	_events = events


static func boss(id: String, events = null, count := BOSS_MAX) -> FightPhases:
	return FightPhases.new(id, clampi(count, 1, BOSS_MAX), id, events)


static func mini(id: String, dial_key: String, events = null) -> FightPhases:
	return FightPhases.new(id, MINI_MAX, dial_key, events)


# Moves to phase `next` (clamped to the fight's count) and publishes it. now is the fight's clock.
func enter(next: int, now := 0.0) -> void:
	phase = clampi(next, 1, phases)
	_began = now
	_clock = now
	if _events != null and _events.has_signal("fight_phase_changed"):
		_events.fight_phase_changed.emit(fight_id, phase, phases)


# A mini-boss's turn: phase two the first time its health share is at or under MINI_TURN.
# Returns true on the tick it turns.
func by_health(share: float, now := 0.0) -> bool:
	if phase < 1:
		enter(1, now)
	if phase == 1 and phases >= 2 and share <= MINI_TURN:
		enter(2, now)
		return true
	return false


func tick(now: float) -> void:
	_clock = now


# The transition beat's length for this fight.
func transition() -> float:
	var key := _dial_key + ".transition_mult"
	return TRANSITION_SECONDS * (ChallengeDials.f(key) if ChallengeDials.DEFAULTS.has(key) else 1.0)


# True during the transition beat that opens phase two or three.
func in_transition() -> bool:
	return phase > 1 and _clock - _began < transition()


# Follow-ups owed after a lead attack in this phase (ChallengeDials <key>.follow_ups_by_phase).
# None during the transition beat.
func follow_ups() -> int:
	if phase < 1 or in_transition():
		return 0
	return maxi(0, int(round(_list(".follow_ups_by_phase", 0.0))))


# Wind-up and cadence scale for this phase (<key>.tempo_by_phase; under 1 is faster). A wind-up
# scaled by it is still floored at the tell floor by the caller's ChallengeDials.floored().
func tempo() -> float:
	return _list(".tempo_by_phase", 1.0)


# Movement scale for this phase (<key>.speed_by_phase).
func speed() -> float:
	return _list(".speed_by_phase", 1.0)


func ratcheted() -> bool:
	return phase > 1


# Sounds the cue for a follow-up: the hazard comes CUE_LEAD later and lands CUED_TOTAL from now.
func cue(attack_id: String) -> void:
	if _events != null and _events.has_signal("attack_cued"):
		_events.attack_cued.emit(fight_id, attack_id, CUED_TOTAL)


func _list(suffix: String, fallback: float) -> float:
	var key := _dial_key + suffix
	if not ChallengeDials.DEFAULTS.has(key) or phase < 1:
		return fallback
	return ChallengeDials.by_phase(key, phase)

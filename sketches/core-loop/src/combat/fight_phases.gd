class_name FightPhases
extends RefCounted

const BOSS_MAX := 3
const MINI_MAX := 2
const CUE_LEAD := 0.5
const CUED_WARN := ChallengeDials.TELL_FLOOR
const CUED_TOTAL := CUE_LEAD + CUED_WARN
const TRANSITION_SECONDS := 2.0
const MINI_TURN := 0.5

var fight_id := ""
var phases := 1
var phase := 0
var _dial_key := ""
var _events
var _clock := 0.0
var _began := 0.0


func _init(id: String, count: int, dial_key: String, events = null) -> void:
	fight_id = id
	phases = count
	_dial_key = dial_key
	_events = events


static func boss(id: String, events = null, count := BOSS_MAX) -> FightPhases:
	return FightPhases.new(id, clampi(count, 1, BOSS_MAX), id, events)


static func mini(id: String, dial_key: String, events = null) -> FightPhases:
	return FightPhases.new(id, MINI_MAX, dial_key, events)


func enter(next: int, now := 0.0) -> void:
	phase = clampi(next, 1, phases)
	_began = now
	_clock = now
	if _events != null and _events.has_signal("fight_phase_changed"):
		_events.fight_phase_changed.emit(fight_id, phase, phases)


func by_health(share: float, now := 0.0) -> bool:
	_clock = now
	if phase < 1:
		enter(1, now)
	if phase == 1 and phases >= 2 and share <= MINI_TURN:
		enter(2, now)
		return true
	return false


func tick(now: float) -> void:
	_clock = now


func transition() -> float:
	var key := _dial_key + ".transition_mult"
	return TRANSITION_SECONDS * (ChallengeDials.f(key) if ChallengeDials.DEFAULTS.has(key) else 1.0)


func in_transition() -> bool:
	return phase > 1 and _clock - _began < transition()


func follow_ups() -> int:
	if phase < 1 or in_transition():
		return 0
	return maxi(0, int(round(_list(".follow_ups_by_phase", 0.0))))


func tempo() -> float:
	return _list(".tempo_by_phase", 1.0)


func speed() -> float:
	return _list(".speed_by_phase", 1.0)


func ratcheted() -> bool:
	return phase > 1


func cue(attack_id: String) -> void:
	if _events != null and _events.has_signal("attack_cued"):
		_events.attack_cued.emit(fight_id, attack_id, CUED_TOTAL)


func _list(suffix: String, fallback: float) -> float:
	var key := _dial_key + suffix
	if not ChallengeDials.DEFAULTS.has(key) or phase < 1:
		return fallback
	return ChallengeDials.by_phase(key, phase)

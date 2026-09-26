extends RefCounted

const Rules := preload("res://src/rules.gd")

# The stage loop is one state machine rather than a scatter of booleans: every
# screen, the director's spike and the HUD read `phase`, and only `tick` and the
# three intent calls below can move it.
enum Phase { RUNNING, CHARGING, READY, CLEAR, DEAD }

const PHASE_NAMES := ["running", "charging", "ready", "clear", "scrapped"]

signal phase_changed(phase: int)
signal scrap_changed(scrap: int)

var phase: int = Phase.RUNNING
var stage_time := 0.0
var scrap := 0
var scrap_taken := 0
var hp := Rules.PLAYER_HP
var hp_max := Rules.PLAYER_HP
var charge := 0.0
var charge_seconds := Rules.CHARGE_SECONDS
var caches_opened := 0

var _since_hit := Rules.REGEN_DELAY


func live() -> bool:
	return phase == Phase.RUNNING or phase == Phase.CHARGING or phase == Phase.READY


func charging() -> bool:
	return phase == Phase.CHARGING


func tier() -> int:
	return Rules.tier_of(stage_time)


func tier_progress() -> float:
	return fmod(stage_time, Rules.TIER_SECONDS) / Rules.TIER_SECONDS


func charge_fraction() -> float:
	return clampf(charge / charge_seconds, 0.0, 1.0)


func tick(delta: float, in_forge_zone: bool) -> void:
	if not live():
		return
	stage_time += delta
	_since_hit += delta
	if _since_hit > Rules.REGEN_DELAY and hp < hp_max:
		hp = minf(hp_max, hp + Rules.REGEN_RATE * delta)
	if phase == Phase.CHARGING:
		# Leaving the apron only stalls the charge; the tier clock keeps running,
		# so running away is never free.
		if in_forge_zone:
			charge += delta
			if charge >= charge_seconds:
				charge = charge_seconds
				_set_phase(Phase.READY)


func start_charge() -> bool:
	if phase != Phase.RUNNING:
		return false
	_set_phase(Phase.CHARGING)
	return true


func take_exit() -> bool:
	if phase != Phase.READY:
		return false
	_set_phase(Phase.CLEAR)
	return true


func damage(amount: float) -> void:
	if not live() or amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	_since_hit = 0.0
	if hp <= 0.0:
		_set_phase(Phase.DEAD)


func add_scrap(amount: int) -> void:
	if amount <= 0:
		return
	scrap += amount
	scrap_taken += amount
	scrap_changed.emit(scrap)


func spend(amount: int) -> bool:
	if amount > scrap:
		return false
	scrap -= amount
	scrap_changed.emit(scrap)
	return true


func raise_max_hp(amount: float) -> void:
	hp_max += amount
	hp += amount


func phase_name() -> String:
	return PHASE_NAMES[phase]


func _set_phase(next: int) -> void:
	if phase == next:
		return
	phase = next
	phase_changed.emit(phase)

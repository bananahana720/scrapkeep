extends RefCounted

const SpeedTier := preload("res://src/core/speed_tier.gd")

const MAX := 100.0
const FILL_BLAZING_PER_S := 12.0
const FILL_SKIM := 25.0
const DRAIN_PER_S := 20.0
const HOT_AT := 50.0
const WARM_AT := MAX * 0.25
const HOT_DAMAGE_TAKEN := 1.5
const BLAST_RADIUS := 7.0
const BLAST_FORCE := 2.0
const COOK_OFF_S := 4.0
const COOK_OFF_FORCE := 0.5
const COOK_OFF_MIN_SPEED := 14.0
const COOK_OFF_SELF_HULL := 0.10
const COOK_OFF_SOURCE := "heat_cook_off"
const SKIM_MIN_TIER := SpeedTier.CRUISE
const SPEND_KINDS := ["ram", "stomp", "slam"]

const OFF := "off"
const WATCH := "watch"
const ON := "on"

var blast_props := Callable()
var mode := OFF
var value := 0.0
var waited := 0.0
var rolled_s := 0.0
var blazing_s := 0.0
var skims := 0
var detonations := 0
var cook_offs := 0
var hits_hot := 0

signal changed(value: float, band: int)
signal redlined
signal detonated(at: Vector3, force: float)
signal cooked_off(at: Vector3, force: float)
signal skimmed(at: Vector3)


func on() -> bool:
	return mode == ON


func set_mode(next: String) -> void:
	mode = next if next in [OFF, WATCH, ON] else OFF
	clear()


static func band_of(v: float) -> int:
	if v >= MAX:
		return 3
	if v >= HOT_AT:
		return 2
	if v >= WARM_AT:
		return 1
	return 0


func band() -> int:
	return band_of(value)


func warmth() -> float:
	if not on() or value < WARM_AT:
		return 0.0
	return value / MAX


func hot_share() -> float:
	return clampf((value - WARM_AT) / (HOT_AT - WARM_AT), 0.0, 1.0)


func hot() -> bool:
	return on() and value >= HOT_AT


func redline() -> bool:
	return on() and value >= MAX


func fuse_left() -> float:
	if not redline():
		return -1.0
	return maxf(COOK_OFF_S - waited, 0.0)


const KETTLE_S := 2.0
const KETTLE_HZ := Vector2(4.0, 10.0)


func kettle_live() -> bool:
	var left := fuse_left()
	return left > 0.0 and left <= KETTLE_S


func kettle_pulse() -> float:
	if not kettle_live():
		return 0.0
	var t := KETTLE_S - fuse_left()
	var phase := t * KETTLE_HZ.x + 0.5 * t * t / KETTLE_S * (KETTLE_HZ.y - KETTLE_HZ.x)
	return 0.5 + 0.5 * cos(TAU * phase)


func taken_scale() -> float:
	return HOT_DAMAGE_TAKEN if hot() else 1.0


func tick(delta: float, tier: int, at := Vector3.ZERO, force := 0.0) -> void:
	if mode == OFF:
		return
	if tier >= SpeedTier.CRUISE:
		rolled_s += delta
	if tier >= SpeedTier.BLAZING:
		blazing_s += delta
	if mode != ON:
		return
	if value >= MAX:
		waited += delta
		if waited >= COOK_OFF_S:
			_set_value(0.0)
			cook_offs += 1
			cooked_off.emit(at, maxf(force, COOK_OFF_MIN_SPEED) * COOK_OFF_FORCE)
		return
	if tier >= SpeedTier.BLAZING:
		_set_value(value + FILL_BLAZING_PER_S * delta)
	elif tier < SpeedTier.FAST:
		_set_value(value - DRAIN_PER_S * delta)


func skim(tier: int, at := Vector3.ZERO) -> bool:
	if mode == OFF or tier < SKIM_MIN_TIER:
		return false
	skims += 1
	if mode != ON or value >= MAX:
		return false
	_set_value(value + FILL_SKIM)
	skimmed.emit(at)
	return true


func spend(kind: String, at: Vector3, force: float) -> float:
	if not redline() or not kind in SPEND_KINDS:
		return 0.0
	_set_value(0.0)
	detonations += 1
	var blast := force * BLAST_FORCE
	if blast_props.is_valid():
		blast_props.call(at, BLAST_RADIUS, "redline")
	detonated.emit(at, blast)
	return blast


func note_hit() -> void:
	if hot():
		hits_hot += 1


func clear() -> void:
	waited = 0.0
	if value != 0.0:
		_set_value(0.0)


func reset_counts() -> void:
	rolled_s = 0.0
	blazing_s = 0.0
	skims = 0
	detonations = 0
	cook_offs = 0
	hits_hot = 0


func summary() -> Dictionary:
	return {"mode": mode, "rolled_s": snappedf(rolled_s, 0.01), "blazing_s": snappedf(blazing_s, 0.01),
		"skims": skims, "detonations": detonations, "cook_offs": cook_offs, "hits_hot": hits_hot}


func _set_value(next: float) -> void:
	var before := band()
	var was := value
	value = clampf(next, 0.0, MAX)
	if value < MAX:
		waited = 0.0
	if value == was:
		return
	changed.emit(value, band())
	if band() == 3 and before != 3:
		redlined.emit()

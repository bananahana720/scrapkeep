extends RefCounted


enum { CHARGING, READY, FIRING, HOLDING, RETURNING }
const PERIODIC := "periodic"
const ON_DEMAND := "on_demand"
const COOL := 0.5

var mode := PERIODIC
var charge := 3.0
var rise := 0.7
var hold := 1.2
var sink := 1.4
var phase := CHARGING
var t := 0.0


func _init(mode_id := PERIODIC, charge_seconds := 3.0, offset := 0.0) -> void:
	mode = mode_id
	charge = charge_seconds
	t = clampf(offset, 0.0, charge)


func step(delta: float) -> String:
	t += delta
	match phase:
		CHARGING:
			if t >= charge:
				t = 0.0
				if mode == ON_DEMAND:
					phase = READY
					return "ready"
				phase = FIRING
				return "fired"
		FIRING:
			if mode == ON_DEMAND:
				if t >= COOL:
					t = 0.0
					phase = CHARGING
					return "charging"
			elif t >= rise:
				t = 0.0
				phase = HOLDING
		HOLDING:
			if t >= hold:
				t = 0.0
				phase = RETURNING
		RETURNING:
			if t >= sink:
				t = 0.0
				phase = CHARGING
				return "charging"
	return ""


func trigger() -> bool:
	if mode != ON_DEMAND or phase != READY:
		return false
	phase = FIRING
	t = 0.0
	return true


func gauge() -> float:
	match phase:
		CHARGING:
			return clampf(t / charge, 0.0, 1.0)
		READY, FIRING, HOLDING:
			return 1.0
		_:
			return clampf(1.0 - t / sink, 0.0, 1.0)


func extension() -> float:
	match phase:
		FIRING:
			if mode == ON_DEMAND:
				return 0.0
			var f := clampf(t / rise, 0.0, 1.0)
			return 1.0 - pow(1.0 - f, 2.0)
		HOLDING:
			return 1.0
		RETURNING:
			return clampf(1.0 - t / sink, 0.0, 1.0)
	return 0.0


func seconds_to_fire() -> float:
	if phase == CHARGING:
		return charge - t
	if phase == RETURNING:
		return sink - t + charge
	if phase == HOLDING:
		return hold - t + sink + charge
	return 0.0

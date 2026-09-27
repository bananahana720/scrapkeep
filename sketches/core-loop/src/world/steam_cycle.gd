extends RefCounted

# A contraption's cycle, the one clock its gauge needle, its sound and its firing all
# read (VISUAL-LANGUAGE section 11: a bone dial whose needle sweeps linearly).
#
# PERIODIC (a steam lift): the needle sweeps while the piston rests, the piston fires
# up at full, holds, and sinks back. Nothing waits for the ball; you read the needle
# and time your roll across the plate.
# ON_DEMAND (a launcher): the needle sweeps while it charges, then holds at the red
# line until a ball rolls in; it fires the tick the ball arrives. A ball that arrives
# while it charges rolls on through, so a launcher is never a stop.

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


# One tick. Returns "fired" on the tick a periodic piston fires, "ready" on the tick a
# launcher reaches the red line, "charging" on the tick it starts to charge, else "".
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


# A launcher fires only from the red line. True when it fired.
func trigger() -> bool:
	if mode != ON_DEMAND or phase != READY:
		return false
	phase = FIRING
	t = 0.0
	return true


# The needle, 0 to 1: linear through the charge, pinned at 1 while ready or lifted.
func gauge() -> float:
	match phase:
		CHARGING:
			return clampf(t / charge, 0.0, 1.0)
		READY, FIRING, HOLDING:
			return 1.0
		_:
			return clampf(1.0 - t / sink, 0.0, 1.0)


# The piston's extension, 0 at rest to 1 at the top. The rise eases out, so the plate
# leaves fast and the ball keeps the push as it tops out.
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


# Seconds until the next firing, for a periodic cycle; 0 while it is up.
func seconds_to_fire() -> float:
	if phase == CHARGING:
		return charge - t
	if phase == RETURNING:
		return sink - t + charge
	if phase == HOLDING:
		return hold - t + sink + charge
	return 0.0

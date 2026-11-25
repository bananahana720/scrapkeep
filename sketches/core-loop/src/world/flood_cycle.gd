extends RefCounted

enum { DRY, WARNING, RISING, HIGH, FALLING }

const PHASE_NAMES := ["dry", "klaxon", "rising", "flooded", "draining"]
const WET_DURATIONS := [5.0, 6.0, 14.0, 8.0]
const HIDDEN_BELOW := 1.5

var phase := DRY
var elapsed := 0.0
var floods := 0
var dry_seconds := 57.0
var first_dry := 57.0


func duration(p: int) -> float:
	if p == DRY:
		return first_dry if floods == 0 else dry_seconds
	return WET_DURATIONS[p - 1]


func advance(delta: float) -> void:
	elapsed += delta
	while elapsed >= duration(phase):
		elapsed -= duration(phase)
		phase = (phase + 1) % 5
		if phase == DRY:
			floods += 1


func fraction() -> float:
	return clampf(elapsed / duration(phase), 0.0, 1.0)


func depth(full: float) -> float:
	match phase:
		RISING:
			return lerpf(-HIDDEN_BELOW, full, fraction())
		HIGH:
			return full
		FALLING:
			return lerpf(full, -HIDDEN_BELOW, fraction())
		_:
			return -HIDDEN_BELOW


func klaxon() -> bool:
	return phase == WARNING or phase == RISING


func seconds_to_flood() -> float:
	if phase != WARNING:
		return -1.0
	return maxf(0.0, duration(WARNING) - elapsed)


func hatch_revealed() -> bool:
	return floods > 0

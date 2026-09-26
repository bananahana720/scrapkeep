extends RefCounted

# The flood is a clock, not a pile of booleans: one phase plus its elapsed time
# answers "is the klaxon on", "how high is the water" and "has it ever receded".
enum { DRY, WARNING, RISING, HIGH, FALLING }

const PHASE_NAMES := ["dry", "klaxon", "rising", "flooded", "draining"]
const DURATIONS := [57.0, 5.0, 6.0, 14.0, 8.0]
const HIDDEN_BELOW := 1.5

var phase := DRY
var elapsed := 0.0
var floods := 0


func advance(delta: float) -> void:
	elapsed += delta
	while elapsed >= DURATIONS[phase]:
		elapsed -= DURATIONS[phase]
		phase = (phase + 1) % DURATIONS.size()
		if phase == DRY:
			floods += 1


func fraction() -> float:
	return clampf(elapsed / DURATIONS[phase], 0.0, 1.0)


func cycle_seconds() -> float:
	var total := 0.0
	for d in DURATIONS:
		total += d
	return total


# Metres above the basin floor; negative means the plane is parked out of sight.
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
	return maxf(0.0, DURATIONS[WARNING] - elapsed)


func hatch_revealed() -> bool:
	return floods > 0

extends RefCounted

enum { WALK, CRUISE, FAST, BLAZING }

const NAMES := ["walk", "cruise", "fast", "blazing"]
const MULTIPLES := [0.0, 0.55, 1.15, 1.9]
const COLORS := [Color(0.65, 0.72, 0.8), Color(0.55, 0.9, 0.7), Color(1.0, 0.85, 0.35), Color(1.0, 0.98, 0.90)]


static func of(speed: float, cruise: float) -> int:
	var tier := 0
	for i in MULTIPLES.size():
		if speed >= MULTIPLES[i] * cruise:
			tier = i
	return tier


static func fraction(speed: float, cruise: float) -> float:
	return clampf(speed / maxf(1.0, cruise * MULTIPLES[BLAZING]), 0.0, 1.0)


static func label(tier: int) -> String:
	return NAMES[clampi(tier, 0, NAMES.size() - 1)]

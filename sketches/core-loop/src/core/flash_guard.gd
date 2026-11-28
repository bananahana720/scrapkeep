extends RefCounted

const ALPHA_SHARE := 0.35
const INFO_SHARE := 0.55
const SPIKE_SHARE := 0.3
const WHITE_SHARE := 0.3
const MIN_PERIOD := 1.0 / 3.0

static var on := false


static func alpha(value: float) -> float:
	return value * ALPHA_SHARE if on else value


static func info(value: float) -> float:
	return value * INFO_SHARE if on else value


static func spike(rest: float, peak: float) -> float:
	return lerpf(rest, peak, SPIKE_SHARE) if on else peak


static func whiten(amount: float) -> float:
	return amount * WHITE_SHARE if on else amount


static func blink(lit: bool) -> bool:
	return true if on else lit


static func period(seconds: float) -> float:
	return maxf(seconds, MIN_PERIOD) if on else seconds


static func rate(hz: float) -> float:
	return minf(hz, 1.0 / MIN_PERIOD) if on else hz

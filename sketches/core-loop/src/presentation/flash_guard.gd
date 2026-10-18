extends RefCounted

# Reduce flashes (Andrew, design question 7, 17 Oct 2026): one saved toggle that every bright
# flash, white pop and strobe reads before it draws. Off, every helper returns its input. On,
# a flash keeps its colour, shape and timing but loses most of its brightness, and nothing
# repeats faster than WCAG 2.3.1's three flashes a second. Telegraphs keep their timing and
# their read: only the brightness of the spike is cut, never the warning itself.
# Game.set_reduce_flashes sets `on`; the sites read it each time they flash.

# A decorative overlay's or glyph's alpha keeps this share.
const ALPHA_SHARE := 0.35
# A flash that carries information (where a hit came from, where an attack landed, a reach
# ring) keeps more, so it still reads at a glance.
const INFO_SHARE := 0.55
# A light, emission or exposure spike keeps this share of its rise above rest.
const SPIKE_SHARE := 0.3
# A colour pushed toward white keeps this share of the push, so a hit stays tinted.
const WHITE_SHARE := 0.3
# The fastest a repeating pulse may cycle with the toggle on: 3 Hz.
const MIN_PERIOD := 1.0 / 3.0

static var on := false


static func alpha(value: float) -> float:
	return value * ALPHA_SHARE if on else value


static func info(value: float) -> float:
	return value * INFO_SHARE if on else value


# `peak` brought back toward `rest`: a light that jumps from 1 to 4 jumps to 1.9.
static func spike(rest: float, peak: float) -> float:
	return lerpf(rest, peak, SPIKE_SHARE) if on else peak


# How far toward white a flash may push a colour (0 to 1).
static func whiten(amount: float) -> float:
	return amount * WHITE_SHARE if on else amount


# A hard on/off blink's state: steady on with the toggle on, so it still shows but never
# strobes. `lit` is the blink's own state this frame.
static func blink(lit: bool) -> bool:
	return true if on else lit


# A pulse's period, never shorter than MIN_PERIOD with the toggle on.
static func period(seconds: float) -> float:
	return maxf(seconds, MIN_PERIOD) if on else seconds


# A pulse's rate in Hz, never above 1 / MIN_PERIOD with the toggle on.
static func rate(hz: float) -> float:
	return minf(hz, 1.0 / MIN_PERIOD) if on else hz

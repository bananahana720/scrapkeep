extends RefCounted

# The sinkhole's floor is lava (Andrew, 2026-10-17 23:24Z): touching the cinder floor is free, lingering on it hurts.
# A ball rolling on a cinder strip (contraptions.gd _on_cinder) and on the floor by the Dig's floor rule
# (src/combat/floor_rule.gd) builds dwell; after GRACE_S of unbroken contact it burns BURN_HP_PER_S, paid in
# TICK_S pulses so the hurt sound and flash fire a few times a second, not every tick. Leaving the floor or landing a hit on
# an enemy cools it at once, so a bowl through a pack or a quick zigzag never burns. The burn stops at FLOOR_HP: it
# nudges a ball up the wall and never kills ("Overpowered pays").
#
# step() returns what changed this tick for world.gd to publish: "glow" 0..1 as the grace runs out (the cinders'
# telegraph), "damage" to apply (0 most ticks), and "fact", one of "" / GLOW_FACT / BURN_FACT / COOL_FACT.

const GRACE_S := 1.5
# The glow starts this far into the grace, so a brush of the floor shows nothing.
const GLOW_FROM_S := 0.6
const BURN_HP_PER_S := 4.0
const TICK_S := 0.5
const FLOOR_HP := 1.0
const SOURCE := "cinder_floor"
const GLOW_FACT := "cinder_glow"
const BURN_FACT := "cinder_burn"
const COOL_FACT := "cinder_cooled"

var dwell := 0.0
var burned := 0.0
var _pulse := 0.0
var _glowing := false


func reset() -> void:
	dwell = 0.0
	_pulse = 0.0
	_glowing = false


# A hit landed on an enemy: the ball is fighting on the floor, not idling on it.
func struck() -> void:
	dwell = 0.0
	_pulse = 0.0


func step(delta: float, on_cinder: bool, hp: float) -> Dictionary:
	var out := {"glow": 0.0, "damage": 0.0, "fact": ""}
	if not on_cinder:
		if _glowing:
			out["fact"] = COOL_FACT
		reset()
		return out
	dwell += delta
	out["glow"] = clampf((dwell - GLOW_FROM_S) / maxf(GRACE_S - GLOW_FROM_S, 0.001), 0.0, 1.0)
	if dwell >= GLOW_FROM_S and not _glowing:
		_glowing = true
		out["fact"] = GLOW_FACT
	if dwell < GRACE_S:
		return out
	if _pulse == 0.0:
		out["fact"] = BURN_FACT
	_pulse += delta
	if _pulse >= TICK_S:
		_pulse -= TICK_S
		var amount := minf(BURN_HP_PER_S * TICK_S, maxf(0.0, hp - FLOOR_HP))
		out["damage"] = amount
		burned += amount
	return out

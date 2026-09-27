extends RefCounted

const Pattern := preload("res://src/combat/pattern.gd")
const Palette := preload("res://src/core/palette.gd")

# The class kits as data. Weapon ids come from class_def.gd; `pylon_turret` is the
# engineer's weapon while mounted. Each weapon is a base Pattern plus the strike kind
# its hits publish (enemy_struck) and the colour its bolts draw in.

const RAPID_LASER := "rapid_laser"
const ARC_CASTER := "arc_caster"
const PYLON_TURRET := "pylon_turret"
const OVERDRIVE := "overdrive"

const ALL := [RAPID_LASER, ARC_CASTER, PYLON_TURRET]

# Runner-gunner: tight, fast and laser-true. Small damage, high rate, no spread, a thin
# hit radius: it rewards aim and never stops firing.
# Arc caster: slower electromagnetic bolts with a fat field and a one-jump chain, so
# the engineer lands hits on the move without a magnet that would lie about the aim.
# Pylon turret: the planted form of the caster, faster and chaining further.
const BASE := {
	RAPID_LASER: {"damage": 7.0, "rate": 12.0, "range_m": 85.0, "speed": 190.0, "bolt_radius": 0.25,
		"knock": 4.0},
	ARC_CASTER: {"damage": 12.0, "rate": 5.0, "range_m": 70.0, "speed": 110.0, "bolt_radius": 0.55,
		"knock": 7.0, "chain_jumps": 1, "chain_range": 9.0, "chain_falloff": 0.7},
	PYLON_TURRET: {"damage": 11.0, "rate": 9.0, "range_m": 95.0, "speed": 150.0, "bolt_radius": 0.5,
		"knock": 9.0, "chain_jumps": 2, "chain_range": 16.0, "chain_falloff": 0.75},
}

const STRIKE_KIND := {RAPID_LASER: "runner", ARC_CASTER: "arc", PYLON_TURRET: "turret"}

# Overdrive (runner special): a ring blast that throws everything off you, then a few
# seconds of faster fire. Surrounded is when a runner most needs to keep rolling.
const OVERDRIVE_RADIUS := 12.0
const OVERDRIVE_DAMAGE := 30.0
const OVERDRIVE_KNOCK := 34.0
const OVERDRIVE_SECONDS := 3.0
const OVERDRIVE_RATE := 1.6
const OVERDRIVE_COOLDOWN := 6.0

# The pylon discharge (engineer special, and the turret's opening burst on a plant):
# power comes from speed. Planting banks your arrival speed; F discharges on the move
# from your current speed, or from the bank while mounted.
const DISCHARGE_COOLDOWN := 5.0
const BURST_MIN_TARGETS := 2
const BURST_MAX_TARGETS := 8
const BURST_SPEED_PER_TARGET := 5.0
const BURST_RADIUS := 12.0
const BURST_RADIUS_PER_SPEED := 0.45
const BURST_MAX_RADIUS := 30.0
const BURST_DAMAGE := 14.0
const BURST_DAMAGE_PER_SPEED := 1.4
const BURST_KNOCK := 16.0


static func base(weapon_id: String) -> Resource:
	return Pattern.make(BASE.get(weapon_id, BASE[RAPID_LASER]))


static func color(weapon_id: String) -> Color:
	if weapon_id == RAPID_LASER:
		return Palette.AMBER
	if weapon_id == PYLON_TURRET:
		return Palette.ARC.lightened(0.25)
	return Palette.ARC


static func strike_kind(weapon_id: String) -> String:
	return STRIKE_KIND.get(weapon_id, "runner")


# The discharge a given speed buys: how many enemies it arcs into, how far it reaches
# and how hard each arc hits. `scale` is the pattern's burst_scale (the capacitor part)
# and `damage_mult` the weapon's damage tiers.
static func burst(speed: float, scale := 1.0, damage_mult := 1.0) -> Dictionary:
	var charged := maxf(0.0, speed) * scale
	return {
		"speed": speed,
		"targets": clampi(BURST_MIN_TARGETS + int(charged / BURST_SPEED_PER_TARGET), BURST_MIN_TARGETS, BURST_MAX_TARGETS),
		"radius": minf(BURST_RADIUS + charged * BURST_RADIUS_PER_SPEED, BURST_MAX_RADIUS),
		"damage": (BURST_DAMAGE + charged * BURST_DAMAGE_PER_SPEED) * damage_mult,
	}

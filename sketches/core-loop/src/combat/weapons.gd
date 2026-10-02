extends RefCounted

const Pattern := preload("res://src/combat/pattern.gd")
const Palette := preload("res://src/core/palette.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# The class kits as data. Weapon ids come from class_def.gd; `pylon_turret` is the
# engineer's weapon while mounted. Each weapon is a base Pattern plus the strike kind
# its hits publish (enemy_struck) and the colour its bolts draw in.

const RAPID_LASER := "rapid_laser"
const ARC_CASTER := "arc_caster"
const PYLON_TURRET := "pylon_turret"
const STICKY_CHARGE := "sticky_charge"

const ALL := [RAPID_LASER, ARC_CASTER, PYLON_TURRET, STICKY_CHARGE]

# Runner-gunner: tight, fast and laser-true. Small damage, high rate, no spread, a thin
# hit radius: it rewards aim and never stops firing.
# Arc caster: slower electromagnetic bolts with a fat field and a one-jump chain, so
# the engineer lands hits on the move without a magnet that would lie about the aim.
# Pylon turret: the planted form of the caster, faster and chaining further.
# knock is the shove a hit gives, in m/s before the enemy's weight divides it: a gun
# nudges (3 to 6), a bomb or blast throws (24 to 34, with BURST_, LINE_ and
# OVERDRIVE_KNOCK), and a ram pushes as hard (Augments.RAM_KNOCK). The numbers live in
# EventKinds.IMPACT; these read them.
const BASE := {
	RAPID_LASER: {"damage": 7.0, "rate": 12.0, "range_m": 85.0, "speed": 190.0, "bolt_radius": 0.25,
		"knock": EventKinds.IMPACT["runner"]["knock"]},
	ARC_CASTER: {"damage": 12.0, "rate": 5.0, "range_m": 70.0, "speed": 110.0, "bolt_radius": 0.55,
		"knock": EventKinds.IMPACT["arc"]["knock"], "chain_jumps": 1, "chain_range": 9.0, "chain_falloff": 0.7},
	PYLON_TURRET: {"damage": 11.0, "rate": 9.0, "range_m": 95.0, "speed": 150.0, "bolt_radius": 0.5,
		"knock": EventKinds.IMPACT["turret"]["knock"], "chain_jumps": 2, "chain_range": 16.0, "chain_falloff": 0.75},
	# Kest's sticky charge: damage is the charge's, bolt_radius its blast, range_m the
	# longest throw; the throw cadence is the weapon slot's cooldown, not the rate.
	STICKY_CHARGE: {"damage": 16.0, "rate": 1.0, "range_m": 30.0, "speed": 22.0, "bolt_radius": 3.0,
		"knock": EventKinds.IMPACT["sticky"]["knock"]},
}

const STRIKE_KIND := {RAPID_LASER: "runner", ARC_CASTER: "arc", PYLON_TURRET: "turret", STICKY_CHARGE: "sticky"}

# Overdrive (runner special): a ring blast that throws everything off you, then a few
# seconds of faster fire. Surrounded is when a runner most needs to keep rolling.
const OVERDRIVE_RADIUS := 12.0
const OVERDRIVE_DAMAGE := 30.0
const OVERDRIVE_KNOCK := EventKinds.IMPACT["overdrive"]["knock"]
const OVERDRIVE_SECONDS := 3.0
const OVERDRIVE_RATE := 1.6
# A tap is the blast above; a full gauge scales radius, damage and knock by this.
const OVERDRIVE_FULL := 1.5

# The pylon discharge (engineer special, and the turret's opening burst on a plant):
# power comes from speed. Planting banks your arrival speed; F discharges on the move
# from your current speed, or from the bank while mounted.
# The F gauge feeds burst() as if you were rolling this fast at a full charge; a tap is a
# standing discharge. While mounted the bank counts if it is bigger.
const DISCHARGE_FULL_SPEED := 40.0
const BURST_MIN_TARGETS := 2
const BURST_MAX_TARGETS := 8
const BURST_SPEED_PER_TARGET := 5.0
const BURST_RADIUS := 12.0
const BURST_RADIUS_PER_SPEED := 0.45
const BURST_MAX_RADIUS := 30.0
const BURST_DAMAGE := 14.0
const BURST_DAMAGE_PER_SPEED := 1.4
const BURST_KNOCK := EventKinds.IMPACT["burst"]["knock"]
# Kest's detonation line: a bomb's shove along the line, radial from each charge.
const LINE_KNOCK := EventKinds.IMPACT["line"]["knock"]


static func base(weapon_id: String) -> Resource:
	return Pattern.make(BASE.get(weapon_id, BASE[RAPID_LASER]))


static func color(weapon_id: String) -> Color:
	if weapon_id == STICKY_CHARGE:
		return ClassDef.KEST_COLOR
	if weapon_id == RAPID_LASER:
		return ClassDef.RIVET_COLOR
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


# Kest's detonation line: its length grows with the gauge, and every sticky charge
# caught in it goes off early and adds LINE_PER_CHARGE to the line, up to LINE_MAX_CAUGHT.
const LINE_MIN := 6.0
const LINE_MAX := 14.0
const LINE_WIDTH := 2.5
const LINE_DAMAGE_MIN := 20.0
const LINE_DAMAGE_MAX := 30.0
const LINE_PER_CHARGE := 0.25
const LINE_MAX_CAUGHT := 3

# Sticky charges: the throw's reach grows with the gauge; a fuse or a touch sets one off.
const STICKY_THROW_MIN := 10.0
const STICKY_FUSE := 1.2
const STICKY_MAX_LIVE := 3
# Kest's demo slam lays a spread of small charges on landing.
const MINI_COUNT := 3
const MINI_DAMAGE := 5.3
const MINI_RADIUS := 1.5
const MINI_ARM := 0.3
const MINI_FUSE := 1.0
const MINI_SPREAD := 3.5

# The rocket jump off your own blast, opt-in by holding Space: faster the closer you are.
const ROCKET_REACH := 4.5
const ROCKET_MIN := 22.0
const ROCKET_MAX := 30.0
const ROCKET_COOLDOWN := 1.0

# Kest's dust cloak: enemies see this share of their usual range; the first shot out of
# it deals CLOAK_CRIT times its damage and ends it.
const CLOAK_SECONDS := 1.5
const CLOAK_SIGHT := 0.6
const CLOAK_CRIT := 2.0

# Pins: a knocked enemy flying faster than PIN_MIN_SPEED that reaches another within
# PIN_RADIUS (hull to hull) hits it once per knock, and passes on PIN_CARRY of its speed.
const PIN_MIN_SPEED := 6.0
const PIN_RADIUS := 1.2
const PIN_BASE := 8.0
const PIN_PER_SPEED := 0.5
const PIN_CAP := 40.0
const PIN_CARRY := 0.6

# Rivet's sprint: contact punch is this much higher (the crush bar 20% lower).
const SPRINT_PUNCH := 1.25

# Upgrade-tree variants (upgrade_tree.gd). Point Blank: the blast at this share of its
# radius for this much damage. Sticky Rain: each throw's damage and radius shares, split
# across its charges. Time Bomb: a charge grows this much per second waited, up to the
# cap. Marked: marked targets take this much more from charges. Dive Bomber: slam charges
# grow with the landing speed past DIVE_FALL (m/s), up to DIVE_MAX. Phantom's cut width, Smoke Screen's
# cloud, Nightfall's hold cap, the Sentry Post's reach and fire-rate share, and the
# boost cap when boosts stack.
const POINT_BLANK_RADIUS := 0.5
const POINT_BLANK_DAMAGE := 2.0
const RAIN_DAMAGE := 1.5
const RAIN_RADIUS := 0.7
const GROW_PER_SECOND := 0.35
const GROW_MAX_SECONDS := 4.0
const MARK_BONUS := 1.5
const DIVE_FALL := 12.0
const DIVE_MAX := 2.0
const BLINK_CUT_WIDTH := 3.0
const SMOKE_CLOUD_RADIUS := 4.0
const CLOAK_HOLD_MAX := 6.0
const SENTRY_REACH := 30.0
const SENTRY_RATE := 0.6
const OVERDRIVE_MAX := 6.0

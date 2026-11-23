extends RefCounted

const Pattern := preload("res://src/combat/pattern.gd")
const Palette := preload("res://src/core/palette.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Attachments := preload("res://src/build/attachments.gd")

# The class kits as data. Weapon ids come from class_def.gd; `pylon_turret` is the
# engineer's weapon while mounted. Each weapon is a base Pattern plus the strike kind
# its hits publish (enemy_struck) and the colour its bolts draw in.

const RAPID_LASER := "rapid_laser"
const ARC_CASTER := "arc_caster"
const PYLON_TURRET := "pylon_turret"
const STICKY_CHARGE := "sticky_charge"
const CLAW_SWEEP := "claw_sweep"
const LEDGER_READER := "ledger_reader"
const CANNON_LANE := "cannon_lane"

const ALL := [RAPID_LASER, ARC_CASTER, PYLON_TURRET, STICKY_CHARGE, CLAW_SWEEP, LEDGER_READER, CANNON_LANE]

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
	RAPID_LASER: {"damage": 12.0, "rate": 12.0, "range_m": 85.0, "speed": 190.0, "bolt_radius": 0.25,
		"knock": EventKinds.IMPACT["runner"]["knock"],
		"trigger": Pattern.TRIGGER_PRESS, "floor_s": 0.20, "mag": 6, "reload_s": 0.95,
		"window_s": Vector2(0.38, 0.54), "window_mult": 1.2},
	ARC_CASTER: {"damage": 8.0, "rate": 5.0, "range_m": 70.0, "speed": 110.0, "bolt_radius": 0.55,
		"knock": EventKinds.IMPACT["arc"]["knock"], "chain_jumps": 1, "chain_range": 9.0, "chain_falloff": 0.7,
		"trigger": Pattern.TRIGGER_TAP_CHARGE, "floor_s": 0.30, "tap_threshold_s": 0.16,
		"charge_s": 0.64, "charge_min": 0.25, "recover_s": 0.12},
	PYLON_TURRET: {"damage": 9.0, "rate": 9.0, "range_m": 95.0, "speed": 150.0, "bolt_radius": 0.5,
		"knock": EventKinds.IMPACT["turret"]["knock"], "chain_jumps": 2, "chain_range": 16.0, "chain_falloff": 0.75,
		"trigger": Pattern.TRIGGER_TAP_CHARGE, "floor_s": 0.30, "tap_threshold_s": 0.16,
		"charge_s": 0.64, "charge_min": 0.25, "recover_s": 0.12},
	# Kest's sticky charge: damage is the charge's, bolt_radius its blast, range_m the
	# longest throw; the throw cadence is the weapon slot's cooldown, not the rate.
	STICKY_CHARGE: {"damage": 16.0, "rate": 1.0, "range_m": 30.0, "speed": 22.0, "bolt_radius": 3.0,
		"knock": EventKinds.IMPACT["sticky"]["knock"]},
	# Tarn's claw sweep: short, heavy and slow, the highest per-hit weapon. Plating
	# tuning for Tarn belongs to the Tarn verification unit.
	CLAW_SWEEP: {"damage": 32.0, "rate": 2.0, "range_m": 5.0, "speed": 140.0, "bolt_radius": 1.1,
		"knock": EventKinds.IMPACT["claw"]["knock"]},
	# Tally's ledger reader: the row gives _patterns, pattern() and _damage_mod a weapon to
	# read. Combat runs her cards instead and never calls _fire for it.
	LEDGER_READER: {"damage": 10.0, "rate": 2.5, "range_m": 30.0, "speed": 140.0, "bolt_radius": 0.5,
		"knock": EventKinds.IMPACT["ledger"]["knock"]},
	# The remembered cannon's lane: the row gives _rate, pattern ops and a volley proc a
	# pattern to read. Combat commits a Mind lane for it instead of firing bolts.
	CANNON_LANE: {"damage": LANE_DAMAGE, "rate": 1.0, "range_m": CANNON_LANE_REACH, "speed": 120.0, "bolt_radius": 0.6,
		"knock": EventKinds.IMPACT["cannon"]["knock"]},
}

# PILOT-CADENCE.md section 4: the hold_auto rows. Setting a BASE row's `trigger` to hold_auto
# returns that weapon to hold-to-fire with no code change (resolve_row).
# BASE keeps each row's hold_auto `rate`; this table holds only what else differs.
const HOLD_AUTO := {
	RAPID_LASER: {"damage": 7.0},
	ARC_CASTER: {"damage": 12.0},
	PYLON_TURRET: {"damage": 11.0},
}

# PILOT-CADENCE.md sections 2.5, 3.1 and 3.2 cadence constants.
const PIERCE_CHIP := 0.5
const RIVET_FAN_FLOOR_S := 0.10
const RIVET_FAN_DAMAGE := 0.5
const RIVET_FAN_SPREAD_DEG := 5.0
const CHARGE_BOLT_DAMAGE := {
	ARC_CASTER: 34.0,
	PYLON_TURRET: 36.0,
}
const CHARGE_MOUNT_BOOST_S := 3.0
const CHARGE_FAST_RATE := 1.5
const CHARGE_BLAZING_RATE := 2.0

const STRIKE_KIND := {RAPID_LASER: "runner", ARC_CASTER: "arc", PYLON_TURRET: "turret", STICKY_CHARGE: "sticky",
	CLAW_SWEEP: "claw", LEDGER_READER: "ledger", CANNON_LANE: "cannon"}

# Overdrive (runner special): a ring blast that throws everything off you, then a few
# seconds of faster fire. Surrounded is when a runner most needs to keep rolling.
const OVERDRIVE_RADIUS := 12.0
const OVERDRIVE_DAMAGE := 30.0
const OVERDRIVE_KNOCK := EventKinds.IMPACT["overdrive"]["knock"]
const OVERDRIVE_SECONDS := 3.0
const OVERDRIVE_RATE := 1.6
# A tap is the blast above; a full gauge scales radius, damage and knock by this.
const OVERDRIVE_FULL := 1.5

# --- PC-RIVET constants (design-v3/pilots/rivet.md sections 2.3 and 3; all start values) ---
# Line Drive. The punch: a copper pulse runs down the cable at LINE_PULSE_SPEED and strikes the
# latched machine as a ram at max(LINE_PUNCH_FLOOR, LINE_PUNCH_SHARE x the ball's planar speed),
# throwing it LINE_PUNCH_KNOCK along the cable. The haul: the winch drags the ball to the anchor
# at the ball's speed or LINE_HAUL_SPEED, whichever is higher, and crowd control slides off for
# the haul plus LINE_HAUL_GRACE. A closed Warden guard takes at most LINE_WARDEN_POSTURE.
const LINE_PULSE_SPEED := 150.0
const LINE_PUNCH_SHARE := 0.6
const LINE_PUNCH_FLOOR := 8.0
const LINE_PUNCH_KNOCK := OVERDRIVE_KNOCK
const LINE_HAUL_SPEED := 24.0
const LINE_HAUL_GRACE := 0.3
const LINE_WARDEN_POSTURE := 12.0
# Foundry Cutter: one beam on the reticle ray, CUTTER_LENGTH long, CUTTER_WIDTH by heft class
# I to V, cutting CUTTER_PIERCE machines a beat for CUTTER_DAMAGE x the heft multiplier, clamped
# CUTTER_CLAMP_DEG off the travel heading. The middle beat is Full Cut: FULL_CUT_WIDTH wide,
# FULL_CUT_DEG swept, FULL_CUT_REACH out, FULL_CUT_DAMAGE once per machine, no pierce cap.
const CUTTER_LENGTH := 40.0
const CUTTER_WIDTH := [0.6, 0.7, 0.8, 0.9, 1.0]
const CUTTER_PIERCE := 3
const CUTTER_DAMAGE := 12.0
const CUTTER_CLAMP_DEG := 60.0
const FULL_CUT_WIDTH := 2.5
const FULL_CUT_DEG := 90.0
const FULL_CUT_REACH := 30.0
const FULL_CUT_DAMAGE := 18.0
const FULL_CUT_SCAR := 1.5
# The Breach Skid landing: a forward cone BREACH_REACH_SCALE x the class landing radius, plus
# everything within BREACH_INNER of the ball; it hands back BREACH_SPRINT sprint charges.
const BREACH_REACH_SCALE := 1.5
const BREACH_INNER := 2.5
const BREACH_SPRINT := 1
# Prism Cutter: PRISM_BEAMS beams PRISM_SPREAD_DEG apart, each PRISM_LENGTH long, PRISM_WIDTH
# wide at class I plus PRISM_WIDTH_STEP a class, PRISM_PIERCE machines a beat for PRISM_DAMAGE.
# Its peak, Focus: one PRISM_FOCUS_WIDTH beam, CUTTER_LENGTH long, PRISM_FOCUS_DAMAGE to up to
# PRISM_FOCUS_PIERCE machines.
const PRISM_BEAMS := 3
const PRISM_SPREAD_DEG := 15.0
const PRISM_LENGTH := 30.0
const PRISM_WIDTH := 0.5
const PRISM_WIDTH_STEP := 0.1
const PRISM_PIERCE := 2
const PRISM_DAMAGE := 8.0
const PRISM_FOCUS_WIDTH := 1.5
const PRISM_FOCUS_DAMAGE := 30.0
const PRISM_FOCUS_PIERCE := 6
# Juggernaut Drive: the ball rams every machine whose hull passes within DRIVE_REACH of its
# centre once per flight for DRIVE_DAMAGE x heft x DRIVE_RAM_MULT, knock DRIVE_KNOCK half outward
# and half forward. Each beat a bow wave throws machines DRIVE_WAVE_NEAR to DRIVE_WAVE_FAR beside
# the path ahead outward at DRIVE_WAVE_KNOCK x falloff, no damage. Its peak, Shoulder: the
# corridor is DRIVE_SHOULDER_REACH for one beat and rams deal DRIVE_SHOULDER_MULT. Crowd control
# slides off for DRIVE_IMMUNE s after the recovery.
const DRIVE_REACH := 3.0
const DRIVE_DAMAGE := 30.0
const DRIVE_RAM_MULT := 1.25
const DRIVE_KNOCK := OVERDRIVE_KNOCK
const DRIVE_WAVE_NEAR := 3.0
const DRIVE_WAVE_FAR := 8.0
const DRIVE_WAVE_AHEAD := 10.0
const DRIVE_WAVE_KNOCK := 20.0
const DRIVE_SHOULDER_REACH := 5.0
const DRIVE_SHOULDER_MULT := 2.0
const DRIVE_IMMUNE := 2.0
# --- end PC-RIVET constants ---

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
const BURST_DAMAGE_PER_SPEED := 0.8
const BURST_KNOCK := EventKinds.IMPACT["burst"]["knock"]
# Kest's detonation line: a bomb's shove along the line, radial from each charge.
const LINE_KNOCK := EventKinds.IMPACT["line"]["knock"]
# Tarn's clamp: the gauge scales the ring, its damage and how long the catch holds;
# every enemy in the ring is dragged in and takes CLAMP_BONUS from claw sweeps.
const CLAMP_RADIUS_MIN := 4.0
const CLAMP_RADIUS_MAX := 7.0
const CLAMP_DAMAGE_MIN := 14.0
const CLAMP_DAMAGE_MAX := 24.0
const CLAMP_SECONDS_MIN := 1.5
const CLAMP_SECONDS_MAX := 3.0
const CLAMP_BONUS := 1.5
const CLAMP_KNOCK := EventKinds.IMPACT["clamp"]["knock"]
# Tally's program cards: a slot-1 press runs Balance Due at the aim point within CARD_REACH and
# costs one pressure; CARD_RECOVERY is the pause before the next run. CARDS keeps each card's icon.
const CARDS := {"gather_plate": {"icon": "ab_tally_gather"}, "link_clips": {"icon": "ab_tally_link"},
	"balance_due": {"icon": "ab_tally_balance"}}
const CARD_REACH := 30.0
const CARD_RECOVERY := 0.4
# Gather: the plate pulls ordinary enemies within the radius toward it every tick, harder
# the farther out they stand; it does no damage.
const GATHER_RADIUS := 4.0
const GATHER_SECONDS := 4.0
const GATHER_TICK := 0.2
const GATHER_KNOCK := 6.0
# The ledger clip on a body: the latched enemy and its nearest neighbours within the reach ring;
# the next direct hit on a clip arcs once to each other clip at a share of its force, never under
# the floor, times the chain multiplier stored at the cast.
const LINK_NEIGHBOUR_REACH := 9.0
const LINK_NEIGHBOURS := 2
const LINK_SECONDS := 4.0
const LINK_ARC_SHARE := 0.6
const LINK_ARC_MIN := 8.0
# Balance Due: one capacitor ring at the aim point; damage grows with planar speed at the press.
const BALANCE_RADIUS := 3.0
const BALANCE_BASE := 10.0
const BALANCE_PER_SPEED := 1.2
const BALANCE_MAX := 56.0
# Pressure: rolling at cruise or faster refills one charge per PRESSURE_ROLL_S seconds.
const PRESSURE_ROLL_S := 2.0
# The ledger clip (pilots/tally.md sections 2 and 10): each clip pays CLIP_PRESSURE, never past
# the cap. On a world latch a clip post clips the first CLIP_POST_MAX enemies within
# CLIP_POST_RADIUS for CLIP_POST_SECONDS. A Flywheel Surge pays SURGE_PRESSURE (A2-CRITIC).
const CLIP_PRESSURE := 1
const CLIP_POST_RADIUS := 4.0
const CLIP_POST_SECONDS := 4.0
const CLIP_POST_MAX := 3
const SURGE_PRESSURE := 1
# Plate Return: each clip outside the landing radius takes SETTLE_SHARE of the strike (the
# ult_settle knob's default); a ride clips at most CLIP_CAP by heft class I to V. Her plate is B
# when it lies within rope range and ULT_PLATE_AIM_DEG of the aim.
const SETTLE_SHARE := 0.4
const CLIP_CAP := [6, 7, 8, 9, 10]
const ULT_PLATE_AIM_DEG := 30.0
# Audit Trail: each beat stamps a ring on ground within AUDIT_GROUND_REACH below the ball.
const AUDIT_STAMP_RADIUS := 4.0
const AUDIT_STAMP_KNOCK := 10.0
const AUDIT_GROUND_REACH := 12.0
# Flywheel Throw: each beat throws a small plate at the densest knot within FLY_KNOT_SEARCH of the
# ground track (pulls for FLY_PLATE_SECONDS, clips FLY_KNOT_CLIPS); the landing grows by
# FLY_LANDING_BONUS, and FLY_PULL_LEAD s before the strike everything within the radius plus
# FLY_PULL is pulled FLY_PULL inward.
const FLY_KNOT_SEARCH := 15.0
const FLY_PLATE_SECONDS := 1.5
const FLY_KNOT_CLIPS := 3
const FLY_LANDING_BONUS := 2.0
const FLY_PULL := 4.0
const FLY_PULL_LEAD := 0.2
const LEDGER_KNOCK := EventKinds.IMPACT["ledger"]["knock"]
# The remembered cannon's numbers: reach, damage and cooldowns only. Every warn, live,
# half width, band and span comes from mind_attacks.gd, never from here.
const CANNON_LANE_REACH := 26.0
const LANE_DAMAGE := 30.0  # 38 in the brief; under the claw sweep's 32 (tarn_kit_test)
const RECOIL_REACH := 16.0
const RECOIL_DAMAGE := 24.0
const PLATE_DAMAGE_MIN := 18.0
const PLATE_DAMAGE_MAX := 34.0
const RUSH_REACH := 14.0
const RUSH_DAMAGE := 30.0
const CANNON_KNOCK := EventKinds.IMPACT["cannon"]["knock"]
const LANE_CHARGE_DAMAGE := 28.0
const LANE_CHARGE_PAST := 12.0
const LANE_CHARGE_WARN := 0.1
const LANE_CHARGE_LIVE := 0.3
const ZONE_DAMAGE := 12.0
const ZONE_REACH := 26.0
const CALL_CAP := 12
const VOID_DROP := 12.0
const APEX_CAP := 20.0
const CREEP_AHEAD_BEATS := 2
const MORTAR_BEATS := 6
const MORTAR_REACH := 0.5
const RECITAL_SECONDS := 6.0


static func base(weapon_id: String, loadout := {}) -> Resource:
	return Pattern.make(_attached(weapon_id, loadout, {}))


# PILOT-CADENCE.md section 4: the legacy hold_auto Pattern for `weapon_id`, the BASE row with
# its trigger field alone set to hold_auto.
static func hold_auto_base(weapon_id: String) -> Resource:
	var row: Dictionary = BASE.get(weapon_id, BASE[RAPID_LASER]).duplicate()
	row["trigger"] = Pattern.TRIGGER_HOLD_AUTO
	return Pattern.make(resolve_row(weapon_id, row))


# A BASE row as its trigger mode fires it. A row whose trigger is hold_auto takes its
# HOLD_AUTO damage, so setting `trigger` alone turns a cadence weapon back into today's gun
# (PILOT-CADENCE.md section 4).
static func resolve_row(weapon_id: String, row: Dictionary) -> Dictionary:
	if String(row.get("trigger", Pattern.TRIGGER_HOLD_AUTO)) != Pattern.TRIGGER_HOLD_AUTO or not HOLD_AUTO.has(weapon_id):
		return row
	var out := row.duplicate()
	for key in HOLD_AUTO[weapon_id]:
		out[key] = HOLD_AUTO[weapon_id][key]
	return out


# The damage `weapon_id`'s base pattern fires, after its trigger mode (resolve_row).
static func base_damage(weapon_id: String) -> float:
	return float(resolve_row(weapon_id, BASE.get(weapon_id, BASE[RAPID_LASER]))["damage"])


# Multiplier from spark base damage to full charged-bolt damage for tap_charge weapons.
static func charge_bolt_mult(weapon_id: String) -> float:
	if not CHARGE_BOLT_DAMAGE.has(weapon_id) or not BASE.has(weapon_id):
		return 1.0
	var spark: float = float(BASE[weapon_id].get("damage", 0.0))
	return (float(CHARGE_BOLT_DAMAGE[weapon_id]) / spark) if spark > 0.0 else 1.0


# SQ11: the top tier's second fire mode over the attached primary; null below the top tier
# or for a loadout that belongs to another weapon.
static func second_mode(weapon_id: String, loadout: Dictionary) -> Resource:
	if String(loadout.get("weapon", "")) != weapon_id:
		return null
	var mode: Dictionary = Attachments.second_mode(loadout)
	if mode.is_empty():
		return null
	return Pattern.make(_attached(weapon_id, loadout, mode["mods"]))


# The BASE row with the loadout's attachment mods (attachments.gd), then `extra`, multiplied in.
# A loadout for another weapon, or none, leaves the row untouched.
static func _attached(weapon_id: String, loadout: Dictionary, extra: Dictionary) -> Dictionary:
	var row: Dictionary = resolve_row(weapon_id, BASE.get(weapon_id, BASE[RAPID_LASER]))
	if String(loadout.get("weapon", "")) != weapon_id:
		return row
	var scales: Dictionary = Attachments.mods(loadout)
	if scales.is_empty() and extra.is_empty():
		return row
	var out := row.duplicate()
	for table in [scales, extra]:
		for field in table:
			out[field] = float(out.get(field, Pattern.new().get(field))) * float(table[field])
	return out


static func color(weapon_id: String) -> Color:
	if weapon_id == STICKY_CHARGE:
		return ClassDef.KEST_COLOR
	if weapon_id == RAPID_LASER:
		return ClassDef.RIVET_COLOR
	if weapon_id == CLAW_SWEEP:
		return ClassDef.TARN_COLOR
	if weapon_id == LEDGER_READER:
		return ClassDef.TALLY_COLOR
	if weapon_id == CANNON_LANE:
		return ClassDef.CANNON_COLOR
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
# A body a ram, crush or pin kills flies on as a hulk this long at most (KNOCKBACK-FEEL).
const HULK_SECONDS := 0.6

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

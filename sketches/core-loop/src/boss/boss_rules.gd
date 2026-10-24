extends RefCounted

# Admiral Brindle's numbers in one table (DEMO-SPEC Brindle, BOSS-BRINDLE). Every value
# is a starting point for play to tune; tuning edits this file and nothing else. Health
# is fixed: the fight never reads the run's parts or heft (R-10).

# The posture fight (boss_posture.gd) on the hull, overriding the rule's constants as a
# stage row's "posture" dictionary does for a Warden. The slice Warden's numbers: a
# glancing hit fills the bar on the square of its ratio, and only a smash shatters an
# open core on the first contact, so every other opening is crack, then shatter.
const POSTURE := {"curve": 2.0, "ram_shatters": false, "mult_max": 1.5}
# Health is the posture rule's four chunks, one per phase: the first three shattered on
# the hull end Requisition, Furnace and Scuttle, and the fourth is the scooter, taken by
# the catch. hp reads the chunks left, so MAX_HP is the chunk count.
const MAX_HP := 4.0
# A phase ends when its chunk is shattered and its floor has run; a chunk lost earlier holds
# the phase, and the hull takes no posture, until then. The floor is the phase's opening
# flourish (INTRO_SECONDS for the Requisition, the transition beat for the Furnace and the
# Scuttle, fight_phases.gd) or the run tier's row below, whichever is longer.
const PHASE_NAMES := ["Requisition", "Furnace", "Scuttle"]
# The old set-piece floors (DESIGN-NOTES boss note 1): a grown ball routed him but could not
# skip a set piece, so the fight lasted at least 76.5 s. Cut on 24 Oct (Brindle phase floors
# card, option 1: overpowered pays); kept here so either other option is one row.
const SET_PIECE_SECONDS := [28.0, 24.0, 22.0]
# Seconds each phase must run before a broken chunk turns it, per run tier (run_tier.gd BASE 0,
# HARD 1). 0 leaves only the flourish.
# 2026-10-24 fit (Brindle phase floors card, coordinator default): a fit to the Brindle band, not a
# design value. The smallest scale of the SET_PIECE_SECONDS shape that puts the skipper's Brindle row
# median in 90-100 s (BUDGETS.md 1.5-3 min). Fit on the 24 skipper runs at cd0276f6 (flourish only,
# median 58.5 s): a phase lasts max(its natural length, its floor); x1.00 predicts 90.0 s, x1.05 93.7 s.
const PHASE_MIN_BY_TIER := {
	0: [29.5, 25.0, 23.0],
	1: [29.5, 25.0, 23.0],
}
# No attack lands before this, so the entry and the hull readout are free to read.
const INTRO_SECONDS := 3.0

# The Warden grammar. The hull is plated; each weak point opens to one verb.
# 2026-10-15 (BRINDLE-SCUTTLE): 110, down from 120. A ram pilot arrives at stage 2 at
# about heft 2.5, and its ram at the 24 m/s top roll is (14 + 24 * 1.3) * 2.5 = 113: at
# 120 it never met the plating and the posture bar filled at ratio 0.94 squared, slowly
# enough that the Furnace slag drained the ball's heft before the chunk broke (Tally seed
# 3 stalled at the 420 s cap). At 110 that ram meets the plating; a cruise ram or a bare
# ball does not (tests/brindle_heavy_ram_test.gd).
const HULL_PLATING := 110.0
const CLASH_PUNCH := 150.0
const CLASH_STUN := 2.0
const WALL_STUN := 3.0
const CAP_MULT := 1.5
const CONTACT_KINDS := ["stomp", "ram", "slam"]
const CAP_KINDS := ["stomp", "slam"]
const CAP_REACH := 2.6
# An open weak point on a piece that cannot die reads this, not 0: every hit lands in
# full, and combat's crush rule (plating 0) never fires on a body that will not die.
const OPEN_PLATING := 0.01
# A contact kind counts on the scooter only with the ball this close to it.
const SCOOTER_TOUCH := 3.5
# A ball whose centre is this far above a piece's centre came down on top of it.
const ABOVE := 1.2

# Phase 1: two magnetic cranes sweep sectors from their pivots.
const CRANE_PERIOD := 3.4
const CRANE_WARN := 1.4
const CRANE_SWEEP := 1.2
const CRANE_SPAN := 1.3962634  # 80 degrees
const CRANE_BAND := Vector2(3.0, 20.0)
const CRANE_REACH := 5.0
# A catch steals this share of mass, clamped, and lifts and tugs the ball; it never pins.
const STEAL_SHARE := 0.2
const STEAL_MIN := 10
const STEAL_MAX := 60
const TUG_LIFT := 7.0
const TUG_PULL := 1.2
# The magnet holds what it stole and drips it as a trail, one pickup per DRIP seconds.
const TRAIL_PICKUPS := 12
const DRIP := 0.2
const TRAIL_ARC := 1.2217305  # 70 degrees
const PICKUP_REACH := 2.6
const PICKUP_LIFE := 12.0
const CIRCLE_SPEED := 4.0
const CIRCLE_RADIUS := 16.0

# Phase 2: slag rings, announced by a klaxon before they fill, and lobber drones.
const SLAG_WARN := 2.5
const SLAG_LIVE := 6.0
const SLAG_GAP := 1.5
const SLAG_DAMAGE := 12.0
const SLAG_REACH := 1.8
const SLAG_BOUNCE_UP := 14.0
const SLAG_BOUNCE_OUT := 10.0
const SLAG_GRACE := 0.8
const QUENCH_SECONDS := 8.0
const VENT_COOLDOWN := 10.0
const VENT_REACH := 2.8
const LOBBER_PERIOD := 7.0
const LOBBER_CAP := 3
# A drone's pad is marked this long before it arrives, off the hull's side away from
# the ball, and it waits while the ball is closer than DRONE_CLEAR (up to DRONE_WAIT).
const DRONE_WARN := 1.0
const DRONE_SIDE := 9.0
const DRONE_CLEAR := 8.0
const DRONE_WAIT := 3.0

# Phase 3: telegraphed charges at the ball. A charge that reaches the rim buries the
# hull's nose in the bank with its centre at CHARGE_STOP_R, which keeps every corner of
# the hull more than a ball's width short of the rim wall, so nothing is ever pinned.
const CHARGE_WARN := 1.4
const CHARGE_SPEED := 24.0
const CHARGE_OVERSHOOT := 10.0
const CHARGE_RECOVER := 1.0
const CHARGE_REST := 1.0
const CHARGE_DAMAGE := 18.0
const CHARGE_SHOVE_SIDE := 12.0
const CHARGE_SHOVE_UP := 9.0
const CHARGE_GRACE := 1.0
const CHARGE_STOP_R := 49.0

# The eject: a 2.5 s arc to the banked ring, then a lap-running chase.
const EJECT_FLIGHT := 2.5
const SCOOTER_SPEED := 11.0
const SCOOTER_SLOW := 0.75
const SCOOTER_SLOW_SECONDS := 1.5
const SCOOTER_MIN_SPEED := 5.0
const SCOOTER_RING := 52.0

const CREST_PART := "admirals_crest"
# Growth continues in the fight: each phase break spills a ring of scrap pickups from
# the ship to roll up, and a lobber drone killed in the arena drops its scrap.
const BREAK_SPILL := 80
const BREAK_PICKUPS := 16
const BREAK_RADIUS := 10.0

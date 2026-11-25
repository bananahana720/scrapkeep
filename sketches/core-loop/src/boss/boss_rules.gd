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
# A phase ends when its chunk is shattered and its set piece has played for its minimum
# time; a chunk lost earlier holds the phase until then. Hits on a held hull bank toward the
# next phase's bar, up to HELD_BANK of it (ruling bs): the bar they fill is kept through the
# hold and the beat that follows, and no stagger starts from it. The Scuttle's hold banks
# nothing, because no bar follows it.
const PHASE_NAMES := ["Requisition", "Furnace", "Scuttle"]
const PHASE_MIN_SECONDS := [28.0, 24.0, 22.0]
const HELD_BANK := 50.0
# The reel (W1-61, ruling ed / W1-139d): for the rest of a held phase Brindle reels. He keeps
# pressing at a slowed cadence (never leaving more than REEL_MAX_GAP seconds between committed
# attacks outside an earned stun, W1-139g), and each ball contact on the hull (stomp, ram or slam),
# at most one per REEL_GAP seconds and REEL_HITS a reel, sheds REEL_SCRAP as REEL_PICKUPS
# pickups REEL_REACH metres from the hull's centre toward the ball (scrap and cogs, as a break
# spill pays) and pays the ultimate meter's "reel" weight. A build that breaks no chunk early
# never sees it; a strong one gets a loot shower under slowed pressure instead of a quiet wait.
# 2026-11-12, tuning taste Andrew can overturn: 12 hits of 10 scrap is 1.5 phase-break spills a reel.
const REEL_GAP := 0.5
const REEL_HITS := 12
const REEL_SCRAP := 10
const REEL_PICKUPS := 2
const REEL_REACH := 9.0
const REEL_SPREAD := 1.6
const REEL_PERIOD_MULT := 1.5
const REEL_MAX_GAP := 5.5
const REEL_SLAG_PERIOD := 3.0
const REEL_SLAG_LIVE := 3.0
const REEL_STEAL_SHARE := 0.45
const REEL_STEAL_MAX := 700
# While reeling, molten slag and desperate Scuttle charges sear away this share of loose scrap
# armour (capped) before the hit lands, so overfed late-World-1 builds cannot shrug off 6+ hits.
# Outside a reel, slow (< cruise) slag and charge hits still sear a smaller share so stopped balls
# cannot face-tank with spilled scrap recovery (W46-S1, ruling cu).
const REEL_SEAR_SHARE := 0.50
const REEL_SEAR_MAX := 700
const SLOW_SEAR_SHARE := 0.40
const SLOW_SEAR_MAX := 500
# Cruising balls (>= cruise) skim molten slag for a light finite graze instead of full melt+sear,
# keeping World 1's speed-is-safety grammar while keeping stop_tax finite across every band pool.
const SKIM_SLAG_MULT := 0.20
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
# Slow (< cruise) non-reel crane catch impact damage (W46-S1, ruling cu): presses stopped balls
# in Phase 1 while cruising balls slip the magnet cleanly.
const CRANE_DAMAGE := 15.0
const TUG_LIFT := 7.0
const TUG_PULL := 1.2
# The magnet holds what it stole and drips it as a trail, one pickup per DRIP seconds.
const TRAIL_PICKUPS := 12
const DRIP := 0.2
const TRAIL_ARC := 1.2217305  # 70 degrees
const PICKUP_REACH := 2.6
const PICKUP_LIFE := 12.0
# An armour hit's spill in the bowl (ruling aw): at most SPILL_PILES shed piles in a fan
# SPILL_AHEAD metres ahead of the ball, SPILL_SIDE either side, the stage spill's middle reach.
const SPILL_PILES := 6
const SPILL_AHEAD := 9.0
const SPILL_SIDE := 4.5
const CIRCLE_SPEED := 4.0
const CIRCLE_RADIUS := 16.0

# Phase 2: slag rings, announced by a klaxon before they fill, and lobber drones.
# FURNACE_CLOSE_BAND covers the floor directly around the parked hull (clear of the hull's
# 4.5 m half-width, meeting Arena.RING_A's 16 m inner edge) so camping under the furnace draws a
# telegraphed vent ring on turn 2 onward and during reels.
const FURNACE_CLOSE_BAND := Vector2(5.5, 16.0)
const SLAG_WARN := 2.5
const SLAG_LIVE := 6.0
const SLAG_GAP := 1.5
const SLAG_DAMAGE := 12.0
const SLAG_REACH := 1.8
const SLAG_BOUNCE_UP := 14.0
const SLAG_BOUNCE_OUT := 10.0
const SLAG_GRACE := 1.2
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
# The hull turns to its lane through the tell instead of taking the heading in one tick. At
# this rate (radians a second) no corner of the 9 m by 14 m hull outruns CHARGE_SPEED: a corner
# is 8.32 m from the centre. The rate is the rule, not a ceiling: the hull turns faster when
# it must to be square in the lane CHARGE_TURN_SETTLE seconds before the lane goes live. The
# most that asks is a full reverse inside the shortest tell: 3.7 rad/s (a 31 m/s corner) in
# Hazard.MIN_WARN, and 7.0 rad/s (a 58 m/s corner) in the hook turn's cued tell, which only a
# ball that stays dead astern through the hook's cue reaches. Under CHARGE_TURN_SNAP radians
# owed the hull takes the heading exactly.
const CHARGE_TURN_RATE := 2.88
const CHARGE_TURN_SETTLE := 0.15
const CHARGE_TURN_SNAP := 0.002
# W1-106 (A11): the hull starts bracing this long before a lead charge stops short of the rim,
# then holds the brace through FightPhases.CUE_LEAD (0.5 s), so the visible brace runs for
# HOOK_BRACE_LEAD + CUE_LEAD = 0.7 s (>= 0.6 s fairness floor) without moving commit time.
const HOOK_BRACE_LEAD := 0.2
# The Scuttle's hint for a build that cannot hit its way in (boss.gd take_hint): the UI row
# it shows and the seconds before it may show again while he has still not been stunned.
const SCUTTLE_HINT := "hint_wall_bait"
const SCUTTLE_HINT_GAP := 20.0

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

extends RefCounted

const Intent := preload("res://src/movement/intent.gd")
const EventDirector := preload("res://src/world/event_director.gd")
const TelegraphScript := preload("res://src/combat/telegraph.gd")
const Palette := preload("res://src/core/palette.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Augments := preload("res://src/movement/augments.gd")
const Grip := preload("res://src/movement/grip.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const SkillBand := preload("res://tools/skill_band.gd")
const BossRules := preload("res://src/boss/boss_rules.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const BotKite := preload("res://tools/bot_kite.gd")
const BotFairness := preload("res://tools/bot_fairness.gd")

# One scripted player for the design feedback loop (DEMO-SPEC, "Bot runs"). It plays a
# real Game through the same doors a person uses: an Intent.Scripted source for the
# keys, camera.look() for the mouse and the flow's own title and class calls. It never
# calls a run mutator, strikes an enemy or moves the ball, so the run log and the codex
# log it leaves behind record play, not a test's shortcuts.
#
# What it may read is what a player could see: the ball, enemies in the `enemy` group,
# the committed telegraphs combat and the boss draw, the gates' offer records, the scrap
# lines, the vault, the stage events' rings and the boss's ship. Those reads go through
# the game's module nodes; the bot is a harness, not a module, so the CONTRACTS rule
# against reaching into another module's folder does not bind it, and it writes nothing
# there.
#
# Policies (DEMO-SPEC, three drivers):
#   skipper        beelines at the Warden from the drop, breaks it, takes the first gate.
#   completionist  rolls the scrap lines (and so the fabricator hoops on them), joins
#                  an armed event, cracks the vault, then breaks the Warden; prefers a
#                  gate that completes a synergy, then the higher tier.
#   random         a seeded wander biased toward the beacon, which commits to the
#                  Warden once close or late; random gate choice.
#   traversal      the Cable Reach's measuring pilot (design-v3/TRAVERSAL.md): it follows a
#                  route from the drop to the beacon and never fights. It is human-shaped:
#                  its whole stick and every press go out TRAVERSE_REACTION seconds after
#                  they were decided, with at most one verb per TRAVERSE_PRESS_GAP seconds.
#   camper         holds the gun on the Warden from CAMP_RANGE and never closes.
#   orbit          the anti-kiting gates' circling arm (bot_kite.gd): circles the nearest live pack unit or Warden
#                  at 14 m at cruise speed, never rams, never dodges.
#   terrain        orbit with the default dodging that breaks the circle onto the nearest line (bot_kite.gd).
# The fight profiles for the Warden bands, by name: brawler is the completionist (it
# fights with every verb it has), skipper is the skipper, camper is the camper.
# All of them fight the boss module's posture target or Brindle's parts (see _boss).
#
# The hands every policy shares, so a measured cost is the game's and not a blind spot:
#   - Telegraph reading. A committed ring or lane (combat's telegraph.gd, the boss's
#     hazards) is seen REACTION seconds after it appears, a human's reaction time. From
#     then on, if the ball is inside it or will be within PREDICT seconds, the bot steers
#     to the nearest safe spot that keeps its line. Rings wider than FIELD_RADIUS (the
#     Warden's magnet reach) are fields, not dodgeable hits, and are ignored.
#   - Class kits. The pylon engineer plants on a steep face within PLANT_SEARCH of a
#     fight (the plant fires the opening burst), turrets for TURRET_SECONDS, then
#     slingshots off toward the target. Both classes fire their special into a crowd or
#     a close fight: overdrive for the runner, the discharge for the engineer.
#   - Weak points when punch is short. With punch below the lock's plating, a caps
#     Warden gets slams beside it (a slam within 2.6 m of a cap meets plating 0) and its
#     own pulse is taken for the height; a magnet Warden gets the gun on its magnet while
#     it tugs. With punch at or above plating the bot rams, as a player would.
#   - Upgrade-tree picks (tree_policy). "" leaves every offer untaken, so older runs
#     keep the untouched kit; "random" takes one of the two offered on each tree_offered
#     from its own seeded stream, so the rest of the bot's choices are unchanged.
#
# A run ends on run_ended ("won" or "lost"), death ("died"), a missing boss module
# ("boss"), a stall ("stalled", "boss_stalled"), or the runner's --until/--stages cap.
# The sweep adds "fight_capped" (the fight ran past
# fight_limit) and "broken" (the Warden broke; it ends the run there).

const POLICIES := ["skipper", "completionist", "random", "camper", "traversal", "orbit", "terrain"]
# How far the bot looks for a crew to break when the Warden's clamp is shut (_gate_foe).
const GATE_HUNT := 140.0
const PROFILES := {"brawler": "completionist", "camper": "camper", "skipper": "skipper"}
const CAMP_RANGE := 30.0
const CAMP_NEAR := 12.0
const TRAVERSE_REACTION := 0.15
const TRAVERSE_PRESS_GAP := 0.4
const TRAVERSE_REACHED := 12.0
# The traversal pilot's optional hands (traversal_line.gd --hands=), off unless named so the bare
# pilot's baselines hold. The harpoon hand swings from an anchor hanging SWING_ABOVE over the ball
# (a lower one only drags it) and within SWING_AHEAD (cosine) of the way to the waypoint, at
# SWING_MIN_SPEED or more (a slow ball has nothing to swing). SWING_YAWS and SWING_PITCHES are the
# bearings it looks along for one. A held line is let go once the anchor is behind the ball, once
# the ball carries less than SWING_CARRY m/s toward the waypoint after SWING_GRACE s, or after
# SWING_HOLD_MAX s; SWING_GAP s pass before the next bite.
const HAND_NAMES := ["harpoon", "glide"]
const SWING_ABOVE := 6.0
const SWING_AHEAD := 0.5
const SWING_MIN_SPEED := 6.0
const SWING_YAWS := [0.0, 0.35, -0.35, 0.7, -0.7]
const SWING_PITCHES := [0.3, 0.55, 0.8]
const SWING_CARRY := 3.0
const SWING_GRACE := 0.8
const SWING_HOLD_MAX := 5.0
const SWING_GAP := 1.5
# A press is in flight for TRAVERSE_REACTION, and the line has not changed yet: no second press
# until the first has landed.
const SWING_SENT := 0.4
# The glide hand holds glide over a thermal column and down a drop of GLIDE_DROP m or more to the
# ground, and lets go once the ball is out of the column and gains under GLIDE_GAIN m/s toward the
# waypoint. Only a kit with the glide augment (Kest's blink) has the hand.
const GLIDE_DROP := 10.0
const GLIDE_GAIN := 2.0
# The glide hand also keeps GLIDE_ABOVE m of height over the waypoint and GLIDE_NEAR m of way to
# it: a glide that ends short of the waypoint beats one that overshoots below it.
const GLIDE_ABOVE := 6.0
const GLIDE_NEAR := 40.0
# Radians of camera yaw per second: a brisk mouse, not a snap.
const TURN_RATE := 5.0
const SENSITIVITY := 0.0022
# A stage longer than this is a stall: the bot could not break the Warden.
const STAGE_LIMIT := 240.0
# The Mind's crown (stage 6) takes the park Mind 127 to 232 s to break (parkwin and parkboss
# receipts, 2026-10-16/17), against the 240 s limit: its fight gets PARK_MIND_LIMIT. Any broken
# Warden gets GATE_LIMIT seconds after the break to reach an exit gate, so a late break is not
# a stall (one run broke at 232.6 s and stalled in "gates" 7 s later).
const PARK_MIND_LIMIT := 480.0
# The roll to the gates is a leg of its own: completionist seed 35118 (Pylon) broke the stage-6
# Warden at 230.7 s and was cut off at 240 s on its way to gate 1. A gate the bot cannot reach
# still stalls, GATE_LIMIT after the break, with stall_state "gates". 90 s, not PR #34's 60 s:
# STAGE6's measured exits took up to 26 s plus the exit-bank run-up (merge, 2026-10-17).
const GATE_LIMIT := 90.0
const BOSS_LIMIT := 420.0
const STUCK_SPEED := 2.5
const STUCK_SECONDS := 2.0
const DETOUR_SECONDS := 1.4
# Walls on the way: probe this far along the heading and these turns off it.
const WALL_REACH := 4.0
const WALL_TILT := 0.5
const WALL_TURNS := [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5]
# Once a wall turns the ball to one side it keeps that side until the straight way clears: picking
# the first clear turn every tick flipped between +1.5 and -1.5 where the 1.0 ray grazed a long wall
# square to the goal, and the ball dithered on the spot (random seed 2867 on the eye_fin_east foot
# at (98, 103, 137) on the park table, 164 s to the stall cap). The side belongs to the bearing it
# was taken on: a heading more than WALL_SIDE_KEEP_DEG off it, or a stuck detour, drops it.
const WALL_SIDE_KEEP_DEG := 45.0
const BOOST_GAP := 1.6
const CARD_PRESS_GAP := 0.5
# Shift is the pilot's go verb, pressed as the keyboard presses it: Sable boosts on the press,
# Rivet sprints for as long as it is held, Kest blinks on the press.
const SHIFT_HOLD := 1.2
# The ram lap: charge until this close, then run up this far and charge again.
const CHARGE_CLOSE := 3.8
# The harpoon hand is the bowl-floor camper's: grounded on the floor (its radius, features.gd) and
# not within DROP_MEMORY of having been beyond LINE_REACH of the fight target.
const HARPOON_FLOOR := 30.0
const LINE_REACH := 50.0
const DROP_MEMORY := 6.0
# A player's re-press on a body the ball already sits inside (see _pass_bite_blocked).
const PASS_BITE_GAP_S := 0.25
# The latch arm on a harpoon-anchor Warden (_anchor_fight): a bite within LATCH_REACH of the body
# (inside the 45 m rope), the body reads hung when it stands more than HUNG_ABOVE over the ground
# under it and rising or falling past ANCHOR_MOVING m/s; from the ground the ball waits for a hung
# body at LATCH_STANDOFF times its height out (the camera looks up at most about 30 degrees). The drop
# hauls from DROP_ABOVE over the open point; a line staggered below it waits DROP_WAIT for the
# brake-drop to carry the ball over, then hauls from where it hangs. The bot rides the drop on its
# line rather than releasing first (wardens/swarm.md section 4: a latched ball rides the brake-drop
# onto the queen), and any height over the open point counts as above it (DROP_ABOVE 0).
const LATCH_REACH := 40.0
const HUNG_ABOVE := 5.0
const ANCHOR_MOVING := 2.0
const LATCH_STANDOFF := 1.6
const LATCH_STANDOFF_MAX := 30.0
const DROP_ABOVE := 0.0
const DROP_WAIT := 0.6
# Off the line in a stagger the ball jumps for the drop within DROP_JUMP_REACH of the open point.
const DROP_JUMP_REACH := 8.0
# A jump and the air jump lift the ball about 6 m (measured on the park table, seed 1): an open
# point higher than DROP_REACH_UP over the ball cannot be jumped over, so the ball bites from below.
const DROP_REACH_UP := 6.0
# With the posture bar at LINE_FINISH or more the ball takes the line instead of the ram, from
# LINE_FINISH_STANDOFF out, so the stagger the shots from the line open finds it hanging and the
# drop follows (swarm.md section 4: the high dwell is the latch window and the brake-drop carries
# a hanging ball onto the open queen).
const LINE_FINISH := 80.0
const LINE_FINISH_STANDOFF := 12.0
const RUNUP := 24.0
const RUNUP_SECONDS := 3.2
# A runup stays on the target's shelf: the ground RUNUP_EDGE past the runup point may sit at
# most RUNUP_DROP below the target's, else the runup shortens in RUNUP_STEP down to RUNUP_MIN.
# The ball overshoots the point, so a runup to a shelf's rim ends on the deck below.
const RUNUP_EDGE := 6.0
const RUNUP_DROP := 2.0
const RUNUP_STEP := 2.0
const RUNUP_MIN := 8.0
# The dam Warden's spillway sheet hand (_anchor_fight) takes the stick within SHEET_HAND_REACH of
# the sheet's foot; farther out the ball rolls there as on any other approach. On the dam the hand
# runs through a stagger too: the sheet ram is the only break, so a stagger opened inside a live
# sheet is converted by riding it into the core, and one opened outside it waits at the foot.
const SHEET_HAND_REACH := 60.0
# The launch presses the go verb from a standstill, or rolling with its heading within this
# cosine of the core's.
const SHEET_LAUNCH_LINED := 0.97
# At this posture or more the hand holds fire on the dam Warden: a weapon, cast or ultimate hit
# that fills the bar opens a stagger, not the break.
const SHEET_HOLD_FIRE := 90.0
# A Warden charge beyond RUNUP that gains less than CHARGE_PROGRESS on its best distance for
# CHARGE_WINDOW seconds is pinned (a cache pocket's back wall, a pit): the ball moves fast enough
# to dodge the stuck detour without getting anywhere. It recovers: back RECOVER_BACK off the
# bearing, then RECOVER_SIDE to the side whose way on is clear, each leg held at most
# RECOVER_LEG_SECONDS, then charges again. With a wall within RECOVER_PROBE ahead (a pit's rim,
# a cache's back wall) a side-step cannot leave, so it backs off as far as RECOVER_BACK_MAX
# allows and rolls at the wall with walls not dodged, jumping RECOVER_JUMP_AT short of it and
# again near the top of the jump, to a point RECOVER_OVER past it. RECOVER_LIMIT per stage
# leaves a hopeless stall to the stage watchdog.
const CHARGE_WINDOW := 6.0
const CHARGE_PROGRESS := 2.0
const RECOVER_BACK := 8.0
const RECOVER_SIDE := 14.0
const RECOVER_REACHED := 3.0
const RECOVER_LEG_SECONDS := 3.0
const RECOVER_LIMIT := 3
const RECOVER_PROBE := 10.0
const RECOVER_BACK_MAX := 12.0
const RECOVER_JUMP_AT := 3.0
const RECOVER_OVER := 6.0
const AIM_REACH := 40.0
const WAYPOINT_REACHED := 9.0
const WAYPOINT_SECONDS := 14.0
const GATE_HOP_SECONDS := 6.0
const GATE_HOP_EVERY := 1.5
# A static prop on the line to a gate (the crown's relic cache stands on the beacon island's
# approach and, once its wall is cracked, is a pocket the line runs into) is steered round:
# the line is probed GATE_PROBE metres ahead, and a blocked one goes round the prop's nearest
# visible corner (GATE_MARGIN off its walls), held up to GATE_DETOUR_SECONDS so the turn does
# not flip back at the mouth; with no corner in sight it turns by GATE_TURN steps instead.
const GATE_PROBE := 9.0
const GATE_PROBE_NEAR := 30.0
const GATE_TURN := 30.0
const GATE_MARGIN := 4.0
# A gate on a rise the ball cannot climb from a standstill (the park crown's exit bank is a
# 27 degree face below its gates, 14 to 22 m up in 16 m) is taken as a player takes it: back
# off GATE_RUNUP_BACK metres down the line, then charge it at speed. Tried once the gate has
# stood untaken GATE_RUNUP_AFTER seconds with the ball more than 3 m below it.
const GATE_RUNUP_AFTER := 14.0
const GATE_RUNUP_BACK := 70.0
const GATE_RUNUP_SECONDS := 12.0
const GATE_CHARGE_SECONDS := 10.0
const GATE_DETOUR_SECONDS := 6.0
# A gate the ball has rolled off the gates' island beside GATE_SWITCH_FALLS times is given up
# for the next offer: the crown's relic cache stands beside the east gate's run-in, and a bot
# that keeps going round it at speed keeps leaving the beacon top by its east rim.
const GATE_SWITCH_FALLS := 2
# A gate still untaken after GATE_SWITCH_SECONDS is given up for the next offer the same way:
# the cache's walls can hold a bot that keeps rounding them on the beacon top.
const GATE_SWITCH_SECONDS := 40.0
# Level with a gate and within GATE_CALM_RANGE of it, the bot rolls in without boosting and brakes
# above GATE_CALM_SPEED, as a player eases up near a rim: the crown's gates stand 5 m in from a
# 25 m drop, and a heavy ball boosted at its run-in point overshoots it off the beacon top. Any
# other gate still untaken after GATE_HOP_SECONDS gets the same easing: a heavy ball that comes up
# beside a gate at speed (the Flume's gate lip from its drum lip) swings across its run-in point,
# side to side, and never lines up to roll through.
const GATE_CALM_RANGE := 25.0
const GATE_CALM_SPEED := 12.0
# Within GATE_LINE_SIDE of a gate's line, between GATE_LINE_BACK and GATE_LINE_NEAR behind it, the
# bot steers for the line GATE_LINE_LEAD metres ahead of the ball instead of the run-in point. From
# GATE_LINE_NEAR out, a ball 6 m off the line crosses the arch inside reward_gates' 5 m take
# (WIDTH / 2 + 1), so it never takes a neighbour 10 m along (the Highdraft and crown gates).
const GATE_LINE_SIDE := 6.0
const GATE_LINE_BACK := 14.0
const GATE_LINE_NEAR := 2.0
const GATE_LINE_LEAD := 6.0
const VAULT_SECONDS := 45.0
const EVENT_PURSUIT_SECONDS := 40.0
const EVENT_LATEST := 150.0
const WANDER_GAP := Vector2(3.0, 6.0)
const WANDER_SPREAD := 1.0
const WANDER_COMMIT_DISTANCE := 45.0
const WANDER_COMMIT_TIME := 45.0
# Telegraph reading.
const REACTION := 0.25
# The anti-kiting gates' contact rule (the same for every policy): a stage's first contact is the first tick a live enemy
# stands within CONTACT_RADIUS of the ball; a hit taken with none that close (a shell, a lane) also opens it. The
# gates read the hull lost, and the seconds alive, in the CONTACT_WINDOW_S after it.
const CONTACT_RADIUS := 30.0
const CONTACT_WINDOW_S := 120.0
const PREDICT := 0.35
const FIELD_RADIUS := 20.0
const ESCAPE_DIRECTIONS := 16
const ESCAPE_REACH := [5.0, 9.0, 13.0, 18.0]
# The caps loop: slam from this close to the Warden's centre.
const CAP_JUMP := 4.6
# Beside the body (Warden radius 2.8 + ball 1.0) and the approach point on a cap's line.
const CAP_INSIDE := 3.3
const CAP_BESIDE := 3.8
# Below this share of max HP the caps loop dodges the Warden's pulse instead of riding it.
const PULSE_HP_SHARE := 0.45
# Punch the bot knows it can bring: the best punch_now() it has seen, fading this fast,
# so "short of plating" is judged on a full-speed ram, not on the ball at rest.
const PUNCH_FADE := 4.0
# Engineer plants.
const PLANT_SEARCH := 22.0
const PLANT_RANGE := 45.0
const PLANT_REACH := 2.6
const PLANT_TIMEOUT := 5.0
const PLANT_EVERY := 10.0
const TURRET_SECONDS := 3.5
const FACE_TILT := 0.866
# Leaving a plant, the engineer reads the aim cone (kit.slingshot_aim, the direction and speed the
# HUD draws) and follows its arc in SLING_STEP steps for up to SLING_FLIGHT seconds. When it comes
# down more than LEVEL_BAND below both the ball's ground and the fight's floor, she drops off the
# post (E) instead: a stacked Pylon Capacitor slingshot leaves the Highdraft crown at 45 to 66 m/s
# and lands on the net, a 20 to 40 s climb back to the Warden.
const SLING_STEP := 0.05
const SLING_FLIGHT := 4.0
const MIND_STAGE := 5
# A fight climb on the Mind stage that has not reached its target after MIND_CLIMB_GIVE_UP seconds
# drops the end-height test for the rest of the stage (ISLE-SKIRT): that test reads the east skirt
# of the Hanging Isle's ramp as one gentle step, and Tarn (completionist seed 36003) shuttled on it
# from t=100 s to the limit. The Mind fight's own climbs back to the hand finish well inside it.
const MIND_CLIMB_GIVE_UP := 45.0
# Specials.
const CROWD := 2
const CROWD_RADIUS := 12.0
const CLOSE_FIGHT := 14.0
# The boss.
const BOSS_ORBIT := 32.0
const BAIT_RADIUS := 47.0
# Brindle's charge lane: a read lane is left to half its width plus this margin (m). A clash needs
# the ball closing on the bow at CLASH_SPEED (m/s), at least CLASH_MIN_GAP (m) ahead of the front, and
# lined up within CLASH_ALIGN (m) of the axis at CLASH_ROLL (m/s) with CLASH_SPARE (s) to spare.
const CHARGE_MARGIN := 2.0
const CLASH_SPEED := 8.0
const CLASH_MIN_GAP := 5.0
const CLASH_ALIGN := 1.5
const CLASH_ROLL := 12.0
const CLASH_SPARE := 0.3
const RAMP_ANGLES := [0.0, 180.0]
const RAMP_BOTTOM := 46.0
const RAMP_PAST := 18.0
const RAMP_JUMP := 26.0
const RAMP_WINDOW := 0.5
const PICKUP_CHASE := 30.0
# Armour shed in the bowl (ruling aw) lands about 9 m ahead of the ball after a hit, closer at the
# rim. The bot takes a shed pile within SHED_CHASE, or further off only while it lies inside the
# cone of the ball's travel (SHED_AHEAD, the cosine, about 66 degrees either side), so past
# SHED_CHASE it never turns round for one. Chasing every pile kept a light ball circling the
# Furnace taking hits (park seed 0 from mass 0, 94 s to 196 s); taking none left a stripped ball
# unable to rebuild for a break (seed 16 stalled again); the near piles alone starved a bare ball
# in phase 3 (bot_brindle_short_test); and a 45 degree cone left park seed 3 short of mass (190 s).
const SHED_CHASE := 8.0
const SHED_AHEAD := 0.4
const SHED_ROLLING := 1.0
const CAP_ABOVE := 1.2
const CAP_REACH := 2.6
# The explorer's standing activities (slice table): game seconds each may hold the bot, counted
# from the first frame it is the target and including the roll onto its pay; past that it is
# abandoned and the bot moves on. The cache's run-up point lies this far out from its face.
const ACTIVITY_SECONDS := 40.0
# The surge course is a ring, a siren and then a run down a whole line, so it gets longer than a standing site.
const SURGE_SECONDS := 80.0
# Down the line, it aims this far ahead of itself on the deck's centre.
const SURGE_LEAD_M := 18.0
# Inside this of the next gate it aims at the gate.
const SURGE_GATE_AIM_M := 35.0
# While the siren winds, it waits this far back from the head, on the line.
const SURGE_RUNUP_M := 14.0
# A field find's limit: the walk into its dead end comes on top of the ram.
const FIND_SECONDS := 60.0
const CACHE_RUNUP := 24.0
const CACHE_RUNUP_SECONDS := 5.0
const CACHE_RAM_SECONDS := 3.0
const CACHE_STAGE := 45.0
const PAY_BACKOFF := 6.0
# The high ground goes first: a ball cannot climb back out of the trough, so a site on a shelf is
# worked before the ones below it, ties nearest first. Sites are ranked by ground height in bands.
const LEVEL_BAND := 8.0
const PLATE_REACH := 30.0
const CAMP_LAST := 1000.0
# The spacing of the waypoints on a field find's graph path.
const FIND_LEG_M := 24.0
# A find within this many metres is taken before the lit sites, as a player hearing its tell would.
const FIND_NEAR_M := 120.0
# A find's path that gains no waypoint in this many game seconds is given up: the ball is stuck.
const FIND_LEG_SECONDS := 10.0
# A site more than LEVEL_BAND above the ball is not rolled at straight: the cliff under its shelf
# wedges the ball (the Reach camp stands 22 m over the trough). The way up is planned once on the
# ground's heights, a CLIMB_STEP grid within CLIMB_PAD of both ends that never rises steeper than
# CLIMB_SLOPE, and followed point by point.
const CLIMB_STEP := 4.0
const CLIMB_PAD := 100.0
const CLIMB_SLOPE := 0.5
# When no way up stays within CLIMB_SLOPE, the plan is retried at each of these steeper limits
# before the ball is steered straight at the target: Spillway stage 1 (Tarn, random seed 35221)
# has a basin whose way out climbs between 0.5 and 0.55, and the straight line from it meets the 14 m face
# under the Warden's shelf, which held the ball for the rest of the stage.
const CLIMB_SLOPE_RETRY := [0.6, 0.75]
# A greybox kicker rises exactly CLIMB_SLOPE (14 m over 28 m); the slack keeps rounding from closing it.
const SLOPE_SLACK := 0.001
# How far past a kicker's lip its launch lands, clear of the gap a lip leaves before the next floor.
const KICKER_LAUNCH := 8.0
const KICKER_JUMP_AT := 3.0
const CLIMB_REACHED := 6.0
const ROUTE_REACHED := 15.0
# A cable takes a ball whose centre comes within its radius of the cable's high end (contraptions.gd) and rides it
# down. A climb cell whose rolling centre is within CABLE_CLEAR more is closed: on the park's first stage the way up
# to the domes camp passed under domes_zip's end, and each pass rode the explorer 58 m back down to the deck.
const CABLE_CLEAR := 2.0
# A fight target on a shelf more than LEVEL_BAND above the ball is climbed to the same way, the
# route replanned every FIGHT_CLIMB_REPLAN seconds while the ball stays below: on the Highdraft
# crown the deck under the beacon's cliff lies off the dogleg bridges, and the way up is a
# shoulder ramp the straight line never meets.
const FIGHT_CLIMB_REPLAN := 6.0
const CLIMB_LEVEL := 1.5
# On a map with standing activities the explorer stops its other rolling (scrap lines, events, the
# vault) at this stage second and goes to the Warden, so the fight has the rest of STAGE_LIMIT.
const ENGAGE_BY := 140.0
# The skill bar's hands (SKILL-BAR section 8). A bot casts slot 2 or 3 the way a player does: a
# number key picks it and a left click casts it, never by writing special_* or line_* (the router's
# outputs). Every policy sends the pick and the click on one tick; the traversal pilot sends them
# CAST_GAP apart and counts the pair as one verb. The line skill goes along a body line within
# LINE_CAST_REACH, or loads just before a planned bite. Q goes at a full meter when a Warden core is
# open within ULT_CORE_REACH or ULT_CROWD enemies are within ULT_CROWD_RADIUS; the traversal pilot
# fires it when its next waypoint lies ULT_TRAVERSE_NEAR to ULT_TRAVERSE_FAR ahead over open ground.
# A refused Q waits ULT_RETRY before the next press. What the hands read is what the bar and the
# meter show: abilities.selected, abilities.slots(), abilities.ultimate(), combat.line_load() and
# combat.ultimate.phase().
const CAST_GAP := 0.1
const LINE_CAST_REACH := 15.0
const ULT_CORE_REACH := 45.0
const ULT_CROWD := 3
const ULT_CROWD_RADIUS := 20.0
const ULT_TRAVERSE_NEAR := 25.0
const ULT_TRAVERSE_FAR := 70.0
const ULT_RETRY := 1.0

var game
var policy := "skipper"
var seed_value := 1
var profile := ""
var route: Array[Vector2] = []
var press_ticks: Array[int] = []
var class_index := 0
var rng := RandomNumberGenerator.new()
var source := Intent.Scripted.new()
# Set by the runner's --trace: prints the bot's goal and the ball every two seconds.
var trace := false
# "" or "random"; set before start(). tree_picks lists the node ids taken, in order.
var tree_policy := ""
var tree_picks: Array[String] = []
# SG8's lab switch (bot_run --late-offer): "" leaves the tree's late_offer off and the bot as it
# was; "take" or "skip" turns late_offer on and answers only the take_or_skip offer that way.
var late_offer_policy := ""
# SR10's lab switch (bot_run --relay-stake=0..4): above 0, the skipper stakes the park relay with
# the game's own set_stakes before it rolls in, works it to its pay, then goes on to the Warden.
# 0 leaves every code path below untouched.
var relay_stake := 0
# The pacing lab's switch (bot_run --explore-by=<s>, scripts/pacing-check.mjs): the stage second the
# completionist stops its optional rolling for the Warden. Left at ENGAGE_BY unless the flag is given.
var engage_by := ENGAGE_BY
# Under --explore-by an activity's ACTIVITY_SECONDS run only while the ball is within ACTIVITY_NEAR of
# the site; the roll there has its own ACTIVITY_TRAVEL_SECONDS. The default clock counts the roll too, and
# on the park dam it ran out on the way to the altar and the camp (trace, seed 3, 24 Oct).
const ACTIVITY_NEAR := 40.0
const ACTIVITY_TRAVEL_SECONDS := 60.0
# The roll gets ACTIVITY_TRAVEL_SECONDS plus a second for every ACTIVITY_TRAVEL_SPEED metres it starts away.
const ACTIVITY_TRAVEL_SPEED := 8.0
var _activity_travel := {}
var _activity_travel_cap := {}
# A site the roll could not reach in its cap is put off, not dropped, until the ball has moved
# ACTIVITY_RETRY_MOVE from where it gave up, once: on the park dam the rim cache and the bench altar
# lie past the crest, and the way down is the spillway sheet the explorer takes later anyway.
const ACTIVITY_RETRY_MOVE := 150.0
var _activity_deferred := {}
# Under --explore-by a roll that has not come CLOSING_M nearer its site in CLOSING_SECONDS has run
# out its travel cap: the explorer was spending 2-4 minutes a park rocking under a rim it cannot climb
# (dam seed 2, rim_cache, 130 s at one spot on 5dc9b6cf with --explore-by=1200) before the
# distance-scaled cap let it go. key -> [nearest metres so far, seconds since it last closed].
const CLOSING_M := 10.0
const CLOSING_SECONDS := 30.0
var _closing := {}
# Under --explore-by a cache the explorer has rammed RAM_TRIES times without a break is given up:
# a run-up that meets the rise foot short of the face keeps failing the same way (dam east_rim_bench,
# 5dc9b6cf), and the near clock let it try for FIND_SECONDS.
const RAM_TRIES := 4
var _ram_tries := {}
const RELAY_ARM_SECONDS := 150.0
var _relay_clock := 0.0
var _relay_closed := {}
var late_offer_counts := {"offered": 0, "taken": 0, "declined": 0}
var _tree_rng := RandomNumberGenerator.new()

# The sweep's limits. stage_limit replaces STAGE_LIMIT. fight_limit, when above zero, ends the
# run as "fight_capped" that many seconds after fight_start_of the stage note (the later of the
# bot's turn to the Warden and the Warden's engagement) if the Warden is not broken by then.
var stage_limit := STAGE_LIMIT
var fight_limit := 0.0

# "", then won, died, stalled, boss, boss_stalled, fight_capped or broken.
var outcome := ""
var ticks := 0
# One row per stage the bot entered: what it tried, for the sidecar log.
var stage_notes: Array[Dictionary] = []
# The Brindle fight, when there was one.
var boss_note := {}

var _offers: Array = []
var _gate_pick := -1
var _gate_time := 0.0
var _gate_hop := 0.0
var _gate_detour := Vector3.ZERO
var _gate_detour_left := 0.0
var _gate_run := ""
var _gate_run_clock := 0.0
var _gate_on_top := false
# Whether this stage's gates stand on a sky island's top (a Highdraft map: the crown's beacon,
# 25 m over the deck). The climb-back, calm, back-out and gate-switch rules apply only there.
var _island_gates := false
var _gate_falls := 0
var _stage := 0
var _fight_phase := "charge"
var _fight_target: Node3D = null
var _runup_point := Vector3.ZERO
var _runup_time := 0.0
var _charge_best := INF
var _charge_clock := 0.0
var _recoveries := 0
var _recover_legs: Array[Vector3] = []
var _recover_time := 0.0
var _recover_wall := false
var _recover_climb := false
var _slow_time := 0.0
var _detour_time := 0.0
var _detour := Vector3.ZERO
var _wall_side := 0.0
var _wall_dir := Vector3.ZERO
var _boost_clock := 0.0
var _card_press_tick := -1000000
var _shift_left := 0.0
var _waypoints: Array[Vector3] = []
var _find_route: Array[Vector3] = []
var _find_route_for := ""
var _find_exit := Vector3.INF
var _find_leg_clock := 0.0
var _waypoint_time := 0.0
var _vault_time := 0.0
var _vault_done := false
var _event_time := {}
var _event_skip := {}
var _wander_clock := 0.0
var _wander_heading := Vector3.FORWARD
var _committed := false
var _planned := false
var _note := {}
var _goal := ""
var _camp_backing := false
var _activity := ""
# The stage's rib caches still on the ground, by instance id -> where they stand, and the rogue
# once it has woken: what _content_scan reads for the stage note's rogue and rib cache rows.
var _caches_seen := {}
var _rib_spot := {}
var _rogue_seen: Node3D = null
# The woken rogue's instance id: a freed rogue compares equal to null, so the note's beaten
# check keys on the id (instance_from_id is null once it is freed).
var _rogue_id := 0
var _rogue_clock := 0.0
var _rib_clock := {}
var _activity_time := {}
var _activity_skip := {}
var _cache_phase := "runup"
var _cache_clock := 0.0
var _climb: Array[Vector3] = []
var _climb_for := ""
# Under --explore-by: the park route's row centres between the ball and a site's row, walked before the climb.
var _route: Array[Vector3] = []
var _fight_climb: Array[Vector3] = []
var _fight_climb_clock := 0.0
var _fight_climb_held := 0.0
var _fight_climb_tick := -1
var _mind_slope_spent := false
var _route_lips: Array[Vector3] = []
var _plate_hand := {}
var _ignore_walls := false
# Telegraph reading: instance id -> tick first seen; the ids evaded this stage.
var _seen := {}
# A skill band (tools/skill_band.gd) or null. Null is the driver as it always was: REACTION,
# every tell read, every hand on. A band slows the reaction, drops unread tells and refuses
# the kit hands it does not have (see _kit).
var band = null
# The lowest hull the run reached, for the record; it steers nothing.
var _min_hp := INF
var _evaded := {}
# Telegraph ids already counted as a read (the gates' reads per hit), pruned with _seen.
var _read := {}
# Brindle charge lanes (hazard instance id) already counted as read, sidestepped, clash-tried, and the clash taken.
var _charge_read := {}
var _charge_stepped := {}
var _clash_tried := {}
var _clash_latched := {}
# The pulse ring the caps loop takes on purpose, by its centre.
var _welcome_ring_at := Vector3.INF
# Engineer plant cycle: idle, seek or mounted.
var _plant_state := "idle"
var _plant_clock := 0.0
var _plant_cool := 0.0
var _plant_face := Vector3.ZERO
var _plant_target: Node3D = null
var _boss_clock := 0.0
# The hull at the last tick or hit: a hit's hull loss is what it took off this, after scrap armour.
var _hull_seen := -1.0
# The opening the 19 Oct ruling protects: no boss kills a Learner in its first 45 s.
const FIRST_45_S := 45.0
# Seconds the dam's spillway sheet has been open in this cycle, for a band that launches by sight; -1 shut.
var _sheet_live_s := -1.0
var _punch_seen := 0.0
var _warden_hp_at := -1.0
var _warden_kinds := {}
# The harpoon hand: RMB held while a line is on the fight target, and Ctrl held to commit it.
var _harpoon_held := false
var _pass_bite_frame := -100000
# Weak points (stub_boss.gd weak_open, #241): the point being read, how long it has been open, the
# learner's one roll for it, whether a go is on, and the Warden it was read on: a go waives the harpoon hand's
# wait between bites (_harpoon_hand) on that Warden only, so it bites again at once and the hand commits the haul.
var _weak_seen := ""
var _weak_age := 0.0
var _weak_roll := 0.0
var _weak_go := false
var _weak_warden: Node3D = null
var _harpoon_commit := false
# The anti-kiting gates (bot_kite.gd): the policy object, whether the stick coasts above cruise speed with boost off (orbit
# and terrain circling), and the test-only plants (tools/bot_plants.gd; both false/empty without --plant=).
var kite
var _cruise_hold := false
var hide_pack_telegraphs := false
# The fairness record (tools/bot_fairness.gd): reads the game, steers nothing.
var _fair := BotFairness.new()
# Only the explorer changes hands: jump clear, bite, release at the apex, bite again, haul.
# chain_hand_enabled = false keeps the one-bite hand, the control for the two-hook one.
var chain_hand_enabled := true
var _chain_phase := ""
var _chain_first: Node3D = null
var _chain_second: Node3D = null
var _chain_rose := false
var _chain_launch_y := 0.0
# The latch arm (_anchor_fight): the anchor Warden's last height, its vertical speed as the
# ball sees it, whether the ball was on its line last tick, how long a staggered line has hung
# below the open point, the haul made in this stagger (and whether from over the open point)
# with the chunks it found, and whether this stagger's jump for the drop is spent.
var _anchor_target: Node3D = null
var _anchor_last_y := INF
var _anchor_vy := 0.0
var _anchor_lined := false
var _anchor_below := 0.0
var _haul_made := false
var _haul_above := false
var _haul_pressed_above := false
var _haul_chunks := -1
var _drop_jumped := false
var _anchor_chunks_seen := -1
var _anchor_seen_hung := false
# Seconds since the ball was last beyond the drop line of its fight target.
var _off_line := 0.0
var _out: Array[Dictionary] = []
var _defer_look := false
var _look_delta := Vector2.ZERO
var _leg := 0
var _last_press_tick := -1000000
# The cast in hand: the bar number (2 or 3), its hold, and where it is. "click" sends the pick
# and the click; "hold" keeps the click down; "release" lets it up and, if the cast did not
# commit, presses 1 to send the pick home. The traversal pilot adds "sent" (the pick is in its
# buffer) and schedules the click at _cast_click_tick once the pick has passed its press gate.
var _cast_slot := 0
var _cast_hold := 0.0
var _cast_phase := ""
var _cast_click_tick := -1
var _ult_wait := 0.0
var _traverse_point := Vector3.INF
# The traversal hands (HAND_NAMES) the runner named, and what they decided this tick.
var hands: Array[String] = []
var _glide_held := false
# True on a tick the harpoon hand turns the camera to a candidate anchor: the Q set piece flies
# where the camera looks, so the traversal pilot does not press it then.
var _hand_aim := false
var _gliding := false
var _swing_clock := 0.0
var _swing_cool := 0.0
var _swing_sent := 0.0
# In-play seconds, the meter's own clock (it fills only in play), and the fill records.
var _play_clock := 0.0
var _fill_from := 0.0
var _fills: Array[float] = []
var _fill_open := true
var _totals := {"slot_casts_special": 0, "slot_casts_line": 0, "ultimates": 0, "ult_presses": 0, "shots": 0}
# The meter's points by source at the first full meter, for the record only.
var _first_fill_sources := {}


# The seed mapping (seed % roster size) moves whenever the roster grows, so band tests
# pass --pilot (tools/bot_run.gd) to name the pilot each seed plays. With a pilot this
# returns that ClassDef id's index, or -1 when no row has that id.
static func class_index_for(seed_number: int, pilot := "") -> int:
	var roster: Array = ClassDef.all()
	if pilot == "":
		return seed_number % roster.size()
	for i in roster.size():
		if roster[i].id == pilot:
			return i
	return -1


func _init(game_ref, policy_name: String, seed_number: int) -> void:
	game = game_ref
	# No human answers the hot-wire screen in a bot run; tick answers the offer instead.
	game.bot_driven = true
	profile = policy_name if policy_name in PROFILES else ""
	var named: String = PROFILES.get(policy_name, policy_name)
	policy = named if named in POLICIES else "skipper"
	seed_value = seed_number
	class_index = class_index_for(seed_number)
	rng.seed = hash([policy, seed_number])
	_tree_rng.seed = hash(["tree", seed_number])


# Call once the game's flow exists. Reseeding the run's stream makes each seed its own
# stage plan (events, scrap, spawns); the base seed alone would give every run of a
# policy the same map draw.
func start(resume := false) -> void:
	wire()
	if resume and game.flow.resume_run():
		return
	game.flow.press_start()
	game.flow.choose_class(class_index)


# start()'s wiring alone, for a caller that begins the run itself (self-play pressing the menus' keys).
# Call it once, in place of start(): both together connect every handler twice.
func wire() -> void:
	game.ctx.rng.seed = 20260926 + seed_value * 7919
	game.player.source = source
	var events = game.events
	if policy == "completionist":
		events.line_state_changed.connect(_on_explorer_line)
	events.stage_entered.connect(_on_stage_entered)
	events.stage_cleared.connect(func(_s: int): _close_note())
	events.reward_offered.connect(_on_offers)
	events.reward_chosen.connect(func(_id: String): _offers = [])
	events.player_died.connect(func(): _end("died"))
	events.run_ended.connect(func(won: bool): _end("won" if won else "lost"))
	events.warden_engaged.connect(func(_s: int):
		_note_set("warden_engaged_s", snappedf(game.run.stage_time, 0.01))
		# The descent's speed is not a ram the fight can repeat; judge from here on.
		_punch_seen = float(game.flow.punch_now()))
	events.beacon_unsealed.connect(func(_s: int):
		_note_set("warden_broken_s", snappedf(game.run.stage_time, 0.01))
		# The latch arm's haul broke it: a haul in the breaking stagger, a drop when from over the open point.
		if _haul_made:
			_count("latch_chunks")
			_note_set("latch_break", true)
			if _haul_above:
				_count("drop_chunks")
				_note_set("drop_break", true)
			_haul_made = false
		if _warden_hp_at >= 0.0:
			_settle_warden_damage(0.0))
	events.event_started.connect(func(id: String):
		if id in EventDirector.PARTICIPATORY:
			_note_add("events_joined", id))
	events.core_gained.connect(func(source_id: String, _at: Vector3, _n: int): _note_add("cores", source_id))
	events.part_gained.connect(func(id: String, source_id: String): _note_add("parts", "%s:%s" % [source_id, id]))
	events.player_hit.connect(_on_player_hit)
	_fair.setup(game, Callable(self, "boss_hazards"))
	events.enemy_struck.connect(_on_enemy_struck)
	events.special_used.connect(func(_id: String, _at: Vector3): _count("specials"))
	events.shot_fired.connect(func(_weapon: String, _from: Vector3, _to: Vector3):
		_totals["shots"] = int(_totals["shots"]) + 1
		var kit = game.player.kit
		if kit.hooked and kit.on_body and _anchor_warden(kit.anchor_body):
			_count("latch_shots"))
	_connect_optional("slot_cast", func(slot: String, _id: String, _at: Vector3): _on_slot_cast(slot))
	_connect_optional("ultimate_started", func(_id: String, _path: String, _from: Vector3, _to: Vector3, _s: float): _on_ultimate_started())
	_connect_optional("ultimate_ready", func(_id: String): _on_ultimate_ready())
	events.world_fact.connect(func(fact: String, _at: Vector3):
		if fact == "thermal_ride" and game.flow.in_stage():
			_count("thermal_rides")
		if kite != null and game.flow.in_stage():
			kite.on_ride_fact(fact))
	events.slammed.connect(func(at: Vector3, _strength: float, _flatness: float):
		if not _plate_hand.is_empty() and game.flow.in_stage() and _plate_contains(_plate_hand, at):
			_count("plate_slams"))
	events.mounted.connect(func(_at: Vector3, _banked: float): _count("plants"))
	events.dismounted.connect(func(v: Vector3):
		if v.length() > 0.5:
			_count("slingshots"))
	_connect_optional("boss_arena_entered", func(): _on_boss_entered())
	_connect_optional("boss_phase_changed", func(phase: int, phase_name: String): _on_boss_phase(phase, phase_name))
	_connect_optional("boss_weak_point_hit", func(point_id: String):
		if not boss_note.is_empty():
			var hits: Dictionary = boss_note["weak_point_hits"]
			hits[point_id] = int(hits.get(point_id, 0)) + 1)
	_connect_optional("boss_defeated", func():
		_boss_set("defeated_s", snappedf(_boss_clock, 0.01))
		_boss_hold_note())
	events.scrap_lost.connect(func(amount: int, _at: Vector3, _total: int, cause: String):
		if cause == "crane":
			_boss_set("stolen", int(boss_note.get("stolen", 0)) + amount))
	if late_offer_policy != "":
		game.player.tree.late_offer = true
	if tree_policy == "random":
		_connect_optional("tree_offered", _on_tree_offered)


func _on_tree_offered(_class_id: String, depth: int, choices: Array) -> void:
	if choices.is_empty():
		return
	var tree = game.player.tree
	if late_offer_policy != "" and tree.offer_kind(depth) == tree.OFFER_TAKE_OR_SKIP:
		late_offer_counts["offered"] += 1
		# A skip opens the forced sibling, whose tree_offered lands back here as a one-card pick.
		if late_offer_policy == "skip":
			if tree.skip():
				late_offer_counts["declined"] += 1
			return
		if tree.pick(String(choices[0])):
			tree_picks.append(String(choices[0]))
			late_offer_counts["taken"] += 1
		return
	var choice: String = choices[_tree_rng.randi() % choices.size()]
	if game.player.tree.pick(choice):
		tree_picks.append(choice)


func _connect_optional(signal_name: String, handler: Callable) -> void:
	if game.events.has_signal(signal_name):
		game.events.connect(signal_name, handler)


func class_id() -> String:
	return game.run.class_id()


func _engineer() -> bool:
	return class_id() == "pylon_engineer"


# Kest's throw is hold-release: the bot lets go of LMB once the throw would reach its
# aim, as a player watching the landing ring would, instead of always throwing long.
func _throw_hold(aim) -> bool:
	var gauge = game.player.abilities.gauge(AbilityState.WEAPON)
	if gauge == null or not gauge.charging or not _aim_valid(aim):
		return true
	var reach: float = _flat(game.player.ball_position(), _aim_point(aim))
	var want := clampf((reach - Weapons.STICKY_THROW_MIN) / (Weapons.BASE[Weapons.STICKY_CHARGE]["range_m"] - Weapons.STICKY_THROW_MIN), 0.0, 1.0)
	return gauge.fraction() < want


# One physics tick. Returns true when the run is over.
func tick(delta: float) -> bool:
	if outcome != "":
		return true
	ticks += 1
	_hull_seen = float(game.run.hp)
	var flow = game.flow
	var state: String = flow.state_name()
	match state:
		"dead":
			_end("died")
			return true
		"summary":
			_end("won" if flow.run_won else "lost")
			return true
		"victory":
			source.hold = {}
			return false
		"boss":
			if _boss() == null:
				_end("boss")
				return true
	if not flow.in_play():
		source.hold = {}
		return false
	if policy == "completionist" and state not in ["stage", "beacon"]:
		_clear_chain_hand()
	# Every stage state, the gates included: a gate the bot cannot reach (seed 5 random put
	# gate 1 behind a Spillway chute kerb) once ran a process forever, since only the
	# Warden fight had a limit. stall_state says which state ran out.
	if flow.in_stage() and game.run.stage_time > _stage_cap():
		_note_set("stall_state", state)
		_end("stalled")
		return true
	var fight_start = fight_start_of(_note)
	if fight_limit > 0.0 and fight_start != null and _note.get("warden_broken_s") == null \
			and game.run.stage_time - float(fight_start) > fight_limit:
		_end("fight_capped")
		return true
	_boost_clock -= delta
	_play_clock += delta
	_min_hp = minf(_min_hp, float(game.run.hp))
	_ult_wait -= delta
	_harpoon_held = false
	_harpoon_commit = false
	_cruise_hold = false
	_contact_scan()
	_fair.tick(delta)
	if flow.in_stage():
		_content_scan()
	_plant_cool -= delta
	_punch_seen = maxf(float(flow.punch_now()), _punch_seen - PUNCH_FADE * delta)
	if trace and ticks % (Engine.physics_ticks_per_second * 2) == 0:
		var b: Vector3 = game.player.ball_position()
		print("  trace t=%.0f stage %d %s goal=%s ball=(%.0f, %.0f, %.0f) speed=%.1f hp=%.0f heft=%.2f punch=%.0f" % [game.run.stage_time,
			game.run.stage, state, _goal, b.x, b.y, b.z, game.player.planar_velocity().length(), game.run.hp, game.run.heft(), flow.punch_now()])
	if trace and is_instance_valid(_anchor_target) and ticks % (Engine.physics_ticks_per_second * 2) == 0:
		print("    anchor y=%.1f vy=%.1f staggered=%s chunks=%d posture=%.0f; line hooked=%s on_body=%s state=%s" % [
			_anchor_target.global_position.y, _anchor_vy, _anchor_target.staggered(), _anchor_target.chunks_left(),
			_anchor_target.posture(), game.player.kit.hooked, game.player.kit.on_body, game.player.kit.line_state])
	if trace and state == "boss" and ticks % (Engine.physics_ticks_per_second * 2) == 0:
		var boss = _boss()
		if boss != null and is_instance_valid(boss.get("arena")) and boss.get("ship") != null:
			var b: Vector3 = game.player.ball_position()
			print("    boss phase %s %s hp %.0f; ball r %.1f above arena ground %.1f, grounded %s, body velocity %s" % [boss.phase,
				boss.state_name(), boss.hp, boss.arena.radius_of(b), b.y - boss.arena.ground(b), game.player.state.grounded,
				game.player.body().linear_velocity])
			print("    posture %.1f stagger %s; hull=%s distance=%.1f; line=%s hooked=%s on_body=%s" % [boss.posture(), boss.staggered(),
				boss.ship.hull.global_position, _flat(b, boss.ship.hull.global_position), game.player.kit.line_state,
				game.player.kit.hooked, game.player.kit.on_body])
	match state:
		"stage", "beacon":
			_roam(delta)
		"gates":
			_to_gate(delta)
		"boss":
			_boss_clock += delta
			if _boss_clock > BOSS_LIMIT:
				_end("boss_stalled")
				return true
			_fight_boss(delta)
		"lap":
			_lap_roll()
		_:
			source.hold = {}
	_set_piece_hands()
	return outcome != ""


# The victory lap: boost for the vent in the bowl's middle, so the bot rides the wall down into it, flies, lands on the
# far wall and rolls back for another shot, the way a player showing off would. The lap's clock ends it. A started
# driver has already ended on run_ended by then, so the lap's callers (victory_lap_test, lap_capture) call this directly.
func _lap_roll() -> void:
	var lap = game.flow.lap
	if not is_instance_valid(lap):
		source.hold = {}
		return
	var to: Vector3 = lap.centre() - game.player.ball_position()
	var wish := Vector3(to.x, 0.0, to.z).normalized() if Vector2(to.x, to.z).length() > 1.0 else Vector3.BACK
	source.hold = {"move": _world_to_stick(wish), "shift_held": true}


# The stall limit now. A sweep's own stage_limit is kept; the default one stretches for the
# Mind's crown, for the gates after a break, by however far --explore-by moved engage_by, and by
# the time the Spillway's locks held the run (ruling t).
func _stage_cap() -> float:
	if stage_limit != STAGE_LIMIT:
		return stage_limit
	var cap := stage_limit
	if game.run.stage == 6:
		cap = PARK_MIND_LIMIT
	var broken = _note.get("warden_broken_s")
	if broken != null:
		cap = maxf(stage_limit, float(broken) + GATE_LIMIT)
	return cap + maxf(0.0, engage_by - ENGAGE_BY) + _lock_held_s()


# The seconds the Spillway's locks (#420, src/world/stage_locks.gd) held this stage on purpose:
# the yard's lock from its slam to its bells, and the Warden's clamp from the first engage until
# it opens, each still counting while it stands and each at most its row's max_s, so a lock the
# bot never sees open cannot grow the cap with the clock (seed 16 ran 97 min on 97bcc2c0).
# STAGE_LIMIT is a harness fit (ruling t), so a run the locks delay is not called stalled for it.
# With --locks=0 there are no notes and nothing is added.
func _lock_held_s() -> float:
	var lock_at = _note.get("lock_s")
	var engaged = _note.get("warden_engaged_s")
	if lock_at == null and engaged == null:
		return 0.0
	var gate = game.flow.get("gate")
	if gate == null:
		return 0.0
	var held := 0.0
	if lock_at != null:
		var unlock_at = _note.get("unlock_s")
		var until := float(unlock_at) if unlock_at != null else float(game.run.stage_time)
		held += clampf(until - float(lock_at), 0.0, float(gate.lock_row().get("max_s", 0.0)))
	if engaged != null and gate.has_gate():
		var open_at = _note.get("gate_open_s")
		var until := float(open_at) if open_at != null else float(game.run.stage_time)
		held += clampf(until - float(engaged), 0.0, float(gate.gate_row().get("max_s", 0.0)))
	return held


# The fight clock starts at the later of the bot's turn to the Warden and the Warden's
# engagement (first ring entry or strike), so a roll from spawn is not fight time. Null
# until one of them is noted.
static func fight_start_of(note: Dictionary):
	var turned = note.get("warden_fight_s")
	var engaged = note.get("warden_engaged_s")
	if turned == null:
		return engaged
	if engaged == null:
		return turned
	return maxf(float(turned), float(engaged))


func warden_broken() -> bool:
	return _note.get("warden_broken_s") != null


func _end(why: String) -> void:
	if outcome != "":
		return
	outcome = why
	_close_note()
	if not boss_note.is_empty():
		if why == "died" and not boss_note.has("outcome"):
			boss_note["died_s"] = snappedf(_boss_clock, 0.01)
		boss_note["outcome"] = why
		boss_note["seconds"] = snappedf(_boss_clock, 0.01)
		_boss_hold_note()
		var boss = _boss()
		if boss != null:
			boss_note["phase_reached"] = boss.get("phase")
			boss_note["wall_stuns"] = boss.get("stuns")
			boss_note["clashes"] = boss.get("clashes")
	source.hold = {}


# --- bookkeeping -----------------------------------------------------------------------

func _on_stage_entered(stage: int, _retry: bool) -> void:
	_plate_hand = {}
	_clear_chain_hand()
	_close_note()
	_stage = stage
	_offers = []
	_gate_pick = -1
	_fight_phase = "charge"
	_fight_target = null
	_reset_charge_watch()
	_recoveries = 0
	_slow_time = 0.0
	_detour_time = 0.0
	_wall_side = 0.0
	_waypoints = []
	_find_route = []
	_find_route_for = ""
	_find_exit = Vector3.INF
	_waypoint_time = 0.0
	_vault_time = 0.0
	_vault_done = false
	_event_time = {}
	_event_skip = {}
	_activity = ""
	_activity_time = {}
	_activity_travel = {}
	_activity_travel_cap = {}
	_activity_deferred = {}
	_activity_skip = {}
	_closing = {}
	_ram_tries = {}
	_relay_clock = 0.0
	_relay_closed = {}
	_caches_seen = {}
	_rib_spot = {}
	_rogue_seen = null
	_rogue_id = 0
	_rogue_clock = 0.0
	_rib_clock = {}
	_rogue_done = false
	_rogue_travel = 0.0
	_rogue_travel_cap = -1.0
	_rib_skip = {}
	_rib_travel_cap = {}
	_leg_route = []
	_leg_for = ""
	_cache_phase = "runup"
	_cache_clock = 0.0
	_climb = []
	_route_lips.clear()
	_climb_for = ""
	_route.clear()
	_fight_climb = []
	_fight_climb_clock = 0.0
	_fight_climb_held = 0.0
	_fight_climb_tick = -1
	_mind_slope_spent = false
	_wander_clock = 0.0
	_committed = policy == "skipper"
	_planned = false
	_seen = {}
	_evaded = {}
	_plant_state = "idle"
	_plant_cool = 0.0
	_warden_hp_at = -1.0
	_warden_kinds = {}
	_note = {"stage": stage, "warden_engaged_s": null, "warden_fight_s": null, "warden_broken_s": null, "exit_s": null, "events_joined": [],
		"cores": [], "parts": [], "vault_tried": false, "pockets_drawn": null, "waypoints": 0, "stuck_detours": 0, "hp_lost": 0.0, "hits": 0,
		"max_hp": game.run.max_hp, "evasions": 0, "cap_hits": 0, "magnet_stuns": 0, "plants": 0, "slingshots": 0,
		"specials": 0, "punch_short_s": 0.0, "plate_slams": 0, "thermal_rides": 0,
		"first_contact_s": null, "first_hit_s": null, "hull_lost_120s": 0.0, "alive_120s": null, "fight_s": 0.0, "circle_s": 0.0,
		"circle_share": null, "line_rides": 0, "lines_in_reach": null, "line_misses": 0, "telegraph_reads": 0,
		"rogue_woke_s": null, "rogue_beaten_s": null, "rogues_beaten": 0, "rib_caches_placed": 0, "rib_caches_taken": 0}


func _note_set(key: String, value) -> void:
	if not _note.is_empty():
		_note[key] = value


func _note_add(key: String, value) -> void:
	if not _note.is_empty():
		(_note[key] as Array).append(value)


func _count(key: String, by: float = 1.0) -> void:
	var into: Dictionary = boss_note if _in_boss() else _note
	if into.is_empty():
		return
	into[key] = into.get(key, 0) + by


func _on_slot_cast(slot: String) -> void:
	var key := "slot_casts_special" if slot == AbilityState.SPECIAL else "slot_casts_line" if slot == AbilityState.LINE else ""
	if key == "":
		return
	_totals[key] = int(_totals[key]) + 1
	_count(key)


func _on_ultimate_started() -> void:
	_totals["ultimates"] = int(_totals["ultimates"]) + 1
	_count("ultimates")
	_fill_from = _play_clock
	_fill_open = true


# Seconds of play from the run's start, or from the last set piece, to a full meter. A retry that
# restores a full meter publishes ready again; that fill was already counted.
func _on_ultimate_ready() -> void:
	if not _fill_open:
		return
	_fill_open = false
	_fills.append(snappedf(_play_clock - _fill_from, 0.01))
	if _first_fill_sources.is_empty():
		_first_fill_sources = _meter_sources()


# The meter's points paid this run, by source (instrumentation for the record; no hand reads it).
func _meter_sources() -> Dictionary:
	var meter = game.player.abilities.get("meter")
	if meter == null:
		return {}
	var out := {}
	for key in meter.sources:
		out[key] = snappedf(float(meter.sources[key]), 0.01)
	return out


func _boss_set(key: String, value) -> void:
	if not boss_note.is_empty():
		boss_note[key] = value


func _boss_add(key: String, value) -> void:
	if not boss_note.is_empty():
		(boss_note[key] as Array).append(value)


func _in_boss() -> bool:
	return game.flow.state_name() == "boss" and not boss_note.is_empty() and not boss_note.has("outcome")


func _on_player_hit(amount: float, source_id: String) -> void:
	# hp_lost and the largest hit are the whole hit before scrap armour; hull_lost is what reached the hull.
	var hull: float = amount if _hull_seen < 0.0 else maxf(0.0, _hull_seen - float(game.run.hp))
	_hull_seen = float(game.run.hp)
	_count("hp_lost", amount)
	_count("hull_lost", hull)
	_count("hits")
	_note_contact_hit(hull)
	_fair.hit(source_id, hull)
	if source_id == "brindle_charge":
		_count("charge_hits")
	var in_boss := _in_boss()
	var into: Dictionary = boss_note if in_boss else _note
	if not into.is_empty():
		if not into.has("hit_sources"):
			into["hit_sources"] = {}
		into["hit_sources"][source_id] = snappedf(float(into["hit_sources"].get(source_id, 0.0)) + amount, 0.1)
		# The comps study's per-fight report (research/comps/difficulty/SUMMARY.md, Lab measure): the largest
		# single hit as a share of pilot health, and the damage taken in the fight's first 45 s. A stage note
		# counts only from its Warden fight's start to the break, so mob hits on the way in or out stay out of
		# the Warden's row. The study file arrives with #167.
		var fight_start = null if in_boss else fight_start_of(_note)
		if in_boss or (fight_start != null and _note.get("warden_broken_s") == null):
			var fight_s: float = _boss_clock if in_boss else game.run.stage_time - float(fight_start)
			if amount > float(into.get("largest_hit", 0.0)):
				into["largest_hit"] = snappedf(amount, 0.1)
				into["largest_hit_source"] = source_id
				into["largest_hit_share"] = snappedf(amount / maxf(float(game.run.max_hp), 1.0), 0.001)
			if hull > float(into.get("largest_hull_hit", 0.0)):
				into["largest_hull_hit"] = snappedf(hull, 0.1)
				into["largest_hull_hit_share"] = snappedf(hull / maxf(float(game.run.max_hp), 1.0), 0.001)
			if fight_s <= FIRST_45_S:
				into["hp_lost_45s"] = snappedf(float(into.get("hp_lost_45s", 0.0)) + amount, 0.1)
				into["hull_lost_45s"] = snappedf(float(into.get("hull_lost_45s", 0.0)) + hull, 0.1)


func _on_enemy_struck(enemy: Node3D, kind: String, _force: float) -> void:
	if _note.is_empty():
		return
	# Which strikes break the Warden: the HP it had at each strike is settled against
	# the HP it has on the next tick (or zero at its break), by the kinds that struck.
	if is_instance_valid(enemy) and enemy == game.flow.warden:
		if _warden_hp_at < 0.0:
			_warden_hp_at = float(enemy.get("hp"))
		_warden_kinds[kind] = true
	if not (kind == "slam" or kind == "stomp"):
		return
	if is_instance_valid(enemy) and enemy == game.flow.warden and enemy.has_method("contact_part") \
			and enemy.contact_part(game.player.ball_position(), kind) == "cap":
		_count("cap_hits")


func _settle_warden_damage(hp_now: float) -> void:
	var dealt := maxf(0.0, _warden_hp_at - hp_now)
	if dealt > 0.0 and not _note.is_empty() and not _warden_kinds.is_empty():
		if not _note.has("warden_damage"):
			_note["warden_damage"] = {}
		var by: Dictionary = _note["warden_damage"]
		for kind in _warden_kinds:
			by[kind] = snappedf(float(by.get(kind, 0.0)) + dealt / _warden_kinds.size(), 0.1)
	_warden_hp_at = -1.0
	_warden_kinds = {}


# Under --explore-by: the stage's rogue (rogue_director.gd) and rib caches (build.gd). A woken rogue
# and a cache within RIB_NEAR come before the lit sites; once those and the event are done, the
# rogue's site and the far caches are rolled to along the park graph. A player hunting the park
# does both; the default bot never does, so its rows stay as they were. Each has a cap, as the
# activities have.
const ROGUE_SECONDS := 120.0
const RIB_SECONDS := 20.0
const RIB_NEAR := 60.0
var _rogue_done := false
var _rogue_travel := 0.0
var _rogue_travel_cap := -1.0
var _rib_skip := {}
var _rib_travel_cap := {}
var _leg_route: Array[Vector3] = []
var _leg_for := ""
var _leg_clock := 0.0


# A woken rogue is fought wherever the explorer is: it woke because the ball came near its site.
func _rogue_fight(delta: float) -> bool:
	if engage_by <= ENGAGE_BY or _rogue_done or _rogue_seen == null or game.run.stage_time > engage_by:
		return false
	if not is_instance_valid(_rogue_seen) or _rogue_seen.is_dead():
		_rogue_done = true
		return false
	_rogue_clock += delta
	if _rogue_clock > ROGUE_SECONDS:
		_rogue_done = true
		return false
	_ignore_walls = false
	# A cache leg the fight broke into is planned again from wherever the fight leaves the ball.
	_leg_for = ""
	_goal = "rogue fight"
	_fight(_rogue_seen, delta)
	return true


# A rogue not yet woken is rolled to at its site, once the lit sites are done.
func _rogue_goal(delta: float) -> bool:
	if engage_by <= ENGAGE_BY or _rogue_done or _rogue_seen != null or game.world == null or game.run.stage_time > engage_by:
		return false
	var plan: Dictionary = game.world.get("rogue_plan")
	if plan.is_empty():
		return false
	var ball: Vector3 = game.player.ball_position()
	var at: Vector3 = game.ctx.terrain.drop_point(float(plan.at.x), float(plan.at.y), 1.0)
	if _rogue_travel_cap < 0.0:
		_rogue_travel_cap = ACTIVITY_TRAVEL_SECONDS + _flat(ball, at) / ACTIVITY_TRAVEL_SPEED
	_rogue_travel += delta
	if _rogue_travel > _rogue_travel_cap or _stalled("rogue", _flat(ball, at), delta):
		_rogue_done = true
		return false
	_ignore_walls = false
	_goal = "rogue site"
	if not _leg_to("rogue", ball, at, delta):
		_act(at, _nearest_enemy(), delta)
	return true


# The nearest rib cache within `reach`: before the lit sites when it is a short detour (RIB_NEAR),
# after them at any distance. A wider first reach (150 m, 25 Oct, seeds 1-4) took a flume cache on
# 2 runs in 4 but cost the flume an activity and its rogue fight, so the lit sites keep the lead.
func _rib_goal(delta: float, reach: float) -> bool:
	if engage_by <= ENGAGE_BY or game.build == null or game.build.get("scrap") == null or game.run.stage_time > engage_by:
		return false
	var ball: Vector3 = game.player.ball_position()
	var best = null
	var best_d := INF
	for c in game.build.scrap.caches():
		var key := "rib:%d" % (c["item"] as Object).get_instance_id()
		var d := _flat(ball, c["at"])
		if not _rib_skip.has(key) and d < best_d and d <= reach:
			best_d = d
			best = c
	if best == null:
		return false
	var key := "rib:%d" % (best["item"] as Object).get_instance_id()
	if not _rib_travel_cap.has(key):
		_rib_travel_cap[key] = RIB_SECONDS + best_d / ACTIVITY_TRAVEL_SPEED
	_rib_clock[key] = float(_rib_clock.get(key, 0.0)) + delta
	if float(_rib_clock[key]) > float(_rib_travel_cap[key]) or _stalled(key, best_d, delta):
		_rib_skip[key] = true
		return false
	_ignore_walls = false
	_goal = "rib cache"
	var at: Vector3 = best["at"]
	if best_d < WAYPOINT_REACHED or not _leg_to(key, ball, at, delta):
		_act(at, _nearest_enemy(), delta)
	return true


# Whether the roll to `key` has stopped closing on it (CLOSING_M in CLOSING_SECONDS).
func _stalled(key: String, d: float, delta: float) -> bool:
	var c: Array = _closing.get(key, [d, 0.0])
	if d < float(c[0]) - CLOSING_M:
		c = [d, 0.0]
	else:
		c[1] = float(c[1]) + delta
	_closing[key] = c
	return float(c[1]) > CLOSING_SECONDS


# The park graph's path to `point`, a waypoint every FIND_LEG_M, as a field find walks it. True
# while a waypoint is still ahead; false once there is none (the caller rolls straight on) or the
# leg gains no waypoint in FIND_LEG_SECONDS.
func _leg_to(key: String, ball: Vector3, point: Vector3, delta: float) -> bool:
	if _leg_for != key:
		_leg_for = key
		_leg_route = _graph_path(ball, point)
		_leg_clock = 0.0
	while not _leg_route.is_empty() and _flat(ball, _leg_route[0]) < WAYPOINT_REACHED:
		_leg_route.pop_front()
		_leg_clock = 0.0
	if _leg_route.is_empty():
		return false
	_leg_clock += delta
	if _leg_clock > FIND_LEG_SECONDS:
		_leg_route = []
		return false
	_act(_leg_route[0], _nearest_enemy(), delta)
	return true


# The world 1 pacing check's optional rows (design-v3/pacing/world1-pacing.json content): the
# rogue's wake and break, and the rib caches the ball took. A cache that leaves the ground within
# RIB_TAKEN_M of the ball was taken; one cleared by a stage change was not. Reads only; steers nothing.
const RIB_TAKEN_M := 8.0


func _content_scan() -> void:
	if _note.is_empty():
		return
	var world = game.world
	var activities = world.get("activities") if world != null else null
	if activities != null and _note.get("pockets_drawn") == null:
		_note["pockets_drawn"] = drawn_pockets(activities.sites)
	var rogue = world.get("rogue") if world != null else null
	if rogue != null and is_instance_valid(rogue) and rogue.get_instance_id() != _rogue_id:
		_rogue_seen = rogue
		_rogue_id = rogue.get_instance_id()
		_note["rogue_woke_s"] = snappedf(game.run.stage_time, 0.01)
		_note["rogue_kind"] = String(rogue.get("kind"))
	if _rogue_id != 0 and _note["rogue_beaten_s"] == null:
		var body = instance_from_id(_rogue_id)
		if body == null or body.is_dead():
			_note["rogue_beaten_s"] = snappedf(game.run.stage_time, 0.01)
			_note["rogues_beaten"] = 1
	var scrap = game.build.get("scrap") if game.build != null else null
	if scrap == null or not scrap.has_method("caches"):
		return
	var ball: Vector3 = game.player.ball_position()
	var now := {}
	for c in scrap.caches():
		now[(c["item"] as Object).get_instance_id()] = c["at"]
	for id in now:
		if not _caches_seen.has(id):
			_note["rib_caches_placed"] = int(_note["rib_caches_placed"]) + 1
	for id in _caches_seen:
		if not now.has(id) and _flat(ball, _caches_seen[id]) < RIB_TAKEN_M:
			_note["rib_caches_taken"] = int(_note["rib_caches_taken"]) + 1
	# How close the ball came to each cache still waiting, for reading a missed one.
	# Keyed by where each was placed: a cache the magnet pulls moves.
	var closest: Dictionary = _note.get("rib_closest_m", {})
	for id in now:
		if not _caches_seen.has(id):
			_rib_spot[id] = "%.0f,%.0f" % [now[id].x, now[id].z]
		var key: String = _rib_spot.get(id, "")
		closest[key] = snappedf(minf(float(closest.get(key, INF)), _flat(ball, now[id])), 0.1)
	_note["rib_closest_m"] = closest
	_caches_seen = now


# The pockets this stage drew (pocket_draw.gd), by library id ("rim_vault", "dome_camp"), in the
# order the stage built them; [] when it drew none. Read only, so a frame read or a band can say
# which seeds met which pocket.
static func drawn_pockets(sites: Array) -> Array:
	var out: Array = []
	for s in sites:
		if s.drawn:
			out.append(String(s.interior.get("id", s.id)))
	return out


func _close_note() -> void:
	if _note.is_empty():
		return
	_note["exit_s"] = snappedf(game.run.stage_time, 0.01)
	_note["hp_lost"] = snappedf(float(_note["hp_lost"]), 0.1)
	_note["hull_lost"] = snappedf(float(_note.get("hull_lost", 0.0)), 0.1)
	_note["punch_short_s"] = snappedf(float(_note["punch_short_s"]), 0.01)
	if not _note.has("secrets_found"):
		_note["secrets_found"] = []
	_close_contact()
	stage_notes.append(_note)
	_note = {}


func _on_boss_entered() -> void:
	_close_note()
	_boss_clock = 0.0
	_seen = {}
	_evaded = {}
	_charge_read = {}
	_charge_stepped = {}
	_clash_tried = {}
	_clash_latched = {}
	_plant_state = "idle"
	_fight_phase = "charge"
	_fight_target = null
	boss_note = {"entered_run_s": snappedf(game.run.run_time, 0.01), "entry_heft": snappedf(game.run.heft(), 0.001),
		"entry_parts": game.run.parts.size(), "phases": [], "weak_point_hits": {}, "hp_lost": 0.0, "hits": 0,
		"evasions": 0, "plants": 0, "slingshots": 0, "specials": 0, "stolen": 0, "defeated_s": null,
		"hold_s": null, "hold_bound_s": null,
		"weak_opened": null, "weak_sealed": null, "weak_timed_out": null, "weak_broken": null, "weak_open_at_end": null,
		"crew_waves": null,
		"charge_reads": 0, "charge_sidesteps": 0, "charge_hits": 0, "clash_tries": 0}


# The stub bosses' phase-hold seconds (stub_boss.gd); a hull boss has none and records null.
func _boss_hold_note() -> void:
	var boss = _boss()
	if boss == null or not "hold_s" in boss:
		return
	_boss_set("hold_s", snappedf(boss.hold_s, 0.01))
	_boss_set("hold_bound_s", snappedf(boss.hold_bound_s, 0.01))
	_boss_weak_note(boss)


# The Waking's per floor phase weak-point counts, each {phase: count}, for the sweep's seal rate. Left null unless the
# fight ran with weak points (dial 1), so a dial 0 record keeps its shape and its values.
func _boss_weak_note(boss) -> void:
	if not "weak_stats" in boss or not boss.weak.active():
		return
	var stats: Dictionary = boss.weak_stats
	_boss_set("weak_opened", (stats["opened"] as Dictionary).duplicate())
	_boss_set("weak_sealed", (stats["sealed"] as Dictionary).duplicate())
	_boss_set("weak_timed_out", (stats["timed_out"] as Dictionary).duplicate())
	_boss_set("weak_broken", (stats["broken"] as Dictionary).duplicate())
	_boss_set("weak_open_at_end", (stats["open_at_end"] as Dictionary).duplicate())
	_boss_set("crew_waves", (stats["crew_waves"] as Dictionary).duplicate())


func _on_boss_phase(phase: int, phase_name: String) -> void:
	_boss_add("phases", {"phase": phase, "name": phase_name, "at_s": snappedf(_boss_clock, 0.01),
		"heft": snappedf(game.run.heft(), 0.001), "hp": snappedf(game.run.hp, 0.1)})


# --- the completionist's route ----------------------------------------------------------

# Laid once the build has laid out the stage: every scrap line end to end, nearest to
# the drop first, so its hoops are rolled through too.
func _plan() -> void:
	_planned = true
	if policy != "completionist":
		return
	var terrain = game.ctx.terrain
	var spawn: Vector3 = terrain.spawn_point(_stage)
	var beacon: Vector3 = terrain.beacon_point(_stage)
	var axis := Vector2(beacon.x - spawn.x, beacon.z - spawn.z).normalized()
	var lines: Array = terrain.scrap_lines(_stage).duplicate()
	lines.sort_custom(func(a, b): return _along(a, spawn, axis) < _along(b, spawn, axis))
	var at := Vector2(spawn.x, spawn.z)
	for line in lines:
		var from: Vector2 = line[0]
		var to: Vector2 = line[1]
		if at.distance_to(to) < at.distance_to(from):
			var swap := from
			from = to
			to = swap
		_waypoints.append(terrain.drop_point(from.x, from.y, 1.0))
		_waypoints.append(terrain.drop_point(to.x, to.y, 1.0))
		at = to
	_note["waypoints"] = _waypoints.size()


static func _along(line: Array, spawn: Vector3, axis: Vector2) -> float:
	var mid: Vector2 = ((line[0] as Vector2) + (line[1] as Vector2)) * 0.5
	return (mid - Vector2(spawn.x, spawn.z)).dot(axis)


# --- the roam: what to go for now ------------------------------------------------------

func _roam(delta: float) -> void:
	if policy == "completionist" and _chain_phase != "":
		_explorer_chain(delta)
		return
	if not _planned:
		_plan()
	_welcome_ring_at = Vector3.INF
	var warden: Node3D = game.flow.warden if is_instance_valid(game.flow.warden) else null
	if warden != null and _warden_hp_at >= 0.0:
		_settle_warden_damage(float(warden.get("hp")))
	if warden != null:
		_note["magnet_stuns"] = maxi(int(_note.get("magnet_stuns", 0)), int(warden.get("magnet_stuns") if warden.get("magnet_stuns") != null else 0))
	var crew := _gate_foe()
	if crew != null:
		_goal = "gate crew"
		_fight(crew, delta)
		return
	match policy:
		"skipper":
			if relay_stake > 0 and _relay_arm(delta):
				return
			_fight(warden, delta)
		"completionist":
			_completionist(warden, delta)
		"camper":
			_camper(warden, delta)
		"traversal":
			_traverse(delta)
		"orbit", "terrain":
			if kite == null:
				kite = BotKite.new(self)
			kite.step(delta, policy == "terrain")
		_:
			_random(warden, delta)


# The Spillway's locks (src/world/stage_locks.gd) read as a person reads them: a shut yard's
# crew comes first, and once the Warden is awake behind a shut clamp, the nearest enemy inside
# GATE_HUNT. The traversal pilot only rides.
func _gate_foe() -> Node3D:
	var gate = game.flow.get("gate")
	if gate == null or policy == "traversal":
		return null
	if gate.lock_active() and _note.get("lock_s") == null:
		_note_set("lock_s", snappedf(game.run.stage_time, 0.01))
	if not gate.lock_active() and _note.get("lock_s") != null and _note.get("unlock_s") == null:
		_note_set("unlock_s", snappedf(game.run.stage_time, 0.01))
	if gate.has_gate() and not gate.locked() and _note.get("gate_open_s") == null:
		_note_set("gate_open_s", snappedf(game.run.stage_time, 0.01))
	var ball: Vector3 = game.player.ball_position()
	if gate.lock_active():
		return gate.foe_for(ball)
	if gate.locked() and game.flow.engaged():
		return gate.foe_for(ball, GATE_HUNT)
	return null


# --- the traversal pilot -----------------------------------------------------------------

# Steers along the route, then to the beacon, and sends what it decided TRAVERSE_REACTION
# seconds later: the stick, the mouse and every press are held in a buffer for that long, so
# nothing the steering reads (position, velocity, wall rays, the stuck check) is answered
# sooner. The stick is buffered as the world direction it meant and turned back into the
# camera's frame when it goes out, because the camera has moved by then. Presses go through
# one gate: a second verb inside TRAVERSE_PRESS_GAP is dropped. It never holds fire.
func _traverse(delta: float) -> void:
	_welcome_ring_at = Vector3.INF
	var lag := int(ceil(TRAVERSE_REACTION * Engine.physics_ticks_per_second))
	var ball: Vector3 = game.player.ball_position()
	while _leg < route.size():
		var leg: Vector2 = route[_leg]
		if _flat(ball, game.ctx.terrain.drop_point(leg.x, leg.y, 1.0)) > TRAVERSE_REACHED:
			break
		_leg += 1
	var point: Vector3 = game.ctx.terrain.beacon_point(_stage)
	if _leg < route.size():
		point = game.ctx.terrain.drop_point(route[_leg].x, route[_leg].y, 1.0)
	_goal = "traverse leg %d" % _leg
	_traverse_point = point
	source.hold = {}
	source.press = {}
	_defer_look = true
	_look_delta = Vector2.ZERO
	_act(point, _traverse_hands(ball, point, delta), delta)
	_defer_look = false
	source.hold.erase("fire_held")
	var stick: Vector2 = source.hold.get("move", Vector2.ZERO)
	_out.append({"hold": source.hold, "press": source.press, "look": _look_delta, "wish": _stick_to_world(stick)})
	source.hold = {}
	source.press = {}
	if _out.size() <= lag:
		return
	var sent: Dictionary = _out.pop_front()
	var look: Vector2 = sent["look"]
	game.camera.look(Vector2(-look.x / SENSITIVITY, -look.y / SENSITIVITY))
	source.hold = sent["hold"]
	if source.hold.has("move"):
		source.hold["move"] = _world_to_stick(sent["wish"])
	source.press = sent["press"]
	# The aim moved while the press was in flight: a bite that would now land on a body is dropped.
	if source.press.has("harpoon_pressed") and "harpoon" in hands:
		var now: Dictionary = game.player.kit.aim
		if now.get("state", Augments.AIM_NONE) == Augments.AIM_NONE or now.get("body") != null:
			source.press.erase("harpoon_pressed")
	var picked: bool = source.press.has("slot_pick")
	_gate_presses()
	_traverse_click(picked)


# The optional hands, decided before the stick like every other verb. Returns the aim the camera
# turns to (the anchor the harpoon hand wants to bite), or null.
func _traverse_hands(ball: Vector3, point: Vector3, delta: float) -> Variant:
	_glide_held = false
	_hand_aim = false
	if hands.is_empty():
		return null
	if "glide" in hands:
		_glide_hand(ball, point)
	if "harpoon" in hands:
		var aim = _swing_hand(ball, point, delta)
		_hand_aim = aim != null
		return aim
	return null


# Swings from an anchor ahead, and lets the line go before it can stop the ball. It bites the
# world only: an enemy is a fight, and a body line (a Warden, an island tip, Sable's stake) winches
# the ball in and holds it, which the on_body release below would drop the tick after the bite, so
# stakes are left out of the hand rather than exempted from that release. Once hook-out lands a
# world bite also releases holds that list `hook`: the hand can then act as a hold breaker in
# traversal measurements, and that is intended.
func _swing_hand(ball: Vector3, point: Vector3, delta: float) -> Variant:
	var kit = game.player.kit
	var way := Vector3(point.x - ball.x, 0.0, point.z - ball.z)
	if way.length() < 0.5:
		return null
	way = way.normalized()
	_swing_cool -= delta
	_swing_sent -= delta
	if kit.hooked:
		_swing_clock += delta
		var anchor: Vector3 = kit.anchor
		var carried: float = game.player.planar_velocity().dot(way)
		var past: bool = Vector3(anchor.x - ball.x, 0.0, anchor.z - ball.z).dot(way) < 0.0
		if _swing_sent <= 0.0 and (kit.on_body or past or _swing_clock > SWING_HOLD_MAX \
				or (_swing_clock > SWING_GRACE and carried < SWING_CARRY)):
			_swing_sent = SWING_SENT
			source.press["harpoon_released"] = true
			_swing_cool = SWING_GAP
			return null
		_harpoon_held = true
		return null
	_swing_clock = 0.0
	if _swing_cool > 0.0 or _swing_sent > 0.0 or kit.mounted or _cast_phase != "" or game.player.frozen() \
			or not game.player.verb_ready("harpoon") or game.player.planar_velocity().length() < SWING_MIN_SPEED:
		return null
	if _swing_bites(kit.aim, ball, way):
		source.press["harpoon_pressed"] = true
		_swing_sent = SWING_SENT
		return null
	var best := Vector3.INF
	var far := 0.0
	var space = game.get_world_3d().direct_space_state
	var reach: float = game.player.tuning.f("rope_range")
	var assist: float = game.player.tuning.f("grapple_assist_deg")
	for yaw in SWING_YAWS:
		for pitch in SWING_PITCHES:
			var dir: Vector3 = (way.rotated(Vector3.UP, yaw) * cos(pitch) + Vector3.UP * sin(pitch)).normalized()
			var hit := Augments.grapple_target(space, ball + Vector3.UP * 0.8, dir, ball, reach, assist,
				Augments.WORLD_MASK | Augments.ENEMY_MASK, false)
			if _swing_bites(hit, ball, way) and (hit["point"] - ball).dot(way) > far:
				far = (hit["point"] - ball).dot(way)
				best = hit["point"]
	return {"at": best} if best != Vector3.INF else null


func _swing_bites(aim: Dictionary, ball: Vector3, way: Vector3) -> bool:
	if aim.get("state", Augments.AIM_NONE) == Augments.AIM_NONE:
		return false
	if aim.get("body") != null:
		return false
	var to: Vector3 = aim["point"] - ball
	return to.y >= SWING_ABOVE and to.length() > 0.5 and Vector3(to.x, 0.0, to.z).normalized().dot(way) >= SWING_AHEAD


# Holds glide over a thermal column, or down a long drop while it still gains toward the waypoint.
# _drive spends the air jump and holds the key once the ball falls.
func _glide_hand(ball: Vector3, point: Vector3) -> void:
	var player = game.player
	if not player.kit.on("glide") or player.state.grounded or player.kit.hooked:
		_gliding = false
		return
	var way := Vector3(point.x - ball.x, 0.0, point.z - ball.z).normalized()
	var over := _inside_thermal(ball)
	var drop: float = ball.y - _ground_point(ball.x, ball.z).y
	var gains: bool = player.planar_velocity().dot(way) >= GLIDE_GAIN
	# Glide carries a ball past a waypoint and lands it below one on a ledge it cannot climb back
	# to (Highdraft islands, kest seed 1: 143 dead stops): only with height to spare over the
	# waypoint and distance left to it.
	var room: bool = ball.y - point.y >= GLIDE_ABOVE and Vector2(point.x - ball.x, point.z - ball.z).length() >= GLIDE_NEAR
	_gliding = over or (room and gains and (drop >= GLIDE_DROP or _gliding))
	_glide_held = _gliding


# The traversal pilot's cast is one verb sent as two keys: the pick passes the press gate, and
# the click follows CAST_GAP later outside the gate. A pick the gate dropped drops the cast.
func _traverse_click(picked: bool) -> void:
	if picked:
		if source.press.has("slot_pick") and _cast_phase == "sent":
			_cast_click_tick = ticks + int(ceil(CAST_GAP * Engine.physics_ticks_per_second))
		elif _cast_phase == "sent":
			_cast_phase = ""
	if _cast_click_tick >= 0 and ticks >= _cast_click_tick:
		_cast_click_tick = -1
		source.press["fire_pressed"] = true
		_cast_phase = "release"


func _stick_to_world(stick: Vector2) -> Vector3:
	var yaw: float = game.camera.yaw
	return Vector3(cos(yaw), 0.0, -sin(yaw)) * stick.x + Vector3(-sin(yaw), 0.0, -cos(yaw)) * stick.y


func _world_to_stick(wish: Vector3) -> Vector2:
	var yaw: float = game.camera.yaw
	return Vector2(wish.dot(Vector3(cos(yaw), 0.0, -sin(yaw))), wish.dot(Vector3(-sin(yaw), 0.0, -cos(yaw))))


func _gate_presses() -> void:
	var pressed: Array = []
	for key in source.press:
		# slot_pick is an int: 0 picks slot 1 (home), -1 picks nothing.
		var value = source.press[key]
		if (value is int and value >= 0) or (value is bool and value):
			pressed.append(key)
	if pressed.is_empty():
		return
	if ticks - _last_press_tick < int(ceil(TRAVERSE_PRESS_GAP * Engine.physics_ticks_per_second)):
		source.press = {}
		return
	source.press = {pressed[0]: source.press[pressed[0]]}
	_last_press_tick = ticks
	press_ticks.append(ticks)


# Holds the gun on the Warden from CAMP_RANGE: rolls up until in range, then stops
# steering and holds the brake on the ground. Thrown or dodged inside CAMP_NEAR (on stage 3 a
# lift dropped camper seed 2 on the hive's roof, where it rode the hoist and stomped a chunk off),
# it rolls back out to CAMP_RANGE first: the camper never fights from contact range.
func _camper(target: Node3D, delta: float) -> void:
	_welcome_ring_at = Vector3.INF
	if target == null or not is_instance_valid(target):
		_goal = "beacon"
		_act(game.flow.beacon.global_position, _nearest_enemy(), delta)
		return
	var ball: Vector3 = game.player.ball_position()
	var flat: float = _flat(ball, target.global_position)
	var in_range: bool = flat <= CAMP_RANGE
	if in_range and (flat < CAMP_NEAR or (_camp_backing and flat < CAMP_RANGE * 0.8)):
		_camp_backing = true
		_goal = "camp back"
		var out := Vector3(ball.x - target.global_position.x, 0.0, ball.z - target.global_position.z)
		out = out.normalized() if out.length() > 0.1 else Vector3.RIGHT
		_act(ball + out * CAMP_RANGE, target, delta, target)
		return
	_camp_backing = false
	_goal = "camp"
	_act(ball if in_range else target.global_position, target, delta, target)
	if in_range and game.player.state.grounded:
		source.hold["brake_held"] = true


func _completionist(warden: Node3D, delta: float) -> void:
	# Give up before resuming a camp or bounty: on Tally 36428 stage 4 the
	# activities ran past ENGAGE_BY and the Warden was never reached.
	if _activity_rushed():
		if engage_by > ENGAGE_BY and _note.get("warden_fight_s") == null:
			_note["explore_clock_hit"] = true
		_fight(warden, delta)
		return
	if _rogue_fight(delta) or _rib_goal(delta, RIB_NEAR):
		return
	if _activity_goal(delta):
		return
	var event := _event_goal(delta)
	if not event.is_empty():
		_goal = event["goal"]
		_act(event["steer"], event.get("aim", null), delta)
		return
	if _rogue_goal(delta) or _rib_goal(delta, INF):
		return
	if not _waypoints.is_empty():
		_waypoint_time += delta
		var ball: Vector3 = game.player.ball_position()
		if _flat(ball, _waypoints[0]) < WAYPOINT_REACHED or _waypoint_time > WAYPOINT_SECONDS:
			_waypoints.pop_front()
			_waypoint_time = 0.0
		if not _waypoints.is_empty():
			_goal = "waypoint %d" % _waypoints.size()
			_act(_waypoints[0], _nearest_enemy(), delta)
			return
	var vault: Node3D = _vault()
	if vault != null and not _vault_done:
		_note["vault_tried"] = true
		_vault_time += delta
		if _vault_time > VAULT_SECONDS:
			_vault_done = true
		else:
			_fight(vault, delta)
			return
	_fight(warden, delta)


func _random(warden: Node3D, delta: float) -> void:
	var ball: Vector3 = game.player.ball_position()
	if warden != null and not _committed:
		_committed = _flat(ball, warden.global_position) < WANDER_COMMIT_DISTANCE or game.run.stage_time > WANDER_COMMIT_TIME
	if _committed or warden == null:
		_fight(warden, delta)
		return
	_wander_clock -= delta
	if _wander_clock <= 0.0:
		_wander_clock = rng.randf_range(WANDER_GAP.x, WANDER_GAP.y)
		var to_beacon: Vector3 = game.ctx.terrain.beacon_point(_stage) - ball
		var base := atan2(to_beacon.x, to_beacon.z)
		var angle := base + rng.randfn(0.0, WANDER_SPREAD)
		_wander_heading = Vector3(sin(angle), 0.0, cos(angle))
		if rng.randf() < 0.3:
			source.press["jump_pressed"] = true
	_goal = "wander"
	_act(ball + _wander_heading * 30.0, _nearest_enemy(), delta)


# SR10 bot arm. On a map with a relay site (the park's dam and islands), set the stake through the
# relay's own API while it is not charging (set_stakes refuses once it is, and clamps at 4), roll
# into the ring, and stay on it until it pays and the pay is taken or RELAY_ARM_SECONDS run out.
# One row per relay in the stage note's relay_stakes. True when it drove this tick.
func _relay_arm(delta: float) -> bool:
	if relay_stake <= 0:
		return false
	var world = game.world
	if world == null or world.activities == null:
		return false
	var s = world.activities.site("hold_the_relay")
	if s == null or s.relay == null or _relay_closed.has(s.id):
		return false
	var rows: Array = _note.get("relay_stakes", [])
	var row: Dictionary
	if rows.is_empty():
		s.relay.set_stakes(relay_stake)
		row = {"stage": game.run.stage, "k": s.relay.stakes, "parts_before": game.run.parts.size()}
		rows.append(row)
		_note["relay_stakes"] = rows
	else:
		row = rows[0]
	_relay_clock += delta
	var ball: Vector3 = game.player.ball_position()
	if s.started and not row.has("credit"):
		# The credit the game granted at the start (the first buy may already be spent by now).
		var activities = world.activities
		row["credit"] = snappedf(s.relay.pack_credit(activities.relay_pack_cost(s) * int(s.rule["waves"])), 0.01)
		row["rewards"] = s.relay.rewards()
	row["minibosses"] = s.minibosses_sent
	if s.done:
		row["outcome"] = "won"
		if s.pickup != null and not s.pickup_taken and _relay_clock <= RELAY_ARM_SECONDS:
			_goal = "relay pay"
			_pay_roll(s, ball, delta)
			return true
	elif _relay_clock > RELAY_ARM_SECONDS:
		row["outcome"] = "gave_up"
	else:
		_goal = "relay charge" if s.started else "relay approach"
		_act(_approach(s, ball), _nearest_enemy(), delta)
		return true
	row["parts"] = game.run.parts.size() - int(row["parts_before"])
	row["seconds"] = snappedf(_relay_clock, 0.01)
	_relay_closed[s.id] = true
	return false


# The slice's standing activities (src/world/activities.gd), nearest first: the ambush altar's
# ring fight, the cracked cache's ram and the hauler's brute, each then rolled onto for its pay.
# One target at a time, held until it is done and paid or its ACTIVITY_SECONDS run out. True when
# it drove this tick. Reads the sites' public state only, as a player reads what stands lit.
func _activity_goal(delta: float) -> bool:
	_ignore_walls = false
	var world = game.world
	if world == null or world.activities == null or world.activities.sites.is_empty():
		_activity = ""
		return false
	var activities = world.activities
	var ball: Vector3 = game.player.ball_position()
	var s = _site_by_key(activities, _activity) if _activity != "" else null
	if s != null and not _activity_open(s):
		# A field find's room is a dead end inside a dead end: leave by its open face, the way in.
		if s.has_meta("find"):
			var out: Vector2 = Vector2(s.rule.get("face", Vector2(0.0, -1.0))).normalized() * CACHE_RUNUP * 1.5
			_find_exit = _ground_point(s.global_position.x + out.x, s.global_position.z + out.y)
		s = null
		_activity = ""
	if _find_exit != Vector3.INF:
		if _flat(ball, _find_exit) < WAYPOINT_REACHED or _activity_rushed() \
				or (engage_by > ENGAGE_BY and _stalled("find_exit", _flat(ball, _find_exit), delta)):
			_find_exit = Vector3.INF
			_closing.erase("find_exit")
		else:
			_goal = "activity find exit"
			_act(_find_exit, _nearest_enemy(), delta)
			return true
	if s == null:
		var best_level := -INF
		var best := INF
		for c in activities.sites:
			if not is_instance_valid(c) or not _activity_open(c):
				continue
			# A cache whose row raises its wall to a speed tier (activities.gd BARS, W1-76) asks for a line
			# the bot does not plan; ramming it at the bot's speed would only loop the refused cue.
			if c.rule.has("bar_tier"):
				continue
			var level := roundf(c.global_position.y / LEVEL_BAND)
			# The alpha maps' camp comes after the slice's standing sites, wherever it stands:
			# on the reach its shelf pulled the explorer off the cache into a wall it cannot pass.
			if _site_has_authored_pack(c):
				level -= CAMP_LAST
			# A field find (secrets.gd FINDS) is the explorer's (--explore-by): the default completionist
			# keeps its ENGAGE_BY clock and its stall limit, so a find run out at the rush left it across
			# the dam from the sheet, wedged on the canyon rim (seed 6 on 0f56e5ce, Stack #413).
			if c.has_meta("find") and engage_by <= ENGAGE_BY:
				continue
			# The last stop: the explorer has learned the tells and checks the dead ends once the lit
			# sites are done, unless it rolls within earshot of one.
			if c.has_meta("find") and _flat(ball, c.global_position) > FIND_NEAR_M:
				level -= CAMP_LAST * 2.0
			var d := _flat(ball, c.global_position)
			if level > best_level or (level == best_level and d < best):
				best_level = level
				best = d
				s = c
		_activity = _site_key(s) if s != null else ""
		_cache_phase = "runup"
		_cache_clock = 0.0
	if s == null:
		return false
	# A deferred site picked again is retried to the end: the give-up point stops closing it, or the
	# way back in, which passes near that point, dropped it again before it was reached.
	if _activity_deferred.get(_site_key(s)) is Vector3:
		_activity_deferred[_site_key(s)] = true
	var finished: Array = []
	var secrets: Array = []
	for c in activities.sites:
		if is_instance_valid(c) and c.done:
			finished.append(c.id)
			if c.has_meta("find"):
				secrets.append(String(c.get_meta("find")))
	_note["activities_finished"] = finished
	# The field finds (secrets.gd FINDS) this stage opened, for the world 1 pacing check.
	_note["secrets_found"] = secrets
	var entered: Array = _note.get("activities_entered", [])
	if not s.id in entered:
		entered.append(s.id)
		_note["activities_entered"] = entered
	var key := _site_key(s)
	# A cache's doubled run-up point stands past ACTIVITY_NEAR, so its ram cycle counts as near work.
	var near: float = ACTIVITY_NEAR + (CACHE_RUNUP if s.id == "cracked_cache" else 0.0)
	if engage_by > ENGAGE_BY and _flat(ball, s.global_position) > near:
		if not _activity_travel_cap.has(key):
			# A retried site gets the flat cap only: the dam's rim cache, which the explorer cannot break,
			# spent a second distance-scaled cap and left the camp undone.
			var leg: float = 0.0 if _activity_deferred.has(key) else _flat(ball, s.global_position) / ACTIVITY_TRAVEL_SPEED
			_activity_travel_cap[key] = ACTIVITY_TRAVEL_SECONDS + leg
		_activity_travel[key] = float(_activity_travel.get(key, 0.0)) + delta
		if _stalled(key, _flat(ball, s.global_position), delta):
			_activity_travel[key] = INF
	else:
		_activity_time[key] = float(_activity_time.get(key, 0.0)) + delta
	if float(_activity_travel.get(key, 0.0)) > float(_activity_travel_cap.get(key, INF)) and not _activity_deferred.has(key):
		_activity_deferred[key] = ball
		_activity_travel.erase(key)
		_activity_travel_cap.erase(key)
		_closing.erase(key)
		_activity = ""
		return false
	if float(_activity_time.get(key, 0.0)) > (FIND_SECONDS if s.has_meta("find") else (SURGE_SECONDS if s.id == "surge_run" else ACTIVITY_SECONDS)) \
			or float(_activity_travel.get(key, 0.0)) > float(_activity_travel_cap.get(key, INF)):
		_activity_skip[key] = true
		_activity = ""
		return false
	if s.done:
		_goal = "activity %s pay" % s.id
		_pay_roll(s, ball, delta)
		return true
	# Authored camp packs use the altar's ring fight, regardless of the site's id.
	if _site_has_authored_pack(s) or s.id == "ambush_altar":
		var foe := _pack_foe(s, ball)
		if foe != null:
			_goal = "activity %s fight" % s.id
			_fight(foe, delta)
		else:
			_goal = "activity %s" % s.id
			_act(_approach(s, ball), _nearest_enemy(), delta)
		return true
	match s.id:
		"cracked_cache":
			_cache_ram(s, ball, delta)
		"surge_run":
			# Into the ring, up to the head while the siren winds, then gate to gate ahead of the water. A lost
			# course is not chased round again, as a lost event is not.
			var course = s.course
			if course == null or (not s.started and s.relay_cooldown > 0.0):
				_activity_skip[s.id] = true
				_activity = ""
				return false
			if s.surge_live:
				_goal = "activity surge_run gate %d" % course.model.next_gate
				# Close to a gate it aims at the gate itself: past a bend, where the line drops off the weir deck onto
				# the gap reach, a point down the line is round the corner from the gate it must take.
				var gate: Vector3 = course.next_gate_point()
				var close := Vector2(gate.x - ball.x, gate.z - ball.z).length() < SURGE_GATE_AIM_M
				_act(gate if close else course.lead_point(ball, SURGE_LEAD_M), _nearest_enemy(), delta)
			elif s.started:
				# Back from the head on the line's centre, so the run starts straight down the deck (a deck as narrow as
				# the flume's trough is not entered from the side).
				_goal = "activity surge_run head"
				var head: Vector2 = course.model.route.points[0] - course.model.route.tangent(0.0) * SURGE_RUNUP_M
				_act(Vector3(head.x, ball.y, head.y), _nearest_enemy(), delta)
			else:
				_goal = "activity surge_run ring"
				_act(_approach(s, ball), _nearest_enemy(), delta)
		"hauler_bounty":
			if s.brute != null and is_instance_valid(s.brute) and not s.brute.is_dead():
				_goal = "activity %s fight" % s.id
				_fight(s.brute, delta)
			else:
				_activity_skip[s.id] = true
				_activity = ""
				return false
		_:
			# A site with no hand here is passed over at once. hold_the_relay is _relay_arm's, armed by a stake; held, it
			# stood the explorer still for ACTIVITY_SECONDS at the park's first stage, and its heft never rose there.
			_activity_skip[s.id] = true
			_activity = ""
			return false
	return true


# Site.pack holds live enemies only after the ring starts on this base. The map
# row distinguishes an authored camp from the altar's default pack before entry.
func _site_has_authored_pack(s) -> bool:
	var map = game.ctx.terrain.map()
	if not "activity_sites" in map:
		return false
	for authored in map.activity_sites:
		for spec in [authored] + authored.get("alts", []):
			if String(spec.get("id", "")) == s.id:
				return not spec.get("pack", []).is_empty()
	return false


# The next point on the way to a site: the site itself, or the climb route when it stands on a
# shelf above the ball. Under --explore-by the park graph's path comes first, then the authored
# route: the route's straight leg from the_eye to west_rim_bench crossed the spillway chute and
# held the explorer under the rim cache's 50 m cliff, where the graph keeps to the rim (422 m).
func _approach(s, ball: Vector3) -> Vector3:
	var at: Vector3 = s.global_position
	if _climb_for != s.id:
		_climb_for = s.id
		_climb.clear()
		_route.clear()
		if engage_by > ENGAGE_BY:
			_route = _graph_path(ball, at)
			if _route.is_empty():
				_route = _route_to(s, ball)
		if _route.is_empty() and at.y - ball.y > LEVEL_BAND:
			_climb = _climb_route_any(ball, at)
	while not _route.is_empty() and _flat(ball, _route[0]) < ROUTE_REACHED:
		_route.pop_front()
		if _route.is_empty() and at.y - ball.y > LEVEL_BAND:
			_climb = _climb_route_any(ball, at)
	while not _climb.is_empty() and _flat(ball, _climb[0]) < CLIMB_REACHED:
		_climb.pop_front()
	_kicker_jump(ball)
	if not _route.is_empty():
		return _route[0]
	return at if _climb.is_empty() else _climb[0]


# The park's authored way to a site: the first route through the site's row, from its start to
# that row, entered at the point nearest the ball. The dam's rim cache stands on west_rim_bench,
# which only the routes out of the_eye reach; rolled to straight, the explorer hung on the deck's
# western edge above the pool. Empty for a field find, which walks the park graph (_find_leg), and when the map has no route through the row.
func _route_to(s, ball: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var map = game.ctx.terrain.map()
	if s.has_meta("find") or not "park" in map:
		return out
	# A live site carries its activity's name, so its row is the nearest row of that activity.
	var site_row := ""
	var site_d := INF
	for spec in map.park.get("activity_rows", []):
		var spot: Array = spec.get("at", [])
		var kinds: Array = [String(spec.get("activity", ""))]
		for alt in spec.get("alts", []):
			kinds.append(String(alt.get("activity", "")))
		if not kinds.has(s.id) or spot.size() < 2:
			continue
		var d := Vector2(float(spot[0]), float(spot[1])).distance_to(Vector2(s.global_position.x, s.global_position.z))
		if d < site_d:
			site_d = d
			site_row = String(spec.get("site", ""))
	if site_row == "":
		return out
	var rows := {}
	for r in map.park.get("park_rows", []):
		rows[String(r.get("id", ""))] = r
	for route in map.park.get("routes", []):
		var ids: Array = [route.get("from", "")]
		ids.append_array(route.get("via", []))
		var end := ids.find(site_row)
		if end < 0:
			continue
		for i in end + 1:
			var r = rows.get(String(ids[i]))
			if r == null or not r.has("at"):
				continue
			var p: Vector3 = _ground_point(float(r.at[0]), float(r.at[1]))
			if out.is_empty() or _flat(out[-1], p) > ROUTE_REACHED:
				out.append(p)
		break
	var nearest := 0
	for i in out.size():
		if _flat(ball, out[i]) < _flat(ball, out[nearest]):
			nearest = i
	return out.slice(nearest)


# A grid path over the terrain's heights from the ball to the site that never climbs a step
# steeper than slope (CLIMB_SLOPE unless given; falling is free), every other cell kept. Empty when there is none.
# A cell costs more the further it drops to a neighbour, so a route up a ramp keeps to its middle,
# not the rim of its skirt where a ball cutting the corner at the foot slides back to the deck.
# Each step's rise is read on both of its halves (the heights are sampled at half a step), so a
# face narrower than CLIMB_STEP is not averaged into a gentle slope: the Highdraft ramp's 3 m side
# skirt passed as a climbable step and held Tarn below the Warden's island for a whole stage.
# A park kicker is a placed wedge the terrain's heights do not hold, so its ramp is laid over them
# and its lip carries a one-way launch edge KICKER_LAUNCH past it: the Flume's warden exit rises
# 14 m up drum_lip_kicker to its lip on the gate terrace's edge, a way the heights alone never had.
func _climb_route(from: Vector3, to: Vector3, slope := CLIMB_SLOPE) -> Array[Vector3]:
	var terrain = game.ctx.terrain
	var lo := Vector2(minf(from.x, to.x), minf(from.z, to.z)) - Vector2.ONE * CLIMB_PAD
	var hi := Vector2(maxf(from.x, to.x), maxf(from.z, to.z)) + Vector2.ONE * CLIMB_PAD
	var nx := int(ceilf((hi.x - lo.x) / CLIMB_STEP)) + 1
	var nz := int(ceilf((hi.y - lo.y) / CLIMB_STEP)) + 1
	var hx := 2 * nx - 1
	var legacy := _mind_slope()
	var graph := AStar2D.new()
	graph.reserve_space(nx * nz)
	var half := PackedFloat32Array()
	half.resize(hx * (2 * nz - 1))
	var kickers := _kickers_within(lo, hi)
	for j in 2 * nz - 1:
		for i in hx:
			var p := lo + Vector2(i, j) * CLIMB_STEP * 0.5
			half[j * hx + i] = maxf(terrain.height(p.x, p.y), _kicker_height(kickers, p))
	for j in nz:
		for i in nx:
			graph.add_point(j * nx + i, lo + Vector2(i, j) * CLIMB_STEP)
	for j in nz:
		for i in nx:
			var a := j * nx + i
			for step in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]:
				var bi: int = i + step.x
				var bj: int = j + step.y
				if bi < 0 or bi >= nx or bj >= nz:
					continue
				var b := bj * nx + bi
				var ha: float = half[2 * j * hx + 2 * i]
				var hm: float = half[(2 * j + step.y) * hx + 2 * i + step.x]
				var hb: float = half[2 * bj * hx + 2 * bi]
				var run := Vector2(step).length() * CLIMB_STEP * 0.5
				var up := maxf(hm - ha, hb - hm) / run
				var down := maxf(ha - hm, hm - hb) / run
				var drop := absf(hb - ha) / CLIMB_STEP
				var high := a if ha > hb else b
				graph.set_point_weight_scale(high, maxf(graph.get_point_weight_scale(high), 1.0 + drop))
				if legacy:
					# Mind stage: the pre-13c94abc test, one slope from the end heights.
					up = (hb - ha) / (run * 2.0)
					if absf(up) <= slope:
						graph.connect_points(a, b)
					elif up > 0.0:
						graph.connect_points(b, a, false)
					else:
						graph.connect_points(a, b, false)
				elif up <= slope + SLOPE_SLACK and down <= slope + SLOPE_SLACK:
					graph.connect_points(a, b)
				elif up <= slope + SLOPE_SLACK:
					graph.connect_points(a, b, false)
				elif down <= slope + SLOPE_SLACK:
					graph.connect_points(b, a, false)
	# Each kicker's lip and landing are two more points: the ramp's cells climb to the lip, the lip
	# launches one way to the landing, and the landing joins the cells beside it on its own level.
	var lifted := {}
	var lips := {}
	for k in kickers:
		var lip: Vector3 = k["lip"]
		var land2: Vector2 = Vector2(lip.x, lip.z) + Vector2(k["dir"].x, k["dir"].z) * KICKER_LAUNCH
		var land_y: float = terrain.height(land2.x, land2.y)
		if land_y > lip.y + CLIMB_LEVEL:
			continue
		var lip_id := graph.get_available_point_id()
		graph.add_point(lip_id, Vector2(lip.x, lip.z))
		var land_id := graph.get_available_point_id()
		graph.add_point(land_id, land2)
		graph.connect_points(lip_id, land_id, false)
		lifted[lip_id] = lip.y
		lifted[land_id] = land_y
		lips[lip_id] = true
		for j in nz:
			for i in nx:
				var c := lo + Vector2(i, j) * CLIMB_STEP
				var hc: float = half[2 * j * hx + 2 * i]
				var to_lip := c.distance_to(Vector2(lip.x, lip.z))
				if to_lip <= CLIMB_STEP * 1.5 and lip.y - hc <= (slope + SLOPE_SLACK) * maxf(to_lip, 0.01) \
						and hc - lip.y <= slope * maxf(to_lip, 0.01):
					graph.connect_points(j * nx + i, lip_id, false)
				var to_land := c.distance_to(land2)
				if to_land <= CLIMB_STEP * 1.5 and absf(hc - land_y) <= slope * maxf(to_land, 0.01):
					graph.connect_points(land_id, j * nx + i)
	var start := graph.get_closest_point(Vector2(from.x, from.z))
	var goal := graph.get_closest_point(Vector2(to.x, to.z))
	for mouth in _cable_mouths():
		var reach: float = mouth["radius"] + CABLE_CLEAR
		var top: Vector3 = mouth["at"]
		for j in range(maxi(0, floori((top.z - reach - lo.y) / CLIMB_STEP)), mini(nz, ceili((top.z + reach - lo.y) / CLIMB_STEP) + 1)):
			for i in range(maxi(0, floori((top.x - reach - lo.x) / CLIMB_STEP)), mini(nx, ceili((top.x + reach - lo.x) / CLIMB_STEP) + 1)):
				var id := j * nx + i
				var c := lo + Vector2(i, j) * CLIMB_STEP
				if id != start and id != goal and Vector3(c.x, half[2 * j * hx + 2 * i] + 1.0, c.y).distance_to(top) <= reach:
					graph.set_point_disabled(id)
	var ids := graph.get_id_path(start, goal)
	var out: Array[Vector3] = []
	_route_lips.clear()
	# Every cell on a ramp and the one before it is kept: cut between kept cells, the line from the
	# floor to a ramp cell crosses the wedge's side face, which stands up to its full rise.
	var ramp := []
	for id in ids:
		var at := graph.get_point_position(id)
		ramp.append(not lifted.has(id) and _kicker_height(kickers, at) > terrain.height(at.x, at.y) + CLIMB_LEVEL)
	for k in range(1, ids.size()):
		var id: int = ids[k]
		var at := graph.get_point_position(id)
		if lifted.has(id):
			out.append(Vector3(at.x, float(lifted[id]) + 1.0, at.y))
			if lips.has(id):
				_route_lips.append(out.back())
		elif k % 2 == 1 or ramp[k] or (k + 1 < ids.size() and ramp[k + 1]):
			out.append(_ground_point(at.x, at.y))
	return out


# Each cable's high end on this stage's map and its catch radius.
func _cable_mouths() -> Array:
	var out := []
	var map = game.ctx.terrain.map()
	if map == null or not "contraptions" in map:
		return out
	for spec in map.contraptions:
		if spec["kind"] == "cable":
			out.append({"at": spec["from"], "radius": float(spec["radius"])})
	return out


# _climb_route at CLIMB_SLOPE, then at each CLIMB_SLOPE_RETRY limit until one finds a way.
func _climb_route_any(from: Vector3, to: Vector3) -> Array[Vector3]:
	var out := _climb_route(from, to)
	for slope in CLIMB_SLOPE_RETRY:
		if not out.is_empty():
			break
		out = _climb_route(from, to, slope)
	return out


# The kickers of this stage's park map whose footprint reaches the box lo..hi, greybox or seated on a
# ride piece (the seat keeps the row's footprint and lip height): each one's placed transform, its
# half width and half length, its rise and its lip (top, at the facing end).
func _kickers_within(lo: Vector2, hi: Vector2) -> Array:
	var out := []
	var terrain = game.ctx.terrain
	var map = terrain.map()
	if map == null or not "park" in map or not terrain.has_method("geometry_root"):
		return out
	var root: Node3D = terrain.geometry_root(terrain.stage)
	if root == null:
		return out
	for row in map.park.get("park_rows", []):
		if row.get("element") != "kicker":
			continue
		var node := root.find_child("Park_" + String(row["id"]), true, false) as Node3D
		if node == null:
			continue
		var xf: Transform3D = node.global_transform
		var half_len := float(row["size"][0]) * 0.5
		var reach := Vector2(float(row["size"][0]), float(row["size"][2])).length() * 0.5
		var at := Vector2(xf.origin.x, xf.origin.z)
		if at.x + reach < lo.x or at.x - reach > hi.x or at.y + reach < lo.y or at.y - reach > hi.y:
			continue
		out.append({"xf": xf, "hw": float(row["size"][2]) * 0.5, "hl": half_len, "rise": float(row["size"][1]),
			"dir": xf.basis.z.normalized(), "lip": xf * Vector3(0.0, float(row["size"][1]), half_len)})
	return out


# The top of the highest kicker ramp over a ground point, or -INF off every kicker.
static func _kicker_height(kickers: Array, p: Vector2) -> float:
	var top := -INF
	for k in kickers:
		var xf: Transform3D = k["xf"]
		var local: Vector3 = xf.affine_inverse() * Vector3(p.x, xf.origin.y, p.y)
		if absf(local.x) <= float(k["hw"]) and absf(local.z) <= float(k["hl"]):
			top = maxf(top, xf.origin.y + float(k["rise"]) * (local.z + float(k["hl"])) / (2.0 * float(k["hl"])))
	return top


# Past ENGAGE_BY on a map with standing activities, only the Warden is left to do.
func _activity_rushed() -> bool:
	var world = game.world
	if world == null or world.activities == null or world.activities.sites.is_empty():
		return false
	return game.run.stage_time > engage_by


# A site's key for the bot's timers and skips: its id, "find:<id>" for a field find, or "door:<id>"
# for the timed door, so the stage's finds, door and ordinary cracked cache are worked one by one.
func _site_key(s) -> String:
	if s.has_meta("find"):
		return "find:%s" % s.get_meta("find")
	return "door:%s" % s.id if s.has_meta("door") else String(s.id)


func _site_by_key(activities, key: String):
	for c in activities.sites:
		if is_instance_valid(c) and _site_key(c) == key:
			return c
	return null


# A site the bot may still work: not given up, and either unfinished or with its pay on the ground.
func _activity_open(s) -> bool:
	if _activity_skip.has(_site_key(s)):
		return false
	var put_off = _activity_deferred.get(_site_key(s))
	if put_off is Vector3 and _flat(game.player.ball_position(), put_off) < ACTIVITY_RETRY_MOVE:
		return false
	return not s.done or (s.pickup != null and not s.pickup_taken)


func _pack_foe(s, ball: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for enemy in s.pack:
		if is_instance_valid(enemy) and not (enemy.has_method("is_dead") and enemy.is_dead()):
			var d := _flat(ball, enemy.global_position)
			if d < best_d:
				best_d = d
				best = enemy
	return best


# The pay is taken by a ball that rolls onto it, not one standing on it: step off first.
func _pay_roll(s, ball: Vector3, delta: float) -> void:
	if s.pickup == null:
		return
	var at: Vector3 = s.pickup.global_position
	var steer := at
	if s.inside_pickup or _flat(ball, at) < 1.0:
		steer = at + Vector3(PAY_BACKOFF, 0.0, 0.0)
	_act(steer, _nearest_enemy(), delta)


# The cache breaks to a ram at 0.85 x cruise square into its face: out to a run-up point on the open
# side, then at the wall along its axis with the wall-avoiding turn off.
func _cache_ram(s, ball: Vector3, delta: float) -> void:
	var out: Vector3 = s.global_basis.z
	out.y = 0.0
	out = out.normalized()
	# Under --explore-by a far cache is rolled to first: the run-up and ram cycle crept the explorer
	# about 30 m a cycle toward the dam's rim cache, 1,075 m from the drop, and never reached it.
	# A field find has its own graph leg (_find_leg) in the run-up.
	if engage_by > ENGAGE_BY and not s.has_meta("find") and _flat(ball, s.global_position) > ACTIVITY_NEAR + CACHE_RUNUP:
		_goal = "activity %s approach" % s.id
		_act(_approach(s, ball), _nearest_enemy(), delta)
		return
	_cache_clock += delta
	if _cache_phase == "runup":
		# Under --explore-by the run-up is twice as long: from 24 m the rim cache's uphill ram met its wall at about 9 m/s.
		var runup: float = CACHE_RUNUP * (2.0 if engage_by > ENGAGE_BY else 1.0)
		var point: Vector3 = _ground_point(s.global_position.x + out.x * runup, s.global_position.z + out.z * runup)
		_goal = "activity %s runup" % s.id
		# A field find stands at the end of a dead end, so the line there is the park graph's path,
		# not a straight heading across the slopes between.
		if s.has_meta("find") and _find_leg(s, ball, point, delta):
			return
		# From far off, square along the ball's own latitude first, so the line to the run-up
		# does not cut across the shelf's edge.
		var heading := point
		if _flat(ball, point) > CACHE_STAGE and absf(ball.z - point.z) > CACHE_STAGE:
			heading = _ground_point(point.x, ball.z)
		_act(heading, null, delta)
		if _flat(ball, point) < 5.0 or _cache_clock > CACHE_RUNUP_SECONDS:
			_cache_phase = "ram"
			_cache_clock = 0.0
			if engage_by > ENGAGE_BY:
				var key := _site_key(s)
				_ram_tries[key] = int(_ram_tries.get(key, 0)) + 1
				if int(_ram_tries[key]) > RAM_TRIES:
					_activity_skip[key] = true
					_activity = ""
		return
	_goal = "activity %s ram" % s.id
	_ignore_walls = true
	var through: Vector3 = s.global_position - out * 4.0
	_act(Vector3(through.x, ball.y, through.z), null, delta, null, false)
	# The doubled run-up gets a doubled ram: 3 s from 48 m out stopped about 9 m short of the
	# flume bend cache's wall, and the explorer cycled run-up and ram there for minutes.
	if _cache_clock > CACHE_RAM_SECONDS * (2.0 if engage_by > ENGAGE_BY else 1.0):
		_cache_phase = "runup"
		_cache_clock = 0.0


# Follows the park graph's path from the ball to a field find's run-up point, a waypoint every
# FIND_LEG_M. True while a waypoint is still ahead; the run-up takes over from the last one.
func _find_leg(s, ball: Vector3, point: Vector3, delta: float) -> bool:
	var key := _site_key(s)
	if _find_route_for != key:
		_find_route_for = key
		_find_route = _graph_path(ball, point)
		_find_leg_clock = 0.0
	while not _find_route.is_empty() and _flat(ball, _find_route[0]) < WAYPOINT_REACHED:
		_find_route.pop_front()
		_find_leg_clock = 0.0
	if _find_route.is_empty():
		return false
	_find_leg_clock += delta
	if _find_leg_clock > FIND_LEG_SECONDS:
		_activity_skip[key] = true
		_activity = ""
		_find_route = []
		return true
	_cache_clock = 0.0
	_goal = "activity %s path %d" % [s.id, _find_route.size()]
	_act(_find_route[0], _nearest_enemy(), delta)
	return true


func _graph_path(from: Vector3, to: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var graph = game.world.activities.get("_graph") if game.world != null and game.world.activities != null else null
	if graph == null:
		return out
	var start: int = graph.nearest(Vector2(from.x, from.z))
	var goal: int = graph.nearest(Vector2(to.x, to.z))
	var prev: PackedInt32Array = graph.search_prev(start)["prev"]
	var nodes: Array[int] = []
	var at := goal
	while at != -1 and at != start and nodes.size() < 4096:
		nodes.push_front(at)
		at = prev[at]
	if at != start:
		return out
	var since := 0.0
	var last: Vector3 = graph.position(start)
	for node in nodes:
		var p: Vector3 = graph.position(node)
		since += _flat(last, p)
		last = p
		if since >= FIND_LEG_M:
			out.append(p)
			since = 0.0
	return out


# The stage's participatory event, when the completionist should be on it: its ring
# while armed, then the event's own target while live. Empty when there is none.
func _event_goal(delta: float) -> Dictionary:
	var world = game.world
	if world == null or world.events == null:
		return {}
	for offer in world.events.offers:
		var id: String = offer["id"]
		if _event_skip.has(id):
			continue
		var phase: int = offer["phase"]
		var model = offer["model"]
		if phase == EventDirector.LIVE:
			return {"goal": "live " + id, "steer": _live_target(id, model), "aim": _nearest_enemy()}
		if phase == EventDirector.ANNOUNCED or phase == EventDirector.ARMED:
			if game.run.stage_time > EVENT_LATEST + maxf(0.0, engage_by - ENGAGE_BY):
				continue
			_event_time[id] = float(_event_time.get(id, 0.0)) + delta
			if _event_time[id] > EVENT_PURSUIT_SECONDS:
				_event_skip[id] = true
				continue
			var ring: Vector2 = model.ring
			return {"goal": "ring " + id, "steer": game.ctx.terrain.drop_point(ring.x, ring.y, 1.0), "aim": _nearest_enemy()}
		if phase == EventDirector.COOLDOWN:
			# One attempt each: a lost event is not chased round again.
			_event_skip[id] = true
	return {}


func _live_target(id: String, model) -> Vector3:
	var ball: Vector3 = game.player.ball_position()
	match id:
		"scrap_stampede":
			return model.hauler_position()
		"surge_run":
			var next: int = clampi(model.next_gate, 0, model.gates.size() - 1)
			var g: Vector2 = model.gates[next]
			return game.ctx.terrain.drop_point(g.x, g.y, 1.0)
		"hold_the_relay":
			var relay: Vector2 = model.relay
			var out := Vector2(ball.x - relay.x, ball.z - relay.y)
			if out.length() < 0.5:
				out = Vector2(1.0, 0.0)
			var around := out.normalized().rotated(0.7) * 12.0
			return game.ctx.terrain.drop_point(relay.x + around.x, relay.y + around.y, 1.0)
	var ring: Vector2 = model.ring
	return game.ctx.terrain.drop_point(ring.x, ring.y, 1.0)


# --- fighting a plated lock ------------------------------------------------------------

# Combat's plating_of first: it subtracts shred, so a stripped Warden reads as rammable.
func _plating(target: Node3D) -> float:
	var spawner = game.ctx.spawner
	if spawner != null and spawner.has_method("plating_of"):
		return float(spawner.plating_of(target))
	if target.has_method("plating_now"):
		return float(target.plating_now())
	return 0.0


# Ram laps with the gun on it when punch reaches the plating; the lock's weak point when
# it does not.
func _fight(target: Node3D, delta: float) -> void:
	_welcome_ring_at = Vector3.INF
	if target == null or not is_instance_valid(target):
		# No lock stands (an unsealed stage): roll into the beacon's ring.
		_goal = "beacon"
		_act(game.flow.beacon.global_position, _nearest_enemy(), delta)
		return
	if target != _fight_target:
		_fight_target = target
		_fight_phase = "charge"
		_reset_charge_watch()
	# The bot's own commitment to the Warden: a completionist or a wanderer can wake it
	# (warden_engaged) on the way past long before it turns to fight.
	if target == game.flow.warden and _note.get("warden_fight_s") == null:
		_note["warden_fight_s"] = snappedf(game.run.stage_time, 0.01)
		_note["warden_fight_heft"] = snappedf(game.run.heft(), 0.001)
		# The pacing check's tell: the explorer turned because --explore-by ran out, not because
		# the park had nothing left it could do (a park read at the clock is the clock's length).
		if engage_by > ENGAGE_BY and not _note.has("explore_clock_hit"):
			_note["explore_clock_hit"] = false
	var short: bool = _punch_seen < _plating(target)
	if short:
		_count("punch_short_s", delta)
	_note_shred(target, delta)
	if _anchor_warden(target) and (_kit("harpoon") or _sheet_warden(target)):
		_anchor_fight(target, short, delta)
		return
	_ground_fight(target, short, delta)


# The fight on the ground: the caps loop when punch is short of a caps Warden, else ram laps.
func _ground_fight(target: Node3D, short: bool, delta: float) -> void:
	var caps: bool = target.has_method("cap_points") and not (target.cap_points() as Array).is_empty()
	if caps and short and _kit("weak_points"):
		_goal = "caps %s" % target.get("kind")
		_cap_loop(target, delta)
		return
	_goal = "fight %s %s%s" % [target.get("kind"), _fight_phase, " short" if short else ""]
	_ram_laps(target, _aim_node(target, short), delta)


# --- the latch arm (unit KF-BOT; wardens/swarm.md, mind.md and reactor.md section 4) -----------
# Against a Warden that is a harpoon anchor the fight is two jobs. While the body stands in ram
# reach it is the ground fight (_ground_fight; _ram_laps leaves the body-line smash hand out, since
# the anchor refuses a haul outside the stagger). While the body is hung out of reach (the swarm's
# hive rising or at its high dwell) the ball bites a hardpoint from the ground or the air, rides the
# line with the harpoon held (the winch down to the anchor's minimum rope) and fires its weapon at
# the body. A shrug or a snip cuts the line and the ball keeps its velocity, so the hand only bites
# again when a window is open; the hive's stop throws the ball and it bites again from the air. When
# the body is back down and still, the line lets go and the ground fight resumes, unless the posture
# bar reads LINE_FINISH or more: then the ball takes the line from where it stands and fires from it,
# so the stagger opens with it hanging (the high dwell's latch window, swarm.md section 4).
# In a stagger every hardpoint holds and Ctrl hauls (Augments.haul_open), and a haul's smash on the
# open point always takes a chunk. A ball on the line over the open point hauls at once: the drop
# finisher (the swarm's brake-drop carries a hanging ball over the dropped queen). One below it
# waits DROP_WAIT for the drop to carry it over, then hauls from where it hangs. Off the line the
# ball rams the open point and jumps beside it once per stagger; over the point in the air it bites
# and hauls, the drop again, and back on the ground it bites from there and hauls.
# It reads what a player sees: the body's position and motion, the line, the stagger and the open point.
func _anchor_warden(target) -> bool:
	return target != null and is_instance_valid(target) and target.get("harpoon_anchor") == true


# The dam reactor's spillway sheet: its hand releases the hook and breaks the Warden by ram, so
# a band without the harpoon still runs it.
func _sheet_warden(target: Node3D) -> bool:
	return target.get("family") == "reactor" and target.get("mounting") == "dam_face" \
			and target.spec.get("park_landmark", false) and target.mount_driver != null \
			and target.mount_driver.has_method("sheet_live")


func _anchor_fight(target: Node3D, short: bool, delta: float) -> void:
	var kit = game.player.kit
	var ball: Vector3 = game.player.ball_position()
	var at: Vector3 = target.global_position
	if target != _anchor_target:
		_anchor_target = target
		_anchor_last_y = at.y
		_anchor_lined = false
		_anchor_below = 0.0
		_haul_made = false
		_haul_pressed_above = false
		_drop_jumped = false
		_anchor_seen_hung = false
	_anchor_vy = (at.y - _anchor_last_y) / maxf(delta, 0.0001)
	_anchor_last_y = at.y
	var staggered: bool = target.staggered()
	_anchor_seen_hung = _anchor_seen_hung or _anchor_hung(target)
	_watch_haul(target, staggered)
	var lined: bool = kit.hooked and kit.on_body and kit.anchor_body == target
	if lined and not _anchor_lined:
		_count("latch_bites")
		if not game.player.state.grounded:
			_count("latch_bites_air")
	_anchor_lined = lined
	if _sheet_warden(target):
		var sheet = target.mount_driver
		var dir: Vector3 = sheet.sheet_dir if sheet.sheet_dir != Vector3.ZERO else sheet._face_heading(target)
		var runup: float = minf(RUNUP, float(sheet.SHEET_RUN) - RUNUP_EDGE)
		var foot: Vector3 = at + dir * runup
		var live: bool = sheet.sheet_live()
		if kit.hooked:
			source.press["harpoon_released"] = true
		var until_pulse: float = target._charge_len - target._charge_time if target._charging else target.pulse_cycle() - target._pulse_clock
		if live and sheet.entered_sheet_cycle == sheet.gates_opened and game.player.body().get_colliding_bodies().has(target):
			_fight_phase = "sheet return %d" % sheet.gates_opened
		var rammed: bool = _fight_phase == "sheet return %d" % sheet.gates_opened
		# In a stagger a second ram in the same live sheet is the break, so the ball goes again.
		var launching: bool = (live and (not rammed or staggered)) or (not live and target._charging and until_pulse <= DROP_WAIT)
		var timed := _sheet_timed()
		if not timed:
			# Below the full kit the hand plays by sight (skill_band.gd): an open sheet seen for the
			# band's reaction and read this cycle, and the stagger re-ram only with the base kit.
			if not live:
				_sheet_live_s = -1.0
			elif _sheet_live_s < 0.0:
				_sheet_live_s = 0.0
			else:
				_sheet_live_s += delta
			var seen: bool = live and _sheet_live_s >= _reaction() \
					and band.reads(target.get_instance_id() * 1000 + int(sheet.gates_opened))
			launching = seen and (not rammed or (staggered and _kit("weak_points")))
		var steer: Vector3 = target.family_point_at() if launching else _ground_point(foot.x, foot.z)
		_harpoon_held = false
		_harpoon_commit = false
		_anchor_below = 0.0
		if _flat(ball, foot) > SHEET_HAND_REACH:
			# The roll to the dam is an ordinary roll, boosts and all; the sheet hand's cruise-capped
			# stick starts at the apron.
			_goal = "roll to spillway sheet"
			_act(steer, target, delta, target)
			return
		_goal = "ride spillway sheet" if live else "wait spillway sheet"
		if trace and ticks % (Engine.physics_ticks_per_second / 4) == 0:
			var bv: Vector3 = game.player.body().linear_velocity
			print("    sheet t=%.2f live=%s launch=%s phase=%s ball=(%.1f, %.1f, %.1f) v=(%.1f, %.1f, %.1f) grounded=%s posture=%.1f staggered=%s entered=%d gates=%d riding=%s foot=(%.1f, %.1f)" % [
				game.run.stage_time, live, launching, _fight_phase, ball.x, ball.y, ball.z, bv.x, bv.y, bv.z,
				game.player.state.grounded, target.posture(), staggered, sheet.entered_sheet_cycle, sheet.gates_opened, sheet.riding, foot.x, foot.z])
		var boost_clock := _boost_clock
		var ignore_walls := _ignore_walls
		_boost_clock = maxf(_boost_clock, delta)
		_ignore_walls = launching
		_slow_time = 0.0
		_detour_time = 0.0
		_act(steer, target, delta, target, not timed)
		_ignore_walls = ignore_walls
		_boost_clock = boost_clock
		if timed and (staggered or float(target.posture()) >= SHEET_HOLD_FIRE):
			# Near a full bar, and in a stagger, any hit but the sheet ram only opens or spends a
			# stagger that resets the bar (Tarn's claw, seed 3): the weapon, casts and ultimate wait.
			source.hold.erase("fire_held")
			source.press.erase("fire_pressed")
			source.press.erase("ultimate_pressed")
		var offset := Vector3(steer.x - ball.x, 0.0, steer.z - ball.z)
		var planar: Vector3 = game.player.planar_velocity()
		var desired := offset.normalized() * minf(game.player.tuning.f("cruise"), offset.length() * RUNUP_DROP)
		var change := desired - planar
		var wish := change.normalized() if change.length() > game.player.tuning.RADIUS / RUNUP_DROP else Vector3.ZERO
		var yaw: float = game.camera.yaw
		var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		source.hold["move"] = Vector2(wish.dot(right), wish.dot(forward))
		if not launching:
			source.press.erase("shift_pressed")
			source.hold.erase("shift_held")
			_boost_clock = 0.0
			_shift_left = 0.0
			if game.player.state.grounded and _flat(ball, foot) <= RUNUP_EDGE:
				source.hold["brake_held"] = true
		else:
			source.hold.erase("brake_held")
			if live and ball.y >= target.family_point_at().y:
				source.hold["brake_held"] = true
			# The go verb fires along the aim, so a rolling ball waits until it rolls straight at the
			# core: pressed mid-turn it threw the ball wide of the sheet (Tally's surge, seed 4). It
			# never fires while the ball still drifts away from the core, however slowly.
			var at_core: bool = planar.dot(dir) <= 0.0 \
					and (planar.length() <= 1.0 or planar.normalized().dot(offset.normalized()) >= SHEET_LAUNCH_LINED)
			if at_core and _boost_clock <= 0.0 and game.player.state.grounded and game.player.verb_ready("boost"):
				source.press["shift_pressed"] = true
				source.hold["shift_held"] = true
				_boost_clock = BOOST_GAP
				_shift_left = SHIFT_HOLD
		return
	if lined:
		_anchor_ride(target, staggered, ball, delta)
		return
	_anchor_below = 0.0
	if kit.hooked:
		# A line on anything else (the reticle reached scenery first): let it go.
		source.press["harpoon_released"] = true
	if staggered:
		_anchor_open(target, short, ball, delta)
		return
	var finish := _line_finish(target)
	if not _anchor_hung(target) and not finish:
		_ground_fight(target, short, delta)
		return
	_goal = "latch %s%s" % [target.get("kind"), " finish" if finish else ""]
	if not kit.hooked:
		_anchor_bite(target, ball)
	# From the ground the camera looks up about 30 degrees at most: wait out from under the body.
	var away := Vector3(ball.x - at.x, 0.0, ball.z - at.z)
	if away.length() < 0.5:
		away = Vector3.FORWARD
	var standoff := clampf((at.y - ball.y) * LATCH_STANDOFF, LINE_FINISH_STANDOFF if finish else 0.0, LATCH_STANDOFF_MAX)
	_act(at + away.normalized() * standoff, target, delta, target)


# Whether the posture bar is high enough that the stagger should open with the ball on the line.
# Only on a mounting the ball has seen carry the body out of ram reach: a body that never leaves the
# ground (the alpha stage-5 hand before KD5 hangs it) staggers on the ram, and the line would only
# trade rams for shots.
func _line_finish(target: Node3D) -> bool:
	return _anchor_seen_hung and target.has_method("posture") and float(target.posture()) >= LINE_FINISH


# Whether the anchor's body is out of ram reach: rising, or standing HUNG_ABOVE over the ground
# under it and not on its way down.
func _anchor_hung(target: Node3D) -> bool:
	var at: Vector3 = target.global_position
	var floor_y: float = _ground_point(at.x, at.z).y - 1.0
	return _anchor_vy > ANCHOR_MOVING or (at.y - floor_y > HUNG_ABOVE and _anchor_vy > -ANCHOR_MOVING)


# The bite on a hardpoint, from the ground or the air, when the reticle holds the body in reach.
# Withheld where the player discards the press, as _harpoon_hand withholds it.
func _anchor_bite(target: Node3D, ball: Vector3) -> void:
	var kit = game.player.kit
	var swallowed: bool = game.player.frozen() or kit.slingshot.charging
	var special = game.player.abilities.gauge(AbilityState.SPECIAL)
	if special != null and special.charging:
		swallowed = true
	if swallowed or kit.rewind_left > 0.0 or kit.aim.get("body") != target or ball.distance_to(target.global_position) > LATCH_REACH:
		return
	_cast(3)
	source.press["harpoon_pressed"] = true
	_harpoon_held = true
	_count("latch_presses")


# The open point off the line: ram it (a fast ram shatters too) and jump beside it once per
# stagger (the air jump at the top when still short of it); in the air over it, bite (the drop);
# past the top of the air jump still short of it, landed again, or with the point out of jump
# reach, bite from there.
func _anchor_open(target: Node3D, short: bool, ball: Vector3, delta: float) -> void:
	var point := _open_point(target)
	var grounded: bool = game.player.state.grounded
	var spent: bool = _drop_jumped and not grounded and game.player.state.air_actions <= 0 and game.player.state.velocity.y < 0.0
	# A point beyond the jump's reach (the park stage-3 Warden staggers on a floor 7 to 15 m over
	# the ball's ground) is bitten from where the ball is.
	var beyond_jump := point.y - ball.y > DROP_REACH_UP
	var bite := (not grounded and ball.y > point.y + DROP_ABOVE) or spent or (grounded and _drop_jumped) or beyond_jump
	_ground_fight(target, short, delta)
	_goal = "drop climb"
	if bite:
		_anchor_bite(target, ball)
	elif grounded and _flat(ball, point) < DROP_JUMP_REACH and game.player.verb_ready("jump"):
		source.press["jump_pressed"] = true
		_drop_jumped = true
	elif not grounded and _drop_jumped and game.player.state.velocity.y < 1.0 and game.player.state.air_actions > 0:
		# Short of the point at the top of the jump: the air jump.
		source.press["jump_pressed"] = true


func _open_point(target: Node3D) -> Vector3:
	return target.family_point_at() if target.has_method("family_point_at") else target.global_position


# On the line: hold it, fire at the body, let go when the body is back down and still. In the
# stagger, haul: at once from over the open point (the drop), else after DROP_WAIT.
func _anchor_ride(target: Node3D, staggered: bool, ball: Vector3, delta: float) -> void:
	var kit = game.player.kit
	_count("latch_ride_s", delta)
	_harpoon_held = true
	if staggered:
		var point := _open_point(target)
		var above := ball.y > point.y + DROP_ABOVE
		if kit.line_state == Augments.LINE_SMASH:
			_goal = "haul"
			_harpoon_commit = true
			# A haul counts once the kit has committed it (Augments.haul_open let the Ctrl press
			# through), not when the hand decides to press: a break in a stagger the bot only
			# meant to haul is not a finish from the line (KF-BOT fix round, mutation b).
			if not _haul_made:
				_haul_made = true
				_haul_above = _haul_pressed_above
				_haul_chunks = int(target.chunks_left())
				_count("latch_hauls")
				if _haul_above:
					_count("drop_hauls")
				if trace:
					print("    haul t=%.2f above=%s ball=%s point=%s stagger_left=%.2f" % [game.run.stage_time, _haul_above, ball,
						point, target.stagger_left()])
		elif above or _anchor_below > DROP_WAIT:
			_goal = "drop" if above else "haul from below"
			# A fresh Ctrl press: one that hit-stop swallowed comes up for a tick and goes again.
			_harpoon_commit = not game.player._brake_was_held
			_haul_pressed_above = above
		else:
			_goal = "drop wait"
			_anchor_below += delta
		_act(point, target, delta, target, false)
		return
	_anchor_below = 0.0
	if not _anchor_hung(target) and _anchor_vy > -ANCHOR_MOVING and not _line_finish(target):
		_goal = "latch let go"
		source.press["harpoon_released"] = true
		_harpoon_held = false
		_ground_fight(target, _punch_seen < _plating(target), delta)
		return
	_goal = "ride %s" % target.get("kind")
	_act(target.global_position, target, delta, target)


# A haul is the finish when the stagger it was made in loses a chunk (or the Warden breaks, the
# beacon_unsealed handler in start()); a drop when it was made from over the open point. A
# stagger's end clears it and the stagger's jump.
func _watch_haul(target: Node3D, staggered: bool) -> void:
	# A shatter ends the stagger on its frame, so the chunk is read before the stagger's end clears the haul.
	var left := int(target.chunks_left())
	if trace and _anchor_chunks_seen >= 0 and left < _anchor_chunks_seen:
		print("    chunk t=%.2f left=%d haul=%s above=%s line=%s" % [game.run.stage_time, left, _haul_made, _haul_above,
			game.player.kit.line_state])
	_anchor_chunks_seen = left
	if _haul_made and left < _haul_chunks:
		_count("latch_chunks", float(_haul_chunks - left))
		if _haul_above:
			_count("drop_chunks", float(_haul_chunks - left))
		_haul_chunks = left
	if not staggered:
		_haul_made = false
		_haul_pressed_above = false
		_drop_jumped = false


# How far the fight stripped the Warden: the peak share of its plating shred away, and
# the seconds spent with at least half of it gone.
func _note_shred(target: Node3D, delta: float) -> void:
	var spawner = game.ctx.spawner
	if target != game.flow.warden or spawner == null or not spawner.has_method("shred_of"):
		return
	var plating: float = float(target.get("plating"))
	if plating <= 0.0:
		return
	var share: float = spawner.shred_of(target) / plating
	_note["shred_peak"] = snappedf(maxf(float(_note.get("shred_peak", 0.0)), share), 0.01)
	if share >= 0.5:
		_note["stripped_half_s"] = snappedf(float(_note.get("stripped_half_s", 0.0)) + delta, 0.01)


# The fight bites its target from the bowl floor when the reticle holds it
# and commits the smash once the line is on. RMB and Ctrl go through _drive's hold, which is
# rebuilt every tick; the bite is a one-tick press. The hand's state is cleared at the top of
# every tick, so only a tick that runs the hand carries it.
# The press is withheld where the player discards it (a charging special or slingshot, a
# frozen ball), so a bite counts only when it can land.
func _harpoon_hand(target: Node3D, delta: float) -> void:
	if not _kit("harpoon"):
		return
	var kit = game.player.kit
	var bank_shot: bool = game.player.abilities.id_of(AbilityState.LINE) == "bank_shot"
	if _cast_phase == "await_smash":
		_cast_phase = ""
	if _smash_pending():
		if _cast_phase == "":
			# Keep the haul against a closed guard; bank off the paid open-core hit.
			_cast_slot = 3
			_cast_phase = "await_smash"
	elif bank_shot and kit.hooked and kit.on_body and is_instance_valid(kit.anchor_body):
		_cast(3)
	_harpoon_commit = false
	_off_line = 0.0 if _flat(game.player.ball_position(), target.global_position) > LINE_REACH else _off_line + delta
	# The reticle may reach scenery before the press is consumed. Let that line
	# go explicitly; withholding RMB alone leaves a world rope standing forever.
	if kit.hooked and not kit.on_body:
		source.press["harpoon_released"] = true
		_harpoon_held = false
		return
	# Aim can move from the hull to a cap between the decision and the bite.
	# Finish the body line that actually landed before taking another target.
	if kit.hooked and kit.on_body and is_instance_valid(kit.anchor_body):
		_harpoon_held = true
		# A body-line smash needs a fresh Ctrl press after the bite. Read the
		# consumed key state, so hit-stop cannot swallow alternating presses.
		_harpoon_commit = not (kit.on_body and kit.line_state == Augments.LINE_LATCHED \
			and game.player._brake_was_held)
		return
	_harpoon_held = false
	var swallowed: bool = game.player.frozen() or kit.slingshot.charging
	var special = game.player.abilities.gauge(AbilityState.SPECIAL)
	if special != null and special.charging:
		swallowed = true
	if not swallowed and kit.aim.get("body") == target and kit.rewind_left <= 0.0 and game.player.state.grounded \
			and (_off_line > DROP_MEMORY or (_weak_go and is_instance_valid(_weak_warden) and target == _weak_warden)) and _flat(game.player.ball_position(), target.global_position) <= HARPOON_FLOOR:
		# The two-hook takeoff jumps instead of biting, so only a bite waits out the pass range.
		if _bite_passes(target) and not _chain_takeoff(target):
			# Cable Charge on the hull never bites from inside (its old guard); any other bite
			# there re-presses at a player's cadence, not every tick.
			if _pass_bite_blocked(target):
				return
			_pass_bite_frame = Engine.get_physics_frames()
		# A movement exit waits for the haul; other line skills load on the bite.
		if not bank_shot:
			_cast(3)
		source.press["harpoon_pressed"] = true
		_harpoon_held = true
		if _chain_takeoff(target):
			var second := _chain_partner(target)
			if second != null:
				_chain_phase = "takeoff"
				_chain_first = target
				_chain_second = second
				_chain_rose = false
				_chain_launch_y = game.player.ball_position().y
				source.press.erase("harpoon_pressed")
				_harpoon_held = false
				source.press["jump_pressed"] = true
		if source.press.get("harpoon_pressed", false):
			_count("harpoon_bites")


# The explorer's two-hook hand would jump from this bite instead of pressing it.
func _chain_takeoff(target: Node3D) -> bool:
	return chain_hand_enabled and _kit("chain") and policy == "completionist" and not _in_boss() \
			and target != game.flow.warden and target.is_in_group("enemy") and game.player.verb_ready("jump") \
			and _chain_partner(target) != null


# A bite on a body the ball already sits inside drops as "passed" on its next tick
# (augments.gd _follow), so a press every tick re-bites, links and drops forever: a 55-link
# chain against a touching add, or a Brindle hull the ball never rams because each bite
# clears its speed bank. A player cannot press at 90 Hz; the hand backs off instead.
# Fully blocking those bites (#621) cost the small reactor arm its Warden pace (median
# 50.9 -> 70.7 s) and slowed every bot Warden fight by up to 48 percent: the point-blank bite
# itself is a play a player makes, only not at 90 Hz. The hand re-presses one every
# PASS_BITE_GAP_S instead.
func _pass_bite_blocked(target: Node3D) -> bool:
	if game.player.abilities.id_of(AbilityState.LINE) == "cable_charge" and target.get("role") == "hull":
		return true
	return Engine.get_physics_frames() - _pass_bite_frame < roundi(PASS_BITE_GAP_S * Engine.physics_ticks_per_second)


func _bite_passes(target: Node3D) -> bool:
	if Augments.anchor_line(target) or Grip.of(target, game.player.heft(), game.player.tuning.pole_flail()) in ["pole", "flail"]:
		return false
	var radius = target.get("radius")
	var passing: float = Augments.MIN_ROPE + Tuning.RADIUS + (float(radius) if radius != null else 0.0)
	return game.player.ball_position().distance_to(target.global_position) <= passing


func _smash_pending() -> bool:
	var kit = game.player.kit
	if game.player.abilities.id_of(AbilityState.LINE) != "bank_shot" \
			or not kit.hooked or not kit.on_body or not is_instance_valid(kit.anchor_body):
		return false
	var guarded: bool = kit.anchor_body.has_method("posture") and kit.anchor_body.has_method("staggered")
	return not (kit.line_state == Augments.LINE_SMASH and (not guarded or kit.anchor_body.staggered()))


func _await_smash_holds() -> bool:
	var target: Node3D = _fight_target if is_instance_valid(_fight_target) else _anchor_target
	if _smash_pending() and not _anchor_warden(target):
		return true
	_cast_phase = ""
	return false


func _clear_chain_hand() -> void:
	_chain_phase = ""
	_chain_first = null
	_chain_second = null
	_chain_rose = false


func _on_explorer_line(state: String, _target: Node3D, _at: Vector3, _cause: String) -> void:
	if state == "let_go" and _chain_phase == "second":
		_count("chain_releases")
	elif state == "broke" and _chain_phase in ["first", "rise"]:
		_count("chain_breaks_" + _cause)
	elif state == "chain_end" and not game.player.chain.finished.is_empty():
		_count("chain_ends_" + String(game.player.chain.finished.back()["cause"]))


# Tree order breaks equal-distance ties; no object ids or extra RNG draws affect a seed.
func _chain_partner(first: Node3D) -> Node3D:
	var ball: Vector3 = game.player.ball_position()
	var nearest: float = game.player.tuning.f("rope_range")
	var second: Node3D = null
	for enemy in game.get_tree().get_nodes_in_group("enemy"):
		if enemy == first or not enemy is Node3D or not is_instance_valid(enemy):
			continue
		if not Augments.hookable_body(enemy):
			continue
		var distance := ball.distance_to(enemy.global_position)
		if distance < nearest:
			nearest = distance
			second = enemy
	return second


# The hand reads the same lock and airborne grace the pilot sees. It sends only input,
# never attaches a line or writes the chain. Turning during the rise saves the grace
# for the second bite; withholding fire and specials keeps the selected anchor alive.
func _explorer_chain(delta: float) -> void:
	var player = game.player
	var kit = player.kit
	if not is_instance_valid(_chain_second) or (_chain_second.has_method("is_dead") and _chain_second.is_dead()):
		var first: Node3D = _chain_first if is_instance_valid(_chain_first) else null
		_chain_second = _chain_partner(first)
	if _chain_second == null or player.frozen() or (_chain_phase != "takeoff" and not player.chain.active()):
		_clear_chain_hand()
		source.hold = {}
		return
	_goal = "two-hook %s" % _chain_phase
	_harpoon_held = false
	_harpoon_commit = false
	match _chain_phase:
		"takeoff":
			var up: float = player.body().linear_velocity.y
			_chain_rose = _chain_rose or (not player.state.grounded and up > 0.0)
			if not is_instance_valid(_chain_first) or (_chain_rose and up <= 0.0):
				_clear_chain_hand()
				source.hold = {}
				return
			# A jump sets grounded false before the downcast clears the floor.
			# Wait for visible clearance; hit-stop can leave it inside that cast for several ticks.
			if not player.state.grounded and player.ball_position().y > _chain_launch_y + Tuning.RADIUS \
					and kit.aim.get("body") == _chain_first and player.verb_ready("harpoon"):
				_chain_phase = "first"
				source.press["harpoon_pressed"] = true
				_harpoon_held = true
				_count("harpoon_bites")
		"first", "rise":
			_chain_phase = "rise"
			var up: float = player.body().linear_velocity.y
			_chain_rose = _chain_rose or (not player.state.grounded and up > 0.0)
			if not kit.hooked or (_chain_rose and up <= 0.0):
				if kit.hooked:
					source.press["harpoon_released"] = true
				_chain_phase = "second"
			else:
				_harpoon_held = true
		"second":
			if kit.hooked and kit.anchor_body == _chain_second:
				_chain_phase = "smash"
				_harpoon_held = true
				_harpoon_commit = true
			elif player.chain.grace_left > 0.0 and not player.state.grounded \
					and kit.aim.get("body") == _chain_second and player.verb_ready("harpoon"):
				source.press["harpoon_pressed"] = true
				_harpoon_held = true
				_count("harpoon_bites")
		"smash":
			_harpoon_held = kit.hooked
			_harpoon_commit = kit.hooked
			if not kit.hooked:
				_clear_chain_hand()
	_drive(player.ball_position(), _chain_first if _chain_phase == "takeoff" else _chain_second, delta)
	source.hold.erase("fire_held")
	source.hold.erase("shift_held")
	source.press.erase("shift_pressed")


func _ram_laps(target: Node3D, aim, delta: float) -> void:
	# An anchor Warden's line is the latch arm's (_anchor_fight); the body-line smash hand
	# would bite it from the floor and hold a haul the anchor refuses outside the stagger.
	if not _anchor_warden(target):
		_harpoon_hand(target, delta)
	var ball: Vector3 = game.player.ball_position()
	var at: Vector3 = target.global_position
	var distance := _flat(ball, at)
	# A latched body line releases inside MIN_ROPE plus both body radii. Give
	# the wide hull a runup outside that distance so a bite can become a smash.
	var close := CHARGE_CLOSE
	if target.get("role") == "hull":
		close = maxf(close, float(target.get("radius")) + Augments.MIN_ROPE + 3.0)
	match _fight_phase:
		"charge":
			if distance < close:
				_fight_phase = "runup"
				_runup_time = 0.0
				var away := Vector3(ball.x - at.x, 0.0, ball.z - at.z)
				if away.length() < 0.5:
					away = Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
				away = away.normalized().rotated(Vector3.UP, rng.randf_range(-0.7, 0.7))
				var run := RUNUP
				while run > RUNUP_MIN and not _runup_on_shelf(at, away, run):
					run -= RUNUP_STEP
				_runup_point = _ground_point(at.x + away.x * run, at.z + away.z * run)
			elif target == game.flow.warden:
				_charge_watch(ball, at, distance, delta)
		"runup":
			_runup_time += delta
			if _flat(ball, _runup_point) < 4.0 or _runup_time > RUNUP_SECONDS:
				_fight_phase = "charge"
		"recover":
			_recover_time += delta
			if _flat(ball, _recover_legs[0]) < RECOVER_REACHED or _recover_time > RECOVER_LEG_SECONDS:
				_recover_legs.pop_front()
				_recover_time = 0.0
				if _recover_legs.is_empty():
					_fight_phase = "charge"
				elif not _recover_wall:
					source.press["jump_pressed"] = true
			_recover_climb = _fight_phase == "recover" and _recover_wall and _recover_legs.size() == 1
			if _recover_climb:
				_wall_jump(ball, _recover_legs[0])
	var steer: Vector3 = at
	if _fight_phase == "runup":
		steer = _runup_point
	elif _fight_phase == "recover":
		steer = _recover_legs[0]
	if _fight_phase != "recover" and _climbing(ball, at):
		steer = _fight_way_up(ball, at, delta)
		_goal += " climb"
	else:
		_fight_climb.clear()
		_fight_climb_clock = 0.0
	_act(steer, aim, delta, target)
	_recover_climb = false


# The per-target watch. The recovery count is per stage (_on_stage_entered), so a fight that
# swaps targets does not renew the cap.
func _reset_charge_watch() -> void:
	_charge_best = INF
	_charge_clock = 0.0
	_recover_legs = []
	_recover_time = 0.0
	_recover_wall = false
	_recover_climb = false


# The Warden charge's progress: the seconds since the ball last gained CHARGE_PROGRESS on its
# best distance. Inside RUNUP or on a climb the ram laps and the climb route steer, not this.
func _charge_watch(ball: Vector3, at: Vector3, distance: float, delta: float) -> void:
	if distance <= RUNUP or _climbing(ball, at):
		_charge_best = INF
		_charge_clock = 0.0
		return
	if distance < _charge_best - CHARGE_PROGRESS:
		_charge_best = distance
		_charge_clock = 0.0
		return
	_charge_clock += delta
	if _charge_clock < CHARGE_WINDOW or _recoveries >= RECOVER_LIMIT:
		return
	_recoveries += 1
	_count("charge_recoveries")
	_charge_best = INF
	_charge_clock = 0.0
	_recover_legs = _charge_escape(ball, at)
	_recover_time = 0.0
	_fight_phase = "recover"
	source.press["jump_pressed"] = true


# The recovery's legs. A wall ahead: back off the bearing as far as the room behind allows, then
# over the wall. Otherwise: back off the bearing, then to the side whose way on toward the
# target is clear of walls (the nearer one to the target when both or neither are).
func _charge_escape(ball: Vector3, at: Vector3) -> Array[Vector3]:
	var toward := Vector3(at.x - ball.x, 0.0, at.z - ball.z).normalized()
	var ahead := _face_ahead(ball, toward, RECOVER_PROBE)
	_recover_wall = ahead < INF
	if _recover_wall:
		var room := minf(RECOVER_BACK_MAX, _face_ahead(ball, -toward, RECOVER_BACK_MAX) - RECOVER_JUMP_AT)
		var from := ball - toward * maxf(room, RECOVER_JUMP_AT)
		var over := ball + toward * (ahead + RECOVER_OVER)
		var climb: Array[Vector3] = [_ground_point(from.x, from.z), _ground_point(over.x, over.z)]
		return climb
	var back := ball - toward * RECOVER_BACK
	var best := Vector3.INF
	var best_score := -INF
	for turn in [PI * 0.5, -PI * 0.5]:
		var side := _ground_point(back.x, back.z) + toward.rotated(Vector3.UP, turn) * RECOVER_SIDE
		side = _ground_point(side.x, side.z)
		var score := -_flat(side, at)
		if _way_clear(side, side + toward * RECOVER_SIDE):
			score += 1000.0
		if score > best_score:
			best_score = score
			best = side
	var out: Array[Vector3] = [_ground_point(back.x, back.z), best]
	return out


# The climb leg's jumps: off the ground RECOVER_JUMP_AT short of the wall, and the air jump
# once the first one stops rising.
func _wall_jump(ball: Vector3, over: Vector3) -> void:
	var state = game.player.state
	if state.grounded:
		var toward := Vector3(over.x - ball.x, 0.0, over.z - ball.z).normalized()
		if _face_ahead(ball, toward, RECOVER_JUMP_AT) < INF:
			source.press["jump_pressed"] = true
	elif state.air_actions > 0 and state.velocity.y < 1.0:
		source.press["jump_pressed"] = true


# The distance along a level ray from the ball to the first wall (a face steeper than WALL_TILT),
# INF when none lies within reach.
func _face_ahead(from: Vector3, dir: Vector3, reach: float) -> float:
	var space = game.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * reach, 1))
	if hit.is_empty() or absf((hit["normal"] as Vector3).y) >= WALL_TILT:
		return INF
	return _flat(from, hit["position"])


# Whether a ray at ball height from one point to the other meets no wall (a face steeper than WALL_TILT).
func _way_clear(from: Vector3, to: Vector3) -> bool:
	var space = game.get_world_3d().direct_space_state
	var lift := Vector3.UP * 0.2
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from + lift, to + lift, 1))
	return hit.is_empty() or absf((hit["normal"] as Vector3).y) >= WALL_TILT


# Whether to climb to a target above the ball: more than LEVEL_BAND above it, or, with a climb in
# hand, still on lower ground. The crown's beacon ramp tops out within LEVEL_BAND of the Warden's
# floor, and rolling straight from there runs into the side wall of the bridge beside it.
func _climbing(ball: Vector3, at: Vector3) -> bool:
	if at.y - ball.y > LEVEL_BAND:
		return true
	return not _fight_climb.is_empty() and _ground_point(at.x, at.z).y - _ground_point(ball.x, ball.z).y > CLIMB_LEVEL


# Whether the straight line from the ball to a point drops more than LEVEL_BAND below the ground at
# both ends: a ball rolled across falls in and may not climb out, so it takes the climb route, which
# goes round a trough whose walls are steeper than it climbs.
# The sinkhole's gate slot stands across its 20 m bowl from the Warden (seed 20 skipper, #397).
func _dips(ball: Vector3, at: Vector3) -> bool:
	var terrain = game.ctx.terrain
	var low := minf(terrain.height(ball.x, ball.z), terrain.height(at.x, at.z)) - LEVEL_BAND
	var steps := int(_flat(ball, at) / CLIMB_STEP)
	for k in range(1, steps):
		var p := ball.lerp(at, float(k) / steps)
		if terrain.height(p.x, p.z) < low:
			return true
	return false


# The next point on the climb to a fight target above the ball, or the target when no way up is found.
func _fight_way_up(ball: Vector3, at: Vector3, delta: float) -> Vector3:
	if _fight_climb_tick != ticks:
		_fight_climb_held = _fight_climb_held + delta if _fight_climb_tick == ticks - 1 else delta
		_fight_climb_tick = ticks
	if _fight_climb_held > MIND_CLIMB_GIVE_UP and _in_mind_stage() and not _mind_slope_spent:
		_mind_slope_spent = true
		_fight_climb_clock = 0.0
	_fight_climb_clock -= delta
	if _fight_climb_clock <= 0.0:
		_fight_climb = _climb_route_any(ball, at)
		_fight_climb_clock = FIGHT_CLIMB_REPLAN
	while not _fight_climb.is_empty() and _flat(ball, _fight_climb[0]) < CLIMB_REACHED:
		_fight_climb.pop_front()
	_kicker_jump(ball)
	return at if _fight_climb.is_empty() else _fight_climb[0]


# At the top of a kicker on the route, jump: rolled off the lip, a ball slowed by the climb drops
# into the gap before the next floor (the Flume's drum lip, 3 m short of the gate lip).
func _kicker_jump(ball: Vector3) -> void:
	if not game.player.state.grounded or not game.player.verb_ready("jump"):
		return
	for lip in _route_lips:
		if _flat(ball, lip) < KICKER_JUMP_AT and ball.y > lip.y - KICKER_JUMP_AT:
			source.press["jump_pressed"] = true
			return


# Whether the ground RUNUP_EDGE past the runup point and to either side of it is level with the
# target's: the ball turns round there, so a bridge or a rim beside it drops it to the deck.
func _runup_on_shelf(at: Vector3, away: Vector3, run: float) -> bool:
	var floor_y: float = _ground_point(at.x, at.z).y
	var side := away.cross(Vector3.UP)
	for offset in [away * (run + RUNUP_EDGE), away * run + side * RUNUP_EDGE, away * run - side * RUNUP_EDGE]:
		if _ground_point(at.x + offset.x, at.z + offset.z).y < floor_y - RUNUP_DROP:
			return false
	return true


# Slams beside a caps Warden: a slam landing within 2.6 m of a cap meets plating 0.
# The bot rolls up the radial line of the cap nearest it, so it lands beside that cap,
# jumps when it touches, and slams only while beside the body: a ball resting on top of
# an enemy never reads grounded, so a slam begun there would not land. Hugging the
# Warden also takes its pulse for height, so its core ring is welcome while HP is
# above PULSE_HP_SHARE of max.
func _cap_loop(target: Node3D, delta: float) -> void:
	var ball: Vector3 = game.player.ball_position()
	var at: Vector3 = target.global_position
	# The pulse costs 10 HP; a sensible player takes it for height only while healthy.
	_welcome_ring_at = at if game.run.hp > PULSE_HP_SHARE * game.run.max_hp else Vector3.INF
	var from_ball := Vector3(ball.x - at.x, 0.0, ball.z - at.z).normalized()
	var line := from_ball
	var best := -INF
	for cap in target.cap_points():
		var dir := Vector3(cap.x - at.x, 0.0, cap.z - at.z).normalized()
		if dir.dot(from_ball) > best:
			best = dir.dot(from_ball)
			line = dir
	var d := _flat(ball, at)
	# From outside, come in along the cap's line; beside it, press into the body.
	var steer: Vector3 = at + line * CAP_BESIDE if d > CAP_JUMP + 2.0 else at
	_act(steer, target, delta, target)
	var v: Vector3 = game.player.state.velocity
	if game.player.state.grounded:
		if d < CAP_JUMP:
			source.press["jump_pressed"] = true
	elif d > CAP_INSIDE and d < CAP_JUMP + 1.0 and v.y < 2.0:
		source.hold["brake_held"] = true


# What to point the gun at: the weak point when punch is short and one shows (the
# magnet while it tugs), else the body.
func _aim_node(target: Node3D, short: bool):
	if short and _kit("weak_points") and target.has_method("weak_points") and not (target.weak_points() as Array).is_empty():
		return {"at": target.weak_points()[0]["at"]}
	return target


# --- the boss: Brindle's Requisition in the Slag Bowl ----------------------------------

func _boss():
	var ctx = game.ctx
	var boss = ctx.get("boss") if "boss" in ctx else null
	if boss == null and ctx.has_meta("boss"):
		boss = ctx.get_meta("boss")
	if boss == null or not is_instance_valid(boss) or not boss.has_method("enter_arena"):
		return null
	return boss


# A boss without a ship is the stub's one posture Warden on a flat pad (stub_boss.gd, its
# `warden` field). The bot fights it with the routine it uses on a stage Warden.
func _fight_posture_boss(boss, delta: float) -> void:
	_read_weak_points(boss, delta)
	var target = boss.get("warden")
	if not boss.has_method("active") or not boss.active() or not is_instance_valid(target) or not target is Node3D:
		_goal = "boss wait"
		_act(game.player.ball_position() + game.player.planar_velocity(), null, delta)
		return
	var fitter := _open_fitter(boss)
	if fitter != null:
		_fight_fitter(fitter, delta)
		return
	var part := _open_part(boss)
	if part != null:
		_fight_part(part, delta)
		return
	_fight(target, delta)


# The physical part of the point the bot reads as open and goes for (stub_boss.gd weak_part), or null. Null at dial 0
# (no point ever opens) and for a boss whose points are not bodies (the Mind's seats), so the fight is the Warden's.
func _open_part(boss) -> Node3D:
	if not _weak_go or not boss.has_method("weak_part"):
		return null
	var open: Array = boss.weak_open()
	return boss.weak_part(String(open[-1])) if not open.is_empty() else null


# A fitter of the open hatch to hit before the hatch itself (waking.gd crew): the first one holding a plate, and only
# while the seal clock runs (weak_points.gd fit_min or more on the hatch). Once knock-offs leave fewer than fit_min the
# clock stops, so the hatch is the target again; a knocked fitter comes back after KNOCK_SECONDS, and chasing every one
# spends the window on drones. An inbound one is never a target: waking.gd only knocks off a fitting one. Gated by the same go as the
# part, so the expert always, the learner after its read and roll, the novice never; it draws nothing.
func _open_fitter(boss) -> Node3D:
	if not _weak_go or not boss.has_method("crew") or not boss.has_method("weak_open"):
		return null
	var open: Array = boss.weak_open()
	if open.is_empty():
		return null
	var id := String(open[-1])
	var weak = boss.get("weak")
	if weak != null and weak.fitters(id) < weak.fit_min:
		return null
	for f in boss.crew():
		if f.point_id != id or f.is_dead():
			continue
		if f.fit_state == f.State.FITTING:
			return f
	return null


func _fight_fitter(fitter: Node3D, delta: float) -> void:
	_goal = "fitter %s" % fitter.point_id
	_weak_warden = fitter
	_harpoon_hand(fitter, delta)
	_act(fitter.global_position, fitter, delta, fitter)


# An open hatch or override: roll at it, bite it with the harpoon hand and commit the haul. The hand's wait between
# bites is waived for it the way it is for an open Warden point (_weak_warden).
func _fight_part(part: Node3D, delta: float) -> void:
	_goal = "part %s" % part.get("point_id")
	_weak_warden = part
	_harpoon_hand(part, delta)
	_act(part.global_position, part, delta, part)


# Whether the bot presses its harpoon-and-haul on the Warden for an open weak point: the expert always, the
# learner once the point has been open 0.6 s and its one roll for the opening is under 0.5, the novice never.
static func weak_point_go(band_name: String, opened_age: float, roll: float) -> bool:
	match band_name:
		"expert":
			return true
		"learner":
			return opened_age >= 0.6 and roll < 0.5
	return false


# With no point open (always, at dial 0) this draws nothing and leaves the fight as it was. A learner draws
# one roll per opening; the go waives the harpoon hand's wait between bites (_harpoon_hand).
func _read_weak_points(boss, delta: float) -> void:
	_weak_go = false
	var open: Array = boss.weak_open() if boss.has_method("weak_open") else []
	if open.is_empty():
		_weak_seen = ""
		_weak_warden = null
		return
	var id := String(open[-1])
	if id != _weak_seen:
		_weak_seen = id
		_weak_age = 0.0
		_weak_roll = rng.randf() if band != null and band.name == "learner" else 0.0
	_weak_age += delta
	_weak_go = weak_point_go(band.name if band != null else "expert", _weak_age, _weak_roll)
	_weak_warden = boss.get("warden") if _weak_go else null


# Phase 1: guns on the live crane magnets from the orbit, chasing any stolen scrap.
# Phase 2: up a ramp and slam a vent cap when punch is short of the hull, else ram.
# Phase 3: bait charges into the rim wall and ram the stunned ship; clash head-on when
# punch reaches the clash threshold. The chase: run the scooter down.
func _fight_boss(delta: float) -> void:
	var boss = _boss()
	if boss_note.is_empty():
		_on_boss_entered()
	var ship = boss.get("ship")
	var arena = boss.get("arena")
	if ship == null:
		_fight_posture_boss(boss, delta)
		return
	if not boss.has_method("active") or not boss.active() or ship == null or not is_instance_valid(arena):
		_goal = "boss wait"
		_act(game.player.ball_position() + game.player.planar_velocity(), null, delta)
		return
	var ball: Vector3 = game.player.ball_position()
	var hull: Node3D = ship.hull
	var punch: float = _punch_seen
	var phase: int = int(boss.phase)
	var scooter = boss.get("scooter")
	if scooter != null and is_instance_valid(scooter):
		_goal = "boss scooter"
		_ram_laps(scooter, scooter, delta)
		return
	var pickup := _nearest_pickup(boss, ball)
	# Posture opens through repeated hits even below plating. Orbiting the magnets
	# never makes the hull contacts that crack and shatter its cockpit.
	if hull.has_method("fight") and hull.fight() == "posture":
		# Crane theft drains punch below the plated hull's posture curve. Recover
		# the dropped scrap between openings, including after the crane phase.
		if pickup != Vector3.INF and not hull.staggered():
			_goal = "boss pickup"
			if game.player.kit.hooked:
				source.press["harpoon_released"] = true
			_act(pickup, hull, delta)
			return
		if hull.staggered():
			_goal = "boss open cockpit"
			_harpoon_hand(hull, delta)
			_act(hull.global_position, hull, delta, hull, false)
			if not game.player.kit.hooked and _flat(ball, hull.global_position) < hull.radius + 3.0:
				if game.player.state.grounded:
					source.press["jump_pressed"] = true
				else:
					source.hold["brake_held"] = true
			return
		# Phase 3's charge lane, once read, outranks the ram laps and run-ups _fight plans.
		if phase == 3 and _charge_plan(boss, hull, ball, punch, delta):
			return
		_fight(hull, delta)
		return
	match phase:
		1:
			var magnet: Node3D = _live_part(boss, ship.magnets, ball) if _kit("weak_points") else null
			if pickup != Vector3.INF:
				_goal = "boss pickup"
				_act(pickup, magnet if magnet != null else hull, delta)
			elif punch >= _plating(hull) or not _kit("weak_points"):
				_goal = "boss ram"
				_ram_laps(hull, magnet if magnet != null else hull, delta)
			else:
				_goal = "boss magnets"
				_act(_orbit_point(arena, ball, BOSS_ORBIT), magnet if magnet != null else hull, delta)
		2:
			if punch >= _plating(hull) or not _kit("weak_points"):
				_goal = "boss ram"
				_ram_laps(hull, hull, delta)
			else:
				_ramp_to_cap(boss, arena, ship, delta)
		_:
			if boss.has_method("stunned") and boss.stunned():
				_goal = "boss stunned"
				_ram_laps(hull, hull, delta)
			elif _charge_plan(boss, hull, ball, punch, delta):
				pass
			else:
				_goal = "boss bait"
				_act(arena.point_at(arena.angle_of(ball), BAIT_RADIUS), hull, delta, hull)


# Brindle's committed charge lane when this band has seen it long enough and read it (the
# `_threats` rules: seen for the band's reaction time, `band.reads`), else null. Counts each
# read lane once.
func _charge_lane(boss):
	var c = boss.get("_charge")
	if not c is Dictionary or not String(c.get("state", "")) in ["brace", "run"]:
		return null
	var h = c.get("hazard")
	if h == null or not is_instance_valid(h) or h.is_done():
		return null
	var id: int = h.get_instance_id()
	if not _seen.has(id):
		_seen[id] = ticks
		return null
	if float(ticks - int(_seen[id])) / float(Engine.physics_ticks_per_second) < _reaction():
		return null
	if band != null and not band.reads(id):
		return null
	if not _charge_read.has(id):
		_charge_read[id] = true
		_count("charge_reads")
	return h


# Phase 3 against a read charge lane. Returns false (the old plan runs) on an unread lane.
# The full kit clashes only when it can win; everything else steps out of the lane.
func _charge_plan(boss, hull: Node3D, ball: Vector3, punch: float, delta: float) -> bool:
	var h = _charge_lane(boss)
	if h == null:
		return false
	var id: int = h.get_instance_id()
	var lateral: float = h.lane_lateral(ball)
	if _clash_viable(boss, h, ball, punch, id):
		if not _clash_tried.has(id):
			_clash_tried[id] = true
			_count("clash_tries")
		_goal = "boss clash"
		_act(hull.global_position, hull, delta, hull, false)
		return true
	_clash_latched.erase(id)
	if not _charge_stepped.has(id):
		_charge_stepped[id] = true
		_count("charge_sidesteps")
	var out: float = h.half_width + CHARGE_MARGIN
	var sign_side := 1.0 if lateral >= 0.0 else -1.0
	var along: float = h.lane_along(ball)
	var at: Vector3 = h.centre + h.heading * along + h.side() * sign_side * (out + 1.0)
	_goal = "boss sidestep"
	_act(Vector3(at.x, ball.y, at.z), hull, delta, hull, absf(lateral) >= h.half_width + 1.0)
	return true


# Head-on with time to spare: the full kit, enough punch, the ball closing on the bow at
# speed, and it can line up with the lane's axis before the front arrives. Latched per lane
# once taken, so the clash does not flicker.
func _clash_viable(boss, h, ball: Vector3, punch: float, id: int) -> bool:
	if band != null and band.kit != "full":
		return false
	var clash_punch: float = float(boss.get("clash_punch") if boss.get("clash_punch") != null else 150.0)
	if punch < clash_punch:
		return false
	var c: Dictionary = boss.get("_charge")
	var front: float = float(c.get("travelled", 0.0)) + Requisition.HULL.z * 0.5
	var gap: float = h.lane_along(ball) - front
	if gap < CLASH_MIN_GAP:
		return _clash_latched.has(id) and gap > 0.0
	var v: Vector3 = game.player.planar_velocity()
	var closing: float = -v.dot(h.heading)
	var wait: float = h.seconds_until_live() if not h.is_live() else 0.0
	var arrive: float = wait + gap / (BossRules.CHARGE_SPEED + maxf(closing, 0.0))
	var align: float = maxf(absf(h.lane_lateral(ball)) - CLASH_ALIGN, 0.0) / CLASH_ROLL
	var ok: bool = _clash_latched.has(id) or closing >= CLASH_SPEED
	ok = ok and (align <= 0.0 or align <= arrive - CLASH_SPARE)
	if ok:
		_clash_latched[id] = true
	return ok


func _live_part(boss, parts: Array, ball: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for part in parts:
		if not is_instance_valid(part):
			continue
		if boss.has_method("target_live") and not boss.target_live(part):
			continue
		var d := ball.distance_to(part.global_position)
		if d < best_d:
			best_d = d
			best = part
	return best


func _nearest_pickup(boss, ball: Vector3) -> Vector3:
	if not boss.has_method("pickups_left"):
		return Vector3.INF
	var best := Vector3.INF
	var best_d := PICKUP_CHASE
	for p in boss.pickups_left():
		var at: Vector3 = p["at"]
		var d := _flat(ball, at)
		if String(p.get("source", "")) == "shed" and d > SHED_CHASE and not _shed_ahead(ball, at):
			continue
		if d < best_d:
			best_d = d
			best = at
	return best


func _shed_ahead(ball: Vector3, at: Vector3) -> bool:
	var v: Vector3 = game.player.planar_velocity()
	v.y = 0.0
	var to := at - ball
	to.y = 0.0
	if v.length() < SHED_ROLLING or to.length() < 0.01:
		return false
	return v.normalized().dot(to.normalized()) > SHED_AHEAD


# A point on the circle of radius r, a little ahead of the ball in its travel.
func _orbit_point(arena, ball: Vector3, r: float) -> Vector3:
	return arena.point_at(arena.angle_of(ball) + 0.5, r)


# Up whichever ramp the ship is passing, a jump off its top, and a slam onto the cap
# under the ball. Waits at the ramp's foot, guns on the hull, while the ship is away.
func _ramp_to_cap(boss, arena, ship, delta: float) -> void:
	var ball: Vector3 = game.player.ball_position()
	var cap := _live_part(boss, ship.caps, ball)
	var hull: Node3D = ship.hull
	if cap != null and not game.player.state.grounded:
		var over := _flat(ball, cap.global_position) <= CAP_REACH and ball.y - cap.global_position.y >= CAP_ABOVE
		_goal = "boss cap air"
		_act(cap.global_position, cap, delta, cap)
		if over:
			source.hold["brake_held"] = true
		return
	var ship_angle: float = arena.angle_of(hull.global_position)
	var ramp := 0.0
	var gap := INF
	for a in RAMP_ANGLES:
		var g := absf(wrapf(ship_angle - deg_to_rad(a), -PI, PI))
		if g < gap:
			gap = g
			ramp = deg_to_rad(a)
	var r: float = arena.radius_of(ball)
	var on_ramp: bool = absf(wrapf(arena.angle_of(ball) - ramp, -PI, PI)) < 0.2
	if gap < RAMP_WINDOW and on_ramp and r < RAMP_BOTTOM + 3.0:
		_goal = "boss ramp climb"
		_act(arena.point_at(ramp, RAMP_PAST), cap if cap != null else hull, delta, hull)
		if r < RAMP_JUMP and game.player.state.grounded:
			source.press["jump_pressed"] = true
		return
	_goal = "boss ramp foot"
	_act(arena.point_at(ramp, RAMP_BOTTOM), hull, delta, hull)


# --- the gates -------------------------------------------------------------------------

func _on_offers(offers: Array) -> void:
	_offers = offers
	_gate_pick = _choose_gate(offers)
	_gate_time = 0.0
	_gate_hop = 0.0
	_gate_detour_left = 0.0
	_gate_run = ""
	_gate_run_clock = 0.0
	_gate_on_top = false
	_gate_falls = 0
	var map = game.ctx.terrain.map_for(game.run.stage)
	_island_gates = map != null and map.has_method("_islands")
	if _island_gates:
		# A climb planned in the Warden fight is not the way to the gates.
		_fight_climb.clear()
		_fight_climb_clock = 0.0


func _choose_gate(offers: Array) -> int:
	if offers.is_empty():
		return -1
	match policy:
		"skipper":
			return 0
		"completionist":
			var best := 0
			var best_score := -1.0
			for i in offers.size():
				var o: Dictionary = offers[i]
				var score := float(o.get("tier", 1)) + (10.0 if String(o.get("synergy", "")) != "" else 0.0) \
					+ (0.5 if String(o.get("mark", "")) != "" else 0.0)
				if score > best_score:
					best_score = score
					best = i
			return best
	return rng.randi_range(0, offers.size() - 1)


func _to_gate(delta: float) -> void:
	_goal = "gate %d" % _gate_pick
	if _offers.is_empty() or _gate_pick < 0:
		source.hold = {"move": Vector2(0.0, 1.0)}
		return
	var offer: Dictionary = _offers[mini(_gate_pick, _offers.size() - 1)]
	var at: Vector3 = offer["at"]
	var facing: Vector3 = offer["facing"]
	var rel: Vector3 = game.player.ball_position() - at
	var along := rel.dot(facing)
	var side := (rel - facing * along).length()
	# Lined up behind the arch: roll through it. Otherwise swing round behind it first.
	var target := at - facing * 9.0
	if side < 2.5 and along < 1.0:
		target = at + facing * 10.0
	elif side < GATE_LINE_SIDE and along > -GATE_LINE_BACK and along < -GATE_LINE_NEAR:
		# Near the run-in point but off the line: steer for the line GATE_LINE_LEAD ahead, so the ball
		# merges onto it rolling forward; a point target here is orbited (the Flume's gate 1, seed 6).
		target = at + facing * (along + GATE_LINE_LEAD)
	# Off the gates' island (a Highdraft beacon top), the straight line meets its cliff: climb back.
	# Off the islands, a straight line across a trough takes the same way round (_dips).
	var ball_at: Vector3 = game.player.ball_position()
	if _climbing(ball_at, at) or (not _island_gates and _dips(ball_at, at)):
		if _gate_on_top and _island_gates:
			_gate_on_top = false
			_gate_falls += 1
			if _gate_falls >= GATE_SWITCH_FALLS:
				_switch_gate()
		target = _fight_way_up(ball_at, target, delta)
		_goal += " climb"
	else:
		_gate_on_top = true
		_fight_climb.clear()
		_fight_climb_clock = 0.0
	if rel.length() < GATE_PROBE_NEAR:
		target = _gate_round_props(ball_at, target, delta)
	else:
		_gate_detour_left = 0.0
	# A ball off the gates' island with a way up follows that way: the run-up's straight
	# charge would meet the island's cliff (the crown's beacon top stands 25 m over the deck).
	if _fight_climb.is_empty() or not _island_gates:
		target = _gate_runup(at, facing, rel, ball_at, target, delta)
	else:
		_gate_run = ""
	# A gate still untaken after GATE_HOP_SECONDS has something on its line (a kerb, a
	# bench): hop while rolling at it, as a player clears a low lip.
	_gate_time += delta
	_gate_hop -= delta
	if _gate_time > GATE_SWITCH_SECONDS and _gate_on_top and _island_gates:
		_switch_gate()
	if _gate_time > GATE_HOP_SECONDS and _gate_hop <= 0.0 and game.player.state.grounded and along < 0.0 and along > -14.0:
		_gate_hop = GATE_HOP_EVERY
		source.press["jump_pressed"] = true
	# Past a kicker's lip and falling short of the next floor, spend the air jump (the Flume's drum lip).
	if not game.player.state.grounded and game.player.state.air_actions > 0 and game.player.state.velocity.y < 0.0 \
			and game.player.verb_ready("jump"):
		for lip in _route_lips:
			if _flat(ball_at, lip) < 12.0 and ball_at.y < lip.y + 2.5 and ball_at.y > lip.y - 2.0:
				source.press["jump_pressed"] = true
				_count("gate_air_jumps")
				break
	if trace and ticks % (Engine.physics_ticks_per_second * 2) == 0:
		var ball: Vector3 = game.player.ball_position()
		print("    gate %d at=(%.1f, %.1f, %.1f) facing=(%.2f, %.2f, %.2f) ball=(%.1f, %.1f, %.1f) along=%.1f side=%.1f dy=%.1f ground=%.1f target=(%.1f, %.1f, %.1f)"
			% [_gate_pick, at.x, at.y, at.z, facing.x, facing.y, facing.z, ball.x, ball.y, ball.z, along, side, rel.y,
				game.ctx.terrain.height(ball.x, ball.z), target.x, target.y, target.z])
	var calm: bool = (_island_gates or _gate_time > GATE_HOP_SECONDS) and _gate_on_top and _gate_run == "" \
		and absf(rel.y) < 3.0 and rel.length() < GATE_CALM_RANGE
	if not calm:
		_act(target, null, delta)
		return
	var boost_clock := _boost_clock
	_boost_clock = maxf(_boost_clock, delta)
	_act(target, null, delta)
	_boost_clock = boost_clock
	if game.player.state.grounded and game.player.planar_velocity().length() > GATE_CALM_SPEED:
		source.hold["brake_held"] = true


# Gives up the picked gate for the next offer, with a fresh clock, run-up and detour.
func _switch_gate() -> void:
	_gate_falls = 0
	_gate_time = 0.0
	_gate_run = ""
	_gate_detour_left = 0.0
	if _offers.size() > 1:
		_gate_pick = (_gate_pick + 1) % _offers.size()
		_count("gate_switches")


# The run-up for a gate up a face: "runup" drives to GATE_RUNUP_BACK metres down the gate's
# line, "charge" rolls the line at speed; each phase gives up after its seconds and the other
# takes over, so a stalled charge is a fresh run-up.
func _gate_runup(at: Vector3, facing: Vector3, rel: Vector3, ball: Vector3, target: Vector3, delta: float) -> Vector3:
	if _gate_time < GATE_RUNUP_AFTER or rel.y > -3.0:
		_gate_run = ""
		return target
	var start := at - facing * GATE_RUNUP_BACK
	start.y = ball.y
	if _gate_run == "":
		_gate_run = "runup"
		_gate_run_clock = 0.0
		_count("gate_runups")
	_gate_run_clock += delta
	if _gate_run == "runup" and (_flat(ball, start) < 8.0 or _gate_run_clock > GATE_RUNUP_SECONDS):
		_gate_run = "charge"
		_gate_run_clock = 0.0
	elif _gate_run == "charge" and _gate_run_clock > GATE_CHARGE_SECONDS:
		_gate_run = "runup"
		_gate_run_clock = 0.0
		_count("gate_runups")
	_goal += " " + _gate_run
	if _gate_run == "runup":
		return start
	return at + facing * 10.0


# The static prop on the gate line, or an empty Dictionary. Ground is not a prop.
func _gate_probe(from: Vector3, heading: Vector3, length: float) -> Dictionary:
	var origin := from + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(origin, origin + heading * length)
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var node := hit["collider"] as Node
	if "/Ground" in str(node.get_path()):
		return {}
	return hit


# A body's own collider shapes, CollisionShape3D children and bare shape owners (anchor posts) alike.
func _body_shapes(body: Node) -> Array:
	var out: Array = []
	var body_3d := body as CollisionObject3D
	if body_3d == null:
		return out
	for owner_id in body_3d.get_shape_owners():
		var at := body_3d.global_transform * body_3d.shape_owner_get_transform(owner_id)
		for i in body_3d.shape_owner_get_shape_count(owner_id):
			out.append({"shape": body_3d.shape_owner_get_shape(owner_id, i), "global_transform": at})
	return out


# The prop's footprint on the ground plane: its parent's collision boxes when it is a small
# device (a cache is four walls and a roof), else the body alone.
func _prop_footprint(body: Node) -> Rect2:
	var owner_node: Node = body.get_parent()
	var shapes: Array = []
	if owner_node != null and owner_node.get_child_count() <= 12:
		for child in owner_node.get_children():
			if child is CollisionObject3D:
				shapes.append_array(_body_shapes(child))
	if shapes.is_empty():
		shapes = _body_shapes(body)
	var box := Rect2()
	var first := true
	for cs in shapes:
		var bs := cs.shape as BoxShape3D
		if bs == null:
			continue
		for sx in [-0.5, 0.5]:
			for sz in [-0.5, 0.5]:
				var corner: Vector3 = cs.global_transform * Vector3(bs.size.x * sx, 0.0, bs.size.z * sz)
				if first:
					box = Rect2(Vector2(corner.x, corner.z), Vector2.ZERO)
					first = false
				else:
					box = box.expand(Vector2(corner.x, corner.z))
	return box


# Returns where to steer for the gate: the target, or a way round a prop on the line: the
# corner of its footprint (GATE_MARGIN off the walls) the ball sees and that makes the
# shortest trip to the target, else the nearest clear heading.
func _gate_round_props(ball: Vector3, target: Vector3, delta: float) -> Vector3:
	_gate_detour_left -= delta
	if _gate_detour_left > 0.0 and _flat(ball, _gate_detour) > 3.0:
		return _gate_detour
	var line := target - ball
	line.y = 0.0
	if line.length() < 1.0:
		return target
	var reach := minf(line.length(), GATE_PROBE)
	line = line.normalized()
	var hit := _gate_probe(ball, line, reach)
	if hit.is_empty():
		return target
	var walls := _prop_footprint(hit["collider"])
	if _island_gates and walls.has_point(Vector2(ball.x, ball.z)):
		# Inside a prop's pocket (the crown's relic cache is walled on three sides): no corner is
		# in sight from in there, so back out the way the ball came in, away from the gate.
		_gate_detour = ball - line * (walls.size.length() * 0.5 + GATE_MARGIN)
		_gate_detour_left = GATE_DETOUR_SECONDS
		_count("gate_backouts")
		return _gate_detour
	var box := walls.grow(GATE_MARGIN)
	var best_cost := INF
	var best := Vector3.ZERO
	if box.has_area():
		for corner in [box.position, box.position + Vector2(box.size.x, 0.0), box.position + Vector2(0.0, box.size.y), box.end]:
			var at := Vector3(corner.x, ball.y, corner.y)
			var way := at - ball
			way.y = 0.0
			if way.length() < 1.0 or not _gate_probe(ball, way.normalized(), way.length()).is_empty():
				continue
			var cost := way.length() + _flat(at, target)
			if cost < best_cost:
				best_cost = cost
				best = at
	if best_cost < INF:
		_gate_detour = best
		_gate_detour_left = GATE_DETOUR_SECONDS
		_count("gate_detours")
		return best
	for step in range(1, 7):
		for side in [1.0, -1.0]:
			var heading := line.rotated(Vector3.UP, deg_to_rad(GATE_TURN * step * side))
			if _gate_probe(ball, heading, GATE_PROBE).is_empty():
				_gate_detour = ball + heading * GATE_PROBE
				_gate_detour_left = 1.0
				_count("gate_detours")
				return _gate_detour
	return target


# --- acting: telegraphs first, then the class kit, then the stick --------------------

# steer is where the goal wants to go, aim what to look and shoot at (a Node3D, a
# {"at": Vector3} point or null), fight the lock this is about (for plants and
# specials). evade false rolls straight on, as a clash does.
func _act(steer: Vector3, aim, delta: float, fight: Node3D = null, evade := true) -> void:
	var player = game.player
	if policy == "completionist" and _chain_phase != "":
		_drive(player.ball_position(), _chain_first if _chain_phase == "takeoff" else _chain_second, delta)
		source.hold.erase("fire_held")
		source.hold.erase("shift_held")
		source.press.erase("shift_pressed")
		return
	if player.kit.mounted:
		_turret(aim, delta)
		return
	if _plant_state == "mounted":
		_plant_state = "idle"
	_ultimate_hands(fight)
	_line_hands()
	var threats := _threats() if evade else []
	if not threats.is_empty():
		for h in threats:
			if not _evaded.has(h.get_instance_id()):
				_evaded[h.get_instance_id()] = true
				_count("evasions")
		var escape := _escape(threats, steer, fight if policy == "camper" else null)
		_plant_state = "idle" if _plant_state == "seek" else _plant_state
		_specials(fight, true)
		_drive(escape, aim, delta)
		return
	# A plant face does not replace a fight climb's waypoint: the face beside the crown's beacon
	# ramp slingshots the engineer back to the deck before she reaches the Warden's floor.
	# A seek dropped for the climb is not resumed afterwards: its face may lie back down the ramp.
	if _engineer() and _kit("plant") and fight != null and is_instance_valid(fight):
		if _climbing(player.ball_position(), fight.global_position):
			_plant_state = "idle" if _plant_state == "seek" else _plant_state
		else:
			var planted := _plant(fight, delta)
			if planted != Vector3.INF:
				steer = planted
	_specials(fight, false)
	_drive(steer, aim, delta)


# Every committed telegraph the ball is in, or will be within PREDICT, among those seen
# for at least REACTION seconds.
func _threats() -> Array:
	var ball: Vector3 = game.player.ball_position()
	var ahead: Vector3 = ball + game.player.state.velocity * PREDICT
	var out: Array = []
	var live := {}
	for h in _hazards():
		var id: int = h.get_instance_id()
		live[id] = true
		if not _seen.has(id):
			_seen[id] = ticks
			continue
		if float(ticks - int(_seen[id])) / float(Engine.physics_ticks_per_second) < _reaction():
			continue
		if band != null and not band.reads(id):
			continue
		if _welcome_ring_at != Vector3.INF and h.get("center") != null and _flat(h.center, _welcome_ring_at) < 1.0:
			continue
		if not _read.has(id):
			_read[id] = true
			_count("telegraph_reads")
		if h.contains(ball) or h.contains(ahead):
			out.append(h)
	if _seen.size() > 64:
		for id in _seen.keys():
			if not live.has(id):
				_seen.erase(id)
				_read.erase(id)
	if band != null:
		band.forget(live)
	return out


# Whether the dam sheet hand reads the Warden's clock and holds fire (the Expert, and no band).
func _sheet_timed() -> bool:
	return band == null or band.timed_sheet()


# Seconds from a telegraph appearing to the bot seeing it.
func _reaction() -> float:
	return REACTION if band == null else band.reaction_s


# Whether the band has this verb's hand. No band has them all.
func _kit(verb: String) -> bool:
	return band == null or band.allows(verb)


# The telegraphs a player can see: combat's rings and lanes under the game root (not
# the player's own amber ones, not fields wider than FIELD_RADIUS) and the boss's hazards.
func _hazards() -> Array:
	var out: Array = []
	var pack_telegraphs := _pack_telegraphs() if hide_pack_telegraphs else {}
	for child in game.get_children():
		if child.get_script() != TelegraphScript or child.is_queued_for_deletion():
			continue
		if child.color == Palette.AMBER:
			continue
		if child.shape == TelegraphScript.Shape.RING and child.radius > FIELD_RADIUS:
			continue
		if hide_pack_telegraphs and pack_telegraphs.has(child):
			continue
		out.append(child)
	var boss = _boss() if game.flow.state_name() == "boss" else null
	if boss != null and boss.has_method("active_hazards"):
		for h in boss.active_hazards():
			if is_instance_valid(h) and h.has_method("contains"):
				out.append(h)
	return out


# The nearest spot outside every threat, preferring the ball's line and the goal.
# away: the camper's Warden. A camper holding its range steers at its own ball, so with no goal and no
# line every direction scored 0 and the first (+z) won; on the stage 3 hive that heading ran the ball
# under the collar, where its contacts cracked and shattered the core (camper seed 5 broke the hive at
# fcddfe10). Inside CAMP_RANGE its escape scores only the heading away from the Warden, so a dodge never closes.
func _escape(threats: Array, steer: Vector3, away: Node3D = null) -> Vector3:
	var ball: Vector3 = game.player.ball_position()
	var v: Vector3 = game.player.planar_velocity()
	var line := Vector3(v.x, 0.0, v.z).normalized() if v.length() > 1.0 else Vector3.ZERO
	var goal := Vector3(steer.x - ball.x, 0.0, steer.z - ball.z).normalized()
	if away != null and is_instance_valid(away) and _flat(ball, away.global_position) <= CAMP_RANGE:
		goal = Vector3(ball.x - away.global_position.x, 0.0, ball.z - away.global_position.z).normalized()
		line = Vector3.ZERO
	for reach in ESCAPE_REACH:
		var best := Vector3.INF
		var best_score := -INF
		for i in ESCAPE_DIRECTIONS:
			var angle := TAU * i / ESCAPE_DIRECTIONS
			var dir := Vector3(sin(angle), 0.0, cos(angle))
			var at := _ground_point(ball.x + dir.x * reach, ball.z + dir.z * reach)
			var safe := true
			for h in threats:
				if h.contains(at):
					safe = false
					break
			if not safe:
				continue
			var score := dir.dot(line) + 0.7 * dir.dot(goal)
			if score > best_score:
				best_score = score
				best = ball + dir * (reach + 6.0)
		if best != Vector3.INF:
			return best
	# Nowhere safe in reach: keep the line and jump, which clears a low ring's edge.
	source.press["jump_pressed"] = true
	return ball + (line if line != Vector3.ZERO else goal) * 12.0


func _ground_point(x: float, z: float) -> Vector3:
	var boss = _boss() if game.flow.state_name() == "boss" else null
	if boss != null and is_instance_valid(boss.get("arena")) and boss.arena.has_method("ground"):
		var p := Vector3(x, 0.0, z)
		return Vector3(x, boss.arena.ground(p) + 1.0, z)
	return game.ctx.terrain.drop_point(x, z, 1.0)


# The engineer's plant cycle. Returns the face to roll to while seeking, else INF.
func _plant(fight: Node3D, delta: float) -> Vector3:
	var ball: Vector3 = game.player.ball_position()
	match _plant_state:
		"idle":
			if _plant_cool > 0.0 or ball.distance_to(fight.global_position) > PLANT_RANGE:
				return Vector3.INF
			var face := _find_face(fight)
			if face == Vector3.INF:
				_plant_cool = 2.0
				return Vector3.INF
			_plant_face = face
			_plant_target = fight
			_plant_state = "seek"
			_plant_clock = 0.0
			return face
		"seek":
			_plant_clock += delta
			if _plant_clock > PLANT_TIMEOUT:
				_plant_state = "idle"
				_plant_cool = PLANT_EVERY
				return Vector3.INF
			if ball.distance_to(_plant_face) < PLANT_REACH:
				source.press["mount_pressed"] = true
			return _plant_face
	return Vector3.INF


# Mounted: turret on the aim, then slingshot off toward it, or drop off the post when the
# slingshot would come down off the fight's floor (_sling_lands_low).
func _turret(aim, delta: float) -> void:
	if _plant_state != "mounted":
		_plant_state = "mounted"
		_plant_clock = 0.0
	_plant_clock += delta
	var ball: Vector3 = game.player.ball_position()
	var look_at: Vector3 = _aim_point(aim) if _aim_valid(aim) else ball + game.camera.yaw_basis() * Vector3.FORWARD
	_look(ball, look_at, _aim_valid(aim), delta)
	source.hold = {"fire_held": true}
	var threatened := false
	for h in _threats():
		threatened = true
	if _plant_clock > TURRET_SECONDS or threatened or not _aim_valid(aim):
		if _sling_lands_low():
			source.press["mount_pressed"] = true
		else:
			source.press["jump_pressed"] = true
		_plant_state = "idle"
		_plant_cool = PLANT_EVERY


# The Hanging Isle (stage 5) holds the Mind fight: its small-ball pin was measured with the
# end-height slope test, and the two-half test moves that median (MIND-ROUTE, 2026-10-16).
func _in_mind_stage() -> bool:
	return int(_note.get("stage", 0)) == MIND_STAGE


# The end-height test plans the Mind stage's climbs until one runs past MIND_CLIMB_GIVE_UP.
func _mind_slope() -> bool:
	return _in_mind_stage() and not _mind_slope_spent


func _sling_lands_low() -> bool:
	var cone: Dictionary = game.player.kit.slingshot_aim
	if cone.is_empty():
		return false
	var p: Vector3 = game.player.ball_position()
	var low: float = _ground_point(p.x, p.z).y
	if is_instance_valid(_plant_target):
		low = minf(low, _ground_point(_plant_target.global_position.x, _plant_target.global_position.z).y)
	var v: Vector3 = (cone["dir"] as Vector3) * float(cone["speed"])
	var gravity: float = game.player.tuning.f("gravity")
	var t := 0.0
	while t < SLING_FLIGHT:
		p += v * SLING_STEP
		v.y -= gravity * SLING_STEP
		t += SLING_STEP
		var ground: float = _ground_point(p.x, p.z).y
		if v.y < 0.0 and p.y <= ground:
			return ground < low - LEVEL_BAND
	return true


# A steep face (a pylon can bite: |normal.y| < FACE_TILT) within PLANT_SEARCH, the one
# closest to the ball's side of the fight.
func _find_face(fight: Node3D) -> Vector3:
	var space = game.get_world_3d().direct_space_state
	var ball: Vector3 = game.player.ball_position()
	var to_fight := Vector3(fight.global_position.x - ball.x, 0.0, fight.global_position.z - ball.z).normalized()
	var best := Vector3.INF
	var best_score := INF
	for i in 16:
		var angle := TAU * i / 16.0
		var dir := Vector3(sin(angle), 0.0, cos(angle))
		var from := ball + Vector3.UP * 0.3
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * PLANT_SEARCH, 1))
		if hit.is_empty():
			continue
		var n: Vector3 = hit["normal"]
		if absf(n.y) >= FACE_TILT:
			continue
		var score: float = ball.distance_to(hit["position"]) - 6.0 * dir.dot(to_fight)
		if score < best_score:
			best_score = score
			best = hit["position"]
	return best


func _specials(fight: Node3D, pressed_by_threat: bool) -> void:
	if not _kit("special"):
		return
	var ball: Vector3 = game.player.ball_position()
	var near := 0
	for node in game.get_tree().get_nodes_in_group("enemy"):
		if node is Node3D and is_instance_valid(node) and ball.distance_to(node.global_position) < CROWD_RADIUS:
			if not (node.has_method("is_dead") and node.is_dead()):
				near += 1
	var close: bool = fight != null and is_instance_valid(fight) and ball.distance_to(fight.global_position) < CLOSE_FIGHT
	if near >= CROWD or close or (pressed_by_threat and near >= 1):
		_cast(2)


# --- the skill bar's hands (SKILL-BAR section 8) ---------------------------------------

# Starts a cast of bar slot `slot` (2 or 3): the number key, then a left click held for
# hold_seconds (0 is a tap: the click comes up on the next tick, so a gauge fires at its floor,
# as the old one-tick special press did). False when the slot does not read ready on the bar,
# a cast is already in hand, or a set piece runs.
func _cast(slot: int, hold_seconds := 0.0) -> bool:
	if _cast_phase == "await_smash": _await_smash_holds()
	if slot == 3 and game.player.abilities.id_of(AbilityState.LINE) == "bank_shot" and source.press.get("harpoon_released", false): return false
	if _cast_phase != "" or _set_piece_up() or slot < 2 or slot > AbilityState.BAR.size():
		return false
	if _bar_state(slot) != AbilityState.READY or (slot == 3 and _line_loaded()):
		return false
	_cast_slot = slot
	_cast_hold = hold_seconds
	_cast_phase = "click"
	return true


# The bar slot's state as the bar draws it (ready, cooling, active or unavailable).
func _bar_state(slot: int) -> String:
	for s in game.player.abilities.slots():
		if int(s["number"]) == slot:
			return String(s["state"])
	return AbilityState.UNAVAILABLE


# Sends the cast in hand into this tick's keys. Runs after _drive has built the hold, so the
# click it writes is the one the router reads.
func _cast_hands() -> void:
	var abilities = game.player.abilities
	var name: String = AbilityState.BAR[_cast_slot - 1] if _cast_slot >= 1 else ""
	match _cast_phase:
		"click":
			# A pick of the number already selected is the undo gesture, so a slot still picked
			# (a refused cast keeps its pick) gets only the click.
			if abilities.selected != name:
				source.press["slot_pick"] = _cast_slot - 1
			if policy == "traversal":
				_cast_phase = "sent"
				source.hold.erase("fire_held")
				return
			# A click is down on the tick it goes down, as a mouse reports it: the press and the
			# hold together. A tap lets it up on the next tick. (2026-10-11 fix round: the tap
			# used to send the press with the click already up, an input no mouse makes.)
			source.press["fire_pressed"] = true
			source.hold["fire_held"] = true
			_cast_phase = "hold" if _cast_hold > 0.0 else "release"
		"hold":
			_cast_hold -= 1.0 / Engine.physics_ticks_per_second
			source.hold["fire_held"] = true
			if _cast_hold <= 0.0:
				_cast_phase = "release"
		"release":
			# The click comes up for a tick: a gauge fires, and the release latch clears.
			source.hold.erase("fire_held")
			if abilities.selected == name and not abilities.charging():
				source.press["slot_pick"] = 0
			_cast_phase = ""


# Slot 3 while a body line stands on an enemy within LINE_CAST_REACH. The load before a planned
# bite is cast from _harpoon_hand, on the bite's own tick.
func _line_hands() -> void:
	if not _kit("line_cast"):
		return
	var kit = game.player.kit
	if not kit.hooked or not kit.on_body or not is_instance_valid(kit.anchor_body):
		return
	var body: Node3D = kit.anchor_body
	if not body.is_in_group("enemy"):
		return
	if game.player.ball_position().distance_to(body.global_position) <= LINE_CAST_REACH:
		_cast(3)


# A load waits on the next bite; the bar refuses a second cast while one does.
func _line_loaded() -> bool:
	var combat = game.get("combat")
	return combat != null and combat.has_method("line_load") and not (combat.line_load() as Dictionary).is_empty()


func _set_piece_up() -> bool:
	var combat = game.get("combat")
	return combat != null and combat.get("ultimate") != null and combat.ultimate.phase() != "idle"


# Q at a full meter: a Warden core open within ULT_CORE_REACH, or ULT_CROWD enemies within
# ULT_CROWD_RADIUS; for the traversal pilot, a next waypoint ULT_TRAVERSE_NEAR to
# ULT_TRAVERSE_FAR ahead with the way clear. The set piece flies where the camera looks, and
# every policy is already looking at its target or along its way.
func _ultimate_hands(fight: Node3D) -> void:
	if _cast_phase == "await_smash": _await_smash_holds()
	if not _kit("ultimate"):
		return
	if _ult_wait > 0.0 or _set_piece_up() or _cast_phase != "":
		return
	if String(game.player.abilities.ultimate().get("state", "")) != AbilityState.READY:
		return
	var ball: Vector3 = game.player.ball_position()
	var want := false
	if policy == "traversal":
		if _traverse_point != Vector3.INF:
			var ahead := _flat(ball, _traverse_point)
			want = not _hand_aim and ahead >= ULT_TRAVERSE_NEAR and ahead <= ULT_TRAVERSE_FAR and _way_clear(ball, _traverse_point)
	elif band != null and not band.timed_ultimate():
		# Below the Expert the press is untimed: the meter is ready and a fight is on.
		var near_lock: bool = fight != null and is_instance_valid(fight) and ball.distance_to(fight.global_position) <= ULT_CROWD_RADIUS
		want = near_lock or _enemies_within(ball, ULT_CROWD_RADIUS) >= 1
	else:
		want = _core_open(fight, ball) or _enemies_within(ball, ULT_CROWD_RADIUS) >= ULT_CROWD
	if not want:
		return
	source.press["ultimate_pressed"] = true
	_ult_wait = ULT_RETRY
	_totals["ult_presses"] = int(_totals["ult_presses"]) + 1


# A staggered Warden or boss hull is an open core: the fight lock, the stage Warden or the boss's.
func _core_open(fight: Node3D, ball: Vector3) -> bool:
	var cores: Array = [fight]
	if game.flow != null and is_instance_valid(game.flow.warden):
		cores.append(game.flow.warden)
	var boss = _boss() if game.flow.state_name() == "boss" else null
	if boss != null:
		if boss.get("ship") != null and is_instance_valid(boss.ship.hull):
			cores.append(boss.ship.hull)
		if boss.get("warden") is Node3D:
			cores.append(boss.get("warden"))
	for core in cores:
		if core == null or not is_instance_valid(core) or not core.has_method("staggered"):
			continue
		if core.staggered() and ball.distance_to(core.global_position) <= ULT_CORE_REACH:
			return true
	return false


func _enemies_within(ball: Vector3, radius: float) -> int:
	var near := 0
	for node in game.get_tree().get_nodes_in_group("enemy"):
		if node is Node3D and is_instance_valid(node) and ball.distance_to(node.global_position) < radius:
			if not (node.has_method("is_dead") and node.is_dead()):
				near += 1
	return near


# While the set piece runs only the stick, Space and Q reach the ball, and Space bails the
# flight and Q recalls the wind-up: the hands send neither.
func _set_piece_hands() -> void:
	if not _set_piece_up():
		return
	source.press.erase("jump_pressed")
	source.press.erase("ultimate_pressed")


# --- the hands: stick, mouse and buttons -----------------------------------------------

static func _plate_contains(plate: Dictionary, ball: Vector3) -> bool:
	var rect: Rect2 = plate["rect"]
	return ball.x >= rect.position.x and ball.x <= rect.end.x and ball.z >= rect.position.y and ball.z <= rect.end.y


func _plate_shortcut(steer: Vector3, ball: Vector3) -> Dictionary:
	if not game.flow.in_stage() or ball.y - steer.y <= LEVEL_BAND or game.world.breach == null:
		return {}
	var chosen := {}
	var nearest := PLATE_REACH
	for plate in game.world.breach.plates:
		if game.world.breach.breached(plate["id"]):
			continue
		var centre: Vector2 = (plate["rect"] as Rect2).get_center()
		var at := Vector3(centre.x, ball.y, centre.y)
		var distance := _flat(ball, at)
		if distance <= nearest and _flat(at, steer) <= _flat(ball, steer):
			chosen = plate
			nearest = distance
	return chosen


func _inside_thermal(ball: Vector3) -> bool:
	if not game.flow.in_stage() or not game.player.kit.on("glide"):
		return false
	var map = game.ctx.terrain.map()
	if not "contraptions" in map:
		return false
	for spec in map.contraptions:
		if spec["kind"] == "thermal" and Vector2(ball.x, ball.z).distance_to(spec["at"]) <= float(spec["radius"]):
			return true
	return false


# Rolls toward steer and looks at aim (or along the way when there is nothing to aim
# at). The stick is set in the camera's frame, as a person's WASD is.
func _drive(steer: Vector3, aim, delta: float) -> void:
	var player = game.player
	var ball: Vector3 = player.ball_position()
	_plate_hand = _plate_shortcut(steer, ball)
	var on_plate := not _plate_hand.is_empty() and _plate_contains(_plate_hand, ball)
	if not _plate_hand.is_empty():
		var centre: Vector2 = (_plate_hand["rect"] as Rect2).get_center()
		steer = Vector3(centre.x, ball.y, centre.y)
	var thermal := _inside_thermal(ball)
	var speed: float = player.planar_velocity().length()
	# A ball wedged against a wall or a lip, off the ground and off any line, is as stuck as one
	# on the ground (flume seed 1 sat 100 s at (271, 0, 473) after #442 with no detour).
	# A thermal's hang and a hold (a boss grab, a counter's tether) are not wedges.
	var fleet = game.ctx.spawner.get("fleet") if game.ctx.spawner != null else null
	var held: bool = fleet != null and fleet.holds != null and fleet.holds.holding()
	var wedged: bool = not player.state.grounded and not player.kit.hooked and not player.frozen() and not thermal \
			and not held and absf(player.state.velocity.y) < STUCK_SPEED
	if speed < STUCK_SPEED and (player.state.grounded or wedged):
		_slow_time += delta
	else:
		_slow_time = 0.0
	if _slow_time > STUCK_SECONDS and _detour_time <= 0.0:
		_slow_time = 0.0
		_detour_time = DETOUR_SECONDS
		var to := Vector3(steer.x - ball.x, 0.0, steer.z - ball.z).normalized()
		_detour = to.rotated(Vector3.UP, PI * 0.5 * (1.0 if rng.randf() < 0.5 else -1.0))
		_wall_side = 0.0
		source.press["jump_pressed"] = true
		_count("stuck_detours")
	var heading := Vector3(steer.x - ball.x, 0.0, steer.z - ball.z)
	if _detour_time > 0.0:
		_detour_time -= delta
		heading = _detour
	elif player.state.grounded and not _ignore_walls and not _recover_climb:
		heading = _around_walls(ball, heading)
	var hold := {"fire_held": _throw_hold(aim)}
	var look_at: Vector3 = ball + heading
	var aiming := _aim_valid(aim)
	if aiming:
		look_at = _aim_point(aim)
	_look(ball, look_at, aiming, delta)
	var yaw: float = game.camera.yaw
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	if heading.length() > 0.3:
		var dir := heading.normalized()
		# Steer the velocity, not the ball: push toward the change that turns the current
		# velocity onto the target at the same speed, so a fast ball does not orbit it.
		var v: Vector3 = player.planar_velocity()
		v.y = 0.0
		var change := dir * maxf(v.length(), 12.0) - v
		# The circling policies hold cruise speed: they aim the velocity at cruise along dir, so above cruise the stick
		# turns and slows the ball (a released stick let a downhill ring roll the ball 600 m off it, crown seed 1).
		if _cruise_hold:
			change = dir * player.tuning.f("cruise") - v
		var want := dir if change.length() < 0.5 else change.normalized()
		hold["move"] = Vector2(want.dot(right), want.dot(forward)).normalized()
		# At cruise the stick comes off, so the ball coasts at it instead of accelerating past.
		if _cruise_hold and change.length() < 0.5:
			hold["move"] = Vector2.ZERO
		var lined: float = v.normalized().dot(dir) if v.length() > 0.5 else 1.0
		# No brake-carving: brake is also the slam key, and a carve held over a bump
		# becomes a slam that plants the ball (seen on the Slag Bowl's bank).
		if _boost_clock <= 0.0 and lined > 0.9 and player.state.grounded and player.verb_ready("boost") and not _cruise_hold:
			_boost_clock = BOOST_GAP
			_shift_left = SHIFT_HOLD
			source.press["shift_pressed"] = true
	if _shift_left > 0.0:
		_shift_left -= delta
		hold["shift_held"] = true
	if _harpoon_held:
		hold["harpoon_held"] = true
	if _harpoon_commit:
		hold["brake_held"] = true
	if on_plate:
		# Stay over the opening through the jump and landing, without a ground brake press.
		hold["move"] = Vector2.ZERO
		hold.erase("shift_held")
		source.press.erase("shift_pressed")
		if player.state.grounded:
			source.press["jump_pressed"] = true
		elif player.state.velocity.y < 2.0:
			hold["brake_held"] = true
	if _glide_held and not thermal:
		# The glide hand's drop: spend the air jump, then hold the key while falling. A blink
		# would leave the footprint, as in the thermal branch.
		hold.erase("shift_held")
		source.press.erase("shift_pressed")
		if player.state.air_actions > 0:
			source.press["jump_pressed"] = true
		elif player.state.velocity.y < 0.0 and not player.kit.slamming:
			hold["jump_held"] = true
	if thermal:
		# Spend the air jump before glide can engage; a blink would leave the footprint.
		hold.erase("shift_held")
		source.press.erase("shift_pressed")
		if player.state.grounded or player.state.air_actions > 0:
			source.press["jump_pressed"] = true
		elif player.state.velocity.y < 0.0 and not player.kit.slamming:
			hold["jump_held"] = true
	# Jump, boost and movement abilities cancel a committed body-line haul. Outside a boss
	# the explorer's two-hook hand keeps them: it jumps and boosts off its lines on purpose.
	var chain_hand: bool = policy == "completionist" and chain_hand_enabled and _chain_phase != "" and not _in_boss()
	if not chain_hand and (_harpoon_commit or (player.kit.hooked and player.kit.line_state == Augments.LINE_SMASH)):
		source.press.erase("jump_pressed")
		source.press.erase("shift_pressed")
		source.press.erase("movement_pressed")
		hold.erase("shift_held")
	source.hold = hold
	_card_hands()
	_cast_hands()


# Tally's reader runs a card per press, not while held: the hands turn a held trigger into one
# press every CARD_PRESS_GAP seconds. Since the skill bar her reader holds one card (Balance Due)
# on slot 1 and the bays are gone, so there is no bay to keep loaded. Slots 2 and 3 and Q go
# through the shared hands; slot 2 also plants a plate when TALLY_PLATE_CROWD ordinary enemies
# stand within TALLY_GATHER_RADIUS of a valid aim point, and Q also fires when her gather plate
# lies within TALLY_PLATE_REACH with TALLY_PLATE_CROWD enemies within TALLY_PLATE_RADIUS of it
# (pilots/tally.md section 9).
const TALLY_PLATE_REACH := 45.0
const TALLY_PLATE_CROWD := 3
const TALLY_PLATE_RADIUS := 6.0
const TALLY_GATHER_RADIUS := 12.0


func _card_hands() -> void:
	if game.player.abilities.cap(AbilityState.WEAPON, "cards", null) == null:
		return
	# The press conversion below is the weapon and always runs. The gather plate is a slot 2 cast
	# and the plate burst is Q, so each follows its verb. At base the plate burst stays as it is:
	# it is a crowd read near an untimed press.
	if _kit("special"):
		_tally_gather_hands()
	if _kit("ultimate"):
		_tally_plate_hands()
	if not source.hold.get("fire_held", false):
		return
	source.hold.erase("fire_held")
	if ticks - _card_press_tick >= int(ceil(CARD_PRESS_GAP * Engine.physics_ticks_per_second)):
		source.press["fire_pressed"] = true
		_card_press_tick = ticks


func _tally_gather_hands() -> void:
	var combat = game.get("combat")
	if combat == null or _cast_phase != "" or _set_piece_up() or not combat.has_method("_card_aim"):
		return
	var aim: Dictionary = combat._card_aim()
	if not aim["valid"]:
		return
	var ordinary := 0
	for node in game.get_tree().get_nodes_in_group("enemy"):
		if node is Node3D and is_instance_valid(node) and not (node.has_method("is_dead") and node.is_dead()) \
				and combat._ordinary(node) and node.global_position.distance_to(aim["point"]) <= TALLY_GATHER_RADIUS:
			ordinary += 1
	if ordinary >= TALLY_PLATE_CROWD:
		_cast(2)


func _tally_plate_hands() -> void:
	var combat = game.get("combat")
	if combat == null or _ult_wait > 0.0 or _set_piece_up() or _cast_phase != "":
		return
	if String(game.player.abilities.ultimate().get("state", "")) != AbilityState.READY:
		return
	var plate: Dictionary = combat.get("plate") if combat.get("plate") != null else {}
	if plate.is_empty() or game.player.ball_position().distance_to(plate["at"]) > TALLY_PLATE_REACH:
		return
	if _enemies_within(plate["at"], TALLY_PLATE_RADIUS) < TALLY_PLATE_CROWD:
		return
	source.press["ultimate_pressed"] = true
	_ult_wait = ULT_RETRY
	_totals["ult_presses"] = int(_totals["ult_presses"]) + 1


# A wall (a face steeper than WALL_TILT) within WALL_REACH on the way is rolled around:
# the heading turns to the nearest free bearing, as a player steers round a post, on the side
# already held while the straight way stays walled.
func _around_walls(ball: Vector3, heading: Vector3) -> Vector3:
	if heading.length() < 0.3:
		return heading
	var space = game.get_world_3d().direct_space_state
	var dir := heading.normalized()
	if _wall_side != 0.0 and rad_to_deg(dir.angle_to(_wall_dir)) > WALL_SIDE_KEEP_DEG:
		_wall_side = 0.0
	var from := ball + Vector3.UP * 0.2
	for turn in WALL_TURNS:
		if turn * _wall_side < 0.0:
			continue
		var probe := dir.rotated(Vector3.UP, turn)
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + probe * WALL_REACH, 1))
		if hit.is_empty() or absf((hit["normal"] as Vector3).y) >= WALL_TILT:
			if turn != 0.0:
				_count("wall_turns", 1.0 / Engine.physics_ticks_per_second)
			_wall_side = signf(turn)
			_wall_dir = dir
			return probe * heading.length()
	# Every turn on the held side is walled: the side is dropped and the whole fan tried again, so a
	# ball boxed in on that side steers the other way or straight on as before the side was held,
	# not 1.5 rad off its goal (random seed 2869 on the park table stalled riding the pit Warden
	# while that turn was pressed).
	if _wall_side != 0.0:
		_wall_side = 0.0
		return _around_walls(ball, heading)
	return heading


# Turns the camera toward the point. The traversal pilot defers the turn: it is measured
# from where the camera will be once the turns still waiting in the buffer have gone out,
# and kept in _look_delta for _traverse to send late.
func _look(ball: Vector3, point: Vector3, pitch_to: bool, delta: float) -> void:
	var cam = game.camera
	var yaw: float = cam.yaw
	var pitch: float = cam.pitch
	if _defer_look:
		for waiting in _out:
			yaw += waiting["look"].x
			pitch += waiting["look"].y
	var flat := Vector3(point.x - ball.x, 0.0, point.z - ball.z)
	var dyaw := 0.0
	if flat.length() > 0.3:
		var want := atan2(-flat.x, -flat.z)
		dyaw = clampf(wrapf(want - yaw, -PI, PI), -TURN_RATE * delta, TURN_RATE * delta)
	var want_pitch := -0.30
	if pitch_to and flat.length() > 0.5:
		var pivot := ball + Vector3.UP * 0.8
		want_pitch = clampf(atan2(point.y - pivot.y, flat.length()), -1.2, 0.5)
	var dpitch := clampf(want_pitch - pitch, -TURN_RATE * delta, TURN_RATE * delta)
	if _defer_look:
		_look_delta = Vector2(dyaw, dpitch)
		return
	# camera.look takes mouse pixels: yaw -= x * s, pitch -= y * s.
	cam.look(Vector2(-dyaw / SENSITIVITY, -dpitch / SENSITIVITY))


static func _aim_valid(aim) -> bool:
	if aim is Dictionary:
		return aim.has("at")
	return aim != null and is_instance_valid(aim)


func _aim_point(aim) -> Vector3:
	if aim is Dictionary:
		return aim["at"]
	var target: Node3D = aim
	return target.global_position + Vector3.UP * 1.2


# --- the anti-kiting gates' contact record (every policy) ---------------------------------

# Opens the stage's contact the first tick a live enemy is within CONTACT_RADIUS of the ball. Reads only; it moves nothing.
func _contact_scan() -> void:
	if _note.is_empty() or _note.get("first_contact_s") != null or not game.flow.in_stage():
		return
	var ball: Vector3 = game.player.ball_position()
	for node in game.get_tree().get_nodes_in_group("enemy"):
		if not node is Node3D or not is_instance_valid(node):
			continue
		if node.has_method("is_dead") and node.is_dead():
			continue
		if ball.distance_to(node.global_position) <= CONTACT_RADIUS:
			_note["first_contact_s"] = snappedf(game.run.stage_time, 0.01)
			return


# Whether this stage's contact has opened (a pack within CONTACT_RADIUS, or a first hit). The ringless plant reads it.
func contact_open() -> bool:
	return not _note.is_empty() and _note.get("first_contact_s") != null


# A hit on the stage: its first, and the hull it cost inside the contact window.
func _note_contact_hit(hull: float) -> void:
	if _in_boss() or _note.is_empty():
		return
	var now := float(game.run.stage_time)
	if _note.get("first_hit_s") == null:
		_note["first_hit_s"] = snappedf(now, 0.01)
	if _note.get("first_contact_s") == null:
		_note["first_contact_s"] = snappedf(now, 0.01)
	if now - float(_note["first_contact_s"]) <= CONTACT_WINDOW_S:
		_note["hull_lost_120s"] = float(_note["hull_lost_120s"]) + hull


func _close_contact() -> void:
	_note["hull_lost_120s"] = snappedf(float(_note["hull_lost_120s"]), 0.1)
	_note["fight_s"] = snappedf(float(_note["fight_s"]), 0.01)
	_note["circle_s"] = snappedf(float(_note["circle_s"]), 0.01)
	if _note["first_contact_s"] != null:
		_note["alive_120s"] = snappedf(clampf(float(_note["exit_s"]) - float(_note["first_contact_s"]), 0.0, CONTACT_WINDOW_S), 0.01)
	# circle_share: seconds on the ring over the window (first contact to its end or death), the anchor policies' measure.
	if _note["alive_120s"] != null and float(_note["alive_120s"]) > 0.0:
		_note["circle_share"] = snappedf(float(_note["circle_s"]) / float(_note["alive_120s"]), 0.001)


# The boss's committed hazards, for the fairness recorder's read of every published telegraph.
func boss_hazards() -> Array:
	var boss = _boss() if game.flow.state_name() == "boss" else null
	return boss.active_hazards() if boss != null and boss.has_method("active_hazards") else []


# The test-only hide_pack_telegraphs plant: the committed telegraphs of every enemy but the Warden, and the shells a
# lobber fired. The game still draws them; only this driver does not see them.
func _pack_telegraphs() -> Dictionary:
	var out := {}
	for node in game.get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(node) or node == game.flow.warden:
			continue
		var t = node.get("_telegraph")
		if t != null and is_instance_valid(t):
			out[t] = true
	for child in game.get_children():
		if child.get_script() != null and String(child.get_script().resource_path).ends_with("projectile.gd"):
			var ring = child.get("ring")
			if ring != null and is_instance_valid(ring) and child.get("lobber") != game.flow.warden:
				out[ring] = true
	return out


func _nearest_enemy() -> Node3D:
	var ball: Vector3 = game.player.ball_position()
	var best: Node3D = null
	var best_d := AIM_REACH
	for node in game.get_tree().get_nodes_in_group("enemy"):
		if not node is Node3D or not is_instance_valid(node):
			continue
		if node.has_method("is_dead") and node.is_dead():
			continue
		var d := ball.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


func _vault() -> Node3D:
	var world = game.world
	if world == null or world.vault == null or not is_instance_valid(world.vault):
		return null
	return world.vault


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# The sidecar record: who drove, what happened, how long it took.
func record(wall_seconds: float) -> Dictionary:
	var row := {
		"run_id": game.run.run_id, "policy": policy, "profile": profile, "seed": seed_value, "class": class_id(),
		"outcome": outcome, "stage_reached": game.run.stage, "ticks": ticks,
		"game_seconds": snappedf(float(ticks) / float(Engine.physics_ticks_per_second), 0.01),
		"wall_seconds": snappedf(wall_seconds, 0.01), "stages": stage_notes,
		"boss": boss_note if not boss_note.is_empty() else null,
		"reaction_s": _reaction(),
		"fairness": _fair.record(outcome == "died" or outcome == "lost"),
		"band": band.describe() if band else null,
		"min_hp": snappedf(_min_hp, 0.1) if _min_hp != INF else null, "max_hp": game.run.max_hp,
		# The skill bar (SKILL-BAR section 8): casts of slots 2 and 3, set pieces started, Q presses,
		# the in-play seconds each fill took (run start or the last set piece to a full meter), and
		# the in-play seconds played, which bounds a meter that never filled.
		"slot_casts": {"special": _totals["slot_casts_special"], "line": _totals["slot_casts_line"]},
		"shots": _totals["shots"], "ultimates": _totals["ultimates"], "ult_presses": _totals["ult_presses"],
		"ult_fill_s": _fills, "play_s": snappedf(_play_clock, 0.01),
		# The meter's points by source: over the run, and at the first full meter. A record for
		# reading why a fill band is red; no hand reads either.
		"ult_sources": _meter_sources(), "ult_sources_first_fill": _first_fill_sources,
	}
	if late_offer_policy != "":
		row["late_offer"] = {"policy": late_offer_policy, "tree_picks": tree_picks.size()}
		row["late_offer"].merge(late_offer_counts)
	var dials := ChallengeDials.describe()
	if not dials.is_empty():
		row["dials"] = dials
	# The pack pressure counts (combat/pack_pressure.gd): when a pressure dial is moved, or the shipped
	# silt boils fired.
	var spawner = game.ctx.spawner
	var pressure_dials := dials.keys().any(func(k: String) -> bool: return k.begins_with("pack.") or k.begins_with("ground.") or k.begins_with("hazard."))
	if spawner != null and spawner.get("churn") != null and (pressure_dials or spawner.boils.boils > 0):
		row["pressure"] = {"churn_drag_s": snappedf(spawner.churn.drag_s, 0.01), "churned_cells": spawner.churn.churned_cells,
			"boils": spawner.boils.boils, "boil_hits": spawner.boils.ball_hits, "boil_tosses": spawner.boils.enemy_tosses}
	return row

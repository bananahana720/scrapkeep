# Pilot ball motion spec

What every part of the pilot ball does in each movement situation, checked against the code. Written 22 Oct 2026 by a coherence review: three Opus 5.5 reviewers (rig and physics, boards against the rig, visual read at chase size) and one Opus 5.5 architect. Evidence is level 2 to 3: the reviewers read the code and worked the geometry, but ran and rendered nothing. Real frames come from the render requests at the end.

Movement boards and every Animation, Systems, Effects and Modeling unit that touches the ball build from this file. A board panel that draws motion this file does not support must carry a PROPOSAL label.

## Verdict

The pilot ball is only partly coherent at this baseline (`b` review snapshot). Physics is honest and the layer split is right on flat ground: the lattice shows the true roll, the cockpit pod stays level and turns to the heading, and the weapon ring turns to the aim (`player_ball.gd`, `hero_assets.gd`). **Note:** The four historical October 22 rig fixes flagged below (pod under `pod_mount()`, gimbal rings decoupled via `carrier_bank`, fairlead rope exits, and cutaway shell normalization) were subsequently landed in `player_ball.gd`, `hero_assets.gd`, and `line_view.gd` (see ruling `dm` and `en`). At the Oct 22 audit, it stopped making sense in four places: presentation squashed/inflated the pod under the Juice node, gimbal rings copied lattice tumble, the rope/cableway left through the ball center, and level hardware cut steep walls. (Code and geometry read; no live renders taken in that pass.)

## Situations

### Shared rule for every situation (radius ladder and what moves)

Status: **works with a fix**

- **Lattice:** The rolling wheel. It tumbles freely with the true rigid-body spin (rigid_ball.gd:42-65, player_ball.gd:1103-1104). Faces sit at 0.94-0.975, caps at 0.985, inside a collider of radius 1.0 that never changes. Nothing scales the lattice except the landing clench.
- **Pod and pilot:** Always level with gravity (player_ball.gd:1100). It turns only to the heading, within limits (see the rolling row). The pod is never scaled, squashed or stretched. Ladder from the inside out: pilot reach up to 0.80 (after the three clip re-keys, cage_contract_test.gd:60-69), optional inner sphere at about 0.815, gimbal rings 0.83-0.865, panels 0.88-0.92.
- **Weapon ring and carrier:** The level carrier: the band, the bearing collar and the gap-bracket modules (ring 1.02-1.10, modules up to 1.25). The ring turns to the aim on its bearing (hero_assets.gd:755-769). Story: an electromagnetic field bearing across the 0.985-1.02 air gap (BIBLE.md:42 'electromagnetic mech'). That is why nothing solid crosses the tumbling lattice. Proposed: the carrier banks toward a steep contact face just enough to keep every carrier part off that face.
- **Rope:** Proposed: the rope always leaves a fairlead that runs round the collar, on the anchor's side, at about r 1.06. It never leaves the centre. The collar is a free bearing, so the pull still acts through the centre with no torque, which matches the physics at augments.gd:722-743.
- **Heft:** Growth shows as panels on the pod, thicker caps, heavy module forms and accretion chunks. The lattice radius stays fixed (Andrew, 22 Oct, "Fixed outline"). The outline barely grows (ROSTER-LOOK.md:275).
- **Camera:** World-up chase rig, unchanged: arm 7.5 to 10.5 m, lens 65 to 80 degrees, roll capped at 0.13 rad (chase_camera.gd:219-256).

### Flat rolling and steering

Status: **works with a fix**

- **Lattice:** Rolls at w = v/R. Correct today.
- **Pod and pilot:** The pod turns to the heading at rate 10 (hero_assets.gd:602-604). Fix: clamp the pod's yaw to within 45 degrees of the camera yaw, so the panelled flank never faces the chase eye during a strafe or look-around (the camera yaw is the player's, chase_camera.gd:113-127, 242). The gimbal rings hold their rest pose on flat ground. Today they spin at the full roll rate.
- **Weapon ring and carrier:** Level, turns to the aim at rate 14. Correct today, and pinned at cage_contract_test.gd:306-312.
- **Rope:** None.
- **Heft:** Panels stay fixed in pod space and the struts roll past in front of them (ROSTER-LOOK.md:59).
- **Camera:** Unchanged.

### Rolling at the speed soft cap (30 to 60 m/s)

Status: **works with a fix**

- **Lattice:** True spin, about 4.8 rev/s at 30 m/s and 9.5 rev/s at 60. Strobe fix: a chalk balance mark on one tread cap, varied tread rotation per cap, and a speed blur over the strut layer from the fast tier up. The 10% stretch along the travel line is removed (juice.gd:286-288).
- **Pod and pilot:** Level, unscaled, with no stretch. The rings stay still, so the head is not crossed by spinning hoops.
- **Weapon ring and carrier:** Level, aimed, unscaled.
- **Rope:** None.
- **Heft:** Panels are on the pod, so they do not strobe. Chunks on lattice hubs still roll and tuck under the existing tuck rule.
- **Camera:** The fast profile at 10.5 m and 80 degrees puts the head at about 29 px (ROSTER-LOOK.md:193).

### Side and wall riding (sinkhole glazed band, flume chute, halfpipe walls)

Status: **works with a fix**

- **Lattice:** Grip from the fast tier down to a contact normal y of -0.2. carve_spin gives a correct no-slip spin about the wall (ball_rules.gd, tuning.gd:100-109, rigid_ball.gd:132-134). Correct today.
- **Pod and pilot:** Level with gravity, facing along the wall. This is the core gyrosphere read and it works today. The gimbal rings tilt only by the carrier's bank.
- **Weapon ring and carrier:** Today the level band, at 1.10 against the 1.0 collider, sinks about 0.10 m into faces steeper than about 65 degrees. The low side modules clip banks from about 25-35 degrees (ROSTER-LOOK.md:209 guards only below Z -0.6). Fix (carrier bank): the carrier tilts toward the smoothed contact normal by the smallest angle that keeps its support distance along the normal at 0.99 m or less. That is 0 degrees on floors and gentle slopes, and about 38 degrees on a vertical wall for 1.25 m modules. It is smoothed, so it never pops.
- **Rope:** None, or the fairlead as in the swing row.
- **Heft:** Today at class V the visual is 1.4x and shifted 0.4 m along the raw contact normal, so it jumps on every take or peel and overlaps a tube's far wall (juice.gd:289-293, ball_rules.gd:131-139). Fix: shell 1.0, so the shift disappears.
- **Camera:** World-up and yaw only. It suits the level cockpit. Watch the spring arm in enclosed tubes (inference).

### Halfpipe apex reversal

Status: **works with a fix**

- **Lattice:** True spin slows and reverses through the contact. Correct.
- **Pod and pilot:** The pod holds its yaw below 1.5 m/s (hero_assets.gd:602). After the apex it turns back at rate 10, which is about 0.3 s of pilot whip. Fix: with the camera clamp the whip is bounded to 90 degrees. Add a slower turn rate on reversal.
- **Weapon ring and carrier:** Holds the aim and carries the carrier bank on the steep lip.
- **Rope:** None.
- **Heft:** As in the wall row.
- **Camera:** Unchanged.

### Grinding or riding a rail or cable (cableway, grapple line)

Status: **design change needed**

- **Lattice:** Today every ride tick forces a floor-roll spin, so the wheel spins in mid-air and snaps on release (rigid_ball.gd:105-108 via set_velocity_now). Fix: keep the existing spin on held rides and let it decay with angular damping.
- **Pod and pilot:** Level. Today the 0.18 m cable runs through the ball's centre and the cockpit (ride_rail.gd:77-91, contraptions.gd:264-271).
- **Weapon ring and carrier:** Level, aimed.
- **Rope:** Fix: hold the ball centre a hanging distance below the cable. Draw a short hanger from the collar fairlead up to a trolley clamp on the cable, reusing the cable ribbon. There is no rail grind in the game.
- **Heft:** Unchanged once the shell is 1.0.
- **Camera:** Unchanged.

### Ramp and kicker launches, and air time

Status: **works with a fix**

- **Lattice:** Free air keeps its spin (angular damp 0.25, rigid_ball.gd:51). Contraption arcs force the floor-roll spin each tick. Fix: keep the spin, as in the ride row.
- **Pod and pilot:** Level and unscaled. Today a jump stretches the whole rig by 0.22-0.28 (juice.gd:255-256). Remove that from the pod. The optional gimbal sway (6 degrees, ROSTER-LOOK.md:181) may pitch the seat on take-off.
- **Weapon ring and carrier:** Level, aimed, no stretch. The carrier bank returns to 0 in the air, because the airborne normal is world up.
- **Rope:** None.
- **Heft:** No inflation.
- **Camera:** The falling profile pushes the arm to 12 m when vy < -8 (chase_camera.gd profiles).

### Harpoon latch, swing on the rope, fling release

Status: **works with a fix**

- **Lattice:** The swing leaves the spin alone, which is honest. Today the fling and pole exit reset the spin in mid-air (player_ball.gd:1081, 1094). Fix: keep the spin.
- **Pod and pilot:** Fix: while hooked, the pod faces the anchor's planar direction, so the pilot does not whip 180 degrees at each apex (hero_assets.gd:600-604).
- **Weapon ring and carrier:** Keeps the aim. It is the turret read.
- **Rope:** Today it is drawn from the ball's centre through the pilot (line_view.gd:147, 259). RopeExit is read only by tests (world_one_shell_sable_test.gd:267). Fix: draw it from the collar fairlead toward the anchor. The line then always runs outside the collider and never crosses the struts or the pilot.
- **Heft:** No inflation.
- **Camera:** Unchanged.

### Reel and haul toward the anchor

Status: **works with a fix**

- **Lattice:** Keeps its spin. The winch adds velocity only (augments.gd:728-735). Correct.
- **Pod and pilot:** Faces the anchor, as in the swing row. Its back is to a camera aimed at the anchor, which is a clean read.
- **Weapon ring and carrier:** Aimed. At impact the band and forward modules reach past the collider by up to 0.10-0.25 m. That is accepted look-only overhang.
- **Rope:** From the collar fairlead, taut. Sable's spool, and each pilot's winch module, turns while reeling (Animation).
- **Heft:** Without the 1.4x inflation, impacts no longer sink 0.365 m into targets.
- **Camera:** Locked profile (chase_camera.gd:28).

### Air slam and the dunk landing, including the stored dunk charge

Status: **works with a fix**

- **Lattice:** Pinned on landing with its spin halved (augments.gd:568-575, 693-696). Then the landing clench below.
- **Pod and pilot:** Today the slam squashes the pilot and pod by 0.3-0.45, along an axis that is world up whenever the hit lands in the air (juice.gd:259-262, ball_rules.gd:139). Fix: the pod is never scaled. The pilot plays drop_land and the seat dips on its gimbal.
- **Weapon ring and carrier:** Unscaled. Proposed: the stored dunk charge shows on the collar's rear arc, or on the seat-back DecalPlate, in class colour (DECISIONS.md:248 d). It is not built yet (GROUNDING.md:113).
- **Rope:** The next reel impact spends the charge, a planned Systems card.
- **Heft:** No inflation.
- **Camera:** Kick plus punch FOV (juice.gd:263-265). Keep it.

### Hard landing (the lattice fold)

Status: **design change needed**

- **Lattice:** Fix: the lattice alone clenches uniformly to about 0.97 and springs back over 0.25 s, scaled by impact. The fold is uniform, so it has no axis and cannot produce the pancake bug. The canon 8% (ROSTER-LOOK.md:67, 70) does not fit the radius ladder: panels scaled by 0.92 land in the ring band at 0.83-0.865 (cage_contract_test.gd:47, 66-67, 414).
- **Pod and pilot:** Unscaled. drop_land clip and a seat dip of up to 6 degrees.
- **Weapon ring and carrier:** Unscaled.
- **Rope:** None.
- **Heft:** The panels slide in 1 cm, to 0.87-0.91, during the clench. The rings and the inner sphere do not move.
- **Camera:** Kick above impact 18 (juice.gd:251-252).

### Carving (Rivet and others)

Status: **works with a fix**

- **Lattice:** Carve spin on gripped steep contact. Correct (ball_rules.gd, tuning.gd:104-109).
- **Pod and pilot:** Level, with no lean. The camera roll carries the carve. Optional sway extra.
- **Weapon ring and carrier:** Carrier bank on banks steep enough to need it.
- **Rope:** None.
- **Heft:** Pod panels. With the yaw clamp the flank never faces the camera.
- **Camera:** Roll from lateral acceleration, up to 0.13 rad.

### Bouncing off bumpers and enemies

Status: **works with a fix**

- **Lattice:** Today a rebound resets the spin instantly. Fix: keep the spin on rebound, or blend it partway toward the new roll.
- **Pod and pilot:** A slower turn on reversal, plus the camera clamp, so the pilot does not whip on every pinball hit.
- **Weapon ring and carrier:** Holds the aim while the pod turns. Good turret read today.
- **Rope:** None.
- **Heft:** Bumpers no longer sink into a 1.365 m drawn ball.
- **Camera:** Shake from impact/30 (chase_camera.gd:250).

### Heft growth from class I to V mid-run

Status: **works with a fix**

- **Lattice:** Fixed radius (Andrew, 22 Oct, "Fixed outline"). Thicker caps from class III.
- **Pod and pilot:** Constant. Today the juice shell grows the pilot to 1.4x (juice.gd:289, 691-692).
- **Weapon ring and carrier:** Constant band. Hub modules swap to their heavy form at V, up to 1.25.
- **Rope:** Unchanged.
- **Heft:** Class up slams the panels in (0.18 s, 1.2 overshoot) and class down flings them out (0.45 s, hero_assets.gd:1049-1122). Both are correct today. The second growth read, the whole-ball inflate, is removed: SHELL_PER_CLASS goes to 0 (ROSTER-LOOK.md:280).
- **Camera:** Unchanged. A class V ball no longer fills more of the view.

### Kest glide (air subset)

Status: **works today**

- **Lattice:** Keeps its spin.
- **Pod and pilot:** VaneL and VaneR open on the pod (hero_assets.gd:613-622). It is not yet checked whether the placeholder box wings (player_ball.gd:1199-1213) also draw beside the hero shell.
- **Weapon ring and carrier:** Aimed.
- **Rope:** None.
- **Heft:** Unchanged.
- **Camera:** Unchanged.

### Low gravity (proposal)

Status: **not in game**

- **Lattice:** Would keep its spin under damping. No rig change needed.
- **Pod and pilot:** Proposal: the gimbal sway extra shows lighter gravity in the seat.
- **Weapon ring and carrier:** Level, aimed.
- **Rope:** Unchanged.
- **Heft:** Unchanged.
- **Camera:** Unchanged. Gravity is one global setting today (tuning.gd:9, rigid_ball.gd:114).

### Rolling upside down on a ceiling (proposal)

Status: **not in game**

- **Lattice:** Not supported: grip stops at a normal y of -0.2 (tuning.gd:105). It would need its own press rule.
- **Pod and pilot:** Would stay gravity-upright, hanging below the contact point.
- **Weapon ring and carrier:** An equatorial ring clears the ceiling, but top modules (Sable's mast, Rivet's stacks) clip. Proposal: those brackets fold down on ceiling contact.
- **Rope:** Unchanged.
- **Heft:** Fine with the shell at 1.0.
- **Camera:** The spring arm would collapse into the ceiling (chase_camera.gd:221, 243). It needs a below-and-looking-up profile. Owner call before building: a world-up camera or a surface-rolled camera.

## Fixes

| Wave | Lane | Fix | Owner call |
|---|---|---|---|
| 19 | Systems | **Take the cockpit out of the juice transform.** Parent HeroPod to a level node under the visual root that takes the juice position offset but not its basis, or counter-scale it. Add a test that the pod's global scale stays 1.0 through a squash and at class V. Must land before the wave 21 playtest. Evidence: player_ball.gd:232-246 (Juice holds the mesh); hero_assets.gd:521, 1036 (the pod is parented to juice_node); juice.gd:283-293 | no |
| 19 | Systems | **Stop the heft inflation (shell size 1.0 on Hoberman shells).** Set juice SHELL_PER_CLASS to 0 for Hoberman shells, as accretion.gd:35 already does. Keep the class-up pulse as the panel slam and the clunk. Re-pin presentation_rows_test.gd:116 and the outgrow check at :153-154. Default: a fixed lattice, with growth shown through panels, caps, heavy modules and chunks. Must land. Evidence: juice.gd:62, 289, 293, 691-692; accretion.gd:27, 35; presentation_rows_test.gd:116; DECISIONS.md:248 vs :250; GROUNDING.md:120, 122 | yes |
| 20 | Animation | **Replace the jelly squash with a lattice-only clench.** Remove the speed and jump stretch. On a landing or slam, scale the Core uniformly down to about 0.97 and spring it back over 0.25 s. The panels slide in to 0.87-0.91 and the rings stay put. The pilot plays drop_land with a seat dip. Change the test constant FOLD from 0.92 to 0.97. The Cannon's 0.85 wind-up fold does not fit the ladder, so its unit decides (veto 14). Removing the whole-rig squash and stretch must land. The clench itself can be cut. Evidence: juice.gd:249-262, 286-288; ball_rules.gd:137-139; ROSTER-LOOK.md:67, 70; cage_contract_test.gd:47-48, 66-67, 412-414 | no |
| 19 | Animation | **Drive the gimbal rings from the carrier's bank, not the lattice's tumble.** Feed counter_tilt the carrier's tilt against the pod: pitch on Gyro X, roll on GyroInner Z, each bounded to about 40 degrees, so the split never nears the lock. The rings sit at rest on flat ground. The optional 6-degree sway can be added. Re-pin cage_contract_test.gd:313-315 to 'still on a flat roll, tilts with the bank'. Update pilot_mask.gd:15, which calls counter_tilt. Must land. Evidence: hero_assets.gd:724-732; cage_contract_test.gd:297-315; ROSTER-LOOK.md:90, 150, 171; pilot_mask.gd:15 | no |
| 20 | Systems | **Bank the carrier off steep faces (a sideways twin of rule 6).** Each frame, smooth the contact normal. Tilt the WeaponRing and the bracket modules, one shared bank, about the axis UP × n (n the smoothed normal) by the smallest angle that keeps their support distance along the normal at 0.99 m or less. Use precomputed hull points per shell and about six bisection steps. Add a headless check of the six shells posed on a vertical and a 30-degree wall, with support no more than 0.99. Should land before the playtest, because the wall rides are a headline read. Evidence: ROSTER-LOOK.md:26, 30, 170, 209; hero_assets.gd:755-762; tuning.gd:105; arithmetic: 1.10 x sin(a) > 1.0 above 65 degrees, and 1.25 x cos(t) <= 1.0 needs a tilt of about 37 degrees | no |
| 19 | Systems | **The rope leaves the collar fairlead, never the centre.** Add a Fairlead carriage on the collar that turns to the anchor's planar direction and holds its last yaw when the anchor is overhead. _draw_cable starts at the fairlead (centre + 1.06 x the flat direction to the anchor, banked with the carrier). The physics stays at the centre, which the free bearing explains. Move RopeExit to the carriage and re-pin world_one_shell_sable_test.gd:267-270. The spool or winch module turns while winching. Must land. Evidence: line_view.gd:142-151, 242-259; augments.gd:722-743; world_one_shell_sable_test.gd:267-270; ROSTER-LOOK.md:45 | no |
| 20 | Systems | **Keep the spin through mid-air velocity sets.** Add a keep-spin mode, used by ride ticks, _fling, _pole_exit and rebounds. On a held ride, decay the spin toward 0. Reset the spin only on grounded hand-offs. Evidence: rigid_ball.gd:79-81, 105-108; player_ball.gd:1081, 1094 | no |
| 20 | Systems | **Couple the cableway ride to the cable.** Offset the held path by a hanging distance below the cable. Draw a hanger line from the collar fairlead to a trolley clamp on the cable, reusing the rope ribbon. Systems measures the clearance under the cables first. If the ride tests break, defer to post-alpha and accept the current read. Evidence: ride_rail.gd:75-91; contraptions.gd:264-271, 767-779 (lens cite, not re-read); DECISIONS.md:250 | no |
| 20 | Animation | **Pod yaw rules: clamp to the camera, face the anchor, slow the reversals.** Keep the pod's yaw within 45 degrees of the camera yaw. Face the anchor while hooked. Use a slower turn rate after a reversal. Add a --yaw option to pilot_mask and run it at 0, 30 and 45 degrees at class V. Evidence: hero_assets.gd:600-604; chase_camera.gd:113-127, 242; pilot_mask.gd:9-11 | no |
| 20 | Effects | **Wagon-wheel strobe treatment.** Add a chalk balance mark on one tread cap and varied tread rotation per cap. Add a speed blur over the strut layer from the fast tier up. The Perf lane checks the cost on the 4080. Evidence: ROSTER-LOOK.md:211; contact.gd:49 (60 m/s soft cap, lens cite); arithmetic of 1 rad per 60 Hz frame at 60 m/s | no |
| 20 | Modeling | **Inner cockpit sphere: place it in the ladder or cut it.** Default: build a thin, nearly clear sphere at about 0.815, inside the gimbal rings, with no rim specular and no decal. It goes in only after PE-RIVET, PE-SABLE and PE-KEST re-key the clips to 0.80 m or less. Gate it on pilot_mask with --seed-sphere as an opaque worst case, and cut it if rule 1 fails. Then the rings and the seat read as the cockpit. Evidence: ROSTER-LOOK.md:106, 304; cage_contract_test.gd:60-69; GROUNDING.md:128; DECISIONS.md:250 | yes |
| 20 | Modeling | **Record the radius ladder and pin it.** Write one ladder into ROSTER-LOOK and cage_contract_test: pilot up to 0.80, sphere 0.815, rings 0.83-0.865, panels 0.88-0.92 (folded 0.87-0.91), lattice 0.94-0.975, caps 0.985, collider 1.0, collar and band 1.02-1.10, modules up to 1.25 in the carrier frame, with nothing past 1.0 below carrier Z -0.6. Evidence: cage_contract_test.gd:41-48, 66-69, 406-414; ROSTER-LOOK.md:23, 26, 171, 174, 209 | no |
| 20 | Effects | **Dunk charge on the level carrier, in class colour.** Show the stored charge on the collar's rear arc, or on the seat-back DecalPlate, in class colour, from one record shared with the sound. This goes inside the dunk card. Evidence: GROUNDING.md:113, 115; DECISIONS.md:248; ROSTER-LOOK.md:176 | no |
| 19 | Systems | **Motion capture tooling for real frames.** Extend look_harness and look_subjects with --frames=N consecutive frames at a fixed fps, plus pose overrides: speed, pod yaw, a contact normal on a park wall, a hooked anchor, and a squash tick. Evidence: look_harness.gd:6-35; look_subjects.gd:33, 276-296; the visual lens's tool-gap list | no |
| 19 | Effects | **Check that the placeholder glide wings hide on hero shells.** Hide the box wings when the shell carries VaneL and VaneR. Verify first with a still. Evidence: player_ball.gd:1199-1213, 1245-1255 (lens cite); hero_assets.gd:613-622 | no |
| post-alpha | Systems | **Ceiling rolls and low gravity stay as proposals.** Draw them only as labelled proposals. Before building, decide the camera (world-up camera looking up from below, or a surface-rolled camera), add a top-bracket fold, and give the ceiling its own press rule. Evidence: tuning.gd:9, 105; chase_camera.gd:221, 243; ROSTER-LOOK.md:420, 434 (lens cite) | yes |

## Board corrections

- pilots-balls-heft-moodboard: the class V ball is drawn bigger, with 'EXPANDING HUSK / SCALE PROPOSAL' and the scissors 'OPEN TO GROW'. Andrew ruled the outline fixed on 22 Oct, so this panel is do-not-copy. Growth shows through panels, thicker caps, heavy modules and chunks. Label the scale panel as a proposal, not to copy.
- pilots-balls-heft-moodboard, pilots-reference-cannon-heft-study and pilots-reference-sable-salvage-cockpit: panels are drawn on the outside of the lattice. Canon puts them on the pod at 0.88-0.92, inside the lattice, with the struts rolling past in front (ROSTER-LOOK.md:59, 269).
- Sable salvage, Tally and Cannon boards: the weapon band looks bolted to the struts. It floats on its collar across a visible air gap (the field bearing). Nothing solid joins the band to the lattice.
- Rope exits: the boards place them at a side winch, at 1-2 o'clock with a hanging hook (forbidden by ROSTER-LOOK.md:107), at 4-5 o'clock pointing down, at 9 o'clock with slack rope, and at 3 o'clock. The spec has one rule: the rope leaves a fairlead on the collar, on the anchor's side. The winch drum is a module that turns while reeling.
- pilots-hardware-grapple-reel-dunk-moodboard, STORE panel: the mint latch window sits on the lattice face. Move it to the collar's rear arc or the seat-back plate, in class colour (DECISIONS.md:248 d).
- Six Slams panel, and Rivet's 'FORWARD SKID (MOVE)': slam hardware hangs under the contact point. A fixed part cannot ride the bottom of a rolling ball, and rule 6 bans reach past 1.0 below Z -0.6. Show the slam as an effect at the contact point, with its hardware on the level carrier. Each pilot uses its own telegraph colour (PILOTS.md:68), not mint on all six.
- Kest board: the mortar tubes point up and out at 10 and 2 o'clock. Sable's style and shape boards point the emitters sideways at 3 and 9. On a ring that turns to the aim, every muzzle points forward (ROSTER-LOOK.md:89).
- Cannon heft study: the barrel reaches about one ball diameter past the lattice. Cap it at the 1.25 module reach, or it cuts into kicker faces.
- pilots-cockpits-roster-moodboard: the inner sphere fills the lattice almost to the struts, and no gimbal rings show. In the spec the sphere, if Andrew keeps it, is a thin shell at about 0.815, inside the visible gimbal rings. The Tarn and Rivet cockpit insets are the correct read. style-setpiece-reel-dunk-reference shows no sphere. Align both to the ruling.
- Gimbal rings on the boards: draw them at rest, or tilted by the carrier bank on walls. Never draw them as spinning hoops in a straight roll.
- style-telegraphs-moodboard (the rejected ring cage), style-landmark-spillway-dawn-reference (single plain bars, a sideways gun) and style-shape-moodboard's LATTICE panel (a geodesic of plain bars): add 'don't copy the ball' lines to style/README.md (ROSTER-LOOK.md:83).
- No board shows the ball on a rail or cable, the wall-ride bank, the swing rope from a level part, or the chase-eye motion reads. The movement board set covers these. Until then, the boards cannot stand in for motion, because they settle only look (pilots/README.md:3, DECISIONS.md:246 item 5).

## Render requests

- Inflation baseline, on the 3060 (card 1, via tools/coordinator/gpu_queue.sh --gpu 1 --need 3000 --display --shared): godot --rendering-driver vulkan --display-driver x11 --gpu-index $SCRAPKEEP_GPU_INDEX --path sketches/core-loop --resolution 1920x1080 --script res://tools/look_harness.gd -- --subject=cge_sable_rule_c1,cge_sable_rule_c5,cge_rivet_rule_c1,cge_rivet_rule_c5,cge_kest_rule_c1,cge_kest_rule_c5,cge_tarn_rule_c1,cge_tarn_rule_c5,cge_tally_rule_c1,cge_tally_rule_c5,cge_cannon_rule_c1,cge_cannon_rule_c5 --out=<abs>/artifacts/local/ballread/cge. Compare the ball screen box in frames.json for c1 against c5. A ratio near 1.4 confirms the juice inflation in frames. A ratio near 1.0 means the harness does not run juice, and the inflation is then untested in stills. Re-render after the shell fix.
- Rule 1 numbers, headless on the CPU, all six pilots at classes 1, 3 and 5: godot --headless --path sketches/core-loop --script res://tools/pilot_mask.gd -- --out=<abs>/artifacts/local/ballread/mask-<pilot>-c<N>.json --pilot=<class id> --class=<N> --samples=16. Add --seed-sphere=0.815 for the inner-sphere worst case. Run again after the gimbal fix: with the rings still, the head share should rise.
- Same-tick pair for the ring and pivot fixes: look_harness --subject=cge_<pilot>_rule_c3 for all six, with --pair --base=<pre-fix sha7>, so a blind A/B shows the still rings and the fairlead. Cut 96 px greyscale thumbnails for rule 10.
- Kicker and air: the existing kicker row in look_subjects.gd:144-145 (visual lens cite), mid eye, before and after removing the jump stretch.
- Wall and ride stills from real play: first find seeds that use ride lines, with godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/traversal_line.gd -- --pilot=sable --seeds=1,2,3,4,5,6,7,8 --trace --out=<abs dir>. Then run claude-open <godot> --path sketches/core-loop --script res://tools/alpha_capture.gd -- --out=<abs dir> --seed=<seed> --seconds=150 off Andrew's screen, and read the 9 s periodic stills for wall rides, cable rides and swings.
- Glide wings check: xvfb-run godot --rendering-driver opengl3 --path sketches/core-loop -s tools/player_fx_capture.gd -- --out=<abs dir> --pilot=2 (Kest), looking for box wings drawn beside the vanes.
- Bounce and impact: stress_capture.gd scene S1 (Rivet, one pack) for the bounce squash and pod whip, before and after the pod fix.
- Blocked until the motion-capture tooling lands (fixes list, wave 19): 60-frame strips at 14, 30 and 60 m/s at --fixed-fps 60 for the strobe and chalk mark; the sinkhole glazed band (park_sinkhole.json:122, lens cite) with the ball gripping at 30 m/s, for the ring bank and clipping; a swing on map_highdraft grapple_line or sinkhole tube_rope_1, for the rope origin and the pod facing the anchor; slam peak frames at +1, +3 and +8 ticks, for the pilot's height; class III to IV transition frames, for the panel slam; and a pod yawed 45 degrees off the eye at class V.

## Movement board brief

Purpose: one chase-first movement reference set that shows how the pilot ball moves in every traversal situation. It draws only motion the motion spec supports, so Animation, Systems and Effects units build one machine (DECISIONS.md:243, 246). It is generated against the eight style boards and the redrawn pilot boards, and it settles look only. All numbers come from the spec.

Format: follow the ROSTER-LOOK §0.7 rules for the chase view: landscape 3:2, directly behind the ball, 17 degrees down, the ball about one fifth of the frame height, plain pale sandstone ground. Each panel also gets a small side-view diagram beside the chase view. Every panel carries one status chip: TODAY (works now), WITH FIX (needs a fix from the spec, named on the chip) or PROPOSAL (not in the game). Andrew's pilot for every panel: Sable at heft III, plus one Cannon panel for the heavy end.

Panels:
1. The radius ladder and what moves. A cutaway, labelled from the inside out: pilot, optional inner sphere marked PROPOSAL, gimbal rings, pod panels, lattice, tread caps, collider, collar and band, modules. Three motion arrows: the lattice tumbles, the pod stays level and turns to the heading, the carrier turns to the aim. The field gap is drawn as the bearing.
2. Rolling: rest, cruise and 30 m/s. The struts blur, the chalk balance mark stays readable, the gimbal rings are still and the pilot is upright (WITH FIX: still rings, strobe treatment).
3. Wall ride on the sinkhole band. The pilot is level, the lattice spins like a globe about the wall, and the carrier banks about 38 degrees off the wall so the band never touches it (WITH FIX: carrier bank). Include a halfpipe apex inset: the pod holds its yaw.
4. Cableway ride. The ball hangs below the cable on a short hanger from the collar fairlead to a trolley, and the spin decays (WITH FIX: cable coupling, keep spin).
5. Kicker launch and air. The wheel keeps spinning, nothing stretches, and the seat sways 6 degrees as an extra (WITH FIX: no stretch).
6. Swing and fling. The rope leaves the collar fairlead on the anchor's side and stays outside the lattice. The pod faces the anchor through the apex. On release the spin carries on (WITH FIX: fairlead, anchor facing, keep spin).
7. Reel and haul into a riveted hatch. The line is taut from the fairlead, the winch drum turns, and the pilot's back faces the camera (WITH FIX: fairlead).
8. Air slam and landing. The lattice clenches by about 3%, the pilot plays drop_land, the seat dips, and the ring and pilot stay full size. The stored charge glows in class colour on the collar's rear arc (WITH FIX: clench, dunk display).
9. Heft growth in motion, I to III to V. Panels slam into the pod gaps with overshoot, caps thicken, and modules take their heavy form at V. The outline barely grows. No opened-husk frame: Andrew ruled the outline fixed on 22 Oct.
10. Bounce chain on bumpers. The ring holds the aim while the pod turns no more than 45 degrees off the camera (WITH FIX: yaw clamp).
11. PROPOSAL: low gravity. Long air time, and the seat sways more.
12. PROPOSAL: ceiling roll. The pilot hangs upright, the top brackets fold, and the camera sits below the ball looking up. Labelled 'owner call: camera'.

Forbidden in every panel: scaling or squashing the whole ball or the pilot; a lattice bigger than the collider, outside panel 9's pending frame; rope or cable through the ball's centre; hardware under the contact point; gimbal rings spinning in a straight roll; panels outside the lattice; muzzles pointing anywhere but forward; mint on anything except Sable's own devices; the ring cage or a lattice of plain bars; hanging hooks or chains.

Acceptance: the reviewer checks each panel against the motion spec row it names. A panel that draws unsupported motion without a PROPOSAL chip is a FAIL with an ART-MISTAKES line.

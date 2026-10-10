# Roster look: six pilots in Hoberman mechas

> **2026-10-10 evening:** Andrew rejected the open-cage boards. §0 below is the live direction and supersedes the cage anatomy, placement and board matrix further down.

Wave 13, unit A3. This sheet sets one visual language for the six pilot balls. Andrew chose the open gyro cage on 2026-10-10 (session plan, "Decisions settled today", row "Sphere body"). The heft accretion stages come from the plan's creative-charge list ("The cage gains body with heft") and stay on the veto list at the end. Every number here is a starting value to tune in play unless it cites code.

The board spec is `artifacts/local/alpha/push/w13/concepts/boards/pilots-cage.json`: 38 subjects, six per pilot and eight for the Cannon. Wave P-D builds from the boards Andrew approves.

**What this sheet replaces.** For the alpha sketch it replaces the class-shell rows and the "growth and cockpit rules" in `VISUAL-LANGUAGE.md` §9 (lines 378 to 416), and the "reuse the 0.98 m glass sphere" rule in the wave 1 D6 build spec (`game-completion-plan-75f776/artifacts/local/alpha/push/w1/D6/out/BUILD-SPEC.md:8`). Bible AD-01 (`BIBLE.md:620`) asks for "a protected, readable cockpit and recognizable equipment". The cage meets that better than glass did: the rings are a roll cage, and the equipment sits outside where it shows. Moving the cage into the Bible needs a heavy-lane card (`VISUAL-LANGUAGE.md:3`).

## 0. Direction change, 2026-10-10 evening: the Hoberman mecha

Andrew rejected all 38 open-cage pictures on 2026-10-10. His direction, in his words: "more like a Hoberman sphere that's like completely expanded out", with "panels or other things that kind of like tack on to that sphere within like maybe those different nodes or gaps", "gyroscopic stabilization for certain aspects of the ball", a weapon as "a stabilized horizontal ring that also wraps around" the sphere, and a cockpit with controls the pilot works "in sort of a mecha like manner": "a mecha that kind of like is an extension of that character", like Power Rangers.

**This section supersedes** the cage anatomy (§2), the per-pilot machinery placement (§4), the board matrix and pick rule (§4), and the cage half of §5. The camera numbers (§1), silhouette rules (§3), colour slots (§6), the plate-per-class layering and budgets (§5), cosmetics (§7) and performance (§8) still hold, with "ring" read as "lattice" and "plate" read as "gap panel". The board spec for this direction is `concepts/boards/hoberman-probe.json`, a 16-picture probe; the full board follows from the probe.

### 0.1 Anatomy: four layers, split by how each one moves

The code already has three motion layers (`hero_assets.gd:401-480`). The weapon ring is the one new node.

| Part | Node | Moves | Starting size (metres, origin at ball centre) | What it does in play |
| --- | --- | --- | --- | --- |
| **Lattice** | Core | Tumbles with the true ball spin | A fully expanded Hoberman sphere at outer radius 0.975, inside the 0.985 core limit (`shell_base.py:15`). Scissor-strut pairs 0.035 m thick, crossing at **pivot hubs**. Start from an icosahedral layout: 30 great-circle scissor chains meeting at 12 five-way hubs and 20 three-way hubs, which leaves large open triangular and pentagonal **gaps**. Rubber tread caps on the outer face of each hub. | The ball the eye believes. Its spin shows true roll. The open gaps keep the pilot visible (§3 rule 1). |
| **Hubs** | Core > Hub.00 to Hub.31 | With the lattice | 32 named empties at the hub centres, facing outward | Mount points. Per-pilot modules and heft chunks clamp here. |
| **Gaps** | Core > Gap.00 to Gap.NN | With the lattice | Named empties at each gap centre, facing outward | Panel slots. Heft plates and cosmetic panels fill gaps (§0.3). |
| **Weapon ring** | Pod > WeaponRing | Stays level (gyro-stabilised); yaws to the **aim** direction, not the heading | A flat horizontal ring just outside the lattice at the equator: radius 1.02 to 1.10, 0.08 m tall, on its own bearing collar | Carries the pilot's weapon. The weapon always points where the shot goes, so aim reads from the ball itself. |
| **Cockpit pod** | Pod | Upright, turns to the heading | A compact gimballed pod at the centre, on a two-axis gimbal (today's Gyro hoop becomes the gimbal's outer ring). Seat, foot pedals and per-pilot **controls** | The pilot sits and works the controls. Each control moves when its skill fires (§0.4). |
| **Pilot** | Pod > Dome > AnimatedPilot | With the pod; plays clips | Unchanged: `fit_pilot_into` (`hero_assets.gd:516-529`) | |

**Collider:** unchanged, a sphere of radius 1.0. The weapon ring overhangs to 1.10 for looks only; it never collides.

**The mechanical story.** The lattice is the rolling wheel. The pod hangs on a gimbal and stays upright like a gyroscope. The weapon ring rides a level bearing and swings to the target, the way a tank turret stays on target while the hull rocks. Every machine is the pilot's own build, an extension of who they are: the Power Rangers zord read.

### 0.2 Each pilot's zord

| Pilot | Lattice enamel | Weapon ring carries | Hub modules (clamped at nodes) | Gap panels | Cockpit controls the pilot works |
| --- | --- | --- | --- | --- | --- |
| Sable (fox engineer) | Petrol teal | A twin arc emitter wound in copper coil, mint glow at the coil tips | Pylon spike emitters on three or four upper hubs; the grapple winch on one side hub | Small rounded felt-lined plates | Twin yokes; a gauge lever for the detonation charge |
| Rivet (mole machinist) | Charcoal steel | Twin rapid laser barrels in copper housings | A stepped drill-nose module filling the front gap; twin exhaust stacks on rear hubs | Raked chevron plates | Twin throttle levers; a sprint pedal |
| Kest (bird demolitions) | Petrol teal | Short charge-launcher tubes and banded satchels | Slotted fin vanes that fold out of the side gaps like wings for the glide and blink | Light perforated panels | A single flight stick on a perch; a fuse plunger |
| Tarn (tiger) | Iron oxide red | Two big curved claw blades | Two hooked claw arms on the side hubs for the claw pull; a pull drum low at the rear | Thick slabs scored with claw marks | Twin yokes with grip triggers; a clamp lever |
| Tally (pack rat) | Mulberry | A drum magazine that deals flat metal cards | Ledger drums on the 3 and 9 o'clock hubs, echoing the ears; a stamp sole hub at the bottom | Square stamped plates with punched holes | A lever panel with three tabbed card slots, one per card |
| The Cannon (ancient tortoise robot) | Dull petrol, with salvaged verdigris cast carapace plates tiling some gaps | One big seamless cast cannon barrel | Split ports on the low side hubs; a rush ring on the bottom hub | Seamless verdigris carapace plates, the showcase | Two paddle levers |

Node names that kit code already uses (`RopeExit`, `VaneL/R`, `ClawPivot.R/L`, `ClawTip.R/L`, `PullDrum`, `Flywheel.R/L`, `ReaderCarriage`, `CardBay.0/1/2`, `MainBarrel`, `LaneMuzzle`, `SplitExit.R/L`, `RushContact`) keep their names and move to the new parent: weapon parts under WeaponRing, movement parts on hubs.

### 0.3 Heft: panels fill the gaps

Heft classes stay as §5 sets them. What changes is where the armour goes:

| Class | Adds |
| --- | --- |
| I | Bare lattice, weapon ring and pod. Every gap open. |
| II | Panels in the lower gaps, below the pod |
| III | Panels in the side gaps, and thicker tread caps on the hubs |
| IV | Panels in most gaps; only the gaps on the camera's sight cone to the pilot stay open (§3 rule 1) |
| V | Every non-sight gap paneled, and the hub modules grow to their heavy form |

Accretion chunks snap to the nearest hub (§5's "snap to a ring" call becomes "snap to a hub"). Class up slams panels into their gaps; class down flings them out of their gaps, with the same timings as §5.

### 0.4 Cockpit controls drive the clips

The plan's skill bar (`design-v3/SKILL-BAR.md`) has a weapon, three skills on keys 1 to 3 and an ultimate. Each one gets a control in the cockpit, and the pilot works it when the skill fires: a yoke trigger squeeze for fire, a lever throw for a skill, both hands on the big control for the ultimate. These are the new cockpit clips for the clip spec, on top of the seven reaction clips. The control and the clip read the same skill event, so the hands always match the bar.

### 0.5 Separable extras (on the veto list)

- **The fold is the squash.** A Hoberman sphere really folds. On a hard landing or a ground smash, the lattice contracts about 8% and springs back out over 0.25 s. The squash and stretch comes from the mechanism instead of a scale cheat. The collider does not change.
- **Full span for the ultimate.** The ultimate opens the lattice past its rest size, to about 1.15 times, and the hub modules lock out, the zord's "megazord" moment, then folds back. The collider grows only if the ultimate's design says so.
- **Panels as armour you can see.** A heavy hit knocks one gap panel loose; it flings and is not freed (§5 rule).

### 0.6 Recipe route

The lattice is procedural, which suits a Blender recipe better than a picture: one function places the 32 hubs on an icosahedral layout, threads scissor-strut pairs along the great circles between them, and emits the Hub and Gap empties. `shell_base.truss_cage()` (`shell_base.py:74-85`) is the starting point. FLUX boards set each pilot's modules, colours and cockpit; the lattice itself comes from code. Unit CAGE-BASE in §9 becomes HOBERMAN-BASE with the same budgets.


### 0.7 Concept set rules (2026-10-10 audit of the Astra pictures)

An audit of the 20 Astra concept pictures set one rule per aspect so the six mechas read as one roster. The cleanup round edits the pictures to these rules, and the Blender recipes follow the same rules. Pictures live in `artifacts/local/alpha/push/w13/concepts/codex/`.

| Aspect | Rule | Best example |
| --- | --- | --- |
| Lattice construction | Build the rolling body as a fully expanded Hoberman sphere: two flat bars of equal length crossing in an X at one copper pivot pin, chained end to end along great circles, every chain ending in a hub. No single-bar triangles, no geodesic dome, no buckyball of plain bars, no chain-link segments. | base/base-hero.png |
| Lattice density | Keep it at the base density: about five X-pairs between neighbouring hubs, so the gaps stay large, open triangles and diamonds about as wide as the pilot's head. Never pack the lattice so tightly that it reads as a mesh. | base/base-hero.png |
| Hub style and tread caps | Every hub is a round copper hub body with a flat black rubber tread cap on its outer face, carrying a shallow tyre-tread pattern. No square bone blocks, no domed grid caps, no bone ball joints, no petrol hub bodies. | base/mechanism.png panel A (tread cap exploded off a copper hub) |
| Lattice enamel | Paint every strut in the one enamel ROSTER-LOOK 0.2 gives this pilot. Copper is used only on pivot pins and hubs. Do not mix bone or charcoal struts into the lattice. | tally/hero.png (every strut mulberry) |
| Weapon ring height and clearance | Put one flat horizontal band exactly at the sphere's equator. It sits fully outside the lattice with a visible air gap all round, and stays level while the lattice tilts. Its diameter is about 1.1 times the sphere's. | base/base-hero.png |
| Weapon ring band and bearing collar | Make the band worn-bone segments joined by charcoal clamp blocks. Directly under the band, show a full-diameter dark-steel bearing collar of the same radius, with copper bearing studs. The pilot's colour goes on the weapon housings only, not the band. | tally/sheet.png weapon ring and collar panel |
| Weapon placement and aim | Mount the weapon on the front arc of the ring at 12 o'clock. Twin weapons sit at about 11 and 1 o'clock, parallel. Every muzzle, emitter tip, blade edge or card slot points forward, along the pilot's facing. Never point a weapon sideways, backward, or tip to tip. | kest/sheet.png FRONT panel (both launcher mouths face the viewer) |
| Cockpit gimbal | Hang the seat inside two nested thin dark-steel rings. The outer ring pivots left-right, the inner ring pivots front-back, and copper pivot bosses show at each axis. Both rings are visible through the front gap in every hero view. No pedestal post, no single hoop. | base/mechanism.png panel C |
| Cockpit controls | Twin yokes take the hands, and a small lever or button bank sits beside the right yoke for slots 2 and 3. The ultimate is the largest control, a two-handed bar across the lap in copper. The Shift movement verb is on the pedals. Draw exactly two pedals. | tarn/sheet.png cockpit cutaway (lap bar ultimate, clamp lever, two pedals) |
| Pilot scale and visibility | The seated pilot, from ears or crest to boots, is about half the sphere's height, sitting centred at the equator (ROSTER-LOOK.md:132 gives 139 px of pilot in a 252 px ball). Leave the face fully clear through the front gap in a hero view. Leave the head and ears clear through a rear gap in a chase view. | sable/hero.png (largest pilot in the set, face unobstructed; still under half) |
| Pilot on model | Copy the pilot exactly from refs/pilots-lineup.png and the per-pilot sheet: same species read, outfit colours, cap, goggles, bandana, shell and proportions. The seat directly behind the head contrasts with the fur in value: bone for Tarn, Rivet and Sable, petrol for Tally and Kest, charcoal for the Cannon (ROSTER-LOOK.md:252-258). | tally/hero.png |
| Material and weathering | Use battered, workshop-built, chunky stylized 3D. Wear the enamel through to bare steel along edges and around pivot pins, put dark grease at hubs and a light dust on top faces, and keep the flat faces mostly intact. No uniform speckle over every surface (BIBLE.md:645, :705). | tarn/hero.png |
| Copper, never brass | Every warm metal is pinkish-orange copper #b77843 with brown patina. No yellow brass #d9b44a anywhere on a player machine. | base/base-hero.png |
| Hero lighting and background | Use a seamless plain warm-grey studio background and floor, with a soft warm key from the upper left, a soft contact shadow under the ball, and no scenery or props. | base/base-hero.png |
| Hero camera | Square frame. Three-quarter front view, about 30 degrees off the nose and about 20 degrees above the ring plane, so the ring shows as an open ellipse. The ball is centred and fills about 85% of the frame height. | rivet/hero.png |
| Hero heft stage | Draw every hero at heft III: the lower and side gaps paneled in the pilot's gap-panel style, the upper and front gaps open, and the hub modules at normal size. (Calls this as one stage for all six so the heroes line up.) | sable/hero.png |
| Chase camera | Landscape 3:2. Directly behind the ball, looking 17 degrees down (ROSTER-LOOK.md:125). The ball fills about one fifth of the frame height (about 205 of 1024 px), sits centred horizontally and just below the middle, and rolls straight away from the camera. The pilot's back, head and ears show through the rear gaps. | tarn/chase.png (straight behind and the closest to size, at 32%) |
| Chase ground | Plain, fine, pale sandstone ground with gentle grain and no pebble field. No horizon objects and no motion-blur streaks. A soft shadow falls to the lower left, with one small dust puff at the contact point. | sable/chase.png |
| Callout sheet layout | Use three rows on 1536x1024. Top row: orthographic FRONT, orthographic SIDE (nose right), then the COCKPIT cutaway, largest, at the right. Middle row: WEAPON RING over BEARING COLLAR, HUB MODULE exploded, GAP PANEL exploded. Bottom row: heft I, III and V front views, all at the same scale. | rivet/sheet.png |
| Label typography and leaders | Panel titles in bold condensed sans, all caps. Callouts in the same sans, sentence case, charcoal, with no boxes. Each leader is a thin straight charcoal line ending in a dot placed on the named part. Every digit and word is spelled exactly. | tarn/sheet.png |
| Control label names | Label five controls, with names exactly as in design-v3/PILOTS.md section 1: '1: <weapon>', '2: <slot 2>', '3: <slot 3>', 'Q: <ultimate>' and 'Shift: <movement>' on the pedals. The weapon is slot 1 (SKILL-BAR.md:35), so never draw a separate 'Weapon trigger' label next to slot 1. | rivet/sheet.png (only sheet that puts the Shift verb, Overdrive Sprint, on the pedal) |
| Heft row | I: every gap open. III: lower and side gaps paneled. V: every gap paneled except the sight gaps that run front and rear to the pilot's head. The same hub modules and weapon appear in all three stages; only their size grows at V. | tarn/sheet.png bottom row |
| Colour discipline and glow | Emissive light appears only at the working device, in the class colour: Sable mint #8bf0d3, Rivet copper #b77843, Kest amber #e5a044, Tarn oxide #9b513a, Tally ledger cream #e6d9b8, and the Cannon ancient green #9dff3c as dashed seams (class_def.gd:13-18). No marker lamps or other lit boxes elsewhere. | tally/hero.png (the card slot is the only light) |
| Forbidden | No glass bubble or dome, no hamster ball, no hanging hooks or chains, no logos or watermarks, and no text outside callout sheets. | all 20 pass |

**Read at game size.** I made downscaled copies with each ball at 150 px and 250 px tall, plus a 150 px greyscale row for ROSTER-LOOK.md:153: /tmp/claude-1000/hob-audit/strip-150.png and grid-250.png. In every picture the X-scissor crossings, pivot pins, rivets and chipped speckle merge into one busy texture. Only the hub caps survive, as dark dots on the outline. AD-04 (BIBLE.md:645) therefore argues for base-hero density, wider struts and fewer crossings. Per pilot:
- Sable: the russet head, pointed ears and petrol cap survive, the strongest 'who' read in colour. So do the crown of pylon spike points and the winch drum at 3. The wrench rack becomes a grey grille. The mint emitter tips shrink to 1 to 2 px specks. In greyscale the head loses its colour pop, though the ear shape holds.
- Rivet: the twin copper stacks survive, the clearest outline break. So do the white smock between the yokes and the barrel end caps at 3 and 9. The chevron fins merge into the lattice. From behind, the goggle strap makes the earless grey head read as a helmeted figure. The mixed bone and charcoal struts read as clutter.
- Kest: the white round head with its crest survives, as do the slotted fin vanes at 2 and 10 (the V silhouette holds) and the amber-striped ring band. Lost: the triangulated lattice, the launcher tubes and the perforated panels. The head is among the smallest in the set at about 25 px.
- Tarn: the claw blades and the hooked claw arms survive; they make the boldest, bottom-heavy outline in the set. The rear pull drum survives too. The head is lost: ash-brown fur against a dark seat and an oxide lattice has almost no value contrast, and the stripes vanish.
- Tally: the big round ears survive, the best 'who' read in greyscale. So do the ledger drums at 3 and 9 as bright discs, so 'four circles on a square' holds. The dark mulberry lattice is busy, and the card magazine shrinks to a stub.
- The Cannon: the long bone barrel survives as the outline break, along with the split ports low at 5 and 7. The pilot is lost: the teal shell blends into the petrol lattice and the verdigris plates. The rear breech hub reads as a false face, the bulbous hub caps make the outline lumpy, and the green dashed seams become specks.
Across the set: at 250 px, about the mid-camera size, heads measure roughly 25 to 45 px (eyeball estimate), so only Tally clears the 45 px rule (ROSTER-LOOK.md:145). Scaling the pilot to half the ball's height is the single biggest fix.

**Lineup.** A six-mecha lineup reads as one roster only if these stay the same for every machine:
- Build: the lattice from one base mesh (base-hero construction and density), the same flat copper tread-cap hubs, and the ring at the equator in the same bone band over a full-diameter collar.
- Scale: one ball diameter, so all six balls are the same pixel size, with the pilot at about half the ball's height.
- State: the same heft stage (III).
- Camera: one camera height and yaw (three-quarter front, about 20 degrees above the ring plane, so every ring ellipse opens the same amount), one ground line and contact shadow, one light direction, and one plain warm-grey background.
- Weapons: each mounted on the front arc and pointing the same way.
- Gimbal and glow: the nested gimbal visible through every front gap, and glow only at each device.
- Order and spacing: left to right as in refs/pilots-lineup.png (Sable, Rivet, Kest, Tarn, Tally, the Cannon), evenly spaced.

Only these may vary: lattice enamel, hub modules, gap-panel style, weapon, class glow colour and pilot.

Two cautions:
- Sable, Kest and the Cannon all get petrol enamel under ROSTER-LOOK 0.2, so lattice colour cannot carry identity for those three. The head shape and the outline break must carry it.
- Six separate generations will drift again. Compose the lineup from six renders of the procedural base (ROSTER-LOOK 0.6), or pass base/base-hero.png and each corrected hero as references in a single generation.

## 1. The problem with today's sphere

Every pilot today rolls in the same clear bubble. `shell_base.spherical()` builds it (`tools/blender/shell_base.py:172-241`):

- **A clear glass hull.** A 40 by 24 UV sphere of radius 0.98 m on the `glass` slot (`shell_base.py:175-179`). The glass shader sets alpha to 0.05 face-on, rising to 0.27 at the rim (`src/presentation/hero_assets.gd:188`). On screen it reads as a pale ring around empty space.
- **Shrunken machinery.** The class kit is scaled to 0.67 and pushed 0.28 m down, "below shoulder height, inside the ball" (`shell_base.py:181-185`). The machinery that should say "this is Rivet" sits small and low behind the glass rim.
- **One shared base.** Every pilot gets the same petrol band at Z -0.29 (`shell_base.py:186-193`), the same rubber puck and three mint intake rings (`:194-196`), the same seat (`:197-203`) and the same gyro hoop (`:228-233`).
- **A decal on glass.** Cosmetic decals print onto the Core's glass or paint at local z 0.35 and up (`src/presentation/cosmetic_presentation.gd:89-112`).

**What the player sees.** The chase camera sits 7.5 m back at rest and 10.5 m at speed (`src/movement/chase_camera.gd:213`). At 7.5 m and a 65 degree lens, the 2 m ball is about 252 px tall at 1080p and the pilot's head is about 51 px. At 10.5 m and 80 degrees the ball is 147 px and the head 29 px. The pilot is the only shape with character. The glass rim and the shared band are the same for all six. That is the Super Monkey Ball read: a creature in a clear ball.

The tests pin the glass too. `tests/hero_assets_test.gd:190-198` requires a radius 0.98 glass hull of more than 500 vertices, so wave P-D re-pins it (section 9).

## 2. Cage anatomy

The ball splits into three layers by how each one moves. Code already has this split. Core rolls under the ball's rolling mesh (`hero_assets.gd:401`). Pod rides the juice node, stays upright and turns to face the heading (`hero_assets.gd:402, 468-476`). Gyro sits under Pod and spins with speed (`hero_assets.gd:477-480`). The cage keeps those node names, so the loader and the tests keep their hooks.

```
 side view, heading to the right            what moves how
                                            
        .--- tread ring (Core) ---.          Core   tumbles with the true ball spin
      /   ,-- gyro hoop (Gyro) -,   \        Gyro   spins about the side axis with speed
     |   /    [pilot head]       \   |       Pod    upright, turns to the heading
     |  |  hub=O===yoke===O=hub   |  |              (yoke, cradle, seat, machinery,
     |  |      \  seat  /         |  |               intake coil, pilot)
     |   \      \bowl__/  [kit]  /   |
      \   '--  (((coil)))  ----'    /    collider: sphere, radius 1.0, never changes
        '------- ground ---------'
```

| Part | Node | Moves | Size (starting values, Blender metres, origin at ball centre) |
| --- | --- | --- | --- |
| Tread rings | Core | Tumble with the ball's real rotation. They are the "ball" the eye believes. | Two or three great-circle hoops (the board picks the count). Outer radius 0.975, inside the 0.985 core limit (`shell_base.py:15`). Band 0.10 m wide, 0.06 m deep. Rubber tread pads 0.14 m long, about every 60 degrees with plus or minus 15 degrees of jitter. |
| Ring struts | Core | With the rings | Gussets at ring crossings, tubes of 0.04 m or less. The lattice idea starts from `truss_cage()` (`shell_base.py:74-85`). |
| Gyro hoop | Pod > Gyro | Spins about the side axis at speed divided by 0.98 (`hero_assets.gd:480`) | Moves inside the rings: radius 0.84 to 0.88 (today 0.938 to 0.965 at `shell_base.py:229-230`, which would cross the tread rings). Two axle hubs at plus and minus 0.86 on X, 0.13 m across. Today's class-accent pips at `shell_base.py:231-232` become the hub caps. |
| Yoke | Pod | Upright | Two bare-metal arms, 0.05 m square, from the hubs down to the cradle |
| Cradle and seat | Pod | Upright | Seat at Z -0.30 (`BUILD-SPEC.md` neutral body). The seat back stops at Z -0.10, below the shoulder roots at Z -0.06, so the head and shoulders show from behind. The bowl bottoms out near Z -0.62. |
| Controls | Pod | Upright | Grips at (plus or minus 0.32, 0.40, 0.05) on yoke levers, as today (`shell_base.py:201-203`) |
| Intake coil | Pod | Upright | Today's three mint field rings under the seat (`shell_base.py:195-196`). This is the shared collector, and the open bottom now shows it. |
| Machinery | Pod | Upright; moving parts on named nodes | Per pilot, section 4 |
| DecalPlate | Pod | Upright | New. A 0.36 by 0.30 m plate on the back of the seat, facing the chase camera (section 7) |
| Pilot | Pod > Dome > AnimatedPilot | Upright with Pod; plays clips | Unchanged: `fit_pilot_into` (`hero_assets.gd:516-529`) |

**The mechanical story.** The cradle is a pendulum on rollers. Its weight keeps it upright inside the tumbling rings, and the gyro hoop is a stabiliser flywheel. The hoop spins faster as you go faster, so its spin rate shows your speed.

**Optional extra, off by default: pendulum sway.** The cradle pitches up to 6 degrees back on hard acceleration and 6 degrees forward on braking, easing out over 0.25 s. Momentum then shows in the pilot's posture. Keep it only if the sight-cone check (section 3, rule 3) still passes.

## 3. Silhouette rules at chase distance

**The camera.** At rest the arm is 7.5 m, rising to 10.5 m at speed (`chase_camera.gd:213`). The falling and boss profiles push it to 12 m (`chase_camera.gd:27-29`), and the shoulder view pulls it in to 4.2 m (`:11`). Pitch starts at 0.30 rad, about 17 degrees down (`:36`). The lens is 65 degrees at rest and 80 degrees fast (`:19-20`).

**On-screen sizes at 1080p** (measured as angle over vertical lens):

| Camera | Ball (2.0 m) | Seated pilot (1.1 m) | Head (0.4 m) | Ring band (0.10 m) | A 0.15 m outline break |
| --- | --- | --- | --- | --- | --- |
| Close, 3.6 m, 65 degrees | 516 px | 289 px | 106 px | 26 px | 40 px |
| Mid, 7.5 m, 65 degrees | 252 px | 139 px | 51 px | 13 px | 19 px |
| Fast, 10.5 m, 80 degrees | 147 px | 81 px | 29 px | 7 px | 11 px |
| Far, 12 m, 65 degrees | 158 px | 87 px | 32 px | 8 px | 12 px |

**Read order.** In under 0.3 s the eye must get three things, in this order:

1. The ring outline says "ball".
2. The pilot's head shape over the seat back says "who".
3. The machinery breaking the outline says "what kit".

**Rules.** Each rule has a check.

1. **Pilot fully visible.** At the mid camera, at least 75% of the pilot's silhouette pixels are unblocked by cage parts, averaged over a 1 s roll at cruise, at heft classes I, III and V. At least 90% of the head-and-ears region is unblocked. Check: render a pilot-only mask and the full frame from the same eye, then compare.
2. **Head size holds.** The head stays at least 45 px tall at the mid camera, and ears, crest or carapace add at least 8 px above it. Check: the same mask.
3. **Sight cone.** The sight cone is a cone from the pilot's head towards the chase eye, half-angle 35 degrees. Nothing on Pod may sit inside it. Core ring bands may cross it, because they are thin and keep moving. Plates and chunks never enter it, and chunks keep today's tuck rule (`TUCK_FROM` and `TUCK_GONE`, `hero_assets.gd:69-70`).
4. **Outline break.** The machinery breaks the ring outline by 0.15 to 0.25 m (11 to 18 px at 10.5 m) at one or more points seen from behind, at the clock positions in section 4. No two pilots share the same break pattern.
5. **Rear tell.** Each pilot shows one machine face to the chase camera: a breech, a drum face, exhaust mouths, a wrench rack.
6. **Where machinery may reach.** Pod parts may stand out to radius 1.25. Nothing past radius 1.0 may sit below Z -0.6, so slopes do not swallow it. Core stays inside 0.985 (`shell_base.finish()` checks this at `shell_base.py:156-157`). Today's accretion budget already lets hardware stand out "about 1.1 m off the collider" (`src/build/accretion.gd:17-19`), so visual reach past the collider is not new.
7. **Thick enough to survive speed.** Ring bands are at least 0.10 m wide (7 px at 10.5 m). Today's 0.055 m gyro hoop is 4 px there.
8. **No wagon-wheel strobe.** At 30 m/s the rings turn 0.51 rad (29 degrees) per 60 Hz frame. Evenly spaced pads 30 degrees apart would seem to spin backwards. Irregular spacing averaging 60 degrees does not. Check: record a 1 s strip at 30 m/s and look for reversed motion.
9. **Value-opposite cradle.** The yoke and seat directly around the pilot sit at least 25 L* away from the pilot's main fur or feather value (section 6).
10. **Greyscale identity.** Six mid-camera frames, cut to 96 px wide greyscale thumbnails and shuffled. A blind reader names all six pilots. This is the measurable stand-in for the 0.3 s glance. Andrew's sitting can add a human 0.3 s flash test as an optional extra.

## 4. Per-pilot machinery and silhouette

Clock positions are as seen from the chase camera, with 12 at the top. "Glow" is the `class_accent` slot, which emits only at the working device (`VISUAL-LANGUAGE.md:66, 389`). The node names in the last-but-one column already exist and stay, so kit code and tests keep their hooks.

| Pilot (class id) | Class colour | Head read from behind | Machinery (form mirrors function) | Outline break | Rear tell | Glow at | Nodes kept | Plate motif |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sable (`pylon_engineer`) | Field mint `#8bf0d3` (`class_def.gd:13`) | Two tall pointed ears, petrol cap, bushy bone-tipped tail over the seat lip | Pylon coil mast (copper winding, bare-metal core) for the detonation gauge; rope winch spool for the grapple; a rack of three or four wrenches | 11 o'clock: the coil mast rises 0.20 m past the ring. 3 o'clock: the spool bulges 0.12 m. Asymmetric. | Wrench rack and coil base on the seat back | Coil tip | `RopeExit` (`tools/blender/world_one/shell_sable.py:179`) | Small rounded plates, felt-lined and rubber-bushed; Sable's shell "rattles least" (`VISUAL-LANGUAGE.md:307`) |
| Rivet (`runner_gunner`) | Copper `#b77843` (`class_def.gd:14`) | Broad round low head, no ear points, goggle strap | Stepped drill nose with the cutting lens at its tip; copper cooling fins raked back like chevrons; twin exhaust stacks | 11:30 and 12:30: twin stacks stand 0.18 m tall. The fins at 4 and 8 form a V pointing forward. | Exhaust mouths, lit copper during the sprint | Lens tip and exhaust mouths | None today. Add `DrillTip`, an empty at the lens facing +Y. | Raked chevron plates |
| Kest (`demolitions_caster`) | Safety amber `#e5a044` (`class_def.gd:15`) | One narrow swept crest over a bone head | Slotted fin vents: glide fins with louvres that the smoke blink vents through; short mortar tube in a recoil cradle; satchels in horizontal bands only (`VISUAL-LANGUAGE.md:331`) | 2 and 10 o'clock: the vents sweep up and back, 0.10 m past the ring folded and 0.25 m open. A V. | Vent louvres and mortar mouth | Fuse tips | `VaneL` and `VaneR` (`world_one/shell_kest.py:228`; opened by `hero_assets.gd:481-486`) | Light perforated panels |
| Tarn (`tarn`) | Iron oxide `#9b513a` (`class_def.gd:16`) | Small round ears, wide cheek wedges, thick striped tail | Two claw frames, each with toothed upper and lower jaws on hinges; a rope pull drum; a vice bridge | 4 and 8 o'clock: the jaw tips sit 0.15 m past the ring, low and forward. Wide shoulders. | Pull drum face, low centre | Jaw-tooth edges | `ClawPivot.R/L`, `ClawTip.R/L`, `PullDrum`, `PullExit` (`tools/blender/shell_tarn.py:120-129`) | Thick slabs scored with claw marks |
| Tally (`tally`) | Ledger cream `#e6d9b8` (`class_def.gd:17`) | Two big round disc ears | Ledger drums: today's flywheels, wound with punched card tape; a card reader carriage with three bays; a stamp sole | 3 and 9 o'clock: round drums stand 0.12 m past the ring, level. They echo the ears. | Drum faces | Reader slot | `Flywheel.R/L`, `FlywheelAxis.R/L`, `ReaderCarriage`, `CardBay.0/1/2`, `ReturnExit`, `StampContact` (`tools/blender/shell_tally.py:134-164`) | Square stamped plates with rows of punched holes |
| Cannon (`remembered_cannon`), the showcase | Uranium-glass green `#9dff3c` (`class_def.gd:18`, `palette.gd:12-15`) | Earless low oval carapace | One cast barrel housing (muzzle forward, round breech behind the seat); two split ports; sector shutter; rush ring underneath | 5 and 7 o'clock: the split ports stand 0.12 m out. The breech sits centred inside the outline. | Breech face, 0.40 m across, the only centred rear tell in the roster | Muzzle ring and seams, with the dashed pattern cue | `MainBarrel`, `LaneMuzzle`, `BarrelPivot`, `SplitExit.R/L`, `SectorShutter`, `RushContact` (`tools/blender/world_one/shell_cannon.py:20-25, 109, 125`) | Salvaged cast shell fragments strapped on with copper bands |

**Pilot looks come from the six-pilot lineup prompt** (`game-completion-plan-75f776/artifacts/local/alpha/push/w1/D6/out/PROMPTS.md:380-385`) and the recipes. Rivet's fur is `common.mix("charcoal", "bone", 0.32)` (`tools/blender/world_one/shell_rivet.py:140`). Kest's crest and beak are at `world_one/shell_kest.py:179-180`. Tarn's ash is `ASH = "5e5a54"` (`tools/blender/pilot_tarn.py:24`).

**The board matrix.** Every pilot gets the same six cage ideas, so Andrew can compare across the roster:

| Variant | Cage idea |
| --- | --- |
| v1 | Two hoops, lightest; kit on a rear rack or a boom |
| v2 | Three-axis gyroscope; kit on the flanks |
| v3 | Wide tread band plus two hoops; kit forward |
| v4 | Welded strut lattice; kit built into the struts |
| v5 | Mid heft, plated |
| v6 | Late heft, heavy machine |

The Cannon adds v7, an ancient cast ring repaired with salvage, and v8, the barrel as the cage's spine. Kest's v1 and v3 test a perch in place of a seat.

**Pick rule (on the veto list).** Andrew picks one variant per pilot, or re-rolls or skips. If his v1 to v4 picks split across structures, the coordinator uses the most-picked structure for the whole roster's rings and keeps each pilot's machinery placement from that pilot's own pick. One ring structure is the "one visual language" the plan asks for.

## 5. Heft accretion stages

Durability is scrap armour (design principle 19), so plates say how much armour you carry. Heft classes are set at heft 1.0, 1.5, 2.2, 3.2 and 4.6 (`src/core/run_state.gd:21`). Plates follow the class signals `heft_class_changed` and `heft_class_dropped` (`src/core/game_events.gd:36-37`).

A **detail shell** is an extra GLB layer drawn on top of a base asset, with its own budget class (`tools/asset_budgets.json:75`, `docs/decisions.tsv:363`).

| Class | Stage | What it adds | Mounted on | File | Budget |
| --- | --- | --- | --- | --- | --- |
| I | Open: a rider | Base cage only | Core, Pod, Gyro | `world_one/shell_<id>.glb` | `shell` class cap: 11,000 tris, 11,600 verts, 10 draws (`asset_budgets.json:39`). Target: 6,600 tris or fewer, 10 draws or fewer. |
| II | Open, first plates | Six bowl plates around the seat bowl, all below Z -0.35 | Pod | `shell_<id>_c2.glb` | `detail` class (1,500 tris, 3,000 verts, 1 draw); target 900 tris |
| III | Plated | Tread shoes: four per ring on the inner face of the rings, never past radius 0.985 | Core | `shell_<id>_c3.glb` | `detail`; target 900 tris |
| IV | Heavy machine | Flank armour outside the yoke at 3 and 9 o'clock, out to radius 1.12; rear armour round the machinery base | Pod | `shell_<id>_c4.glb` | `detail`; up to 1,500 tris |
| V | Heavy machine, full | Bowl armoured up to the pilot's waist (Z -0.15); the machinery's heavy parts (Sable's doubled coil, Rivet's big drill cone, Kest's wide vents, Tarn's big claws, Tally's big drums, the Cannon's enlarged barrel housing) | Pod | `shell_<id>_c5.glb` | `detail`; up to 1,500 tris |

**Totals at class V.** Pilot 4,600 tris (`asset_budgets.json:45`), plus cage 6,600, plus plates 4,800, makes 16,000 tris. That matches today's no-growth pod ceiling (`world_one/shell_sable.py:26-28`). Draws: 5 + 10 + 4 = 19.

**One surface per plate shell.** Each layer is one mesh on one slot, so it costs one draw. Bolt heads and rubbed edges ride vertex colour. Plates use `paint`, so the equipped paint carries onto them. The Cannon's plates use `ancient_enamel`.

**Class up.** The new layer's plates slam in over 0.18 s from 0.10 m out, easing out with a 1.2 overshoot. That overshoot is reserved for player-owned success (`VISUAL-LANGUAGE.md` §8). It lands on the heft dial's clunk (§7). It is one bold animation for the event and has no light.

**Class down sheds plates.** The lost layer's plates fling outward over 0.45 s, matching `FLING_SECONDS` (`accretion.gd:28`), then hide. They are never freed during a run. Armour mode holds a class until heft falls 5% of the interval below the threshold (`run_state.gd:33, 246-263`), so plates never flicker.

**The outline still grows.** It widens 0.12 m a side at class IV, and machinery grows at class V.

**Accretion chunks join the cage.** Chunks today sit on an invisible sphere and grow 7% per class (`accretion.gd:27, 66-67`). With open rings, a chunk floating between rings looks wrong. Two changes, both on the veto list:

- Chunk slots snap to the nearest point on a ring or strut.
- `SHELL_PER_CLASS` goes to 0.0 for caged shells, because the plates now carry the growth read.

The 36-chunk cap (`accretion.gd:21`) and the tuck rule stay.

**Measures.**

- Blind pairs at the far camera, class I against class V: the reader picks the heavier one, 3 of 3 for each pilot.
- At class V, rule 1's pilot visibility still holds.

## 6. Materials and colour slots

The slots are the shared table in `hero_assets.gd:84-99`. Materials come from a cache keyed by slot and tint (`hero_assets.gd:175-177, 249`), so every pilot's rings share one `paint` material per tint.

| Slot | On the cage | Colour | Emits | Paint cosmetic tints it |
| --- | --- | --- | --- | --- |
| `paint` | Ring enamel, yoke panels, machinery housings, every plate layer | Vertex colours from petrol, oxide and bone (`common.PAINT_SET`) | No | Yes (`hero_assets.gd:233-235`) |
| `bare_metal` | Ring edges, struts, axle hubs, yoke arms, rubbed bright where hands and rope touch | Sand lightened 25% (`hero_assets.gd:86`) | No | No |
| `rubber` | Tread pads, bushings, seat padding, bumpers | Charcoal | No | No |
| `class_accent` | The working device only (section 4) | The class row's colour (`hero_assets.gd:88`) | 0.5 | No |
| `field` | The intake coil under the seat | Field mint | 1.6 | No |
| `pilot` | The pilot | Vertex colours | No | No |
| `copper` (proposed) | Windings, coil wraps, straps, bearings | `Palette.COPPER`, metallic 0.6, roughness 0.4 | No | No |
| `ancient_enamel` | The Cannon's cast parts and plates | Vertex colours under the enamel cap | No | No |
| `ancient_light` | The Cannon's seams, with the dashed pattern | `Palette.ANCIENT` | 2.4 | No |
| `glass` | Retired on caged shells | | | |
| `requisition_tag`, `fleet_paint` | Never on a player asset | | | |

**Copper, never brass.** Brass is the Furnace Fleet's requisition colour (`VISUAL-LANGUAGE.md:48`, `palette.gd:21`). A player asset carries no `requisition_tag` slot and no brass-hued vertex colour. Paint rows already refuse tints near BRASS (`src/core/cosmetics.gd:19-20`). Copper on every mech's coils is the standing rule (`VISUAL-LANGUAGE.md:44`). It does not clash with Rivet's class colour, because class colour governs emitted light, not materials (`VISUAL-LANGUAGE.md:66`).

**Why a `copper` slot.** Today copper rides vertex colour on `paint` or `pilot`. An equipped paint multiplies every `paint` vertex colour, so a Cobalt paint would turn the copper windings blue. A slot keeps copper copper. The CAGE-BASE unit adds it.

**Value-opposite cradle.** Lightness (L*) values computed from the hex colours:

| Colour | L* |
| --- | --- |
| Petrol | 34.5 |
| Oxide | 43.0 |
| Bone | 79.8 |
| Sandstone | 68.8 |
| Tarn ash | 38.4 |
| Rivet fur | 38.7 |
| Tally fur | 45.0 |
| Tally cream | 95.3 |
| Cannon verdigris | 49.8 |

Tarn and Rivet are within 4 L* of petrol, so a petrol yoke would swallow their heads.

| Pilot | Yoke and seat |
| --- | --- |
| Tarn, Rivet | Bone, or rubbed bare metal |
| Tally, Kest | Petrol |
| Sable | Bone |
| Cannon | Charcoal (16.4) |

**Tarn's colour clash.** Tarn's class colour is iron oxide, which also means "harm to you" and Fleet paint (`VISUAL-LANGUAGE.md` §2). Tarn's cage enamel therefore uses bone and petrol, never oxide. The stripes and the jaw-tooth glow carry the class read.

**The ancient colour.** The ancients' light is uranium-glass green `#9dff3c` (`palette.gd:12-15`; Andrew's choice, `docs/decisions.tsv:350`). It reads as BRASS to deuteranopes and as mint under tritanopia, so every seam also carries a dashed pattern. The A3 brief said Cherenkov blue. The register is newer and is Andrew's own call, so this sheet follows it (see Conflicts).

## 7. Cosmetics on the cage

- **Paint** (rows at `cosmetics.gd:24-41`) tints the `paint` slot: ring enamel, machinery housings and every plate layer. A class-up keeps your colour. The Cannon's plates are `ancient_enamel` and keep their cast look. Its paint, Old Verdigris, tints its rings.
- **Decal** (rows at `cosmetics.gd:48-55`) moves off the Core. Today it projects onto Core surfaces named `glass` or `paint` (`cosmetic_presentation.gd:109-112`). The Core now tumbles and has no glass. The decal goes on the seat-back `DecalPlate`, which faces the chase camera. The projection uses the plate's local frame, and the 0.65 m tile default (`cosmetic_presentation.gd:87`) shrinks to the plate's 0.36 m. B5 owns this code change.
- **Shell variant** (the slot kind settled in today's grill) swaps the cage structure: ring count, strut style and plate shape. It never moves the machinery, its sockets or the sight cone. Each variant ships its own four heft layers. The board feeds it: each pilot's runner-up variant becomes that pilot's first earned shell variant, so the concept pass doubles as the cosmetic pipeline. The heft layers and the variant share one loader path, B5's shell lookup by variant and heft layer (plan, wave P-B).
- **Trail and companion paint** are unchanged.

## 8. Performance notes

- **No light on the cage.** No OmniLight3D, SpotLight3D or other light node rides the shell, a plate or the pilot. Glow is emission on cached slot materials (`hero_assets.gd:88-95`). The wave 11 Vulkan segfault was an OmniLight3D on each cracked cache, freed with the cache at stage clear. The next boss entry then hit the engine's light-unpair bug (`design-v3/HANDOFF.md:11`). The wave 9 per-cage light was the same class of bug.
- **No per-instance `material_override` on cage or plate nodes.** Slot materials come from the cache and attach as surface overrides through `paint()` (`hero_assets.gd:259-278`). `air_cue` builds and frees a `material_override` for each ring it makes (`hero_assets.gd:447-463`). Plates must not copy that pattern.
- **Hide, never free, during a run.** Heft layers load once when the shell fits and toggle visibility. Only `_fit`'s class swap frees them (`hero_assets.gd:369-374`).
- **Heft layers are state, not distance detail.** They get no visibility range, and they cast shadows, because the player's shadow is a landing read. The scenery detail-shell rule turns shadows off and fades by range (`docs/decisions.tsv:378`). That rule is for level-of-detail chains, not for the player.
- **Budget.** 16,000 tris and 19 draws for the whole ball at class V. That is one object, inside principle 16's gate of 7 ms GPU and 10 ms CPU at p99 on the dev box. Check the ratio against the pre-wave base on card 1, under the 1.3x rule.
- **Collider unchanged.** It stays a sphere of radius 1.0. Growth shows in plates and machinery.

## 9. Recipe route for wave P-D

**Steps.**

1. **Board approval by click.** The coordinator runs `tools/concept/run_board.sh pilots-cage` through the GPU queue on card 0. `BOARD_ROOT` defaults to `artifacts/local/alpha/push/w13/concepts` (`run_board.sh:4-7`). The coordinator serves the board widget, Andrew approves, re-rolls or skips each card, and the verdicts land in `boards/pilots-cage.verdicts.json`. The pick rule in section 4 harmonizes the structure.
2. **CAGE-BASE first, one unit.** It adds the shared Blender helper and the Godot fit (block below). The six pilot units wait for it.
3. **Six pilot units in parallel.** Each pilot gets a shell recipe on the shared helper, the board's machinery, and the four heft-layer detail shells. The pilot body is the existing animated GLB. Rebuild it after `tools/blender/pilot_tarn.py` only when the approved card changes the pose (a Kest perch, for example). Keep it within the `pilot` class: 4,600 tris, 3,100 verts, 5 draws.
4. **Registry fragment and fold.** Each unit writes `units/<unit>/registry-fragment.json`, with the shell under `shell`, the layers under `detail`, loader `src/presentation/hero_assets.gd`, and provenance naming the recipe and the board verdict key. The coordinator folds it with `tools/fold_registry.py` and runs `node scripts/fold-registry.test.mjs`. Today's shell rows sit at `assets/registry.json:2846-2897`.
5. **Loader.** `SHELLS` stays keyed by class id (`hero_assets.gd:55-62`). B5 adds the layer and variant lookup, which reads `shell_<id>[_<variant>]_c2..c5.glb` and mounts each layer under HeroCore or HeroPod. It warns once and skips a missing layer.
6. **Look subjects.** CAGE-BASE adds three rows per pilot to `tools/look_subjects.gd`: `cge_<pilot>_c1`, `_c3` and `_c5`, kind `actor`. Eyes sit behind the heading at:
   - close: (0, 1.06, 3.44)
   - mid: (0, 2.22, 7.17)
   - far: (0, 3.55, 11.46)

   All three target (0, 0.2, 0) with a 65 degree lens. These match the chase pitch of 0.30 rad at 3.6, 7.5 and 12 m. Blind pairs: the old glass shell against the new cage at each distance, and class I against class V at far. The reader records picks before opening `key.json`.

**Shared VERIFY for every P-D unit.**

- `npm run asset:inspect -- <glb> --max-tris <class cap>` with status pass, run on the shell and each layer.
- The `CORE_RADIUS` line from `shell_base.finish()`.
- The registry fold test.
- `tools/coordinator/compile_check.sh` and `node scripts/sketch-lint.mjs --sketch core-loop`.
- The unit's named tests, red then green. Re-pins carry dated headers.
- A fence check with `git diff --name-status` against SCOPE.

### Unit CAGE-BASE (runs first)

- **SCOPE:**
  - `tools/blender/shell_base.py`: add `cage(name, kit, animal, rings, struts, cradle, extras)` beside `spherical()`, which stays for the fallback until all six move. It builds the Core rings, the Gyro hoop with axle hubs, and the Pod yoke, cradle, intake coil and `DecalPlate`. It adds `Plate.C2` to `Plate.C5` socket empties and the radius and sight-cone checks in `finish()`.
  - `src/presentation/hero_assets.gd` `SLOTS`: the `copper` row only.
  - `src/build/accretion.gd`: chunk slot snap and `SHELL_PER_CLASS` for caged shells.
  - `tools/look_subjects.gd`: 18 rows.
  - `tests/hero_assets_test.gd:180-204`: re-pin the glass-hull check to a ring check (Core outer radius 0.95 to 0.985, no `glass` slot; Pod > Gyro and Pod > Dome > Pilot kept).
  - A new `tests/cage_contract_test.gd`.
- **ACCEPTANCE:**
  - A neutral test cage built by `cage()` passes `asset:inspect` under `shell` at 6,600 tris or fewer and 10 draws or fewer.
  - Core max radius is 0.985 or less. No Pod vertex sits past radius 1.0 below Z -0.6.
  - The sight cone is empty of Pod geometry.
  - `cage_contract_test` fails on a shell with a `glass` or `requisition_tag` slot, a light node, or a `material_override`.
  - Chunks seat within 0.05 m of a ring or strut in a headless build at 36 chunks.
  - `hero_assets_test` is green after the dated re-pin.
  - The look rows boot with a dead-frame pass.

### Unit PD-SABLE

- **SCOPE:** `tools/blender/world_one/shell_sable.py` (rewritten on `sb.cage`), a new `tools/blender/world_one/shell_sable_plates.py`, `assets/models/world_one/shell_sable.glb` and `shell_sable_c2.glb` to `_c5.glb`, the unit's registry fragment, and a dated re-pin of `tests/world_one_shell_sable_test.gd`.
- **ACCEPTANCE:**
  - Built from the approved `sable_v*` card; the recipe header names the key.
  - Coil mast break at 11 o'clock, 0.20 m. Spool break at 3 o'clock, 0.12 m.
  - `RopeExit` sits at the spool's rope mouth.
  - The coil tip is the only `class_accent` surface.
  - The wrench rack shows in the mid frame.
  - Plates are rounded and bushed.
  - The yoke and seat are bone.
  - Rules 1 to 9 of section 3 pass.
  - Budgets per section 5.

### Unit PD-RIVET

- **SCOPE:** `tools/blender/world_one/shell_rivet.py`, `world_one/shell_rivet_plates.py`, `assets/models/world_one/shell_rivet.glb` and `_c2` to `_c5`, the registry fragment, and a re-pin of `tests/world_one_shell_rivet_test.gd`.
- **ACCEPTANCE:**
  - Built from the approved `rivet_v*` card.
  - A new `DrillTip` empty at the lens faces +Y and lines up with the laser's fire direction.
  - Twin stacks stand 0.18 m and show above the seat back in the mid frame.
  - The fins read as a forward V.
  - Lens and exhaust mouths are the only `class_accent`.
  - The yoke and seat are bone, because the fur is L* 38.7.
  - Rules 1 to 9 pass. Budgets per section 5.

### Unit PD-KEST

- **SCOPE:** `tools/blender/world_one/shell_kest.py`, `world_one/shell_kest_plates.py`, `assets/models/world_one/shell_kest.glb` and `_c2` to `_c5`, the registry fragment, and a re-pin of `tests/world_one_shell_kest_test.gd`.
- **ACCEPTANCE:**
  - Built from the approved `kest_v*` card.
  - `VaneL` and `VaneR` hinge on the cage flanks. They open to 90 degrees under `hero_assets.gd:481-486` without entering the sight cone or crossing the ring's inner radius.
  - The vents stand 0.10 m past the ring folded and 0.25 m open.
  - Satchel bands are horizontal only.
  - If the perch is approved, the pilot body follows the `pilot_tarn.py` route and passes the `pilot` class.
  - Plates are perforated panels.
  - The registry exception for Kest's 16 draws (`assets/registry.json:2857-2864`) is removed if the shell comes in at 10 draws or fewer.
  - Rules 1 to 9 pass.

### Unit PD-TARN

- **SCOPE:** `tools/blender/shell_tarn.py`, a new `tools/blender/shell_tarn_plates.py`, `assets/models/world_one/shell_tarn.glb` and `_c2` to `_c5`, the registry fragment, and re-pins of `tests/tarn_look_test.gd` and `tests/pilot_tarn_asset_test.gd` where they pin shell geometry.
- **ACCEPTANCE:**
  - Built from the approved `tarn_v*` card.
  - `ClawPivot.R/L`, `ClawTip.R/L`, `PullDrum` and `PullExit` are kept, and the jaw nodes rotate as single-material meshes.
  - At rest the jaw tips sit 0.15 m past the ring at 4 and 8 o'clock, above Z -0.6.
  - The cage enamel is bone and petrol, never oxide.
  - Jaw-tooth edges are the only `class_accent`.
  - The yoke is bone.
  - Plates are slabs with claw scores.
  - Rules 1 to 9 pass.

### Unit PD-TALLY

- **SCOPE:** `tools/blender/shell_tally.py`, a new `tools/blender/shell_tally_plates.py`, `assets/models/world_one/shell_tally.glb` and `_c2` to `_c5`, the registry fragment, and re-pins of `tests/tally_look_test.gd` and `tests/pilot_tally_asset_test.gd` where they pin shell geometry.
- **ACCEPTANCE:**
  - Built from the approved `tally_v*` card.
  - `Flywheel.R/L` become the ledger drums with the same names, and `FlywheelAxis.R/L` are kept.
  - `ReaderCarriage`, `CardBay.0/1/2`, `ReturnExit` and `StampContact` are kept.
  - The drums stand 0.12 m past the ring at 3 and 9 o'clock.
  - The reader slot is the only `class_accent`.
  - The yoke is petrol, because the cream is L* 95.
  - `tally_look_test`'s cream contract stays green.
  - Rules 1 to 9 pass.

### Unit PD-CANNON (showcase)

- **SCOPE:** `tools/blender/world_one/shell_cannon.py`, `world_one/shell_cannon_plates.py`, `assets/models/world_one/shell_cannon.glb` and `_c2` to `_c5`, the registry fragment, and re-pins of `tests/cannon_look_test.gd` and `tests/pilot_cannon_asset_test.gd` where they pin shell geometry.
- **ACCEPTANCE:**
  - Built from the approved `cannon_v*` card. The v7 cast ring or v8 barrel spine is used if Andrew picked it.
  - `MainBarrel`, `LaneMuzzle`, `BarrelPivot`, `SplitExit.R/L`, `SectorShutter` and `RushContact` are kept. `LaneMuzzle` lines up with Combat's lane direction (`BUILD-SPEC.md`, cannon unit).
  - Ancient parts are cast and seamless, with no bolts. Salvage repairs are bolted copper and rubber.
  - Every `ancient_light` seam carries the dashed pattern cue.
  - The breech face is 0.40 m across and centred in the mid frame.
  - Plates are on `ancient_enamel`.
  - The yoke is charcoal.
  - `cannon_look_test` is green.
  - Rules 1 to 9 pass.
  - The showcase pass adds one close turntable strip of a class-up slam for the review page.

## Conflicts resolved

- **The ancient colour.** The A3 brief said ancient tech glows Cherenkov blue. On 2026-10-09 Andrew chose uranium-glass green over Cherenkov blue (`docs/decisions.tsv:350`), and the code follows (`palette.gd:12-15`, `VISUAL-LANGUAGE.md:50`). This sheet and the board prompts use uranium-glass green with the dashed seam pattern. A line in the project memory still says Cherenkov blue and is stale.
- **Glass against the open cage.** `VISUAL-LANGUAGE.md:391, 416` and the D6 `BUILD-SPEC.md:8` keep a glass hull. Andrew's 2026-10-10 sphere-body choice supersedes them for the alpha sketch. AD-01's "protected, readable cockpit" holds as a roll cage.
- **Brass on Tally.** The atlas prompt for Tally (`design-v2/visual-development/prompt-17-tally-presence.txt`) names "repaired brass/wood". Friendly gear never wears brass, so the cage uses copper and timber. The relic name "Brass Governor" (`src/build/relics.gd:126`) is a friendly item named for the Fleet's colour. It is flagged for a rename and not changed here.
- **Rivet's front end.** The plan calls it a drill nose. `VISUAL-LANGUAGE.md` §6 calls it an optical rail and cutting lens. Both stand: the drill nose's tip is the lens.
- **Plates on the rings against a visible pilot.** Plates that tumble with the rings would sweep over the pilot. The fix is to put only thin tread shoes on the rings (class III) and put the bulk armour on the upright Pod, below the sight cone.

## Veto list (calls made under the creative charge)

1. Three motion layers: the tread rings tumble with the ball, the gyro hoop spins with speed, and the cradle and machinery stay upright.
2. The gyro hoop moves inside the rings, to radius 0.84 to 0.88.
3. Plates by class: II bowl, III ring shoes, IV flank armour, V waist-high bowl plus heavy machinery. One single-surface detail shell each.
4. Machinery may break the outline out to radius 1.25 on the Pod, never below Z -0.6.
5. Caged shells drop accretion's per-class scale, and chunks snap to rings.
6. The decal moves to a seat-back `DecalPlate`.
7. Each pilot's board runner-up becomes its first earned shell variant.
8. A new `copper` slot, so paint never tints windings.
9. Value-opposite yoke colours per pilot.
10. The structure pick rule: the most-picked v1 to v4 structure goes roster-wide.
11. A Kest perch as a board option.
12. Optional, off by default: pendulum sway of 6 degrees.

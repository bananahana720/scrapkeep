# Roster look: six pilots in Hoberman mechas

Wave 13, unit A3. This sheet sets one visual language for the six pilot balls: a fully expanded Hoberman sphere mecha. Andrew first chose an open gyro cage on 2026-10-10 (session plan, "Decisions settled today", row "Sphere body"). That evening he rejected all 38 cage pictures and chose the Hoberman mecha (`docs/decisions.tsv:417`). The heft stages come from the plan's creative-charge list ("The cage gains body with heft", now the mecha gains body) and stay on the veto list at the end. Every number here is a starting value to tune in play unless it cites code.

The concept source is the cleaned Astra picture set in `artifacts/local/alpha/push/w13/concepts/codex/`: a shared base (`base/base-hero.png`, `base/mechanism.png`) and, for each pilot, a hero, a chase view and a callout sheet. Andrew approved the set as one, conditional on the coherence re-audit (`docs/decisions.tsv:422`). Section 0.7 holds the set rules. Wave P-D builds from the pictures.

**How to read this sheet.** Section 0 is the design. Sections 1 to 3 say why the sphere changes and how it must read at chase distance. Sections 4 to 7 set each pilot's machinery, the heft panels, the colour slots and the cosmetics. Sections 8 and 9 hold performance and the build route.

**What this sheet replaces.** For the alpha sketch it replaces the class-shell rows and the "growth and cockpit rules" in `VISUAL-LANGUAGE.md` §9 (lines 378 to 416), and the "reuse the 0.98 m glass sphere" rule in the wave 1 D6 build spec (`game-completion-plan-75f776/artifacts/local/alpha/push/w1/D6/out/BUILD-SPEC.md:8`). Bible AD-01 (`BIBLE.md:620`) asks for "a protected, readable cockpit and recognizable equipment". The mecha meets that better than glass did. The pod hangs in a two-axis gimbal at the centre, the lattice is a roll cage around it, and the equipment sits outside where it shows. Moving the mecha into the Bible needs a heavy-lane card (`VISUAL-LANGUAGE.md:3`).

## Ball look candidates, 13 November 2026 (Andrew picked the cutaway, ruling dm)

Andrew asked on 13 Nov 2026 to reconsider the ball ("go big and bold") and set one hard rule: the player must see the pilot and what the pilot wears. Three looks sit behind the launch switch `--ball-look=gyro|bell|cutaway`; the default `today` keeps the Hoberman shells this sheet describes, so nothing below changes until the finished cutaway has passed his PC check. The concept page with pictures, the pass line and the receipts is https://claude.ai/artifact/YLJGxfhfDNfA9nwEzpmQW4.

- **Where they live.** Shapes: `tools/blender/ball_looks.py`. Switch, plating, window and materials: `src/presentation/ball_looks.gd`. Pictures and counts: `tools/ball_look_capture.gd`. Test: `tests/ball_looks_test.gd`.
- **Pass line.** The play camera sees at least 75% of the pilot on the median of 24 spins and 60% on the worst, at 7.5 m and at 10.5 m. Blockout receipts (cloud, Sable, shared cockpit): cutaway 82% and 82%, bell 67% and 53%, gyro 57% and 37%, today's shell 52% and 45%.
- **Picked: cutaway** (Andrew, 13 Nov 21:44Z; ruling dm in [DECISIONS.md](../../../project-guide/handoff/DECISIONS.md)), a solid plated ball whose shader discards a window on the side facing the camera (no blended surface). It is the "sight-cone cutout" this sheet lists as a separable extra, made the whole look.
- **What a pick replaces.** The bell puts glass on the level Pod, which the "Forbidden" row below allowed for an inner cockpit sphere on 22 Oct; none puts glass on the rolling outline.

### The cutaway as built (13 November 2026)

The gyro and the bell remain one shared shell each, as Andrew saw them. The cutaway keeps every pilot's own shell and changes only what rolls, so sections 0.1 to 0.4 below still describe the Pod, the weapon ring, the cockpit and the hub mounts.

| Part | Under `--ball-look=cutaway` |
| --- | --- |
| Rolling part (Core) | The lattice mesh becomes plating: gores in the pilot's own enamel (the mean colour of the lattice it replaces), darker gores between, a bone belt, oxide caps, tread pads. The hub mounts stay, so scrap still clamps on. |
| Heft classes II to V | The lattice's gap panels sit inside the ball's radius and would float beside the pilot, so they are hidden. The plating grows instead: II copper hoops, III armour over the dark gores, IV tread cleats on the belt, V copper caps with a stud crown. Kit that stands outside the ball (hoods, drums, hooks) still arrives with its class. |
| Window | 40 degrees about the line from the ball's centre to the camera, with an ink line and a halftone fringe. It cuts the plating, and everything that rides the ball: scrap chunks, part hardware, panel plates. On the level part it cuts kit that stands farther than 0.93 from the centre (the weapon ring's near arc), and anything behind the pilot's back above the seat (brackets, backrests), judged by the tube of sight the window opens. The seat, controls and everything in front of the pilot are never cut. |
| Seat back | A pilot too small for the shared seat back has it lowered (`LOW_SEAT_BACK`: Rivet, to 0.06 above the seat). |
| Glance | At rest for three seconds, the pilot turns chest, neck and head over a shoulder to look at the camera, holds 1.2 seconds, turns back, and repeats every seven seconds; it ends the moment the ball moves or a reaction clip plays (`src/presentation/pilot_glance.gd`, laid over the playing clip). |
| Equipped paint | Takes the enamel gores; the dark gores, belt and caps keep the pattern. |
| Outfits | Unchanged: the `outfit` slot, the customize page and `fit_outfit` already mount an outfit on the pilot's bones (three exist: Rivet's Welding Hood, Tarn's Steady Cap, Tally's Eyeshade), and the window is what lets the player see it in play. A new outfit is a `Cosmetics` row and a GLB whose parts are named for the rig's bones. |
| Not cut | Glass, class accents (the ready glow swaps those materials by identity), Kest's live band and fuse materials, and unshaded or see-through riders such as synergy halos keep their own materials. An equipped decal shows on the weapon ring's band only (its other home, the gap panels, is hidden), and that band is then not cut. |

**Receipts** (`tools/ball_look_capture.gd`; cloud numbers are the compatibility renderer, the PC's are on branch `scratch/w40-ball-look-capture`). Share of the pilot the play camera sees, median of 24 spins at rest (the worst spin and the speed view are within one point), heft class I, cloud:

| Pilot | Cutaway | Ball triangles | Surfaces |
| --- | --- | --- | --- |
| Sable | 90% | 13,812 | 20 |
| Rivet | 88% | 14,416 | 17 |
| Kest | 79% | 14,680 | 19 |
| Tarn | 81% | 15,174 | 21 |
| Tally | 78% | 14,633 | 13 |
| Cannon | 77% | 9,566 | 15 |

Today's shell shows 52% of Sable (PC: 54%, against the cutaway blockout's 85%). Heft class V adds 5 to 8 surfaces and about 1,300 to 2,100 triangles and hides no more of the pilot. A late run's ball (Sable, class III, scrap chunks and 40 panel plates) shows 86% of the pilot under the cutaway; today's shell with the same load showed 21%, 6% on the worst spin. No surface blends. The pilot is about 9,800 of each ball's triangles.

**Still open.** The class card and customize previews build a painter with no tuning, so they show today's shells. The default stays `today` until Andrew has seen the finished cutaway on his PC.

## 0. Direction change, 2026-10-10 evening: the Hoberman mecha

Andrew rejected all 38 open-cage pictures on 2026-10-10. His direction, in his words: "more like a Hoberman sphere that's like completely expanded out", with "panels or other things that kind of like tack on to that sphere within like maybe those different nodes or gaps", "gyroscopic stabilization for certain aspects of the ball", a weapon as "a stabilized horizontal ring that also wraps around" the sphere, and a cockpit with controls the pilot works "in sort of a mecha like manner": "a mecha that kind of like is an extension of that character", like Power Rangers.

**How the rest of this sheet reads it.** Sections 1 to 9 are written to this design. The camera numbers (§1), silhouette rules (§3), heft classes, budgets and timings (§5), colour slots (§6), cosmetics (§7) and performance (§8) are the earlier rules re-read for a lattice: "ring" reads as "lattice" and "plate" reads as "gap panel". The cage anatomy, the cage board matrix and its pick rule, and the chunk-on-ring rules are gone. The 16-picture FLUX probe board was rejected as not detailed enough (`docs/decisions.tsv:418`), so the concept source is the Astra set, not a board (§9).

### 0.1 Anatomy: four layers, split by how each one moves

The code already has three motion layers (`hero_assets.gd:401-480`). The weapon ring is the one new node.

| Part | Node | Moves | Starting size (metres, origin at ball centre) | What it does in play |
| --- | --- | --- | --- | --- |
| **Lattice** | Core | Tumbles with the true ball spin | A fully expanded Hoberman sphere at outer radius 0.975, inside the 0.985 core limit (`shell_base.py:15`). Scissor-strut pairs 0.035 m thick, crossing at **pivot hubs**. Start from an icosahedral layout: 30 great-circle scissor chains meeting at 12 five-way hubs and 20 three-way hubs, which leaves 30 large open diamond-shaped **gaps** (32 hubs and 60 links bound 30 faces). Rubber tread caps on the outer face of each hub. | The ball the eye believes. Its spin shows true roll. The open gaps keep the pilot visible (§3 rule 1). |
| **Hubs** | Core > Hub.00 to Hub.31 | With the lattice | 32 named empties at the hub centres, facing outward | Mount points. Heft chunks clamp here. Per-pilot modules sit here in the rest pose, and §0.2 says what carries them in play. |
| **Gaps** | Core > Gap.00 to Gap.29 | With the lattice | Named empties at each gap centre, facing outward | Panel slots. Heft panels and cosmetic panels fill gaps (§0.3). |
| **Weapon ring** | Pod > WeaponRing | Stays level (gyro-stabilised); yaws to the **aim** direction, not the heading | A flat horizontal ring just outside the lattice at the equator: radius 1.02 to 1.10, 0.08 m tall, on its own bearing collar | Carries the pilot's weapon. The weapon always points where the shot goes, so aim reads from the ball itself. |
| **Cockpit pod** | Pod | Upright, turns to the heading | A compact gimballed pod at the centre, on a two-axis gimbal (today's Gyro hoop becomes the gimbal's outer ring). Seat, foot pedals and per-pilot **controls** | The pilot sits and works the controls. Each control moves when its skill fires (§0.4). |
| **Pilot** | Pod > Dome > AnimatedPilot | With the pod; plays clips | Unchanged: `fit_pilot_into` (`hero_assets.gd:516-529`) | |

**Collider:** unchanged, a sphere of radius 1.0. The weapon ring overhangs to 1.10 for looks only; it never collides.

**The mechanical story.** The lattice is the rolling wheel. The pod hangs on a gimbal and stays upright like a gyroscope. The weapon ring rides a level bearing and swings to the target, the way a tank turret stays on target while the hull rocks. Every machine is the pilot's own build, an extension of who they are: the Power Rangers zord read.

### 0.2 Each pilot's zord

| Pilot | Lattice enamel | Weapon ring carries | Hub modules (sit at nodes in the rest pose) | Gap panels | Cockpit controls the pilot works |
| --- | --- | --- | --- | --- | --- |
| Sable (fox engineer) | Petrol teal | A twin arc emitter wound in copper coil, mint glow at the coil tips | One coil mast on an upper hub at 11 o'clock (the sheet keeps one upper break, not a crown of spikes; see Conflicts resolved); the grapple winch on one side hub at 3 o'clock | Small rounded felt-lined plates | Twin yokes; gauge lever and spool brake in the bank beside the right yoke; copper lap bar; two pedals |
| Rivet (mole machinist) | Charcoal steel | Twin rapid laser barrels in copper housings | A stepped drill-nose module filling the front gap; twin exhaust stacks on rear hubs | Raked chevron plates | Twin yokes; slot-2 lever and winch lever in the bank; copper lap bar with a sight; two pedals |
| Kest (bird demolitions) | Petrol teal | Short charge-launcher tubes and banded satchels | Slotted fin vanes that fold out of the side gaps like wings for the glide and blink | Light perforated panels | Twin yokes; fuse plunger and charge key in the bank; copper lap bar; two pedals (perch open: `pilots/kest.md` section 11 item 16) |
| Tarn (tiger) | Iron oxide red | Two big curved claw blades | Two hooked claw arms on the side hubs for the claw pull; a pull drum low at the rear | Thick slabs scored with claw marks | Twin yokes with grip triggers; clamp lever and drum lever in the bank; copper lap bar; two pedals |
| Tally (pack rat) | Mulberry | A drum magazine that deals flat metal cards | Ledger drums on the 3 and 9 o'clock hubs, echoing the ears; a stamp sole hub at the bottom | Square stamped plates with punched holes | Twin yokes; three tabbed card slots as the bank; copper lap bar; two pedals |
| The Cannon (ancient tortoise robot) | Dull petrol, with salvaged verdigris cast carapace plates tiling some gaps | One big seamless cast cannon barrel | Split ports on the low side hubs; a rush ring on the bottom hub | Seamless verdigris carapace plates, the showcase | Twin yokes worked by its paddles; plate crank and cable clamp lever in the bank; copper lap bar; two pedals |

Node names that kit code already uses (`RopeExit`, `VaneL/R`, `ClawPivot.R/L`, `ClawTip.R/L`, `PullDrum`, `Flywheel.R/L`, `ReaderCarriage`, `CardBay.0/1/2`, `MainBarrel`, `LaneMuzzle`, `SplitExit.R/L`, `RushContact`) keep their names and move to the new parent: weapon parts under WeaponRing, movement parts on a level carrier. **Which parts hold still.** Hubs tumble with the lattice, about five turns a second at 30 m/s. A module that has to hold a clock position at chase distance would smear into a ring if it rode a hub. So each module rides the carrier §4 names. It sits at its hub in the rest pose, as in the pictures. In play it rides either the level WeaponRing or a gap bracket, a slim arm from the Pod out through one gap (§2). Flat parts that need no position, such as Rivet's folded fins, stay on their hubs and roll.

### 0.3 Heft: panels fill the gaps

Heft classes stay as §5 sets them. What changes is where the armour goes:

| Class | Adds |
| --- | --- |
| I | Bare lattice, weapon ring and pod. Every gap open. |
| II | Panels in the lower gaps, below the pod |
| III | Panels in the side gaps, and thicker tread caps on the hubs |
| IV | Panels in most gaps; only the gaps on the camera's sight cone to the pilot stay open (§3 rule 1) |
| V | Every non-sight gap paneled, and the hub modules grow to their heavy form |

Accretion chunks snap to the nearest hub (§5). Class up slams panels into their gaps; class down flings them out of their gaps, with the same timings as §5. **Where panels mount.** The upright Pod carries the panels, just inside the lattice's inner face, so each gap shows its panel in the rest pose and the struts roll past in front of it. A panel on the tumbling lattice would sweep across the sight cone every turn of the ball (§5 and Conflicts resolved).

### 0.4 Cockpit controls drive the clips

The plan's skill bar (`design-v3/SKILL-BAR.md`) puts the weapon on slot 1, slot 2 on key 2, slot 3 on key 3, the ultimate on Q and the movement verb on Shift. Each one gets a control in the cockpit, and the pilot works it when the skill fires: a yoke trigger squeeze for fire, a lever throw for a skill, both hands on the big control for the ultimate, the pedals for Shift. These are the new cockpit clips for the clip spec, on top of the seven reaction clips. The control and the clip read the same skill event, so the hands always match the bar.

### 0.5 Separable extras (on the veto list)

- **The fold is the squash.** A Hoberman sphere really folds. On a hard landing or a ground smash, the lattice contracts about 8% and springs back out over 0.25 s. The squash and stretch comes from the mechanism instead of a scale cheat. The collider does not change.
- **Full span for the ultimate.** The ultimate opens the lattice past its rest size, to about 1.15 times, and the hub modules lock out, the zord's "megazord" moment, then folds back. The collider grows only if the ultimate's design says so. The Cannon's wind-up fold to 85 percent (`pilots/cannon.md` section 5, veto 14) is that pilot's base design, not this extra; the full span stays off for the Cannon.
- **Panels as armour you can see.** A heavy hit knocks one gap panel loose; it flings and is not freed (§5 rule).
- **What a fold or span scales.** A fold or span scales the lattice (Core) only. During a fold the Pod's `HeftC2..C5` holders scale by the same factor, so the lattice never passes through the panels: the 8% squash puts the inner face at 0.94 x 0.92 = 0.865, inside the panels at 0.92. The gimbal rings stay put, and HOBERMAN-BASE checks them (§9). A span stays at or under 1.02 / 0.985 = 1.035 unless the WeaponRing moves out with it, and the ball lifts so the caps never sink below the ground.

### 0.6 Recipe route

The lattice is procedural, which suits a Blender recipe better than a picture: one function places the 32 hubs on an icosahedral layout, threads scissor-strut pairs along the great circles between them, and emits the Hub and Gap empties. `shell_base.truss_cage()` (`shell_base.py:74-85`) is the starting point, because it already places the 12 icosahedral vertices. The cleaned Astra pictures set each pilot's modules, colours and cockpit; the lattice itself comes from code. Unit HOBERMAN-BASE in §9 builds it.


### 0.7 Concept set rules (2026-10-10 audit of the Astra pictures)

An audit of the 20 Astra concept pictures set one rule per aspect so the six mechas read as one roster. The cleanup round edits the pictures to these rules, and the Blender recipes follow the same rules. Pictures live in `artifacts/local/alpha/push/w13/concepts/codex/`.

| Aspect | Rule | Best example |
| --- | --- | --- |
| Lattice construction | Build the rolling body as a fully expanded Hoberman sphere: two flat bars of equal length crossing in an X at one copper pivot pin, chained end to end along great circles, every chain ending in a hub. No single-bar triangles, no geodesic dome, no buckyball of plain bars, no chain-link segments. | base/base-hero.png |
| Lattice density | Keep it at the base density: about five X-pairs between neighbouring hubs, so the gaps stay large, open diamonds about as wide as the pilot's head. Never pack the lattice so tightly that it reads as a mesh. The triangle budget may allow fewer pairs (§5 budget check); the look target is the picture, and the cut order is in §5. | base/base-hero.png |
| Hub style and tread caps | Every hub is a round copper hub body with a flat black rubber tread cap on its outer face, carrying a shallow tyre-tread pattern. No square bone blocks, no domed grid caps, no bone ball joints, no petrol hub bodies. | base/mechanism.png panel A (tread cap exploded off a copper hub) |
| Lattice enamel | Paint every strut in the one enamel ROSTER-LOOK 0.2 gives this pilot. Copper is used only on pivot pins and hubs. Do not mix bone or charcoal struts into the lattice. | tally/hero.png (every strut mulberry) |
| Weapon ring height and clearance | Put one flat horizontal band exactly at the sphere's equator. It sits fully outside the lattice with a visible air gap all round, and stays level while the lattice tilts. Its diameter is about 1.1 times the sphere's. | base/base-hero.png |
| Weapon ring band and bearing collar | Make the band worn-bone segments joined by charcoal clamp blocks. Directly under the band, show a full-diameter dark-steel bearing collar of the same radius, with copper bearing studs. The pilot's colour goes on the weapon housings only, not the band. | tally/sheet.png weapon ring and collar panel |
| Weapon placement and aim | Mount the weapon on the front arc of the ring at 12 o'clock. Twin weapons sit at about 11 and 1 o'clock, parallel. Every muzzle, emitter tip, blade edge or card slot points forward, along the pilot's facing. Never point a weapon sideways, backward, or tip to tip. | kest/sheet.png FRONT panel (both launcher mouths face the viewer) |
| Cockpit gimbal | Hang the seat inside two nested thin dark-steel rings. The outer ring pivots left-right, the inner ring pivots front-back, and copper pivot bosses show at each axis. Both rings are visible through the front gap in every hero view. No pedestal post, no single hoop. | base/mechanism.png panel C |
| Cockpit controls | Twin yokes take the hands, and a small lever or button bank sits beside the right yoke for slots 2 and 3. The ultimate is the largest control, a two-handed bar across the lap in copper. The Shift movement verb is on the pedals. Draw exactly two pedals. | tarn/sheet.png cockpit cutaway (lap bar ultimate, clamp lever, two pedals) |
| Pilot scale and visibility | The seated pilot, from ears or crest to boots, is about half the sphere's height, sitting centred at the equator (§3 gives 139 px of pilot in a 252 px ball). Leave the face fully clear through the front gap in a hero view. Leave the head and ears clear through a rear gap in a chase view. | sable/hero.png (largest pilot in the set, face unobstructed; still under half) |
| Pilot on model | Copy the pilot exactly from refs/pilots-lineup.png and the per-pilot sheet: same species read, outfit colours, cap, goggles, bandana, shell and proportions. The seat directly behind the head contrasts with the fur in value: bone for Tarn, Rivet and Sable, petrol for Tally and Kest, charcoal for the Cannon (§6). | tally/hero.png |
| Material and weathering | Use battered, workshop-built, chunky stylized 3D. Wear the enamel through to bare steel along edges and around pivot pins, put dark grease at hubs and a light dust on top faces, and keep the flat faces mostly intact. No uniform speckle over every surface (BIBLE.md:645, :705). | tarn/hero.png |
| Copper, never brass | Every warm metal is pinkish-orange copper #b77843 with brown patina. No yellow brass #d9b44a anywhere on a player machine. | base/base-hero.png |
| Hero lighting and background | Use a seamless plain warm-grey studio background and floor, with a soft warm key from the upper left, a soft contact shadow under the ball, and no scenery or props. | base/base-hero.png |
| Hero camera | Square frame. Three-quarter front view, about 30 degrees off the nose and about 20 degrees above the ring plane, so the ring shows as an open ellipse. The ball is centred and fills about 85% of the frame height. | rivet/hero.png |
| Hero heft stage | Draw every hero at heft III: the lower and side gaps paneled in the pilot's gap-panel style, the upper and front gaps open, and the hub modules at normal size. (Calls this as one stage for all six so the heroes line up.) | sable/hero.png |
| Chase camera | Landscape 3:2. Directly behind the ball, looking 17 degrees down (§3, the chase pitch of 0.30 rad). The ball fills about one fifth of the frame height (about 205 of 1024 px), sits centred horizontally and just below the middle, and rolls straight away from the camera. The pilot's back, head and ears show through the rear gaps. | tarn/chase.png (straight behind and the closest to size, at 32%) |
| Chase ground | Plain, fine, pale sandstone ground with gentle grain and no pebble field. No horizon objects and no motion-blur streaks. A soft shadow falls to the lower left, with one small dust puff at the contact point. | sable/chase.png |
| Callout sheet layout | Use three rows on 1536x1024. Top row: orthographic FRONT, orthographic SIDE (nose right), then the COCKPIT cutaway, largest, at the right. Middle row: WEAPON RING over BEARING COLLAR, HUB MODULE exploded, GAP PANEL exploded. Bottom row: heft I, III and V front views, all at the same scale. | rivet/sheet.png |
| Label typography and leaders | Panel titles in bold condensed sans, all caps. Callouts in the same sans, sentence case, charcoal, with no boxes. Each leader is a thin straight charcoal line ending in a dot placed on the named part. Every digit and word is spelled exactly. | tarn/sheet.png |
| Control label names | Label five controls, with names exactly as in design-v3/PILOTS.md section 1: '1: <weapon>', '2: <slot 2>', '3: <slot 3>', 'Q: <ultimate>' and 'Shift: <movement>' on the pedals. The weapon is slot 1 (SKILL-BAR.md:35), so never draw a separate 'Weapon trigger' label next to slot 1. | rivet/sheet.png (only sheet that puts the Shift verb, Overdrive Sprint, on the pedal) |
| Heft row | I: every gap open. III: lower and side gaps paneled. V: every gap paneled except the sight gaps that run front and rear to the pilot's head. The same hub modules and weapon appear in all three stages; only their size grows at V. | tarn/sheet.png bottom row |
| Colour discipline and glow | Emissive light appears only at the working device, in the class colour: Sable mint #8bf0d3, Rivet copper #b77843, Kest amber #e5a044, Tarn oxide #9b513a, Tally ledger cream #e6d9b8, and the Cannon ancient green #9dff3c as dashed seams (class_def.gd:13-18). No marker lamps or other lit boxes elsewhere. | tally/hero.png (the card slot is the only light) |
| Inner cockpit sphere (Andrew, 22 Oct) | The gimballed pod at the centre may be a clear or semi-opaque sphere that stays level while the lattice rolls, so the pilot reads through it. It sits inside the lattice, never replaces it as the outline, and carries no decal. | DECISIONS section 10, machine lore |
| Forbidden | No glass outer shell, bubble or dome around the ball (the lattice is the ball's outline), no hamster ball, no hanging hooks or chains, no logos or watermarks, and no text outside callout sheets. | all 20 pass |

**Read at game size.** The audit made downscaled copies with each ball at 150 px and 250 px tall, plus a 150 px greyscale row for the §3 rule 10 test (scratch files, not kept). In every picture the X-scissor crossings, pivot pins, rivets and chipped speckle merge into one busy texture. Only the hub caps survive, as dark dots on the outline. AD-04 (BIBLE.md:645) therefore argues for base-hero density, wider struts and fewer crossings. Per pilot:
- Sable: the russet head, pointed ears and petrol cap survive, the strongest 'who' read in colour. So do the crown of pylon spike points and the winch drum at 3. The wrench rack becomes a grey grille. The mint emitter tips shrink to 1 to 2 px specks. In greyscale the head loses its colour pop, though the ear shape holds.
- Rivet: the twin copper stacks survive, the clearest outline break. So do the white smock between the yokes and the barrel end caps at 3 and 9. The chevron fins merge into the lattice. From behind, the goggle strap makes the earless grey head read as a helmeted figure. The mixed bone and charcoal struts read as clutter.
- Kest: the white round head with its crest survives, as do the slotted fin vanes at 2 and 10 (the V silhouette holds) and the amber-striped ring band. Lost: the triangulated lattice, the launcher tubes and the perforated panels. The head is among the smallest in the set at about 25 px.
- Tarn: the claw blades and the hooked claw arms survive; they make the boldest, bottom-heavy outline in the set. The rear pull drum survives too. The head is lost: ash-brown fur against a dark seat and an oxide lattice has almost no value contrast, and the stripes vanish.
- Tally: the big round ears survive, the best 'who' read in greyscale. So do the ledger drums at 3 and 9 as bright discs, so 'four circles on a square' holds. The dark mulberry lattice is busy, and the card magazine shrinks to a stub.
- The Cannon: the long bone barrel survives as the outline break, along with the split ports low at 5 and 7. The pilot is lost: the teal shell blends into the petrol lattice and the verdigris plates. The rear breech hub reads as a false face, the bulbous hub caps make the outline lumpy, and the green dashed seams become specks.
Across the set: at 250 px, about the mid-camera size, heads measure roughly 25 to 45 px (eyeball estimate), so only Tally clears the 45 px rule (§3 rule 2). Scaling the pilot to half the ball's height is the single biggest fix.

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

**What the player sees.** The chase camera sits 7.5 m back at rest and 10.5 m at speed (`src/movement/chase_camera.gd:224`). At 7.5 m and a 65 degree lens, the 2 m ball is about 252 px tall at 1080p and the pilot's head is about 51 px. At 10.5 m and 80 degrees the ball is 147 px and the head 29 px. The pilot is the only shape with character. The glass rim and the shared band are the same for all six. That is the Super Monkey Ball read: a creature in a clear ball.

**What the mecha changes.** The lattice outline replaces the glass rim as the "ball" read. Each pilot's machinery moves from behind the glass to the outside of the outline, on the weapon ring and on level carriers (§2, §4), where it shows. The pilot sits at half the ball's height, centred, seen through open gaps and not through glass.

The tests pin the glass too. `tests/hero_assets_test.gd:190-198` requires a radius 0.98 glass hull of more than 500 vertices, so unit HOBERMAN-BASE re-pins it (§9).

## 2. Build rules

Section 0.1 sets the layers. This section sets what each part is made of, so P-D can build one shared base and six pilot shells on it. The code already splits the ball by motion. Core rolls under the ball's rolling mesh (`hero_assets.gd:401`). Pod rides the juice node, stays upright and turns to face the heading (`hero_assets.gd:402, 468-476`). Gyro sits under Pod (`hero_assets.gd:477-480`). The mecha keeps those node names, so the loader and the tests keep their hooks. Gyro becomes the gimbal's outer ring, and its code changes from a speed spin to holding the pod level (`PILOT-CLIPS.md` section 5).

```
 side view, heading to the right            what moves how

        .---- lattice (Core) ----.           Core         tumbles with the true ball spin
      /   hub     hub     hub      \         WeaponRing   level, yaws to the aim
  ====[== weapon ring + collar ======]==>    Gyro         gimbal outer ring, holds the pod level
     |     ( gimbal rings: Gyro )     |       Pod          upright, turns to the heading
     |       [ pilot on seat ]        |                    (seat, yokes, lever bank, lap bar,
      \   pedals   gap panels (Pod)   /                     pedals, gap panels, brackets)
        '--------- ground ---------'
                                              collider: sphere, radius 1.0, never changes
```

| Part | Node | Moves | Build (starting values, Blender metres, origin at ball centre) |
| --- | --- | --- | --- |
| Struts | Core | With the lattice | Two flat bars per X, equal length, crossing at one copper pin. Bar face 0.06 m wide (§3 rule 7, `shell_base.py` default since PD-0b), pair 0.035 m thick (§0.1). About two to three X-pairs per hub-to-hub link to fit the budget (§5). Pins ride vertex colour, not geometry. |
| Hubs and tread caps | Core > Hub.00 to Hub.31 | With the lattice | Round copper hub body about 0.20 m across. A flat black rubber tread cap 0.10 m across on its outer face (0.14 before PD-0b), with the face at radius 0.985, the core limit (`shell_base.py:15`). Shallow tyre tread. The caps are what the ground touches, so the ball rolls on tyres. |
| Gaps | Core > Gap.00 to Gap.29 | With the lattice | Empties at each gap centre. They mark where panels and cosmetic parts sit in the rest pose. They carry no mesh. |
| Weapon ring | Pod > WeaponRing | Level; yaws to the aim | Band radius 1.02 to 1.10, 0.08 m tall: worn-bone segments joined by charcoal clamp blocks. Directly under it, a full-diameter dark-steel bearing collar with copper studs. The air gap between the lattice's cap faces (0.985) and the band (1.02) stays visible all round. |
| Gimbal | Pod > Gyro (outer ring) and a new inner ring | The outer ring pivots left-right, the inner front-back, counter-tilting so the pod stays level while the lattice tumbles | Two thin dark-steel rings round the seat with copper pivot bosses at each axis. Both show through the front gap. HOBERMAN-BASE sizes them from the clip envelope: they clear the pilot's kept-clip radius by 0.03 m (start) and stay inside the lattice's inner face at 0.94 m (`PILOT-CLIPS.md` section 10). |
| Seat | Pod | Upright | Seat at Z -0.30 (`BUILD-SPEC.md` neutral body). The seat back stops at Z -0.10, below the shoulder roots at Z -0.06, so the head and shoulders show from behind. Colour per §6. |
| Controls | Pod > Control.* | Upright; each throws when its skill fires (§0.4) | Twin yokes, grips at (plus or minus 0.32, 0.40, 0.05), where today's hands rest (`shell_base.py:201-203`). A lever bank beside the right yoke for slots 2 and 3. A copper two-handed lap bar for Q, the largest control. Two pedals for Shift. Node names per `PILOT-CLIPS.md` section 5. |
| Gap panels | Pod, in the heft layers | Upright | Hang from the pod just inside the lattice: outer face at radius 0.92, 0.04 m thick. §5. |
| Modules and brackets | Pod or WeaponRing | Level | Each pilot's machinery, on the carrier §4 names. |
| DecalPlate | Pod | Upright | New. A 0.36 by 0.30 m plate on the back of the seat, facing the chase camera (§7). |
| Pilot | Pod > Dome > AnimatedPilot | With the pod; plays clips | Unchanged: `fit_pilot_into` (`hero_assets.gd:516-529`). |

**Level carriers and gap brackets.** At 30 m/s the lattice turns about five times a second. A part that must hold a clock position at chase distance cannot ride a hub, because it would smear into a ring. It rides a level carrier instead: the WeaponRing, or a gap bracket. A gap bracket is a slim dark-steel arm, 0.05 m or less across, from the Pod out through one lattice gap to the module. The struts roll past the arm. At 0.05 m the arm is about 4 px at the fast camera (the method of §3). In the rest pose the module sits at its hub, as in the pictures. Check: in a 1 s roll at the mid camera, a strut crossing a bracket reads as passing through a thin arm and not as a glitch. If it reads as a glitch, thin the bracket or move the part to the ring.

**Optional extra, off by default: gimbal sway.** The gimbal lets the pod pitch up to 6 degrees back on hard acceleration and 6 degrees forward on braking, easing out over 0.25 s. Momentum then shows in the pilot's posture. Keep it only if the sight-cone check (§3, rule 3) still passes.

## 3. Silhouette rules at chase distance

**The camera.** At rest the arm is 7.5 m, rising to 10.5 m at speed (`chase_camera.gd:224`). The falling and boss profiles push it to 12 m (`chase_camera.gd:27-29`), and the shoulder view pulls it in to 4.2 m (`:11`). Pitch starts at 0.30 rad, about 17 degrees down (`:36`). The lens is 65 degrees at rest and 80 degrees fast (`:19-20`).

**On-screen sizes at 1080p** (measured as angle over vertical lens):

| Camera | Ball (2.0 m) | Seated pilot (1.1 m) | Head (0.4 m) | Strut face (0.06 m) | A 0.15 m outline break |
| --- | --- | --- | --- | --- | --- |
| Close, 3.6 m, 65 degrees | 516 px | 289 px | 106 px | 26 px | 40 px |
| Mid, 7.5 m, 65 degrees | 252 px | 139 px | 51 px | 13 px | 19 px |
| Fast, 10.5 m, 80 degrees | 147 px | 81 px | 29 px | 7 px | 11 px |
| Far, 12 m, 65 degrees | 158 px | 87 px | 32 px | 8 px | 12 px |

**Read order.** In under 0.3 s the eye must get three things, in this order:

1. The lattice outline says "ball".
2. The pilot's head shape over the seat back says "who".
3. The machinery breaking the outline, or riding the ring, says "what kit".

**Rules.** Each rule has a check.

1. **Pilot visible through the lattice.** At the mid camera, at least 50% of the pilot's silhouette pixels are unblocked by the lattice, the weapon ring, the gimbal rings and any panel, averaged over one full roll (16 evenly spaced lattice angles), at heft classes I, III and V. At least 55% of the head-and-ears region is unblocked, and the head is at least 45 px tall. Check: `tools/pilot_mask.gd` (a per-pixel raycast of the pilot against the full shell from the same eye, `pilot_mask_test.gd` keeps it honest). Re-pinned 2026-10-10 from the PD-0b strut table (`docs/decisions.tsv`): a fully expanded Hoberman lattice is about a third cover by nature, so the 75/90 floor written for an open ring cage was unreachable at any strut width from 0.10 m down to 0.05 m (neutral shell: 47.4/52.6, 51.5/57.4, 56.6/63.0, 59.5/66.4). The neutral shell at the §0.7 density now measures pilot 56.6%, head 63.0%, head 61 px, which leaves a pilot's machinery 6 to 8 points. Panels, modules and brackets still never enter the sight cone (rule 3).
2. **Head size holds.** The head stays at least 45 px tall at the mid camera, and ears, crest or carapace add at least 8 px above it. The pilot sits at half the ball's height (§0.7). Check: the same mask.
3. **Sight cone.** The sight cone is a cone from the pilot's head towards the chase eye, half-angle 35 degrees. Nothing solid on Pod may sit inside it: no panel, no module, no bracket. The weapon ring's 0.08 m band and the two thin gimbal rings may cross it, because rule 1 still counts them. Lattice struts and hub caps may cross it, because they are thin and keep moving. Chunks keep today's tuck rule (`TUCK_FROM` and `TUCK_GONE`, `hero_assets.gd:69-70`).
4. **Outline break.** The machinery breaks the lattice outline by 0.15 to 0.25 m (11 to 18 px at 10.5 m) at one or more points seen from behind, at the clock positions in §4. The break rides a level carrier, so it holds while the ball rolls. No two pilots share the same break pattern.
5. **Rear tell.** Each pilot shows one machine face to the chase camera: a drum face, exhaust mouths, a wrench rack, a pull drum.
6. **Where machinery may reach.** Modules and brackets may stand out to radius 1.25. The ring reaches 1.10, for looks only. Nothing past radius 1.0 may sit below Z -0.6, so slopes do not swallow it. Core stays inside 0.985. `CORE_LIMIT` is `shell_base.py:15`, but `shell_base.finish()` flags Core only above 1.0 (`shell_base.py:156-157`), so HOBERMAN-BASE tightens that check to `CORE_LIMIT`. Today's accretion budget already lets hardware stand out "about 1.1 m off the collider" (`src/build/accretion.gd:17-19`), so visual reach past the collider is not new.
7. **Thick enough to survive speed.** Strut faces are at least 0.06 m wide (about 6 px at 10.5 m; 0.10 m was the cage-era number, cut to 0.06 by the PD-0b strut rule on 2026-10-10 because every width from 0.10 to 0.05 missed the old rule 1 and 0.06 keeps the strut readable) and hub caps at least 0.10 m across (about 9 px). Today's 0.055 m gyro hoop is 4 px there. The §0.7 audit found crossings and pins merge into one texture at 150 px, so wider struts and fewer crossings fix the read (AD-04, `BIBLE.md:645`).
8. **No wagon-wheel strobe.** At 30 m/s the lattice turns 0.51 rad (29 degrees) per 60 Hz frame. On the icosahedral layout the nearest hubs sit 37.4 degrees apart (inference: the angle from a five-way hub to its nearest three-way hub, computed from the layout), so a regular pattern can seem to creep backwards. Break the symmetry. Vary each cap's tread rotation and wear the paint differently on each chain. Put a chalk balance mark, a small pale dot like the one on a tyre, on one tread cap so the eye can follow one full turn. Check: record a 1 s strip at 30 m/s and look for reversed motion of the mark.
9. **Value-opposite seat.** The seat directly around the pilot sits at least 25 L* away from the pilot's main fur or feather value (§6).
10. **Greyscale identity.** Six mid-camera frames, cut to 96 px wide greyscale thumbnails and shuffled. A blind reader names all six pilots. This is the measurable stand-in for the 0.3 s glance. Andrew's sitting can add a human 0.3 s flash test as an optional extra.

## 4. Per-pilot machinery and silhouette

Clock positions are as seen from the chase camera, with 12 at the top. "Glow" is the `class_accent` slot, which emits only at the working device (`VISUAL-LANGUAGE.md:66, 389`). The pictures for each row are `concepts/codex/<pilot>/{hero,chase,sheet}.png`. The carrier is where the part rides in play (§2): the **ring** (level, yaws to aim), a **bracket** (a gap bracket from the Pod, level, holds its clock position), the **pod** (upright), or the **lattice** (rolls with the ball).

| Pilot (class id) | Class colour | Head read from behind | Machinery and carrier (form mirrors function) | Outline break | Rear tell | Glow at | Gap-panel motif |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Sable (`pylon_engineer`) | Field mint `#8bf0d3` (`class_def.gd:13`) | Two tall pointed ears, petrol cap, bushy bone-tipped tail over the seat lip | Coil mast, copper winding on a bare-metal core, for the detonation gauge (bracket). Winch spool with its stake hatch, for the grapple (bracket). Four-wrench rack (pod, seat back). Twin arc emitter (ring). | 11 o'clock: the mast rises 0.20 m past the lattice (0.25 m at class V). 3 o'clock: the spool bulges 0.12 m. Nothing at 1 o'clock. Asymmetric. | Wrench rack and coil base on the seat back | Coil tip | Small rounded plates, felt-lined and rubber-bushed; Sable's shell "rattles least" (`VISUAL-LANGUAGE.md:307`) |
| Rivet (`runner_gunner`) | Copper `#b77843` (`class_def.gd:14`) | Broad round low head, no ear points, goggle strap | Stepped drill nose with the cutting lens at its tip, hung under the ring's front arc so the lens and the twin copper laser barrels share the aim (ring). Copper fins folded flat in the front lower gaps, raked into a forward V (lattice, under 0.05 m proud). Twin exhaust stacks at the upper rear (bracket). | 11:30 and 12:30: twin stacks stand 0.18 m tall. The fin V shows from the side and front only, never at 4 and 8 o'clock, which is Tarn's. | Exhaust mouths, lit copper during the sprint, the haul and the set piece | Lens tip and exhaust mouths | Raked chevron plates |
| Kest (`demolitions_caster`) | Safety amber `#e5a044` (`class_def.gd:15`) | One narrow swept crest over a bone head | Slotted fin vents that open for the glide and vent the smoke blink (pod, hinged at the side gaps). A pair of short mortar tubes in recoil cradles at 11 and 1 o'clock, and satchels in horizontal bands only (`VISUAL-LANGUAGE.md:331`), the bands counting volley targets (ring). | 2 and 10 o'clock: the vents sweep up and back, 0.10 m past the lattice folded and 0.25 m open. A V. | Vent louvres and mortar mouth | Fuse tips | Light perforated panels |
| Tarn (`tarn`) | Iron oxide `#9b513a` (`class_def.gd:16`) | Small round ears, wide cheek wedges, thick striped tail | Two hooked claw arms, low on the side gaps, with toothed jaws on hinges (bracket). Two big curved claw blades (ring). A rope pull drum low at the rear (pod). | 4 and 8 o'clock: the claw tips sit 0.15 m past the lattice at class I, low and forward, and reach further with class (`pilots/tarn.md` section 5). Wide shoulders. | Pull drum face, low centre | Claw-tooth edges | Thick slabs scored with claw marks |
| Tally (`tally`) | Ledger cream `#e6d9b8` (`class_def.gd:17`) | Two big round disc ears | Ledger drums, today's flywheels wound with punched card tape, whose windows show pressure (ring, at 3 and 9). Drum magazine for the cards (ring). Reader carriage with three tabbed bays, her slot 2 and 3 bank (pod, beside the right yoke, in front of the lap). Stamp sole at the bottom (lattice, a look only; the stamp effect plays at the ground contact). | 3 and 9 o'clock: round drums stand 0.12 m past the lattice, level. They echo the ears. | Drum faces | Reader slot | Square stamped plates with rows of punched holes |
| The Cannon (`remembered_cannon`), the showcase | Uranium-glass green `#9dff3c` (`class_def.gd:18`, `palette.gd:12-15`) | Earless low oval carapace | One cast barrel with four raised family bands, on the ring's front arc (ring). Two twin-bore split ports at the low side gaps (bracket). Sector shutter on the barrel (ring). Rush ring at the bottom (bracket). | 5 and 7 o'clock: the split ports stand 0.12 m out, low. With the aim off the camera's line, the long barrel breaks the outline at the equator. | Split-port blocks and the rush ring, low. With the aim straight ahead the ball hides the barrel (`pilots/cannon.md` section 5). | Four bands, muzzle ring and seams, with the dashed pattern cue | Seamless verdigris carapace plates, the showcase |

**Nodes kept.** The names exist in code today and stay, so kit code and tests keep their hooks.

- Sable: `RopeExit` (`tools/blender/world_one/shell_sable.py:179`). Add `CoilMast`, the coil mast on its gap bracket.
- Rivet: none today. Add `DrillTip`, an empty at the lens facing +Y, plus `Drill` and `Exhaust.L/R`.
- Kest: `VaneL` and `VaneR` (`world_one/shell_kest.py:228`; opened by `hero_assets.gd:481-486`).
- Tarn: `ClawPivot.R/L`, `ClawTip.R/L`, `PullDrum`, `PullExit`, `RendContact` (`tools/blender/shell_tarn.py:120-130`).
- Tally: `Flywheel.R/L`, `FlywheelAxis.R/L`, `ReaderCarriage`, `CardBay.0/1/2`, `ReaderExit` (moves to WeaponRing at 12 o'clock), `ReturnExit`, `StampContact` (`tools/blender/shell_tally.py:134-164`).
- Cannon: `MainBarrel`, `LaneMuzzle`, `BarrelPivot`, `SplitExit.R/L`, `SectorShutter`, `RushContact` (`tools/blender/world_one/shell_cannon.py:20-25, 109, 125`).

**Pilot looks come from the six-pilot lineup prompt** (`game-completion-plan-75f776/artifacts/local/alpha/push/w1/D6/out/PROMPTS.md:380-385`) and the recipes. Rivet's fur is `common.mix("charcoal", "bone", 0.32)` (`tools/blender/world_one/shell_rivet.py:140`). Kest's crest and beak are at `world_one/shell_kest.py:179-180`. Tarn's ash is `ASH = "5e5a54"` (`tools/blender/pilot_tarn.py:24`).

**The pictures, not a board.** The cage boards had a matrix of six cage ideas per pilot and a pick rule. Both are retired. Each pilot's look is its three cleaned pictures. The sheet's panels (cockpit cutaway, weapon ring over collar, hub module exploded, gap panel exploded, heft I, III and V) are the build reference. Section 0.7 sets what must match across all six. Where a picture and a rule or number in this sheet disagree, this sheet wins, and the cleanup round redraws the picture.

## 5. Heft stages and gap panels

Durability is scrap armour (design principle 19), so panels say how much armour you carry. Heft classes are set at heft 1.0, 1.5, 2.2, 3.2 and 4.6 (`src/core/run_state.gd:21`). Panels follow the class signals `heft_class_changed` and `heft_class_dropped` (`src/core/game_events.gd:36-37`).

A **detail shell** is an extra GLB layer drawn on top of a base asset, with its own budget class (`assets/asset_budgets.json:75`, `docs/decisions.tsv:363`). A layer GLB has the same top-level Core and Pod split as the base (`CUSTOMIZE.md` section 6).

| Class | Stage | What it adds | Mounted on | File | Budget |
| --- | --- | --- | --- | --- | --- |
| I | Open: a rider | Base mecha only: lattice, weapon ring, gimballed pod, hub modules in their light form | Core, Pod (with Gyro and WeaponRing) | `world_one/shell_<id>.glb` | `shell` class cap: 11,000 tris, 11,600 verts, 10 draws (`asset_budgets.json:39`). Target: 6,600 tris or fewer, 10 draws or fewer. The budget check below says why the target is at risk. |
| II | Open, first panels | Six panels in the lower gaps, all below Z -0.35 | Pod | `shell_<id>_c2.glb` | `detail` class (1,500 tris, 3,000 verts, 1 draw); target 900 tris |
| III | Paneled | Panels in the side gaps. Thicker tread caps on the hubs, never past radius 0.985 | Pod (panels), Core (caps) | `shell_<id>_c3.glb` | `detail`; target 900 tris. Two parts cost 2 draws, so the registry row records an exception, as Kest's shell does for draws (`assets/registry.json:2868-2876`). |
| IV | Heavy machine | Panels in most gaps, with only the sight gaps open; collars round the module bases | Pod | `shell_<id>_c4.glb` | `detail`; up to 1,500 tris |
| V | Heavy machine, full | Every gap paneled except the sight gaps; the modules' heavy parts (Sable's thicker mast, Rivet's big drill cone, Kest's wide vents, Tarn's long claws, Tally's big drums, the Cannon's enlarged ports and rush ring) | Pod | `shell_<id>_c5.glb` | `detail`; up to 1,500 tris |

**Totals at class V.** Pilot 4,600 tris (`asset_budgets.json:45`), plus the base at its 6,600 target, plus panels 4,800, makes 16,000 tris. That matches today's no-growth pod ceiling (`world_one/shell_sable.py:24-28`). Draws: pilot 5, base 7 by slot count (five slots, and the Cannon adds two ancient slots; 10 at the cap), layers 4 plus the class III Core part. That is 17 by slot count and 20 at the caps.

**Budget check (inference, not measured).** The lattice is most of the shell. It has 32 hubs and 60 hub-to-hub links. The arithmetic below assumes 12-tri flat bars, pins as vertex colour, about 56 tris per hub with its cap, and 2,900 tris for the ring, gimbal, pod, controls and modules.

| X-pairs per link | Bars | Hubs | Rest | Base total |
| --- | --- | --- | --- | --- |
| 2 | 2,880 | 1,800 | 2,900 | about 7,600 |
| 3 | 4,320 | 1,800 | 2,900 | about 9,000 |
| 5 (the §0.7 density) | 7,200 | 1,800 | 2,900 | about 11,900, past the cap |

Every row is over the 6,600 target, and the §0.7 density is over the 11,000 cap. HOBERMAN-BASE reports the pairs per link that fit. The cut order is: first one X-pair per link, then cheaper hubs and bars (8-tri bars, 5-sided hub drums), then raise the base target to about 9,000. That last step takes class V to about 18,400 tris, over the old 16,000 ceiling. The registry checks class caps and has no pod class (`assets/asset_budgets.json`), so the gate is the frame-time ratio in §8. It is a coordinator call.

**One surface per plate shell.** Each heft layer (the detail shell that holds a class's panels) is one mesh on one slot per part, so it costs one draw per part. Bolt heads and rubbed edges ride vertex colour. Panels use `paint`, so the equipped paint carries onto them. The Cannon's panels use `ancient_enamel`.

**Where panels sit.** Panels hang from the upright Pod, with their outer face at radius 0.92, just inside the lattice's inner face at 0.94 (§2). In the rest pose each paneled gap shows its panel. In a roll the struts pass in front of the panels. Class II to IV panels stay below the sight cone. The sight gaps are the arcs on the cone from the chase eye to the pilot's head, and from the front camera to the face. No panel ever fills one, and nothing enters the weapon ring's sweep.

**Class up.** The new layer's panels slam in over 0.18 s from 0.10 m out, easing out with a 1.2 overshoot. That overshoot is reserved for player-owned success (`VISUAL-LANGUAGE.md` §8). It lands on the heft dial's clunk (§7). It is one bold animation for the event and has no light.

**Class down sheds panels.** The lost layer's panels fling outward over 0.45 s, matching `FLING_SECONDS` (`accretion.gd:28`), then hide. They are never freed during a run. Armour mode holds a class until heft falls 5% of the interval below the threshold (`run_state.gd:33, 249-265`), so panels never flicker.

**The outline barely grows.** Panels sit inside the lattice, so the silhouette gains weight and not width. Width comes from the modules' heavy forms at class V.

**Accretion chunks join the lattice.** Chunks today sit on an invisible sphere and grow 7% per class (`accretion.gd:27, 66-67`). Over an open lattice, a chunk floating in a gap looks wrong. Two changes, both on the veto list:

- Chunk slots snap to the nearest hub or strut.
- `SHELL_PER_CLASS` goes to 0.0 for Hoberman shells, because the panels now carry the growth read.

The 36-chunk cap (`accretion.gd:21`) and the tuck rule stay.

**Measures.**

- Blind pairs at the far camera, class I against class V: the reader picks the heavier one, 3 of 3 for each pilot.
- At class V, rule 1's pilot visibility still holds.

## 6. Materials and colour slots

The slots are the shared table in `hero_assets.gd:84-99`. Materials come from a cache keyed by slot and tint (`hero_assets.gd:175-177, 249`), so every pilot's lattice shares one `paint` material per tint.

| Slot | On the mecha | Colour | Emits | Paint cosmetic tints it |
| --- | --- | --- | --- | --- |
| `paint` | Lattice struts in the pilot's one enamel, ring band segments, module housings, every gap-panel layer | Vertex colours: today petrol, oxide and bone (`common.PAINT_SET`); see the enamel note below | No | Yes (`hero_assets.gd:233-235`) |
| `bare_metal` | Control hardware, yoke arms, lever shafts, pivot axles, rubbed bright where hands touch | Sand lightened 25% (`hero_assets.gd:86`) | No | No |
| `rubber` | Hub tread caps, ring clamp blocks, gimbal rings, bearing collar, seat padding, pedals, bumpers | Charcoal | No | No |
| `class_accent` | The working device only (§4) | The class row's colour (`hero_assets.gd:88`) | 0.5 | No |
| `field` | Not drawn on the mecha (a call) | | | |
| `pilot` | The pilot | Vertex colours | No | No |
| `copper` (proposed) | Hub bodies, pivot pins, windings, coil wraps, bearing studs, lap bar, straps | `Palette.COPPER`, metallic 0.6, roughness 0.4 | No | No |
| `ancient_enamel` | The Cannon's cast parts and panels | Vertex colours under the enamel cap | No | No |
| `ancient_light` | The Cannon's seams, with the dashed pattern | `Palette.ANCIENT` | 2.4 | No |
| `glass` | Retired on Hoberman shells | | | |
| `requisition_tag`, `fleet_paint` | Never on a player asset | | | |

**Copper, never brass.** Brass is the Furnace Fleet's requisition colour (`VISUAL-LANGUAGE.md:48`, `palette.gd:21`). A player asset carries no `requisition_tag` slot and no brass-hued vertex colour. Paint rows already refuse tints near BRASS (`src/core/cosmetics.gd:19-20`). Copper on every mech's coils is the standing rule (`VISUAL-LANGUAGE.md:44`). It does not clash with Rivet's class colour, because class colour governs emitted light, not materials (`VISUAL-LANGUAGE.md:66`).

**Why a `copper` slot.** Today copper rides vertex colour on `paint` or `pilot`. An equipped paint multiplies every `paint` vertex colour, so a Cobalt paint would turn the copper hubs and windings blue. A slot keeps copper copper. The HOBERMAN-BASE unit adds it. The hub bodies and pins are the most copper on the ball, so they need it most.

**Dark steel.** The gimbal rings and the bearing collar are dark steel, and no dark-metal slot exists, so they use `rubber`'s charcoal. Separable extra: a `dark_steel` slot, if the metal read is lost at game size.

**The intake coil.** Today's three mint field rings under the seat are not drawn on the mecha (`shell_base.py:194-196`). Section 0.7 allows light only at the working device, and the concept pictures show no coil. Separable extra: a mint coil on the bottom hub, if Andrew misses the magnet read.

**Enamel colours against the paint set.** §0.2 gives Rivet charcoal steel and Tally mulberry. Today's paint set is petrol, oxide and bone (`common.PAINT_SET`, `tools/blender/common.py:61`), and `hero_assets_test.gd:172, :205` fails any other paint vertex colour. HOBERMAN-BASE re-pins the test to add the two enamels, with a dated header, and samples the mulberry from Tally's picture.

**Value-opposite seat.** Lightness (L*) values computed from the hex colours:

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

Tarn and Rivet are within 4 L* of petrol, so a petrol seat would swallow their heads.

| Pilot | Seat (the gimbal rings stay dark steel on `rubber`, §0.7) |
| --- | --- |
| Tarn, Rivet | Bone, or rubbed bare metal |
| Tally, Kest | Petrol |
| Sable | Bone |
| Cannon | Charcoal (16.4) |

The lattice enamels are not in this table. The pictures show two weak pairs: Tarn's ash fur against an oxide lattice, and the Cannon's teal shell against a petrol lattice (§0.7 audit). P-D measures each enamel from the approved picture, and rule 10's greyscale test is the check.

**Tarn's colour clash.** Tarn's class colour is iron oxide, which also means "harm to you" and Fleet paint (`VISUAL-LANGUAGE.md` §2). §0.2 gives Tarn an oxide lattice anyway, and PD-TARN keeps it. The clash is softened three ways. Oxide goes on the lattice struts only. The gap panels and seat are bone and petrol. The claw-tooth glow and the stripes carry the class read. This is open for Andrew (`pilots/tarn.md` section 11, item 8).

**The ancient colour.** The ancients' light is uranium-glass green `#9dff3c` (`palette.gd:12-15`; Andrew's choice, `docs/decisions.tsv:350`). It reads as BRASS to deuteranopes and as mint under tritanopia, so every seam also carries a dashed pattern. The A3 brief said Cherenkov blue. The register is newer and is Andrew's own call, so this sheet follows it (see Conflicts).

## 7. Cosmetics on the mecha

- **Paint** (rows at `cosmetics.gd:24-41`) tints the `paint` slot: lattice enamel, ring band, module housings and every gap-panel layer. Copper hub bodies stay copper. A class-up keeps your colour. The Cannon's panels are `ancient_enamel` and keep their cast look. Its paint, Old Verdigris, tints its lattice.
- **Decal** (rows at `cosmetics.gd:48-55`) moves off the Core. Today it projects onto Core surfaces named `glass` or `paint` (`cosmetic_presentation.gd:109-112`). The Core now tumbles, has no glass and carries lattice struts on `paint`, so a decal there would smear across the bars. The decal goes on the seat-back `DecalPlate`, which faces the chase camera. The projection uses the plate's local frame, and the 0.65 m tile default (`cosmetic_presentation.gd:87`) shrinks to the plate's 0.36 m. B5 owns this code change.
- **Shell variant** (the slot kind settled in the grill) swaps the mecha's structure: pairs per link, strut style, hub-cap tread and panel shape. It never moves the machinery, its brackets, its sockets or the sight cone. Each pilot's earned variant is named in `CUSTOMIZE.md` section 8. A variant ships a base GLB, and a layer it lacks borrows the default panels (`CUSTOMIZE.md` section 6). The heft layers and the variant share one loader path, B5's shell lookup by variant and heft layer (plan, wave P-B).
- **Trail and companion paint** are unchanged.

## 8. Performance notes

- **No light on the mecha.** No OmniLight3D, SpotLight3D or other light node rides the shell, a panel or the pilot. Glow is emission on cached slot materials (`hero_assets.gd:88-95`). The wave 11 Vulkan segfault was an OmniLight3D on each cracked cache, freed with the cache at stage clear. The next boss entry then hit the engine's light-unpair bug (`design-v3/HANDOFF.md:11`). The wave 9 per-cage light was the same class of bug.
- **No per-instance `material_override` on mecha or panel nodes.** Slot materials come from the cache and attach as surface overrides through `paint()` (`hero_assets.gd:259-278`). `air_cue` builds and frees a `material_override` for each ring it makes (`hero_assets.gd:447-463`). Panels must not copy that pattern. A part that shows a live fact, such as Sable's wrench rack or Tally's drum windows, sets a per-instance shader parameter on the cached material instead.
- **Hide, never free, during a run.** Heft layers load once when the shell fits and toggle visibility. Only `_fit`'s class swap frees them (`hero_assets.gd:369-374`).
- **Heft layers are state, not distance detail.** They get no visibility range, and they cast shadows, because the player's shadow is a landing read. The scenery detail-shell rule turns shadows off and fades by range (`docs/decisions.tsv:378`). That rule is for level-of-detail chains, not for the player.
- **Budget.** About 16,000 tris and 17 draws (20 at the caps) for the whole ball at class V at the 6,600 base target (§5). That is one object, inside principle 16's gate of 7 ms GPU and 10 ms CPU at p99 on the dev box (`ALPHA-PLAN.md:152`). Check the ratio against the pre-wave base on card 1, under the 1.3x rule. If the base target rises to 9,000, this check is the gate.
- **New per-frame code is small.** The lattice tumble costs nothing new, because Core already rolls under the rolling mesh (`hero_assets.gd:401`). The additions are the WeaponRing yaw and the gimbal counter-tilt in `_steer_pod` (`hero_assets.gd:468-486`).
- **Collider unchanged.** It stays a sphere of radius 1.0. Growth shows in panels and machinery.

## 9. Recipe route for wave P-D

**Steps.**

1. **Concept source.** The cleaned Astra set is the source: `concepts/codex/base/` and `concepts/codex/<pilot>/{hero,chase,sheet}.png`. Andrew approved it as one set, conditional on the coherence re-audit (`docs/decisions.tsv:422`), so a pilot unit takes its pictures without a per-pilot click once the re-audit passes. The cage boards (`boards/pilots-cage.json`) and the FLUX probe (`boards/hoberman-probe.json`) are retired. A unit whose pictures fail the re-audit returns BLOCKED.
2. **HOBERMAN-BASE first, one unit.** It is PD-0 in `artifacts/local/alpha/push/w13/design/P-UNITS.md` section 3. It adds the shared Blender helper and the Godot fit (block below). The six pilot units wait for it.
3. **Six pilot units in parallel.** Each pilot gets a shell recipe on the shared helper, the machinery from its pictures, and the four heft-layer detail shells. The routes:
   - **Tracked recipe.** The shipped GLBs come from the recipe in `tools/blender/` on `shell_base.hoberman()`.
   - **Forge shell brief.** `tools/asset-forge` may draft static shell parts from the approved picture with `tools/asset-forge/kinds/model/brief.shell.md`: +Y forward, centre pivot, `Core`, `Pod` and `Dome` nodes. The forge shell profile caps every vertex at 0.985 m and the longest edge at 2.0 m (`tools/asset-forge/packs/core-loop.toml:60, :162`). So a draft can cover the lattice, the pod, the controls and the gap panels. It cannot pass the weapon ring (radius 1.02 to 1.10) or a module that stands past the lattice, so the tracked recipe builds those. The brief still describes the glass ball: a glass `Core`, a `glass` slot and a `Gyro` spun from speed (`brief.shell.md:3, :11, :15, :21`). A Hoberman draft ignores that: its Core is the lattice, it has no `glass` slot, and it swaps `glass` for `copper`. A forge draft is ported into the tracked recipe, never shipped from the forge folder.
   - **Pilot bodies stay on the rig route.** The forge refuses `--category pilot` (`core-loop.toml:166`). Rivet, Sable and Kest bodies come from `rig_pilot.py` (`tools/blender/PILOT-RIG.md:3`, commands at `:48-55`). Tarn's, Tally's and the Cannon's come from `pilot_tarn.py`, `pilot_tally.py` and `pilot_cannon.py` (`hero_assets.gd:33-36`). A body is rebuilt only when the approved picture changes the pose, such as a Kest perch. It stays within the `pilot` class: 4,600 tris, 3,100 verts, 5 draws.
4. **Registry fragments and fold.** Each unit writes its fragment under `assets/registry.d/` (`tools/fold_registry.py:70`). The forge writes its own fragments since merge 88a4d17 (`docs/decisions.tsv:421`). Today's shell rows sit in `assets/registry.json` itself (`:2856-2910`, keyed by path), so a unit edits its row in place and adds the layers in a new fragment. `assets/registry.json` is generated. The coordinator folds with `tools/fold_registry.py` and runs `node scripts/fold-registry.test.mjs`.
5. **Loader.** `SHELLS` stays keyed by class id (`hero_assets.gd:55-62`). B5 adds the layer and variant lookup, which reads `shell_<id>[_<variant>]_c2..c5.glb` and mounts each layer under HeroCore or HeroPod (`CUSTOMIZE.md` section 6). It warns once and skips a missing layer.
6. **Look subjects.** HOBERMAN-BASE adds three rows per pilot to `tools/look_subjects.gd`: `cge_<pilot>_c1`, `_c3` and `_c5`, kind `actor`. The `cge_` prefix is kept as an id so the P-D briefs and the look harness agree. Eyes sit behind the heading at:
   - close: (0, 1.06, 3.44)
   - mid: (0, 2.22, 7.17)
   - far: (0, 3.55, 11.46)

   All three target (0, 0.2, 0) with a 65 degree lens. These match the chase pitch of 0.30 rad at 3.6, 7.5 and 12 m. Blind pairs: the old glass shell against the new mecha at each distance, and class I against class V at far. The reader records picks before opening `key.json`.

The full unit briefs, with GOAL, VERIFY counts, TIMEBOX and merge order, are `P-UNITS.md` section 3. This section holds the design contract each unit must meet. Where the two differ on a look or budget number, this sheet governs.

**Shared VERIFY for every P-D unit.**

- `npm run asset:inspect -- <glb> --max-tris <class cap>` with status pass, run on the shell and each layer.
- The `CORE_RADIUS` line from `shell_base.finish()`, at `CORE_LIMIT` once HOBERMAN-BASE lands.
- The registry fold test.
- `tools/coordinator/compile_check.sh` and `node scripts/sketch-lint.mjs --sketch core-loop`.
- The unit's named tests, red then green. Re-pins carry dated headers.
- A fence check with `git diff --name-status` against SCOPE.

### Unit HOBERMAN-BASE (runs first)

- **SCOPE:**
  - `tools/blender/shell_base.py`: add `hoberman(...)` beside `spherical()`, which stays for the fallback until all six move, and `truss_cage()`, whose 12 icosahedral vertices seed the hub layout. It builds the Core lattice with `Hub.00` to `Hub.31` and `Gap.00` to `Gap.29`, the Gyro outer ring and inner gimbal ring, the Pod seat, controls and `DecalPlate`, and `WeaponRing`. `finish()` gets the Core check at `CORE_LIMIT` and the sight-cone check.
  - `tools/blender/world_one/shell_neutral.py`, `assets/models/world_one/shell_neutral.glb` and its registry fragment with `ships: false`: the neutral test shell.
  - `src/presentation/hero_assets.gd`: the `copper` row in `SLOTS`, and in `_steer_pod` the WeaponRing yaw to the aim and the gimbal counter-tilt.
  - `src/build/accretion.gd`: chunk slot snap and `SHELL_PER_CLASS` for Hoberman shells.
  - `tools/look_subjects.gd`: 18 rows.
  - `tests/hero_assets_test.gd:180-204`: re-pin the glass-hull check (`:190-198`) to a lattice check (Core outer radius 0.95 to 0.985, no `glass` slot; Pod > Gyro and Pod > Dome > Pilot kept), and widen the paint-colour check (`:172, :205`) for §6's enamels.
  - A new `tests/cage_contract_test.gd`. The name stays so `P-UNITS.md` and `CUSTOMIZE.md` keep their references.
- **ACCEPTANCE:**
  - The neutral shell built by `hoberman()` passes `asset:inspect` under `shell` (11,000 tris, 10 draws). The REPORT gives its tri count at 2, 3 and the §0.7 density of X-pairs per link, and the pairs per link that fit the 6,600 target (§5 budget check).
  - 32 hubs (12 five-way, 20 three-way) as `Hub.00` to `Hub.31`, 30 `Gap.NN` empties facing outward, strut pairs 0.035 m, Core radius 0.985 or less.
  - `WeaponRing` under Pod at radius 1.02 to 1.10 and 0.08 m tall. Headless, it reaches a new aim within 0.2 s (start) and stays level while Core tumbles.
  - No Pod vertex sits past radius 1.0 below Z -0.6. The sight cone is empty of solid Pod geometry.
  - Both gimbal rings clear each pilot's kept-clip radius by 0.03 m (start) and stay inside the lattice's inner face.
  - At the smallest fold scale (0.92 squash; 0.85 Cannon), the lattice inner face (0.94 x scale) stays outside both gimbal rings and the roster envelope in `clips/envelope.json`, else the REPORT gives the lowest scale that clears.
  - `cage_contract_test` fails on a shell with a `glass` or `requisition_tag` slot, a light node, or a `material_override`, and passes the neutral shell.
  - Chunks seat within 0.05 m of a hub or strut in a headless build at 36 chunks.
  - The `copper` slot is `Palette.COPPER` (`palette.gd:7`), metallic 0.6, roughness 0.4, and paint never tints it.
  - `hero_assets_test` is green after the dated re-pin. The look rows boot with a dead-frame pass.

### Unit PD-SABLE

- **SCOPE:** `tools/blender/world_one/shell_sable.py` (rewritten on `sb.hoberman`), a new `tools/blender/world_one/shell_sable_plates.py`, `assets/models/world_one/shell_sable.glb`, `shell_sable_c2.glb` to `_c5.glb` and the earned variant's base (`shell_sable_felt.glb`), the registry row and a layers fragment, and a dated re-pin of `tests/world_one_shell_sable_test.gd`. Forge draft: the gap panels and the rack. Body: the existing pilot GLB, from `rig_pilot.py -- sable` (`PILOT-RIG.md:48`), unchanged unless the picture changes the pose.
- **ACCEPTANCE:**
  - Built from Sable's cleaned concept set; the recipe header names the pictures.
  - The coil mast, node `CoilMast`, rides a gap bracket at 11 o'clock and stands 0.20 m past the lattice (0.25 m at class V, one thicker mast). The spool bulges 0.12 m at 3 o'clock. Nothing breaks the outline at 1 o'clock.
  - `RopeExit` sits at the spool's rope mouth.
  - The coil tip is the only `class_accent` surface. The rack's lit count rides a shader parameter, not a `material_override`.
  - The wrench rack shows in the mid frame. The twin arc emitter rides `WeaponRing`.
  - Panels are rounded and bushed. The seat is bone.
  - Rules 1 to 9 of §3 pass. Budgets per §5.

### Unit PD-RIVET

- **SCOPE:** `tools/blender/world_one/shell_rivet.py`, `world_one/shell_rivet_plates.py`, `assets/models/world_one/shell_rivet.glb`, `_c2` to `_c5` and the earned variant's base (`shell_rivet_calibrated.glb`), the registry row and a layers fragment, and a re-pin of `tests/world_one_shell_rivet_test.gd`. Forge draft: the chevron panels. Body: `rig_pilot` route, unchanged unless the picture changes the pose.
- **ACCEPTANCE:**
  - Built from Rivet's cleaned concept set.
  - A new `DrillTip` empty at the lens faces +Y and lines up with the laser's fire direction. `Drill`, `Exhaust.L` and `Exhaust.R` exist.
  - The drill nose fills the front gap: 3 steps and a 0.12 m lens at class I, 5 steps and 0.20 m at class V.
  - Twin stacks stand 0.18 m on gap brackets at 11:30 and 12:30 and show above the seat back in the mid frame.
  - The fins fold flat, under 0.05 m proud, as a forward V, and never break the outline at 4 or 8 o'clock.
  - Lens and exhaust mouths are the only `class_accent`. The seat is bone, because the fur is L* 38.7.
  - Rules 1 to 9 pass. Budgets per §5.

### Unit PD-KEST

- **SCOPE:** `tools/blender/world_one/shell_kest.py`, `world_one/shell_kest_plates.py`, `assets/models/world_one/shell_kest.glb`, `_c2` to `_c5` and the earned variant's base (`shell_kest_roost.glb`), the registry row and a layers fragment, and a re-pin of `tests/world_one_shell_kest_test.gd`. Forge draft: the perforated panels. Body: `rig_pilot` route (`PILOT-RIG.md:48-55`), only if Andrew approves a perch.
- **ACCEPTANCE:**
  - Built from Kest's cleaned concept set.
  - `VaneL` and `VaneR` hinge under Pod at the side gaps. They open to 90 degrees under `hero_assets.gd:481-486` without entering the sight cone or touching the weapon ring.
  - The vents stand 0.10 m past the lattice folded and 0.25 m open.
  - The two mortar tubes sit in recoil cradles on the ring, at 11 and 1 o'clock. Satchel bands are horizontal only.
  - If the perch is approved, the pilot body follows the `rig_pilot` route and passes the `pilot` class.
  - Panels are perforated. The seat is petrol.
  - The registry exception for Kest's 16 draws (`assets/registry.json:2868-2876`) is removed if the shell comes in at 10 draws or fewer.
  - Rules 1 to 9 pass.

### Unit PD-TARN

- **SCOPE:** `tools/blender/shell_tarn.py`, a new `tools/blender/shell_tarn_plates.py`, `assets/models/world_one/shell_tarn.glb`, `_c2` to `_c5` and the earned variant's base (`shell_tarn_redjaw_teeth.glb`), the registry fragment, and re-pins of `tests/tarn_look_test.gd` and `tests/pilot_tarn_asset_test.gd` where they pin shell geometry. Forge draft: the claw-scored slabs. Body: `pilot_tarn.py`, which imports `rig_pilot` (`pilot_tarn.py:22`), unchanged unless the picture changes the pose.
- **ACCEPTANCE:**
  - Built from Tarn's cleaned concept set.
  - `ClawPivot.R/L`, `ClawTip.R/L`, `PullDrum`, `PullExit` and `RendContact` are kept, and the claw jaws rotate as single-material meshes.
  - At rest the claw tips sit 0.15 m past the lattice at 4 and 8 o'clock, on gap brackets, above Z -0.6.
  - The blades ride `WeaponRing`. The pull drum sits low at the rear.
  - Every strut is in the one oxide enamel. Bone and petrol appear on the panels and seat only.
  - Claw-tooth edges are the only `class_accent`. The seat is bone.
  - Panels are slabs with claw scores.
  - Rules 1 to 9 pass.

### Unit PD-TALLY

- **SCOPE:** `tools/blender/shell_tally.py`, a new `tools/blender/shell_tally_plates.py`, `assets/models/world_one/shell_tally.glb`, `_c2` to `_c5` and the earned variant's base (`shell_tally_abacus.glb`), the registry fragment, and re-pins of `tests/tally_look_test.gd` and `tests/pilot_tally_asset_test.gd` where they pin shell geometry. Forge draft: the stamped plates. Body: `pilot_tally.py`, unchanged unless the picture changes the pose.
- **ACCEPTANCE:**
  - Built from Tally's cleaned concept set.
  - `Flywheel.R/L` become the ledger drums with the same names, riding the ring at 3 and 9 o'clock, and `FlywheelAxis.R/L` are kept.
  - `ReaderCarriage`, `CardBay.0/1/2`, `ReaderExit` (moves to WeaponRing at 12 o'clock), `ReturnExit` and `StampContact` are kept.
  - The drums stand 0.12 m past the lattice and stay level.
  - The reader slot is the only `class_accent`.
  - The seat is petrol, because the cream is L* 95.
  - `tally_look_test`'s cream contract stays green.
  - Rules 1 to 9 pass.

### Unit PD-CANNON (showcase)

- **SCOPE:** `tools/blender/world_one/shell_cannon.py` (including the stale ancient blue at `:66`, which becomes `9dff3c`, `docs/decisions.tsv:419`), `world_one/shell_cannon_plates.py`, `assets/models/world_one/shell_cannon.glb`, `_c2` to `_c5` and the earned variant's base (`shell_cannon_choir.glb`), the registry fragment, and re-pins of `tests/cannon_look_test.gd` and `tests/pilot_cannon_asset_test.gd` where they pin shell geometry. Forge draft: the carapace panels. Body: `pilot_cannon.py`, which also writes the shell (`pilot_cannon.py:474-476`), so compare the SHA-256 of `shell_cannon.glb` before and after any run.
- **ACCEPTANCE:**
  - Built from the Cannon's cleaned concept set.
  - `MainBarrel`, `LaneMuzzle`, `BarrelPivot`, `SplitExit.R/L`, `SectorShutter` and `RushContact` are kept. `LaneMuzzle` lines up with Combat's lane direction (`BUILD-SPEC.md`, cannon unit).
  - The barrel rides the ring's front arc with four family bands. The split ports stand 0.12 m out at 5 and 7 o'clock. The rush ring sits at the bottom.
  - Ancient parts are cast and seamless, with no bolts. Salvage repairs are bolted copper and rubber.
  - Every `ancient_light` seam carries the dashed pattern cue.
  - Panels are on `ancient_enamel`. The seat is charcoal.
  - `cannon_look_test` is green.
  - Rules 1 to 9 pass.
  - The showcase pass adds one close turntable strip of a class-up slam for the review page.

PD-INT closes the wave: the verifier runs rule 10's greyscale test, the class I against class V blind pairs, and the frame-time ratio, and writes evidence only (`P-UNITS.md` section 3).

## Conflicts resolved

- **The ancient colour.** The A3 brief said ancient tech glows Cherenkov blue. On 2026-10-09 Andrew chose uranium-glass green over Cherenkov blue (`docs/decisions.tsv:350`), and the code follows (`palette.gd:12-15`, `VISUAL-LANGUAGE.md:50`). This sheet and the concept pictures use uranium-glass green with the dashed seam pattern. A line in the project memory still says Cherenkov blue and is stale.
- **Glass against the Hoberman mecha.** `VISUAL-LANGUAGE.md:391, 416` and the D6 `BUILD-SPEC.md:8` keep a glass hull. Andrew's 2026-10-10 choice of the Hoberman mecha supersedes them for the alpha sketch (`docs/decisions.tsv:417`). AD-01's "protected, readable cockpit" holds as a gimballed pod inside a roll lattice.
- **Brass on Tally.** The atlas prompt for Tally (`design-v2/visual-development/prompt-17-tally-presence.txt`) names "repaired brass/wood". Friendly gear never wears brass, so the mecha uses copper and timber. The relic name "Brass Governor" (`src/build/relics.gd:126`) is a friendly item named for the Fleet's colour. It is flagged for a rename and not changed here.
- **Rivet's front end.** The plan calls it a drill nose. `VISUAL-LANGUAGE.md` §6 calls it an optical rail and cutting lens. Both stand: the drill nose's tip is the lens.
- **Modules on a rolling lattice.** §0.2 first put the modules on hubs, and hubs tumble. Pilots' silhouette rules need fixed clock positions. The fix is the level carrier rule (§2, §4). The Kest, Tally and Sable sheets raised it as an open item; this sheet's defaults are the ones their sheets proposed.
- **Sable's crown against one mast.** §0.2 first listed pylon spikes on three or four upper hubs. `PILOTS.md` section 1, the canonical silhouette column, keeps one mast at 11 o'clock and nothing at 1, because a crown crowded the upper outline that Rivet's stacks and Kest's vents use. This sheet follows `PILOTS.md`. Sable's concept pictures may still show a crown, and the cleanup round redraws it.
- **The Cannon's ring height.** `PILOTS.md` section 1 and `P-UNITS.md` section 0.4 item 11 still put the Cannon's barrel on a gun ring at the crown. §0.1 puts every WeaponRing at the equator, and `pilots/cannon.md` section 5 follows it. This sheet follows §0.1.
- **Tarn's lattice colour.** The first draft of §6 kept oxide off Tarn's cage. §0.2 now gives him an oxide lattice. §6 keeps the clash softened and open for Andrew.
- **Panels on the lattice against a visible pilot.** Panels that tumble with the lattice would sweep over the pilot every turn. The fix is to hang the panels from the upright Pod, just inside the lattice and below the sight cone, and let the tumbling Core carry only thin hub and tread caps (§5). `CUSTOMIZE.md` section 6 takes the same default. The row in `PILOT-CLIPS.md` section 5 that puts panels on `Core > Gap.NN` should follow this.

## Veto list (calls made under the creative charge)

1. Four layers by motion: the lattice tumbles, the weapon ring stays level and yaws to the aim, the pod hangs upright in a two-axis gimbal.
2. The ball rolls on rubber tread caps whose faces sit at radius 0.985.
3. Heft panels hang from the Pod just inside the lattice, not on the tumbling Core. Class III's thicker caps ride Core, at a 2-draw registry exception.
4. Level carriers: a part that must hold a clock position rides the ring or a gap bracket, and not a hub.
5. Modules and brackets may break the outline out to radius 1.25, never below Z -0.6.
6. Mecha shells drop accretion's per-class scale, and chunks snap to hubs.
7. The decal moves to a seat-back `DecalPlate`.
8. Each pilot's earned variant (`CUSTOMIZE.md` section 8) shares the heft loader path.
9. A new `copper` slot, so paint never tints hubs or windings.
10. Value-opposite seat colours per pilot.
11. Rivet's charcoal and Tally's mulberry enamels extend the paint set, with a dated re-pin.
12. Tarn's lattice is oxide, with bone and petrol on panels and seat only.
13. Sable keeps one coil mast at 11 o'clock and no crown of spikes.
14. The intake coil leaves the shell.
15. The base triangle target stays 6,600 at first, with the cut order in §5. Raising it to about 9,000 is a coordinator call.
16. A chalk balance mark on one tread cap, to defeat the wagon-wheel strobe.
17. A Kest perch is Andrew's pick (`pilots/kest.md` section 11, item 16).
18. Separable extras, off by default: the fold as squash, the full span for the ultimate (§0.5), the sight-cone cutout for tumbling panels (`CUSTOMIZE.md` section 6), and gimbal sway of 6 degrees (§2).

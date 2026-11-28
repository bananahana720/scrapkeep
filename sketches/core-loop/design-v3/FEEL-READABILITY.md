# Core-loop v3: feel and readability

Contract for feel and readability in motion and dense combat. Feel lead handoff, 2026-09-28, in `proto/core-loop-v3-feel`, supplied base `9b9eb78`. This document owns ROADMAP **5, Feel**, and **6, Readability**, and contributes to **2, the Warden's eye**, and **7, selling the pilot**. Music and the ACE-Step decision belong entirely to [AUDIO-V3.md](AUDIO-V3.md). These are proposed build contracts, not implemented features or a new build authorization.

Read against `ROADMAP.md`, `LOOP-REDESIGN.md` and `research/CODEX-REVIEW-1.md` (archived in git history) at coordinator revision `494cd44`; Systems' `SYSTEMS-CHAOS.md` §§1.5, 10 and 11 (archived in git history); Andrew's playtest entries 7 and 8; and the current sketch's telegraph, camera, HUD, VFX and capture code. The independent review's findings 5 and 6 override the older draft's hit-stop, dodge and hit-count claims here. The coordinator must carry these corrections into the loop and Systems documents at reconciliation. §6 separates executed tool checks from pending display evidence; §9 reserves each writer's files.

**Andrew's words this answers.** "Very sparse and tightly knit" (the HUD). "I was just going around in circles and I don't know if I was dodging" (the Warden). "Juicy feedback", "eye candy" that makes him want "to know what's gonna happen next with these upgrades", "visceral feedback from myself and how I interact with the game", bombs more satisfying, knockback per weapon. The target is a "crazy chaotic mess" in the family of Isaac, Gunfire Reborn, RoR, Hades and Vampire Survivors. His entry-7 rule stands: say at a glance what to press, what hurts and how to grow; icons over words; information timed to need; 25 words in a fight.

**The draft's diagnosis, with current evidence limits.**

1. The prior author recorded `30-pack-mind.png`: the Mind's lane telegraph covers the entire bowl floor in HAZARD stripes at fill alpha, its rails run to the horizon across the sky, and nothing marks the escape. The grammar draws each threat correctly on its own (W2) and has no rule for what happens when threats cover most of the frame. That observation motivates a moving-footage test; a still cannot establish whether the player recognized an exit or a dodge.
2. The prior contact sheet and the inspected `25-warden3.png`: every HUD element is 34 to 64 px on a 1080p frame, all of it in one 60 px strip at the bottom centre plus one plate at the top. Between them, 800 px of play view carry only the reticle. "Sparse and tightly knit" is literal: little, and all in one knot.

## 1. The chaos-readability grammar

The rule: **a fact that decides the next half second is drawn above and apart from everything that only celebrates the last one.** The screen may fill; what fills it is governed, and what must stay readable is exempt from the governor.

### 1.1 Priority stack

Every drawn thing belongs to one priority class. The class decides draw order (front to back), whether the density governor (§1.2) may touch it, and whether it carries the charcoal keyline. **The keyline is the priority mark**: information wears it, candy never does, so at a glance a keylined shape is one to act on. The threat grammar already keylines every hostile line (W2 note 18); this extends the rule to the reads and the exits and forbids it on effects.

| P | Class | Members | Governor | Keyline | Draw order |
| --- | --- | --- | --- | --- | --- |
| P0 | The ball | Shell, cockpit, pilot, rig stubs, hull damage (§2.2) | never | n/a | world |
| P1 | Hostile committed geometry | Every threat edge, front, bracket reticle, flight trace, height rail; the pulse core ring; a hold's binding | never | yes (exists); in the clear and edges telegraph looks (FX-29, clear the default since 13 Nov 2026) the height rail has none | priority 40, no depth test in haze and classic; clear and edges depth-test with a 0.3 m pull toward the eye, so a body or a wall draws over the line (threat_grammar.gd LOOKS) |
| P2 | The three reads and the exits | The window beam; the safe-resolution chevrons; the return contraption's lane and gauge; kicker lips; the reach ring's dashed bone | never | yes | priority 39, depth-tested; short occlusion marker only |
| P3 | Player committed geometry | Skill-shot indicators, the charge gauge ring, the grapple reticle | never | yes | priority 38 |
| P4 | Rewards and pickups | Scrap squares in flight, cores, gate toppers, hoops, interactable glyphs | thinned only past density 0.8 | yes on the topper, none on scrap | priority 30 |
| P5 | Player effects | Hit sparks, kill pops, chain bursts, trails, speed lines, slam rings' afterglow, synergy shockwaves | yes | **never** the keyline band; the solid hit spark, the kill mark and the stun stars wear a thin comic ink rim inside their own shape (FX-01, FX-02, 12 Nov 2026, an assumption Andrew can overturn) | priority 20, additive |
| P6 | Hostile area fills and swept ground | The striped 35% fill inside an edge, a wave's 15% swept stripes, a lane's run fill | unioned past 4 overlapping areas (§1.3) | n/a | priority 10 |
| P7 | Ambient | Dust, steam, sparks off the fins, heat shimmer, idle loops | first to go | never | world |

Two consequences the current code does not have. First, P6 sits *below* P5: a hostile fill is a region, and a spark over it costs nothing, but a hostile **edge** (P1) is above every spark. The still's floor-wide stripes would still be there, but the lane's rails, its far cap and the escape (P2) would be drawn over the ball's own effects. Second, P2 is new as a class: the beam, the evasion chevrons, the return lane and the lips are what §2 of LOOP-REDESIGN calls the three reads, and they get hostile-grade exemption from the governor.

### 1.2 The density governor

One scalar per frame, `density` in 0 to 1, read by every P5 and P7 emitter from one place (`src/presentation/density.gd`, §9 F1a). It never touches P0 to P3.

`density = clamp(0.35 * threats_in_view / 6 + 0.35 * fx_alive / 40 + 0.3 * enemies_in_view / 12, 0, 1)`, smoothed with a 0.25 s rise and 0.6 s fall so it never flickers. The weights make six threats alone read as 0.35, and a screen-filling build against a six-pack lap read as 1.0.

| density | P5 alpha cap | P5 size cap | P5 lifetime | P5 colour | P7 | Kill pops |
| --- | --- | --- | --- | --- | --- | --- |
| 0.0 to 0.4 | 0.9 | 1.0 | 1.0 | class colour | on | one starburst each |
| 0.4 to 0.7 | 0.6 | 0.85 | 0.7 | class colour at 70% saturation | at 40% | coalesce: kills within 120 ms and 4 m share one starburst, scaled 1.2 per extra kill, capped 2.5 |
| 0.7 to 1.0 | 0.35 | 0.7 | 0.5 | desaturated to 40%, value held | off | coalesce within 200 ms and 6 m; the chain counter (§2.4) carries the number |

The trail and the speed lines are P5 and follow the same caps, except the trail's *first* 0.12 s stays at full alpha so the ball's direction never goes (it is a read).

**Per-frame effect budget.** Hard caps on top of the governor, so a burst of 30 kills cannot spend the pool on candy.

| Budget | Cap | Source today | Why |
| --- | --- | --- | --- |
| P5 glyphs alive | 40 of the 48 pool (8 reserved for P2 and P3 shapes that share the pool) | `vfx.gd` `POOL` 48 | the pool never starves a read |
| Hit sparks alive | 12 | none | past 12 they add nothing but noise |
| Kill pops per 250 ms | 3 (the rest coalesce) | none | one bold animation per event (VL §8) |
| Speed lines | 20 (tier 3) | `LINES_PER_TIER` | exists |
| Trails | 1 | exists | |
| Hit-stop | ≤ 1 onset / 250 ms; ≤ 100 ms / rolling 1 s; ≤ 300 ms / rolling 5 s | current spine caps a request at 60 ms; current juice gap 400 ms | proposed budget in §3.4; W11 integration must use one clock |
| Camera shake sum | 0.6 at density ≥ 0.6, else 1.2 | `chase_camera.gd` clamp 1.2 | §3.1 |
| Toasts | 1 | exists | |
| World prompts | 3 | `MAX_PROMPTS` | exists |
| Edge markers | 3 | exists | |
| Damage numbers | 0 | none exist | shape over digits, and the chain counter is the one celebration number |
| Hostile edges | unlimited | | never governed |
| Hostile area fills drawn | 4, then unioned | none | §1.3 |

### 1.3 Hostile fills at scale: union, and draw the escape

The still's failure is not too little hostile drawing but too much of the same kind with no negative space. Three rules.

1. **Overlap unions.** RR-06 says overlapping fills add no brightness. Extend: past four overlapping hostile areas in view, the fills draw as one union at 35% and each threat keeps only its edge, front, brackets and rail. The edges are the information; the fill is the region.
2. **Optional escape hint.** Trial only after edges pass the moving test. Above 45% projected floor coverage, a 2 m bone dashed ring may mark reachable clear ground within 12 m. Coverage uses the union of projected geometry, not overlapping bounding-box areas. Sample terrain and every active committed threat at the expected arrival time and through a 0.3 s arrival margin; reject blocked routes, holes and height mismatches. Suppress the hint when no candidate is verified. It never steers the ball or claims a guaranteed dodge. Reduced motion keeps the positional cue. This needs coordinator-approved threat-time data before F1b can build it.
3. **Rails follow the committed lane.** End rails and posts at the actual far cap, not at an invented threat boundary. Beyond 60 m, reduce decoration, retain any edge that intersects the play view, and use an offscreen direction cue for an approaching threat. A distance clip must never imply that the damaging lane ends there.

### 1.4 Colour and shape redundancy (unchanged, restated as the test)

Every fact has two cues; every hostile fact has three, one of them motion. The VL §3 table stands: hostile is HAZARD, 45° stripes, sharp corners, klaxon; yours is class colour, clean, rounded, class instrument; a reward is the rarity ramp plus a frame shape plus a bell; travel and exits are amber, chevron, arpeggio. One addition: **the keyline** (§1.1) is a fourth cue that is pure value, so it survives every vision type and every colour collision the VL §2 table measured (Rivet copper against HAZARD is ΔE 2 to a protanope; the stripes and the keyline carry it).

### 1.5 "I'm a god" without hiding the next threat

Late-run power reads through the **scale of consequence**, never through the count of effects.

- **One bigger shape, not many.** Coalesced kills (§1.2) make one starburst scaled by the count. A six-kill chain is one 2.5× burst with the chain number on it, not six bursts.
- **The rig records growth.** The evolved part's rig on the pod (Codex track, LOOP-REDESIGN §8) and the accretion chunks are the standing record of power; they are P0 and never governed. Growth is seen on the ball from across the bowl.
- **The aura, optional and deferred.** If §10's trial is chosen, at heft III or with any evolution live, a class-colour rim glow sits at the frame's edge (a vignette, alpha ≤ 0.18, inner radius 0.78 of the half-diagonal) that breathes with the music's pressure. It never enters the centre 60% of the frame, and yields to any hostile edge or edge marker, including at the rim. Reduced motion holds it static.
- **The chain counter** (§2.4) is the only number that grows, and it grows in size, not in words.
- **The audio does the rest.** Audio owns escalation and any chain cue. §7 reserves threat audibility regardless of the score.

### 1.6 A resolved threat is not automatically a dodge

One record per committed attack and player: `attack_id`, committed geometry, whether the player was threatened during the warning, last damaging-volume exit time, resolved/cancelled state and actual hit outcome. L1 owns the Warden record; threat owners supply equivalent records for other attacks. Presentation never infers success from an empty ring, a vanished node, silence or unchanged HP alone.

| Outcome | Predicate | Shape and cue |
| --- | --- | --- |
| Safe resolution | Relevant player was threatened during the warning, attack resolves, no hit from that attack, player is outside its damaging volume at resolution | Two short outward bone chevrons beside the ball, 0.18 s; small resolution cue. Includes an early clean exit |
| Near-miss bonus | Safe resolution and final exit occurred within 0.3 s of resolution | Same chevrons plus one short class-colour streak and the bonus swish; never a second opening beam |
| Never threatened / cancelled | Never entered the damaging volume during warning, or attack cancelled | Ordinary attack ending/cancel shape only. No player success award |
| Hit | That attack reports a hit, including a shielded hit or a shove | Hull/contact read, no safe or bonus cue. Other simultaneous threats still resolve independently |
| Open | Warden's authoritative vulnerability begins | Split upright aperture and time beam; objective repeats split posts. No outward chevrons |

For a moving wave, resolve against the committed front passing the player's relevant region, not the telegraph's despawn. Leaving the harmless lift ring alone is not a damage dodge. If the attack owner cannot establish relevance or resolution, omit the success cue and log the missing record for the coordinator. Overlapping attacks may yield different outcomes; never let one safe flash imply universal safety.

## 2. HUD density and hierarchy

### 2.1 Diagnosis, in pixels

At 1920×1080 today: ability slots 64 px, key glyphs 20 px, health tank 190×~14 px, heft dial about 64 px, scrap digits 19 px, speed glyph 34 px, objective icon 34 px with 19 px words, status plate about 160×70 px. The bottom band (`screen_regions.gd` 86% to 100%, 151 px tall) holds one 60 px strip; the top band (0 to 14%) holds two small plates; toasts 15% to 29% (empty most of the time); prompts 62% to 84%. Nothing is wrong with any one element, and the sum reads as a thin frame around an empty middle.

### 2.2 Three rings of attention

The fix is not more HUD. It is putting each fact where the eye already is when it needs it.

| Ring | Where | Carries | Read at |
| --- | --- | --- | --- |
| **The ball** (diegetic, P0) | On the shell | Hull integrity, heft, charges, cooldowns, cloak, the rig stubs | a glance mid-fight |
| **Near the reticle** (world-anchored HUD) | At the action anchor; secondary HUD outside the exclusion | The charge gauge ring (exists), contextual keycaps (exist), the chain counter, the drop lead marker; evasion chevrons stay world-anchored on the ball | the moment of action |
| **The frame** (instruments) | Top and bottom bands | The precise reads: gauges, the ability bar, objective and integrity chunks, clock, difficulty, cores | a deliberate look |

**Diegetic on the ball.**

| Fact | On the shell | Precise twin on the frame | Owner |
| --- | --- | --- | --- |
| Health (hull) | Plates crack in iron oxide from the top down: 75% one crack, 50% two plates dark, 25% sparks off a hinge at 1 Hz and the cockpit glass frosts at its edge. Dead Space's spine, on a ball. | Tank gauge (exists) | Codex (`hero_assets.gd` damage slots), W11 for the damage-taken read |
| Heft | Shell size (exists, `juice.gd` `SHELL_PER_CLASS`) plus chunk count (exists) | Heft dial | exists |
| Charges | Lights on the working device: Kest's satchels have an amber lamp each, Sable's pylon plates a mint pip each, Rivet's exhaust stacks glow one per charge | Pips under the slot (exist) | Codex (lamp slots), `ability_slots.gd` publishes |
| Cooldown | The device's rest state: Rivet's fins fold, Kest's mortar cradle sits back, Sable's spool is still; the ready pulse opens it | Wedge sweep (exists) | Codex, driven by the slot record |
| Cloak | Dotted outline (exists) | none | exists |
| Growth in progress | Rig stubs (§4.2) | Tree crumb | Codex |

The shell says "roughly"; the frame says "exactly". A player who never looks down still knows. This is the same fact in two layers from one source row (`run.hp`, the slot record), so they cannot drift.

### 2.3 What grows, what spreads, what is timed

**Grows** (1080p, before UI scale): ability slots 64→80 px, key glyphs 20→26, charge pips 6→8, health tank 190→320×16 with the quarter ticks 2 px taller, heft dial 64→96, objective icon 34→44, toast icon 26→32. Type stays (labels 16, objective 20, toasts 22/28) since the words were never the problem.

**Spreads.** The bottom band becomes three anchors on the thirds instead of one strip: health and speed left-centre, the ability bar centre, heft and scrap right-centre. The top band likewise: status left, objective centre, cores right of the objective. The reticle exclusion stays clear of secondary HUD.

**Timed to need.** The default is *shown*, and the exceptions are where nothing is happening.

| Element | Shows | Fades to |
| --- | --- | --- |
| Ability bar | always | 60% opacity when every slot is ready and none has changed for 3 s; back to 100% on any change |
| Health tank | while hp < 100%, and for 4 s after any change | hidden; the hull carries it |
| Heft dial | always (growth is what Andrew watches) | never |
| Scrap count | for 2 s after any change, always at the bay and when a price is in view | the dial alone |
| Objective plate | always | never |
| Integrity chunks | always while sealed; grows 44→56 px within 40 m of the Warden | |
| Window echo | split upright posts beside the objective show the live window | |
| Chain counter | at chain ≥ 3 | gone 1.2 s after the chain breaks |
| Clock and difficulty | always | |
| Toast | one, 1.6 or 2.4 s | |
| World prompt | glyph and selected-target cue at 30 m; nearby keycap plus glyph plus ≤ 5 words at 6 m; active hold remains locked after passing | |
| Edge markers | when the target is off screen | |

### 2.4 The chain counter

Andrew asked for visceral feedback from his own action. The chain counter is the celebration's one number. Its 72×72 box at (1176, 414) sits outside the reticle exclusion. Class-colour mono digits sit on a compact class badge; paired outward chevrons remain reserved for evasion. Type starts at 28 px for chain 3, grows 2 px per kill to 56 px at chain 17, then holds. Three or more digits shrink to fit rather than crossing the box. Each kill pops it 1.12 (the good-news overshoot) with the class instrument one rung higher, so the counter is also the scale climbing. A chain breaks after 2.5 s without a kill: the digits fall 20 px and fade, one dry click. It never becomes a word ("COMBO" never appears). W11's kill chains publish `chain_count`; this draws it.

### 2.5 Layout at 1080p with safe zones

Title-safe margins are 5%: x=96..1824, y=54..1026. Coordinates below are (x, y, width, height) at 1920×1080. These correct the old 322 px ability-bar arithmetic: 4×80 + 3×14 = 362. At other sizes or UI scales, reflow within the safe rectangle and validate collisions; scaling alone is insufficient. Text, chain digits and prompts never enter the exclusion. Only aim geometry, the reticle and its hold gauge may enter it, together with the actual world scene.

| Element | Box (x, y, w, h) | Band |
| --- | --- | --- |
| Status: stage pips, clock, difficulty | 96, 54, 220, 84 | top |
| Objective: icon, ≤ 5 words, core pips, integrity chunks | 640, 54, 640, 64 | top |
| Toast, one | 560, 168, 800, 44 | toasts |
| Callout or hold-R meter, mutually exclusive | 720, 224, 480, 30 | toasts |
| Reticle exclusion | 760, 340, 400, 400 | play |
| Chain counter | 1176, 414, 72, 72 | play, outside exclusion |
| Prompt slot 1 | 115, 680, 360, 44 | left |
| Prompt slot 2 | 115, 738, 360, 44 | left |
| Prompt slot 3 | 1445, 680, 360, 44 | right |
| Prompt corridor, forbidden to prompts | 660, 670, 600, 172 | play floor |
| Health tank + speed | 384, 966, 360, 40 | bottom left |
| Ability bar: four 80 px slots, 14 px gaps, keycaps and pips | 779, 916, 362, 110 | bottom centre |
| Heft dial + scrap | 1216, 930, 186, 96 | bottom right |

`screen_regions.gd` owns these rectangles. Prompt slots may follow their anchors within the side lanes but never enter the corridor; stable nearest-first arbitration shows at most three, only one with words. Edge markers clamp inside title-safe and move clear of HUD boxes. Enlarge the bottom band to include y=916. `int_screen_layout_test` checks pairwise intersections, safe bounds and exclusions at 1080p and supported UI scales.

The PIL mock uses this table as its source, validates its rectangles, and composites both panels over the same supplied still. Left preserves today's UI; right masks the old HUD strips and draws proposed boxes. It is a placement study, not a rendered v3 HUD. Run `python3 sketches/core-loop/tools/hud_mock.py`; output is `artifacts/local/hud-mock/side-by-side.png`, with input and output hashes in `manifest.json`.

### 2.6 Coexistence in the fight

The integrity badge, the window beam, the picks, the chain counter and interactable prompts all appear in the same 20 s. Where each lives, so none collide:

- **Integrity chunks**: fixed four-quarter sectors of authoritative `warden.integrity()`, including a partially filled boundary sector. They never promise a number of future drops or gun bursts. Damage animates exactly the depleted fraction; a shear celebrates crossing a quarter threshold once. A large hit can cross several thresholds; small hits remain visible. Heft, gun-role toggles and window extensions never relabel the sectors.
- **The window**: a split vertical aperture around the exposed core, with two upright posts and the actual remaining-time beam between them. A matching split-post glyph appears beside the objective. It never reuses the circular integrity outline or evasion chevrons. Class colour is secondary. Its beam consumes the accepted, capped window clock, including any extension; it cannot invent a duration.
- **Picks** (a hoop on a drop line, a gate on the bank): a world prompt, glyph at 30 m, keycap at 6 m, in the prompts band, so they are only ever below the horizon line and off the centre corridor. A reward gate's offer is the exception: it hangs from its own gate at the gate's crossbar point in that gate's own slot of the sign room (never in a neighbour's), shows its detail only when the slot is wide enough, else the name alone, else the name alone at the floor size, else no sign, and is named for every standing gate whose slot can hold its name. CONTRACTS.md, UI regions, has the rule and the three cases that leave a gate with no sign.
- **The chain counter**: outside the reticle exclusion, class colour, so it cannot be mistaken for a threat or a prompt.
- **Interactable prompts** (a device, the vault, a fabricator's hoop): share the three band-prompt slots, nearest first, so a busy line shows three and the rest wait (exists). A reward gate's sign is not one of the three: it has its own slot (CONTRACTS.md, UI regions).
- **Words**: objective 5, toast 4, one near prompt 5, boss name 3, reserve 8. `ui_word_budget_test` stays at 25 with the new elements staged.

## 3. Feel tuning

### 3.1 The camera

What the rig does today (`chase_camera.gd`): FOV 65→82 with speed fraction, arm 7.5→10.5 m, follow rate 6→15, roll up to ±0.13 rad from lateral acceleration, shake up to 1.2 from `impact/30` plus presentation's `shake()`, kicks that spring back at 14/s, FOV punches capped at ±20. It is a good base. What it lacks is behaviour for the drop, the rebound and the bowl, and a governor for chaos.

| Situation | Behaviour | Numbers | Why |
| --- | --- | --- | --- |
| **At speed** (tier 2 to 3) | As today, with FOV capped so the base plus any punch never passes 88 | base 65→80, punch clamp ±12 at tier 3 | 82 + 16 (launch punch) is 98 today, which is a fisheye; comfort and readable edges |
| **Off a lip, descending on a drop line** | The lead marker: a P2 bracket at the predicted landing point from the movement owner's terrain-aware trajectory prediction, and the pitch eases down up to 12° toward it; arm out to 12 m; FOV +6 | pitch lead 0.6 s ease-out; only while airborne and vertical speed < −8 m/s; suppress the bracket if the predictor cannot handle current glide, grapple or collision state | the drop is the spine; the player must see the core coming |
| **The landing on the core** | one admitted 60 ms hit-stop and −4 FOV punch (the slam profile), then **the rebound whip**: a kick along −velocity of 0.6 (the launch value) and FOV +8 decaying over 0.5 s, yaw left to the player | the whip is one spring, no roll | the rebound must feel like being thrown, and momentum is sacred |
| **In the bowl** (r < `BOWL_OUT`) | A soft look assist toward the mast: when the mouse has been still 0.5 s, yaw blends 25% toward the Warden at 2/s; any mouse input cancels it for 1 s | setting `camera_assist`, default off; optional bowl-only trial | "where is it" while circling; the Warden is the room's landmark |
| **Riding the return** | The launch profile (exists: +16 FOV, kick 0.6) with the punch clamp above | | a ride that feels like a ride |
| **In chaos** (density ≥ 0.6) | Shake sum capped at 0.6, kicks at 0.4, no roll from impacts; hit-stop obeys §3.4 across every source | | the camera must not add noise to a full screen |
| **Damage taken** | Never shake (VL §8). The read is a hazard-red edge flash toward the source for 0.4 s, the damage number and a squash (the `player_hit` row in `event_kinds.gd`, drawn by `edge_flash.gd`) | | shake on being hit is the one thing that makes "did I dodge" unanswerable |

### 3.2 Motion comfort and settings

The pause menu today has only volume rows (W10 note 7: reduced motion did not exist). Add a Feel page with seven rows, each a segment slider or a toggle in W10's grammar, stored in `settings.json`:

| Setting | Range | Default | Effect |
| --- | --- | --- | --- |
| Field of view | 60 to 88 | 65 | base plus speed and punch share an 88° total clamp |
| Camera shake | 0 to 100% | 100% | scales every `shake()` and impact shake |
| Camera roll | on/off | on | lateral and impact roll; off removes both |
| Bowl look assist | on/off | off | optional yaw help only after 0.5 s without mouse input; input cancels it |
| Hit-stop | on/off | on | off makes every request send 0 |
| Reduced motion | on/off | off | RR-11: removes celebratory motion, keeps every measured motion |
| Speed lines | on/off | on | P5 speed lines and the tier-3 comet |

Rules that hold at every setting: pitch clamp −1.25 to 0.55 rad (exists), roll ≤ 0.13 rad, total FOV ≤ 88, no camera cut in play, the ball never leaves the frame (follow rate 15 at speed already holds this).

### 3.3 Per-weapon feedback profiles

One table of numbers, the contract W11's implementation must meet and Audio's cue set pairs with. Hit-stop belongs to the player's own strike: an ordinary hit stops 12 to 40 ms by its damage, and the ball's motion, a dodge and damage taken get none (VL §8; the rows in `event_kinds.gd` own the numbers). Knockback is the enemy's, in m/s at heft I, scaling ×1.3 per heft class. The ball's own recoil is a squash, never a velocity change, except the bomb's rocket jump.

| Weapon | Hit-stop | Camera kick | FOV punch | Shake | Enemy knockback | Ball squash | Hit shape | Instrument (Audio) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **Gun** (Rivet laser, Sable arc caster) | 0 | 0 | 0 | 0 | 1.5 m/s, along the shot | 0 | a 0.3 m chevron scorch (Rivet) or a 0.4 m ring flash (Sable), P5 | closed hi-hat tick / one arpeggio note |
| **Bomb** (Kest sticky, demo slam charges) | 0 on stick; 40 ms on a detonation that kills ≥ 2 | 0.25 along blast→ball | +3 over 0.25 s | 0.35 | 9 m/s radial, falls with distance² | 0.15 away from the blast | a starburst 1.5× the blast radius, one bold; scorch marks stay 4 s | low kick drum; pitched down per extra kill |
| **Ram** (contact at speed) | 0 below plating; 40 ms on break-through (exists) | 0.3 toward the enemy (exists) | 0 | 0.35 (exists) | 6 m/s + 0.3 × impact speed, along the ball's velocity | 0.3 along the contact normal | chunk shear on the enemy (VL: a plate pops off), P5 sparks | plate clang, pitched by impact speed |
| **Smash** (Ctrl) | 40 ms on smash-through (VL §8) | 0.35 + 0.35 × strength down (exists) | −4 × strength (exists) | 0.5 | 10 m/s radial from the impact, plus 4 m/s up (they pop) | 0.3 + 0.2 × strength (exists) | the class ring or wedge at the real radius, one bold | root plus fifth (Sable), snare flam (Rivet), floor tom (Kest) |
| **Blast** (F specials: detonation gauge, overdrive blast, detonation line) | 50 ms (the pin-chain value) when ≥ 3 enemies are caught | 0.4 outward | +6 over 0.3 s | 0.6 | 12 m/s radial (gauge), 8 m/s outward (blast), 9 m/s per charge (line) | 0.25 | the full class shape at the drawn extent; P5/P7 celebration at ≤ 30%; P0 to P3 and the objective retain their contrast | the arpeggio resolving / open hat crash / kick roll |
| **Drop on the core** (the v3 hit) | 60 ms | 0.6 along −velocity (the whip) | −4 then +8 | 0.6 | n/a; authoritative integrity falls | 0.42 | the lost integrity fraction drains; crossing a quarter shears a piece | the reward ladder one note up, the spring snap pitched by impact speed |
| **Warden break** | 60 ms (VL §8) | 0 | +9 (exists) | 0.4 | | 0 | the jaws let go, the cage drops (§4) | the unseal drop (G3) |

Knockback per weapon is the ask from entry 8 ("knockback that differs by weapon"): the gun nudges, the bomb throws radially, the ram carries the ball's direction, the smash pops upward, the blast clears a room. Each is a different verb the enemies' bodies write on the floor.

### 3.4 One interruption budget, including the evolution

All requests share the spine's wall-clock admission gate, not separate weapon cooldowns. Proposed bands: **60 ms maximum per event, 250 ms minimum onset gap, 100 ms total in any rolling second, 300 ms in any rolling five seconds**. Count admitted wall time, including overlap with hit-stop scale, rather than scaled simulation delta. Same-tick requests coalesce to the strongest; never stack, extend a current stop, queue a delayed stop, or repay a refused request. Spend remaining budget by shortening the request or omit it. Sound, squash and world impact still fire when the stop is refused. No presentation effect writes ball velocity.

The current `game.gd` cap is 60 ms. The old Feel draft requested 70 ms and Systems §10 requests 120 ms for evolution; neither is accepted here. Recommend one shared 60 ms break/evolution stop, with a 1.4 s visual transformation while movement continues. A 120 ms exception would require Andrew's explicit choice and a new measured interruption band; it is not a hidden implementation exception. `presentation_juice_test` must exercise a five-second alternating drop/bomb/break/proc burst, boundary timestamps, hit-stop disabled, and velocity before/after.

## 4. Anticipation as eye candy

The rule from LOOP-REDESIGN §8: every reward is previewed before it is earned, and every preview is a shape you can already see, never a line of text. Each tease below is one shape, one motion, one sound, one moment it first appears, all from one source row.

### 4.1 The six teases, designed

| Tease | Shape | Motion | Sound (Audio) | First appears | Source row |
| --- | --- | --- | --- | --- | --- |
| **Socket** (a ripe part hints at its evolution) | A dark recess on the part's accretion chunk cut in the pair's family glyph (`cat_` silhouette), charcoal, keylined | Still. A notch records each held copy. At ripe, when a matching pair is offered in view, the socket breathes at 0.5 Hz in the piece colour (mint remains reserved for a completed synergy) | a soft sustained hum (the dashed-line sound: future) while breathing | the frame the Systems row becomes ripe | Systems evolution row: pair tag, copy count, ripe and armed state |
| **Cage** (the break reward on the mast) | A salvage-girder cage hung above the jaws, holding the gate toppers' rarity frames; when an evolution is armed, the evolved part's silhouette turns inside at 12 rpm | Each core socketed adds a frame with a clack and a 0.3 s bolt-in; the cage sways 2° with the level theme's bar | a warm bell per frame added; the cage drop at the break is the unseal drop's downbeat | the entry drop, in sight from the deck | `flow.gd` tier from `bonus_cores`; `reward_gates.gd` toppers |
| **Bracket** (the half-built rig) | A bare stub on the pod in the next pick's place: a mast stub, a fin hinge, a satchel strap, in bare metal | Ratchets one notch when the pick opens at the bay's catch; the pick fills it with a 0.28 s drop-in (W8's card motion, on the ball) | the dry ratchet click (the bracket's own sound) | the moment the pick becomes available | `upgrade_tree.gd` next pair; `hero_assets.gd` `class_accent` (Codex) |
| **Dial** (a cost you can see before you can pay) | The interactable's bone pressure dial with an amber notch at the cost and the needle at your scrap | The needle swings to your scrap when you enter 30 m (the heft dial's clunk); at the cost it holds and the notch lights | a gauge tick per notch of swing; a bell when the needle reaches the notch | 30 m | `interactables.gd` cost; `run.scrap` |
| **Post** (the next line's payoff) | A copper post at a drop line's head with the part's family glyph on its plate, and the line's event beam behind it | The glyph plate flips face-up when the line becomes the long line this lap | the brass anvil hit (opt-in fight register) | from the east landing | `stage_map.gd` `drop_lines`; §9 prompt grammar |
| **Beam height** (the window's next length) | The core's class-colour beam, height = window seconds × 2 m | A socketed core adds a band with a bolt-in; the beam shrinks linearly as the window runs | the family chord; the held-door tick per hit | first window | `warden.gd` window length |

### 4.2 Pickup reveal moments and rarity flourishes

A pickup's reveal is the 0.4 s between "it exists" and "it is mine", and the rarity ramp gets one flourish each, in shape and sound, never a word.

| Rarity | Frame assembles | Flourish | Sound |
| --- | --- | --- | --- |
| Common | The thin bone outline pops in (0.12 s, overshoot 1.2) | none | one bell |
| Uncommon | The bold mint outline bolts in from two sides (0.2 s) | a single mint ring off the topper | two bells, a third up |
| Rare | The double amber outline draws itself as two lines, outer then inner (0.3 s) | four sparks off the corners, a 0.5 s amber breathe | three bells, a fifth up |
| Rare_plus | The double outline, then the four bolt-head notches clack in one at a time at 45° (0.4 s) | a mint heart pulses inside; the frame casts a mint glow on the ground | the three bells, then a fourth on high D (the rice-cooker) |

Scrap stays a square chunk on a path into the intake (VL §2). Its reveal is the magnet pull W11 builds; the pitch climbs a rung per chunk within 0.5 s, and the tenth in a row gets the class instrument's note. The pull's speed tells the heft: a heavier ball pulls faster.

### 4.3 The evolution transformation beat

A 1.4 s transformation at the Warden break, once per evolution. Systems owns which pieces are consumed and the armed rig. No fixed "three pieces" animation: the actual consumed copy count flies off, heft stays constant and the pair stays attached. Hostile reads, ball visibility and player control remain intact throughout.

1. 0.00 s: the jaws let go (the unseal drop's downbeat). Share the break's admitted hit-stop, at most 60 ms total under §3.4.
2. 0.07 s: the ripe part's chunk on the ball flares in the class colour; the socket fills with the pair's glyph, which turns from charcoal to the rarity colour.
3. 0.30 s: the rig grows out of the chunk in one bold animation (the spiral vane unfolds, the arc mast telescopes, the wrecking chain drops and swings), 0.5 s with the back-out overshoot. Only other P5/P7 celebration dims to ≤ 30%. Hostile edges, the player and action geometry never dim.
4. 0.80 s: the evolved effect may demonstrate its actual extent once, without damage or proc events, only after checking that no committed threat competes with it. Otherwise defer the demonstration to the next safe pause. Never display a live damage shape for an inert preview.
5. 1.40 s: the class motif resolves on the chord; one class-colour toast names it in at most three words, replacing any queued reward toast. The codex records it for Tab; it does not open a card over the fight.

## 5. Discovery without text

Learning means experimenting, not reading. Every new thing is taught by shape, motion and consequence, and the codex names it only after the fact.

### 5.1 First-encounter framing

- **No cut, no stop.** The camera never leaves the ball for a reveal. The thing is placed on the loop's sightlines (LOOP-REDESIGN §3) so it is seen on the way, not presented.
- **The glyph at 30 m.** Every interactable, hoop, gate and post shows its family glyph over itself at 30 m (LOOP-REDESIGN §9 prompt grammar). The glyph is on a backplate that says its family (VL §5: hex nut, parts tag, warning triangle, brackets).
- **It demonstrates itself once.** The first time a family is in view in a run, the thing runs one empty cycle: the lift fires with its steam puff and arpeggio, a cracked wall's crack glints, a rigged cache's dial spins once and settles, an ambush post's ring pulses once in the enemy colour, a dormant drone's blue seam flickers. The demonstration is the tutorial. Once per family per run, keyed by the interactable row.
- **Consequence is the lesson.** A tap on a hold-to-arm does nothing but fill the ring a little (exists: the gauge ring), so the shape teaches the hold. A refusal is the dry click and the ring collapsing (VL §4 cancel). A miss on a bet is the refusal bone. A landed drop drains the true integrity fraction; crossing a quarter shears a piece. Nothing here is a sentence.

### 5.2 The table: mechanic to shape to consequence

| New thing | Shape says | Motion says | Consequence says | Codex after |
| --- | --- | --- | --- | --- |
| A drop line | Amber kicker lip aimed at the mast, a chevron lane | The lip's chevrons run toward the mast | The ball flies where the lip points; the lead bracket (§3.1) shows where it lands | "Drop line" card with the arc drawn |
| The open window | Dome halves open, split upright posts frame the core, the beam stands | The beam shrinks linearly | A hit in the window drains true integrity; outside it, the pulse throws you | the Warden's five states as a ring |
| Safe resolution / near-miss | Two outward bone chevrons at the ball / an extra short streak | On that attack's resolved event, never on silence | The player escaped a relevant committed threat without being hit; the last 0.3 s exit adds the bonus | none needed |
| A synergy found | The two parts' glyphs snap together on the chunk | A starburst on the snap | An inert preview waits for a safe gap (§4.3 step 4) | the pair named on the card |
| A hold on the ball | A striped binding | Filings drag inward, cords wrap | Speed or a smash bursts it in the class colour with the boost refund | the unit's silhouette and its break |
| A rigged cache | A copper crate with one HAZARD stripe and an odds dial | The dial spins on the hold | Heads: the drum roll ends in a crack and the crate bursts open. Tails: the refusal bone and the crate goes dark | "Rigged cache" with the odds shown as the dial |
| A timed trial | A gate with a par dial over it | The needle runs down while you drop | The gate's topper gains a frame on a make, or the dial goes dark | the par time |
| A dormant ally | A drone on a housing, blue seam dark, cost dial | The seam flickers once on first sight; lit mint when running | It follows and rams what you rebound off; the wallet dial falls by the quoted cost; mass and heft never fall from spending | "Awaiting operator" |

### 5.3 The codex after the fact

The field notes (Tab) hold the cards. A card is created by the first *use* (not the first sight), with the shape drawn as it was in the world, the family backplate, and at most eight words. The discovery burst and cue may play after the action when no P1 warning competes; otherwise queue or coalesce the celebration. The card stays in Tab, never opening over combat. The "found" toast is zero words: the burst and the bell. Hint cards (evolution pairs, LOOP-REDESIGN §8) show the two glyphs and a socket, never the evolved name, until the evolution has happened once on this profile.

## 6. Measures and stress-capture procedure

All bands below are proposed acceptance thresholds, not measured results. A headless run qualifies schema and control flow only. Stills qualify placement and pixel proxies. Andrew's moving play establishes whether a dodge, opening and hit feel clear.

### 6.1 Structural checks for the implementation waves

| Measure | Check and pass band |
| --- | --- |
| Words and keycaps | `tests/ui_word_budget_test.gd`: fight ≤ 25 words including digits and every visible prompt; calm ≤ 40. `tests/ui_keycap_text_test.gd`: ≥ 26 px key glyph at 1080p, label never replaces the key symbol. Proposed new filenames require coordinator registration in the sketch runner. |
| Layout | `tests/int_screen_layout_test.gd`: §2.5 boxes inside safe bounds, pairwise disjoint, prompts outside corridor, secondary HUD outside reticle exclusion; reflow at supported scales. |
| Density | New `tests/presentation_density_test.gd`: 30 kills / 200 ms, six packs, eight mixed hostile telegraphs; P5 glyphs ≤ 40, hit sparks ≤ 12, kill pops ≤ 3 / 250 ms; no loss of P0 to P3. Test each shed step and recovery hysteresis. |
| Fills and escape | `tests/threat_grammar_test.gd`: overlaps do not accumulate brightness; more than four fills share a union with every committed edge preserved. Optional hint fails closed when terrain, arrival-time safety or reachable path is uncertain. |
| Camera and momentum | `tests/movement_camera_test.gd`, `tests/presentation_juice_test.gd`: total FOV ≤ 88°, roll ≤ 0.13 rad, shake ≤ 0.6 in density ≥ 0.6; no damage-taken shake, presentation never writes velocity; §3.4 interruption bounds hold across all sources. |
| Warden facts | `tests/warden_window_test.gd`, `tests/warden_impact_test.gd` and a proposed `tests/warden_resolution_test.gd`: early safe exit, near-miss, never-threatened, hit, cancelled and overlapping attacks are distinct; exact partial integrity, multi-quarter hits and both gun roles. |
| Anticipation and systems | Proposed `tests/build_reward_reveal_test.gd`: actual copy notches and consumed copies, mint synergy distinct from piece-colour socket; ≤ 3 rigs and bands; small gate 5 m without gantry; no reward animation hides P1. |
| Discovery and cards | `tests/world_interact_test.gd`: first-use record, no accidental purchase, held target stays locked; `tests/ui_class_card_test.gd`: each pilot's pictured verb agrees with its kit and chosen spine. |

### 6.2 What the corrected stress tool measures

`tools/stress_capture.gd` builds **S1 = one pack, no synthetic telegraphs; S2 = three packs, four of each of four types = 16 synthetic telegraphs; S3 = six packs, eight of each = 32 synthetic telegraphs, plus a Warden whose charge is started and HP preserved**. Each pack is a controller, a punisher and two chasers. The harness grants Rivet every allowed catalogue part plus selected duplicates, holds fire, moves and turns the camera, and replaces defeated fixture enemies throughout sampling. This deliberately exceeds the draft's eight-total-telegraph case. Synthetic threats recycle to keep the scene dense; they do not test damage or successful dodges. Natural attacks remain active. Scene counts distinguish fixture load, total load and threat centres in view; centre-in-frustum is not an edge-visibility test.

After four seconds of scene warmup, record 240 consecutive live frame intervals per scene with no screenshots in that interval. JSON includes per-frame effect and word counts, wall-frame p50/p95/p99/max, process/physics time, renderer CPU/GPU time when available, draw calls and primitives. Zero GPU time means unavailable, not zero cost. Scene replacement cost remains in timings. Each scene then pauses for six renders of the same state: `full`, `full-no-edges`, `no-threats`, `world-only`, `threats-only`, `clean-no-edges`. Particle speed freezes during the capture; visibility restores afterward.

Two overlays are written. `*-occlusion.png` is the older HAZARD-colour diagnostic with sandstone excluded; do not use it as the P1 gate. `*-p1-occlusion.png` isolates edge, keyline, height and motion layers by paired differences. Clean edge/no-edge RGB change ≥ 12/255 defines candidate pixels; retaining < 50% of that contrast in full/full-no-edge marks a loss. Green means retained, magenta lost. This is a contrast-loss proxy; it cannot identify a safe route or prove motion recognition. Unsupported threat painters and fewer than 100 candidate pixels invalidate the P1 result, rather than yielding a false zero-percent pass.

### 6.3 Coordinator commands and expected outputs

Run from this worktree on Andrew's **real Hyprland display**, one GPU job at a time. Do not set `--headless` for capture. The import command is headless and only prepares assets; it does not provide evidence. Runtime storage and caches stay under disposable evidence. `claude-open` launches on workspace 10 without taking focus; explicit `env` arguments carry the artifact directories into the compositor-launched process; inspect the final log and JSON because the launcher returning is not capture completion.

```sh
# Example from a clean worktree on the Linux/PC X11/Wayland compositor:
mkdir -p artifacts/local/stress-v3
export XDG_DATA_HOME="$PWD/artifacts/local/stress-v3/userdata"
export XDG_CACHE_HOME="$PWD/artifacts/local/stress-v3/cache"
export XDG_CONFIG_HOME="$PWD/artifacts/local/stress-v3/config"
"$GODOT_BIN" --headless --editor --import --path sketches/core-loop
claude-open /usr/bin/env XDG_DATA_HOME="$XDG_DATA_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" "$GODOT_BIN" --path "$PWD/sketches/core-loop" --resolution 1920x1080 --log-file "$PWD/artifacts/local/stress-v3/capture.log" --script res://tools/stress_capture.gd -- --out="$PWD/artifacts/local/stress-v3"
```

Expect `stress.json`, 18 source PNGs, six overlay PNGs and optional `contact-stress.jpg` when ImageMagick's `montage` is installed. It quits after three scenes, with a 120 s wall timeout. JSON records source hashes, engine, GPU adapter, display, size, scene validity, raw count samples and timings. No API call, music generation or paid service is involved.

| Gate | Proposed pass band | Coordinator result |
| --- | --- | --- |
| Instrument validity | `reason=done`, `dry_schema_only=false`, `errors=[]`, three scenes, 1920×1080, 240 timing samples each; no script errors in log; live fixtures 4/12/24 and synthetic telegraphs 0/16/32; load valid throughout sampling, not only at capture | Pending display run |
| P1 edge retention | S3 valid differential mask ≥ 100 pixels, no unsupported painters; loss ≤ 15%. Inspect overlay for false matches or time-varying materials. A low/empty mask is inconclusive | Pending |
| Density actually visible | S3 ≥ 12 enemy centres and ≥ 8 hostile telegraph centres in view at capture; record minima/p99 over samples. If below, repair staging and repeat before judging the governor | Pending |
| Effect limits | Every recorded frame within §1.2 and §8 Systems ledger; current tool exposes glyphs, sparkle emitters, bolts, combat marks, speed lines, trail points and prompts. Future zaps/pins/rigs/bands and kill-pop rate require F1's typed ledger; mixed-unit totals are diagnostic only | Pending; v3-only counters not implemented |
| Word limits | `hud_words + world_words ≤ 25`, prompts ≤ 3; all other active text counted by the existing word counter | Pending |
| Frame time, spike | S3 wall-frame p99 ≤ 16.7 ms, quiet GPU, captures excluded | Pending; 240 frames do not qualify ROADMAP 10 |
| ROADMAP 10 qualification | Separate 120 s native traversal, grown combat and boss-peak runs at 1080p on Andrew's PC; each p99 ≤ 16.7 ms | Coordinator hardening wave |

### 6.4 Moving, dense footage is a separate gate

After W11, L1 and the governor/HUD land, record at least 20 s per Warden family at combat density, with camera turning, gun effects, real music and threat SFX audible. Include one early safe exit, one near-miss, one hit, one opening, a partial-integrity hit and an overlapping-threat resolution. Preserve event timestamps beside the clip. Also include a bomb multi-kill, a drop/rebound, a gate choice at 38 m and a dial approached from 30 m. A screenshot sequence without audio cannot pass this gate.

Before coaching, Andrew identifies **safe / bonus / hit**, **open / closed**, and **progress changed / unchanged** at the recorded moments. Target all three Warden reads correct in each family with no class-colour dependence; any confusion returns the relevant shape to revision. Test at normal speed first, then use slow motion to diagnose. A second muted pass checks that shape still carries the fact; an audio pass checks that critical cues survive the mix. `stress_capture.gd` does not create this footage or fabricate these events.

### 6.5 Executed evidence and limits

The supplied spike had never run. Review found telegraphs stopped advancing during timing, fixture kills could empty the load, and the colour mask did not isolate hostile edges. The corrected tool maintains and counts load through sampling and adds the paired P1 metric. Headless control flow passed three scenes with 240 valid interval samples each and no script errors on the final tool. A differential-metric self-test recovered a known 25% loss and rejected an empty mask. Receipts are in `artifacts/local/feel-review/`; the first dry attempt exposed missing asset imports, so checks use an imported disposable project copy under that directory. Coordinator display measurements remain pending. The HUD mock is an executed placement study. Neither artifact proves feel or full v3 readability.

## 7. Audio boundary: preserve the reads

[AUDIO-V3.md](AUDIO-V3.md) owns the music revamp, ACE-Step go/no-go, adaptive arrangement, cue design, loudness and voice budgets. This document makes no bed/stem recommendation and assigns no audio implementation wave. Its instrument columns are feel briefs for Audio to translate into cue IDs, not a second score specification.

Feel-side constraints only: hostile commitment/resolution and imminent collision outrank reward and chain celebration; an opening cue and an evasion cue must remain distinguishable when simultaneous. Never replace or silence a real attack's resolution with a near-miss flourish. Coalesce decorative voices before stealing a warning voice. Suggested starting mix for Audio to measure: duck music/celebration 6 dB under the critical cue with ≤ 20 ms attack and 150–250 ms release, retrigger without gain pumping. Audio may choose different numbers if §6.4's dense moving/audio test passes. Hold the critical cue to its gameplay timestamp; music must not delay it to a beat. Reduced motion and hit-stop-off preserve all audible state information.

## 8. Contracts with Systems, Audio and appearance

Systems owns state and combat extent, appearance owns meshes, Feel owns how those facts remain readable. Renderers read the same authoritative row as mechanics. No decorative transform edits the collider, damage radius, attack timer or momentum.

| System | Visual contract | Source and acceptance |
| --- | --- | --- |
| Sockets and notches | One notch per held copy; dark socket in pair-tag silhouette. Piece-colour pulse means ripe/matching offer; mint joined-glyph pulse means synergy. Armed means the rig silhouette appears in the mast cage. Never infer ripe solely from stack cap | Systems evolution row, including 2-copy and one-copy exceptions; render each state in chase view and at a 30 m sightline |
| Evolution beat | Actual consumed copies detach and the armed rig snaps on during §4.3; pair and heft remain. One named toast, no forced panel; ≤ 3 rigs. The break shares one ≤ 60 ms stop | Systems §10's 120 ms request remains a reconciliation conflict under §3.4; no 120 ms exception without Andrew |
| Drop-gate arches | 5 m tall, no gantry, smaller than break gates; family silhouette, rarity frame and matching-socket cue visible from 38 m before commitment. Only an inspect/stop view adds detail | `reward_gates.gd` small mode and offer rows; moving approach at 20–25 m/s, choose before entry without reading prose |
| Hull rule bands | Three persistent bands above accretion chunks, one per equipped rule. Repeat each band's icon/notch so colour is not the only code; keep pilot and health cracks legible | `ctx.rules`; same icons on Tab's ball and fourth-rule replacement at the chosen-stop hook. Summary shows evolution/rule/bet icon rows |
| Cost, odds and par dials | Readable at 30 m: minimum 32 px projected face or a clamped glyph echo outside the reticle zone. Cost shows wallet versus notch; odds use wedge share; par uses shrinking time arc. Distinct centre glyphs prevent these three quantities looking identical | Authoritative cost/odds/par row; terms and numeric odds disclosed before hold, in calm inspect view. At speed show one selected target and its locked hold gauge |
| Consent at speed | Acquire earlier than 6 m: 0.35 s at 40 m/s already travels 14 m, so the 30 m preview includes the selected target. Keep its glyph and hold progression locked after passing; never steal an already-started mount/grapple action | L3 owns acquisition, lock, cancellation and final consent. Feel depicts that state only. Failed/expired consent must visibly collapse without spending |
| Curse and bet result | HAZARD stripe only for an actual hostile consequence such as the curse band; ordinary player-owned effects stay clean. Win uses W11's crack, loss the dry bone cue; a band cracks off only when the curse actually clears | Bet/curse state; wallet spending never lowers mass/heft. One outcome and one cue per settled bet |
| Variants and leaders | Blessed Warden crown in cage; leader halo in Cherenkov blue plus a distinct crown silhouette, one 1 s edge marker. Flood/squall keeps its actual committed threat geometry | Stage/event state; marker cannot overlap objective, prompts or reticle exclusion |
| Rack and density | Rack attack is one committed threat with body followers, not one warning per drone. One `Density` ledger feeds VFX, bolts and tuning panel; record active counts, shed tier and refused spawns | Systems §1.5 order below; typed counters and per-frame caps tested before increasing population |
| Pilot card, Tab and help | W12 card pictures the actual kit verb: Sable vault/grapple, Rivet sprint/gun, Kest glide/bomb. Tab depicts the chosen loop with return, loot and five Warden states; use the same aperture, evasion and integrity glyphs as play | ≤ 40 words on calm screens; kit and mode supplied by their owners. Cold-read each pilot card; no essay or unsupported promise |

**One shed order.** Ambient P7 is removed first. Then apply Systems' active-effect order: **bolt tails thin → synergy/evolution rings become outlines → pin trails and scrap fountains shorten → drone/rack decorative seams disappear**. Never shed the ball, hostile edges/fronts, window aperture, objective, hold gauge, kicker lips or player committed targeting geometry. A damaging bolt retains its head and trajectory; only its tail thins. Palette changes alone never replace a cap.

The typed ledger carries bodies ≤ 30 at the proposed stage-3 cap, bolts ≤ 64, zap lines ≤ 12, player rings ≤ 8, pins ≤ 12, chunks ≤ 36, rigs ≤ 3 and rule bands ≤ 3, plus §1.2's glyph and spark budgets. Enemy population and damage caps stay with Systems; Feel sheds presentation only. `density` and the current shed step appear on the tuning panel for the sitting. The weighted scalar in §1.2 is a starting proposal; calibrate it against the ledger, not a second independent counter.

The visual track supplies sockets, rig attachment points, cage, dials, hull cracks and bands; each must survive the chase camera without hiding the pilot. Audio receives the §7 priority/ducking contract and the actual event timestamps. Both tracks use the same state rows as HUD and simulation.

## 9. Build waves and file ownership

These are coordinator assignments after the lab decision and build authorization. All paths below are relative to `sketches/core-loop/`; `src/` is written explicitly. A writer receives only its listed files and tests. Exact new filenames are proposed; the coordinator registers them and integration wiring serially. Tests named here that are absent at the supplied base are new files, including the camera, interaction, class-card and Warden-resolution tests. No two writers edit a shared file concurrently, even for separate functions.

**In-flight reservations.** W11 owns `src/presentation/juice.gd`, `src/presentation/vfx.gd`. W12 owns `src/ui/class_card.gd`, `src/ui/field_notes.gd`, `src/ui/help_page.gd`. L1–L3 jointly reserve `src/combat/warden.gd`, `src/core/flow.gd`, `src/core/loop_mode.gd`, `src/world/stage_map.gd`, `src/world/map_spillway.gd`, `src/world/interactables.gd`, `src/ui/world_prompt.gd`, `src/movement/player_ball.gd`; the coordinator retains their individual split. Feel supplies contracts to them and waits for admission before follow-up edits. Audio owns all `music_engine.gd`, `audio.gd`, cue-bank and ACE tooling changes.

| Unit | Exact write set and output | Order and conflict gate |
| --- | --- | --- |
| F0 Evidence tools, now | `tools/stress_capture.gd`, `tools/hud_mock.py`, this document; outputs in `artifacts/local/` | This handoff. Coordinator runs rendered baseline before any governor work; no gameplay writer conflict |
| F1a Density and priority | New `src/presentation/density.gd`; `src/presentation/vfx.gd`; `src/combat/bolts.gd`; `src/combat/threat_grammar.gd`; new `tests/presentation_density_test.gd`; `tests/threat_grammar_test.gd` | After W11. Own the single typed ledger, shed order, fill union and edge priorities. Systems S7 consumes ledger, never rewrites it in parallel |
| F1b Optional escape hint | `src/combat/threat_grammar.gd`; `tests/threat_grammar_test.gd` | Serial after F1a and accepted reachable-safe-arrival data from L1/Systems; default deferred pending §10 |
| F2a HUD foundation | `src/ui/screen_regions.gd`, `src/ui/hud.gd`, `src/ui/ability_bar.gd`, `src/ui/gauge.gd`, `src/ui/heft_dial.gd`; new `src/ui/chain_counter.gd`; `tests/int_screen_layout_test.gd`, `tests/ui_word_budget_test.gd`, `tests/ui_keycap_text_test.gd` | After W11 publishes chain event; parallel with F1a and F3a, disjoint files. W12's three files remain untouched |
| F2b Warden reads and prompts | `src/ui/objective_view.gd`, `src/ui/world_prompt.gd`; new `tests/ui_warden_reads_test.gd`; `tests/world_interact_test.gd` | After F2a and L1–L3. Read accepted resolution/window/integrity and target-lock records; request missing facts from their owner rather than writing `warden.gd` or `flow.gd` |
| F3a Feel profiles and camera | `src/presentation/juice.gd`, `src/movement/chase_camera.gd`; `tests/presentation_juice_test.gd`, `tests/movement_camera_test.gd` | After W11; parallel with F1a/F2a. Implement §3.4 request admission here; coordinator reserves a serial `src/game.gd` follow-up only if other hit-stop callers bypass that gate. Never raise the spine's 60 ms cap |
| F3b Feel settings | `src/ui/pause_menu.gd`, `src/ui/settings_store.gd`, `src/presentation/presentation.gd`, `src/ui/tuning_panel.gd`; `tests/ui_pause_menu_test.gd` | After F1a and F3a; serial against Audio's settings/wiring work. Expose density, shed step and interruption ledger |
| F4a Growth on ball | `src/build/accretion.gd`, `src/presentation/hero_assets.gd`; new `tests/build_reward_reveal_test.gd` | After Systems S1/S3 and appearance have admitted their edits; then sole ownership here for sockets, notches, bands and rig beat. No parallel appearance edits to these files |
| F4b Gate and cage anticipation | `src/build/reward_gates.gd`, `src/core/beacon.gd`, `src/core/upgrade_tree.gd`; new `tests/world_cage_test.gd` | After Systems S2 and its upgrade-tree work, plus loop cage state. Parallel with F4a only on fixed, shared data contracts. A late Systems S8 edit queues behind this unit |
| F5a Discovery and cards | `src/world/interactables.gd`, `src/ui/class_card.gd`, `src/ui/field_notes.gd`, `src/ui/help_page.gd`; `tests/world_interact_test.gd`, `tests/ui_class_card_test.gd` | After W12, L3, Systems bets/variants and F2b; serial with them. First-use pictures, actual kit verbs, 30 m dials and calm inspect disclosure |
| F5b Summary icons | `src/ui/screens.gd`; new `tests/ui_run_summary_test.gd` | After Systems publishes evolution/rule/bet summary records. May parallel F5a with no shared test or source edits |
| F6 Qualification | `tools/stress_capture.gd`; new `tests/threat_visibility_test.gd`; evidence in `artifacts/local/` | After all admitted consumers. Add typed-ledger sampling, run structural tests, display capture and moving/audio reads on the same candidate. Coordinator owns test-runner registration, smoke, native 120 s tests and playtest records |

Shortest schedule: **F0 → admit W11/L1–L3/W12 → F1a ∥ F2a ∥ F3a → F2b ∥ F3b → F4a ∥ F4b when Systems/appearance release files → F5a ∥ F5b → F6**. F4 can start earlier beside UI work if its own gates clear. F1b is optional and serial behind F1a. No Feel music wave remains. These are ownership units, not promises to run all available writers at once.

## 10. Open questions for Andrew

Recommendations are defaults for reconciliation, not recorded owner decisions. The coordinator can bundle these at the lab sitting.

1. **Evolution interruption:** recommend the shared 60 ms cap plus a moving 1.4 s transformation. Alternative: explicitly trial Systems' 120 ms chosen-stop exception. Keep the default until comparative play supports the exception.
2. **Health and chain placement:** recommend hull cracks with the health gauge timed to damage, and chain digits outside the reticle exclusion as mocked. Alternative: always show health and put chain beside heft. Static HUD can proceed with the recommended layout for inspection.
3. **Camera and escape assistance:** recommend bowl yaw assist off by default and defer the escape hint until edge readability is tested. Alternative: opt into both for a short comparison after safe-path data exists. Preserve raw steering in either case.
4. **Power aura:** recommend defer the rim glow until the rig/bands and dense-footage test show a need. Alternative: trial α ≤ 0.18 at heft III. It may never occupy the central 60% or mask hostile cues.

Music questions route to the Audio lead's `AUDIO-V3.md`.

## 11. Every measure mapped to ROADMAP

Row numbers use coordinator `ROADMAP.md` at `494cd44`. Rows 5 and 6 are owned here; the other rows receive evidence, not a second owner. No row is complete on this document alone.

| Measure | ROADMAP row | Pass band / evidence |
| --- | --- | --- |
| Safe resolution, near-miss and hit distinguished; opening has its own shape | 2 Warden; 5 Feel; 6 Readability | Per-threat event cases plus normal-speed dense footage for all three families; §1.6 and §6.4 |
| Truthful Warden integrity | 2 Warden; 6 Readability | Fixed quarter sectors with partial remainder match authoritative integrity after small/large hits and both gun roles; §2.6 |
| Weapon profiles, bombs, drops and rebound | 5 Feel | Profile tests match §3.3; ball momentum unchanged by presentation; Andrew's bomb/drop verdict |
| Cumulative interruption and comfort | 5 Feel; 12 Hand-off | 60 ms event / 100 ms rolling second / 300 ms rolling five seconds, ≥ 250 ms onset gap; settings round-trip; §3.4 |
| FOV, shake, roll and reduced motion | 5 Feel; 6 Readability | FOV ≤ 88°, chaos shake ≤ 0.6, roll ≤ 0.13 rad; measured cues survive reduced motion; §3 |
| Density, shed order, effect counts and threat exemptions | 3 Snowball; 6 Readability | Every-frame typed caps and invariant P0–P3; §1.2 and §8 |
| Dense hostile edge retention | 6 Readability | Valid S3 paired mask, ≤ 15% contrast loss, populated/in-view load; dense moving recognition also required; §6.2–6.4 |
| Overlapping fills, real lane extents and optional safe hint | 2 Warden; 6 Readability | No additive overlap; edges match damage; unverified path suppresses hint; §1.3 |
| HUD safe bounds, action space and keycaps | 6 Readability | Exact §2.5 layout, no forbidden intersections, ≥ 26 px key glyph; mock plus live screenshots at supported scales |
| Fight/calm word count | 6 Readability; 7 Pilot | ≤ 25 / ≤ 40 including numeric tokens and visible prompts; §6.1 |
| Socket/notch, cage and evolution beat | 3 Snowball; 5 Feel; 9 Look | True copies/ripe state, distinguish piece pulse from mint synergy, actual consumed copies, no momentum or threat-read loss; §4 and §8 |
| Gate approach, rule bands, dials, curse and leader reads | 3 Snowball; 4 Discovery; 6 Readability | 5 m small arch readable at 38 m, dials at 30 m, ≤ 3 persistent bands, one rack threat; §8 and moving clip |
| Consent lock and discovery | 4 Discovery; 5 Feel | At-speed hold completes on its locked target; existing mobility is protected; first-use picture, wallet-only spending; §8 |
| Pilot card, Tab, help and summary | 7 Pilot; 12 Hand-off | Pictured kit and chosen loop, identical play glyphs, icon rows for evolutions/rules/bets, Andrew's cold read; §8 |
| Critical-cue audibility | 2 Warden; 5 Feel; 8 Sound contribution | Warning/resolution never replaced by celebration; priority/ducking verified in dense moving audio, Audio owns production decision; §7 |
| Spike frame time | 6 Readability; 10 Performance contribution | 240 live frames/scene, p99 ≤ 16.7 ms at 1080p; no capture overhead in sample, no claim of full performance qualification |
| Final native performance | 10 Performance | Coordinator's separate 120 s traversal/combat/boss runs, each p99 ≤ 16.7 ms, quiet GPU on Andrew's PC |
| Integration and feel verdict | 11 Robustness; 12 Hand-off | Coordinator smoke on admitted candidate, source-hash-bound evidence, Andrew launches and plays; automation never substitutes for his verdict |

## Weight classes (owner direction, 2026-10-11)

`EventJuice.WEIGHT` (`src/presentation/event_juice.gd`) owns impact weight. `EventJuice.WEIGHTED` gives each fact a class or an argument rule, an allegiance and a visual. `EventJuice.weigh(fact, args)` returns the shared record for hit-stop, shake, camera, VFX and sound. Presentation must consume that record together. Impact must never hide a telegraph or change a ring's measured reach.

Start values; `EventJuice.WEIGHT` is authoritative.

| Class | Stop, ms | Shake | Kick, m | FOV punch, degrees | FX scale | Body and pitch |
| --- | --- | --- | --- | --- | --- | --- |
| none | 0 | 0 | 0 | 0 | 0.8 | none |
| hit | `Juice.stop_ms_for(damage)` | 0.1 | 0.1 | 0 | 1.0 | none |
| heavy | `Juice.stop_ms_for(damage, crit, true)` | 0.3 | 0.45 | -4 | 1.4 | `womp`, 0 semitones |
| massive | 55 | 0.4 | 0.6 | -6 | 1.9 | `chunk_low`, -12 semitones |
| climax | 60 | 0.5 | 0.6 | +9 | 2.5 | `chunk_low`, -17 semitones |

Hit and heavy stops read the existing damage band through `Juice.stop_ms_for`. Non-critical damage at 0, 10, 30 and 60 strictly orders all five stops. The strike's `IMPACT.stop` selects its class. Its shake must remain within half to one-and-a-half times that class's shake, with none fixed at zero. Record strength stays in 0..1 and scales shake, kick and FOV punch. FX scale changes particle count and glyph thickness, never damage or telegraph geometry.

| Allegiance | Clamp |
| --- | --- |
| player | The class can request stop, shake and kick. The existing strike whitelist and stop budgets still decide whether a stop lands. |
| motion | Stop is zero. |
| hostile | Stop, shake and kick are zero, including damage taken and player death. |
| reward | Stop is zero. |

Heavier means lower and longer, never louder. Every body layer plays at db 0 through the existing bank and priority trims. The baked `womp` is 0.62 seconds and `chunk_low` is 0.55 seconds at its original pitch. Lowering `chunk_low` by 12 and 17 semitones gives massive and climax longer playback and strictly lower zero-crossing rates than heavy. No new recipe is needed. Listening acceptance still belongs to Andrew.

Class slams must keep distinct bank ids on the frame they share with `slammed`. Three authored cues replace the borrowed voices (coordinator ruling, 2026-10-11):

- `ultimate_landed` uses `ultimate_land`: a class-neutral sub-bass drop under a short Dm7 stab, 1.25 seconds. The class body layer carries the pilot.
- `demo_slammed` uses `kest_demo_knock`: a dry knock followed by three ticking pips, one per mini charge, 0.4 seconds.
- `skid_smashed` uses `rivet_skid_plate`: a short metal scrape into one heavy plate thunk, 0.405 seconds.

Each primary cue lives in `EventKinds.ROWS` and resolves through `Rows.sound`; `WEIGHTED` holds no sound override. The existing `sound_next` ids `kest_falling_triad` and `rivet_snare_flam` stay reserved. The ultimate keeps its cue distinct from a vault kill's `Audio.VAULT_KILL_SOUND` on the same frame. At unshifted playback, `ultimate_land` measures 110.4 zero crossings per second over 1.25 seconds, below and longer than the live shared slam cue returned by `Rows.sound("slammed")`. Both have the same -1 dB bank trim. Andrew's listening verdict on the authored cues remains open. The harpoon smash guard follows `Rows.sound("slammed")`, so a smash plays that cue once, one womp and one crack on its impact frame.

The universal ownership and audibility checks also cover the existing shared facts. Neutral `slammed` uses the authored `core_slam`, a 105-to-55 Hz sweep with a rounded attack and sustained mass; neutral `enemy_rebounded` uses `shell_spring`; Rivet's `cc_ignored` uses `tenacity_choke`. Their primary cues carry no other pilot's voice. `posture_changed` and its presentation sub-fact `posture_break` use the shared `drop_landing`; the sub-fact lives in `UI_ROWS` because it is not a bus signal. `kill_pop` had a -7 dB trim, the minimum correction needed to stay within 6 dB of `slam_boom` when the kill rule resolves to massive or climax; since the percussion remake (13 November 2026) the pop is quieter by nature and its trim is -5. The rebound, ignored-control and posture bindings use existing recipes. Their listening effect still needs Andrew's verdict.

Owner default: the Warden-break freeze rides the player's `posture_break` strike, and `beacon_unsealed` stays a reward with no stop. Andrew may veto this default and amend this page.

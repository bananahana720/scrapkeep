# Core-loop v3: feel and readability

Design for how the game reads and feels in motion and in chaos: the effects grammar, HUD density and hierarchy, camera and feel tuning, anticipation as eye candy, discovery without text, and the checks that measure each. Feel lead, 2026-09-28, on `proto/core-loop-v3-feel` at base 43eeeea. It sets the rules W11 (universal juice), W12 (class card and Tab page), L1 to L3 (lab modes and interactables) must meet, and the layer beyond them. It changes no code; §9 names the waves.

Sources read: `VISUAL-LANGUAGE.md` (§2 to §8, §10), `design-v3/LOOP-REDESIGN.md` (§2 the three reads, §7, §8, §9), `research/R1`, `research/R2`, `DESIGN-NOTES.md` W1, W2, W8, W10; `src/ui/hud.gd`, `screen_regions.gd`, `objective_view.gd`, `word_budget.gd`; `src/presentation/juice.gd`, `vfx.gd` (header), `music_engine.gd` (header, `MUSIC-GEMS.md`); `src/combat/threat_grammar.gd` (header and constants); `src/movement/chase_camera.gd`; the stills `alpha-capture/contact-19fc173.jpg` and `19fc173-seed1/30-pack-mind.png`. Spike results are in §6.5 and §7.3, with paths. §11 maps the measures to the roadmap's definition of done.

**Andrew's words this answers.** "Very sparse and tightly knit" (the HUD). "I was just going around in circles and I don't know if I was dodging" (the Warden). "Juicy feedback", "eye candy" that makes him want "to know what's gonna happen next with these upgrades", "visceral feedback from myself and how I interact with the game", bombs more satisfying, knockback per weapon. The target is a "crazy chaotic mess" in the family of Isaac, Gunfire Reborn, RoR, Hades and Vampire Survivors. His entry-7 rule stands: say at a glance what to press, what hurts and how to grow; icons over words; information timed to need; 25 words in a fight.

**Two facts from the stills that drive everything below.**

1. `30-pack-mind.png`: the Mind's lane telegraph covers the entire bowl floor in HAZARD stripes at fill alpha, its rails run to the horizon across the sky, and nothing marks the escape. The grammar draws each threat correctly on its own (W2) and has no rule for what happens when threats cover most of the frame. The threat is readable; the *exit* is not, which is exactly "am I dodging".
2. `contact-19fc173.jpg`: every HUD element is 34 to 64 px on a 1080p frame, all of it in one 60 px strip at the bottom centre plus one plate at the top. Between them, 800 px of play view carry only the reticle. "Sparse and tightly knit" is literal: little, and all in one knot.

## 1. The chaos-readability grammar

The rule: **a fact that decides the next half second is drawn above and apart from everything that only celebrates the last one.** The screen may fill; what fills it is governed, and what must stay readable is exempt from the governor.

### 1.1 Priority stack

Every drawn thing belongs to one priority class. The class decides draw order (front to back), whether the density governor (§1.2) may touch it, and whether it carries the charcoal keyline. **The keyline is the priority mark**: information wears it, candy never does, so at a glance a keylined shape is one to act on. The threat grammar already keylines every hostile line (W2 note 18); this extends the rule to the reads and the exits and forbids it on effects.

| P | Class | Members | Governor | Keyline | Draw order |
| --- | --- | --- | --- | --- | --- |
| P0 | The ball | Shell, cockpit, pilot, rig stubs, hull damage (§2.2) | never | n/a | world |
| P1 | Hostile committed geometry | Every threat edge, front, bracket reticle, flight trace, height rail; the pulse core ring; a hold's binding | never | yes (exists) | priority 40, no depth test (exists) |
| P2 | The three reads and the exits | The window beam; the near-miss rim flash; the return contraption's lane and gauge; kicker lips; the reach ring's dashed bone | never | yes | priority 39 |
| P3 | Player committed geometry | Skill-shot indicators, the charge gauge ring, the grapple reticle | never | yes | priority 38 |
| P4 | Rewards and pickups | Scrap squares in flight, cores, gate toppers, hoops, interactable glyphs | thinned only past density 0.8 | yes on the topper, none on scrap | priority 30 |
| P5 | Player effects | Hit sparks, kill pops, chain bursts, trails, speed lines, slam rings' afterglow, synergy shockwaves | yes | **never** | priority 20, additive |
| P6 | Hostile area fills and swept ground | The striped 35% fill inside an edge, a wave's 15% swept stripes, a lane's run fill | unioned past 4 overlapping areas (§1.3) | n/a | priority 10 |
| P7 | Ambient | Dust, steam, sparks off the fins, heat shimmer, idle loops | first to go | never | world |

Two consequences the current code does not have. First, P6 sits *below* P5: a hostile fill is a region, and a spark over it costs nothing, but a hostile **edge** (P1) is above every spark. The still's floor-wide stripes would still be there, but the lane's rails, its far cap and the escape (P2) would be drawn over the ball's own effects. Second, P2 is new as a class: the beam, the near-miss flash, the return lane and the lips are what §2 of LOOP-REDESIGN calls the three reads, and they get hostile-grade exemption from the governor.

### 1.2 The density governor

One scalar per frame, `density` in 0 to 1, read by every P5 and P7 emitter from one place (`src/presentation/density.gd`, §9 F1). It never touches P0 to P3.

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
| Hit-stops per 250 ms | 1 | `juice.gd` `HIT_STOP_GAP_MS` 400 | W11 tightens to 250; keep |
| Camera shake sum | 0.6 at density ≥ 0.6, else 1.2 | `chase_camera.gd` clamp 1.2 | §3.1 |
| Toasts | 1 | exists | |
| World prompts | 3 | `MAX_PROMPTS` | exists |
| Edge markers | 3 | exists | |
| Damage numbers | 0 | none exist | shape over digits, and the chain counter is the one number |
| Hostile edges | unlimited | | never governed |
| Hostile area fills drawn | 4, then unioned | none | §1.3 |

### 1.3 Hostile fills at scale: union, and draw the escape

The still's failure is not too little hostile drawing but too much of the same kind with no negative space. Three rules.

1. **Overlap unions.** RR-06 says overlapping fills add no brightness. Extend: past four overlapping hostile areas in view, the fills draw as one union at 35% and each threat keeps only its edge, front, brackets and rail. The edges are the information; the fill is the region.
2. **The escape is drawn.** Whenever hostile fills cover more than 45% of the play view's floor (measured on the projected ground plane, cheap: the union's screen bounds against the lower two thirds of the frame), the nearest clear ground within 12 m of the ball gets a P2 marker: a bone dashed ring, 2 m, keylined, with a chevron from the ball toward it. It is the RR-05 "escape" made explicit for the case where the escape is not obvious. It never says a word. Reduced motion keeps it (it measures position).
3. **Rails stop at the horizon.** A lane's rails and posts draw only to the lane's real length (the far cap) and never past 60 m from the camera. The sky is not a threat.

### 1.4 Colour and shape redundancy (unchanged, restated as the test)

Every fact has two cues; every hostile fact has three, one of them motion. The VL §3 table stands: hostile is HAZARD, 45° stripes, sharp corners, klaxon; yours is class colour, clean, rounded, class instrument; a reward is the rarity ramp plus a frame shape plus a bell; travel and exits are amber, chevron, arpeggio. One addition: **the keyline** (§1.1) is a fourth cue that is pure value, so it survives every vision type and every colour collision the VL §2 table measured (Rivet copper against HAZARD is ΔE 2 to a protanope; the stripes and the keyline carry it).

### 1.5 "I'm a god" without hiding the next threat

Late-run power reads through the **scale of consequence**, never through the count of effects.

- **One bigger shape, not many.** Coalesced kills (§1.2) make one starburst scaled by the count. A six-kill chain is one 2.5× burst with the chain number on it, not six bursts.
- **The rig, not the particles.** The evolved part's rig on the pod (Codex track, LOOP-REDESIGN §8) and the accretion chunks are the standing record of power; they are P0 and never governed. Growth is seen on the ball from across the bowl.
- **The aura.** At heft III or with any evolution live, a class-colour rim glow sits at the frame's edge (a vignette, alpha ≤ 0.18, inner radius 0.78 of the half-diagonal) that breathes with the music's pressure. It never enters the centre 60% of the frame, so it can never sit on a threat. Reduced motion holds it static.
- **The chain counter** (§2.4) is the only number that grows, and it grows in size, not in words.
- **The audio does the rest.** The band's additive layers already climb with pressure (`music_engine.gd`, G10); §8 asks Audio for a "god" layer tied to the chain counter.

## 2. HUD density and hierarchy

### 2.1 Diagnosis, in pixels

At 1920×1080 today: ability slots 64 px, key glyphs 20 px, health tank 190×~14 px, heft dial about 64 px, scrap digits 19 px, speed glyph 34 px, objective icon 34 px with 19 px words, status plate about 160×70 px. The bottom band (`screen_regions.gd` 86% to 100%, 151 px tall) holds one 60 px strip; the top band (0 to 14%) holds two small plates; toasts 15% to 29% (empty most of the time); prompts 62% to 84%. Nothing is wrong with any one element, and the sum reads as a thin frame around an empty middle.

### 2.2 Three rings of attention

The fix is not more HUD. It is putting each fact where the eye already is when it needs it.

| Ring | Where | Carries | Read at |
| --- | --- | --- | --- |
| **The ball** (diegetic, P0) | On the shell | Hull integrity, heft, charges, cooldowns, cloak, the rig stubs | a glance mid-fight |
| **Near the reticle** (world-anchored HUD) | Within 120 px of the reticle | The charge gauge ring (exists), contextual keycaps (exist), the chain counter, the near-miss flash, the drop lead marker | the moment of action |
| **The frame** (instruments) | Top and bottom bands | The precise reads: gauges, the ability bar, objective and drop segments, clock, difficulty, cores | a deliberate look |

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

**Spreads.** The bottom band becomes three anchors on the thirds instead of one strip: health and speed left-centre, the ability bar centre, heft and scrap right-centre. The top band likewise: status left, objective centre, cores right of the objective. The middle stays empty of HUD.

**Timed to need.** The default is *shown*, and the exceptions are where nothing is happening.

| Element | Shows | Fades to |
| --- | --- | --- |
| Ability bar | always | 60% opacity when every slot is ready and none has changed for 3 s; back to 100% on any change |
| Health tank | while hp < 100%, and for 4 s after any change | hidden; the hull carries it |
| Heft dial | always (growth is what Andrew watches) | never |
| Scrap count | for 2 s after any change, always at the bay and when a price is in view | the dial alone |
| Objective plate | always | never |
| Drop segments | always while sealed; grows 44→56 px within 40 m of the Warden | |
| Window echo | the objective icon's ring turns class colour while a window is open | |
| Chain counter | at chain ≥ 3 | gone 1.2 s after the chain breaks |
| Clock and difficulty | always | |
| Toast | one, 1.6 or 2.4 s | |
| World prompt | glyph at 30 m; keycap plus glyph plus ≤ 5 words at 6 m | |
| Edge markers | when the target is off screen | |

### 2.4 The chain counter

Andrew asked for visceral feedback from his own action. The chain counter is that feedback's one number. It sits 90 px up and right of the reticle, mono digits in the class colour with the class shape behind them (ring, chevron or starburst), 28 px at chain 3, growing 2 px per kill to 56 px at 17 and holding. Each kill pops it 1.12 (the good-news overshoot) with the class instrument one rung higher, so the counter is also the scale climbing. A chain breaks after 2.5 s without a kill: the digits fall 20 px and fade, one dry click. It never becomes a word ("COMBO" never appears). W11's kill chains publish `chain_count`; this draws it.

### 2.5 Layout at 1080p with safe zones

Title-safe margins 5% (96 px sides, 54 px top and bottom). Coordinates are the element's box at 1920×1080; UI scale multiplies sizes and re-centres.

| Element | Box (x, y, w, h) | Band |
| --- | --- | --- |
| Status plate (stage pips, clock, difficulty) | 96, 54, 220, 84 | top |
| Objective plate (icon 44, ≤ 5 words, core pips, drop segments as a ring of segments around the icon) | centred, 54, ≤ 640, 64 | top |
| Toast (one) | centred, 168, ≤ 800, 44 | toasts |
| Callout or hold-R meter | centred, 224, 480, 30 | toasts |
| **Reticle exclusion zone** (no HUD, no toast, no prompt) | 760, 340, 400, 400 | play |
| Chain counter | reticle + (90, −90), ≤ 72 | play |
| Edge markers | rim of the play view, 13 to 30 px | play |
| World prompts (3) | 115 to 1805, 670 to 842, 360 each; **never inside 660 to 1260 x** (the floor corridor where telegraphs live) | prompts, narrowed |
| Health tank + speed glyph | 384, 966, 320+40, 40 | bottom left third |
| Ability bar (4 × 80 + 3 × 14) | 799, 950, 322, 110 (keycaps and pips below) | bottom centre |
| Heft dial + scrap | 1216, 950, 96 + 90, 96 | bottom right third |

`screen_regions.gd` changes: `prompts` band 0.62 to 0.78 with a centre exclusion; a new `exclusion` rect for the reticle; three bottom anchors instead of adjacency to the bar. `ui_layout_test` asserts no overlap and no HUD inside the exclusion.

### 2.6 Coexistence in the fight

The drop-segment badge, the window beam, the picks, the chain counter and interactable prompts all appear in the same 20 s. Where each lives, so none collide:

- **Drop segments**: on the objective icon (top centre) as a ring of N segments in the Warden's colour; a landed drop cracks one off with a pop and the reward note. Never on the Warden's body in the HUD sense; the body loses a piece (the shear) in the world.
- **The window beam**: in the world on the core (P2). Its HUD echo is the objective icon's ring turning class colour. No bar anywhere, since open is a state.
- **Picks** (a hoop on a drop line, a gate on the bank): a world prompt, glyph at 30 m, keycap at 6 m, in the prompts band, so they are only ever below the horizon line and off the centre corridor.
- **The chain counter**: near the reticle, class colour, so it cannot be mistaken for a threat or a prompt.
- **Interactable prompts**: share the three prompt slots with gates and hoops, nearest first, so a busy line shows three and the rest wait (exists).
- **Words**: objective 5, toast 4, one near prompt 5, boss name 3, reserve 8. `ui_word_budget_test` stays at 25 with the new elements staged.

## 3. Feel tuning

### 3.1 The camera

What the rig does today (`chase_camera.gd`): FOV 65→82 with speed fraction, arm 7.5→10.5 m, follow rate 6→15, roll up to ±0.13 rad from lateral acceleration, shake up to 1.2 from `impact/30` plus presentation's `shake()`, kicks that spring back at 14/s, FOV punches capped at ±20. It is a good base. What it lacks is behaviour for the drop, the rebound and the bowl, and a governor for chaos.

| Situation | Behaviour | Numbers | Why |
| --- | --- | --- | --- |
| **At speed** (tier 2 to 3) | As today, with FOV capped so the base plus any punch never passes 88 | base 65→80, punch clamp ±12 at tier 3 | 82 + 16 (launch punch) is 98 today, which is a fisheye; comfort and readable edges |
| **Off a lip, descending on a drop line** | The lead marker: a P2 bracket at the predicted landing point (ballistic, the same solve the projectile trace uses), and the pitch eases down up to 12° toward it; arm out to 12 m; FOV +6 | pitch lead 0.6 s ease-out; only while airborne and vertical speed < −8 m/s | the drop is the spine; the player must see the core coming |
| **The landing on the core** | W11's 70 ms hit-stop and −4 FOV punch (the slam profile), then **the rebound whip**: a kick along −velocity of 0.6 (the launch value) and FOV +8 decaying over 0.5 s, yaw left to the player | the whip is one spring, no roll | the rebound must feel like being thrown, and momentum is sacred |
| **In the bowl** (r < `BOWL_OUT`) | A soft look assist toward the mast: when the mouse has been still 0.5 s, yaw blends 25% toward the Warden at 2/s; any mouse input cancels it for 1 s | setting `camera_assist`, default on in the bowl only | "where is it" while circling; the Warden is the room's landmark |
| **Riding the return** | The launch profile (exists: +16 FOV, kick 0.6) with the punch clamp above | | a ride that feels like a ride |
| **In chaos** (density ≥ 0.6) | Shake sum capped at 0.6, kicks at 0.4, no roll from impacts; hit-stop keeps its 250 ms gap | | the camera must not add noise to a full screen |
| **Damage taken** | Never shake (VL §8). W11's read is the hull crack, an iron-oxide vignette 0.25 s and a squash | | shake on being hit is the one thing that makes "did I dodge" unanswerable |

### 3.2 Motion comfort and settings

The pause menu today has only volume rows (W10 note 7: reduced motion did not exist). Add a Feel page with six rows, each a segment slider or a toggle in W10's grammar, stored in `settings.json`:

| Setting | Range | Default | Effect |
| --- | --- | --- | --- |
| Field of view | 60 to 90 | 65 | the base; speed still widens it by the same ratio |
| Camera shake | 0 to 100% | 100% | scales every `shake()` and impact shake |
| Camera roll | on/off | on | the lateral roll |
| Hit-stop | on/off | on | every `request_hit_stop` sends 0 |
| Reduced motion | on/off | off | RR-11: removes celebratory motion, keeps every measured motion |
| Speed lines | on/off | on | P5 speed lines and the tier-3 comet |

Rules that hold at every setting: pitch clamp −1.25 to 0.55 rad (exists), roll ≤ 0.13 rad, total FOV ≤ 88, no camera cut in play, the ball never leaves the frame (follow rate 15 at speed already holds this).

### 3.3 Per-weapon feedback profiles

One table of numbers, the contract W11's implementation must meet and Audio's cue set pairs with. Ordinary hits get no hit-stop (VL §8: momentum is sacred). Knockback is the enemy's, in m/s at heft I, scaling ×1.3 per heft class. The ball's own recoil is a squash, never a velocity change, except the bomb's rocket jump.

| Weapon | Hit-stop | Camera kick | FOV punch | Shake | Enemy knockback | Ball squash | Hit shape | Instrument (Audio) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **Gun** (Rivet laser, Sable arc caster) | 0 | 0 | 0 | 0 | 1.5 m/s, along the shot | 0 | a 0.3 m chevron scorch (Rivet) or a 0.4 m ring flash (Sable), P5 | closed hi-hat tick / one arpeggio note |
| **Bomb** (Kest sticky, demo slam charges) | 0 on stick; 40 ms on a detonation that kills ≥ 2 | 0.25 along blast→ball | +3 over 0.25 s | 0.35 | 9 m/s radial, falls with distance² | 0.15 away from the blast | a starburst 1.5× the blast radius, one bold; scorch marks stay 4 s | low kick drum; pitched down per extra kill |
| **Ram** (contact at speed) | 0 below plating; 40 ms on break-through (exists) | 0.3 toward the enemy (exists) | 0 | 0.35 (exists) | 6 m/s + 0.3 × impact speed, along the ball's velocity | 0.3 along the contact normal | chunk shear on the enemy (VL: a plate pops off), P5 sparks | plate clang, pitched by impact speed |
| **Smash** (Ctrl) | 40 ms on smash-through (VL §8) | 0.35 + 0.35 × strength down (exists) | −4 × strength (exists) | 0.5 | 10 m/s radial from the impact, plus 4 m/s up (they pop) | 0.3 + 0.2 × strength (exists) | the class ring or wedge at the real radius, one bold | root plus fifth (Sable), snare flam (Rivet), floor tom (Kest) |
| **Blast** (F specials: detonation gauge, overdrive blast, detonation line) | 50 ms (the pin-chain value) when ≥ 3 enemies are caught | 0.4 outward | +6 over 0.3 s | 0.6 | 12 m/s radial (gauge), 8 m/s outward (blast), 9 m/s per charge (line) | 0.25 | the full class shape at the drawn extent; everything else in the frame at ≤ 30% | the arpeggio resolving / open hat crash / kick roll |
| **Drop on the core** (the v3 hit) | 70 ms | 0.6 along −velocity (the whip) | −4 then +8 | 0.6 | n/a (the Warden loses a segment) | 0.42 | a segment cracks off the badge and a piece of the god falls | the reward ladder one note up, the spring snap pitched by impact speed |
| **Warden break** | 70 ms (VL §8) | 0 | +9 (exists) | 0.4 | | 0 | the jaws let go, the cage drops (§4) | the unseal drop (G3) |

Knockback per weapon is the ask from entry 8 ("knockback that differs by weapon"): the gun nudges, the bomb throws radially, the ram carries the ball's direction, the smash pops upward, the blast clears a room. Each is a different verb the enemies' bodies write on the floor.

## 4. Anticipation as eye candy

The rule from LOOP-REDESIGN §8: every reward is previewed before it is earned, and every preview is a shape you can already see, never a line of text. Each tease below is one shape, one motion, one sound, one moment it first appears, all from one source row.

### 4.1 The six teases, designed

| Tease | Shape | Motion | Sound (Audio) | First appears | Source row |
| --- | --- | --- | --- | --- | --- |
| **Socket** (a part at cap hints at its evolution) | A dark recess on the part's accretion chunk cut in the pair's family glyph (`cat_` silhouette), charcoal, keylined | Still. When the pair is on offer at a gate or hoop in view, the socket breathes at 0.5 Hz in the rarity colour of the pair (the "* completes *" pulse, moved onto the ball) | a soft sustained hum (the dashed-line sound: future) while breathing | the frame the part reaches cap | `parts.gd` pair row |
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

The one beat in the run that may spend everything. 1.4 s, at the Warden break, once per evolution.

1. 0.00 s: the jaws let go (the unseal drop's downbeat). Hit-stop 70 ms.
2. 0.07 s: the capped part's chunk on the ball flares in the class colour; the socket fills with the pair's glyph, which turns from charcoal to the rarity colour.
3. 0.30 s: the rig grows out of the chunk in one bold animation (the spiral vane unfolds, the arc mast telescopes, the wrecking chain drops and swings), 0.5 s with the back-out overshoot. Everything else on screen at ≤ 30% (VL §8).
4. 0.80 s: the evolved effect fires once, empty, at the drawn extent (the spiral sweeps the bowl, the arc field flickers, the chain whips a circle), so the player sees what it does before they use it.
5. 1.40 s: the class motif resolves on the chord; the codex card lands after (§5.3), naming it for the first time.

## 5. Discovery without text

Learning means experimenting, not reading. Every new thing is taught by shape, motion and consequence, and the codex names it only after the fact.

### 5.1 First-encounter framing

- **No cut, no stop.** The camera never leaves the ball for a reveal. The thing is placed on the loop's sightlines (LOOP-REDESIGN §3) so it is seen on the way, not presented.
- **The glyph at 30 m.** Every interactable, hoop, gate and post shows its family glyph over itself at 30 m (exists in the §9 prompt grammar). The glyph is on a backplate that says its family (VL §5: hex nut, parts tag, warning triangle, brackets).
- **It demonstrates itself once.** The first time a family is in view in a run, the thing runs one empty cycle: the lift fires with its steam puff and arpeggio, a cracked wall's crack glints, a rigged cache's dial spins once and settles, an ambush post's ring pulses once in the enemy colour, a dormant drone's blue seam flickers. The demonstration is the tutorial. Once per family per run, keyed by the interactable row.
- **Consequence is the lesson.** A tap on a hold-to-arm does nothing but fill the ring a little (exists: the gauge ring), so the shape teaches the hold. A refusal is the dry click and the ring collapsing (VL §4 cancel). A miss on a bet is the refusal bone. A landed drop is the segment cracking off. Nothing here is a sentence.

### 5.2 The table: mechanic to shape to consequence

| New thing | Shape says | Motion says | Consequence says | Codex after |
| --- | --- | --- | --- | --- |
| A drop line | Amber kicker lip aimed at the mast, a chevron lane | The lip's chevrons run toward the mast | The ball flies where the lip points; the lead bracket (§3.1) shows where it lands | "Drop line" card with the arc drawn |
| The open window | Dome halves open, the core blazes, the beam stands | The beam shrinks linearly | A drop in the window cracks a segment; outside it, the pulse throws you | the Warden's five states as a ring |
| A near-miss | The rim flashes class colour, the ball streaks | The flash is on the clang | The ratchet went silent: you were never in it | none needed |
| A synergy found | The two parts' glyphs snap together on the chunk | A starburst on the snap | The new behaviour fires once, empty (§4.3 step 4) | the pair named on the card |
| A hold on the ball | A striped binding | Filings drag inward, cords wrap | Speed or a smash bursts it in the class colour with the boost refund | the unit's silhouette and its break |
| A rigged cache | A copper crate with one HAZARD stripe and an odds dial | The dial spins on the hold | Heads: the drum roll ends in a crack and the crate bursts open. Tails: the refusal bone and the crate goes dark | "Rigged cache" with the odds shown as the dial |
| A timed trial | A gate with a par dial over it | The needle runs down while you drop | The gate's topper gains a frame on a make, or the dial goes dark | the par time |
| A dormant ally | A drone on a housing, blue seam dark, cost dial | The seam flickers once on first sight; lit mint when running | It follows and rams what you rebound off; the dial empties your scrap (the heft dial flashes) | "Awaiting operator" |

### 5.3 The codex after the fact

The field notes (Tab) hold the cards. A card is created by the first *use* (not the first sight), with the shape drawn as it was in the world, the family backplate, and at most eight words. It lands with the codex's discovery burst (exists) and the class instrument's note, a beat after the moment, so it never competes with the moment. The "found" toast is zero words: the burst and the bell. Hint cards (evolution pairs, LOOP-REDESIGN §8) show the two glyphs and a socket, never the evolved name, until the evolution has happened once on this profile.

## 6. Measures

Every rule above has a check. Headless where the fact is structural, rendered where it is pixels.

### 6.1 Headless

| Check | Test | Band |
| --- | --- | --- |
| Words in a fight | `ui_word_budget_test` (exists), staged with the v3 elements (drop segments, chain counter, one near prompt, the beam echo) | ≤ 25 |
| Words on a calm screen | `ui_pause_menu_test`, the Feel page added | ≤ 40 |
| Effect budget | new `presentation_density_test`: spawn 30 kills in 200 ms with six threats in view; assert glyphs alive ≤ 40, kill pops ≤ 3 per 250 ms, density ≥ 0.7 and the P5 alpha cap ≤ 0.35 | as §1.2 |
| Governor exemption | the same test: every group `threat` node and every P2 node keeps its alpha at density 1.0 | exact |
| Union | `threat_grammar_test`: six overlapping instant rings; assert one union fill and six edges | exact |
| Escape marker | the same: fills over 45% of the floor rect produce one bone escape ring within 12 m on clear ground | exact |
| Threat visibility, geometric proxy | new `threat_visibility_test`: project every P1 edge polyline to screen (the test camera at the bowl's rim), rasterise P5 glyph screen bounds, count edge samples inside a P5 bound | ≤ 15% of P1 edge samples covered in the S3 scene |
| Camera bounds | `movement_camera_test`: at tier 3 with a launch punch, FOV ≤ 88; roll ≤ 0.13; shake sum ≤ 0.6 at density 0.6 | exact |
| Layout | `ui_layout_test`: no piece in the reticle exclusion; prompts never inside the floor corridor; the three bottom anchors on the thirds | exact |
| Feedback profiles | `presentation_juice_test`: each weapon's hit-stop, kick and punch match §3.3 | exact |

### 6.2 Rendered

Stills and clips come from `tools/alpha_capture.gd` and the spike's `tools/stress_capture.gd` (§6.4). Both need a real display and run off Andrew's screen with `/home/andrew/.local/bin/claude-open <godot> --path sketches/core-loop --script res://tools/<tool>.gd -- --out=<abs dir>` on workspace 10, one capture at a time, and the script quits so the window closes.

| Check | Method | Band |
| --- | --- | --- |
| Threat visibility, pixels | Three stills per scene at one frame: full, threats-only, no-threats. HAZARD-family pixels (hue within 12° of `#ff5a3c`, saturation > 0.5) in threats-only that are not HAZARD-family in full are occluded | occluded ≤ 15% in S3 (six packs, eight telegraphs, a stacked build) |
| Effect count | The same tool logs glyphs alive, threat nodes in view, trail points, speed lines, prompts, HUD words per still | within §1.2 |
| Frame time | 240 frames per scene at 1920×1080, `Time.get_ticks_usec` deltas | p99 ≤ 16.7 ms; draw calls logged |
| HUD scale | A still at 1080p with the v3 layout; every element's box against §2.5 | exact |
| Contact sheet | `montage` 3×3 for a quick look | |

### 6.3 What the research adds (Haiku web scout, 2026-09-28; leads, not verified facts)

- Hades II players report player boon effects hiding enemies and telegraphs on distant views; the shipped fix is enemy sprite opacity, which is the P1-above-P5 rule from the other side (https://steamcommunity.com/app/1145350/discussions/2/4358999171577943234/, page opened).
- Risk of Rain 2's anniversary patch cut screen shake and post-processing and added a screen-distortion toggle and an option to hide money and XP particles, which is §3.2's Feel page and §1.2's P7 (https://www.gamerevolution.com/guides/677329-risk-of-rain-2-anniversary-update-patch-notes, page opened).
- Diablo 4 players ask for outline-only allied AoEs, which is §1.3's union rule applied to the player's side (https://www.icy-veins.com/d4/news/diablo-4-effect-toggles-players-renew-calls-for-this-feature/, page opened).
- A shake rule of thumb: 2 to 3 px for weak hits over 50 to 100 ms, 8 to 10 px for strong over 150 ms, never rotational, always a global slider (https://gt3000.medium.com/juice-it-adding-camera-shake-to-your-game-e63e1a16f0a6, page opened). `chase_camera.gd`'s jitter is `_shake × 0.22` m at the camera, and it adds `jitter.x × 0.1` to roll; §3.1's chaos cap and §3.2's roll toggle cover it, and F3 should drop the jitter-to-roll term.
- Unreal's Niagara guidance: one emitter with a thousand particles beats ten with a hundred, and under 30 active emitters for a stable frame (https://morevfxacademy.com/complete-guide-to-niagara-vfx-optimization-in-unreal-engine/, page opened). The glyph pool is 48 MeshInstance3Ds, which is the coalescing rule's reason on the GPU side too.
- Ghost of Tsushima shows health only with the sword drawn (https://www.gamedeveloper.com/game-platforms/ghost-of-tsushima-design-analysis, page opened): §2.3's timed-to-need table.

### 6.4 What the rendered check cannot prove

Automated stills do not establish feel. The gate to Andrew's play is the §6.1 table green plus one stress still he can look at; his verdict on "did I dodge" is the measure that counts.

### 6.5 Spike results

SPIKE_STRESS_PLACEHOLDER

## 7. Music: ACE-Step and the music-video engine (coordinator's direction, 2026-09-28)

Andrew authorised a revamp of the music within the game's theme and intent: the Spill-B grammar (G11: keep the loved core, escalate on real thresholds, add layers never swap, land the payoff on the moment), gems never lost, motifs in D, jazzy EDM drive, layered in the Pyramids style (G10). The question is whether ACE-Step 1.5 covers (`/home/andrew/Projects/music-video`, read-only) or that repo's engine can raise production quality while the music stays adaptive.

### 7.1 What adaptivity means in the code

`music_engine.gd` is a sample-exact sequencer that mixes pre-rendered notes on a grid it re-tempos and re-keys: fifteen layers with monotonic gain curves against pressure (`CURVES`), re-voicing every four bars (G10), a bass figure that never leaves (G8), the Warden pivot from 172 to 129 BPM through a bar of half-note triplets (G3), a half-step key lift at half integrity and the sinister break at three quarters (G7), Brindle a whole step up and ramping to 150, drops on the next beat after a beat of silence (G9), and the SFX bank sampling in the live key (`samples_at`, G11). Four things a rendered file cannot do: change tempo without a stretch artefact, change key without a shift artefact, re-voice, and land a drop on a gameplay beat that is not on its own grid.

### 7.2 Options weighed

| Option | Quality gain | Adaptivity kept | Key and tempo lock | Loop seams | Disk | Latency | SFX in key |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **A. Per-layer stems from our guides.** Cover each engine layer separately, play them as the engine's layers. | Low. ACE-Step covers a *mix*; covering one layer alone gives it nothing to lock to, and fifteen independently re-performed layers do not sit together (each cover drifts on its own; the music-video README measured seconds of drift within a section). | The gain curves work; re-voicing, re-key and re-tempo do not. | Every (theme × key × tempo) is a separate set: 3 stages × 3 keys × 2 tempos × 15 layers = 270 files at minimum. | Per layer, every file must loop at the same bar. | ~270 × 16 bars × Opus 96 k (~1.5 MB each at 172) ≈ 400 MB. | None at runtime; days of rendering. | Yes (the engine still owns the key). |
| **B. Cover whole themes, Demucs stems as layers.** | Medium: the mix coheres because it was covered as one. Demucs gives four stems (drums, bass, other, vocals): three usable, against fifteen engine layers, with bleed. | Coarse: three faders instead of fifteen; no re-voice; re-key only by pitch shift. | The same combinatorics on key and tempo, on fewer files. | Bar-grid trim plus crossfade; drift measured by the spike. | ~3 stages × 3 keys × 2 tempos × 3 stems ≈ 54 files, 80 MB. | None at runtime. | Yes. |
| **C. Static beds only.** Title, Moss's lounge, the summary. | High where it applies. | Fully: these are not adaptive today. | One key, one tempo each. | Loop once each. | 3 files, ~5 MB. | None. | n/a (no fight SFX under them). |
| **D. Hybrid: cover the core bed, keep the engine live above it** (recommended, if the spike's numbers hold). The engine's drum-and-bass core at pressure 0.6 (keys, sub, hats, kick, snare, bass) is rendered as a guide per (stage, tempo, key) and covered once; the engine keeps its own synth for every melodic and escalation layer, the stingers, the drops and the SFX, playing over the bed on the bed's grid. At the Warden pivot and the key lift the bed crossfades to the next bed on the bar. | High on the thing that most reads as "produced" (drums and bass), which is also the layer that never changes shape (G8). | Everything above the core stays adaptive; the core swaps beds on the bar at the four thresholds. | Per stage: level bed at 172 in D, Warden bed at 129 in D, Warden bed at 129 in Eb (the lift), the sinister break stays synth; Brindle's three beds. About 12 files. | Bar-grid trim with a 20 ms crossfade; the seam sits on the downbeat where the engine drops anyway. | ~12 × 16 bars × Opus ≈ 20 MB. | None; beds preloaded. The pivot's half-note-triplet bar is the engine's, so the bed change lands on its downbeat. | Yes: the engine owns the key and tells the SFX bank; the bed is a fixed-key file chosen to match. |

The fact that decides between B and D: whether a cover holds the guide's key and tempo tightly enough to sit under live synth layers for 16 bars. The music-video findings say cover strength 0.7 keeps bars, chords and drops for a sung guide; an instrumental guide with no vocal anchor was looser (41% word match, chorus 5.9 s off at 0.6). The spike measures drift per bar and key on the Spillway core.

### 7.3 Spike results and recommendation

SPIKE_AUDIO_PLACEHOLDER

## 8. Needs from the other leads and from Codex

**From Systems and Chaos.**
- Every evolution and rule part publishes its *drawn extent* the way threats do (a descriptor with the geometry damage uses), so P3 and P5 can draw it at the real size and the density governor can count it.
- The chain counter's source: `chain_count` and `chain_broken` on the bus (W11 may already publish; confirm the name).
- The pair row on `parts.gd` exposes the pair's family glyph id so the socket can be cut in that shape.
- The rule parts' effects must not be HAZARD or striped even when they turn enemies into hazards ("every rebound is a pin"); a player-caused hazard is amber and clean (the threat grammar's `owned` stance).
- A cap on simultaneous evolved-effect emitters per build (recommend 3) so the budget in §1.2 is meetable.

**From Audio.**
- The instrument column of §3.3 as cue ids, one per weapon per class, pitched as the table says (impact speed, kill count).
- The chain counter's rung climb (one scale step per kill, the class instrument), and a "god" layer in the band that enters at chain ≥ 8 and leaves 2 s after the chain breaks (Spill-B grammar: add, never swap).
- The tease sounds in §4.1: the socket hum, the cage clack and bell, the bracket ratchet, the dial tick, the anvil, the family chord.
- The rarity flourish ladders in §4.2 (one to four bells, the fourth on high D).
- A near-miss whip (a rising class-colour swish) that replaces the clang for a ball that left the ring in time.
- On §7: the bed handoff design if D is chosen (which bar, which crossfade, and how the SFX bank learns the bed's key).

**From the Codex visual track (appearance).**
- Hull damage slots on the three shells (§2.2): plates that crack in iron oxide from the top down, a hinge that sparks below 25%, and cockpit-glass edge frost. The code publishes `hp` share; the track dresses it.
- Charge lamps and the cooldown rest pose on each working device (§2.2), driven by the slot record.
- The rig stubs (bare brackets) and the evolved rigs on the pod (§4.1 bracket, §4.3), plus the socket recesses on the accretion chunks cut in the `cat_` silhouettes.
- The cage on the mast, the salvage-girder look, holding topper frames.
- The interactable props' dials (a bone pressure dial with an amber notch) and the drone housing's blue seam.
- Nothing above uses HAZARD or stripes; the reviewer checklist (VL §10) applies to each.

## 9. Build waves

Each wave is one writer in its own worktree; the coordinator integrates. F1 and F6 first, because every other wave's output is measured by them.

| Wave | Files and seams | Depends on | Tier |
| --- | --- | --- | --- |
| **F1 Priority stack and governor** | new `src/presentation/density.gd` (the scalar, the caps table, `alpha_cap()`, `size_cap()`, `may_spawn(kind)`); `vfx.gd` reads it for every P5 spawn and the trail (after W11 lands, to avoid a seam collision); `threat_grammar.gd` gains the union past four overlapping fills, the escape marker, and the 60 m rail cap; draw priorities per §1.1. Tests: `presentation_density_test`, `threat_grammar_test` additions. | W11 merged | Opus |
| **F2 HUD v3** | `screen_regions.gd` (prompts 0.62 to 0.78 with the centre exclusion, the reticle exclusion, three bottom anchors), `hud.gd` layout, `ability_bar.gd` sizes, `gauge.gd`, `heft_dial.gd`, `objective_view.gd` (drop segments as a ring, the window echo), new `chain_counter.gd`, timed-to-need fades in `hud.gd`. Tests: `ui_layout_test`, `ui_word_budget_test` restaged. | W12 (class card) merged, for the Tab page's seam | Opus |
| **F3 Camera and Feel settings** | `chase_camera.gd` (drop lead, the rebound whip, bowl assist, the chaos governor, FOV clamp), `juice.gd` per-weapon profile table (§3.3) once W11's edits are in, `pause_menu.gd` and `settings_store.gd` Feel page, `presentation.gd` reduced-motion switch. Tests: `movement_camera_test`, `presentation_juice_test`. | W11 merged | Opus |
| **F4 Teases** | `accretion.gd` sockets (the recess and the breathe), `reward_gates.gd` reveal flourishes, `beacon.gd` cage state (frames per core, the drop at the break), `upgrade_tree.gd` bracket state; the props' look is Codex. Tests: `build_reward_reveal_test`, `world_cage_test`. | A8 (evolutions) for the socket's pair | Opus |
| **F5 Discovery** | `interactables.gd` self-demo once per family (after L3 lands), `field_notes.gd` card-on-first-use, the codex burst timing. Tests: `world_interact_test` additions. | L3 merged | Sonnet |
| **F6 Measures** | promote `tools/stress_capture.gd` from the spike, `threat_visibility_test` (the geometric proxy), the frame-time log in `alpha_capture.gd`. | F1 for the numbers to mean anything; the tool itself now | Sonnet |
| **F7 Music beds** (only if §7.3 says go) | `tools/ace_guide.gd` and `tools/ace/` from the spike; `music_engine.gd` bed player (a looped stream under the layers, bar-locked, crossfade on the threshold bars); `audio.gd` bed selection per stage, tempo and key. Tests: `presentation_bed_test` (the seam lands on the downbeat; SFX key equals the bed's key). | Audio lead's handoff design | Opus |

## 10. Open questions for Andrew (recommendation first)

1. **Health on the hull.** (a) Recommended: the hull cracks and the tank gauge hides at full health, showing for 4 s on any change. (b) Both always on. (c) The tank only, as today.
2. **The chain counter.** (a) Recommended: digits near the reticle in the class colour, from chain 3, no word. (b) On the frame beside the heft dial. (c) None; the coalesced burst's size alone.
3. **Bowl look assist.** (a) Recommended: on by default in the bowl only, off elsewhere, a Feel setting. (b) Off by default. (c) Not built.
4. **The escape marker.** (a) Recommended: a bone dashed ring on the nearest clear ground when hostile fills cover 45% of the floor. (b) Always, for any committed threat within 8 m. (c) Not built; edges alone.
5. **The aura.** (a) Recommended: a class-colour rim glow at heft III or with an evolution, alpha ≤ 0.18. (b) Never; the rig is enough. (c) From heft II.
6. **Music beds.** (a) Recommended if §7.3's drift and key numbers hold: hybrid D, covered drum-and-bass beds under the live engine, starting with Spillway. (b) Static beds only (C). (c) Leave the synth as is and spend the effort on SFX.

## 11. Measures against the roadmap's definition of done

`design-v3/ROADMAP.md` (1589f4f) has twelve rows. This design owns row 6 and the production half of row 8, and contributes to rows 2, 5 and 10. Row 8's other half (the score itself: laps, drops and the snowball in the Spill-B grammar, the beat-grid event log, the voice budget, the gem regression test) is the Audio lead's AUDIO-V3; the coordinator assigned row 8 to this doc on 2026-09-28, so the split is stated here and flagged in the hand-back.

| Row | Measure here | Section | Band |
| --- | --- | --- | --- |
| 2 The Warden | The near-miss rim flash and whip; the window beam and its HUD echo; drop segments never chip | §1.1 P2, §2.6, §5.2 | the `warden_window_test` and near-miss test the roadmap names; stills of each state via `alpha_capture.gd` |
| 5 Feel | Per-weapon feedback profiles as one table; knockback per weapon; the drop landing and the rebound whip; damage taken never shakes | §3.1, §3.3 | `presentation_juice_test` matches the table; ball-velocity invariants after a landed drop ≥ 0.6× (LOOP-REDESIGN §4) |
| 6 Readability | Threat visibility in dense stills; the effect budget and the governor; word budgets; HUD hierarchy and density; keycap legibility | §1, §2, §6.1, §6.2 | occluded P1 pixels ≤ 15% in S3; glyphs alive ≤ 40; fight ≤ 25 words, calm ≤ 40; every keycap ≥ 26 px; no HUD in the reticle exclusion |
| 8 Sound (production half) | Covered beds under the live engine, if adopted: the bed's seam lands on the downbeat, the bed's key equals the engine's live key, every gem layer still plays above the bed | §7 | `presentation_bed_test`: seam on the grid within 1 ms; SFX `samples_at` key equals the bed's key; `presentation_gems_test` unchanged and green; beds at −14 LUFS with a −1 dBFS ceiling |
| 10 Performance | Frame time in the dense scene | §6.2, §6.5 | p99 ≤ 16.7 ms at 1080p, 240 frames per scene, S3 |
| 12 Hand-off | The Feel settings page is reachable from the pause menu and the help page names it | §3.2 | `ui_pause_menu_test` rows |

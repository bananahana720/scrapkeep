# Tarn: pilot sheet

Status: historical wave P-C / wave-13 design spec (`cand/alpha-w13` at `22b8bb6`). Check [PILOT-CADENCE.md](../PILOT-CADENCE.md) and `src/` for current implementation and tuning. In this sheet, a number marked **start** was a starting value to tune in play, a line marked **Call** was a creative-charge decision (listed in section 11), paths without a prefix are under `sketches/core-loop/`, and `BIBLE.md`, `adr/` and `docs/` are under the repo root.

**Weapon fire (ruling ek, 22 Nov 2026):** how this pilot's weapon fires, with its timers, damage and first tree pick, is now [PILOT-CADENCE.md](../PILOT-CADENCE.md) section 3.4. Where this sheet's weapon text differs, that page wins.

Settled in the wave-13 session decisions: a 1-2-3 bar plus one ultimate per pilot; snap-back firing; slot 2 is today's F special; slot 3 is the line skill, and Tarn's flavour is **claw drag**; the ultimate is a directed set piece on the line, charged by performance, scaled by heft class; depths 3 and 4 hold ultimate variants; per-pilot machinery on the ball body that reads the kit; cosmetics come only from achievements and discoveries.

**Body direction changed tonight.** The plan settled an open gyro cage. Andrew rejected all 38 open-cage boards on the evening of 2026-10-10; `ROSTER-LOOK.md` §0, the Hoberman mecha, is now the live body direction and supersedes its own cage sections. Section 5 here follows §0. `ROSTER-LOOK.md` is being revised as this sheet is written, so it is cited by section, not by line.

Reads with: [SKILL-BAR.md](../SKILL-BAR.md) (every interface name here is its name), [ROSTER-LOOK.md](../ROSTER-LOOK.md) (§0 the Hoberman mecha, §0.7 its concept set rules, §3 silhouette rules), `BIBLE.md` section 4.3 (`BIBLE.md:319-338`).

**Sources.** Tarn has no passage in `docs/CHARACTER-BIBLE.md`, `design-v2/I1-character-kits.md`, `DESIGN-V2.md` or `SOUND-STORY.md` (a search for "tarn" finds none). `design-v3/DESIGN-V3.md:182` gives one line ("Articulated claw melee"). Tarn's design history is the Bible (`BIBLE.md:135`, `:319-338`, `:412`, `:416`, `:430`, `:776`), the decision rows (`docs/decisions.tsv:117`, `:274`, `:278-280`) and the code. No playtest entry records how Tarn feels (`docs/playtests/PLAYTEST-LOG.md:35` names the kit only). Every number below is untested by a human.

Terms, defined once:

- **Weight**: an enemy's `weight`, which divides every shove (`src/combat/enemy.gd:10-13`, `:303-310`).
- **Tow limit**: the heaviest weight Tarn's claws can move. It grows with heft class (section 2, slot 3).
- **Clamp mark**: an entry in combat's `_clamped` map (`src/combat/combat.gd:230-231`). Claw sweeps on a marked enemy deal x1.5 (`CLAMP_BONUS`, `src/combat/weapons.gd:94`; `combat.gd:1178-1183`).
- **Tow**: enemies the set piece carries behind the ball.
- **Road**: one half of Tarn's tree. The left half is the Rend road (sharpen the claw), the right half the Anchor road (pull, clamp, break free) (`src/core/trees/tarn.gd:3-4`).

## 1. Fantasy

**One line:** a calm tiger mechanic whose machine brings every fight into claw reach: drag it in, clamp it, rend it.

The Bible's Tarn is "deliberate and unexpectedly gentle" and "the machine supplies the aggression" (`BIBLE.md:325`). The kit says the same thing in mechanics: **everything comes to the tiger.** Shift brings Tarn to the fight. Slot 3 brings the fight to Tarn.

### What no other pilot does

| Trait | Tarn | Closest other pilot | The difference |
| --- | --- | --- | --- |
| Weapon reach | Claw sweep, 5 m (`weapons.gd:44`) | Cannon lane 26 m (`weapons.gd:132`), Kest's throw 30 m (`:40`) | The only melee weapon in the roster |
| Direction of force | Clamp drags in (`combat.gd:1449`), rend pulls in (`src/movement/player_ball.gd:917-929`), slot 3 drags in, the set piece tows | Rivet's blast throws the crowd off (`weapons.gd:59-60`); Tally's gather plate pulls toward a plate she places, 4 m over 4 s, no damage (`weapons.gd:102-107`) | Rivet pushes away. Tally arranges a place. Tarn grabs one thing to himself, now. |
| Weight as a rule you see | Light bodies come to Tarn; heavy bodies pull Tarn to them; the limit grows with heft class | Every other pilot meets weight only through how far a shove goes (`enemy.gd:307`) | A yes-or-no read, visible on every drag |
| Line skill | Reverses the reel: the far end comes to the ball | Sable moves herself, Rivet pushes, Kest leaves a charge, Tally clips, the Cannon fires a lane (`SKILL-BAR.md:179-186`) | The only flavour that moves the target toward the pilot |
| Set piece | Carries enemies with it to B | The framework's default tech fires at up to 3 targets per beat and leaves them where they stand (`SKILL-BAR.md:272`) | The catch travels with you. A2-CRITIC checked all six sheets: no other set piece tows, and Rivet's Juggernaut Drive now throws outward, so inward force stays Tarn's. |

## 2. Kit

| Place | Ability id | Name | Fire shape | Core numbers | Kept or new |
| --- | --- | --- | --- | --- | --- |
| 1 (home) | `claw_sweep` | Claw sweep | auto: hold left click | 32 damage, 2 per s, 5 m, knock 8 | kept (`weapons.gd:44-45`) |
| 2 | `clamp` | Claw clamp | gauge: hold, release | ring 4 to 7 m, 14 to 24 damage, mark 1.5 to 3.0 s, cooldown 6.0 s | kept (`weapons.gd:86-95`, `ability_state.gd:66`) |
| 3 | `claw_drag` | Claw drag | tap | drag at 30 m/s to 3 m from the ball, 14 x chain, mark 2.5 s, cooldown 8.0 s | new |
| Shift chip | `claw_pull` | Claw pull | instant | 12 m plant, 24 m/s floor, cooldown 3.0 s | kept (`src/movement/augments.gd:104-108`, `ability_state.gd:65`) |
| Ctrl chip | `rend_slam` | Rend | instant | 9 m inward pull, 26 x strength x 0.8 | kept (`player_ball.gd:48-50`, `:917-929`) |
| Q | `redjaw_rend` | Redjaw Rend | press | snatch and tow, rend landing (section 3) | new |

Class row change (`src/core/class_def.gd:108-114`): `"line_id": "claw_drag"`, `"ultimate_id": "redjaw_rend"`. Everything else in the row stays, including the pitch and `synergy_hooks`.

### Slot 1: claw sweep (kept)

- **Does.** Short heavy bolts: 32 damage, 2.0 volleys per second, 5 m range, speed 140, bolt radius 1.1, knock 8 with a stagger react (`weapons.gd:44-45`; `src/core/event_kinds.gd:260`). It fires through combat's generic path (`combat.gd:1042-1044`). It deals x1.5 on a clamp-marked enemy (`combat.gd:1178-1183`). It is the highest per-hit weapon (`docs/decisions.tsv:274`).
- **Fire shape.** Auto, hold left click. Slot 1 never snaps back.
- **Sees.** Rust sparks at the hit (`combat.gd:1175`). **New (P-D and P-E only):** the two curved claw blades on the weapon ring, which already faces the aim (`ROSTER-LOOK.md` §0.1), swing through the sweep once per volley, so the blades keep time with the weapon at 2 per second. The pilot squeezes the yoke grip triggers. This is the silhouette rule in section 5.
- **Hears.** The weapon cue pitched 5 semitones down (`src/presentation/audio.gd:58`).
- **Kept.** Every number. Nothing in combat changes.

### Slot 2: claw clamp (kept)

- **Does.** A ring under the ball, radius 4 to 7 m by gauge fraction. Every enemy inside is dragged toward the ball (knock 10, `event_kinds.gd:261`), takes 14 to 24 damage times weapon-damage tuning, and carries a clamp mark for 1.5 to 3.0 s (`weapons.gd:86-95`; `combat.gd:1429-1453`).
- **Fire shape.** Gauge, full at 0.8 s (`ability_state.gd:66`), auto-fire after the 0.5 s grace (`SKILL-BAR.md:91`). Cooldown 6.0 s, 1 charge. On the bar: press 2, hold left click to grow the ring, release to clamp. The selection snaps back to 1 on the release.
- **Sees.** The ring draws through `yours()`, so it takes Tarn's colour and cross ticks (`player_ball.gd:341-344`; `class_def.gd:111`). **New (body only):** both hooked claw arms open with the gauge fraction and snap inward on the release, and the pilot throws the clamp lever in the lever bank beside the right yoke (`ROSTER-LOOK.md` §0.7).
- **Hears.** The taps build as the gauge fills and the release is `tarn_latch_tear`, the long low A (`audio.gd:88`; `src/presentation/harmony.gd:127-128`, `:135`).
- **Kept.** All of it. **Call:** no rule change, so `tests/tarn_kit_test.gd` cases f, g and i (`:248-396`) stay green unchanged.

### Slot 3: claw drag (new line skill)

ABILITIES row: `"claw_drag": {"icon": "ab_tarn_line", "cooldown": 8.0, "line": true, "load_seconds": 4.0}`. No `charge_max`, so it is a tap. **Call:** a tap, so Tarn's bar holds three distinct fire shapes (hold, gauge, tap).

| Field | Value |
| --- | --- |
| `id`, `icon`, name | `claw_drag`, `ab_tarn_line`, Claw Drag |
| fire shape | tap: commits on the left-click press (`SKILL-BAR.md:90`) |
| cooldown, charges | 8.0 s, 1 (framework default) |
| `load_seconds` | 4.0 (framework default) |
| `on_body`, light target | the claw rides the cable to the target (0.1 s bite), then drags it along the line at 30 m/s (start) until it stands 3.0 m in front of the ball, inside the 5 m sweep reach. At most 1.5 s (45 m `rope_range`, `src/movement/tuning.gd:18`). On arrival: 14 x `chain.multiplier()` damage (claw kind), and a clamp mark for 2.5 s. Any other enemy within 1.0 m of the dragged body's path is shoved aside, knock 10, no damage. |
| `on_body`, heavy target | weight above the tow limit: the target does not move. The claw bites it (14 x chain damage, clamp mark 2.5 s) and the ball gets the framework's `reel_burst`, +8 m/s toward it (`SKILL-BAR.md:165`). The drum spins the other way and the ball lurches in. What the tiger cannot move, it climbs. |
| `on_world` | the claw rips a slab (1.0 m, Tarn's claw-scored panel motif, `ROSTER-LOOK.md` §0.2) out of the wall or post and drags it down the line at 30 m/s. Every enemy within 1.2 m of the line between anchor and ball takes 16 x chain damage and knock 14 toward the ball. The slab breaks into debris 3 m from the ball. The ball does not move. **Call:** this replaces the default `reel_burst`, so a wall latch is the world coming to Tarn too. |
| chain scaling | yes, `chain.multiplier()` at the moment it fires (`src/combat/chain.gd:49`) |
| committed geometry | at commit, the drag corridor from the far end to the arrival point (half width 1.0 m for a body, 1.2 m for a slab) draws through `yours()` for 0.1 s before the drag starts, then shrinks behind the moving target. It is exactly what can be hit (`adr/TADR-008-ability-contract.md:38`). |
| ground contact | none: the ball never leaves the air because of it, so it neither ends nor extends a chain |
| line cut mid-drag | the drag stops that tick. The target keeps its momentum and gets no clamp mark: no cable, no pull. This gives the Dig's drill crew and the Highdraft's line cutter a real answer to Tarn (`design-v3/HOOK-CHAIN.md:36`). **Call.** |
| Warden and boss | never moved (Warden weight 1000, `src/combat/warden.gd:123`). The claw bites and slips: slate sparks and the low clank, the glance read (`design-v3/LEGIBILITY.md:50`). The hit fills posture as a gun bolt does, base 1.5 (`LEGIBILITY.md:85`). No clamp mark. The ball gets the reel burst. On Brindle, the Waking and the Mind, the brace pose and the "nope" glyph (`SKILL-BAR.md:308`). |
| sound | new row `line_claw_drag` in `KEYED_SOUNDS`: the drum ratchet (`clank`, the class sound, `class_def.gd:111`), then Tarn's motif across the drag: D3 on the bite, D3 as the drag starts, Eb3 in travel, the long A3 on arrival (`harmony.gd:135`). It rises one rung of the pentatonic per chain link, like `chain_link` (`HOOK-CHAIN.md:26`). |
| card line | "Drag what you bite into claw reach." (7 words) |
| codex | `tarn_claw_drag`, section 8 |
| clip | `cast_line`, 0.8 s (section 6) |

**How the drag moves a body.** Combat re-applies a knock toward the arrival point every physics tick for the drag's duration, with force 30 x the target's weight, so every draggable body travels at the same speed (`enemy.gd:307` divides by weight). Knockback overrides an enemy's own movement while it is above walking pace (`enemy.gd:452-465`). The gather plate already pulls this way every 0.2 s (`combat.gd:1661-1672`). No change to `enemy.gd`.

**Tow limit, one source.** `tow_limit(heft_class) = 1.0 + 0.5 x heft_class` (start). Slot 3, the set piece and its variants all read it. The claw arms' reach reads the same heft class (section 5), so the longer claws you see are the heavier machines you can move.

| Heft class | I | II | III | IV | V |
| --- | --- | --- | --- | --- | --- |
| Tow limit | 1.5 | 2.0 | 2.5 | 3.0 | 3.5 |
| Newly draggable | kite drone 0.7, chaser 1.0, mag trapper 1.2, burrower 1.4, hooker 1.5 | anchor crew 2.0, deflector 2.0 | mind hand 2.5 | drill crew 2.6, lobber 3.0, plated brute 3.0 | none new; reactor relic 4.0, miniboss 5.0 and Wardens never |

Weights: `kite_drone.gd:35`, `chaser.gd:60`, `mag_trapper.gd:32`, `burrower.gd:39`, `hooker.gd:30`, `anchor_crew.gd:28`, `deflector.gd:47`, `mind_hand.gd:65`, `drill_crew.gd:36`, `lobber.gd:47`, `plated_brute.gd:48`, `reactor_relic.gd:33`, `miniboss.gd:26`, all under `src/combat/`.

### Shift: claw pull (kept)

- **Does.** Plants a claw where the aim meets the world within 12 m and pulls the ball toward it at the larger of its planar speed and 1.5 x the dash floor (16 m/s, `tuning.gd:15`), so at least 24 m/s, with at least 2 m/s of lift. It lands as a ram (`augments.gd:104-108`, `:281-302`; ram knock 24, `augments.gd:70`). Cooldown 3.0 s (`ability_state.gd:65`).
- **Fire shape.** Instant on Shift. A verb chip, never selectable (`SKILL-BAR.md:38`).
- **Sees.** The hooked claw arm on the aim side shoots out from its side hub, and the pull drum low at the rear winds in (`ROSTER-LOOK.md` §0.2; today's nodes at `tools/blender/shell_tarn.py:120-129`). The pilot stamps both pedals, the Shift control (§0.7).
- **Kept.** All of it, and the tree nodes that build on it (for example the `dashed` procs at `tarn.gd:9-10`, `:32-33` and `:59-60`).

### Ctrl: rend (kept)

- **Does.** The shared slam strikes within 9 m, then the rend pulls every enemy within 9 m inward at 26 x strength x 0.8, where strength is speed / 30 clamped to 0.4 to 1.6. It strikes nothing a second time (`player_ball.gd:48-50`, `:891-902`, `:917-929`; `augments.gd:66-68`).
- **Sees.** If the fold extra is on (`ROSTER-LOOK.md` §0.5, off by default), the lattice folds about 8% on the landing and springs back over 0.25 s. Both claw arms hook inward from `RendContact` (`shell_tarn.py:130`) either way.
- **Kept.** All of it; `tarn_kit_test.gd` case h (`:327-353`) stays.

**Three inward pulls, on purpose.** Clamp, rend and claw drag all bring enemies in. They differ in reach and payoff: the clamp catches a ring around the ball and marks it; the rend gathers a landing area and marks nothing; the drag brings one far target and marks it. That is Tarn's identity, not a duplicate across pilots. It is on the veto list in case it reads as one mechanic three times.

## 3. The ultimate: Redjaw Rend

The Bible's ultimate: "Successful committed contacts and useful holds earn an expanded grapple-and-rend sequence. Its moving claws define the danger area; debris follows the action rather than hiding it" (`BIBLE.md:336`). Redjaw Rend is that sentence on the framework's set piece. The name takes the Redjaw Workshops, Tarn's engineering tradition (`BIBLE.md:135`).

```
 wind-up 0.35 s           flight: one beat, one claw over claw                 landing
 both claw arms close      beat 1: R arm grips the line, L snatches (10 m)      tow dropped at B
 on the line ahead         beat 2: L arm grips, R snatches (10 m)               rend: pull inward
                           peak:   weapon ring spins, tow swings a 5 m ring     clamp marks 3.0 s
 A ================================================================> B
       tow: light bodies only, up to 2 + heft class, held 3 m behind
```

### The contract (`SKILL-BAR.md:312-326`)

| # | Item | Redjaw Rend |
| --- | --- | --- |
| 1 | id, name, icon | `redjaw_rend`, Redjaw Rend, `ab_tarn_ult` |
| 2 | `paths` | `["line", "rail", "arc"]`, the default order, no reach override. On a line Tarn climbs the cable claw over claw. On a rail the claw arms grip the rail. On an arc the arms tuck and the tech still runs. |
| 3 | tech per beat | the free claw arm alternates: right on odd beats, left on even. It snatches up to 2 enemies within 10 m on its own side (a half disc), targets within 25 degrees of the reticle first. Each snatch deals 12 x heft multiplier (claw kind). A body at or under the tow limit joins the tow; a heavier one takes the damage only and the claw slips. Towed bodies hang 3 m behind the ball, alternating sides 1.5 m apart, re-knocked each tick like the drag. Each takes 4 damage per beat. A towed body shoves aside any enemy it passes within 1.5 m (knock 10, no damage). |
| 4 | peak | the middle beat: both claw arms open full span, the weapon ring and its blades spin one full turn, and the tow whips round the ball with them. A 5 m ring deals 18 x heft to every enemy in it that is not in the tow, knock 14 outward. Strike clip. |
| 5 | landing | the framework's 60 x heft x `chain.multiplier()` within the class landing radius (6 to 10 m), but the knock points **inward**, like the rend: 26 x 0.8 = 20.8 (`player_ball.gd:50`, `augments.gd:68`). Towed bodies drop at the centre and take the landing damage x1.25. Every enemy hit that is not a Warden or a boss gets a clamp mark for 3.0 s, so the first sweeps after recovery deal x1.5. The landing ends the chain (framework). |
| 6 | heft scaling beyond the default | tow limit 1.5 to 3.5 (table above); tow cap 2 + heft class |
| 7 | music | below |
| 8 | body | ready: the claw tooth edges glow (the `class_accent` slot, the only light on the mecha) and the claw arms flex once a second with the 1 Hz breathe. Wind-up: if the full-span extra is on (`ROSTER-LOOK.md` §0.5, off by default), the lattice opens to full span, about 1.15 times its rest size, and the hub modules lock out; otherwise the lattice stays at rest size. Both claw arms close on the line ahead. Flight: the arms alternate grips on the beat, a visible metronome. Peak: the weapon ring spins one turn. Landing: if the full-span extra is on, the lattice folds back. Both arms hook inward. |
| 9 | clips | `ult_ready` 0.6 s, `ult_windup` 0.35 s, `ult_strike` 0.6 s, `ult_recover` 0.8 s (section 6) |
| 10 | depth 3 | `rake_run` and `vice_leap` (below) |
| 11 | depth 4 | the four framework knobs, one per depth-4 node (below) |
| 12 | Wardens and bosses | table below |
| 13 | card, discovery, run log | card "Climb the line, tow them, rend." (6 words); discovery `tarn_redjaw_rend`; run-log `ultimates[].id` is `redjaw_rend` |

**Budget check.** A full beat is 2 snatches x 12 plus 3 towed x 4, so 36 damage per beat at class I. The framework's default tech is 3 targets x 12 = 36 (`SKILL-BAR.md:272`). Tarn spends the same budget differently.

### Heft class

| Heft class | I | II | III | IV | V |
| --- | --- | --- | --- | --- | --- |
| Damage multiplier (framework) | 1.00 | 1.15 | 1.30 | 1.45 | 1.60 |
| Landing radius (framework) | 6 m | 7 m | 8 m | 9 m | 10 m |
| Tow limit | 1.5 | 2.0 | 2.5 | 3.0 | 3.5 |
| Tow cap | 3 | 4 | 5 | 6 | 7 |

The set piece never spends heft (framework). A heavier ball hauls a bigger, heavier catch.

### Wardens and bosses

Tarn's kit already shortened the posture bands once (`docs/decisions.tsv:280`: small 58.3 s against 82.4 recorded). So Tarn's set piece adds nothing to Wardens beyond the framework defaults.

| Target | Snatch | Tow | Landing | Read |
| --- | --- | --- | --- | --- |
| Warden, guard closed | half damage; posture as gun bolts, base 1.5 (`SKILL-BAR.md:305`) | never | framework: up to 45 posture once, cannot crack or shatter; no clamp mark | the claw slips: slate sparks, low clank |
| Warden, core open | as above | never | shatters the chunk (framework, `LEGIBILITY.md:87`) | the normal shatter |
| Warden as anchor (wave K-F) | a `line` path may end on it; landing on it is the drop finisher (framework) | never | as above by guard state | as above |
| Brindle, the Waking, the Mind | x0.5 | never | x0.5; phase windows untouched; no clamp mark | brace pose and the "nope" glyph |

**Call:** the clamp mark never lands on a Warden or a boss from slot 3 or from the set piece. Today's slot-2 clamp is untouched.

### The music moment

Tarn's motif is D3, D3, Eb3, then a long A3 on the reese voice (`harmony.gd:135`). The code's own gloss: "Tarn's taps test the latch and the long low A tears it loose" (`harmony.gd:127-128`).

| Moment | What plays |
| --- | --- |
| meter full | the framework lift, and `tarn_ready` with the motif's notes an octave up plus the small bell (`SKILL-BAR.md:222`) |
| wind-up | the framework's launch build (`SKILL-BAR.md:287`) |
| each tech beat | one tap on reese, cycling D3, D3, Eb3: the claws testing the latch |
| peak | the long A3 on reese, doubled an octave up on the `fbass` band voice (`band_octave` 12, `harmony.gd:135`): the tear |
| landing | the framework's drop on the beat. The A resolves to D, the band's home (`SOUND-STORY.md:31`): the latch torn loose and set down |

All of these are keyed sounds, so they follow a Warden lift into Eb (`SOUND-STORY.md:71`).

**Observation (inference).** Tarn's first three notes are the Fleet motif's first three, D3 D3 Eb3 (`harmony.gd:138`). The Fleet falls back to D; Tarn tears loose to A. Tarn "signed on the day Brindle fell" (`src/core/achievements.gd:39`). **Call, separable extra:** when Redjaw Rend lands on Brindle, the peak plays the Fleet's brass D D Eb first and Tarn's A answers it. It is hidden and changes no gameplay (the standing OK for mechanic callbacks).

### Depth 3: two variants, one per road

`depth_cap(world_index)` is `clamp(world_index + 1, 2, 4)` (`src/core/upgrade_tree.gd:119-120`), so depth 3 opens in world 2.

**Call:** every one of Tarn's eight depth-3 nodes swaps the set piece. The four on the Rend road swap to Rake Run; the four on the Anchor road swap to Vice Leap. Each node keeps its existing op as well. So every build changes its set piece in world 2 (the plan's "by world 3 a build changes its set piece"), and the depth-1 pick decides which one.

| | Redjaw Rend (default) | Rake Run (Rend road) | Vice Leap (Anchor road) |
| --- | --- | --- | --- |
| id | `redjaw_rend` | `rake_run` | `vice_leap` |
| What changes | | the tech | the path type, and the tow becomes a throw |
| `paths` | line, rail, arc | line, rail, arc | arc, line, rail |
| Tech per beat | snatch 2, tow behind | no snatch, no tow. Both ring blades rake: a strip each side of the path, 3 m wide, offset 0.5 m from the path, one beat's travel long (about 6.3 m at 18 m/s and 172 BPM, `SOUND-STORY.md:31`). 10 x heft to every enemy in a strip, no target cap. **A2-CRITIC:** each raked enemy is dragged 2 m in toward the path (knock 6, the gather pull, `combat.gd:1661-1672`) and takes a 1.5 s clamp mark, in place of the draft's knock 8 outward. The rake now brings the fight to the tiger, and the landing rend finds a marked row. Rivet's Juggernaut Drive throws outward, so the two corridors push opposite ways. Claw marks stay drawn on the ground for 2 s. | the free claw arm snatches up to 2 within 10 m and hurls each toward B, timed to land as the ball does. A body over the tow limit takes the snatch damage only. |
| Peak | the tow swings a 5 m ring, 18 x heft | crosscut: both ring blades cross forward, two lanes 10 m long and 1.5 m wide ahead of the ball at plus and minus 20 degrees, 24 x heft | the vice opens: the landing area (class radius + 2 m) draws on the ground and pulls every enemy inside toward its centre every 0.2 s, knock 6 (the gather loop, `combat.gd:1661-1672`) |
| Landing | rend inward, tow dropped x1.25, marks 3.0 s | rend inward, then a 3.0 s sweep frenzy: the existing `overdrive`, sweeps at x1.6 rate (`weapons.gd:64-65`) | 60 x heft within class radius + 2 m, inward 20.8, hurled bodies x1.25, marks 4.0 s |
| Music | taps D D Eb, peak long A | the taps doubled as sixteenth pairs on each beat: the rake | one tap per snatch; the long A held from the peak to the landing; the drop lands an octave lower |
| Body | claw arms alternate grips | the ring blades held out level to both sides at the equator; sparks fly where the strips cut the ground | both claw arms plant behind at the wind-up, the launch; then snatch and throw forward |
| Plays well with | the clamp and the sweep | the Rend road's sweep upgrades, through the frenzy | the Anchor road's clamp and pull upgrades, through the marks |

ABILITIES rows (B3 adds whatever other keys its `ult_default` row carries):

```gdscript
"redjaw_rend": {"icon": "ab_tarn_ult", "cooldown": 0.0, "paths": ["line", "rail", "arc"]},
"rake_run": {"icon": "ab_tarn_ult", "cooldown": 0.0, "paths": ["line", "rail", "arc"]},
"vice_leap": {"icon": "ab_tarn_ult", "cooldown": 0.0, "paths": ["arc", "line", "rail"]},
```

The tree card shows the variant through its depth notch (`upgrade_tree.gd:167-173`), so one icon id serves all three.

**Depth-3 node edits** (`tarn.gd:22-39`, heap indices 6 to 13). Each keeps its id, name, key, icon, tags and op, and gains one op. The effect text is rewritten to fit both inside the 8-word cap (`upgrade_tree.gd:50`).

| Index | Node | Road | Op kept | Op added | New `effect` (words) |
| --- | --- | --- | --- | --- | --- |
| 6 | `t_raking_claws` | Rend | `pattern` claw_sweep | `"swap": {"ultimate": "rake_run"}` | "Third talon rakes wider. Q: Rake Run" (7) |
| 7 | `t_rip_through` | Rend | `pattern` claw_sweep | `"swap": {"ultimate": "rake_run"}` | "Sweeps tear a neighbour. Q: Rake Run" (7) |
| 8 | `t_frenzy` | Rend | `proc` slammed, overdrive | `"swap": {"ultimate": "rake_run"}` | "Rend slams start a frenzy. Q: Rake Run" (8) |
| 9 | `t_wide_swipe` | Rend | `pattern` claw_sweep | `"swap": {"ultimate": "rake_run"}` | "Wider sweeps catch more. Q: Rake Run" (7) |
| 10 | `t_pounce` | Anchor | `proc` dashed, air | `"swap": {"ultimate": "vice_leap"}` | "Pulls refund your air jump. Q: Vice Leap" (8) |
| 11 | `t_stalker` | Anchor | `proc` enemy_killed, refund_move | `"swap": {"ultimate": "vice_leap"}` | "Kills recharge claw pulls. Q: Vice Leap" (7) |
| 12 | `t_double_clamp` | Anchor | `charges` special | `"swap": {"ultimate": "vice_leap"}` | "Stock two clamps. Q: Vice Leap" (6) |
| 13 | `t_break_free` | Anchor | `proc` hold_broken, refund_special | `"swap": {"ultimate": "vice_leap"}` | "Breaking free recharges clamp. Q: Vice Leap" (7) |

### Depth 4: one knob per node

Depth 4 opens in world 3. Every one of the sixteen depth-4 nodes keeps its op and gains one of the four framework knobs (`SKILL-BAR.md:332`). The two children of each depth-3 node get different knobs, so the depth-4 pick is a set-piece choice too. Only the four shared knobs are used, so the six P-C units never add rows to `KNOBS` (`upgrade_tree.gd:54-76`) at the same time.

How Tarn's set pieces read each knob (values follow B3's defaults: 0, 0, 0.0 and false):

| Knob | Node value | Framework meaning | Rake Run | Vice Leap |
| --- | --- | --- | --- | --- |
| `ult_beats` | 2 | +2 flight beats | 2 more rake beats | a longer arc, 2 more snatch beats |
| `ult_volley` | 1 | +1 target per volley | strips 3.0 m to 4.5 m wide | 3 snatches per beat instead of 2 |
| `ult_radius` | 2.0 | +2 m landing radius | landing radius + 2 m | vice radius + 2 m more (class radius + 4 m) |
| `ult_encore` | true | a second leg if a target sits within 30 m of the landing | a second Rake Run on a line to it | a second Vice Leap arc onto it |

| Index | Node | Parent | Op kept | Knob added | New `effect` (words) |
| --- | --- | --- | --- | --- | --- |
| 14 | `t_flurry` | `t_raking_claws` | `pattern` rate | `"ult_beats": 2` | "Sweeps 30% faster. Q lasts longer." (6) |
| 15 | `t_crosscut` | `t_raking_claws` | `pattern` arms | `"ult_volley": 1` | "Talons split three ways. Q rakes wider." (7) |
| 16 | `t_carve` | `t_rip_through` | `pattern` chain_jumps | `"ult_volley": 1` | "Tears hop once more. Q rakes wider." (7) |
| 17 | `t_feeding_frenzy` | `t_rip_through` | `proc` enemy_killed, overdrive | `"ult_encore": true` | "Kills start a frenzy. Q can go twice." (8) |
| 18 | `t_shock_rend` | `t_frenzy` | `proc` slammed, blast | `"ult_radius": 2.0` | "Rend slams send a shockwave. Q lands bigger." (8) |
| 19 | `t_aftershock` | `t_frenzy` | `proc` slammed, grant_move | `"ult_encore": true` | "Rend slams refill pulls. Q can go twice." (8) |
| 20 | `t_maul` | `t_wide_swipe` | `pattern` range, knock | `"ult_radius": 2.0` | "Sweeps reach and hurl harder. Q lands bigger." (8) |
| 21 | `t_sweep_volley` | `t_wide_swipe` | `proc` slammed, volley | `"ult_volley": 1` | "Rend slams fire two sweeps. Q rakes wider." (8) |
| 22 | `t_leap_strike` | `t_pounce` | `proc` dashed, volley | `"ult_volley": 1` | "Claw pulls fire a sweep. Q grabs more." (8) |
| 23 | `t_long_haul` | `t_pounce` | `charges`, `cooldown` movement | `"ult_beats": 2` | "Three faster pulls. Q lasts longer." (6) |
| 24 | `t_relentless` | `t_stalker` | `charges` movement | `"ult_encore": true` | "Stock a third pull. Q can go twice." (8) |
| 25 | `t_blood_rush` | `t_stalker` | `proc` enemy_killed, refund_special | `"ult_radius": 2.0` | "Kills recharge your clamp. Q lands bigger." (7) |
| 26 | `t_crusher` | `t_double_clamp` | `proc` special_used, blast | `"ult_radius": 2.0` | "Clamps send a shockwave. Q lands bigger." (7) |
| 27 | `t_clamp_fever` | `t_double_clamp` | `proc` special_used, overdrive | `"ult_volley": 1` | "Clamps start a sweep frenzy. Q grabs more." (8) |
| 28 | `t_snap_back` | `t_break_free` | `proc` hold_broken, blast | `"ult_encore": true` | "Breaking free blasts back. Q can go twice." (8) |
| 29 | `t_unbroken` | `t_break_free` | `proc` hold_broken, grant_move | `"ult_beats": 2` | "Breaking free refills a pull. Q lasts longer." (8) |

Node shape after the edit, in the file's existing vocabulary:

```gdscript
{"id": "t_raking_claws", "name": "Raking Claws", "effect": "Third talon rakes wider. Q: Rake Run", "key": "weapon",
	"icon": "ab_tarn_weapon", "tags": ["close"],
	"pattern": {"claw_sweep": {"add": {"count": 1}, "min": {"spread_deg": 12.0}, "mul": {"damage": 0.8}}},
	"swap": {"ultimate": "rake_run"}},
{"id": "t_flurry", "name": "Flurry", "effect": "Sweeps 30% faster. Q lasts longer.", "key": "weapon",
	"icon": "ab_tarn_weapon", "tags": ["close", "sustain"], "pattern": {"claw_sweep": {"add": {"rate": 0.6}}},
	"knob": {"ult_beats": 2}},
```

Depths 1 and 2 (`tarn.gd:7-20`) are unchanged.

## 4. Three worlds

Tarn unlocks by routing Brindle (`achievements.gd:38-39`; `class_def.gd:113`), so a normal profile first plays Tarn on a run after world one has been beaten once. Under `--profile=sitting` Tarn is open from the first run (`SKILL-BAR.md:618-623`).

| World | Depth cap | What the kit adds | Enemies and the weight rule | The identity line |
| --- | --- | --- | --- | --- |
| 1, Spillway Works | 2 | The whole bar from the drop: sweep, clamp, claw drag, claw pull, rend, and Redjaw Rend once the meter fills (it starts empty, `SKILL-BAR.md:211`). Depth 1 picks the road: Long Claw (Rend) or Anchor Line (Anchor). Depth 2 is unchanged. | Heft class I to II, tow limit 1.5 to 2.0. Chasers come in; the lobber (3.0) does not, so the first "too heavy" read is the lobber pulling Tarn to it. | Learn the loop: drag, clamp, sweep. |
| 2, the Dig | 3 | Depth 3 changes the set piece: Rake Run on the Rend road, Vice Leap on the Anchor road. | Tow limit 2.0 to 2.5: anchor crews, deflectors and mind hands come in. The harpoon-spam answers enter here (the plan's difficulty call). A drill crew's line cut stops a drag mid-pull (section 2). Whether dragging a deflector pulls its dish off its line is untested (inference from `HOOK-CHAIN.md:36`). | Choose how you rend. |
| 3, the Highdraft | 4 | Each build gains one set-piece knob: longer, wider, bigger or twice. | Light flyers drag easily (kite drone 0.7, winch drone 0.8 at `src/combat/winch_drone.gd:48`, line cutter 1.0 at `line_cutter.gd:35`). Class IV to V, tow limit 3.0 to 3.5: lobbers and plated brutes come in. Vice Leap's arc-first path crosses gaps between sky islands. The Mind quotes Tarn's motif inverted (`mind_tarn`, `audio.gd:89-90`; `SOUND-STORY.md:61`). | Haul the heavy ones. |

**Relics stay as they are.** Tarn's six relic rows tune only the claw pull and the clamp, two per world (`src/build/relics.gd:46-51`, `:83-88`, `:120-125`). **Call:** no relic touches slot 3 or the set piece this wave.

## 5. The body: Tarn's mecha

The brief asked for the open gyro cage. Andrew rejected it tonight, so this section follows `ROSTER-LOOK.md` §0, the Hoberman mecha: an open scissor lattice that rolls, a level weapon ring that turns to the aim, hub modules, gap panels, and a cockpit pod at the centre. Tarn's parts are the ones the cage carried (two claws, a pull drum, claw-scored slabs), moved onto the new frame. Tarn sits in the pod and stays fully visible through the open gaps (`ROSTER-LOOK.md` §3, rule 1).

### Each part shows a verb

| Layer (`ROSTER-LOOK.md` §0.1) | Tarn's part (§0.2) | Nodes | What moves it |
| --- | --- | --- | --- |
| Weapon ring: level, turns to the aim | two big curved claw blades on the front arc at about 11 and 1 o'clock, edges forward (§0.7) | new blade nodes under `WeaponRing` (P-D names them) | Sweep: the blades swing through the sweep once per volley. Rake Run: held out to both sides. Set-piece peak: the ring spins one full turn. |
| Gap brackets at 4 and 8 o'clock (rest pose: the side hubs) | two hooked claw arms | `ClawPivot.R/L` and `ClawTip.R/L` keep their names and move to gap brackets under Pod (ROSTER-LOOK §0.2 node rule, §4; today at `tools/blender/shell_tarn.py:120-121`) | Shift: the aim-side arm shoots out. Clamp: both arms open with the gauge and snap inward. Claw drag: the arm on the line's side reaches along the cable. Set piece: the arms alternate grips on the beat. |
| Pod, low at the rear (rest pose: a low rear hub) | the pull drum, rubber with 12 rope grooves | `PullDrum`, `PullExit` (today at `shell_tarn.py:123-129`) | Claw drag: winds in. Heavy reversal: spins the other way. Shift: winds in. The rear tell, low centre. |
| Gap panels | thick slabs scored with claw marks | Pod > `HeftC2`..`HeftC5` panel holders, at the rest-pose positions the `Gap.NN` empties mark (`PILOT-CLIPS.md` §5, `CUSTOMIZE.md`) | heft class, below |
| Cockpit controls (§0.7) | twin yokes with grip triggers; a lever bank beside the right yoke with the clamp lever and the drum lever; a copper two-handed lap bar; exactly two pedals. Labels: "1: Claw sweep", "2: Claw clamp", "3: Claw Drag", "Q: Redjaw Rend", "Shift: Claw pull". | `Control.Trigger`, `Control.ClampLever`, `Control.DrumLever` under Pod (`PILOT-CLIPS.md` §5); `Control.LapBar`, `Control.Pedal.L/R` | 1: squeeze the grip triggers. 2: throw the clamp lever. 3: two hauls on the drum lever. Q: haul the lap bar back with both hands. Shift: stamp both pedals. The control and its clip read the same skill event (§0.4). |
| Rend contact | the landing point under the pod | `RendContact` (today at `shell_tarn.py:130`) | Rend and every set-piece landing |

**Colour.** Every lattice strut takes Tarn's §0.2 enamel, iron oxide red, with copper only on pivot pins and hubs (§0.7, "Lattice enamel"). Oxide also means harm and Fleet paint, so ROSTER-LOOK §6 ("Tarn's colour clash") keeps it on the lattice struts only (open question 8). The gap panels and the seat behind the head are bone and petrol (ROSTER-LOOK §6, "Tarn's colour clash"), so the ash-brown head reads against the seat (§0.7, "Pilot on model"). Glow shows only at the claw tooth edges (§0.7, "Colour discipline and glow"). The tiger's stripes and that glow carry the class read.

### Panels by heft class

Panels follow `heft_class_changed` and `heft_class_dropped` (`src/core/game_events.gd:36-37`). Class up slams panels into their gaps; class down flings them out (`ROSTER-LOOK.md` §0.3).

| Class | ROSTER-LOOK §0.3 | Tarn's version | Claw-arm reach past the lattice | Tow limit |
| --- | --- | --- | --- | --- |
| I | bare lattice, ring and pod; every gap open | claw arms tucked at 4 and 8 o'clock | 0.15 m | 1.5 |
| II | panels in the lower gaps | claw-scored slabs in the gaps under the pod | 0.15 m | 2.0 |
| III | panels in the side gaps, thicker tread caps | claw-scored slabs in the side gaps; the shared flat tread caps thicken (§0.7 keeps one cap style for all six) | 0.18 m | 2.5 |
| IV | panels in most gaps; the sight cone stays open | a slab skirt round the drum; hinge guards on both claw arms | 0.21 m | 3.0 |
| V | every non-sight gap; hub modules in heavy form | heavy claw arms: a second tooth row and longer hooks | 0.25 m | 3.5 |

**Call:** Tarn's claw arms lengthen one step per class, not only at class V, so the reach you see tracks the tow limit. One fact, the heft class, drives the panels, the claw length and the tow limit. The reach stays inside the 0.15 to 0.25 m outline break (`ROSTER-LOOK.md` §3, rule 4).

### The silhouette rule: bottom-heavy, and the blades keep time

Every pilot now carries a weapon ring at the equator (§0.1), so the ring alone tells nobody apart. Tarn's tell sits below it and on it. Two hooked claw arms push the outline out 0.15 m at 4 and 8 o'clock, below the ring. Above the ring, no module breaks the lattice outline, and the small round ears show through the open upper gaps. While Tarn fires, the two curved blades on the ring swing once per volley, so the outline on the aim side pulses at 2 Hz.

**Check.** In the blind greyscale thumbnails at the mid camera (`ROSTER-LOOK.md` §3, rule 10), Tarn's outline below the ring is wider than above it in every frame. A 1 s strip at the mid camera while firing shows the blade break change at 2 Hz. The Cannon's split ports also sit on low side hubs (§0.2); they do not move with fire, so the pulse separates the two (open question 3).

## 6. Clips

Tarn's body is calm. The face never snarls; the claws carry the aggression (`BIBLE.md:325`). **Call.** Each skill has a cockpit control and the pilot works it when the skill fires (`ROSTER-LOOK.md` §0.4). Clips run at 30 fps on the shared `pilot-v1` rig by the `tools/blender/anim_tarn.py` route (its header: "seven neutral-to-neutral clips at 30 fps", `anim_tarn.py:1`). A5 confirms the ids and P-E builds them.

| Clip id | Length | Trigger | Priority, cooldown | What Tarn does |
| --- | --- | --- | --- | --- |
| `idle_loop` | 4.0 s loop (120 frames) | no reaction playing | lowest | Tests the clamp lever's latch with one finger, then rests the paw on it. Ears turn once; the tail sways. The Bible's "test a bent latch with one finger" (`BIBLE.md:325`). |
| `class_up` | 1.2 s (36) | `heft_class_changed` | 50, 4.0 s (`SKILL-BAR.md:480`) | Rolls both shoulders and flexes both yokes; the claw arms snap once as the new panels slam in |
| `cast_special` | 0.7 s (21) | `slot_cast`, slot `special` | 30, 1.0 s | Throws the clamp lever (`Control.ClampLever`) beside the right yoke: the vice closing |
| `cast_line` | 0.8 s (24) | `line_skill_fired` | 32, 1.0 s | Two hauls on the drum lever (`Control.DrumLever`) next to the clamp lever, while the pull drum winds |
| `ult_ready` | 0.6 s (18) | `ultimate_ready` | 45, 10.0 s | One slow nod, a finger tap on the clamp lever, then both hands to the copper lap bar |
| `ult_windup` | 0.35 s (11) | `ultimate_started` | 70, 0.0 s | Both hands haul the copper lap bar back, head down: the big control for Q |
| `ult_strike` | 0.6 s (18) | `ultimate_peak` | 68, 0.0 s | Leans into the weapon ring's spin with the lap bar held hard back, face focused |
| `ult_recover` | 0.8 s (24) | `ultimate_landed` | 65, 0.0 s | Settles, one long exhale, a small shoulder roll. Control returns at 0.25 s; the clip finishes under play. |
| `smash` | 0.6 s (18) | `slammed` (`game_events.gd:50`), the shared roster row (PILOT-CLIPS.md section 1.1) | 36, 1.0 s | Pulls both yokes to the chest as the claw arms hook inward: the inward pull in the body |
| `unlock` | 3.0 s (90) | `achievement_earned("brindle_routed")` (`game_events.gd:174`) on the unlock card | ceremony | Climbs into the pod, sets down "a claw nobody issued" (`achievements.gd:39`), taps the clamp lever, nods once |

The seven existing reactions stay: `big_cheer`, `wince`, `slump`, `phew`, `brace`, `heave`, `drop_land` (`pilot_reactions.gd:6-17`; Tarn's bake in `anim_tarn.py`).

**Optional extra:** a held `clamp_charge` pose while the slot-2 gauge fills (the clamp lever drawn back as the claw arms open). It shows the gauge in the body. A5 decides.

## 7. Earned cosmetics

Tarn already has two paints: Redjaw Ash, the starter, and Dig Ochre, earned by stilling the Waking (`src/core/cosmetics.gd:32-33`; `achievements.gd:66-68`). Three new items, each earned. Nothing is bought. The trail slot exists today (`cosmetics.gd:17`). The outfit and shell-variant slots arrive with the A4 scaffold and B5.

| Slot | Id | Name | Look | Earned by |
| --- | --- | --- | --- | --- |
| trail | `trail_tarn_claw_marks` | Claw Marks | two parallel scored lines 0.6 m apart in bone, broken every 1.5 m like tooth gaps | "Ten in the Claws": "Drag ten machines into your claws in one stage."; discovery `tarn_dragged` |
| shell variant | `shell_tarn_redjaw_teeth` | Redjaw Teeth | bone-white replacement teeth with copper rivets (brass is the Furnace Fleet's colour, `ROSTER-LOOK.md` §6 and §0.7) on both ring blades and both claw arms, and a spare-tooth rack on a rear hub. The Redjaw benches keep worn teeth "until someone proves a better replacement" (`BIBLE.md:135`). | achievement `tarn_six_at_once`, "Land Redjaw Rend on six machines at once.": on `ultimate_landed` with `ultimate_id` `redjaw_rend` and `hits` 6 or more, count 1 |
| outfit | `outfit_tarn_steady_cap` | Steady Cap | a clean welding cap with one Redjaw stripe, in place of the battered one (`BIBLE.md:325`) | hidden discovery `tarn_hold_still`, "Hold still.": break a hostile hold with Q three times as Tarn (`hold_broken` with method `ultimate`, `game_events.gd:130`). **A2-CRITIC:** an achievement row cannot test the pilot (`src/core/progress.gd:259-288`), so Tarn's kit code counts the breaks and grants through `synergy_discovered`, as the Rivet and Kest sheets do. Beat text: "Hold still. The machine, I mean." (`BIBLE.md:329`) |

A4 and B5 own the row grammar for the `where` filters. Hidden rows already exist (`achievements.gd:53`).

## 8. Discovery and codex rows

Two first-time cards in `src/combat/codex_entries.gd` (format at `:12-30`: id, name, hint, clue, text). Tarn's own code detects each one, as combat does for the others (`codex_entries.gd:4-6`).

| id | Name | Hint (before) | Clue (before) | Text (after) | Fires when |
| --- | --- | --- | --- | --- | --- |
| `tarn_claw_drag` | Claw Drag | "Why go to them when the line can bring them?" | "a bitten enemy + 3 + a click" | "With a line on an enemy, 3 then a click sends the claw down the cable. It drags the enemy into claw reach, clamped. Too heavy, and the claw pulls you in instead. On a wall it rips a slab loose." | the first claw drag that moves a body |
| `tarn_redjaw_rend` | Redjaw Rend | "A full ring and a line to ride. Take company." | "a full ring + Q + enemies near the line" | "Q climbs the line claw over claw. Each beat the free claw snatches what is close and tows it. At the landing the whole catch is rent and clamped. A heavier ball tows heavier machines." | the first Redjaw Rend that lands with at least one body in tow |

**Optional extra:** a third card, `tarn_too_heavy` ("Too Heavy"), opened the first time a drag reverses on a heavy body. It teaches the weight rule at the moment it happens. Rake Run and Vice Leap need no card: the depth-3 tree card names them when picked.

## 9. Tests and bot checks

Everything here runs headless. None of it says whether Tarn is fun; only Andrew's sitting can.

| File | New or re-pin | What it proves |
| --- | --- | --- |
| `tests/tarn_kit_test.gd` | re-pin case a (`:150-162`) with a dated header | the row's six ids, now with `line_id` `claw_drag` and `ultimate_id` `redjaw_rend`; every row exists in `ABILITIES`; no placeholder (`line_reel`, `ult_default`) left. Cases b to i unchanged. |
| `tests/tarn_claw_drag_test.gd` | new | (1) a chaser bitten at 20 m arrives within 3.5 m of the ball within 1.0 s, takes 14 x chain multiplier and has a clamp mark; the next sweep on it deals x1.5. (2) At class I a lobber (3.0) does not move and the ball gains about 8 m/s toward it; at class IV the same lobber is dragged. (3) A line cut at 0.3 s stops the drag that tick and leaves no mark. (4) On a wall: a chaser 1.0 m off the line is hit, one 2.0 m off is not. (5) Load: cast with no line, bite at 3.99 s fires, at 4.01 s it has expired. (6) A Warden is never moved or marked and its posture rises by a gun bolt's amount. (7) The drag adds no chain link. |
| `tests/tarn_set_piece_test.gd` | new | Redjaw Rend: only bodies at or under the tow limit join the tow; never more than 2 + class; never a Warden or a boss; the landing knock points inward; every non-Warden hit is marked 3.0 s. Rake Run: strips hit exactly the drawn geometry and nothing outside it. Vice Leap: plans `arc` first when the arc target is valid; hurled bodies arrive within 2 m of B. Each depth-4 knob changes its reading (section 3). |
| `tests/tarn_tree_depths_test.gd` | new | all eight depth-3 nodes swap `ultimate` (indices 6 to 9 to `rake_run`, 10 to 13 to `vice_leap`); each depth-4 node carries exactly one `ult_*` knob and sibling pairs differ; every effect is 8 words or fewer; `UpgradeTree.problems("tarn")` is empty |
| `tests/tree_safe_picks_test.gd` | re-pin if B1 has not | `_class_kit` (`:104`) reads all six slot ids, so `_op_live` (`:142`) can read an `ultimate` swap; "Tarn no dead tree rows" still checks 36 nodes and finds none dead (`:185-189`) |
| `tests/tree_data_test.gd` | must pass | name and effect word caps; no proc loop on any Tarn build |
| `tests/bot_six_tarn_test.gd` | must pass | the skipper bot wins at least 3 of seeds 1 to 4, stage 1 to the win (`tests/bot_six_pilots_test.gd:12-13`), so world one included. B4's rule on top: each winning run casts slot 2 and slot 3 at least once and lands at least one set piece, read from the run log's `slot_casts` and `ultimates`. |
| `tests/alpha_posture_bands_w23_test.gd` | must pass | Tarn is seed 3 in the world 2 and 3 bands (`:25`). If a band moves, re-pin with a dated header and a `docs/decisions.tsv` line; never widen it silently. |
| `tests/codex_coverage_test.gd`, `tests/discovery_cards_test.gd`, `tests/discovery_card_size_test.gd` | must pass | the two Tarn cards are declared, detected once each, and fit the card size |
| `tests/presentation_motifs_test.gd`, `tests/char_kits_test.gd`, `tests/relics_per_world_test.gd` | must pass | the motif row, the kit table and the relic coverage stay intact |

**Meter band.** Over B4's seeds, Tarn's median `fill_seconds` lands in the framework's average band (75 to 90 s) and its camper takes 180 s or more (`SKILL-BAR.md:210`).

## 10. Implementation map: wave P-C unit PC-TARN

**GOAL.** Tarn plays claw drag on 3 and Redjaw Rend on Q, his tree swaps the set piece at depth 3 and tunes it at depth 4, and his earned items and codex cards exist, with the six-pilot bot still winning.

**Depends on P-B.** B1 (slot ids, `line_id` and `ultimate_id` on the class row, `_line_skills` and `_step_line`, the line and slot signals, `SWAPPABLE`), B3 (`src/combat/ultimate.gd`, `_ult_rows`, the meter, the four `ult_*` knobs in `KNOBS`, the `RideRail` carrier, the `ult_default` placeholder), B4 (bot hands that cast slot 3 and press Q) and B6 (the codex framework rows and the home of tree-card copy) must be merged first. The cosmetic rows wait for B5's outfit and shell-variant slots; if B5 lags, they land as a second commit in this unit. The class card's 3 and Q lines come from B2.

**SCOPE.** Its own worktree only; inside it:

- `src/core/class_def.gd`: the `tarn` row's `line_id` and `ultimate_id` only.
- `src/core/ability_state.gd`: four rows, `claw_drag`, `redjaw_rend`, `rake_run`, `vice_leap`.
- `src/combat/tarn_claw.gd` (new): `tow_limit`, the drag, the slab, the tow, the rake, the hurl and the vice, as the callables for one `_line_skills` row and three `_ult_rows` rows. A per-pilot file keeps the six P-C units out of each other's lines, the way `src/combat/sticky.gd` holds Kest's charges.
- `src/combat/combat.gd`: the one `_line_skills` row for `claw_drag`; nothing else.
- `src/combat/ultimate.gd`: the three `_ult_rows` rows; nothing else.
- `src/core/trees/tarn.gd`: the 24 node edits in section 3.
- `src/core/trees/world_one_cards.gd`: card rows for the 24 nodes, only if B6 routes depth-3 and depth-4 card copy there.
- `src/ui/class_kit.gd`: `WORDS` rows (`:15-48`): `claw_drag` "claw drag", `redjaw_rend` "redjaw rend", `rake_run` "rake run", `vice_leap` "vice leap".
- `src/combat/codex_entries.gd`: the two entries; their detection lives in `tarn_claw.gd`.
- `src/core/achievements.gd` and `src/core/cosmetics.gd`: the three rows each.
- `src/presentation/audio.gd`: the `line_claw_drag` row, and the per-beat taps only if B3 does not already derive them from `Harmony.MOTIFS`.
- Tests: the files in section 9 marked new or re-pin.

Not in scope: the body, blades, claw arms and panels (P-D, unit PD-TARN in `ROSTER-LOOK.md` §9), the clips and their trigger rows (P-E), `enemy.gd`, `bindings.gd`, any other pilot's rows.

**ACCEPTANCE.**

1. Tarn's class row reads `line_id` `claw_drag` and `ultimate_id` `redjaw_rend`; neither placeholder remains for Tarn.
2. A chaser bitten at 20 m arrives within 3.5 m of the ball within 1.0 s, takes 14 x chain multiplier and is clamp-marked for 2.5 s.
3. At class I a lobber is not moved and the ball gains about 8 m/s toward it; at class IV it is dragged.
4. A line cut mid-drag stops the drag on that tick and leaves no mark.
5. The slab hits every enemy within 1.2 m of the line and none outside it.
6. Redjaw Rend tows only bodies at or under the tow limit, never more than 2 + class, never a Warden or a boss; the landing pulls inward and marks every non-Warden, non-boss hit for 3.0 s.
7. Rake Run's strips hit exactly their drawn geometry; Vice Leap plans `arc` first.
8. Every depth-3 node swaps `ultimate` by road; every depth-4 node carries one `ult_*` knob; every effect is 8 words or fewer; `problems("tarn")` is empty; no Tarn node is dead.
9. `bot_six_tarn_test` wins at least 3 of 4 seeds, and each winning run casts slot 2 and 3 and lands a set piece.
10. `alpha_posture_bands_w23_test` holds Tarn's bands, or a dated re-pin and a decisions line explain the move.
11. The two codex cards open once each on their scripted triggers; the three cosmetics rows exist with achievement grants and no price.
12. `git diff --name-status` against the base shows only SCOPE files.

**VERIFY.**

```sh
tools/coordinator/compile_check.sh
node scripts/sketch-lint.mjs --sketch core-loop
npm run sketch:smoke -- --sketch core-loop --test 'tarn_*'        # expect 5 files: kit, look, claw_drag, set_piece, tree_depths
npm run sketch:smoke -- --sketch core-loop --test bot_six_tarn_test
npm run sketch:smoke -- --sketch core-loop --test tree_safe_picks_test
npm run sketch:smoke -- --sketch core-loop --test tree_data_test
npm run sketch:smoke -- --sketch core-loop --test alpha_posture_bands_w23_test
npm run sketch:smoke -- --sketch core-loop --test 'codex_coverage_test'
npm run sketch:smoke -- --sketch core-loop --test 'discovery_card*'
```

Each run must report a nonzero test count. `--test` matches a file's base name with `*` as the only wildcard (`scripts/sketch-smoke.mjs:127`).

**If power rose.** Tune Tarn's own numbers in `tarn_claw.gd` first (drag damage, tow chew, peak ring). Retune enemy packs only through the plan's per-world pack-scale lever, and record it.

## 11. Open questions and veto list

### Open questions, each with a default

1. Should clamp catches feed the meter as contacts, after the Bible's "useful holds" (`BIBLE.md:336`)? **Default: no.** Tarn fills from the shared sources; revisit if B4 puts Tarn outside the bands.
2. `safe_pick_problems` flags every swap as a replacement (`upgrade_tree.gd:201-206`), and `tree_safe_picks_test.gd:22` expects none for Tarn. **Default: B1 exempts ultimate swaps,** since all six pilots hit this.
3. The Cannon's split ports also sit on low side hubs (`ROSTER-LOOK.md` §0.2). **Default: P-D's blind greyscale test decides;** if it confuses them, Tarn's claw arms move up to the 3:30 and 8:30 hubs.
4. Where do the six pilots' set-piece rows live so P-C units do not collide in `ultimate.gd`? **Default: a per-pilot file plus one registration line each.**
5. Should a snatched enemy's attack telegraph be cancelled? **Default: no;** the set piece's x0.2 damage taken covers it. Revisit in play.
6. Should the park tables mark big draggable pieces (boulders, barrels) for the claw drag? **Default: parked until wave K-D.**
7. Should the depth-1 cards name the road's set piece ("Rend road: Rake Run")? **Default: no;** the depth-3 card names it when it is picked.
8. `ROSTER-LOOK.md` §0.2 lists Tarn's lattice enamel as iron oxide red, and §0.7 paints every strut in that enamel. Oxide also means harm and Fleet paint. **Default: an oxide lattice, per §0.7, with bone and petrol on the gap panels and the seat, and glow only at the tooth edges;** ROSTER-LOOK §6 now carries the same rule.
9. Where does slot 3's cockpit control sit? **Default: the drum lever, in the lever bank beside the right yoke next to the clamp lever** (`ROSTER-LOOK.md` §0.7; `DrumLever` in `PILOT-CLIPS.md` §5). Q is the copper lap bar and Shift is the two pedals. A3 and A5 confirm.

### Veto list (calls made under the creative charge)

Say "veto" on any line and it changes.

1. Slot 3 is a tap, so Tarn's bar has three fire shapes: hold, gauge, tap.
2. The claw drag reverses on heavy bodies: what Tarn cannot move, Tarn is pulled onto.
3. The tow limit grows with heft class, 1.5 at class I to 3.5 at class V.
4. A line cut mid-drag stops the drag.
5. On a wall the claw rips a slab and drags it down the line as a ram; Tarn does not move.
6. The clamp mark never lands on a Warden or a boss from slot 3 or the set piece.
7. The clamp (slot 2) ships unchanged.
8. Clamp, rend and claw drag all pull inward, kept as Tarn's identity.
9. Tarn's set-piece landings pull inward, like the rend.
10. The default set piece tows enemies behind the ball and drops them at the landing.
11. Every depth-3 node swaps the set piece: the Rend road gets Rake Run, the Anchor road gets Vice Leap.
12. Every depth-4 node gains one set-piece knob beside its existing effect.
13. No relic touches slot 3 or the set piece this wave.
14. Tarn's face never snarls in any clip; the claws carry the aggression.
15. Tarn's ring blades swing once per sweep, so his outline pulses with his weapon.
16. Tarn's claw arms lengthen one step per heft class, matching the tow limit.
17. Earned items: Claw Marks trail, Redjaw Teeth shell variant, Steady Cap outfit.
18. Hidden callback: Redjaw Rend landing on Brindle quotes the Fleet's D D Eb before Tarn's A.

# The remembered Cannon, pilot sheet (`remembered_cannon`)

Status: design spec for wave P-C, unit A2-cannon of wave 13. Written 2026-10-10 on `cand/alpha-w13` at `38ceda3`. Nothing here is built or played. Every `file:line` cites that commit. The body passages follow the Hoberman mecha in `design-v3/ROSTER-LOOK.md` section 0, which replaced the open cage on the evening of 2026-10-10. Paths without a prefix are under `sketches/core-loop/`; `BIBLE.md`, `docs/` and `adr/` are under the repo root. A number marked **start** is a starting value to tune in play. A line marked **Call** is a decision made under the creative charge; section 11 lists them as vetoes.

**Weapon fire (ruling ek, 22 Nov 2026):** how this pilot's weapon fires, with its timers, damage and first tree pick, is now [PILOT-CADENCE.md](../PILOT-CADENCE.md) section 3.6. Where this sheet's weapon text differs, that page wins.

This sheet fills the per-pilot contract in [SKILL-BAR.md](../SKILL-BAR.md) and uses its names exactly. It replaces the Cannon text in `design-v3/DESIGN-V3.md:185`. Its tree follows the structure the [Sable sheet](sable.md) set in its sections 3.6 and 3.7: every deep node keeps its op and gains one ultimate op, so the six trees read alike.

Terms, defined once:

- **Family**: one of the Mind's four attack shapes, `lane`, `split_lane`, `rush` and `plate`, in that order (`src/boss/mind_attacks.gd:26`).
- **Zone**: one committed family on the ground. It draws whole at once, waits its warn, then is live and strikes each enemy inside it once (`src/combat/combat.gd:1470-1528`).
- **Warn** and **live**: the seconds a zone shows before it strikes, and the seconds it strikes.
- **Call**: committing a zone.
- **Time on target**: zones called at different moments that all go live on one beat. The term is artillery's.
- **Quiet gun**: the tease prop on the Mind's rim (section 3.7).
- **Beat**: one beat of the band, 0.349 s at 172 BPM (`SOUND-STORY.md:31`).

## 1. Fantasy, and what nobody else does

**One line.** A rebuilt ancient gun that calls the Mind's own attacks down on its enemies, then fires itself as the last shell.

The card keeps today's line, "The Mind's guns, yours now. Call the shot." (`src/ui/class_kit.gd:66`). The class row names it the boss-mirror cannon, species rebuilt ancient (`src/core/class_def.gd:122-128`). The pilot is a cast machine with a muzzle for a head and paddles for hands (`tools/blender/pilot_cannon.py:44-52`). It unlocks when the Mind is quieted (`class_def.gd:72-73`, `src/core/achievements.gd:58-60`, `BIBLE.md:582`). Most players meet it on a fresh run after the ending; the `--profile=sitting` flag opens it early (SKILL-BAR.md:618-622).

### Its hits arrive late, on purpose

Every Cannon attack is a zone drawn on the ground now that strikes 1.2 to 1.8 s later, on a clock it cannot hold or hurry. The other five hit now, or stick to the target:

| Pilot | How a hit arrives | Source |
| --- | --- | --- |
| Sable | arc bolts now; a discharge sized by her speed | `src/combat/weapons.gd:34-37`, `:69-83` |
| Rivet | a laser stream now | `weapons.gd:32-33` |
| Kest | a charge that sticks to the target and blows on a 1.2 s fuse | `weapons.gd:40-41`, `:192` |
| Tarn | a claw sweep inside 5 m, now | `weapons.gd:44-45` |
| Tally | a card run at the aim point, now | `weapons.gd:96-101` |
| **Cannon** | a lane, ring or sector painted on the ground that strikes everything inside 1.2 to 1.8 s later | `mind_attacks.gd:39-53`, `combat.gd:1470-1528` |

Kest is the nearest neighbour, and the line between them is sharp. Kest sticks a bomb to the enemy, so the bomb follows it. The Cannon paints the ground where the enemy will be, so the player leads in time. Three rules follow from that:

1. **Lead in time, not in angle.** Call, leave, and it lands. Bosses play this way; the Cannon is the one pilot that does.
2. **What you see is what hits.** A zone strikes only where its own `contains()` holds while it is live (`combat.gd:1460`, `:1521`). Its shape never grows after the call.
3. **The line is the one exception.** The harpoon cable has already drawn the lane, so the line skill strikes at once (section 2.4). The fastest hit in the kit rides the harpoon.

### The mirror, in one table

Beating the Mind unlocks its gun turned outward. Both read one set of family rules (`BIBLE.md:608`).

| | The Mind (`src/boss/mind.gd`) | The Cannon |
| --- | --- | --- |
| From, to | the pad centre out to the ball (`mind.gd:128-133`) | the ground under the ball out to the aim or an enemy (`combat.gd:1549-1553`) |
| Colour | the hostile hazard colour, inside `Threat.GROUP` | uranium-glass green, `Palette.ANCIENT` (`src/core/palette.gd:12-15`), kept out of `Threat.GROUP` (`combat.gd:1459`) |
| Families open | one more per posture chunk (`mind.gd:95-99`) | all four from the drop, one per key |
| The plate | braces against one of your verbs (`mind_attacks.gd:159-173`) | opens enemies to every contact verb at x1.4 for 2.5 s (`combat.gd:1527-1528`, `:539-540`) |
| Its tune | none of its own; it quotes your motif inverted, last note a semitone flat (`src/presentation/harmony.gd:173-185`, `SOUND-STORY.md:61`) | B3 E4 G4 D5, "the Mind's quote of Sable back to front, one note per family" (`harmony.gd:130`, `:137`) |

The last row carries the whole mirror. The Cannon's tune is the Mind's wrong quote of the first pilot, reversed: the gun remembered the fox. Section 3.7 turns that into the tease and the payoff.

### One family, one note, one slot

The motif has four notes in family order (`mind_attacks.gd:26`, `harmony.gd:137`). Every layer of the kit reads this one map, so playing the kit in order plays the tune.

| Family | Note | Slot that calls it | Barrel band (section 5) |
| --- | --- | --- | --- |
| `lane` | B3 | 1, the weapon | first, at the breech |
| `split_lane` | E4 | Shift | second |
| `rush` | G4 | Ctrl, the smash | third |
| `plate` | D5 | 2, the special | fourth, at the muzzle |

**Call:** a family's note sounds when its zone goes live, on the chime voice (`harmony.gd:137`), at -14 dB **start**, on the frame, because a player action plays now (`SOUND-STORY.md:72`). A helper `Harmony.family_note(family)` reads the cell at the family's index in `MindAttacks.FAMILIES`, so no note is written twice.

## 2. Kit

### 2.1 The bar

| Place | Slot, key | Ability | Fire shape | Numbers, world one | Stays from today | New |
| --- | --- | --- | --- | --- | --- | --- |
| 1, home | `weapon`, 1 | Cannon Lane, `cannon_lane` | auto | 30 damage a lane, 1 lane a second, 24.4 m by 3.2 m, warn 1.4 s, live 0.8 s, knock 9 | all of it | B3 on live |
| 2 | `special`, 2 | Cannon Plate, `cannon_plate` | gauge, 0.8 s | 18 to 34 damage, 6.0 s cooldown, 90 degree sector 8 m deep, warn 1.8 s, live 1.0 s, exposes for 2.5 s at x1.4 | all of it | an exposure mark; D5 on live |
| 3 | `line`, 3 | Lane Charge, `cannon_lane_charge` | tap | 28 x chain multiplier, 8.0 s cooldown, 1 charge, load 4.0 s, warn 0.1 s, live 0.3 s | nothing | all of it |
| chip | `movement`, Shift | Recoil Split, `cannon_recoil` | press | kick at 20.8 m/s or faster, lift 1.5 m/s, 3.5 s cooldown; two lanes behind, 14.4 m, 24 damage, warn 1.6 s | all of it | E4 on live |
| chip | `smash`, Ctrl | Rush Ring, `cannon_rush` | on the slam | ring 8 m wide through the nearest enemy within 14 m, 30 x slam strength, warn 1.5 s, live 0.6 s | all of it | G4 on live; a smash clip |
| Q | `ultimate` | Fire Mission, `cannon_fire_mission` | press | section 3 | nothing | all of it |

Warns tighten 0.1 s per world: the Cannon's phase is the world index (`combat.gd:1462-1463`) and each phase past the first takes 0.1 s off (`mind_attacks.gd:268-269`). Section 4 lists them.

### 2.2 Slot 1, Cannon Lane (kept)

- **Does:** held left click calls one lane a second from the ground under the ball down the aim (`combat.gd:1036-1039`, `:1543-1560`). If the aim point sits within 1.5 m of the ball's ground point, the lane runs out along the flat aim (`:1551-1552`).
- **Numbers:** damage 30 (`weapons.gd:133`); rate 1.0 (`:52`); reach 26 m, so the lane is 24.4 m long (`:132`, `mind_attacks.gd:257-259`); half width 1.6 m (`mind_attacks.gd:39`); warn 1.4 s (`:40`); live 0.8 s (`:41`); knock 9.0 along the lane (`src/core/event_kinds.gd:263`, `combat.gd:1524-1525`). The weapon-range mod scales the reach (`combat.gd:1546`).
- **Sees:** a green strip from under the ball that fills over the warn and flashes when live. Ancient green carries a dotted seam, so a deuteranope never reads it as Brindle's brass (`palette.gd:12-14`).
- **Hears:** `shot_fired` on the call (`combat.gd:1560`), pitched 7 semitones down (`src/presentation/audio.gd:58`). New: B3 on live.
- **Under the bar:** slot 1 never snaps back (SKILL-BAR.md:89), and the release latch applies (SKILL-BAR.md:83).

### 2.3 Slot 2, Cannon Plate (kept, one refinement)

- **Does:** press 2, then hold left click. The gauge fills over 0.8 s and draws the sector (`combat.gd:1574-1576`). The release commits a plate from the ball's ground point along the aim (`:1579-1584`). Struck enemies are exposed: any contact strike (stomp, ram or slam, `combat.gd:70`) deals x1.4 (`mind_attacks.gd:30`, `combat.gd:539-540`) for 2.5 s (`mind_attacks.gd:53`, `combat.gd:1527-1528`).
- **Numbers:** 18 to 34 damage by the gauge (`weapons.gd:136-137`, `combat.gd:1582`); cooldown 6.0 s (`src/core/ability_state.gd:74`); 8 m deep, 90 degrees wide (`combat.gd:1575-1576`, `mind_attacks.gd:51-52`); warn 1.8 s (`mind_attacks.gd:49`); live 1.0 s (`:50`).
- **Hears:** the release cue `cannon_recall` (`src/presentation/sfx_bank.gd:497-498`). New: D5 on live.
- **Refinement, an exposure mark.** No file outside `combat.gd` and `mind_attacks.gd` names `exposed`, so today nothing shows which enemies a plate opened. P-C adds a cracked-plate ring in ancient green on each exposed enemy that drains over its 2.5 s. "Plate, then ram" becomes readable.
- The plate records a verb (`combat.gd:1528`) that the multiplier ignores (`:539-540`). Kept as is.

### 2.4 Slot 3, Lane Charge (new: the line charges a cannon lane)

| Field | Lane Charge |
| --- | --- |
| `id`, icon, name | `cannon_lane_charge`, `ab_cannon_line`, Lane Charge |
| Fire shape | tap: it commits on the press |
| `cooldown`, charges | 8.0 s, 1 (the SKILL-BAR default) |
| `on_body` | a lane from the ground under the ball along the flat cable, through the latched enemy and 12 m **start** past it. The latched enemy always takes the hit, even above the zone's 3 m height (`mind_attacks.gd:33`). Every other enemy inside takes it once |
| `on_world` | a lane from the floor under the anchor. On a wall it runs straight out along the surface normal (`kit.anchor_normal`, `src/movement/augments.gd:333`); on a post or floor it runs along the flat aim. 24.4 m long, the weapon's length. No `reel_burst`. If no floor lies within 12 m below the anchor, the lane starts under the ball along the flat cable instead |
| Damage, knock | 28 **start** x `chain.multiplier()`, so 28 to 70; knock 9.0 along the lane (`event_kinds.gd:263`) |
| Warn, live | 0.1 s, 0.3 s **start**. The cable was the telegraph |
| `load_seconds` | 4.0 (default) |
| Chain scaling | yes; no link added (SKILL-BAR.md:151-152) |
| Committed geometry | while slot 3 is selected and a line stands, the cable draws the lane's two edges 1.6 m either side and the 12 m tail. A load draws the same edges on the next bite before it fires. That strip is exactly what strikes |
| Ground contact | none; the ball stays airborne, so a chain survives |
| Warden and boss read | closed guard: a glance, slate sparks, half damage, posture as a gun bolt (`design-v3/LEGIBILITY.md:50`, `:85`). Open core: full damage x chain. Bosses: normal plating. Nothing is displaced, so nothing is resisted |
| Sound | the lane note climbing the motif with the chain: combo 1 B3, 2 E4, 3 G4, 4 D5, 5 and 6 the whole motif in sixteenths. It rises like `chain_link` |
| Card line | "The cable is the lane. It fires now." |
| Discovery | `cannon_lane_charge` (section 8) |
| Clip | `cast_line`, 0.45 s (section 6) |

ABILITIES row (the keys SKILL-BAR.md:439 names):

```gdscript
"cannon_lane_charge": {"icon": "ab_cannon_line", "cooldown": 8.0, "line": true, "load_seconds": 4.0, "family": "lane"},
```

Build note: `_commit_cannon` (`combat.gd:1470-1489`) gains an optional overrides dictionary (`warn`, `live`, `from`, `dir`, `ahead`). The geometry stays the lane family's from `MindAttacks`, as `BIBLE.md:608` requires; only the timing and the start point change.

### 2.5 Shift, Recoil Split (kept)

- **Does:** Shift kicks the ball along the aim at 1.3 times the dash floor, keeping a faster speed, at least 1.5 m/s upward (`augments.gd:113-116`, `:318-327`): 20.8 m/s with `dash_impulse` 16 (`src/movement/tuning.gd:15`). The `dashed` fact lays a split lane behind (`combat.gd:1564-1570`): two lanes from the ball's ground point, one straight back along the kick and one 20 to 40 degrees off it (`mind_attacks.gd:44-45`, `:141-147`).
- **Numbers:** cooldown 3.5 s (`ability_state.gd:73`); 14.4 m long from the 16 m reach (`weapons.gd:134`); 24 damage (`:135`); warn 1.6 s (`mind_attacks.gd:42`); live 0.8 s (`:43`).
- Instant and never selectable (SKILL-BAR.md:38). New: E4 on live.

### 2.6 Smash, Rush Ring (kept)

- **Does:** after the shared slam (`src/movement/player_ball.gd:891-902`), combat lays a rush ring about the landing through the nearest enemy within 14 m (`combat.gd:1588-1602`, `weapons.gd:138-139`). The flavour has no entry in the ball's `_smashes` table (`player_ball.gd:165`); combat owns it through `slammed` (`combat.gd:324`).
- **Numbers:** an annulus 8 m wide (`mind_attacks.gd:48`, `:151-156`); 30 damage x slam strength clamped 0.5 to 1.5 (`combat.gd:1601`); warn 1.5 s (`mind_attacks.gd:46`); live 0.6 s (`:47`).
- New: G4 on live; the `smash` clip (section 6).

## 3. The ultimate: Fire Mission

The Cannon fires itself along an arc. Each beat in the air it calls one of the Mind's families onto the ground below, and every call lands the moment the Cannon does.

### 3.1 The contract fields (SKILL-BAR.md:314-326)

| # | Field | Fire Mission |
| --- | --- | --- |
| 1 | `id`, name, icon | `cannon_fire_mission`, Fire Mission, `ab_cannon_ult` |
| 2 | `paths` | `arc`, then `line`, then `rail`; the hop stays the fallback (SKILL-BAR.md:250). Reach: the class arc reach, 40 to 70 m (SKILL-BAR.md:236) |
| 3 | Tech | each flight beat calls one family zone, in motif order (lane, split, rush, plate, then round again), at the nearest enemy within 25 degrees of the reticle and within 26 m of the ground under the ball; with none, down the flat aim. 12 damage x heft per enemy per zone (SKILL-BAR.md:272). Every zone's warn ends on the landing beat |
| 4 | Peak | the middle beat calls all four families at once round the landing point. It replaces that beat's volley |
| 5 | Landing | the default (60 x heft x chain, radius 6 to 10 m by class, knock 26, ends the chain; SKILL-BAR.md:276). Every called zone goes live on the same beat |
| 6 | Heft scaling | the default table. One override: the apex is capped at 20 m **start**; for flights whose apex would pass it, the carrier's gravity drops to 160 / t squared (t = flight seconds) |
| 7 | Music | motif `cannon`; the calls play its notes as the build, the peak plays it whole an octave up, the landing strikes it as one chord on the drop (section 3.4) |
| 8 | Mecha | section 3.4 |
| 9 | Clips | `ult_ready` 0.8 s, `ult_windup` 0.35 s, `ult_strike` 0.5 s, `ult_recover` 0.6 s (section 6). Both paddles hold the copper lap bar, the Q control, through the flight in the shared `ult_ride_loop` |
| 10 | Depth 3 | Creeping Barrage and Plate Mortar (section 3.5) |
| 11 | Depth 4 | one knob on every leaf (section 3.6) |
| 12 | Wardens and bosses | section 3.3 |
| 13 | Card, discovery, run log | "Fire yourself. Every call lands when you do."; discovery `cannon_fire_mission` (section 8); run log `ultimates[].id` is `cannon_fire_mission` (SKILL-BAR.md:449), plus two new fields, `zones` and `zone_hits` (section 9) |

ABILITIES row:

```gdscript
"cannon_fire_mission": {"icon": "ab_cannon_ult", "paths": ["arc", "line", "rail"], "beats": 0},
```

`beats: 0` means the flight length sets the beats. A positive value fixes them (Plate Mortar uses 6). SKILL-BAR section 12, item 1 now defines `beats` this way, beside Kest's `hold_beats` (A2-CRITIC).

The gravity in play is 26 m/s squared (`tuning.gd:9`), so an arc's apex is 26 x t squared / 8 on flat ground: about 14 m for a 6-beat flight, 32 m for 9 beats uncapped. The cap keeps the camera's 1.25x pull-back (SKILL-BAR.md:280) on the fight.

### 3.2 The flight, beat by beat

A 7-beat flight (2.44 s) at class II, 47 m of arc. Beats land every 0.349 s after the 0.35 s wind-up.

| Time (s) | Beat | What happens | Sound | Pilot and mecha |
| --- | --- | --- | --- | --- |
| 0.00 | Q | the arc is planned and drawn whole in live mint with its 3 m corridor; the meter is spent | `start_build(flight_seconds, true)` | `ult_windup`: the lattice folds to a shell casing |
| 0.35 | launch | the `RideRail` arc departs (`src/world/ride_rail.gd:41-72`); damage taken x0.2 | the build | the barrel pitches down the path |
| 0.70 | 1 | a lane is called; its warn is 6 beats | B3, -14 dB | band 1 flashes |
| 1.05 | 2 | a split lane; warn 5 beats | E4 | band 2 |
| 1.40 | 3 | a rush ring; warn 4 beats | G4 | band 3 |
| 1.75 | 4, the peak | lane, split, rush and plate called round the landing point; warn 3 beats | the motif whole an octave up, B4 E5 G5 D6, in sixteenths (0.70 s) | `ult_strike`: muzzle straight down, paddles wide |
| 2.09 | 5 | a plate; warn 2 beats | D5 | band 4 |
| 2.44 | 6 | a lane; warn 1 beat | B3 | band 1 |
| 2.79 | 7, landing | the landing strike and all nine calls go live on one beat | `drop_now(4, 0.85)` and the chord B3 E4 G4 D5 at -6 dB, resolving into the band's D | `ult_recover`: the lattice springs open to full size |
| 3.04 | recovery ends | full control; the banked speed is handed back (SKILL-BAR.md:254) | the lift releases | |

Rules for the calls:

- **Cap:** 12 calls a flight **start**. The peak's four always fit.
- **No void calls:** a call whose ground lies more than 12 m below the ball is skipped. Over the Highdraft's gaps the floor below is the catch floor (`src/ui/ending_sequence.gd:233-234` names it).
- **Bail (Space):** the ride ends and no landing strike fires (SKILL-BAR.md:297). Every call already made keeps its beat.
- **Collision:** the landing strike fires at the contact point. The calls keep their scheduled beat, so the drawn timing never lies.
- **Recall (Q in the wind-up):** nothing has been called yet; full refund.
- **Kind:** the base landing strikes with a non-contact kind, so a peak plate does not multiply it. That interplay belongs to Plate Mortar.
- **Where the row learns B:** the `tech` Callable receives `beat, ball, aim, heft_mult` only (SKILL-BAR.md:438). The Cannon row caches the landing point and the flight seconds from `ultimate_started(ultimate_id, path, from, to, seconds)` (SKILL-BAR.md:426) and counts beats left from there. No interface change.

Worst case on one enemy standing at the landing point: four peak zones at 12 plus the landing at 60, so 108 x heft, 173 at class V, before the chain. Bosses take half.

### 3.3 Wardens and bosses

The defaults hold (SKILL-BAR.md:301-310). Cannon notes:

- **Closed guard:** each zone glances at half damage and fills posture as a gun bolt. The framework's cap of 45 posture applies to the whole set piece, zones and landing together (SKILL-BAR section 12, item 7; A2-CRITIC raised this sheet's Call into the framework). Nine zones striking on one beat would otherwise stack posture past the cap's intent.
- **Open core:** the landing counts as a harpoon smash on the core and shatters the chunk (SKILL-BAR.md:306). The zones add damage only.
- **The peak's plate** exposes a Warden as the special does. Exposure multiplies damage, never posture.
- **Brindle, the Waking, the Mind:** x0.5, phase windows untouched, the brace pose and the "nope" glyph.
- **Warden as anchor (wave K-F):** a `line` path may end on a Warden. Fire Mission tries the arc first; Creeping Barrage rides the Warden's line first.
- **Check:** with the Cannon, each grown Warden must break at 25 s or more (SKILL-BAR.md:645), measured by the Cannon `tools/bot_run.gd` rows in section 10; `alpha_posture_bands_test` does not sample the Cannon.

### 3.4 The mecha and the music moment

| Moment | Mecha | Music, synth band | ACE band |
| --- | --- | --- | --- |
| Meter full | the four barrel bands light one per beat in motif order, then all four breathe at 1 Hz | the one-layer lift (SKILL-BAR.md:286); the `ultimate_ready` cue plays B4 E5 G5 and a small bell | one pressure step |
| Wind-up | the Hoberman lattice folds to 85 percent of its radius in 0.35 s and the gap panels close up like a shell casing; the weapon ring stays level and keeps its size; the sight cone stays open | `start_build(flight_seconds, true)` | the band holds |
| Each call | the weapon ring yaws the barrel to the zone on its beat; that family's band flashes | the family note on the chime, -14 dB, on the beat | the same on the ACE grid |
| Peak | muzzle straight down | the motif whole, an octave up, in sixteenths | the same stinger |
| Landing | the lattice springs back to full size on the drop, in 0.12 s | `drop_now(4, 0.85)`; the four notes struck together as one chord on the chime at -6 dB; the band's next downbeat is D, home | the handover on the beat |

The arpeggio becomes the chord. The build plays the tune one note per call, and the drop plays every note at once, on the beat every shell lands. SKILL-BAR.md:289 says "the launch is the build and the landing is the drop"; here the motif itself carries that shape.

### 3.5 Depth 3: two variants, every route

`depth_cap` is `clamp(world_index + 1, 2, 4)` (`src/core/upgrade_tree.gd:119-120`), so depth 3 opens in world two.

| | Fire Mission (base) | Creeping Barrage, `cannon_creeping_barrage` | Plate Mortar, `cannon_plate_mortar` |
| --- | --- | --- | --- |
| Lean | both halves | the Lanes half (`src/core/trees/cannon.gd:4-5`) | the Brace half |
| `paths` | arc, line, rail | line, rail, then arc | arc only, then the hop |
| Reach | class arc reach, 40 to 70 m | the rope, 45 m (`tuning.gd:18`) | half the class arc reach: 20, 24, 28, 31, 35 m **start** |
| Flight | from the path length, 5 to 9 beats | from the path length | fixed at 6 beats, 2.09 s; apex about 14 m |
| Tech per beat | one family, time on target | one lane laid across the path where the ball will be 2 beats later (the ball's velocity x 2 beats, so it works on rails); warn 1 beat, so each lane goes live one beat before the ball crosses it. The notes walk B E G D | one plate on the ground under the ball toward the nearest enemy within 16 m; warn 1 beat; it exposes for 2.5 s |
| Peak | four families round the landing point | a split lane fanned forward from the ball, 20 to 40 degrees apart | a rush ring round the landing point through its nearest enemy, live on the landing beat |
| Landing | the default; every zone live with it | the default, plus one lane 24.4 m on along the path, live on the next beat | the default, but the strike is a `slam`, a contact kind (`combat.gd:70`), so every exposed enemy takes x1.4 (`combat.gd:539-540`) |
| Feel | lob over the fight; everything lands as you do | ride a line behind a walking wall that clears the way | a high lob that braces the pack, then crushes it |
| Card | Fire yourself. Every call lands when you do. | Ride the line behind a walking wall. | Lob high, brace the pack, land the crush. |

Creeping Barrage changes the path type (a line first, low and fast) and the tech (lanes rolling ahead, not time on target). Plate Mortar changes the tech (plates that expose, and a landing that cashes the exposure) and the arc's shape. Both pass "not only a number" (SKILL-BAR.md:323).

The trade is real. Creeping Barrage works under a roof, along a cable or a rail. Plate Mortar needs about 14 m of sky. The Dig's tunnels favour the first; its pits and sinkholes favour the second (section 4).

Variant rows. `variant_of` is SKILL-BAR section 12, item 3, so `safe_pick_problems` reads a swap to a variant as growth:

```gdscript
"cannon_creeping_barrage": {"icon": "ab_cannon_ult", "paths": ["line", "rail", "arc"], "beats": 0, "variant_of": "cannon_fire_mission"},
"cannon_plate_mortar": {"icon": "ab_cannon_ult", "paths": ["arc"], "beats": 6, "variant_of": "cannon_fire_mission"},
```

**Node mapping.** Each of the eight depth-3 nodes keeps its name, effect, key, icon and op, and gains one `swap`. Siblings always differ (children of node i are 2i+2 and 2i+3, `upgrade_tree.gd:140-141`), so every offered pair is one Creeping Barrage and one Plate Mortar. The Cannon's world-one table is its full tree (`trees/cannon.gd:77-78`), so no retained-pair case arises.

| Index | Node, kept | Op today (`trees/cannon.gd`) | Added op |
| --- | --- | --- | --- |
| 6 | `c_kick_shot` Kick Shot | proc `dashed` volley 1.0 (`:23-24`) | `"swap": {"ultimate": "cannon_creeping_barrage"}` |
| 7 | `c_plate_fever` Plate Fever | proc `special_used` overdrive 1.5 (`:25-26`) | `"swap": {"ultimate": "cannon_plate_mortar"}` |
| 8 | `c_split_wave` Split Wave | proc `dashed` blast 0.5 (`:27-28`) | `"swap": {"ultimate": "cannon_creeping_barrage"}` |
| 9 | `c_kick_hop` Kick Hop | proc `dashed` air (`:29-30`) | `"swap": {"ultimate": "cannon_plate_mortar"}` |
| 10 | `c_plate_hop` Plate Hop | proc `special_used` air (`:31-32`) | `"swap": {"ultimate": "cannon_creeping_barrage"}` |
| 11 | `c_plate_shock` Plate Shock | proc `special_used` blast 0.5 (`:33-34`) | `"swap": {"ultimate": "cannon_plate_mortar"}` |
| 12 | `c_rush_refill` Rush Refill | proc `slammed` refund_special 0.3 (`:35-36`) | `"swap": {"ultimate": "cannon_creeping_barrage"}` |
| 13 | `c_rush_kick` Rush Kick | proc `slammed` grant_move (`:37-38`) | `"swap": {"ultimate": "cannon_plate_mortar"}` |

**Card copy.** The `effect` stays (8 words at most, `upgrade_tree.gd:50`). The card's second line, "Set piece: Creeping Barrage", comes from the shared `SET_PIECE_LINES` table (SKILL-BAR section 12, item 5), keyed by ultimate id and by knob, so the card cannot disagree with the op.

### 3.6 Depth 4: one knob on every leaf

The framework knobs (SKILL-BAR.md:332), read for the Cannon:

| Knob | Creeping Barrage | Plate Mortar |
| --- | --- | --- |
| `ult_encore` (true) | after the landing, a 4-beat line leg to an enemy within 30 m, with its own lanes, landing at half damage | a second 4-beat lob to an enemy within 30 m, plates included, landing at half damage |
| `ult_beats` (+2) | 2 more beats, so 2 more lanes | 8 beats; the apex stays at the 20 m cap, so the lob floats; 2 more plates |
| `ult_radius` (+2 m) | landing radius +2 m | landing radius +2 m, and the peak's rush band +2 m |
| `ult_volley` (+1) | each beat lays a second lane 6 m beyond the first: a double curtain | each beat drops a second plate, mirrored across the path |

| Index | Node, kept | Op today (`trees/cannon.gd`) | Under | Added knob |
| --- | --- | --- | --- | --- |
| 14 | `c_forked_shot` | pattern count +1, spread 6, damage x0.7 (`:40-42`) | Creeping | `"ult_volley": 1` |
| 15 | `c_relay_shot` | pattern chain +1 (`:43-45`) | Creeping | `"ult_encore": true` |
| 16 | `c_lane_tempo` | pattern rate +0.25 (`:46-47`) | Mortar | `"ult_beats": 2` |
| 17 | `c_quick_plate` | special +1 charge, cooldown x0.8 (`:48-49`) | Mortar | `"ult_radius": 2.0` |
| 18 | `c_long_kick` | movement +1 charge, cooldown x0.8 (`:50-51`) | Creeping | `"ult_beats": 2` |
| 19 | `c_wave_shot` | proc `dashed` volley 2.0 (`:52-53`) | Creeping | `"ult_volley": 1` |
| 20 | `c_endless_kick` | movement +1 charge (`:54-55`) | Mortar | `"ult_encore": true` |
| 21 | `c_kill_kick` | proc `enemy_killed` refund_move 0.5 (`:56-57`) | Mortar | `"ult_volley": 1` |
| 22 | `c_plate_volley` | proc `special_used` volley 2.0 (`:58-59`) | Creeping | `"ult_radius": 2.0` |
| 23 | `c_quick_brace` | special +1 charge, cooldown x0.8 (`:60-61`) | Creeping | `"ult_beats": 2` |
| 24 | `c_third_plate` | special +1 charge (`:62-63`) | Mortar | `"ult_volley": 1` |
| 25 | `c_brace_break` | proc `hold_broken` refund_special (`:64-65`) | Mortar | `"ult_encore": true` |
| 26 | `c_rush_volley` | proc `slammed` volley 2.0 (`:66-67`) | Creeping | `"ult_encore": true` |
| 27 | `c_rush_fever` | proc `slammed` overdrive 2.0 (`:68-69`) | Creeping | `"ult_radius": 2.0` |
| 28 | `c_rush_hop` | proc `slammed` air (`:70-71`) | Mortar | `"ult_beats": 2` |
| 29 | `c_unbowed` | proc `hold_broken` grant_move (`:72-73`) | Mortar | `"ult_radius": 2.0` |

Every depth-4 pair carries two different knobs. Each variant's eight leaves hold each knob twice; each knob appears four times in all. Forked Shot keeps its volley above it (Kick Shot's proc, index 6), so the lane-honesty rule still holds (`tests/tree_safe_picks_test.gd:312-320`).

Two rows as they will read in `src/core/trees/cannon.gd`, using only the existing ops (`upgrade_tree.gd:21-28`, `:46`):

```gdscript
{"id": "c_kick_shot", "name": "Kick Shot", "effect": "Each recoil also fires a free shot", "key": "movement",
	"icon": "ab_cannon_move", "tags": ["ranged", "mobility"], "proc": [{"on": "dashed", "do": "volley", "scale": 1.0, "gap": 1.0}],
	"swap": {"ultimate": "cannon_creeping_barrage"}},
{"id": "c_forked_shot", "name": "Forked Shot", "effect": "Free shots fork into two lighter bolts", "key": "weapon",
	"icon": "ab_cannon_weapon", "tags": ["ranged"],
	"pattern": {"cannon_lane": {"add": {"count": 1}, "min": {"spread_deg": 6.0}, "mul": {"damage": 0.7}}},
	"knob": {"ult_volley": 1}},
```

**Re-pin.** The "Cannon rulings" check forbids every knob and swap today (`tests/tree_safe_picks_test.gd:301`). The re-pin, with a dated header, allows a swap only on the `ultimate` key to a row whose `variant_of` is `cannon_fire_mission`, and knobs only from the four `ult_*` names.

### 3.7 The final-boss mirror: tease and payoff

#### The tease: the quiet gun in the Mind fight

- **Where:** on the rim of the Mind's 36 m pad (`src/boss/stub_boss.gd:18`), opposite the drop-in, 3 m outside the edge, resting on an island rib from the arena kit (`src/presentation/arena_mind_dress.gd:8-13`). Outside the play area, no collider, visual only, like the Mind's own body (`src/boss/mind_dress.gd:6-11`).
- **What it is:** the Cannon's barrel housing, in Old Verdigris (`src/core/cosmetics.gd:35`), a plug in the bore, four dark bands. P-D exports the housing as its own `BarrelHousing` node in the Cannon shell (`src/presentation/hero_assets.gd:61`). A greybox cylinder 1.6 m long stands in until then.
- **How it acts:** it reads the Mind module's `phase` each physics frame, as `mind_dress.gd` already does (`mind_dress.gd:95`, `mind.gd:95-99`). It never reads or writes an attack.

| Moment | Sees | Hears (chime, on the next beat) |
| --- | --- | --- |
| The fight starts, the lane family open (after the 3.0 s intro, `mind.gd:101`, `src/boss/boss_rules.gd:21`) | band 1 lights, steady | B3, -12 dB |
| Phase 2, the split lane opens | band 2 lights | E4 |
| Phase 3, the rush opens | band 3 lights | G4 |
| Phase 4, the plate opens (`mind.gd:96-98`) | band 4 lights | D5 |
| The Mind falls (`mind.gd:120-123`) | the plug pops out (0.3 s), the barrel turns to the ball (0.6 s) and dips once | the motif whole, -6 dB |

The Mind's families open one per chunk (`mind.gd:95-99`, `mind_attacks.gd:64-65`), and the Cannon's motif is "one note per family" (`harmony.gd:130`). So the gun learns its tune one note each time the Mind shows a new attack. A player who listens hears a melody assemble through the whole fight; one who does not loses nothing.

Readability guards:

- Never the hazard or brass colour, never a floor shape, never a telegraph. The band light is steady ancient green with the dotted seam.
- A note moves to the following beat if a boss telegraph started within 0.2 s, so it never masks a warning. Danger never waits for a beat; an announcement lands on one (`SOUND-STORY.md:72`).
- It never joins the band (`SOUND-STORY.md:69`); it stays a cue.
- `mind.gd`'s `_on_warden_died` discovers `mind_quiet_gun` once (section 8).

#### The payoff, part one: the ending

The ending flies over each world for 12 s (`ending_sequence.gd:15`). In the Highdraft frame (`:390-392`) the gun now stands at the bay gate beside the crew tableau (`:326-353`), plug out, four bands lit. This is the unlock beat made visible: "One turned up at the gate, cleaned." (`achievements.gd:60`).

The second Highdraft line arrives 7.0 s into the frame (`ending_sequence.gd:16-17`, `:385`): "West cable holds its note. Nobody answers from the next island." (`src/core/worlds.gd:49`). At 8.0 s **start**, on the next beat, the gun plays its motif whole. Something answers. The copy does not change.

If the run's pilot is the Cannon, the gate stands empty, and the Cannon's own shell in the tableau plays the motif at 8.0 s instead.

#### The payoff, part two: the unlock

The summary shows the unlock beat (`achievements.gd:60`). The first time the Cannon's class card shows unlocked, the `unlock` clip plays once (section 6): the gun settles into the empty cockpit seat, and the folded lattice unfolds round it in four steps, each on one note of the motif.

#### The mirror, when the Cannon fights the Mind

- The rim shows an empty cradle where the quiet gun lay. You are that gun.
- The Mind still quotes you on each adaptation (`event_kinds.gd:127`, `src/core/game_events.gd:138`, `sfx_bank.gd:515-516`). The Cannon's motif comes back inverted and wrong: B3 F#3 D#3 G2 (`harmony.gd:176-185` applied to the cells at `:137`).
- **Call:** one beat after each quote ends, the Cannon answers with its motif played right, B3 E4 G4 D5, at -10 dB **start**, and its barrel bands blink in order. The quote stays the telegraph (`SOUND-STORY.md:294`); the answer comes after it, never before.
- When the Mind falls with the Cannon in the mecha, `mind.gd` discovers `cannon_old_tune` (section 8), which grants the Choir Barrel (section 7).

The mirror for all six, computed from `harmony.gd:132-137` with `mind_quote` (`:176-185`):

| Pilot | Motif | The Mind's quote |
| --- | --- | --- |
| Sable | D4 F4 A4 C5 E5 | D4 B3 G3 E3 B2 |
| Rivet | A4 A4 A4 D5 | A4 A4 A4 D#4 |
| Kest | D4 A3 F3 D3 | D4 G4 B4 C#5 |
| Tarn | D3 D3 D#3 A3 | D3 D3 C#3 F#2 |
| Tally | D4 E4 F4 G4 D5 | D4 C4 B3 A3 C#3 |
| Cannon | B3 E4 G4 D5 | B3 F#3 D#3 G2 |

Read Sable's quote backwards (B2 E3 G3 B3 D4) and drop the repeated B: it is the Cannon's motif an octave down.

#### Separable extra, off unless Andrew says yes: counter-battery

A Cannon lane called down a live Mind lane's line (within 10 degrees and 2 m) before that lane goes live cancels it, once per Mind attack. It stands as gameplay without the lore, since it rewards reading the Mind's warn, and it stays hidden for discovery. Risk: it touches the Mind's attack loop (`mind.gd:160-181`) and could soften the final fight. Default off.

## 4. Three worlds

| | World 1, Spillway Works | World 2, the Dig | World 3, the Highdraft |
| --- | --- | --- | --- |
| Depth cap (`upgrade_tree.gd:119-120`) | 2 | 3 | 4 |
| Tree picks open | Quick Lane or Brace Kick, then one of four depth-2 nodes (`trees/cannon.gd:9-21`) | the set-piece choice: Creeping Barrage or Plate Mortar, each with its rider | a knob for the set piece, on a leaf that also grows a slot |
| Zone warns: lane, split, rush, plate | 1.4, 1.6, 1.5, 1.8 s | 1.3, 1.5, 1.4, 1.7 s | 1.2, 1.4, 1.3, 1.6 s |
| Relics (`src/build/relics.gd`) | Kick Spring, Brace Pin (`:58-63`) | Second Kick, Brace Spring (`:95-100`) | Hot Breech, Twin Plate (`:132-137`) |
| Ultimate | Fire Mission | a variant | a variant plus a knob |

**World 1, learn to lead.** Spillway's flats and flumes give long sightlines, and its warns are the longest. A Cannon player here is usually a veteran on a second run, so the world teaches the Cannon's timing, not the game. Fire Mission arcs across a flume and lands on the pack at its far bank. Lane Charge on a flume wall fires a lane straight out of it, across the channel.

**World 2, choose the set piece.** The Dig closes the sky. Its tunnels are natural lanes: a weapon lane down a tunnel strikes its whole length. Creeping Barrage rides the headframe cables and works under a roof. Plate Mortar needs 14 m of sky and owns the pits and sinkholes, where packs bunch on the floor below. The plan's harpoon-spam answers (deflector, counter-ram) enter here; Lane Charge is the Cannon's answer to a deflector, because a lane is ground geometry, not a bolt. Warns tighten by 0.1 s.

**World 3, the Mind's home.** The Highdraft's islands and gaps make Fire Mission a crossing as well as an attack: an arc to the next island lands the barrage on whatever waits there. The void rule (section 3.2) skips calls over the gaps. Lane Charge on a spire fires straight out of the spire. Warns are at their tightest. The final fight carries the mirror (section 3.7).

## 5. The mecha

Andrew rejected the open cage on the evening of 2026-10-10 and chose a fully expanded Hoberman sphere mecha. `design-v3/ROSTER-LOOK.md` section 0 is the shared design for all six pilots, and this section follows it. The mecha has four layers, split by how each one moves (ROSTER-LOOK section 0.1):

- **Lattice** (`Core`): a Hoberman sphere that tumbles with the true ball spin. Flat bars cross in X pairs at copper pivot pins and chain along great circles to **hubs**, with large open **gaps** between them.
- **Hubs and gaps:** named empties under `Core`, `Hub.00` to `Hub.31` and `Gap.NN`, facing outward. Hub modules clamp at hubs. Gap panels fill gaps.
- **Weapon ring** (`Pod > WeaponRing`): a flat band at the equator, outside the lattice. It is gyro-stabilised, so it stays level, and it yaws to the aim, not the heading.
- **Cockpit pod** (`Pod`): upright on a two-axis gimbal, turning to the heading. The pilot works its controls mecha-style, so the ball reads as the pilot's own zord and not a hamster ball.

**The Cannon's mecha.**

- **Lattice:** dull petrol enamel on every strut, with copper only on the pivot pins and hubs (ROSTER-LOOK sections 0.2 and 0.7). Outer radius 0.975 m. Thirty scissor chains meet at 12 five-way and 20 three-way hubs, at the base density ROSTER-LOOK section 0.7 and its section 2 budget rule set, so each gap is about as wide as the pilot's head. Every hub is a round copper body with a flat black rubber tread cap. The lattice rides the Core and rolls with the ball (`hero_assets.gd:49-52`). The pilot does not roll.
- **Weapon ring, the machinery:** one flat band at the equator, radius 1.02 to 1.10 m and 0.08 m tall, with an air gap all round the lattice. Worn-bone segments joined by charcoal clamp blocks ride a full-diameter dark-steel bearing collar with copper studs. One big seamless cast barrel, `MainBarrel` with its `LaneMuzzle`, sits on the ring's front arc at 12 o'clock. The ring yaws to the aim on its collar, so the barrel always points down the aim. The barrel pitches from -10 to +35 degrees **start**. Length 1.1 ball radii, bore 0.28 ball radii **start**. Four raised family bands run from breech to muzzle: lane, split, rush, plate. Every pilot's weapon ring follows the aim (ROSTER-LOOK section 0.1). The Cannon's is the only ring with one big barrel (section 0.2).
- **Hub modules:** the split ports, `SplitExit.R/L`, are twin-bore blocks on gap brackets from the Pod at 5 and 7 o'clock (rest pose at the low side hubs). The rush ring, `RushContact`, rides a gap bracket at the bottom (rest pose at the bottom hub) (ROSTER-LOOK sections 0.2 and 4).
- **Cockpit and controls:** a compact pod on a two-axis gimbal. Two nested thin dark-steel rings hold the seat. The outer ring pivots left-right and the inner ring front-back, with copper pivot bosses at each axis. Both rings show through the front gap. The seat back is charcoal, for value contrast with the pilot (ROSTER-LOOK section 0.7). The controls follow the roster layout:
  - twin yokes under the paddles, labelled "1: Cannon Lane";
  - a lever bank beside the right yoke: the plate crank, "2: Cannon Plate", and under it the cable clamp lever, "3: Lane Charge";
  - a copper two-handed lap bar, "Q: Fire Mission", the largest control;
  - exactly two pedals, "Shift: Recoil Split".

  The pilot works them on each cast: a yoke trigger squeeze per lane call, half a crank turn on the plate, a paddle slap on the cable clamp lever for Lane Charge, and both paddles on the lap bar for Fire Mission. The two pedals kick down on Shift; the rig has no leg bones, so code moves them and no clip does (PILOT-CLIPS.md section 5). The smash has no control of its own, so the pilot slaps the seat frame on the slam. The muzzle-head sits above the ring and looks out the front gap along its own barrel.
- **Bands read the bar.** A band lights when its slot is ready: lane on each call, split when Shift is ready, rush on each slam, plate when slot 2 is ready. The bands read the same `slots()` record the HUD reads (SKILL-BAR.md:435), so body and HUD cannot drift. A full meter lights all four (section 3.4).
- **The fold:** in the wind-up the lattice folds to 85 percent of its radius **start** and the gap panels close up like a shell casing. On the landing it springs back to full size in 0.12 s. The Cannon fires itself as the shell, so its mecha becomes one. The weapon ring stays level and full size throughout, and the sight cone stays open. The collider does not change. This fold stands in for the roster's full-span extra (ROSTER-LOOK section 0.5) on this pilot (question 10).

**Gap panels fill with heft class** (classes I to V at heft 1.0, 1.5, 2.2, 3.2 and 4.6, `src/core/run_state.gd:21`). The Cannon's panels are seamless verdigris carapace plates, the roster's showcase (ROSTER-LOOK section 0.2). They drop into the `Gap` empties from the bottom up, and accretion chunks snap to the nearest hub (section 0.3). Two rules bind every class:

1. **No panel ever fills a sight gap.** The sight gaps lie on the cone from the chase camera to the pilot's head and paddles, so the pilot stays fully visible.
2. **Nothing enters the weapon ring's sweep.** No panel or hub module stands out into the band's path, so the ring can always yaw.

| Class | Added | Reads as |
| --- | --- | --- |
| I | none: bare lattice, the weapon ring with its barrel, and the pod; every gap open | a rider at a gun |
| II | carapace panels in the lower gaps, below the pod; a scrap muzzle brake on the barrel | a rider with a weapon |
| III | carapace panels in the side gaps as well; thicker tread caps on the hubs; a scrap jacket over the barrel's breech half | a gun carriage |
| IV | carapace panels in most gaps, with only the sight gaps open; a short scrap skirt hung from the bearing collar | an armoured carriage |
| V | every gap paneled except the sight gaps; the split ports and the rush ring grow to their heavy form | a rolling turret |

Losing a class flings the outermost layer's panels out of their gaps as scrap. Durability is scrap armour; the mecha shows it. The heft layers are `detail` shells beside the mecha's `shell`, and the Choir Barrel variant (section 7) swaps only the `BarrelHousing` node under `WeaponRing` at every layer, so the shell variant and the heft layers share one loader path (the plan's creative-charge call).

**Silhouette rule at chase distance.** The barrel rides the weapon ring at the equator and swings with the aim. With the aim straight ahead, the ball hides it from the chase camera, as the concept picture shows (`artifacts/local/alpha/push/w13/concepts/codex/cannon/chase.png`). So the Cannon's chase read is low: the twin-bore split ports at 5 and 7 o'clock and the rush ring on the bottom hub. When the aim swings well off the camera's line, the long level barrel breaks the outline at the equator on that side. **A2-CRITIC** found that a crown break could not carry the Cannon, because Rivet's stacks and Sable's mast broke the crown too. The Cannon now puts nothing on the crown. Rivet's exhaust stacks stand on rear hubs, high; the Cannon's ports and rush ring sit low. On the ring, Rivet carries twin parallel barrels and the Cannon one big barrel (ROSTER-LOOK section 0.2). The far blind pair must name Rivet against the Cannon 3 of 3 with the aim held straight ahead, the hardest case. P-D's far blind pair checks the rule.

Budgets come from the plan: the pilot GLB under the `pilot` class (4,600 tris, 3,100 verts, 5 draws); the lattice, weapon ring, barrel and pod as `world_one/shell_cannon.glb` under `shell`; gap-panel layers under `detail`. Today's pilot GLB stays (`hero_assets.gd:35`). The static shell takes the asset forge's shell brief (`tools/asset-forge/kinds/model/brief.shell.md`: +Y forward, centre pivot, `Core`, `Pod` and `Dome` nodes). That brief keeps every vertex within 0.985 m. The lattice fits; the weapon ring and barrel do not (question 11).

## 6. Clips

The seven existing reactions stay: `drop_land`, `big_cheer`, `wince`, `slump`, `phew`, `brace`, `heave` (`tools/blender/pilot_cannon.py:35-52`, `src/presentation/pilot_reactions.gd:5-18`). New clips, lengths **start**, ids as the clip spec names them (`design-v3/PILOT-CLIPS.md` section 2):

| Clip | What the pilot does | Length | Trigger | Priority, cooldown |
| --- | --- | --- | --- | --- |
| `idle_loop` | taps a paddle on a yoke every 2 beats; the lenses track the reticle | 2.79 s loop, 8 beats at 172 BPM, so the tap sits on the band | none; loops under every other clip | 0 |
| `class_up` | pats a yoke; the bands flash in motif order as the new carapace panels slam into their gaps | 0.9 s | `heft_class_changed`, rising only (`game_events.gd:36`) | 50, 4.0 s |
| `cast_special` | turns the plate crank, "2: Cannon Plate" in the lever bank beside the right yoke, half a turn; the muzzle drops along the cone | 0.6 s | `slot_cast` with slot `special` | 30, 1.0 s |
| `cast_line` | the right paddle slaps the cable clamp lever, "3: Lane Charge", under the plate crank; the muzzle snaps along the cable | 0.45 s | `line_skill_fired` | 32, 1.0 s |
| `ult_ready` | four small head nods in the motif's rhythm, muzzle up (the lenses stay static, PILOT-CLIPS.md:146; ruled 2026-10-12) | 0.8 s | `ultimate_ready` | 45, 10.0 s |
| `ult_windup` | tucks into the seat and grips the copper lap bar, "Q: Fire Mission", with both paddles as the lattice folds; it holds the bar through the flight in the shared `ult_ride_loop` | 0.35 s | `ultimate_started` | 70, 0 s |
| `ult_strike` | at the apex: paddles wide off the lap bar, muzzle straight down, then back on the bar | 0.5 s | `ultimate_peak` | 68, 0 s |
| `ult_recover` | the lattice springs open; it lets go of the lap bar and shakes out the paddles; muzzle back level. The first 0.25 s is the framework recovery, the rest cancels on input | 0.6 s | `ultimate_landed` | 65, 0 s |
| `smash` | muzzle down at the landing, one paddle slap on the seat frame; the smash has no control of its own | 0.55 s | `slammed` (`game_events.gd:50`), the shared roster row (PILOT-CLIPS.md section 1.1) | 36, 1.0 s |
| `unlock` | settles into the empty cockpit seat; the folded lattice unfolds round it in four steps, one motif note each; it sits up and looks down the barrel | 2.79 s, 8 beats | the first time the class card shows the Cannon unlocked after `achievement_earned("mind_quieted")` (`game_events.gd:174`) | once per profile |

Priorities and cooldowns for the shared signals are the framework's (SKILL-BAR.md:472-480). The pose route is A5's: pose tables to Blender actions on `pilot-v1` by the `anim_pilot_reactions.py` route.

## 7. Earned cosmetics

Nothing is bought. Each item comes from a discovery the codex records (section 8). Achievement rows can only require that some class was chosen (`src/core/progress.gd:258-285`), not which one, so a Cannon-only grant rides a discovery that the code detects with the pilot already known.

| Item | Slot | Look | Granted by |
| --- | --- | --- | --- |
| Recital, `trail_cannon_recital` | trail | four small marks behind the ball in family order: a bar, a V, a ring, a quarter fan. They fade in 0.6 s. Tint `Color("6fb3a6")`, a pale verdigris, far from the hazard and brass hues and from the zones' green | the hidden `cannon_recital` discovery |
| Lens Glass, `paint_cannon_lens` | paint | pale uranium glass, tint `Color("d4f2b0")` | the `cannon_time_on_target` discovery: one Fire Mission landing strikes 8 or more enemies |
| Choir Barrel, `shell_cannon_choir` | shell variant (the CUSTOMIZE slot) | the barrel housing recast with the Mind's six choir shutters round the bore (`mind_dress.gd:23`) | the `cannon_old_tune` discovery: quiet the Mind as the Cannon |

Rows (`cosmetics.gd:23` table shape; the shell row waits for B5's slot):

```gdscript
"trail_cannon_recital": {"slot": "trail", "pilot": "remembered_cannon", "name": "Recital", "starter": false, "tint": Color("6fb3a6"), "asset": "trail_cannon_recital"},
"paint_cannon_lens": {"slot": "paint", "pilot": "remembered_cannon", "name": "Lens Glass", "starter": false, "tint": Color("d4f2b0")},
```

Achievement rows on `synergy_discovered`, which the codex emits for every discovery (`src/core/codex.gd:157`, `game_events.gd:42`):

```gdscript
"cannon_recital": {"name": "Recital", "text": "Land the four families in the order the gun hums.", "on": "synergy_discovered",
	"where": {"synergy_id": "cannon_recital", "first_time": true}, "count": 1, "hidden": true, "reward": {"cosmetic": "trail_cannon_recital"}},
"cannon_time_on_target": {"name": "Time on Target", "text": "Land a Fire Mission on eight enemies at once.", "on": "synergy_discovered",
	"where": {"synergy_id": "cannon_time_on_target", "first_time": true}, "count": 1, "reward": {"cosmetic": "paint_cannon_lens"}},
"cannon_old_tune": {"name": "Old Tune", "text": "Quiet the Mind with its own gun.", "on": "synergy_discovered",
	"where": {"synergy_id": "cannon_old_tune", "first_time": true}, "count": 1, "hidden": true, "reward": {"cosmetic": "shell_cannon_choir"}},
```

**Recital, the hidden rule.** Strike enemies with a lane, a split, a rush and a plate in that order within 6.0 s **start**. Combat already knows each strike's family (`combat.gd:1476`, `:1516-1528`). The motif plays whole on the next beat. **Call (separable):** the recital also refunds half the plate's cooldown, so playing the whole kit in order pays. It uses the existing `refund_special` action (`upgrade_tree.gd:88`).

## 8. Discovery and codex rows

The framework's five rows stay B6's (SKILL-BAR.md:456-464). The Cannon adds these to `src/combat/codex_entries.gd` (`ENTRIES` at `:12`; shape: id, name, hint, clue, text):

| id | Name | Fires when | Hint | Clue | Text |
| --- | --- | --- | --- | --- | --- |
| `cannon_lane_charge` | Lane Charge | the first Lane Charge strikes | The cable already shows where it goes. | a standing line + 3 | Press 3 while the harpoon holds something and the cable becomes a lane that fires at once: through an enemy and 12 m on, or straight out of a wall. Chains make it hit harder. |
| `cannon_fire_mission` | Fire Mission | the first Fire Mission lands | A gun can fire itself. | a full ring + Q + open ground ahead | Q fires you along an arc. Each beat in the air calls one of the Mind's families below you, and all of them land the moment you do. |
| `cannon_creeping_barrage` | Creeping Barrage | the first Creeping Barrage lands | Some fire walks ahead of you. | a line + the barrage | Ride a line and every beat lays a lane across your path just before you reach it. |
| `cannon_plate_mortar` | Plate Mortar | the first Plate Mortar lands | Brace them from above. | a high lob + plates + the landing | Every beat of the lob drops a plate. The landing hits every braced enemy as a slam, at 1.4 times. |
| `cannon_recital` | Recital | lane, split, rush and plate strike in order within 6 s | The gun hums four notes when it is happy. | lane, split, rush, plate | Land the four families in the order the Cannon hums them and the tune plays whole. The plate comes back half charged. |
| `cannon_time_on_target` | Time on Target | one Fire Mission landing strikes 8 or more enemies | Everything at once. | Fire Mission + a crowd | Every shell you called in the air landed on the same beat, on eight of them. |
| `cannon_old_tune` | Old Tune | the Mind falls with the Cannon in the mecha | It got your tune wrong all fight. | the Mind + its own gun | The Mind played your tune back wrong all fight. Its own gun played it right. |
| `mind_quiet_gun` | The Quiet Gun | the Mind falls with any pilot | One of its guns never fired. | the Mind's rim, listening | A gun on the rim never fired. It learned one note each time the Mind showed a new attack. |

`cannon_lane_charge` and `cannon_fire_mission` are the first-time cards for slot 3 and the ultimate. The two variant rows are the first-time cards for depth 3. The last four stay hidden until found.

## 9. Tests and bot checks

Headless proofs that fail loud, in the style of `tests/cannon_kit_test.gd` (the real game, calm, stage 1, targets held in place, `:18-23`):

1. **`tests/cannon_kit_test.gd`**, re-pinned with a dated header. Its steps a to j stay and must pass unchanged (`:81-97`). New steps: Lane Charge on a body latch goes live within 0.1 s plus one tick, runs 12 m past the target and strikes it and one bystander inside once each at 28 x the chain multiplier; on a wall latch it runs out along the normal; a load bites and fires; the chain count is unchanged and the ball stays airborne.
2. **`tests/cannon_ultimate_test.gd`**, new. The path order is arc, line, rail, then the hop. Calls follow lane, split, rush, plate; the middle beat calls all four; the cap is 12. Every call goes live on the landing beat, within one physics tick of the drop, and none earlier. A bail keeps the schedule. A void call is skipped. Damage follows the heft table; bosses take x0.5; a closed guard gets 45 posture at most from the whole set piece; an open core shatters.
3. **`tests/cannon_ultimate_variants_test.gd`**, new. Each depth-3 pick swaps to its variant. Creeping lanes go live one beat before the ball crosses them. Mortar reach is half, the flight is 6 beats, its plates expose, its landing deals x1.4 to the exposed. Each knob does what section 3.6 says.
4. **`tests/mind_quiet_gun_test.gd`**, new. One band per phase; notes B3, E4, G4, D5 in order; the motif whole on the fall; never the hazard or brass colour; no collider; absent with the Cannon as pilot, which shows the empty cradle; the Cannon's answer follows each `mind_adapted` by one beat; `mind_quiet_gun` and `cannon_old_tune` discovered once each.
5. **`tests/ending_sequence_test.gd`**, re-pinned. The gun is in the Highdraft frame; its motif plays once at 8.0 s plus or minus one beat.
6. **`tests/tree_safe_picks_test.gd`**, re-pinned (section 3.6). **`tests/tree_data_test.gd`** and **`tests/tree_depth_cap_test.gd`** pass unchanged.
7. **`tests/cannon_look_test.gd`**, re-pinned: the icons `ab_cannon_line` and `ab_cannon_ult`, the family-note map, the barrel bands reading `slots()`.
8. **`tests/presentation_motifs_test.gd`**: `Harmony.family_note` returns B3, E4, G4, D5 for the four families.
9. The cosmetic rows pass `Cosmetics.validate` (`cosmetics.gd:92-134`); each grant fires once.

**Bot checks.**

- **`tests/bot_six_remembered_cannon_test.gd`** (the win rule lives in `bot_six_pilots_test.gd`, `:1-7`): the bot wins world one, and every winning run casts Lane Charge at least once and lands at least one Fire Mission.
- **Fill band:** over B4's 16 seeds, the Cannon's chaining bot fills the meter in a median of 90 s or less, and the camper in 180 s or more (SKILL-BAR.md:600).
- **`tests/trees/tree_bot_run.gd`:** a Cannon build with a variant and a knob finishes a world-two stage.
- **Bands:** `posture_bands_test` and `alpha_posture_bands_test` stay green with the Cannon.

**Measures that say whether it works** (run-log fields, so a sitting answers them):

| Part | Measure | Healthy band **start** |
| --- | --- | --- |
| Fire Mission targeting | `ultimates[].zone_hits / zones`: the share of calls that struck something | 50 percent or more |
| Time on target | enemies struck on the landing beat, median | 4 or more |
| Lane Charge | `line_skill.on_line` share against `loaded` | half or more on a standing line |
| Exposure read | rams on exposed enemies per plate | 0.5 or more |
| The quiet gun | none headless; Andrew's sitting: did you hear it | a yes |

## 10. Implementation map: wave P-C, unit PC-CANNON

**Depends on P-B, in this order:** B1 (slot model, the line hook, `_line_skills`, `line_id` and `ultimate_id`, the new signals), B3 (`ultimate.gd`, `_ult_rows`, the meter, the four `ult_*` knobs in `KNOBS`, `variant_of` in `safe_pick_problems`), B6 (codex framework rows and detection points), B4 (`_cast`, `_line_hands`, `_ultimate_hands`), B5 (the shell-variant slot and the trail loader), B2 (the bar draws slot 3 and the meter). Until P-D, the quiet gun and the bands use greybox shapes; until P-E, the reaction rows point at stand-in clips (SKILL-BAR.md:470).

**SCOPE, must have:**

- `src/core/class_def.gd`: the Cannon row gains `line_id: "cannon_lane_charge"` and `ultimate_id: "cannon_fire_mission"`.
- `src/core/ability_state.gd`: four rows (sections 2.4, 3.1, 3.5).
- `src/combat/weapons.gd`: a Cannon constants block: `LANE_CHARGE_DAMAGE 28.0`, `LANE_CHARGE_PAST 12.0`, `LANE_CHARGE_WARN 0.1`, `LANE_CHARGE_LIVE 0.3`, `ZONE_DAMAGE 12.0`, `ZONE_REACH 26.0`, `CALL_CAP 12`, `VOID_DROP 12.0`, `APEX_CAP 20.0`, `CREEP_AHEAD_BEATS 2`, `MORTAR_BEATS 6`, `MORTAR_REACH 0.5`, `RECITAL_SECONDS 6.0`.
- `src/combat/combat.gd`, the Cannon section only (`:1456-1603`): the `_line_skills` row, the overrides on `_commit_cannon`, the exposure mark hook, Recital detection.
- `src/combat/ultimate.gd`: three `_ult_rows` entries.
- `src/core/trees/cannon.gd`: 8 swaps and 16 knobs (sections 3.5 and 3.6).
- `src/presentation/harmony.gd`: `family_note(family)`.
- `src/presentation/audio.gd`: family notes on live, the Fire Mission calls, peak and chord, the Lane Charge climb, the Cannon's answer to the Mind's quote.
- `src/presentation/quiet_gun.gd` (new) and one attach line in `src/boss/mind_dress.gd`.
- `src/boss/mind.gd`: the two discoveries in `_on_warden_died` (`:120-123`).
- `src/ui/ending_sequence.gd`: the gun in the Highdraft frame and its motif at 8.0 s.
- `src/combat/codex_entries.gd`: the eight rows.
- `src/core/achievements.gd` and `src/core/cosmetics.gd`: the rows in section 7.
- `src/ui/class_kit.gd`: `WORDS` rows (`:15-46`) "lane charge", "fire mission", "creeping barrage", "plate mortar".
- `src/ui/icons.gd`: `EXTRA` gains `ab_cannon_line` and `ab_cannon_ult` (`:44-49`).
- Tests: section 9.

**Optional, separable:** the Recital refund; counter-battery (off by default, needs Andrew's yes).

**Shared-table note.** Six P-C units edit the same tables at once: `ABILITIES`, `_line_skills`, `_ult_rows`, the cue rows in `audio.gd`, the codex, achievements, cosmetics, `WORDS`, `EXTRA`. Ask B1 and B3 to pre-seed one marked block per pilot in each shared table, so each unit writes only inside its own block and the merges never touch the same lines.

**ACCEPTANCE:**

- The Cannon row names `cannon_lane_charge` and `cannon_fire_mission`; the bar shows Lane Charge on 3 and the meter on Q.
- Lane Charge on a body goes live within 0.1 s plus one tick, along the cable, 12 m past the target; the target and every enemy inside take 28 x the chain multiplier once.
- Lane Charge on a wall fires along the normal; on a post, along the flat aim; neither applies `reel_burst`.
- Lane Charge adds no chain link and never grounds the ball.
- Fire Mission plans arc first; a full meter never meets a dead Q.
- Fire Mission calls lane, split, rush, plate in order, all four at the middle beat, 12 at most, none over a void.
- Every Fire Mission call goes live on the landing beat, within one tick of the drop; a bail or a collision keeps the schedule.
- Each family's note plays on live from `MOTIFS["cannon"]`; the Fire Mission landing strikes the four as one chord.
- A closed guard takes 45 posture at most from one set piece; bosses take x0.5; an open core shatters.
- Every depth-3 pair offers one Creeping Barrage and one Plate Mortar; each node's old op still works.
- Every depth-4 node carries one `ult_*` knob and siblings differ; each knob does what section 3.6 says.
- Plate Mortar's landing deals x1.4 to enemies its plates exposed.
- The plate's exposure mark shows on every exposed enemy for exactly the window.
- The quiet gun lights one band per Mind phase, plays the motif on the fall, never wears a hostile colour, has no collider, and is absent with the Cannon as pilot.
- The Cannon answers each `mind_adapted` quote one beat after it ends, never before.
- The ending shows the gun in the Highdraft frame and plays its motif once at 8.0 s plus or minus one beat.
- The three cosmetics validate and each grants once from its discovery.
- `tests/cannon_kit_test.gd` steps a to j pass unchanged; every test in section 9 passes or is re-pinned with a dated header.
- `bot_six_remembered_cannon_test` wins world one with at least one Lane Charge and one Fire Mission per winning run.
- With the Cannon, each grown Warden breaks at 25 s or more after its turn: `tools/bot_run.gd -- --policy=skipper --seeds=6 --pilot=remembered_cannon --table=alpha --from-stage=3 --until=4`, then `--from-stage=5`. `alpha_posture_bands_test` does not sample the Cannon (gate note, 2026-10-12). First measured at merge: 27.54 s and 31.04 s.
- `git diff --name-status` shows only the SCOPE files.

**VERIFY:** `tools/coordinator/compile_check.sh`; `node scripts/sketch-lint.mjs --sketch core-loop`; the section 9 tests by name, each reporting a nonzero case count; `npm run sketch:smoke -- --sketch core-loop`. Automated play does not establish feel: the sitting judges whether time on target lands as a drop and whether the quiet gun is heard.

## 11. Open questions and veto list

### For Andrew, one line each

1. Counter-battery (a Cannon lane down a live Mind lane cancels it): build it, or leave it off? Default: off.
2. Recital: refund half the plate cooldown as well as the trail, or the trail alone? Default: both.
3. The ending: keep the Highdraft copy and let the gun answer "Nobody answers", or change the line? Default: keep it.

### For the coordinator and the P-B owners, one line each

4. The meter counts every Cannon strike as kind `cannon` (`combat.gd:1525`), so plate, split and rush hits may fall under the weapon cap of 0.4 a second; default: B4 measures, and if the Cannon's chaining median passes 60 s, B3 counts non-weapon sources (`combat.gd:1570`, `:1583`, `:1602`) as their own weight.
5. Who adds the four `ult_*` knobs to `KNOBS` (`upgrade_tree.gd:54-76`) and teaches `safe_pick_problems` (`:183-227`) that a swap to a `variant_of` row is growth? Default: B3, as the Sable sheet also asks.
6. SKILL-BAR.md:466 sends depth-3 and depth-4 card copy to `world_one_cards.gd`, but that table only shows at depths 1 and 2 under the world-one flag (`world_one_cards.gd:3-5`, `:71-77`); default: the node's own `effect` plus `SET_PIECE_LINES` is the card.
7. ABILITIES `beats` has no stated meaning; default: 0 means the path length sets the beats, a positive number fixes them.
8. Achievements cannot require a specific pilot (`progress.gd:258-285`); default: Cannon-only grants ride codex discoveries detected in code, as section 7 does.
9. Six P-C units edit the same tables; default: B1 and B3 pre-seed one marked block per pilot.
10. The Cannon folds its lattice to 85 percent for Fire Mission, where the roster's full-span extra opens it past rest (ROSTER-LOOK.md section 0.5); default: the Cannon keeps the fold, and if the full-span extra is on, its landing springs past rest to the full span before it settles.
11. The asset forge's shell brief keeps every vertex within 0.985 m, but the weapon ring reaches 1.10 m (ROSTER-LOOK.md section 0.1) and the barrel reaches further; default: as ROSTER-LOOK section 9 says, a forge draft keeps the 0.985 m limit and covers only the lattice, pod, controls and gap panels, and the tracked recipe builds `WeaponRing`, the barrel and any module past the lattice, so nothing is exempted from the limit.

### Veto list (Calls under the creative charge; say "veto" on any line)

1. Each family has one note from the motif: lane B3, split E4, rush G4, plate D5, sounding when the zone goes live.
2. Slot 2 stays today's plate, plus a visible exposure mark.
3. Lane Charge strikes almost at once (0.1 s warn), because the cable already drew the lane.
4. On a wall, Lane Charge fires straight out along the normal, and the Cannon gets no `reel_burst`.
5. Fire Mission prefers the arc: the Cannon fires itself as the shell.
6. Fire Mission is time on target: every zone called in the air lands on the landing beat.
7. The peak calls all four families round the landing point at once.
8. The calls play the motif as the build; the landing strikes it as one chord on the drop.
9. The 45-posture cap covers the whole set piece, not the landing alone.
10. Depth 3: Creeping Barrage (line first, lanes rolling ahead) against Plate Mortar (high lob, plates, a slam landing), every pair one of each, every old op kept.
11. Depth 4: every leaf keeps its op and gains one `ult_*` knob; siblings differ.
12. The barrel rides the level weapon ring at the equator and follows the aim; with the aim ahead, the low split ports and the rush ring carry the chase read.
13. No gap panel ever fills a sight gap at any heft class.
14. The Hoberman lattice folds into a shell casing for the wind-up and flight, and springs open on the landing.
15. The quiet gun learns one note per Mind phase and plays the motif when the Mind falls.
16. The ending shows the gun at the gate and lets it answer "Nobody answers from the next island"; no copy change.
17. A Cannon fighting the Mind finds an empty cradle on the rim and answers each wrong quote with its motif played right.
18. The three cosmetics come from discoveries: Recital trail, Lens Glass paint, Choir Barrel shell.
19. The idle loop is 8 beats at 172 BPM, so the pilot's tap sits on the band.

# Sable, pilot sheet (`pylon_engineer`)

Status: historical wave 13 design spec (`unit A2-sable`, 2026-10-10, `cand/alpha-w13`); kit rows, line skill (`bank_shot`), and ultimate (`cable_run`) have since landed in `sketches/core-loop/src/` (`PILOT-CADENCE.md` owns current weapon timing). Paths without a prefix are under `sketches/core-loop/`. A number marked **start** was a starting tune value. A line marked **Call** is a decision made under the creative charge; section 11 collects them as the veto list.

**Weapon fire (ruling ek, 22 Nov 2026):** how this pilot's weapon fires, with its timers, damage and first tree pick, is now [PILOT-CADENCE.md](../PILOT-CADENCE.md) section 3.2. Where this sheet's weapon text differs, that page wins.

Reads with: [SKILL-BAR.md](../SKILL-BAR.md) (the bar, the line-skill hook and the set-piece contract; every interface name here is that file's), [ROSTER-LOOK.md](../ROSTER-LOOK.md) (the Hoberman mecha), [PARK.md](../PARK.md) (the stages and Warden anchors), [LEGIBILITY.md](../LEGIBILITY.md) and [HOOK-CHAIN.md](../HOOK-CHAIN.md). Settled inputs: the 10 Oct grill decisions (original session plan notes archived offline; settled rules live in `DECISIONS.md`).

Terms, defined once:

- **Anchor**: anything the harpoon line can bite and pivot on: a steep face, a post, a Warden hardpoint, an enemy body.
- **Bank Shot**: Sable's line skill (slot 3). It whips the ball round the anchor and sends it toward the aim.
- **Stake**: a short pylon Sable drives during her ultimate. It stands for 6 s and the harpoon can bite it.
- **Beachhead**: the pylon Sable plants at the end of her ultimate, the point B.
- **Exit**: the velocity the ball leaves a pivot with. Sable's kit is mostly about exits.
- **Slingshot grammar**: bank the speed you arrive with, then pay it back along the look, plus a bonus. Today it lives in the pylon slingshot (`src/movement/augments.gd:610-613`) and the vault kick (`:183-212`), which share one eject line (`:622-630`).

## 1. Fantasy, and what nobody else does

**Fantasy in one line:** a fox engineer who turns the world into launch points, then leaves every one of them faster than she arrived.

That is the class pitch made physical: "Plant a beachhead, then launch off it like a cannonball" (`src/core/class_def.gd:88`). The Bible's version: she measures "an opening by the angle of the cable that could cross it" (`BIBLE.md:283`), and her ultimate is "a committed slingshot surge" where "deployable anchor hardware loads, then releases a player-chosen path through a fight" (`BIBLE.md:294`).

**Her mechanic, which no other pilot shares:** Sable's power is speed she banks on an anchor and pays back off it. Every part of the kit reads that one fact.

- The discharge's size is a speed: the gauge "stands in for speed in the discharge curve" (`src/combat/combat.gd:1377-1383`), fed through `Weapons.burst(speed)` (`src/combat/weapons.gd:170-178`).
- The mount banks arrival speed (`augments.gd:583`) and the slingshot pays back 0.85 of it plus 6 m/s (`src/movement/tuning.gd:31-32`).
- The vault kick pays back incoming x 1.8 off a face (`augments.gd:83-89`).
- The arc slam marks faces as vault invitations (`src/movement/player_ball.gd:945-957`).
- New: Bank Shot pays it back off the harpoon line at rope range. Cable Run drives stakes, new anchors, and exits at blazing speed.

**One grammar at three distances.** The vault works at contact (1.5 m, `augments.gd:62`). The slingshot works on a planted pylon. Bank Shot works anywhere the line bites, out to 45 m (`tuning.gd:18`). The family look is deliberate: it is her identity, and each distance has its own niche and numbers.

| Pilot | Where their power comes from (code today) | Line flavour (SKILL-BAR.md:181-186) | How Sable differs |
| --- | --- | --- | --- |
| Rivet | Holding a sprint that ignores crowd control (`augments.gd:215-217`) | Force: the target is knocked hard; the ball yanks to the anchor | Rivet sends force into the target. Sable takes the speed herself and the target is only the pivot. Rivet yanks you to the anchor; Sable slings you past it. |
| Kest | Position: blink 8 m, glide, sticky payloads (`augments.gd:102-103`, `weapons.gd:51-54`) | Payload: a charge rides the cable | Kest moves by vanishing. Sable moves by bending her line of travel. |
| Tarn | Pulling herself in with the claw and clamping (`augments.gd:104-108`, `weapons.gd:86-95`) | Claw drag: the target is pulled to the ball | Tarn brings things to her. Sable never stops to hold anything. |
| Tally | Cards from one pressure pool (`src/core/ability_state.gd:68`) | Ledger clip | No overlap in kind. |
| Cannon | A fixed recoil kick along the aim, 1.3 x the dash floor (`augments.gd:113-116`) | Lane charge: a lane fires along the cable | Cannon's recoil is a flat floor anywhere. Bank Shot needs an anchor and scales with entry speed (x 1.25 + 4 m/s), so fast in means faster out. |

## 2. Kit

### 2.1 The bar and the chips

| Place | Ability (id) | What it does | Fire shape | Numbers | What the player sees and hears | Stays from today | New |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 (home) | Arc caster (`arc_caster`); a pylon turret while mounted (`pylon_turret`) | Fat electromagnetic bolts that chain one jump | auto: held left click fires one volley per interval | 12 damage, 5 a second, 70 m, bolt radius 0.55 m, 1 chain jump within 9 m at 0.7 falloff. Mounted: 11 damage, 9 a second, 95 m, 2 jumps within 16 m at 0.75 (`weapons.gd:34-37`) | Mint bolts; the turret's are lighter mint (`weapons.gd:158-159`). Each bolt rings the motif's ninth, E5 (`SOUND-STORY.md:45`) | All of it, including the mounted swap (`ability_state.gd:49`, `combat.gd:999-1003`) and Air Turret (`combat.gd:1001`) | Nothing. Key 1 is home, and the selection snaps back here. |
| 2 | Arc discharge (`detonation_gauge`) | A ring of arcs from the ball into the nearest enemies | gauge: left click held with 2 selected fills it over 1.0 s; release fires; full plus 0.5 s fires by itself (`ability_state.gd:86`, `:108-119`) | 5.0 s cooldown, 1 charge (`ability_state.gd:51`). Tap: 2 targets, 12 m, 14 damage. Full: 8 targets, 30 m, 70 damage (`weapons.gd:74-83`, `:170-178`) | The committed ring grows on the ground (`combat.gd:1386-1389`); the motif climbs a note per ring and resolves onto a bright chord on release (`SOUND-STORY.md:44`, `:90-92`) | The gauge, the numbers, the mounted bank (`combat.gd:1379-1383`), the free plant discharge on every mount (`combat.gd:1881-1893`), Twin Discharge and Auto Gauge (`combat.gd:1274`, `:1307-1308`) | Picked with 2 and cast with left click (F retires). Two refinements below (**Call**). |
| 3 | Bank Shot (`bank_shot`) | On a standing line: whip round the anchor and leave toward the aim, faster | tap; with no line, it loads the next bite for 4.0 s (SKILL-BAR.md:140-147) | 8.0 s cooldown, 1 charge. Exit = min(45, max(entry, 13) x 1.25 + 4) m/s **start**. Body pivot: 10 x chain multiplier damage, knock 12 **start** | A rigid mint flash along the line, a short swing, the exit cone; the octave leap D to D pitched by exit speed and the spool's ratchet clack | The harpoon, the line states and the eject line it reuses (`augments.gd:622-630`) | All of it. Full spec in 2.3. |
| chip, Shift | Boost (base rule) | A shove along your travel | press | +11 m/s, 1.1 s cooldown (`tuning.gd:74-75`, `src/movement/ball_rules.gd:137-148`) | The boost whoosh; the chip shows the cooldown (SKILL-BAR.md:98) | All of it. Sable is the only pilot on the base boost; the others' Shift is their class burst (`player_ball.gd:484-504`) | Drawn as a chip at 0.75 scale. |
| chip, Ctrl | Arc slam (`arc_slam`); Crater Slam (`crater_slam`) by tree or relic | The shared slam, then every steep face within 12 m glows as a vault invitation for 2 s | Ctrl in the air | Shared slam: 9 m, knock 26 x strength (`augments.gd:67-68`, `player_ball.gd:891-902`). Face tags: 16 rays, 12 m, 2 s (`player_ball.gd:40-42`, `:945-957`) | A mint shock ring (`combat.gd:333`); the womp plus a low root and fifth on mallet (`SOUND-STORY.md:103`, `src/core/event_kinds.gd:108`) | All of it, including Crater Slam spending the special for a full discharge (`combat.gd:2356-2360`) | Its own clip (section 6). |
| Q | Cable Run (`cable_run`) | Ride a cable to where you aim, drive a stake every beat, plant a beachhead and slingshot out | press at a full meter | Section 3 | Section 3 | The RideRail carrier and slingshot maths it reuses | All of it. |

**Extras that stay instant and unchanged.** RMB is the harpoon, which for Sable is her movement row, the grapple (`ability_state.gd:50`). Space in the air at a steep face is the vault kick: incoming x 1.8, capped at 45 m/s, each face locked for 1.5 s (`augments.gd:83-99`, `:183-212`). E at a steep face mounts the pylon and banks the speed; Space while mounted is the slingshot gauge, 0.8 s to fill, x 1.3 at full (`augments.gd:79-82`, `:610-613`). The mount stays on E (SKILL-BAR.md:410).

### 2.2 Slot 2 refinements

Both are **Calls**. The special keeps its id, gauge and cooldown.

1. **Live discharge.** The discharge reads the larger of the gauge speed (gauge x 40 m/s), 0.75 x the ball's current speed, and the mounted bank. Today it reads only the gauge or the bank (`combat.gd:1379-1383`). A tap at blazing speed (26.6 m/s, `src/movement/speed_tier.gd:8` with cruise 14 at `tuning.gd:7`) then fires a discharge at 20 m/s: 6 targets, 21 m, 42 damage. Why: the coil feeds on speed everywhere else in her kit, and this rewards keeping momentum (principle 1). It also separates her special from Rivet's blast, which only the gauge scales (`combat.gd:1406-1409`).
2. **Five rings.** The gauge readout draws five rings from 12 to 30 m, one per motif note, so the rings and the notes count the same. This is SOUND-STORY's "could" item (`SOUND-STORY.md:268`). The coil mast's five winding bands light with them (section 5).

The two Sable discharges stay distinct by ear: the release is the whole arpeggio resolving; the plant discharge is the plant clack plus the first three notes (`SOUND-STORY.md:261`).

### 2.3 Bank Shot, the line skill

The fields SKILL-BAR.md:159-173 asks every sheet to fill:

| Field | Bank Shot |
| --- | --- |
| `id`, icon, name | `bank_shot`, `ab_sable_line`, "Bank Shot" |
| Fire shape | tap, committed on the press (SKILL-BAR.md:90) |
| `cooldown`, charges | 8.0 s, 1 (the framework default) |
| `on_world` | The line goes rigid for one frame of feel and the ball leaves along `Augments.eject_direction(n, aim)`, where n points from the anchor to the ball (`augments.gd:624-630`). Exit speed = min(45, max(v_in, 13) x 1.25 + 4) m/s **start**, plus the Mass-S room when that profile is on (`augments.gd:90-98`). The line releases with a quiet cut cause `bank`, which publishes nothing, so no rust "broke" twang (`player_ball.gd:297-299`, `:614-623`). Worked numbers: in at cruise 14 m/s, out at 21.5; in at 20, out at 29; in at blazing 26.6, out at 37.3; in at 33 or more, out at the 45 cap. |
| `on_body` | The latched enemy is the pivot. The ball exits as on a world anchor. The pivot takes 10 x `chain.multiplier()` damage as an `arc` strike and a knock of 12 opposite the exit **start**. The speed goes to Sable; the target only turns her. Plating resolves through `resolve()` like any hit (`combat.gd:53-56`). |
| During a committed smash (`LINE_SMASH`) | The pivot arc fires at once. The redirect waits for `harpoon_smashed` and fires from the landing point, so the smash still pays in full and Sable slings off the wreck. |
| `load_seconds` | 4.0 (default). A load shows as the Bank Shot icon inside the reticle ring and a mint hook head. |
| Chain scaling | Damage uses `chain.multiplier()` at the moment it fires: x 1.0 at combo 1 to x 2.5 at 6 (`src/combat/chain.gd:17-20`). |
| Committed geometry | The exit cone, the slingshot cone's shape (`player_ball.gd:992-995`): apex at the ball, along the computed exit, 5 m x (1 + exit / 45) long, half angle 0.3 rad. It draws whenever slot 3 is selected and a line stands, and the cast flies exactly that vector. One query for the preview and the act (`adr/TADR-008-ability-contract.md:38`). |
| Ground contact | None. The exit is airborne and the line release keeps the chain's 0.8 s airtime grace (`chain.gd:21-22`), so Bank Shot is how Sable routes a chain from one target toward the next. |
| Coil Hook | Bank Shot's release is not an RMB release, so Coil Hook's fling (`player_ball.gd:710-719`) does not stack on it. Coil Hook keeps your line of travel; Bank Shot turns it. |
| Parting Shot | The exit resets the slingshot timer that `parting_shot` reads (`combat.gd:372-374`, `:2551-2552`), because it is a slingshot at range. |
| Warden and boss read | A Warden hardpoint is a world-style line (PARK.md:414), so Bank Shot is `on_world` there: pure movement, no damage, no posture, no resist. On a boss body the pivot damage is x 0.5 (SKILL-BAR.md:308) and the boss does not move. Movement is never resisted, so no "nope" glyph is needed. |
| Sound | `sable_bank`: the spool ratchet clack, then the octave leap D to D (the vault's interval, `event_kinds.gd:97`) with the top note pitched by exit speed toward 45 m/s. It rises a step per chain link like `chain_link`. |
| Card line | "Whip round the line, leave toward your aim." (8 words) |
| Discovery card | Section 8, `bank_shot` |
| Clip | `cast_line`, 0.5 s (section 6) |

**Why a tap, when slot 2 is a gauge.** Two fire shapes on one bar keep the two slots apart by hand as well as by effect: hold to grow a burst, tap to turn. A gauge on a moving line would also make her hold a pick while swinging, which costs momentum.

**Load example.** Pick 3, click with no line: the hook head turns mint and the 4 s ring drains. RMB at a wall 30 m ahead: the bite latches and Bank Shot fires on that tick, so the ball leaves the wall toward the aim. The bite still links like any bite (SKILL-BAR.md:151).

## 3. The ultimate: Cable Run

**Fantasy:** the engineer runs a cable across the gap, staking it as she goes, and comes off the far end like a cannonball.

### 3.1 The contract fields (SKILL-BAR.md:314-326)

| # | Field | Cable Run |
| --- | --- | --- |
| 1 | id, name, icon | `cable_run`, "Cable Run", `ab_sable_ult` |
| 2 | `paths` | `["line", "rail", "arc"]`, the framework order (SKILL-BAR.md:244-250). No reach override: line 45 m, arc 40 to 70 m by class. |
| 3 | Tech | One stake per beat, driven where the ball is on the drawn path. Each stake arcs on planting to up to 3 enemies within 10 m: 12 damage x heft multiplier each (the framework volley, SKILL-BAR.md:272). |
| 4 | Peak | "The relay closes": every standing stake arcs once more to its nearest enemy within 10 m, 12 damage x heft multiplier, and the stakes flash a mint cable between them for 0.5 s. The cable is a picture, not a damage line. |
| 5 | Landing | The beachhead. A discharge ring at B: 60 x heft multiplier x chain multiplier, within the class landing radius (6 to 10 m), knock 26 (SKILL-BAR.md:276). Then the slingshot exit (3.2). |
| 6 | Heft scaling | The framework table (SKILL-BAR.md:232-236), plus the Mass-S bonus on the exit (3.3). |
| 7 | Music | Section 3.5, motif `sable`. |
| 8 | Mecha | Ready: four wrenches lit, coil tip breathing. Wind-up: the spool locks with a clack and the coil mast sparks. Flight: the spool pays the cable out to B and a stake drops from the spool hatch each beat. Landing: the coil discharges white-mint and dims (section 5). |
| 9 | Clips | `ult_ready` 0.8 s, `ult_windup` 0.35 s, `ult_strike` 0.7 s, `ult_recover` 0.6 s (section 6) |
| 10 | Depth 3 | Ball Lightning and Outpost (3.6) |
| 11 | Depth 4 | The four framework knobs, read per variant (3.7) |
| 12 | Wardens and bosses | 3.4 |
| 13 | Card line, discovery, run log | "Ride a cable; every beat drives a stake." (8 words). Discovery `cable_run` (section 8). Run log: the framework `ultimates` row with `id: "cable_run"`, plus Sable's `stakes` and `stakes_hooked` counts (section 10). |

### 3.2 The ride, beat by beat

Framework timing (SKILL-BAR.md:242-258): wind-up 0.35 s, flight = path length / 18 m/s clamped to 1.6 to 3.2 s and rounded to whole beats, recovery 0.25 s. At 172 BPM a beat is 0.349 s (`src/presentation/harmony.gd:8`), so a flight is 5 to 9 beats. At the boss tempo of 129 BPM (`harmony.gd:25`) it is 4 to 6 beats.

| Moment | What happens | Player sees | Player hears |
| --- | --- | --- | --- |
| Q at a full meter | The path is planned once and drawn in live mint, with a small tick mark at each beat where a stake will stand | The whole path and its tick marks; the corridor rails | The meter's lift is already playing |
| Wind-up, 0.35 s | The spool locks. Q again recalls with a full refund. | The pilot points down the line | Spool clack, the launch build starts |
| Each beat | A stake drops at the ball's point on the path, held in the mint field, and arcs to up to 3 enemies within 10 m | A 0.9 m copper-and-bone spike with a mint ring at its foot, then its arcs | One motif note per stake, climbing (3.5) |
| Middle beat (peak) | Every standing stake arcs again; the cable flashes between them | The relay lights end to end | The whole motif as a stinger |
| Landing | The beachhead plants at B and fires the discharge ring | A ring at B and the planted beachhead | The drop on the beat |
| Exit (inside the 0.25 s recovery) | The beachhead slings the ball out (below) | The exit cone flashes, then the ball is gone at blazing | The octave leap |
| After | The stakes and the beachhead stand 6.0 s **start** as anchors, then fold away | Each stake's mint ring drains over its 6 s | A soft clink as each folds |

**The exit.** Speed = clamp((v_flight x 0.85 + 6) x 1.3, blazing + 0.5, 45) m/s **start**, where v_flight is the flight's own path speed. That is the slingshot's keep and boost (`tuning.gd:31-32`) at a full gauge (`augments.gd:82`), floored so the exit always reads blazing: 27.1 m/s at cruise 14 (`speed_tier.gd:8`). At the nominal 18 m/s flight it is 27.7 m/s. On a steep face the direction is the slingshot's eject line (`augments.gd:624-630`). On walkable ground (normal y at or above 0.7, `augments.gd:61`) it is the flat aim tipped up 12 degrees **start**, because the face formula would throw the ball about 50 degrees up off flat ground. The exit counts as a slingshot for Parting Shot (`combat.gd:2551-2552`).

**Stakes as anchors.** A stake is a world anchor: the harpoon bites it from rope range, the ball swings on it as on a wall, and HOOK-CHAIN counts it as a pivot, not a link (HOOK-CHAIN.md:21). Bank Shot off a stake is `on_world`. A stake has no ball collision, so the ball never clips the one it just dropped. Mechanism: stakes sit on a new anchor-only physics layer that the harpoon's target query includes (`src/movement/harpoon.gd:20-29`, mask `WORLD_MASK | ENEMY_MASK` today) and the ball's body mask excludes (the ball is layer 2, `src/movement/rigid_ball.gd:56-58`). At most 11 stand at once; a new Cable Run folds the old ones. Stakes fold on a stage change, a death and a retry.

**Why the stakes float.** The stake marks exactly where the ball passed, which is exactly what was drawn at commitment, and over a gap it leaves a row of hook points in the air. That is the "route through a fight" the Bible asks for (`BIBLE.md:294`). Planting them on the ground below is the fallback (open question 4).

**Defence, camera, cancels.** The framework's: damage taken x 0.2 with health floored at 1, no knockback, no hold can start, no scrap lost (SKILL-BAR.md:278); Space bails, a collision lands early (SKILL-BAR.md:292-299). A bail drops no further stakes and the ones already driven stay. Mounted Sable may press Q: the mount ends and the path leaves from the mount point (SKILL-BAR.md:310).

### 3.3 Heft-class scaling

| Heft class | I | II | III | IV | V |
| --- | --- | --- | --- | --- | --- |
| Damage multiplier (framework) | 1.00 | 1.15 | 1.30 | 1.45 | 1.60 |
| Landing radius (framework) | 6 m | 7 m | 8 m | 9 m | 10 m |
| Arc reach (framework) | 40 m | 47 m | 55 m | 62 m | 70 m |
| Exit with Mass-S on, nominal flight | 27.7 m/s | 29.5 m/s | 32.1 m/s | 35.7 m/s | 35.7 m/s |
| Mecha | bare lattice | lower gap panels | side gap panels | most gaps paneled | doubled coil |

The Mass-S row: heft h gives mass (h - 1) x 450 (`augments.gd:95-96`), q = mass / 990 capped at 1, bonus q x 8 m/s (`augments.gd:93-94`). It applies only with Mass-S on (`--world-one-builds`, `augments.gd:90-92`); off, the exit is 27.7 m/s at every class. The stake count follows the beats, not the class, so heft buys hitting power and a faster exit, never a busier screen.

### 3.4 Wardens and bosses

The framework rules hold (SKILL-BAR.md:301-308). Sable adds:

- **A closed guard.** Stake arcs are gun-class hits: half damage and 1.5 posture each (LEGIBILITY.md:85). The landing adds up to 45 posture once and cannot crack. Read: slate sparks and the low clank.
- **An open core.** A landing on it shatters the chunk (Curtain Call, SKILL-BAR.md:462).
- **The finisher setup.** Stakes driven past a Warden give anchors on its far side. Hook a stake, Bank Shot into the open core, haul: the drop finisher from an angle the Warden's mounting does not offer. Example: on the dam face (PARK.md:372), a Cable Run along the toe apron leaves stakes beside the water sheet.
- **A Warden hardpoint as B.** A `line` path may end on a hardpoint (PARK.md:414). Landing there while the core is open is the drop finisher.
- **Bosses** (Brindle, the Waking, the Mind). x 0.5 damage, phase windows untouched, a brace pose and the "nope" glyph at the landing (SKILL-BAR.md:308). Stakes still stand as anchors in the authored arenas. Brindle's banked outer ring is the fight's momentum lane (`src/boss/arena.gd:9`), and stakes on it give swing points.

### 3.5 The music moment

Sable's motif is D4 F4 A4 C5 E5: the Dm9 stacked up, even sixteenths "like a winch reeling", mallet and bell, ending open on the ninth because "it launches rather than resolves" (`SOUND-STORY.md:40-44`). Cable Run spells it out across the ride:

| Moment | Synth band | ACE band |
| --- | --- | --- |
| Meter full | The framework's one-layer lift at the next bar (SKILL-BAR.md:286); the ready cue is the motif's three notes an octave up and a small bell | the pressure step |
| Wind-up | `start_build(flight_seconds, true)` | the band holds |
| Each stake | One motif note on its beat, climbing D F A C E, then D5 F5 A5 C6 for beats 6 to 9; a winch ratchet tick on each off-beat | the same notes on the ACE grid |
| Peak | The whole motif in sixteenths an octave up, as the stinger | the same stinger |
| Landing | `drop_now(4, 0.85)` on the landing beat, voiced with the gauge release's cadence: the ninth resolving onto a bright chord | handover on the beat |
| Exit | The octave leap, D to D, the vault's interval (`event_kinds.gd:97`) | same |

The beat rounding (SKILL-BAR.md:258) is what makes this work: the stakes fall on beats, so the notes do too. The motif never resolves anywhere in a run except at the landing and the gauge release, so the landing sounds like arriving.

### 3.6 Depth 3: two variants, every route

`depth_cap` is `clamp(world_index + 1, 2, 4)` (`src/core/upgrade_tree.gd:119-120`), so depth 3 opens in world two.

| | Cable Run (base) | Ball Lightning (`ball_lightning`) | Outpost (`outpost`) |
| --- | --- | --- | --- |
| Lean | the bridge between the halves | Cannonball half: "boom, bounce" (`src/core/trees/sable.gd:3-5`) | Beachhead half: "take point, turret" |
| `paths` | line, rail, arc | arc only (then the hop); arc reach +10 m, so 50 to 80 m by class | line, rail, then arc |
| Wind-up | spool locks | a pylon plants at A and slings her up the arc | spool locks |
| Tech per beat | a stake arcs to 3 within 10 m | a discharge bolt strikes the ground under the ball: a 6 m ring, 3 targets, 12 x heft (skipped if no ground within 40 m) | a stake arcs to 3 within 10 m, as base |
| Peak | the relay closes | the apex discharge: `Weapons.burst(20)` from the ball: 6 targets, 21 m, 42 damage x heft (`weapons.gd:170-178`); drawn as a committed ring at the apex during the wind-up | the relay closes |
| Landing | discharge ring 60, class radius | a crater: 60 x heft x chain in class radius + 3 m (9 to 13 m), knock 26; every steep face within 12 m tagged for a vault for 2 s (`player_ball.gd:945-957`); the air jump restored (as `augments.gd:209-210`) | plants the outpost and **mounts it**: the free plant discharge from a bank equal to the flight speed (`combat.gd:1883-1893`), about `Weapons.burst(18)`: 5 targets, 20 m, 39 damage, x heft x chain. It replaces the landing ring. |
| Exit | the slingshot at blazing | a bounce: the horizontal velocity kept, the vertical set to +8 m/s **start** | none: she is mounted with the bank. Space taps or charges the slingshot as today (`augments.gd:79-82`); E dismounts. |
| After | stakes stand 6 s as anchors | the face tags last 2 s | for 4.0 s, on each beat, the 3 stakes nearest an enemy within 30 m fire one turret bolt each: 11 damage, 2 chain jumps (`weapons.gd:36-37`, `:245`), the Sentry Post grammar (`combat.gd:2323-2353`) at a budget the beat sets |
| Music | the motif climbs per stake | the ascent plays D F A; the apex holds C and E with the bell and a thunder tail; each rain strike plays the root D | the stakes climb; the landing is the plant cue, clack plus the first three notes (`SOUND-STORY.md:261`); sentry bolts tick D on the beats and close on E |
| Flat-ground mount | n/a | n/a | New: the outpost may plant on walkable ground. Pylons bite only steep faces today (`augments.gd:63-64`). |

Outpost is the one set piece that ends with the ball still. The wind-up draws a pylon glyph at B with the bank readout, so the stop is foreseen, and Space pays the bank back at once (A2-CRITIC momentum check).

Ball Lightning needs sky; Outpost works under a roof. The depth-3 pick happens at the workshop before both Dig stages, so it is a real trade (section 4).

**Node mapping.** Every one of the eight depth-3 nodes keeps its kit op and gains one `swap`. Siblings always differ, so every offered pair is one Ball Lightning and one Outpost. That includes the retained pair a world-one Face Runner pick produces: Echo Gauge (8) with Hook Charge (6), because `_retained_pair` swaps the held Face Runner for the first unheld depth-3 node under Cannonball (`upgrade_tree.gd:389-411`).

| Index | Node (kept as is) | Kit op today (`trees/sable.gd`) | Added op |
| --- | --- | --- | --- |
| 6 | `s_hook_charge` Hook Charge | proc: `grapple_fired` discharge 0.25 (`:24-25`) | `"swap": {"ultimate": "ball_lightning"}` |
| 7 | `s_pendulum` Pendulum | proc: `slammed` discharge 0.4 (`:26-27`) | `"swap": {"ultimate": "outpost"}` |
| 8 | `s_echo_gauge` Echo Gauge | charges: special +1 (`:28-29`) | `"swap": {"ultimate": "outpost"}` |
| 9 | `s_face_runner` Face Runner | knob: `vault_air`, `vault_lock` 1.0 (`:30-31`) | `"swap": {"ultimate": "ball_lightning"}` |
| 10 | `s_twin_prongs` Twin Prongs | pattern: arc caster count +1 (`:32-34`) | `"swap": {"ultimate": "ball_lightning"}` |
| 11 | `s_overwatch` Overwatch | knob: `mounted_recharge` 2.0 (`:35-36`) | `"swap": {"ultimate": "outpost"}` |
| 12 | `s_rope_anchor` Rope Anchor | knob: `winch_mount` (`:37-38`) | `"swap": {"ultimate": "ball_lightning"}` |
| 13 | `s_siege_plate` Siege Plate | knob: `plant_all` (`:39-40`) | `"swap": {"ultimate": "outpost"}` |

The world-one copy of Face Runner (`FACE_RUNNER_WORLD_ONE`, `trees/sable.gd:82-85`) sits at depth 2 and gains nothing.

**Call: stack, do not replace.** The plan says depths 3 and 4 "hold ultimate variants". Replacing the 24 deep nodes would delete Crater Slam, Sentry Post, Storm Caster and the rest of her late kit. Adding a second op keeps every build intact, keeps `tree_data_test`'s four-key check (`tests/tree_data_test.gd:46-50`) without a new key, and still changes every route's set piece by world three.

**Card copy.** A node's `effect` stays (8 words at most, `upgrade_tree.gd:50`). The card adds a second line from data: "Set piece: Ball Lightning". The text comes from a `SET_PIECE_LINES` table keyed by ultimate id and by knob (section 10), so the card can never disagree with the op.

### 3.7 Depth 4: one knob on every leaf

The framework knobs (SKILL-BAR.md:332), read for each of Sable's set pieces:

| Knob | Cable Run | Ball Lightning | Outpost |
| --- | --- | --- | --- |
| `ult_encore` (true) | the exit becomes a second 2-beat leg to an enemy within 30 m of B, landing at half damage, then the exit | a second bounce: a 2-beat hop to an enemy within 30 m, a crater at half damage | the first slingshot off the outpost within 4 s becomes a 2-beat leg to an enemy within 30 m |
| `ult_beats` (+2) | +2 stakes | +2 rain strikes | +2 stakes, so up to 2 more sentries |
| `ult_radius` (+2 m) | landing ring +2 m | crater +2 m and apex ring +2 m | plant discharge +2 m |
| `ult_volley` (+1) | each stake arcs to 4 | rain strikes and the apex reach 1 more target | 4 stakes fire on each sentry beat |

| Index | Node (kept) | Kit op today (`trees/sable.gd`) | Added knob |
| --- | --- | --- | --- |
| 14 | `s_anchor_storm` | `anchor_pulse` 1.5 (`:42-43`) | `"ult_volley": 1` |
| 15 | `s_winch_ram` | `winch_punch` 1.5 (`:44-45`) | `"ult_encore": true` |
| 16 | `s_crater` | swap smash `crater_slam` (`:46-47`) | `"ult_radius": 2.0` |
| 17 | `s_bounce_battery` | proc `enemy_rebounded` grant_special (`:48-49`) | `"ult_beats": 2` |
| 18 | `s_chain_reaction` | `discharge_chain` (`:50-51`) | `"ult_volley": 1` |
| 19 | `s_twin_discharge` | `special_echo` 0.5 (`:52-53`) | `"ult_encore": true` |
| 20 | `s_octave_kick` | `vault_gain` 2.0, `vault_tags` (`:54-55`) | `"ult_encore": true` |
| 21 | `s_pole_vault` | `vault_enemies` (`:56-57`) | `"ult_radius": 2.0` |
| 22 | `s_storm_caster` | arc caster chain +2, range +4 (`:58-59`) | `"ult_volley": 1` |
| 23 | `s_air_turret` | `air_turret` (`:60-61`) | `"ult_beats": 2` |
| 24 | `s_auto_gauge` | `mounted_autogauge` (`:62-63`) | `"ult_beats": 2` |
| 25 | `s_turret_fan` | turret count +2 (`:64-66`) | `"ult_volley": 1` |
| 26 | `s_pylon_relay` | `winch_bank` 2.0 (`:67-68`) | `"ult_encore": true` |
| 27 | `s_sentry_post` | `sentry` 4.0 (`:69-70`) | `"ult_beats": 2` |
| 28 | `s_fortress` | `mount_pulse` 2.0 (`:71-72`) | `"ult_radius": 2.0` |
| 29 | `s_breach_plate` | `plant_repel` 2.0 (`:73-74`) | `"ult_encore": true` |

Every depth-4 pair carries two different knobs. Counts: encore 5, volley 4, beats 4, radius 3.

Two rows as they will read in `src/core/trees/sable.gd`, using only the existing ops (`upgrade_tree.gd:21-28`, `:46`):

```gdscript
{"id": "s_hook_charge", "name": "Hook Charge", "effect": "Hooking a wall sets off a discharge", "key": "movement",
	"icon": "ab_sable_move", "tags": ["burst"], "proc": [{"on": "grapple_fired", "do": "discharge", "scale": 0.25, "gap": 1.0}],
	"swap": {"ultimate": "ball_lightning"}},
{"id": "s_anchor_storm", "name": "Anchor Storm", "effect": "Hooked anchors discharge every second and half", "key": "movement",
	"icon": "ab_sable_move", "tags": ["burst", "sustain"], "knob": {"anchor_pulse": 1.5, "ult_volley": 1}},
```

## 4. Three worlds

What the kit adds through the depth cap, and how each world's ground asks for it. Stage facts are PARK.md's starting picks (PARK.md:372-379).

| | World 1, Spillway Works | World 2, the Dig | World 3, the Highdraft |
| --- | --- | --- | --- |
| Depth open | 1 and 2 | 3 | 4 |
| Kit | arc caster, discharge, Bank Shot, boost, arc slam, Cable Run; depth 1 Cannonball or Beachhead, depth 2 Coil Hook, Face Runner (world-one table), Arc Nest or Bulwark (`trees/sable.gd:9-22`, `:82-85`) | the set piece becomes Ball Lightning or Outpost | one set-piece knob: encore, beats, radius or volley |
| What she learns | the slingshot grammar at three distances: vault the canyon walls at contact, mount on faces, Bank Shot off the 120 m dam face and the flume trestles at rope range | the pick is terrain: the open pit (900 m across, 150 m deep) has the sky Ball Lightning needs; the sinkhole stage is at least 40% roofed, where an arc lands early on the ceiling and Outpost's line path to the roof works | stakes as a bridge: a Cable Run over a gap between buttes leaves a row of hook points in the air; encore chains spire to spire |
| Ground that asks for it | dam faces, canyon slot walls, the plunge pool bowl, penstocks as grind lines | benches as terraces, adits, lava tubes, the headframe | buttes 120 to 220 m, a net deck at 60 m, cables across gaps, hoodoo anchor fields, spires |
| Warden | the reactor on the dam face: ride the 3 s water sheet up, Bank Shot off a hardpoint into the core | the swarm remnant on the headframe hoist (exposed at the top 4 s of a 12 s cycle): a line path to the cage when it tops out; Outpost stakes round the headframe for the finisher | the Mind's hand moving between three perches every 8 s: Bank Shot off its hardpoint while it drags the ball |
| Pressure the kit answers | packs in washes and culverts | the anti-spam answers enter (deflector, counter-ram, plan "Calls"). Bank Shot changes the approach angle, so she can come at a deflector's dish from the side (inference: the dish faces one way, `src/combat/codex_entries.gd:50-55`) | line cutters at cable anchors cut lines; stakes are her spare anchors |

## 5. The mecha

**Body direction (A2-CRITIC, 2026-10-10).** Andrew rejected the open-cage boards that evening. ROSTER-LOOK §0, the Hoberman mecha, is the live body (`ROSTER-LOOK.md:3`, `:11-15`), and this section is written to it. Sable's parts map onto §0.1 like this. The coil mast rides a gap bracket at 11 o'clock (rest pose: the upper hub). The winch spool and spool hatch ride a gap bracket at 3 o'clock (rest pose: the side hub). The wrench rack sits on the pod's seat back. Her twin arc emitter rides the weapon ring (§0.2). ROSTER-LOOK §0.2 lists one coil mast and no crown; the stakes ride inside the spool hatch. The silhouette rule below is restated in PILOTS.md, and that table is canonical. The clock positions this section cites for the other five come from PILOTS.md section 1.

The shared mecha is ROSTER-LOOK §0.1. The Hoberman lattice on Core tumbles with the roll and carries the Hub and Gap empties that take modules and panels. The level WeaponRing under Pod yaws to the aim. The cockpit Pod hangs upright in a two-axis gimbal and holds the seat, the twin yokes, a lever bank beside the right yoke, the copper lap bar and two pedals (§0.7). The pilot sits in view through the open gaps. Sable's row is ROSTER-LOOK §0.2. This section says how her machinery reads her kit.

| Part | Where | Reads | Motion and light |
| --- | --- | --- | --- |
| Coil mast | a gap bracket at 11 o'clock from behind (rest pose: the upper hub at 11), standing 0.20 m past the lattice | the discharge (slot 2) | Copper winding with a bare-metal core. Five winding bands light mint one at a time as the gauge fills, the same count as the rings and the notes (2.2). The tip is the only `class_accent` surface and breathes at 1 Hz when the meter is full. |
| Winch spool | a gap bracket at 3 o'clock (rest pose: the side hub at 3), a 0.12 m bulge | the harpoon and Bank Shot | Spins out as the line pays out and in as Ctrl hauls. The ratchet pawl (`tools/blender/world_one/shell_sable.py:87`) clacks when Bank Shot locks the line. The cable leaves at `RopeExit` (`shell_sable.py:179`). |
| Wrench rack | on the seat back, the rear tell | the ultimate meter | Four wrenches on one mesh and one node. One lights per 25 meter points through a `lit_count` shader parameter on its single `class_accent` surface, so the rack is the meter in the world, read from the same `abilities.meter` as the HUD arc (SKILL-BAR.md:215), at one draw. At wind-up the whole rack turns a quarter turn, the engineer tightening up before the run. |
| Spool hatch | under the spool | the stakes | One stake drops from it per beat of a Cable Run, with a puff and a clink. |
| Cockpit controls | on the pod, in the §0.7 layout | the bar | A yoke trigger squeezes on each shot of "1: Arc caster" (`Control.Trigger`, PILOT-CLIPS.md section 5). The lever bank beside the right yoke holds the gauge lever, "2: Arc discharge" (`GaugeLever`), and the spool brake, "3: Bank Shot" (`SpoolBrake`). The copper lap bar is "Q: Cable Run". The two pedals carry "Shift: Boost". Each control throws when its skill fires, read from the same event as the clip (§0.4). |

**Gap panels by heft class** (stages from ROSTER-LOOK §0.3). Her gap panels are small, rounded, felt-lined and rubber-bushed (§0.2), the shell that "rattles least" (`VISUAL-LANGUAGE.md:307`).

| Class | Sable's mecha |
| --- | --- |
| I | the bare lattice with every gap open, plus the weapon ring and twin arc emitter, the gimballed pod, the coil mast, the spool and the rack |
| II | six small felt-backed panels in the lower gaps below the pod, under Z -0.35 |
| III | panels in the side gaps, and thicker tread caps on the hubs |
| IV | panels in most gaps. Only the sight gaps to the pilot stay open (ROSTER-LOOK §3 rule 1). The panels round the spool's hub at 3 o'clock are cut in a horseshoe, so the spool face and `RopeExit` stay clear: "Sable needs a readable cable exit" (`BIBLE.md:416`) |
| V | every gap paneled except the sight gaps, and the coil mast's heavy form, the doubled coil: a second winding layer on the same mast, which rises to 0.25 m. **Call:** one thicker mast, not a second one, so the silhouette rule below survives class V |

Losing a class (`heft_class_dropped`, `src/core/game_events.gd:37`) flings that class's gap panels out of their gaps as scrap (§0.3). The coil, spool and rack never shed.

**Silhouette rule at chase distance: one spike, off-centre.** Sable is the only pilot with a single tall break at 11 o'clock, mint at its tip, and a round bump at 3 o'clock. Nothing breaks the outline at 1 o'clock. Rivet's twin stacks stand at 11:30 and 12:30, Kest's vents make a V at 2 and 10, Tarn's claw arms sit at 4 and 8, Tally's drums at 3 and 9, and the Cannon's ports at 5 and 7 (PILOTS.md section 1). At the fast camera the 0.20 m break is about 15 px (ROSTER-LOOK §1). Check: the greyscale 96 px blind-thumbnail test (ROSTER-LOOK §3 rule 10). The mast and spool ride gap brackets, level carriers, so 11 and 3 o'clock hold in a roll (ROSTER-LOOK §2, §4).

## 6. Clips

All clips run on the shared 25-bone `pilot-v1` rig at 30 fps, through the `anim_pilot_reactions.py` route (`tools/blender/anim_pilot_reactions.py:22-29`, `:303`). Clip names follow PILOT-CLIPS.md section 2, and each cast reaches the cockpit control named in its pose story (section 5 above, PILOT-CLIPS.md section 5). Priorities and cooldowns for the framework triggers are SKILL-BAR.md:472-480.

| Clip | Length | Trigger | Pose story |
| --- | --- | --- | --- |
| `idle_loop` | 4.2 s loop (127 frames, 12 beats, PILOT-CLIPS.md:118-122) | none; the default | She leans toward her chosen exit while her eyes track the nearest enemy (`BIBLE.md:283`). Ears flick at 1.3 s and 3.1 s; one paw taps the spool brake lever in the bank beside the right yoke. |
| `class_up` | 1.0 s | `heft_class_changed` | She reaches back to the rack and gives one wrench a quarter turn, then a short nod. |
| `cast_special` | 0.6 s | `slot_cast` with slot `special` | She slaps the gauge lever (`GaugeLever`, "2: Arc discharge") in the bank beside the right yoke, ears pinned back. |
| `cast_line` | 0.5 s | `line_skill_fired` | Both paws haul the spool brake (`SpoolBrake`, "3: Bank Shot") in the bank beside the right yoke, the body leaning into the whip. |
| `ult_ready` | 0.8 s | `ultimate_ready` | A sidelong grin, one ear up, a tap on the full wrench rack. |
| `ult_windup` | 0.35 s | `ultimate_started` | One paw grips the copper lap bar ("Q: Cable Run"), the other points down the drawn line at B, then joins it on the bar for the ride. |
| `ult_strike` | 0.7 s | `ultimate_peak` | Spine stretched tall in the seat, one arm thrown up, ears forward, as the relay closes. (The rig has no leg bones, `tools/blender/PILOT-RIG.md:23-39`, so she cannot stand.) |
| `ult_recover` | 0.6 s | `ultimate_landed` | She drops into the seat and leans the way the exit throws her. |
| `smash` | 0.6 s | `slammed` (`game_events.gd:50`), the shared roster row (PILOT-CLIPS.md section 1.1); priority 36, cooldown 1.0 s | A paw slams the seat rail, then her head snaps to the brightest tagged face. |
| `unlock` | 2.4 s | Sable starts unlocked (`class_def.gd:92`), so this plays in the title's class preview the first time her card is focused on a profile, and on every focus under `--profile=sitting` | She drops into the seat from above (the `root` bone keyed; the seated legs stay fixed), pulls her cap down, cinches the strap and checks the rack. |

The seven reactions stay as built (`src/presentation/pilot_reactions.gd:5-18`): `big_cheer` 2.8 s, `wince` 0.5 s, `slump` 1.5 s, `phew` 0.8 s, `brace` 0.6 s, `heave` 0.8 s (frame keys at `anim_pilot_reactions.py:22-29`), and `drop_land`.

## 7. Earned cosmetics

Nothing is bought. Two rows already exist: Lagoon (starter) and Violet Static (granted by 1000 kills on any pilot) (`src/core/cosmetics.gd:26-27`, `src/core/achievements.gd:48-49`). Three new rows, each earned by playing Sable's kit well:

| Item | Slot | Look | Granted by | How the grant reads in today's evaluator |
| --- | --- | --- | --- | --- |
| `trail_sable_cable` "Cable Stitch" | trail | a dashed mint-and-copper cable that pays out behind the ball | "Cable Runner": land three Cable Runs in one run | discovery `sable_cable_runs` |
| `decal_sable_spool` "Spool and Wrench" | decal, new atlas tile 8 | a spool crossed with a wrench on the seat-back DecalPlate (ROSTER-LOOK section 7) | discovery `parting_shot`: a kill within 1 s of a slingshot (`codex_entries.gd:37-42`, `combat.gd:90`) | `"on": "synergy_discovered", "where": {"synergy_id": "parting_shot", "first_time": true}` (emitted at `src/core/codex.gd:157`) |
| `shell_sable_felt` "Felt Rig" | shell variant (A4 and B5 add the slot) | lattice struts wrapped in grey felt bands, with rubber bushings showing at the pivot pins: the Switchback Enclaves' noise control (`BIBLE.md:285`). The roll's rattle layer becomes a muffled thump; volumes do not change, so no audio information is lost | hidden discovery `switchback`: Bank Shot off one of your own stakes | `"on": "synergy_discovered", "where": {"synergy_id": "switchback", "first_time": true}` |

The trail draws along the set piece's path through the trail slot (SKILL-BAR.md:608). The shell variant and the heft gap panels share one loader path (plan, creative-charge list).

## 8. Discovery and codex rows

Rows for `src/combat/codex_entries.gd` (`ENTRIES` at `:12`), in the existing shape (`id`, `name`, `hint`, `clue`, `text`). A discovery shows its first-time card once, with the name and one line (`tests/discovery_cards_test.gd` header).

| id | Name | Hint | Clue | Text | Detected when |
| --- | --- | --- | --- | --- | --- |
| `bank_shot` | Bank Shot | The line can turn you as well as pull you. | a standing line + slot 3 | Pick 3 and click while a line stands: you whip round the anchor and leave toward your aim, faster than you came. | the first `line_skill_fired` with `bank_shot`, once `loaded_line` is already seen |
| `cable_run` | Cable Run | Everything she drives into the air is somewhere to hook. | a full ring + Q | Q rides a cable to where you aim and drives a stake on every beat. The stakes hold a line for six seconds. | the first `ultimate_landed` with `cable_run`, once `set_piece` is already seen |
| `switchback` (hidden) | Switchback | Your own stakes hold a line as well as any wall. | a standing stake + Bank Shot | Bank Shot off a stake your Cable Run left behind. | `line_skill_fired` with `on: "world"` and the anchor in the stake group |

**Order with the framework cards.** `loaded_line` and `set_piece` (SKILL-BAR.md:456-464) teach the system and come first. Sable's cards teach her flavour and wait for the next qualifying event, so two cards never fire on one tick. Without that rule, the first Cable Run would open both `set_piece` and `cable_run` together.

`switchback` names the Switchback Enclaves, her culture (`BIBLE.md:285`), and grants the Felt Rig.

## 9. Tests and bot checks

Headless proofs, in the style of `tests/char_combat_test.gd` (the real game, calm, stage 1, the class swapped in place). Each case fails loud.

**New `tests/sable_kit_test.gd`** (slots, line skill, tree):

1. Bank Shot on a world line: entry 20 m/s gives an exit of 29.0 m/s plus or minus 0.5, within 5 degrees of `eject_direction(anchor to ball, aim)`; the line releases; no `broke` line event is published; the chain count is unchanged.
2. Bank Shot cap and floor: entry 40 gives 45; entry 2 gives 20.25.
3. Bank Shot on a body: the pivot takes 10 x chain multiplier damage and a knock opposite the exit; the ball's exit matches case 1.
4. Load: a cast with no line emits `line_skill_loaded`; a bite at 3.99 s fires `line_skill_fired`; at 4.01 s `line_skill_expired` fires instead.
5. During `LINE_SMASH`: the pivot arc fires at once and the redirect fires on `harpoon_smashed`.
6. Geometry: the drawn exit cone's direction equals the cast's exit direction to 1 degree.
7. Coil Hook does not stack: with `grapple_fling` 10.0, a Bank Shot exit is unchanged.
8. Slot 2 through the bar: pick 2, hold left click 1.0 s, release: 8 targets, 30 m, 70 damage. Live discharge: a tap at 30 m/s fires at 22.5 m/s.
9. The plant discharge stays free: a mount emits `special_used` with `detonation_gauge` and spends no charge.
10. Tree: every depth-3 node carries `swap.ultimate`; every offered depth-3 pair holds one `ball_lightning` and one `outpost`, including the retained Face Runner pair (8 with 6); every depth-4 node carries exactly one `ult_*` knob and siblings differ; world-one picks S1 to S6 are unchanged.

**New `tests/sable_set_piece_test.gd`** (split out to stay under the 360 s runner cap):

1. Cable Run drops one stake per flight beat (5 to 9 at 172 BPM); each stake is hookable at 5.9 s after the landing and gone at 6.1 s; a stake does not collide with the ball.
2. The exit is at least the blazing tier plus 0.5 m/s and at most 45 m/s; on flat ground it is within 2 degrees of 12 degrees up.
3. The landing deals 60 x heft multiplier x chain multiplier within the class radius.
4. Ball Lightning: the path is arc only; the apex discharge fires exactly once; the landing tags at least one face in a walled fixture and restores the air jump.
5. Outpost: at recovery end `kit.mounted` is true and `mount_banked` is within 1 m/s of the flight speed; in the next 4.0 s no more than 3 stakes fire per beat.
6. Wardens: a landing on an open core shatters one chunk; on a closed guard it adds at most 45 posture once.
7. Stakes fold on `stage_entered`, a death and a retry.

**Re-pins with dated headers.** `tree_data_test` (still 30 nodes and 4 keys), `tree_safe_picks_test` (`UNSAFE` for Sable is `["s_face_runner", "s_crater"]` today at `tests/tree_safe_picks_test.gd:18-19`; it grows by the eight depth-3 nodes unless the variant rule in open question 1 lands), `relics_data_test` and `relics_per_world_test` (the relic re-cut, section 10), `char_kits_test` (five slots). Must pass unchanged: `world_one_stree_test`, `tree_depth_cap_test`, `char_movement_test`, `world_one_mass_s_test`, `hook_chain_test`.

**Bot checks.**

- `tests/bot_six_pilots_test.gd`, which plays Sable and is the template for the other five (`:2-3`): at least 3 wins in seeds 1 to 4 (`:12-13`). Added assertion from each winning run's log: `slot_casts.line` at least 1, `ultimates` at least 1, and `stakes_hooked` reported.
- `tests/char_bot_sable_test.gd` (the world-one skipper run as Sable: breaks stage 1's Warden and launches into stage 2): passes unchanged.
- B4's `bot_skill_bar_test` covers the meter bands for all six; Sable's chainer median fill must sit in the 45 to 60 s band (SKILL-BAR.md:210).
- The park traversal line for `sable` on every stage (PARK.md:450-468) is wave K-D's job; this kit must not drop her below the flow-share band.

## 10. Implementation map: wave P-C, unit PC-SABLE

**SCOPE** (writes only these):

- `src/core/ability_state.gd`: rows `bank_shot` `{"icon": "ab_sable_line", "cooldown": 8.0, "line": true, "load_seconds": 4.0}`, `cable_run` `{"icon": "ab_sable_ult", "cooldown": 0.0, "paths": ["line", "rail", "arc"]}`, `ball_lightning` (`"paths": ["arc"]`, `"variant_of": "cable_run"`), `outpost` (`"paths": ["line", "rail", "arc"]`, `"variant_of": "cable_run"`).
- `src/core/class_def.gd`: the Sable row gains `"line_id": "bank_shot", "ultimate_id": "cable_run"` (`:87-93`).
- `src/combat/combat.gd`: the `_line_skills["bank_shot"]` row (`on_body`, `on_world`, `geometry`); the live-discharge change in `_discharge_speed` (`:1379-1383`); the `_since_slingshot` reset on a Bank Shot exit; the `bank_shot` and `switchback` detection points.
- `src/combat/ultimate.gd`: `_ult_rows` for `cable_run`, `ball_lightning` and `outpost`; the `cable_run` detection point.
- `src/combat/stakes.gd` (new): the stake set: positions, 6 s life, the 11 cap, the anchor layer, arcs on planting, the peak relay, Outpost's sentry beats, fold on reset.
- `src/movement/augments.gd`: a pure `bank_exit(v_in, anchor_to_ball, aim, kit)` beside `_slingshot` (`:610-613`); Outpost's flat-ground mount entry.
- `src/movement/harpoon.gd`: the anchor layer in the target mask (`:28-29`).
- `src/movement/player_ball.gd`: Bank Shot's velocity hand-off with cut cause `bank`; the exit cone in `_update_aim_cones` (`:986-1001`) while slot 3 is selected and a line stands.
- `src/core/trees/sable.gd`: the 8 swaps and 16 knobs of sections 3.6 and 3.7.
- `src/core/trees/world_one_cards.gd`: `SET_PIECE_LINES` rows for `ball_lightning`, `outpost` and the four knobs (the reader is B6's).
- `src/combat/codex_entries.gd`: the three rows of section 8.
- `src/core/cosmetics.gd` and `src/core/achievements.gd`: the three items and three grants of section 7.
- `src/build/relics.gd` (**Call**): Pit Coil (`:68-70`, world 2) becomes "Bank Shot recharges 30% faster" on slot `line`, `cooldown` 0.7; Storm Crater (`:105-107`, world 3) becomes "Stock a second Bank Shot", `charges` 1. Crater Heart (`:28-30`) stays the one crater relic. `SUFFIX` (`:24-25`) gains `line: "_line"`.
- `src/ui/class_kit.gd`: `WORDS` rows `bank_shot: "bank shot"`, `cable_run: "cable run"`, `ball_lightning: "ball lightning"`, `outpost: "outpost"` (`:15-46`).
- `src/presentation/audio.gd`: the `sable_bank` row, the per-stake motif notes, the peak stinger and the Outpost sentry ticks.
- `src/core/run_log.gd`: `stakes` and `stakes_hooked` inside each `ultimates` row; `bank_gain_mps` (median exit minus entry) under `line_skill`.
- `assets/icons/ab_sable_line.svg` and `ab_sable_ult.svg` (`tree_data_test` requires the SVGs, `tests/tree_data_test.gd:47-48`).
- Tests: the two new files in section 9 and the listed re-pins.

**ACCEPTANCE:**

- Every case in section 9's two new files passes, red first.
- Bank Shot never lowers the ball's speed: exit at least entry, on every tick of the fixture sweep from 0 to 45 m/s.
- A Cable Run lands its beats on the music beat: each stake's note falls within one 16th of its beat.
- Every depth-3 offer pair is one Ball Lightning and one Outpost; every depth-4 pair carries two different knobs.
- Sable wins at least 3 of 4 seeds in `bot_six_pilots_test`, with at least one Bank Shot and one ultimate in each win.
- The world-one tree and its cards are byte-identical (`world_one_stree_test` unchanged).
- No relic or tree node for Sable duplicates another's mechanic: one crater relic, two Bank Shot relics.
- `tools/coordinator/compile_check.sh`, `node scripts/sketch-lint.mjs --sketch core-loop` and the related smoke pass; `git diff --name-status` shows only SCOPE files.

**Depends on wave P-B:**

| P-B unit | What PC-SABLE needs from it |
| --- | --- |
| B1 slot model | the `line` slot, `_line_skills`, `_step_line`, `line_load()`, the routed intents, `ClassDef.line_id` and `ultimate_id`, `SWAPPABLE`, the signals |
| B3 ultimate | `ultimate.gd` and `_ult_rows`, the meter, the RideRail carrier, beat rounding, `set_ultimate_lift`, the `ult_default` placeholder this replaces; the four `ult_*` knob readers |
| B2 HUD and card | slot 3 and the meter arc drawn; the tree card's second line |
| B4 bot adapter | casting through `slot_pick`, `_line_hands()` and `_ultimate_hands()` |
| B5 customization | the shell-variant slot for Felt Rig; the trail cosmetic drawn along the set piece |
| B6 discovery | `loaded_line` and `set_piece` registered; the `SET_PIECE_LINES` reader |

PC-SABLE can start once B1 and B3 have merged. Felt Rig waits for B5; the card lines wait for B2 and B6. It edits `combat.gd`, `player_ball.gd` and `ultimate.gd` after B1, B3 and B6, never beside them, and it is one of six P-C units that touch `combat.gd` and `ultimate.gd`, so the coordinator serializes their merges.

## 11. Open questions and veto list

### Open questions for Andrew (one line each)

1. Resolved by A2-CRITIC: B3 adds the four `ult_*` knobs; B1 teaches `safe_pick_problems` that a swap to a `variant_of` row is growth (SKILL-BAR section 12, items 3 and 4).
2. Resolved by A2-CRITIC: Tally's sheet changes. Her surge becomes a kick-start that pays pressure (`pilots/tally.md` section 2); Sable keeps the plain boost.
3. Resolved by A2-CRITIC: her meter fill draws in sand-light `bare_metal`, so mint keeps one meaning (SKILL-BAR section 12, item 8). Coil copper was rejected because copper is Rivet's class colour (`class_def.gd:14`).
4. Stakes held in the air where the ball passed, or planted on the ground below the path (fewer air anchors)?
5. Sable is the starter and already difficulty 3 of 3 (`src/ui/class_kit.gd:71-72`): does the bar make her too heavy for a first run? Your sitting decides.
6. A starter has no unlock: play her ceremony in the title preview, or skip it for Sable?

### Veto list (Calls under the creative charge; say "veto" on any line)

1. Slot 3 is Bank Shot: a tap that whips the ball round the anchor and out along the aim at entry x 1.25 + 4 m/s, capped at 45.
2. On a body, the enemy is only the pivot (10 x chain damage, knock 12); the speed goes to Sable.
3. During a committed smash, Bank Shot's redirect waits for the smash landing.
4. The ultimate is Cable Run: a stake per beat, a beachhead at B, a slingshot exit always at blazing speed.
5. Stakes are harpoon anchors for 6 s and never collide with the ball.
6. Depth 3 adds a set-piece swap to every existing depth-3 node instead of replacing nodes.
7. Every depth-3 pair offers one Ball Lightning and one Outpost.
8. Depth 4 adds one set-piece knob to every existing depth-4 node.
9. Outpost is the only set piece that ends mounted, and it may plant on flat ground.
10. The discharge reads 75% of current speed when that beats the gauge.
11. The gauge draws five rings to match the five motif notes.
12. Shift stays the plain boost.
13. Pit Coil and Storm Crater stop being crater relics and become Bank Shot relics.
14. Earned items: Cable Stitch for three Cable Runs in one run, Spool and Wrench for Parting Shot, Felt Rig for the hidden Switchback.
15. Class V thickens the one coil mast instead of adding a second spike.
16. The wrench rack lights one wrench per 25 meter points, the meter in the world.

### Separable extra, not in the build

- **Stake on Shift hold.** Tap Shift boosts as today; holding it 0.3 s also drops one stake where you pressed. That gives her a portable anchor on open ground, the Bible's "folding winch anchor plants a small stable foot" (`BIBLE.md:410`). Cost: two verbs on one key. Try it only if the sitting shows she runs out of anchors in the 1.6 km parks.

### How each part shows it is working

| Part | Measure | Healthy (start) | Source |
| --- | --- | --- | --- |
| Bank Shot | median exit minus entry; share of casts that start as a load | gain at least 5 m/s; loads at most 60% | run log `line_skill`, `bank_gain_mps` |
| Stakes | stakes hooked per Cable Run | at least 1 in the sitting; near 0 means stakes are clutter | run log `stakes_hooked` |
| Cable Run | meter fill seconds for a chaining player | 45 to 60 s | run log `ultimates.fill_seconds` |
| Live discharge | discharges fired above the gauge's speed | 20 to 50% of casts | run log, `gauge_released` fraction against the speed used |
| Depth 3 | which variant players take, per Dig stage | neither above 80% | run log tree picks |

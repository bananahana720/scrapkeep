# Kest: pilot sheet

Status: design spec for wave P-C, unit A2-kest of wave 13. Written 2026-10-10 on `cand/alpha-w13` at `38ceda3`. Nothing here is built or played. Every `file:line` cites that commit. Paths without a prefix are under `sketches/core-loop/`; `docs/`, `adr/` and `BIBLE.md` are under the repo root. A number marked (start) is a starting value to tune in play. A line marked **Call** is a decision made under the creative charge; section 11 collects them as the veto list.

**Weapon fire (ruling ek, 22 Nov 2026):** how this pilot's weapon fires, with its timers, damage and first tree pick, is now [PILOT-CADENCE.md](../PILOT-CADENCE.md) section 3.3. Where this sheet's weapon text differs, that page wins.

Reads with: [SKILL-BAR.md](../SKILL-BAR.md) (the framework; every slot, signal, field and knob name here is its name), [ROSTER-LOOK.md](../ROSTER-LOOK.md) (the Hoberman mecha, section 0), and the A5 animation spec, [PILOT-CLIPS.md](../PILOT-CLIPS.md) (clip ids).

**Name.** The display name is Kest (`src/core/class_def.gd:101`). The class id stays `demolitions_caster`. Older docs, and the row's `bible_home` (`class_def.gd:105`), call this pilot "Fuse"; this sheet says Kest.

Terms, defined once. SKILL-BAR's terms (slot, cast, snap-back, line skill, load, meter, set piece, heft class) keep their meaning there.

- **The line**: the harpoon line, as SKILL-BAR uses it. Kest's slot 2 is always called "the detonation line" in full.
- **Charge**: one sticky charge (`src/combat/sticky.gd:6-10`). It goes off on its fuse, on an enemy's touch once armed, or when something sets it off.
- **Mini charge**: a smaller charge dropped in place (`sticky.drop`, `sticky.gd:62-65`), as the demo slam lays today.
- **Live**: a charge in the world that has not gone off yet.
- **Cloak**: Kest's dust cloak. For 1.5 s enemies see her at 0.6 of their range, and her first shot out of it deals double and ends it (`src/combat/weapons.gd:210-212`, `src/combat/combat.gd:2161-2213`).
- **Rocket jump**: Space held within 4.5 m of her own blast throws her away from it at 22 to 30 m/s (`weapons.gd:203-206`, `combat.gd:2107-2124`).
- **Blast vault**: a rocket jump off her own Cable Charge on a wall. It is also a codex card name (section 8).

## 1. Fantasy, and what only Kest does

**One line.** Kest, a kestrel from the Highdraft Roosts, watches the fight, sets charges where it will be, then commits: she lets go of the line, the charge blows, and she rides the blast out.

Sources: the pitch "Vanish in your own smoke, then drop a line of fire where they least expect it" (`class_def.gd:102`); "a hovering mortar" (`DESIGN-V2.md:234`); "Kest drops and lands" (`SOUND-STORY.md:35`); the Bible's Kest "watches how loads move before touching the controls", whose arc is learning "to commit" (`BIBLE.md:304`, `:308`).

**What only Kest does: her damage is placed first and paid later, and her own blasts move her.**

| Pilot | When the damage lands | What moves the ball | Who picks the payoff moment |
| --- | --- | --- | --- |
| Sable | now: arc bolts, a discharge from banked speed (`class_def.gd:89`) | grapple, vault, pylon launch | the hit |
| Rivet | now: a laser stream (`class_def.gd:96`) | the sprint | the hit |
| Tarn | now: claw sweeps at 5 m (`class_def.gd:110`, `weapons.gd:44-45`) | the claw pull | the hit |
| Tally | later, on enemies: cards gather and link a pack, balance due pays (`class_def.gd:117`) | the flywheel surge | a card press |
| Cannon | committed lanes (`class_def.gd:124`) | the recoil | the lane |
| **Kest** | **later, in places: charges wait on the ground, a wall or a body** (`class_def.gd:103`) | **blink, glide and her own blasts** | **a fuse, a touch, or her trigger** |

Tally is the nearest: both set up and then cash in. The split is the target. Tally marks enemies and pays per enemy. Kest marks places and pays per blast radius, and the blast carries her.

**One material, five deliveries.** Andrew's rule is no two things doing the same mechanic. Every Kest verb uses charges, so each one must answer a different question:

| Delivery | Where the charge goes | What sets it off | The question it answers |
| --- | --- | --- | --- |
| Slot 1, sticky charge | where she aims, 10 to 30 m | its 1.2 s fuse or an enemy's touch | where? |
| Slot 2, detonation line | makes no charge | her release, along a 6 to 14 m lane | when, for what is already out |
| Slot 3, Cable Charge | down the line, onto what the hook bit | the line ending, or a long fuse | onto whom, and when she lets go |
| Ctrl, demo slam | a ring of three around her landing | a 1.0 s fuse or a touch | a reflex ring when she lands |
| Q, Windhover | round her landing point, thrown from a hang above it | a touch or a 0.6 s fuse, then her stoop | where she lands, and when she commits to the drop |

## 2. The kit

### Summary

| Place | Ability (`id`) | Fire shape | Core numbers | Today or new |
| --- | --- | --- | --- | --- |
| 1 | Sticky charge (`sticky_charge`) | gauge: hold to aim the lob, release to throw | 16 damage, 3.0 m blast, 10 to 30 m, 1.2 s fuse, 0.6 s a throw, 3 live | today, unchanged |
| 2 | Detonation line (`detonation_line`) | press 2, then gauge on left click | 6 to 14 m by 2.5 m, 20 to 30 damage, +25% per caught charge up to 3, 6.0 s | today; preview refined |
| 3 | Cable Charge (`cable_charge`) | press 3, then tap | 28 damage x chain, 4.0 m blast, goes off when the line ends, 8.0 s | new |
| Shift chip | Smoke blink (`smoke_blink`) | press | 8 m, leaves at 16 m/s or more, 4.0 s, starts the cloak | today, unchanged |
| Space | Glide and rocket jump (passives on `smoke_blink`) | hold | glide gravity share 0.30; rocket 22 to 30 m/s within 4.5 m, 1.0 s | today, unchanged |
| Ctrl chip | Demo slam (`demo_slam`) | on the slam's landing | slam knock 26; 3 mini charges, 5.3 damage, 1.5 m | today, unchanged |
| passive | Dust cloak | automatic | 1.5 s, sight 0.6, first shot x2 | today, unchanged |
| Q | Windhover (`windhover`) | press at a full meter | arc to a point 14 m over B, a 2-beat hang, a stoop; volleys 12 x heft at 3 targets round B; stoop 75 x heft x chain | new |

### Slot 1: sticky charge (today, unchanged)

- **Does.** Hold left click to draw a lobbed arc and its landing ring; release throws one charge to exactly that point. It sticks and goes off on its fuse or when an enemy touches it. Past 3 live, the oldest goes off (`combat.gd:2053-2056`).
- **Fire shape.** Gauge: 0.6 s to full; held full, it throws itself 0.5 s later and starts the next (`src/core/ability_state.gd:59`, `:86`; `combat.gd:1971-1999`).
- **Numbers.** 16 damage, 3.0 m blast (`weapons.gd:40`). Reach 10 m on a tap, 30 m at full (`weapons.gd:191`, `combat.gd:2010-2019`). Fuse 1.2 s (`weapons.gd:192`). Touch reach 0.6 m (`sticky.gd:13`). 0.6 s a throw, 1 charge (`ability_state.gd:59`). Out of the cloak a throw deals x2 (`combat.gd:2046-2047`). A throw over a void draws in bone with a cross and spends nothing (`combat.gd:2010-2019`).
- **Sees and hears.** An amber arc and ring while held (`combat.gd:2021-2031`); a stuck charge is a 0.4 m amber bead (`sticky.gd:142-149`); one soft tom thump per throw (`SOUND-STORY.md:45`).
- **New, from the framework only.** Slot 1 is home and never snaps. A charging throw is dropped when 2 or 3 is pressed (SKILL-BAR section 2). The release latch stops a click still held after a slot 3 tap from starting a throw (SKILL-BAR section 1).

### Slot 2: detonation line (today's F special, kept and refined)

- **Does.** Hold to draw a lane from the ground under the ball along the flat aim. Release sets off every live charge in the lane early, then hits everything in it, and starts the cloak (`combat.gd:1848-1878`).
- **Fire shape.** Press 2, then hold and release left click. Gauge 0.8 s, grace 0.5 s (`ability_state.gd:62`, `:86`). F is retired (SKILL-BAR section 6).
- **Numbers.** Lane 6 to 14 m long by the gauge, 2.5 m wide (`weapons.gd:182-184`). 20 to 30 damage by the gauge, +25% per caught charge up to 3, so x1.75 at most (`weapons.gd:185-188`, `combat.gd:1850-1855`). Cooldown 6.0 s, 1 charge (`ability_state.gd:62`).
- **Sees and hears.** The lane drawn while held (`combat.gd:1839-1843`) and an amber arc along it on release (`combat.gd:1876`). One tom thump per caught charge, down the line (`SOUND-STORY.md:44`).
- **Stays.** The mechanics, the name, the `_specials` row (`combat.gd:299`), Marked and Fuse Line (`kest.gd:34-35`, `:65-66`).
- **Refined (Call).** The held preview rings each live charge inside the lane with a 0.6 m amber tick, and the lane's fill steps up one notch per caught charge, so the x1.25 steps read before release. One query: the preview and the release both test `in_line` over `sticky.charges` (`combat.gd:1850-1852`), so the drawn catch is exactly the real catch (TADR-008, `adr/TADR-008-ability-contract.md:38`). No number changes.

### Slot 3: Cable Charge (new line skill, the payload flavour)

**Card line:** "Charge rides the line. Let go: boom." Icon `ab_kest_line`.

**Fire shape.** Tap. Press 3, click; it commits on the press (SKILL-BAR section 1).

**Numbers (all start).**

| Field | Value |
| --- | --- |
| travel along a standing line | 60 m/s, so 0.75 s at the 45 m rope range (`src/movement/tuning.gd:18`) |
| blast | 28 damage x `chain.multiplier()` read when the charge sets; 4.0 m radius; knock `IMPACT["sticky"]` |
| fuse on a body | 2.0 s |
| fuse on a wall or post | 6.0 s |
| load window | 4.0 s (SKILL-BAR default) |
| cooldown, charges | 8.0 s, 1 (SKILL-BAR default) |

**Rules.**

1. **Line on a body** (`on_body`). The charge runs down the line, sets on the enemy and rides it, through the rider path sticky charges already have (`sticky.gd:78-80`, `:88-90`). It goes off when the line ends for any reason (a let-go, a smash landing, a cut, a break) or when its 2.0 s fuse runs out, whichever comes first.
2. **Line on the world** (`on_world`). It sets on the anchor. It goes off when the line ends or its 6.0 s fuse runs out. It does not trigger on a touch: a touch mine is slot 1's job.
3. **No line.** The cast loads (SKILL-BAR section 3). The next bite carries the charge on the hook head, and it sets on arrival with no travel.
4. **One blast path.** It goes off through `_detonate` (`combat.gd:2073-2101`) with `_source: "line"` (the tag pattern at `combat.gd:2062`, `:1875`). The rocket jump, the cloak, Daisy Chain, Time Bomb, Demolition and Marked all read it with no new code path.
5. **Blast vault.** Latch a wall, cast, reel in, and let go within 4.5 m with Space held. The existing rocket jump throws Kest up and away at 22 to 30 m/s (`weapons.gd:203-206`). The let-go's own fling still applies (`src/movement/player_ball.gd:471-473`).
6. **Haul smash.** Ctrl hauls a body-latched ball into a smash. The landing ends the line, so the charge goes off in the smash's tick. With Space held, the rocket jump throws her clear.
7. **No reel burst (Call).** SKILL-BAR's default `on_world` is `reel_burst`. Kest skips it: the blast vault is her wall move, and a reel burst would make it Rivet's yank.

**Chain.** The blast multiplies by `chain.multiplier()` (`src/combat/chain.gd:49`) at the moment it sets: x1.0 at combo 1, x2.5 at the cap of 6 (`chain.gd:19-20`). It adds no link. It never grounds the ball. A blast vault lifts her, so the let-go's 0.8 s airtime grace (`chain.gd:22`) can still find the next bite.

**Committed geometry.** A 4.0 m amber ring at the anchor from the cast (or from the bite, for a load) until it goes off. The hit test forgives 18% past the ring, as every skill shot does (`ability_state.gd:31`). While it waits, a fuse spark crawls along the line toward the charge, so the line reads as the fuse.

**Wardens and bosses.** On a Warden the blast is a blast. It fills posture at the "other" base, 1.5 x the plating multiplier (`src/combat/boss_posture.gd:11`, `design-v3/LEGIBILITY.md:85`), and it never cracks or shatters the core (`LEGIBILITY.md:87`). At the 0.2 floor it shows slate sparks and the low clank (`LEGIBILITY.md:90`). Its Warden use is the exit: haul-smash an open core (the smash shatters by the normal rule) and the blast throws Kest clear. Bosses take it at full damage, so it needs no "nope" read.

**Sound.** Load: `line_load` (SKILL-BAR section 7). The run down the line: a fuse fizz that rises a semitone per chain link, as `chain_link` does (`design-v3/HOOK-CHAIN.md:27`). The set: the motif's first note, D4 (62), soft on the tom. The blast: the motif's last note, D3 (50), on the tom doubled by the 808 (`src/presentation/harmony.gd:134`, `src/presentation/synth.gd:632`).

### Shift: smoke blink (today, unchanged)

- 8 m along the aim, stopping short of the world (`src/movement/augments.gd:103`, `:253-277`). Leaves at the dash floor of 16 m/s or more (`tuning.gd:15`). Keeps a climb and catches a fall (`augments.gd:275-276`). Cooldown 4.0 s, 1 charge (`ability_state.gd:61`). Starts the cloak (`combat.gd:2150-2152`).
- Sees: an amber ring where she left (`combat.gd:2151`). Hears: one muffled thump (`SOUND-STORY.md:45`).
- New: drawn as a chip at 0.75 scale, never selectable (SKILL-BAR section 1).

### Space: glide and rocket jump (today, unchanged)

- Glide: hold Space while falling after the air jump (`augments.gd:429-440`); gravity share 0.30, lift 1.30 (`tuning.gd:16-17`). The vanes open while gliding (`src/presentation/hero_assets.gd:481-486`).
- Rocket jump: as defined above; 1.0 s cooldown (`weapons.gd:206`); Blast Jumper needs no Space (`src/core/trees/kest.gd:28-29`).

### Ctrl: demo slam (today, unchanged)

- The shared slam (knock 26, `augments.gd:68`), then 3 mini charges on a 3.5 m ring turned to the heading: 5.3 damage, 1.5 m radius, arming after 0.3 s, 1.0 s fuse (`weapons.gd:195-200`, `combat.gd:2129-2148`). Dispatched by flavour (`player_ball.gd:165`, `:913-914`).
- Hears: the womp, the falling triad on the tom, three mini thumps after the arm (`SOUND-STORY.md:105`).
- New: the `smash` clip (section 6).

### Passive: dust cloak (today, unchanged)

1.5 s after any own detonation, blink or detonation line; enemies see 0.6 of their range; the first shot out deals x2 and ends it (`weapons.gd:210-212`, `combat.gd:2161-2213`). Every Kest cue plays 6 dB quieter while cloaked (`SOUND-STORY.md:98`).

### Q: Windhover (new ultimate)

Section 3.

## 3. The ultimate: Windhover

**Card line:** "Hang over the fight, shell it, then stoop." Icon `ab_kest_ult`. Run-log id `windhover`.

**In one sentence:** Kest lobs herself to a point above where she will land, hangs there head-to-wind like a windhover (a hovering kestrel) while her mortar shells the landing zone on every beat, then stoops straight down onto it.

**Why Windhover is the base (A2-CRITIC, 2026-10-10).** The first draft made Air Raid the base: an arc that drops inert charges and pays them after the landing. The Cannon's Fire Mission is also an arc whose calls, made in flight, all pay at the landing (`pilots/cannon.md` section 3). Two arc set pieces with deferred payloads read as one path-and-payoff pair, so the weaker claim moved: the Cannon's is its whole mirror lore, Kest's is one of three good shapes. Windhover keeps Kest's grammar (watch, place, commit: `BIBLE.md:304`, `:308`), gives her the roster's only hang-and-stoop path, and is her species. Air Raid becomes a depth-3 variant, where its carpet rolling back along the route still differs from the Cannon's single landing beat.

### The contract (SKILL-BAR section 4's thirteen points)

| # | Field | Windhover |
| --- | --- | --- |
| 1 | id, name, icon | `windhover`, Windhover, `ab_kest_ult` |
| 2 | `paths` | `["arc", "line", "rail"]`, then the hop, with `hold_beats` 2 (SKILL-BAR section 12, item 1). B is a standing line's anchor if one stands, else the ground at the reticle within the class's arc reach (40 to 70 m), else a lock, a rail entry, then the hop. Legs: an `arc` to the hover point H, 14 m above B; a `hold` of 2 beats at H; a straight `line` stoop from H onto B in one beat (14 m in 0.35 s, 40 m/s at 172 BPM) |
| 3 | tech | every beat of the flight, arc and hold, the mortar throws one full sticky charge at each of up to 3 targets within 15 m of B, reticle first within 25 degrees: 12 damage x heft, 3.0 m blast, set off by a touch or a 0.6 s fuse. With no target, the throw lands on B. She shells the zone she is about to land in |
| 4 | peak | the first hold beat (SKILL-BAR section 12: with a hold, the peak is the first hold beat): she cloaks, the vents ring smoke, the stinger plays |
| 5 | landing | the stoop: 60 x heft x chain x 1.25 within the class landing radius + 1 m (7 to 11 m), knock 26, ends the chain. The cloak runs on 1.5 s. Exit: the banked speed handed back along the arc's flat heading (`src/world/ride_rail.gd:5-14`) |
| 6 | heft beyond the default | targets per volley: 3, 3, 3, 4, 4 at classes I to V |
| 7 | music | motif `kest` (`harmony.gd:134`); one tom tick per volley walking D4, A3, F3; the stinger is the falling triad; the stoop lands on the low root (below) |
| 8 | Mecha | vents and mortar by phase (section 5) |
| 9 | clips | `ult_ready` 0.8 s, `ult_windup` 0.35 s, `ult_strike` 0.5 s (the hang pose), `ult_recover` 0.6 s |
| 10 | depth 3 | Air Raid (an inert carpet that rolls back after the landing) and Minelayer (path `line`, lingering mines) |
| 11 | depth 4 | `ult_encore`, `ult_beats`, `ult_radius`, `ult_volley`, read per variant |
| 12 | Wardens, bosses | the defaults; the stoop on an open core shatters; with a line on a Warden at Q, B is the Warden and the stoop is the drop finisher |
| 13 | card, discovery, run log | above; codex row `kest_windhover` (section 8); run log `ultimates[].id = "windhover"`, volley hits count as `volley_hits` |

All numbers in this table are (start) except those SKILL-BAR already fixes. Budget: 3 targets x 12 = 36 a beat at class I, the framework's (SKILL-BAR.md:272).

### The path: up, hang, drop (Call)

The set piece default rides the line first (SKILL-BAR section 4). Kest reorders to arc first: a standing line still picks B, but she lobs to a point above it instead of riding the line straight. The arc and the stoop share the framework's clamped flight (1.6 to 3.2 s, rounded to beats); the 2 hold beats add to it (SKILL-BAR section 12, item 1), so Windhover runs 2.9 to 4.5 s from Q to the end of recovery at 172 BPM. Every leg, H as a hollow ring, the stoop line and the landing ring at B, draws at wind-up, so the hang is a chosen stop and never a surprise one (principle 1).

The arc is `RideRail.arc` (`src/world/ride_rail.gd:41-74`) ending at H, with `flight_planar` set to the flat distance over the arc's beat-rounded time (`ride_rail.gd:54-55`). At the ball's gravity of 26 m/s² (`tuning.gd:9`) a level arc peaks g x t² / 8 above its ends, so long throws rise past H before settling onto it. Over a gap, H may hang over nothing; the stoop still ends at B.

### Phase by phase (at 172 BPM, a 4-beat arc)

| Phase | Time | What happens | What you see | What you hear |
| --- | --- | --- | --- | --- |
| Wind-up | 0.35 s | the legs are planned and drawn | the arc, H, the stoop line and the landing ring at B in the live colour; the vents snap open, the mortar tubes on the weapon ring tilt up | `start_build` (`music_engine.gd:1021-1027`); a fuse fizz rises under it |
| Arc beats | 4 beats, 1.40 s | one volley a beat at up to 3 targets round B | each throw's landing ring shows for the beat before it lands, her slot 1 read (`combat.gd:2021-2031`) | one muffled tom tick per volley, walking the motif down: D4, A3, F3 (62, 57, 53) |
| Hold, beat 1 (peak) | 0.35 s | she hangs at H and cloaks; a volley | `ult_strike`: wings wide, head into the wind | the stinger: the falling triad 62, 57, 53 as three quick tom ticks |
| Hold, beat 2 | 0.35 s | a volley | the stoop line brightens | one tick |
| Stoop | 0.35 s | straight down onto B at 40 m/s | the vents fold back | the fizz climbs |
| Landing | on a beat | the stoop strike | the landing ring; smoke out of the vents | `drop_now(4, 0.85)` (`src/presentation/audio.gd:1625-1640`) and the boom: D3 (50) on the tom and the 808 |
| Recovery | 0.25 s | full control returns at its end | `ult_recover` | none |

"Tick, tick, tick, boom" (`SOUND-STORY.md:42`) is still the whole set piece: the volleys tick, the peak quotes the ticks, the stoop is the boom.

### How it is built from what exists

- **Volley charges** are ordinary sticky charges (`sticky.gd:6-10`) thrown from the mortar to points round B, armed for touch, on a 0.6 s fuse. Their damage is set at the throw: 12 x the heft multiplier, with no `_damage_mod` and no cloak crit. Source tag `ultimate`. They go off through `_detonate` (`combat.gd:2073-2101`), so Daisy Chain, Time Bomb, Demolition and Marked act on them.
- **Cloak (Call).** The cloak is held through the wind-up, the flight and the hold, as Nightfall holds it (`combat.gd:2189-2192`), and runs 1.5 s past the landing. Set-piece damage never calls `_cloak_shot()` (`combat.gd:2201-2209`), so it neither crits nor breaks the cloak. Her first throw after the landing does crit: the set piece ends in smoke.
- **The stoop as an exit.** Volley charges thrown on the last beats are still live round B when she lands. Holding Space after recovery ends, Kest rocket-jumps off the nearest (`combat.gd:2107-2124`). With Blast Jumper (`kest.gd:28-29`) it happens without Space.
- **Before B3 ships legs**, Windhover falls back to a high arc onto B with the volleys on its beats and no hang.

### Heft scaling

| Heft class | I | II | III | IV | V |
| --- | --- | --- | --- | --- | --- |
| damage multiplier (SKILL-BAR) | 1.00 | 1.15 | 1.30 | 1.45 | 1.60 |
| arc reach (SKILL-BAR) | 40 m | 47 m | 55 m | 62 m | 70 m |
| landing radius (SKILL-BAR), +1 m for the stoop | 7 m | 8 m | 9 m | 10 m | 11 m |
| targets per volley (start) | 3 | 3 | 3 | 4 | 4 |
| satchel bands on the weapon ring | 3 | 3 | 3 | 4 | 4 |

The last two rows are one fact. One function, `volley_targets(heft_class)`, feeds the set piece, Air Raid's charges per throw and the weapon ring's satchel bands.

### Wardens and bosses

| Target | Volley charges | Stoop strike | Read |
| --- | --- | --- | --- |
| Warden, guard closed | blasts: fill posture as gun bolts do at half damage (SKILL-BAR section 4); never crack | up to 45 posture for the whole set piece (SKILL-BAR section 12, item 7) | slate sparks and the low clank at the floor (`LEGIBILITY.md:90`) |
| Warden, core open | blasts fill posture only (`LEGIBILITY.md:87`) | counts as a harpoon smash on the core: shatters the chunk | the normal shatter |
| Warden as anchor (wave K-F) | as above | with a line standing on the Warden at Q, B is the anchor and the stoop is the drop finisher; the vertical drop reaches a Warden's back or a hand under a sky island | as above |
| Brindle, the Waking, the Mind | x0.5 | x0.5; phase windows untouched | brace pose and the "nope" glyph |

Demolition (`kest.gd:43-44`) raises the volley charges on plated enemies through `_detonate` (`combat.gd:2085-2086`). On a Warden that only raises posture gain. It still cannot crack or shatter.

### Depth 3: two variants

Every depth-3 node gains a `"swap": {"ultimate": ...}` op (SKILL-BAR section 4). The two variants each change the path type and the tech.

**Minelayer** (`minelayer`). Card line: "Ride the line. Leave a minefield."

| Field | Value (start) |
| --- | --- |
| `paths` | `["line", "rail", "arc"]`: rides a standing line, a lock, or a line fired at departure, low and straight |
| tech | one mini charge every half beat, dropped straight below (no aim: the line is the aim); 10 damage x heft, 2.5 m radius; at most 10 live, the oldest goes off past that |
| after the landing | the mini charges arm and stay as mines: an enemy within 2.0 m (Tripwire's reach, `kest.gd:12-13`) sets one off; the rest go off at 6.0 s. No roll |
| peak | one heavy charge dropped at the midpoint: 30 x heft, 5.0 m, a mine like the others |
| landing | the default |
| why it differs | Windhover shells B now; Air Raid pays a carpet behind her; Minelayer leaves the ground mined for the next 6 s. Its line path flies under cavern roofs, where an arc would hit the roof and end early (SKILL-BAR section 4) |

**Air Raid** (`air_raid`). Card line: "Lob over the fight. It blows behind you." It was the base in the first draft (A2-CRITIC moved it; see the top of this section).

| Field | Value (start) |
| --- | --- |
| `paths` | `["arc", "line", "rail"]`, no hold, then the hop |
| tech | one mortar throw per beat to the reticle's ground point, clamped to 12 m from the ground track (straight down with no ground under the reticle); `volley_targets(heft_class)` mini charges (3, 3, 3, 4, 4) on a 3 m ring at the throw point; 12 damage x heft each, 2.5 m radius; inert until the landing. Each is a `sticky.drop` whose `arm` and `fuse` are both set to the time until its roll slot (`sticky.gd:62-65`, `:84-92`), so a touch cannot set it off early |
| peak | the middle beat: one heavy charge to the reticle, 30 x heft, 5.0 m radius, going off with the landing strike; the stinger |
| landing | the default: 60 x heft x chain, class radius, knock 26 |
| the roll | from the first eighth note after recovery, each throw's group goes off on its own eighth note, newest first, so the fire runs back toward A. One tom thump per group, walking the motif down again |
| why it differs | from Windhover: a carpet paid later along the route, against shells now round B. From the Cannon's Fire Mission: the payoff runs back along the route after she lands, one group per eighth note, instead of every call striking on the one landing beat at B |

New ability rows (P-C adds them to `ability_state.gd` beside Kest's block at `:59-63`):

```
"cable_charge": {"icon": "ab_kest_line", "cooldown": 8.0, "line": true, "load_seconds": 4.0},
"windhover":    {"icon": "ab_kest_ult", "cooldown": 0.0, "paths": ["arc", "line", "rail"], "hold_beats": 2},
"air_raid":     {"icon": "ab_kest_ult", "cooldown": 0.0, "paths": ["arc", "line", "rail"], "variant_of": "windhover"},
"minelayer":    {"icon": "ab_kest_ult", "cooldown": 0.0, "paths": ["line", "rail", "arc"], "variant_of": "windhover"},
```

`hold_beats` is SKILL-BAR section 12's key. The draft's `"beats": 2` would have collided with the Cannon's use of `beats`, which fixes the flight length.

**Bible check.** A 2-beat hold inside a directed set piece is not free flight, which the Bible leaves unestablished (`BIBLE.md:828`).

### Which tree nodes change

Kest's tree is a 30-node heap (`kest.gd:6-71`): depth 1 is indices 0 and 1, depth 2 is 2 to 5, depth 3 is 6 to 13, depth 4 is 14 to 29 (`upgrade_tree.gd` `depth_of`, `children_of`). Depths 1 and 2 do not change.

**Compound nodes (Call).** No node is replaced. Each depth-3 node keeps its slot op and adds the ultimate swap; each depth-4 node keeps its op and adds one ultimate knob. A node with two ops already exists: Heavy Charge carries a knob and a pattern (`kest.gd:23-25`). Keeping the old ops matters for Kest in particular: the raid's charges run through `_detonate`, so Daisy Chain, Time Bomb, Demolition, Hitchhiker and Marked already change the set piece. Names stay. Effect lines are rewritten to 8 words or fewer (`upgrade_tree.gd:50`).

**Depth 3.** In each sibling pair one child gives Minelayer and the other Air Raid, so every depth-3 pick is a set-piece choice. Trap nodes take Minelayer; burst, air and stealth nodes take Air Raid. Per SKILL-BAR section 12, item 5, the "New effect line" column's set-piece half moves to the card's `SET_PIECE_LINES` line; the node's `effect` keeps only its own perk.

| Index | Node id | Kept op | Added op | New effect line |
| --- | --- | --- | --- | --- |
| 6 | `k_minefield` | `charges {weapon: 1}` | `swap {ultimate: minelayer}` | Stock two throws; ultimate becomes Minelayer |
| 7 | `k_heavy_charge` | `knob`, `pattern` | `swap {ultimate: air_raid}` | Two bigger charges live; ultimate becomes Air Raid |
| 8 | `k_carpet` | `knob {glide_bombs: 0.5}` | `swap {ultimate: minelayer}` | Glide drops charges; ultimate becomes Minelayer |
| 9 | `k_blast_jumper` | `knob {rocket_auto: true}` | `swap {ultimate: air_raid}` | Blasts launch you; ultimate becomes Air Raid |
| 10 | `k_mirage` | `charges {movement: 1}` | `swap {ultimate: air_raid}` | Stock two blinks; ultimate becomes Air Raid |
| 11 | `k_dust_devil` | `proc blink_used -> charge` | `swap {ultimate: minelayer}` | Blinks drop charges; ultimate becomes Minelayer |
| 12 | `k_marked` | `knob {line_marks: 3.0}` | `swap {ultimate: minelayer}` | Detonation line marks targets; ultimate becomes Minelayer |
| 13 | `k_vanish` | `proc cloak_broken -> refund_move` | `swap {ultimate: air_raid}` | Breaking cloak refunds blink; ultimate becomes Air Raid |

**Depth 4.** Each knob appears twice per variant.

| Index | Node id | Parent's variant | Kept op | Added knob | New effect line |
| --- | --- | --- | --- | --- | --- |
| 14 | `k_daisy_chain` | Minelayer | `knob {sticky_chain: 4.0}` | `ult_beats: 2` | Charges chain; Minelayer rides two beats longer |
| 15 | `k_sticky_rain` | Minelayer | `swap {weapon: sticky_rain}` | `ult_volley: 1` | Throws scatter three; Minelayer drops paired mines |
| 16 | `k_demolition` | Air Raid | `knob {sticky_breach: 1.75}` | `ult_radius: 2.0` | Charges crack plating; Air Raid lands wider |
| 17 | `k_time_bomb` | Air Raid | `knob {sticky_grow: true}` | `ult_beats: 2` | Charges grow while waiting; Air Raid throws longer |
| 18 | `k_dive_bomber` | Minelayer | `knob {slam_fall_scale: true}` | `ult_radius: 2.0` | Higher slams hit bigger; Minelayer lands wider |
| 19 | `k_scorched` | Minelayer | `knob {mini_linger: 3.0}` | `ult_encore: true` | Slam charges linger; Minelayer runs twice |
| 20 | `k_skybreaker` | Air Raid | `proc rocket_jumped -> grant_move` | `ult_encore: true` | Rocket jumps refill blink; Air Raid lobs twice |
| 21 | `k_comet` | Air Raid | `proc demo_slammed -> detonate` | `ult_radius: 2.0` | Slams burst; Air Raid lands wider |
| 22 | `k_phantom` | Air Raid | `knob {blink_cut: true}` | `ult_volley: 1` | Blinks cut enemies; Air Raid drops more charges |
| 23 | `k_smoke_screen` | Air Raid | `knob {smoke_cloud: 3.0}` | `ult_beats: 2` | Blink smoke hides you; Air Raid throws longer |
| 24 | `k_whirlwind` | Minelayer | `proc blink_used -> charge x3` | `ult_volley: 1` | Blinks ring three charges; Minelayer drops paired mines |
| 25 | `k_hitchhiker` | Minelayer | `knob {sticky_ride: true}` | `ult_encore: true` | Charges ride enemies; Minelayer runs twice |
| 26 | `k_death_mark` | Minelayer | `knob {mark_burst: true}` | `ult_radius: 2.0` | Marked enemies burst; Minelayer lands wider |
| 27 | `k_fuse_line` | Minelayer | `knob {line_charges: 3}` | `ult_beats: 2` | Detonation line leaves charges; Minelayer rides longer |
| 28 | `k_shadow_step` | Air Raid | `knob {cloak_free_blink: true}` | `ult_volley: 1` | Cloaked blinks free; Air Raid drops more charges |
| 29 | `k_nightfall` | Air Raid | `knob {cloak_hold_fast: true}` | `ult_encore: true` | Fast rolling holds cloak; Air Raid lobs twice |

What the four knobs mean for Kest's variants (B3 owns the knob rows and their types):

| Knob | Minelayer | Air Raid |
| --- | --- | --- |
| `ult_encore` | after the landing, a second line leg to a target within 30 m, dropping mines | a second 4-beat lob to a target within 30 m of the landing, with its own throws; its roll follows the first |
| `ult_beats` | +2 flight beats: 4 more mines | +2 flight beats: 2 more throws |
| `ult_radius` | +2 m landing radius | +2 m landing radius |
| `ult_volley` | 2 mines per drop, 1.5 m apart | +1 mini charge per throw |

The tree checks this must pass are in section 9.

## 4. Three worlds

`depth_cap(world)` is `clamp(world + 1, 2, 4)` (`upgrade_tree.gd:119-120`). World 1 offers depths 1 and 2, world 2 opens depth 3, world 3 opens depth 4.

| World | Depth open | What Kest's kit gains | Why it fits the world |
| --- | --- | --- | --- |
| 1, Spillway Works (Brindle) | 2 | The full bar from the drop: sticky charge, detonation line, Cable Charge, Windhover. Trapper (5 live, 2.5 s fuse) or Ghost (cloak sight 0.3), then Tripwire or Demo Expert, or Smoke Trail or Ambush (`kest.gd:7-19`) | The loop is learned here: throw, line, blink, ride the blast. The dam face and flumes give wall anchors for blast vaults. Windhover hangs over the open spillway bowls and stoops into them |
| 2, the Dig (the Waking) | 3 | Air Raid or Minelayer, each with its node's slot op | Enemy answers to harpoon spam arrive from world 2 (plan, creative-charge list), and the drill crew cuts lines (`HOOK-CHAIN.md:36`). A cut ends the line, and a line end sets off the Cable Charge, so a cut becomes Kest's trigger. Minelayer's line path flies under cavern roofs. Kest was dug out of this world (`src/core/achievements.gd:44-45`, `src/world/map_dig.gd:83`) |
| 3, the Highdraft (the Mind) | 4 | One ultimate knob on top of each depth-4 node's op | Her home roosts (`DESIGN-V2.md:234`, `BIBLE.md:298`). Thermals are already her contraption (`src/world/contraptions.gd:683`). Sky islands reward the base Windhover's vertical stoop onto a ledge, and an Air Raid or Minelayer encore's island-to-island second leg. The line cutter (`HOOK-CHAIN.md:36`) feeds her line-end blasts |

Power from the bar and the ultimate is paid for in pack scale per world (plan, creative-charge list). This sheet adds no per-world pack numbers.

## 5. The mecha

ROSTER-LOOK section 0 owns the shared Hoberman mecha: a rolling lattice with hubs and gaps, a level weapon ring that yaws to aim, and a gimballed cockpit pod. Its Kest row (section 0.2), its concept rules (section 0.7) and the cleaned sheet (`artifacts/local/alpha/push/w13/concepts/codex/kest/sheet.png`) set her zord:

- **Lattice.** Petrol teal enamel. Copper hubs with black tread caps. Light perforated panels fill gaps as heft grows.
- **Vents.** Two slotted fin vanes (`VaneL`, `VaneR`) open out of the side gaps for the glide. The smoke blink vents through their louvres, so this sheet calls them the vents. They stay under Pod, where the vane read finds them (`hero_assets.gd:481-486`). Like the weapon ring, they hold level outside the tumbling lattice, so the V at 2 and 10 o'clock holds while the ball rolls (section 11, item 17).
- **Weapon ring.** The mortar is two short launcher tubes on the front arc at 11 and 1 o'clock, parallel and pointing forward. The ring yaws to the aim, so the tubes face where the charge lands. Satchels ride the ring in horizontal bands only. Fuse tips are the glow, in amber.
- **Cockpit.** A petrol seat, which the sheet labels "Perch", hangs in the two-ring gimbal. Twin yokes take her wings, with the slot 1 trigger on a yoke. A lever bank beside the right yoke carries slots 2 and 3. A copper two-handed lap bar is the ultimate. Her feet rest on two pedals for Shift. The labels read "1: Sticky charge", "2: Detonation line", "3: Cable Charge", "Q: Windhover" and "Shift: Smoke blink".

This section adds what the kit drives.

### One fact, every part of the mecha

One read, `kest_cage_state()`, sits where `hero_assets.gd` reads `gliding` today (`hero_assets.gd:481-486`). Its id keeps the old word "cage". It returns vent angle, fuse glow, mortar pitch and lit satchel bands. Kest's own parts read nothing else. The lattice roll, the pod turn and the weapon ring's yaw to aim are shared motions (ROSTER-LOOK section 0.1).

| State | Source fact | Vents | Fuse tips (`class_accent`) | Mortar tubes | Satchel bands |
| --- | --- | --- | --- | --- | --- |
| Rolling | none | folded, 0.10 m past the lattice | dim | stowed, level | dark |
| Gliding | `kit.gliding` (`augments.gd:431`) | open 90 degrees, as today | dim | stowed | dark |
| Cloaked | `kit.cloaked` (`combat.gd:2185`) | louvres puff smoke twice a second | off | stowed | dark |
| Cable Charge loaded | `combat.line_load()` not empty | unchanged | one tip blinks at 2 Hz | unchanged | unchanged |
| Meter full | `abilities.meter.full()` | cracked 30 degrees, breathing at 1 Hz | all lit | tilted up 20 degrees | lit |
| Wind-up | `ultimate.phase() == "windup"` | snap to 90 degrees in 0.12 s | flare | up 45 degrees | lit |
| Flight | `"flight"` | open, smoke trailing | lit | recoils 0.08 m on each beat | one band goes dark per throw |
| Landing | `ultimate_landed` | slam shut on the boom | dim | stowed | refill over 0.4 s |

All angles and times are (start). Missing nodes are skipped, as `get_node_or_null` already does (`hero_assets.gd:483`), so the read works before the P-D mecha lands.

### Heft accretion, Kest's part

ROSTER-LOOK section 5 sets the five classes and their timings. Section 0.3 sets which gaps take panels at each class. Kest's rules on top:

| Class | ROSTER-LOOK section 0.3 | Kest |
| --- | --- | --- |
| I | every gap open | bare lattice, weapon ring and pod; folded vents at 2 and 10 o'clock; 3 satchel bands |
| II | panels in the lower gaps, below the pod | six perforated panels in the lower gaps, below Z -0.35; 3 bands |
| III | panels in the side gaps; thicker tread caps on the hubs | perforated side-gap panels, clear of the vent hinges; 3 bands; while cloaked, smoke breathes out through the panel holes |
| IV | panels in most gaps; the sight gaps stay open | flank panels at 3 and 9 o'clock, kept below the vent hinges so the V stays clear; 4 bands |
| V | every non-sight gap paneled; hub modules at their heavy form | every non-sight gap paneled, clear of the vent hinges; wide vents (ROSTER-LOOK section 5, class V); 4 bands |

A class drop flings the top layer's panels out of their gaps and, at IV, its satchel band with them (the 0.45 s fling, ROSTER-LOOK section 5). The satchel count is `volley_targets(heft_class)` (section 3), so the weapon ring shows how many targets each set-piece volley takes. The bands light through one `lit_count` shader parameter on one surface, not one mesh per band, so they cost one draw.

### Silhouette rule: the V at 2 and 10 o'clock

From the chase camera Kest is the only pilot whose outline breaks symmetrically above the 3-to-9 line: two vents sweeping up and back at 2 and 10 o'clock, with one narrow crest centred between them. The others break elsewhere: Sable at 11 and 3, Rivet at 11:30 and 12:30 with a forward V at 4 and 8, Tarn at 4 and 8, Tally at 3 and 9, the Cannon at 5 and 7 (ROSTER-LOOK section 4). Gap panels never cover the vent hinges at any class.

Check: at the far camera (12 m), with the pilot masked out, a blind reader names Kest from the mecha outline alone, 3 of 3, at classes I, III and V. This narrows ROSTER-LOOK rule 10 to Kest.

The perch stays open (section 11, item 16).

## 6. Clips

A5 confirms ids, routes and lengths. Lengths are (start). **Wing** in this table means the arm chain `shoulder`, `upper_arm`, `lower_arm`, `hand` and `curl` on one side: `pilot-v1` has no wing bones (`tools/blender/PILOT-RIG.md:23-40`), so every wing pose fits the 25-bone rig (A2-CRITIC). The seven reactions stay: `big_cheer`, `wince`, `brace`, `heave`, `slump`, `phew`, `drop_land` (`src/presentation/pilot_reactions.gd:5-18`).

| Clip | Length | Trigger | Priority, cooldown | Kest's pose |
| --- | --- | --- | --- | --- |
| `idle_loop` | 4.0 s loop | the base layer when no reaction plays | n/a | head bobs in small corrections, shoulders still (`BIBLE.md:304`); eyes check the fuse tips on the weapon ring through the front gap |
| `class_up` | 0.9 s | `heft_class_changed` | 50, 4.0 s (SKILL-BAR section 7) | crest up, wings flare once, settles as the gap panels slam in |
| `cast_special` | 0.5 s | `slot_cast` with slot `special` | 30, 1.0 s | the right wing punches the fuse plunger (`FusePlunger`, "2: Detonation line") in the bank beside the right yoke, then sweeps forward along the aim, drawing the lane |
| `cast_line` | 0.45 s | `line_skill_fired` | 32, 1.0 s | the right wing tip taps the charge key (`ChargeKey`, "3: Cable Charge") on the same bank; eyes follow the charge down the line |
| `ult_ready` | 0.8 s | `ultimate_ready` | 45, 10.0 s | crest rises, head tips up to the sky |
| `ult_windup` | 0.35 s | `ultimate_started` | 70, 0.0 s | hunches low (the rig has no leg bones, `tools/blender/PILOT-RIG.md:23-39`), both wings close on the copper lap bar, goggles down |
| `ult_strike` | 0.5 s | `ultimate_peak` | 68, 0.0 s | wings flung wide off the lap bar, head into the wind: the hang pose; both wings back on the bar by the last frame |
| `ult_recover` | 0.6 s | `ultimate_landed` | 65, 0.0 s | lets go of the lap bar and shakes the smoke out of her feathers; upper body only, control returns at 0.25 s |
| `smash` | 0.6 s | `slammed` (`game_events.gd:50`), the shared roster row (PILOT-CLIPS.md section 1.1) | 36, 1.0 s | hunches and covers her head with a wing as the minis pop |
| `unlock` | 3.0 s | `achievement_earned("dig_rescued")` at the rescue site (`achievements.gd:44-45`); again the first time her class card opens | n/a | rises out of the rubble (the `root` bone keyed; seated legs fixed), coughs dust, knocks twice on the gimbal's outer ring; on the third beat the weapon ring spins round on its bearing to face forward |

The unlock knock is a callback to her rescue line, "Says the wall knocked back the whole time" (`achievements.gd:45`), played in her motif's rhythm: knock, knock, spin.

## 7. Earned cosmetics

Nothing is bought. Amber cannot be a cosmetic tint: Kest's amber `e5a044` (`src/core/palette.gd:10`) is about 0.09 from brass `d9b44a` (`palette.gd:21`) in RGB, inside the 0.2 refusal distance (`src/core/cosmetics.gd:20`, `:83-88`). Her earned items use smoke grey and bone. Her two paints stay (`cosmetics.gd:30-31`).

| Item id | Slot | Name | What it looks like | Granted by |
| --- | --- | --- | --- | --- |
| `trail_kest_fuse_smoke` | trail | Fuse Smoke | a grey smoke ribbon with a spark that crawls back along it, tint `8c8577` | the hidden discovery Blast Vault (codex row `kest_blast_vault`, section 8) |
| `outfit_kest_rigger` (**cut for alpha**, Andrew 2026-10-16, [COSMETICS-ART-BRIEFS.md](../COSMETICS-ART-BRIEFS.md)) | outfit | Rigger Harness | a load rigger's harness with carabiners and a coil of tag line: she "maintains suspended equipment" (`BIBLE.md:304`) | discovery `kest_homecoming`, "Homecoming", detected in `kest_kit.gd` when Kest enters world 3, granted through `synergy_discovered`. **A2-CRITIC:** an achievement row cannot test the pilot (`src/core/progress.gd:259-288`), so "enter the Highdraft as Kest" cannot be an achievement condition |
| `paint_kest_rigger` | paint | Rigger Blue | a steel-blue paint, tint `4f6f9a`, standing in for the cut harness; a paint needs no art (Andrew kept it, 2026-10-17) | discovery `kest_homecoming`, "Homecoming", the same grant the harness had. Saves that earned the harness own Rigger Blue on their next load (`profile.gd` `RETIRED_COSMETICS`) |
| `shell_kest_roost` | shell variant | Roost Frame | a variant lattice drawn for the shell slot, with its own four heft layers | achievement `kest_tick_tick_boom`, "Tick, Tick, Boom": one set piece whose charges and landing strike 8 different enemies (start) |

The outfit and shell variant slots come from A4 and B5; today `cosmetics.gd` has only paint, trail, decal and companion paint (`cosmetics.gd:17`). B5 owns the reward key on achievement rows.

## 8. Discovery and codex rows

Three rows in `src/combat/codex_entries.gd`, in its entry shape (`codex_entries.gd:12-30`). SKILL-BAR's framework rows (`loaded_line`, `set_piece`, `set_piece_core`, `set_piece_cash_in`, `set_piece_breakout`) also fire for Kest and need no Kest copy.

| id | Name | Hint | Clue | Text | Opens when |
| --- | --- | --- | --- | --- | --- |
| `kest_cable_charge` | Cable Charge | Your line can carry more than you. | 3 + a click while hooked, or just before the bite | Pick 3 and click: a charge runs down your line and sets on what the hook bit. Let go and it blows. With no line out, the next bite carries it. | the first `line_skill_fired` with id `cable_charge` |
| `kest_windhover` | Windhover | "There. Give it a moment." (`BIBLE.md:308`) | a full ring + Q + open sky over where you aim | Q lobs you up over where you aim. You hang there for two beats while your mortar shells the ground below, then you stoop straight down onto it. | the first `ultimate_landed` with id `windhover` |
| `kest_blast_vault` | Blast Vault | The wall you blow can throw you. | a Cable Charge on a wall + let go close + Space held | Charge a wall through your line, reel in, and let go within a few metres holding Space. The blast throws you up and away, and your chain keeps its grace. | a `rocket_jumped` in the same tick as a Cable Charge going off on a world anchor |

The depth-3 cards for Air Raid and Minelayer come from `SET_PIECE_LINES` (SKILL-BAR section 12, item 5).

## 9. Tests and bot checks

### New: `tests/kest_kit_test.gd`

A table test in the shape of `tarn_kit_test` and `cannon_kit_test`. Scripted sources write `fire_*` and `slot_pick`, not `special_*` or `line_*` (SKILL-BAR section 8), except where a case says so.

| Case | Expected |
| --- | --- |
| 2, then a 0.8 s hold and release, with 2 live charges in the lane | both go off first; line damage 30 x 1.5 = 45; selection snaps to 1 with reason `cast` |
| the held preview with 2 charges in the lane and 1 outside | 2 preview ticks; release catches exactly those 2 |
| Cable Charge on a body at 30 m, combo 3 | travel 0.5 s; sets; let-go detonates the same tick; damage 28 x 1.6 = 44.8 |
| Cable Charge on a body, line held | goes off at 2.0 s, plus or minus one tick |
| Cable Charge on a wall, let-go at 3 m with `jump_held` | detonates; `rocket_jumped` with speed 22 to 30 |
| Cable Charge on a wall, line held, an enemy walks onto the anchor | no touch trigger; goes off at 6.0 s |
| cast with no line, bite at 3.9 s | `line_skill_loaded`, then `line_skill_fired` with `on = "body"` |
| cast with no line, bite at 4.1 s | `line_skill_expired`; no charge |
| line cut while a charge is set | the charge goes off |
| haul smash onto a body carrying a charge | smash and blast in one tick; the chain ends once |
| Windhover, aim ground at 30 m, class I, then class V | legs `arc`, `hold`, `line`; H 14 m above B; 2 hold beats; volleys hit at most 3, then 4 targets within 15 m of B; stoop damage x1.25 within class radius + 1 m |
| Windhover with a line standing on an enemy 35 m away | first leg `arc`; B is the anchor |
| Windhover flight and hold | `kit.cloaked` true throughout; no `cloak_broken("shot")` from set-piece damage |
| Minelayer | path `line`; mines arm at the landing; an enemy at 1.9 m sets one off; the rest go off at 6.0 s; never more than 10 live |
| Air Raid | path `arc`; 3, then 4 mini charges per throw at class I, then V; none goes off before the landing; groups go off on eighth notes, newest first |
| Warden, guard closed | each mini charge adds at most the "other" base posture; the landing adds at most 45 once |
| Warden, core open | the landing shatters the chunk; mini charges do not |
| the 8 depth-3 nodes | each swaps `ultimate` to its row; `UpgradeTree.problems("demolitions_caster")` is empty |

### Re-pins and must-pass

- `tests/tree_safe_picks_test.gd:21` lists today's flagged Kest nodes (`k_ghost`, `k_heavy_charge`, `k_sticky_rain`). The eight swap nodes add eight "replaces ability" reports unless B1 exempts ultimate swaps. Re-pin with a dated header either way.
- `tree_data_test`, `world_one_ktree_test` (depths 1 and 2 are untouched, so it should pass unchanged), `char_kits_test`: pass or re-pin with dated headers.
- `char_combat_test` passes unchanged. Its Kest cases (`_rocket_start`, `_sticky_start`, `_void_start`, `_line_start`, `_line_cap_start`, `_cloak_start` at `tests/char_combat_test.gd:327-441`) drive slot 2 through `special_*` directly, which stays legal (SKILL-BAR section 1).
- `presentation_ultimate_music_test` (B3) gains a Kest case: the peak stinger plays 62, 57, 53; the boom plays 50 within one beat of touchdown; roll groups fall on the eighth grid.

### Bot checks

- `tests/bot_six_demolitions_caster_test.gd` (it extends `bot_six_pilots_test.gd`) wins world one. In each winning run the bot casts slot 2 at least once, slot 3 at least once, and fires at least one ultimate (B4's rule). The run log's `ultimates` rows show path `arc` on at least 60% of starts, which proves the reordered `paths`.
- `posture_bands_test` and `alpha_posture_bands_test` stay green for Kest: the camper still cannot win, and the grown band stays at 25 s or more (SKILL-BAR section 11).
- B4's meter fill bands hold for Kest over 16 seeds.

### Measures for Andrew's sitting

| Part | Read from | Healthy |
| --- | --- | --- |
| Cable Charge reads as a fuse | run log `line_skill`, plus a split of detonations by cause (line end or fuse) | line-end share at 40% or more |
| Detonation line preview | `last_burst.caught` (`combat.gd:1878`) | mean caught per cast rises from the pre-wave base |
| Windhover volleys | `ultimates[].volley_hits` | median 4 or more per set piece |
| Variant pick | the depth-3 picks in the run log | neither variant under 25% across his runs |
| Blast vault found | codex `kest_blast_vault` open time | found within his first hour as Kest |

## 10. Implementation map: unit PC-KEST (wave P-C)

**GOAL.** Kest plays slot 2, the Cable Charge and Windhover with its two variants (Air Raid, Minelayer) from this sheet, with the tree's depths 3 and 4 wired to them, her earned cosmetics granted, and her kit proven headless.

**SCOPE.**

| File | What changes |
| --- | --- |
| `src/combat/kest_kit.gd` (new) | the `cable_charge` row for `_line_skills` (`on_body`, `on_world`, `geometry`); the `air_raid`, `minelayer` and `windhover` rows for `_ult_rows` (`tech`, `peak`, `landing`); `minis_per_throw(heft_class)`; `kest_cage_state()` |
| `src/combat/combat.gd` | one registration call into `kest_kit.gd` at setup; the detonation line preview ticks in `_line_geometry` (`:1839-1843`) |
| `src/core/ability_state.gd` | four rows (section 3) beside `:59-63` |
| `src/core/class_def.gd` | Kest's row (`:101-107`) gains `line_id: "cable_charge"` and `ultimate_id: "windhover"` |
| `src/core/trees/kest.gd` | the 24 node edits in section 3 |
| `src/ui/class_kit.gd` | `WORDS` rows (`:15-46`): `cable_charge` "cable charge", `air_raid` "air raid", `minelayer` "minelayer", `windhover` "windhover" |
| `src/combat/codex_entries.gd` | the three rows in section 8, with their detection points in `kest_kit.gd` |
| `src/core/cosmetics.gd`, `src/core/achievements.gd` | the three items and two achievements in section 7 |
| `src/presentation/hero_assets.gd` | the vane read at `:481-486` reads `kest_cage_state()`; the mortar and satchel nodes join it when P-D ships them |
| `src/presentation/audio.gd`, `src/presentation/sfx_bank.gd` | sound rows: the Cable Charge fizz, set and blast; the raid's ticks, stinger, boom and roll, built from `_motif_score("kest", ...)` (`sfx_bank.gd:1254-1258`) |
| `tests/kest_kit_test.gd` (new) and the re-pins in section 9 | |

**Shared files.** `ability_state.gd`, `class_def.gd`, `class_kit.gd`, `codex_entries.gd`, `cosmetics.gd`, `achievements.gd`, `combat.gd`, `hero_assets.gd`, `audio.gd` and `sfx_bank.gd` are also edited by the five sibling P-C units. Each edit is a row append or a one-line hook, so the coordinator merges the six units one at a time and resolves row conflicts by keeping both sides.

**ACCEPTANCE.**

- Pick 2 and click casts the detonation line; its preview ticks every caught charge, and only those are caught.
- Pick 3 and click fires the Cable Charge along a standing line or loads it; it goes off when the line ends or on its fuse (2.0 s body, 6.0 s wall), never on a touch.
- A let-go within 4.5 m of a wall charge with Space held emits `rocket_jumped`.
- Q at a full meter starts Windhover on an arc to H 14 m over B, holds 2 beats, then stoops; Air Raid's mini charges stay inert until its landing and go off one group per eighth note, newest first.
- Kest is cloaked through the flight; raid damage never crits and never breaks the cloak.
- Mini charges per throw follow the heft table; the weapon ring's satchel bands show the same number.
- Each depth-3 node swaps the ultimate to Minelayer or Air Raid as in section 3; each depth-4 node adds its knob; `UpgradeTree.problems("demolitions_caster")` is empty.
- Air Raid and Minelayer meet their tables in section 3.
- The three codex rows open once on their triggers; `codex_coverage_test` passes.
- The three cosmetics are granted only by their achievement or discovery, and their tints pass the cosmetics row check.
- `bot_six_demolitions_caster_test` wins world one with slot 2, slot 3 and an ultimate in each win; the posture bands stay green.
- `git diff --name-status` shows only SCOPE files.

**VERIFY.** `tools/coordinator/compile_check.sh`; `node scripts/sketch-lint.mjs --sketch core-loop`; the Godot runs of `kest_kit_test`, `tree_data_test`, `tree_safe_picks_test`, `world_one_ktree_test`, `char_combat_test`, `char_kits_test`, `codex_coverage_test`, `posture_bands_test`, `alpha_posture_bands_test`, `presentation_ultimate_music_test` and `bot_six_demolitions_caster_test`, each printing its PASS line with a nonzero case count; `npm run sketch:smoke -- --sketch core-loop` once on the merged wave.

**DEPENDS ON (wave P-B).**

| Unit | What PC-KEST needs from it |
| --- | --- |
| B1 | slot ids, `select`, the router, `_line_skills` and `_step_line`, `line_load()`, the `line_reel` placeholder to replace, `line_id` and `ultimate_id` on class rows, the swap validator reading `SWAPPABLE` (`upgrade_tree.gd:294`), and all ten signals |
| B3 | `src/combat/ultimate.gd` with `_ult_rows`, `plan()` and its beat rounding, the meter, the music hooks, and the four `ult_*` rows in `KNOBS` (`upgrade_tree.gd:54`). **Windhover and `ult_encore` both need `plan()` to carry several legs** (arc, hold, line); without it Windhover falls back to a high arc with no hover |
| B2 | slot 3 and the meter drawn; the tree card showing the ultimate icon on a swap node |
| B4 | the bot casting slots 2 and 3 and pressing Q |
| B5 | the outfit and shell variant slots and the achievement reward key |
| B6 | the framework codex rows Kest's rows sit beside |
| A5 and P-E | the clip ids and the clips themselves; until then the reaction rows point at today's seven clips |
| P-D | on Kest's mecha: `VaneL` and `VaneR` under Pod, and the mortar tubes and satchel band nodes under WeaponRing |

## 11. Open questions and veto items

Say "veto" on any line and it changes.

1. Veto: the Cable Charge goes off when the line ends (let-go, smash, cut, break) or on its fuse, never on a touch.
2. Veto: the Cable Charge has no reel burst on a wall; the blast vault is its wall move.
3. Veto: Windhover prefers the arc; a standing line still picks B, and she lobs above it.
4. Veto: Air Raid (depth-3 variant): mini charges stay inert until the landing, then go off one group per eighth note, back along the path.
5. Veto: Kest stays cloaked through the whole set piece and 1.5 s after; set-piece damage never crits.
6. Veto: volley targets and Air Raid mini charges per throw run 3, 3, 3, 4, 4 by heft class (`volley_targets`), and the satchel bands show the same number.
7. Veto: depth-3 and depth-4 nodes keep their old op and add the ultimate op, rather than being replaced.
8. Veto: every depth-3 sibling pair offers Minelayer against Air Raid.
9. Veto: the detonation line preview ticks each charge it will catch.
10. Veto: slot 3's name avoids the word "line"; slot 2 stays "detonation line".
11. Veto: the unlock clip knocks twice on the gimbal's outer ring.
12. Open: does B3's `plan()` carry several legs? Windhover's hover and every `ult_encore` need it.
13. Open: should the Cable Charge's wall blast also break cracked walls and breach plates, as a verb the park lane can place?
14. Open: re-pin `tree_safe_picks_test` with eight new reports, or have B1 exempt ultimate swaps from the safe-growth check?
15. Open: amber is too close to brass for cosmetic tints, so Kest's earned items use smoke grey and bone. Is that acceptable for her identity?
16. Open: ROSTER-LOOK section 0.2 gives Kest a perch, and the cleaned sheet labels her petrol seat "Perch" (`artifacts/local/alpha/push/w13/concepts/codex/kest/sheet.png`, cockpit panel). Does the perch change her seated rest pose, or is it the section 0.7 seat in her colours? PE-KEST waits on this answer (PILOT-CLIPS section 10).
17. Open: ROSTER-LOOK section 0.2 lists the vents as hub modules, and hubs tumble with the lattice (section 0.1). This sheet keeps `VaneL` and `VaneR` under Pod, where `hero_assets.gd:481-486` reads them, so the V at 2 and 10 o'clock holds. Confirm, or move the vents and the read together.

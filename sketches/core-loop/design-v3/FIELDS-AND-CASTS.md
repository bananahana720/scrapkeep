# Fields, casts, world motifs and damage families

> **Implementation status:** The Spillway jolt layer (`src/combat/area_field.gd`) and pilot/cast plumbing are built; Dig/Highdraft world fields (`Wet floor`, `Floodlight`, `Dust choke`, `Crosswind lane`, `Mind echo`) in section 2.4 remain design proposals unless added in `src/`.

Status: design proposal plus a first slice, written 2026-10-17 from Andrew's project-chat asks (19:35Z, 19:37Z). The slice (section 9) is code on its own branch; everything else is design. Numbers marked (start) are starting values to tune in play. Paths are under `sketches/core-loop/`. Read [ENEMY-PRIORITY.md](ENEMY-PRIORITY.md) first: this page builds on its kill order, perches and pilot struggles.

Andrew's asks, in his words: enemies that "create debuff or buff area of effects that stem from the enemy itself or can be laid out", for example "an electrical field that can stun the player and or cause them to get interrupted"; "cast times with the pilots themselves to either balance aspects of their activatable items or activatable abilities", in the spirit of MMORPGs and MOBAs (League of Legends, Dota). Then (19:37Z): enemies "vary from world to world"; each world has "themes in which the player can play around with or engage with or fight against"; areas "that target certain aspects of the game design or mechanics in terms of movement or abilities or the pilot's grapple or rolling or momentum"; enemies with "plated armor that's strong against concussive hits, but is weak against ability-based or electrical-based attacks". Everything he says is a signal to carry as a consistent motif, "not used unanimously across the board or in equal fashion, but in intentional and resonating ways. Or harmonizing ways."

## 1. The ask as verbs

- **Reading ground.** A patch of floor becomes good or bad to stand on for a few seconds. Seeing it, and deciding to cross, skirt or exploit it, is the skill.
- **Timing a commitment.** A big ability takes a moment to come out. Choosing when, from where and at what speed you start it is the skill; getting caught mid-cast is the cost.
- **Keeping moving.** Every field's answer is a verb the ball already has: speed, a jump, a line. Standing still is what fields punish.
- **Choosing the right tool.** Some enemies shrug off a ram and fold to a bolt, or the reverse. Picking the hit that fits, and building toward it, is the skill.
- **Learning a world.** Each world teaches one idea, tests it, then mixes it with the others.

Disciplines: encounter design (fields and their pairings), systems design (casts, damage families), level design (where fields sit relative to lips, rails and perches), sound and VFX (every pulse is read before it lands), playtesting (the lab and the red team).

## 2. Fields

### 2.1 One component, many owners

`src/combat/area_field.gd` is one area effect: a circle that pulses an effect on what stands in it. An enemy draws it and moves it; the component owns the rule. Items and stage events can use the same rows later.

| Column | Meaning |
| --- | --- |
| `anchor` | `laid`: stays where it was committed (a mat, a puddle). `emitter`: follows its source every tick (an aura). |
| `target` | `player`: a debuff on the ball. `enemies`: a buff on the source's pack (section 2.4, later). |
| `radius`, `height` | the circle, and how far above or below it still counts |
| `pulse`, `lead` | seconds between pulses; the last `lead` seconds of each pulse draw a charge-up (the ring fills, the coil swells), so the pulse is read before it lands |
| `breaks` | what lets a pulse pass the ball by: `speed` (FAST tier, 1.15x cruise, 16.1 m/s at default tuning), `air` (off the ground), `line` (a harpoon line attached) |
| `effect` | the one thing it does; the first row is `jam` |

### 2.2 Fairness rules

1. A field is a committed telegraph. Its ring draws on the frame it is declared and follows the warning rules every attack follows: one pack's warnings start together, and no two packs or kinds start a warning within 0.2 s of each other. A pulse inside an already drawn field is not a new warning; its `lead` is its read.
2. A field never covers a lip's landing zone or a rail's end (the ENEMY-PRIORITY placement rule 4, extended).
3. Effects refresh, never stack. Two fields overlapping jam you for the longer of the two, not the sum.
4. Fields do not take control of the ball. No field removes steering, roots, or caps speed. The holds system (`holds.gd`) stays the only thing that grabs the ball, with its tenacity bound.
5. A field that does damage counts against the attacker budget. A field that only buffs its pack does not, as the Foreman does not.

### 2.3 The jolt layer (first slice)

A Spillway Fleet crew under a cable spool. It unrolls a live mat where the ball is going: an instant ring, radius 6 m (start), laid over the ball after a 1 s warning. Live for 3.7 s, the mat pulses every 1.2 s with a 0.5 s lead. A pulse that finds the ball slow on the mat jolts it: charging gauges and running casts drop with nothing spent, and the specials and line skill jam for 0.5 s. A fast ball, a ball in the air, or a ball on a line slips the pulse. Rivet's sprint ignores it, as it ignores every hold.

- **Threat feature:** a coil on the spool that swells before each pulse.
- **Tone:** a jolt stamps a small "BZZT" word on the ball, and the crew's ears stand on end (the slice draws the swelling coil and the pulse flash only; the word and the ears are presentation work for the cue pass).
- **Sound:** a rising hum through each lead, a crack on the pulse, a dry fizz when a ball slips it. Until the music thread bakes these, the slice is silent on pulses: that counts as a placeholder at the wave 20 check.
- **Pack (proposal):** "live wire": jolt layer (controller) plus chaser (punisher). The mat asks you to stay fast; the chaser's lunge lane asks you to turn. Fast and turning is the skill.

### 2.4 The field family, by world (design)

| Field | Owner | Anchor | Does | Answer | World |
| --- | --- | --- | --- | --- | --- |
| Live mat (jam) | jolt layer | laid | drops casts and gauges, jams specials 0.5 s | speed, jump, line | Spillway |
| Wet floor | stage water | laid | arc on water already electrifies it (`elements.gd` `arc:water`); a jolt mat laid on water spreads to the whole puddle | the same, and your own arc uses it too | Spillway |
| Floodlight (buff) | the floodlight rig (the lamp swarm reworked, proposed by the world 2 and 3 identity thread) | emitter | crew inside the light are plated: they take about 60% from resisted hits | yank them out of the light with the harpoon, or break the lamp | Dig |
| Dust choke | Dig crew | laid | casts started inside it take 1.5x as long (start) | cast before you enter, or carve through and drop out of it | Dig |
| Crosswind lane | Highdraft crew | laid | pushes enemies and loose drones along it, never the ball | air-ram a crew into it for a ring-out off the island | Highdraft |
| Updraft (neutral) | stage wind, as the thermals contraptions already do | laid | lifts anything that enters it, ball and drones alike; the player chooses to ride it | ride it; or knock a drone into it to fling it | Highdraft |
| Mind echo (buff) | the Mind's hands | emitter | its pack braces the damage family you used most this stage | switch family | Highdraft (Mind) |

Three standing rulings bind every row: events never stop the ball (PARK.md), abilities have snap, and movement belongs to the pilot (decisions.tsv). So no field takes steering, velocity or the harpoon. A field acts on abilities (the jam, the dust choke), on enemies (the floodlight, the crosswind), or offers movement the player chooses to take (the updraft).

## 3. The jam (the interrupt)

**The rule, one line: a jolt costs you a cast, never your speed.**

A jam shuts the special and the line skill for its seconds and drops anything charging. The weapon, the boost and movement chip, the smash and Q stay open. It goes through the one crowd-control door (`player_ball.crowd_control`), so Rivet's sprint and every immunity already apply. A smash still lands while jammed, but an upgrade that spends the special on it (Crater Slam's discharge) is skipped, because the special is the jammed slot. Pressing the special again or right mouse drops a running cast with nothing spent, like a charging gauge. In the roster row the field's breaks read `speed` and `jump` (the holds vocabulary); an attached line also lets a pulse pass, which that vocabulary has no word for.

Why not a stun. A stun in a rolling game takes the ball away, which breaks the speed pillar and the "learnable and fair" rule at once: the player cannot react during it. A MOBA silence is the closer fit: you keep moving, you lose your spells. The jam is the silence; the dropped gauge or cast is the interrupt. Both are short, both are telegraphed, and both have three answers the ball already owns.

**Cleanse.** Q starts its set piece through a jam (Q is never jammed), and the set piece already breaks every hold. That is the built-in cleanse. A cleanse item (section 8, after the sitting) clears a jam and grants 1 s of jam immunity.

## 4. Cast times

**The rule, one line: a cast commits you to a moment; only a heavy pilot plants for it.**

A row's `cast` is the seconds between the press and the effect. The ball rolls at full speed the whole time, except where the pilot plants (below).

**Who plants (Andrew's Q2, "Depends on the pilot", 22:12:39Z).** Tarn and the Cannon plant for their heavy casts: the four depth-3 Q variants that carry `plant` (Rake Run, Vice Leap, Creeping Barrage, Plate Mortar) brake the ball to a stop within 0.15 s and hold it through the 0.5 s wind-up. Sable, Kest, Rivet and Tally cast on the move. The plant is the pilot's own choice of stance, the only cast that stops the ball, so the standing rulings hold: no field, item or enemy takes the ball's speed. Checked by `tests/cast_motion_test.gd` for all six pilots. Nothing is spent until the cast lands; an interrupting hit (a jolt, a knock) drops it with nothing spent, exactly as it drops a hold gauge today. The slot reads active while it casts, and the selection timer pauses.

| Rule | Value (start) | Why |
| --- | --- | --- |
| Where the effect lands | ground-targeted casts commit their geometry at the press; self-centred casts fire where the ball is when the cast lands | damage and telegraphs consume the same committed geometry; at 30 m/s a 0.4 s cast travels 12 m, so the player must see where it lands |
| What drops a cast | any interrupting hit through the crowd-control door, a second press, a slot swap | one rule shared with gauges |
| What does not | rolling, steering, boosting, jumping | the speed pillar (a planting pilot stops by its own choice) |
| Indicator | the bar slot fills over the cast; the ground shape draws at the press | the player sees both clocks |

**Which abilities, proposal.** Cast times are a balancing lever for the big activatables only. Small ones stay instant.

| Ability | Cast today | Proposal (start) | Lever |
| --- | --- | --- | --- |
| Every ultimate (Q) | 0.35 s wind-up already (`ultimate.gd` WINDUP_SECONDS) | keep 0.35 s; a jolt during it recalls Q with a full refund | the wind-up becomes interruptible, so Q from inside a mat is a gamble |
| Stronger depth-3 ultimate variants | 0.35 s | 0.5 to 0.8 s, longest for the strongest (for example the Cannon's Plate Mortar) | a variant buys power with exposure, the MOBA trade |
| Tally's Gather Plate | instant tap | 0.3 s | her pull-everything tap is strong in a crowd; a cast gives packs a window |
| Hold-gauge specials (Sable, Rivet, Kest, Tarn, the Cannon) | the gauge is already a commitment | none | the gauge is their cast |
| Line skills | the line itself is the commitment | none | no double tax on the harpoon |
| Weapons, movement, smash | instant | none | speed and feel |

**Momentum casting (separable extra, off in the slice).** Casts run at 1.0x below FAST tier and 0.7x at BLAZING (start). Speed then answers casts as it answers fields, one rule across both. It also makes casting from a carve the skilled way to cast, which feeds the half-pipe in ENEMY-PRIORITY section 3a.

## 5. World motifs

Each world teaches one idea, tests it, then hands it on. The names (Flow, Plate, Wind) follow the coordinator's design-questions page, question 3, whose recommended option is the working default until Andrew answers. Not every enemy carries its world's motif; the motif sits in a few kinds, the arena and the boss, and comes back as a guest in later worlds.

| World | Motif | What it tests | Fields | Damage family it teaches | Where it returns |
| --- | --- | --- | --- | --- | --- |
| Spillway (dam, flumes, Brindle) | **Flow**: water and current; wet machines carry electricity | rolling and momentum: stay fast and fields cannot touch you | live mats, wet floors | **arc**: wet crews are weak to arc (about 150%); arc on water electrifies (already built) | the jolt layer guests in Dig packs beside plated crews |
| The Dig (mine, the Waking) | **Plate**: armour, pressure and light | abilities and kill order: plates shrug off rams, so you cast, and casting is exactly what mats and dust punish | floodlights, dust chokes | **kinetic against plate**: plating resists kinetic, arc finds the seams, frost makes plates brittle | plated elites in the Highdraft |
| The Highdraft (sky islands, the Mind) | **Wind**: gusts, fliers and edges you can knock things off | the grapple and the air: swing, air-ram, ring crews out off the edges | crosswind lanes, updrafts, Mind echo | **mix**: light drones fly off islands to kinetic knocks; the Mind braces your favourite family | the final fight uses every motif once |

The harmony, in one line: **speed beats fields, casts beat plates, the wind is a weapon you aim, and the Mind makes you use all three.** Each answer becomes the next world's pressure: Spillway teaches speed, the Dig makes you commit to casts, the Highdraft makes you swing and ram crews off its edges.

**Remix rule (Andrew, 19:52Z: no rehashed enemies).** A motif that returns in a later world comes back changed, never as a plain repeat: a new pairing, a new terrain interaction, or a harder read. The jolt layer in the Dig lays its mat beside a dust choke and a plated crew, so the cast you need to crack plates is slow and jammable at once; you cast from speed or before you enter. In the Highdraft the mat covers the only landing pad on an island, so the air answer means swinging to the next island instead of landing. The world 2 and 3 identity thread owns the rosters; this page owns how fields, casts and families read in each.

### 5.1 Skill areas

A skill area is a short stretch of a park built around one verb, with a reward at its end (a cache, a secret tune, a cosmetic part). One or two per park, never on the main route.

| Verb | Spillway | Dig | Highdraft |
| --- | --- | --- | --- |
| Rolling and momentum | a flume run lined with jolt mats: hold FAST tier and none land | | |
| Abilities and casts | | a plated vault under floodlights: break the lamps, then cast through the seams | |
| Grapple | | | an island chain with no floor between: swing every gap |
| Carving | the Warden bowl rim (ENEMY-PRIORITY section 3a) | | |

## 6. Damage families and resistances

### 6.1 Families from the kinds we already have

Every hit already carries a `kind` string into the one damage door (`combat.gd strike()`, `damage_door.gd`). A family is a lookup on that kind, not a new tag. The three families match the element table (`elements.gd` ELEMENTS).

| Family | Kinds | Feel |
| --- | --- | --- |
| kinetic | ram, stomp, slam, rush, claw, clamp, burst, overdrive, cannon, shell, sticky, pin, ledger, line | the concussive hit: knocks, posture, plate cracks |
| arc | arc, electrify, the jolt layer's own pulse if it ever damages | no knock; slips past plating |
| frost | frost ring, frost parts | slows nothing on the ball; makes plates brittle |

A second axis already exists: the source class (`combat.gd _classify_source`: contact, drop or slam, weapon, special, item proc). Andrew's "ability-based" reads as weapon and special sources. Resistances key on family first and source second.

### 6.2 How resistance fits the existing systems

| System | Today | With families |
| --- | --- | --- |
| Plating (`resolve()`, armour stage) | punch at or above plating lands in full; below it chips at 20% | a resisted family deals about 60% and a weak family about 150% (the design-questions page, question 5, recommended "Lean, never a wall"), applied in the existing `hit_mult(kind, part)` hook so the armour stage is unchanged |
| Brittle (new, frost) | none | a frost hit marks a plated target brittle for 3 s: its next kinetic hit is not resisted |
| Posture and stagger (`boss_posture.gd`) | contact kinds build 30, smash 45, other kinds 1.5 | unchanged for kinetic; arc builds 0.5x posture but ignores plating, so arc kills and kinetic staggers |
| Knockback (`event_kinds.gd` IMPACT) | per-kind knock, lift, stop | unchanged; arc already does not knock, so it never sends a crew into a ring-out |
| Per-enemy hooks (`enemy.gd plating_for(kind, part)`, `hit_mult`) | the Warden and the Mind's hands brace some kinds (`braced_kinds`) | the family table feeds these same two hooks, so no new stage in the door |

The rule stays one judgement per hit, owned by the existing hooks. No enemy is immune to a family; the worst case is 60%, and below plating today's 20% chip.

**Reading a weakness** (Andrew's Q6, "Learn on first hit", 22:12:39Z): the first resisted and the first weak hit on an armour class each run stamp a comic word over the body, DENT and ZZAP! (STATE_ROWS `dented`, `zzapped`); the first read discovers the codex entry "Plated", and from then on, across runs, every enemy of that class wears a small slate icon 3.1 m up (STATE_ROWS `plated`), above the interrupted star at 2.4 m and far off the ground telegraphs.

**As built (Q5 "Lean, never a wall", 22:12:39Z).** `src/combat/damage_families.gd` owns the numbers (`RESISTED` 0.6, `WEAK` 1.5), the family of each kind and the ARMOUR rows; combat's caps stage applies them to a hit that beat the plating, and nothing reads below 60%. The ability source is the special class (slots 2 and 3 and the set piece); the weapon is not an ability. Weak beats resisted on one hit, so a kinetic ability on plate is weak: casts beat plates. Armour is placed on purpose, not everywhere: the Spillway's Flow conducts through water (`elements.gd` arc:water), not armour; the Dig's Plate is the `plated` row, first on the drill crew (its own plate still takes the first breaking hit whole; its 22 plating still decides whether a hit gets through, the armour row how much of it counts), and any enemy can name its class with an `armour_class()` method, which the elites of "World 2 and 3 enemy identity" will use; synergy and item procs count as kinetic; the Highdraft's Wind is ring-outs, not armour. Checked by `tests/damage_families_test.gd`.

### 6.3 Pilot reads

| Pilot | Main family | Plated Dig crews | Answer |
| --- | --- | --- | --- |
| Sable | arc | strong | already her matchup fix for the plated brute |
| Rivet | kinetic (laser counts as weapon kinetic) | weak | a blazing ram still cracks plate (ram punch scales with speed); arc parts |
| Kest | kinetic (sticky) | weak | quick-fuse into a frost part's brittle window |
| Tarn | kinetic (claw) | weak | Claw Drag the crew out of the floodlight first |
| Tally | kinetic (ledger) | weak | Gather Plate the pack, then a frost part |
| The Cannon | kinetic (cannon) | weak, but its lane pierces | plate mortar variant |

This sharpens ENEMY-PRIORITY section 5: the Dig is where five of six pilots hunt for an arc or frost part, which "Nudge loot" (answer weighting, 1.5x) already supports.

## 7. Tensions with the speed pillar

| Tension | Where | How the design holds it |
| --- | --- | --- |
| Cast times reward slowing down | every cast | casts never root or slow; momentum casting (section 4) would make speed shorten them |
| Plating and dust reward stopping to aim | the Dig | a blazing ram still cracks a Dig plate; arc and frost are the cheaper answer, not the only one |
| A jam takes your tools mid-carve | Spillway mats | FAST tier slips every pulse; only a slow ball is jolted |
| Wind could push the ball off its line | the Highdraft | crosswinds push enemies only; updrafts are ridden by choice |
| Fields could fill a bowl and stop carving | any arena | placement rule 2: no field on a lip's landing zone or a rail end; at most one live field per pack (start) |

None of these slows the ball. The pillar's hard line: no field, cast or resistance takes velocity away. The 60 m/s soft cap is untouched.

## 8. Where it lands

At most two new enemy behaviours per wave (ENEMY-PRIORITY section 4b). Waves 17 and 18 already carry theirs, so:

| Wave | Lands | Why there |
| --- | --- | --- |
| 18 (cloud, now) | the slice: area field component, cast-time field and jam on the ability state, the jolt layer spawnable in the lab | no behaviour reaches play until a pack names it; zero play change |
| 19 | jolt layer in Spillway packs ("live wire"), damage families in the armour stage, the jolt cues | 19 adds one enemy (the Linker); this is its second |
| 20 | the floodlight aura on the floodlight rig | 20 starts poles and flails, a harpoon change, not an enemy |
| After the sitting | dust choke, crosswind and updraft crews, Mind echo, skill areas, the cleanse item, momentum casting | new bodies or new systems |

## 9. First slice (this branch)

| Piece | File | What it does |
| --- | --- | --- |
| Area field | `src/combat/area_field.gd` | the component and its first row, `static_jam`, with laid and emitter anchors, pulse and lead clocks, and the three breaks |
| Jolt layer | `src/combat/jolt_layer.gd`, its `roster.gd` row, `tools/blender/world_one/enemy_jolt_layer.py` | a world 1 Fleet controller on the counter loop with its own model; spawnable by name, in no pack yet |
| Cast time | `src/core/ability_state.gd`, `src/combat/combat.gd`, `src/combat/ultimate.gd` | `cast` on a row, `begin_cast`, `cancel_cast`, `take_cast_done`; the tap path casts through it; interrupts drop it with nothing spent; a Q row's `cast` is its wind-up |
| Jam | `src/core/ability_state.gd` | `jam(seconds)` shuts SPECIAL and LINE; their state reads unavailable and a press answers "jammed" |
| Plant | `src/combat/ultimate.gd`, `plant` on four `ability_state.gd` rows | Q2: Tarn's and the Cannon's variant wind-ups brake the ball to a stop; `tests/cast_motion_test.gd` checks all six pilots |
| Damage families | `src/combat/damage_families.gd`, `src/combat/combat.gd` caps stage, `src/presentation/armour_marks.gd`, codex `armour_plated` | Q5 and Q6: plated resists kinetic (0.6) and is weak to arc and abilities (1.5); DENT and ZZAP! on the first reads; the codex entry and the icon; `tests/damage_families_test.gd` |
| Test | `tests/jolt_layer_test.gd`, `tests/tally_kit_test.gd` | 28 checks: cast rows, cast, jam, field, and a live jolt layer that jolts a slow ball, is slipped by air and by a line, and recalls Q in its wind-up; Tally's test waits out the 0.3 s cast |

Added after Andrew's "Big ones only" tap (19:56:59Z): Gather Plate casts in 0.3 s and aims at the press; every depth-3 Q variant winds up 0.5 s (`VARIANT_CAST`, start, until the power read ranks them); a jolt during Q's wind-up recalls Q with a full refund.

Not in the slice: pack placement, the floodlight, frost brittleness, momentum casting. The model is in (a procedural world-one body with its own coil mesh), and so is its voice: presence loop, tell 1.0 s before each pulse, jam, the Q-recall fizzle and the death break, loaded from assets/audio/specials/jolt_layer_*.wav when present (rendered on PR #12).

## 10. Calls for Andrew

Sent to the coordinator as cards:

1. **Decided 2026-10-17 19:56:52Z, "Jam".** How hard should an electric field hit you? Jam (recommended): charges and casts drop and specials lock 0.5 s, rolling untouched. Short stun: the ball also loses steering for 0.3 s. Slow: the ball loses 20% speed inside the field.
2. **Decided 2026-10-17 19:56:59Z, "Big ones only".** Which abilities should get cast times? Big ones only (recommended): Q stays at 0.35 s and becomes interruptible, stronger Q variants cast longer, Gather Plate 0.3 s. Every bar ability: specials and line skills too, 0.2 to 0.5 s. None yet: keep the mechanism, no cast times before the sitting.

Already asked on the coordinator's design-questions page, so not sent as cards: casting on the move (question 2), world themes (question 3), resistance strength (question 5) and how weaknesses are shown (question 6). This page builds on their recommended options until Andrew answers.

Decided here, reversible: the field component is shared by enemies and items; Q is never jammed; families are a lookup on the existing kind string; the jolt layer stays out of packs until wave 19; momentum casting is off; a ground-targeted cast aims at the press and an invalid aim is refused then.

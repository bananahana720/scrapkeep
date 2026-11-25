# Ability mutations: kit swaps, live shot bits and items that rewrite a verb

Status: design proposal for wave 45 unit W45-B2, written 21 Nov 2026 against `stage/alpha-w45` at `fc8507686`. Nothing here changes code. Numbers marked (start) are starting values until the lab ranks them. The follow-on code is split into units in section 10, each with its permitted files.

**Weapon cadence (ruling ek, 22 Nov 2026):** each pilot's baseline trigger, its timers and its first tree pick are in [PILOT-CADENCE.md](PILOT-CADENCE.md). A kit swap or shot bit on this page changes a weapon through the `Pattern` cadence fields that page defines in its section 7.

The ask this answers: the six ability slots already know how to be swapped, and a closed set of five shot bits already exists, yet a World 1 run almost never changes what a verb does. Items are the heart of progression (ruling in [DECISIONS.md](../../../project-guide/handoff/DECISIONS.md), 23 Oct, "Items are the heart of progression"), and a cobalt fleet-grade item "changes a verb's look and play". Today most of that rung is a cooldown scalar. This page says what the rung should do instead, grounded in what the code can already carry.

Read first: [LEGIBILITY.md](LEGIBILITY.md) section 13 (no slop, ruling cx), [STORY-MAP.md](STORY-MAP.md) for the voice, [POLES-FLAILS.md](POLES-FLAILS.md) for the structure and the weight rule this page borrows, [SKILL-BAR.md](SKILL-BAR.md) and [FIELDS-AND-CASTS.md](FIELDS-AND-CASTS.md) for the slots and the cast and jam rules, and the repo rules in [AGENTS.md](../../../AGENTS.md) (rules 7, 8 and 10).

## 1. The ask as verbs

- **Re-aiming a verb, not re-numbering it.** The player holds a thing and the same press now does something they can see: a slam drags, a sweep returns, a sixth volley fuses.
- **Reading it before it lands.** Every new effect draws the geometry that hits (the skill-shot rule, `FORGIVENESS`), in a colour the game already taught.
- **Combining without a manual.** A shot carries up to three bits and the pair table says what two do together. Two items of one maker still wake one trick. No second hidden list.
- **Staying fast.** No mutation touches how far or how fast the ball moves. Movement distance and speed belong to the pilot.

## 2. What exists today (verified in code at `fc8507686`)

| Fact | Where |
| --- | --- |
| Six slots exist. `SLOTS` is weapon, movement, special, smash, line; `ULTIMATE` stays out of `SLOTS` because its charge is the meter, not a cooldown. `SWAPPABLE := SLOTS + [ULTIMATE]` says an upgrade may swap all six. | [ability_state.gd:18](../src/core/ability_state.gd), [:26-27](../src/core/ability_state.gd) |
| An ability row is data: the rest of the game dispatches on a row's capabilities, never its id, so a variant is one row plus, when it plays differently, one entry in the owning dispatch table (combat's `_specials`, the ball's `SMASHES`). **Important weapon-swap gap:** `active_weapon()` returns the slot's ability id ([combat.gd:1574-1579](../src/combat/combat.gd)), `_patterns` is keyed only by `Weapons.ALL` ([combat.gd:4375-4383](../src/combat/combat.gd)), and fire branches require `_patterns.has(weapon)` ([combat.gd:1616,1621](../src/combat/combat.gd)); a row's `pattern` key is read today only on the sticky lob path ([combat.gd:3561](../src/combat/combat.gd)). Swapped weapon rows (`claw_rake`, `cannon_lane_walk`) therefore require resolving the `pattern` key in `active_weapon()` (unit U3/U5). | [ability_state.gd:98-121](../src/core/ability_state.gd), [:136](../src/core/ability_state.gd), [combat.gd:1574-1621](../src/combat/combat.gd) |
| `swap(slot, id)` and `cap(slot, key, fallback)` are the whole interface a relic or a tree pick uses. | [ability_state.gd:346](../src/core/ability_state.gd), [:386](../src/core/ability_state.gd) |
| Tarn's kit: `claw_sweep`, `claw_pull`, `clamp`, `rend_slam`, line `claw_drag`. Tally's: `ledger_reader` (cards, pressure 3), `flywheel_surge`, `gather_plate` (cast 0.3 s), `stamp_slam`, line `link_clips`. The cannon's: `cannon_lane`, `cannon_recoil`, `cannon_plate`, `cannon_rush`, line `cannon_lane_charge`, each with a Mind `family`. | [ability_state.gd:140-150](../src/core/ability_state.gd), [:175](../src/core/ability_state.gd), [:183-185](../src/core/ability_state.gd), [:191](../src/core/ability_state.gd) |
| A skill shot draws exactly its committed geometry and the hit test forgives a hull `FORGIVENESS := 0.18` beyond the drawn edge, so what you see is never bigger than what can hit. | [ability_state.gd:80-82](../src/core/ability_state.gd) |
| A jam shuts `SILENCED := [SPECIAL, LINE]` by slot, so a swapped row in those slots is jammed exactly like the base row. | [ability_state.gd:91](../src/core/ability_state.gd) |
| `Relics.ROWS` holds one row per relic. A relic fits exactly one pilot and rewrites one slot with `swap`, `cooldown` or `charges`. `MAX_NAME_WORDS := 3`, `MAX_TEXT_WORDS := 8`. | [relics.gd:18-19](../src/build/relics.gd), [:31-105](../src/build/relics.gd), [:231](../src/build/relics.gd) |
| World 1 has 12 relics and only **3 swaps**: `crater_heart` (Sable smash to `crater_slam`), `muzzle_heart` (Rivet special to `point_blank`), `rain_heart` (Kest weapon to `sticky_rain`). | [relics.gd:32-41](../src/build/relics.gd) |
| **Tarn, Tally and the cannon have no World 1 swap.** Their six World 1 relics are all cooldown scalars: `taut_cable` 0.70, `vice_heart` 0.75, `oiled_flywheel` 0.70, `return_spring` 0.75, `kick_spring` 0.70, `brace_pin` 0.75, all on the movement and special slots. | [relics.gd:44-55](../src/build/relics.gd) |
| `Relics.validate()` accepts only `slot in AbilityState.SLOTS`, so `ultimate` cannot be a relic slot. It also requires a swap's icon to end in the slot suffix (`SUFFIX`: `_weapon`, `_move`, `_special`, `_smash`, `_line`; there is no ultimate suffix), exactly one pilot, and at least `MIN_PER_PILOT := 2` relics per pilot. | [relics.gd:24-25](../src/build/relics.gd), [:219-242](../src/build/relics.gd) |
| The ultimate is already swapped by the upgrade trees. Each of the three trees has 8 depth-3 nodes carrying `"swap": {"ultimate": ...}` (Tarn to `rake_run` or `vice_leap`, Tally to `plate_audit` or `plate_flywheel`, the cannon to `cannon_creeping_barrage` or `cannon_plate_mortar`). | [trees/tarn.gd:25](../src/core/trees/tarn.gd), [trees/tally.gd](../src/core/trees/tally.gd), [trees/cannon.gd](../src/core/trees/cannon.gd) |
| A relic that duplicates a tree swap is not offered and does not strip the pick on undo (`gives_swap`, `tree_owns`). | [relics.gd:183](../src/build/relics.gd), [build.gd:1797-1810](../src/build/build.gd), [upgrade_tree.gd:549](../src/core/upgrade_tree.gd) |
| `ShotBits` is a closed set of five bits: `pierce 1, bounce 2, split 4, pull 8, heat 16`. `MAX_PART_BITS := 2`, `MAX_SHOT_BITS := 3`; bits past the third drop in held order and are reported in `dropped`. `TABLE` holds one row per bit (colour, sound, rule) and `PAIRS` the 10 pairwise outcomes. | [shot_bits.gd:20-59](../src/build/shot_bits.gd), [:110-122](../src/build/shot_bits.gd) |
| Parts get bits from tags (`kinetic` and `mass` give pierce, `chain` bounce, `split` split, `anchor` pull, `arc` heat) or from an explicit `"bits"` list on the row. `PartDef.bits` is set from that in `from_row`. | [shot_bits.gd:44-45](../src/build/shot_bits.gd), [part_def.gd:93-95](../src/build/part_def.gd), [:173](../src/build/part_def.gd) |
| `Bolts.child()` copies the parent's bit set, so a child neither gains nor loses a bit. `Bolts.fire()` defaults `bits` to 0. | [bolts.gd:92-96](../src/combat/bolts.gd), [:113-120](../src/combat/bolts.gd) |
| **The bits are never read.** `Bolts.step()` has no bit logic and `Combat._fire()` builds its bolt record with no `bits` key; the other `bolts.fire` call (line 3930, the pylon sentry, source `persistent_actor`) passes none either. Only tests and `PartDef` touch `ShotBits`. A shot carries bit 0 whatever the player holds. | [bolts.gd:123-163](../src/combat/bolts.gd), [combat.gd:1723](../src/combat/combat.gd), [:1746-1756](../src/combat/combat.gd), [:3930](../src/combat/combat.gd) |
| Not every weapon fires bolts. `cannon_lane` commits a Mind lane hazard (`"bolts": 0` in `last_shot`), the sticky charge lobs, Tally's weapon runs program cards. Bits mean something only for bolt weapons: Sable, Rivet and Tarn's claw. | [combat.gd:2263](../src/combat/combat.gd) and the `_fire` path |
| `Pattern.TRANSFORMERS` on `fc8507686` is eight data rows: `cross_split`, `spiral_wave`, `chain_arc`, `damage_tier`, `rate_tier`, `range_tier`, `capacitor`, `overclock`. Caps apply last: `MAX_VOLLEY := 16`, `MAX_ARMS := 8`, `MAX_ARM_OFFSET := 14`. At `fc8507686`, `fan_spread` and `helix_drill` sit in `items.gd:78-86` behind `needs` (`build.gd:508-509`); sibling unit **W45-B1** adds both to `Pattern.TRANSFORMERS` and `AlphaDefs.PARTS` in this wave (alongside `storm_lattice`, `linked_spiral`, `thermal_shock`, `glacier_hull` in `AlphaDefs.SYNERGIES`). | [pattern.gd:19-27](../src/combat/pattern.gd), [:58-91](../src/combat/pattern.gd), [:137-142](../src/combat/pattern.gd), [items.gd:78-86](../src/build/items.gd) |
| `Synergies.EVOLUTIONS` has **4 pairs**: `breaker_drive` (`double_feed` + `hot_rivets`), `bladestorm_rotor` (`spiral_wave` + `loose_trigger`), `storm_mast` (`focus_lens` + `live_line`), `grounding_spike` (`arc_coil` + `drop_weight`). Evolved rows are all stat folds (punch, damage, fire rate, a spiral level). None changes what a verb does. | [synergies.gd:126-138](../src/build/synergies.gd), [parts.gd:386-398](../src/build/parts.gd) |
| 14 maker tricks, two distinct pieces of one maker wake one: `ballast_rig`, `shatter_crew`, `wrecking_ball`, `glacier_hull`, `shrapnel_bloom`, `storm_lattice`, `tesla_pylon`, `live_wire`, `pinwheel`, `hair_trigger`, `storm_front`, `thermal_shock`, `linked_spiral`, `lightning_rod`. | [synergies.gd:36-123](../src/build/synergies.gd) |
| Six F-key **Actives** (`active` verb in [NAMES.md:5](NAMES.md), [active_defs.gd:3-4](../src/combat/actives/active_defs.gd)): `scrap_rocket`, `silo_battery`, `cutting_torch`, `lift_pulse`, `quake_knock`, `glass_lance` (on by default via `tuning.gd:100`). Three call `combat._chain` (`scrap_rocket`, `silo_battery`, `glass_lance`), three count as explosive `+1` blasts for W45-C (`scrap_rocket`, `silo_battery`, `quake_knock`), and all six pass `SOURCE := "special"` to `combat._hit` (e.g. `scrap_rockets.gd:36`), so special-slot mutations must hang on the two kit special release exits (`combat.gd:1899-1915` for gauge releases and `_land_tap` when `slot == SPECIAL` at `combat.gd:1970-1982`) rather than filtering strike `source`. | [active_defs.gd](../src/combat/actives/active_defs.gd), [scrap_rockets.gd:36](../src/combat/actives/scrap_rockets.gd), [combat.gd:1899-1915](../src/combat/combat.gd), [:1970-1982](../src/combat/combat.gd) |
| Strikes that come from an item rather than the player's weapon carry the source `item_proc`, and seams treat them differently. Tree `volley` and Kick Shot also fire `_fire(weapon, "item_proc")` ([combat.gd:3833-3838](../src/combat/combat.gd)). This is the one tag a proc-chain guard hangs on. | [combat.gd:149-153](../src/combat/combat.gd), [:1231-1236](../src/combat/combat.gd), [:1792](../src/combat/combat.gd), [:3833-3838](../src/combat/combat.gd) |

The gap in one line: the slot machinery, the bit table and the evolution table all exist, and together they change no verb in World 1 for three of the six pilots. Section 8's matrix covers both the six ability slots and the six F-key Actives (`active_defs.gd`).

## 3. What other games do, and what we take

Research first (ruling, 23 Oct): reference what other games actually do, give the reasoning and the rejected options.

### The Binding of Isaac: Rebirth

- **What it does.** Tears carry independent flags (piercing, spectral, homing, bouncing, splitting, status effects) that stack freely, and a few items replace the weapon outright: Brimstone turns tears into a charged beam, Tech X into a charged ring, Mom's Knife into a thrown blade. When two replacers meet, a small hand-authored table decides the result rather than a general rule. Difficulty follows the player (the item pool scales the rooms) so a runaway build is the point, not the bug.
- **Why it works.** Flags are orthogonal, so a player learns each once and every combination is free to read. Replacers change the silhouette of the verb, so the player sees which kind of run they are in within a second.
- **What we twist.** Scrapkeep already took half of this: five bits, a cap of three, a ten-row pair table ([shot_bits.gd:1-18](../src/build/shot_bits.gd) cites the comps note and refuses the unbounded stack). The Isaac stack has no cap and the screen fills. We keep the cap. For replacers we reject the hold-to-charge beam, because holding still is the one thing a rolling ball never does (rulings cu, cast times: a long cast is a card). Our replacer fires on a cadence while the ball keeps its speed: every sixth volley fuses (section 7, C1).

### Risk of Rain 2

- **What it does.** Each survivor owns four skill slots and alternate skills swap one slot for another verb. The Lunar Heresy items replace a slot with a fixed alternate. Items proc on hit with a proc coefficient per skill, and a proc-chain mask stops a proc from triggering the same class of proc again, which is what keeps stacked on-hit items from detonating the frame budget.
- **Why it works.** A swap is one slot, one pilot, one visible new verb, and the alternates are authored, never rolled. The chain mask is a bound written into the data, not a hope.
- **What we twist.** The relic rung is already our Heresy: one relic per slot, per pilot, `swap` to another row ([relics.gd:1-12](../src/build/relics.gd)). We keep the shape and fill it for the three pilots that only got cooldown scalars. We copy the chain mask in the form we already have: the `item_proc` source tag (section 8). We refuse the Lunar curse. A relic never removes a slot or costs health, because Overpowered pays (ruling, 17 Oct): strong builds are never punished.

### Hades

- **What it does.** A weapon has aspects that change what its attack, special and cast do as a set, and Daedalus Hammers offer a choice of upgrades that each rewrite one named behaviour of the weapon you hold. Duo boons need a pair of gods and bend one verb's geometry (a slow field, a chain, a delayed blast).
- **Why it works.** Every upgrade names the verb it touches and shows it in the animation. The player chooses among three, so a rewrite is a decision, not a surprise.
- **What we twist.** Our aspect is the pilot relic (one slot, a new row). Our hammer is the cobalt item that names the verb it touches (`touches` in the item row already says `fire`, `special`, `boost` or `harpoon`, [items.gd:13-20](../src/build/items.gd)). Our duo is the maker pair and the evolution. The twist is speed: Hades rewards standing in the right place, Scrapkeep rewards rolling through it, so every rewrite either fires on the move or pays a kite (ruling cu: rolling through a pack and kiting round it stay free).

## 4. Rules that bind every mutation

1. **One home per fact.** A new behaviour lives in the module that owns the state and is reached through one small call. The ability row says what a slot is (`cap(slot, key)`), the bolt record says what a shot carries, the build says what the run holds. No caller reaches into a private member (AGENTS rule 7).
2. **Closed tables, no framework.** A new bit, effect or ability behaviour is a row plus a code change in the owning module, never a script or a rule language ([shot_bits.gd:5-10](../src/build/shot_bits.gd), [ability_state.gd:68-69](../src/core/ability_state.gd): "TADR-008 keeps it one integer per row, no tags or framework").
3. **Movement stays the pilot's.** No mutation sets the ball's velocity, adds a brake, adds a `plant`, or lengthens a cast. Mutations move enemies, spawn committed geometry or change what a strike does. A new cast time is a card (decisions, pilot cast times).
4. **Draw what hits.** Every new area or line goes through the existing committed-hazard path, so the drawn footprint is the hit footprint plus `FORGIVENESS`. Player-owned marks use the pilot's colour or the bit's `TABLE` colour, never `HAZARD`, which only enemy telegraphs own ([bolts.gd:12-13](../src/combat/bolts.gd), [shot_bits.gd:17-18](../src/build/shot_bits.gd)).
5. **Cobalt is the ceiling.** Ruling bn: cobalt is the top ordinary rung in every world for the alpha. Items below are green (`uncommon`) or cobalt (`rare`). Relics stay on the existing relic rung and are not a new tier. Nothing here is pearl or gold.
6. **No slop.** A tell is position, shape, colour, icon, motion or sound first and a word last (LEGIBILITY section 13, carrier order). Relic and item text carries a mechanism or a number, not a feeling (W3).

## 5. A. World 1 kit swaps for Tarn, Tally and the cannon

Two new relics per pilot, six in all, which takes World 1 from 3 swaps to 9. They sit in the **weapon, smash and line** slots, the three slots the six cooldown relics leave empty, so the old relics stay and the new ones pair with them. A run holds one relic per slot, so a pilot can wear a cooldown relic in movement or special and a kit swap in weapon, smash or line at once.

Each row below is a relic row (name at most 3 words, text at most 8, one pilot, `world: 1`) and one new ability row. Every new ability row reuses the pilot's own icon (the suffix rule holds) and the dispatch is a `cap(slot, "mutation", "")` read in the module that already runs the base row.

| Relic | Maker | Pilot, slot | Swap (new row) | Text | Rule (start) |
| --- | --- | --- | --- | --- | --- |
| Gutter Heart | waking | Tarn, smash | `rend_slam` to `rend_drag` (`ab_tarn_smash`, `flavour: rend`) | Rend slams drag machines into the crater | The landing keeps the rend disc, `flavour: rend`, and damage. Machines inside whose weight (`Grip.heft_of`, [flail.gd:159](../src/combat/flail.gd)) is at or below the pilot's heft slide to the centre over 0.4 s (one inward knock; no ball motion). Heavier machines take the hit and hold. This is the pole rule of POLES-FLAILS section 3 turned on the slam: weigh more and it comes to you, weigh less and you come to it. |
| Rake Heart | redjaw | Tarn, weapon | `claw_sweep` to `claw_rake` (`ab_tarn_weapon`, `pattern: claw_sweep`) | Each sweep rakes again on return | The first sweep fires as `source == "weapon"` (carrying bits and waking tricks), then the same arc returns 0.25 s later as a mutation strike (`source == "item_proc"`, `bits = 0`, no item procs or tricks) at 0.6 damage, drawn mirrored. Unit U3 updates `Combat.active_weapon()` ([combat.gd:1574-1579](../src/combat/combat.gd)) to resolve `cap(WEAPON, "pattern", weapon)` when looking up `_patterns`, so every Tarn tree node and transformer on `claw_sweep` applies cleanly. |
| Ink Heart | mind_glass | Tally, smash | `stamp_slam` to `stamp_ink` (`ab_tally_smash`, `flavour: stamp`) | Stamped machines refill pressure on balance due | The stamp keeps `flavour: stamp` (so base stamp pressure pay stays intact, [combat.gd:472](../src/combat/combat.gd), [augment_kit.gd:115](../src/movement/augment_kit.gd)) and books every machine in its disc for 3 s, drawn as a ledger tick on each. When balance due strikes a booked machine, Tally refills 1 pressure, once per machine per stamp. Pressure still caps at its bank (3), so no loop. |
| Double Entry | fleet_surplus | Tally, line | `link_clips` to `link_double` (`ab_tally_line`) | Settled clips jump to one fresh machine | Base `link_clips` already clips the latched machine plus its two nearest neighbours within 9 m ([weapons.gd:177-178](../src/combat/weapons.gd), [combat.gd:3016-3031](../src/combat/combat.gd)). `link_double` keeps that 3-machine clip and adds a settlement transfer: when a clipped machine settles, its clip jumps once to the nearest unclipped machine within 9 m (drawn as a fresh ledger link from the settled machine) so Tally chains one extra settlement per cast. One jump per cast, never recursive. Unit U4 updates the four `link_clips` id checks (`combat.gd:446,2810,2990`, `audio.gd:5078`) to read `cap(LINE, ...)` / accept `link_double`. |
| Walking Lane | mind_glass | Cannon, weapon | `cannon_lane` to `cannon_lane_walk` (`ab_cannon_weapon`, `pattern: cannon_lane`, `family: lane`) | Second call walks the lane further out | A lane called within 2 s of the last starts where the last ended, up to 6 m further along the aim, and a third does not extend: the walk resets after two links. Resolves `pattern: cannon_lane` through `active_weapon()` (same lookup rule as U3) and commits each lane through `_commit_cannon`. |
| Rush Wake | waking | Cannon, smash | `cannon_rush` to `cannon_rush_wake` (`ab_cannon_smash`, `flavour: rush`, `family: rush`) | Rush landings leave a lane behind | On landing, keeping `flavour: rush`, a committed lane is laid back along the rush's travel line at half lane damage (`source == "item_proc"`), with the lane's own telegraph delay. It never re-lays on its own strike. |

Notes on the table:

- **Names and voice.** "Heart" is the existing relic noun (`crater_heart`, `muzzle_heart`, `rain_heart`) and the three hearts here match it. "Double Entry", "Ink", "Walking" and "Wake" are bookkeeping and workshop words the Tally and Mind voice already uses (the ledger, the audit). All texts use `machines` per [NAMES.md:25](NAMES.md) (never `bodies`). Each name is at most three words and the text word counts are 7, 6, 7, 7, 7 and 6 (`<= MAX_TEXT_WORDS := 8`). Each new ability row also adds its `WORDS` entry in `src/ui/class_kit.gd` (owned by U3–U5).
- **Makers spread on purpose.** Maker sets count distinct pieces (`Parts.maker_counts`, [parts.gd:830](../src/build/parts.gd)). Waking and Mind-glass are thin in World 1 today, so a Gutter Heart or an Ink Heart is also a way to reach two of a maker and wake its trick. Redjaw already has `taut_cable` and `vice_heart`, so Rake Heart is the only redjaw addition.
- **Pilot invariants.** None of the six touches the movement slot, adds `plant`, or lengthens a cast. `gather_plate` keeps its 0.3 s cast and `SILENCED` still shuts the line row (`link_double`) like `link_clips`.
- **Ultimate policy (a call, section 9, call 1).** `ultimate` stays tree-owned. `Relics.validate()` keeps refusing it (`relics.gd:220`), and the SUFFIX map keeps having no ultimate entry. Reasons: all three trees already own ultimate swaps in their depth-3 and depth-4 nodes, so a relic would be a second source for the same slot; the undo path only reasons about a same-row duplicate (`tree_owns`); and the ultimate is the one slot whose depth-3 variant is a sibling choice (the Tally header says "siblings always one of each"), which a flat relic would bypass.
- **Offer rules unchanged.** `Relics.eligible()` still hides a relic whose swap a tree pick already gave and still offers one relic per held slot, so a Tarn run never shows both a swap and a cooldown for the same slot.
- **Behaviour sits where the row runs.** Rend and stamp are ball smashes (the ball's `SMASHES` table), claw sweep is a pattern fire (combat `_fire`), the lanes and the rush are committed cannon hazards (`_commit_cannon`), the link is a line skill (`_fire_line_skill`). Each unit reads `cap(slot, "mutation", "")` at the one place its base row already branches.

## 6. B. Plumbing `ShotBits` into live combat

The bit table is finished and tested in isolation and the live game ignores it. This section says how a held part becomes a bolt's behaviour, which weapons it applies to and how it rolls out.

### B1. The grant

- **One call on the build:** `Build.shot_bits() -> int`. It walks the held parts in held order, takes each part's `bits` (`PartDef.bits`), passes the masks to `ShotBits.shot()` and returns `bits`; `dropped` is kept on the build for the readout. It is derived from the part list and cached in the stat cache, so a retry that restores the list restores the shot.
- **Which weapons.** The call returns 0 when the weapon row says `"bolts": false` (a new row key, defaulted true). The cannon lane, the sticky charge and Tally's cards set it. A bit part held by such a pilot still gives its other numbers and never gives a silent bit (section 9, call 4).
- **Which volleys.** `Combat._fire` adds `"bits": ctx.build.shot_bits()` to its bolt record strictly when `source == "weapon"` (player weapon press). Free-shot procs — including tree `volley` and Kick Shot, which already call `_fire(weapon, "item_proc")` ([combat.gd:3833-3838](../src/combat/combat.gd)) — keep `bits = 0` so proc depth stays strictly 1 and stacked volleys cannot cascade split bolts.
- **Children.** `Bolts.child()` already copies the set. The new rule on top of it is the consumed set: a record carries `spent`, the bits already used up (split on its first hit, pull on its first hit, bounce on its first wall). A child inherits the set and `spent` together (except `pierce`, see B3), so a split child never splits again and a bounced bolt never bounces twice.

### B2. Priority and the drop rule

The cap rule is unchanged: `ShotBits.shot()` keeps the earliest held part's bits and drops the rest, in held order, past `MAX_SHOT_BITS := 3` ([shot_bits.gd:108-122](../src/build/shot_bits.gd)). This spec keeps it and does not reorder by power, for two reasons. The earliest part is the one the player has had longest, so the rule is learnable without a screen. And re-ranking by power would make a late pickup silently swap a bit the player was relying on. What the player does get is a way to see it: the build readout draws each dropped bit as its chip struck through (carrier: shape and icon, no sentence), read from `dropped`. No toast and no "dropped" word (S6, W3).

### B3. Tells and the pair table

One row per bit already holds colour, sound and rule, and `ShotBits.tells(mask)` reads all three ([shot_bits.gd:29-40](../src/build/shot_bits.gd), [:126-131](../src/build/shot_bits.gd)). Live play reads that row and nothing else, so sight and sound cannot drift.

| Bit | Colour | Sound | Live rule on a bolt | Pair rows it joins |
| --- | --- | --- | --- | --- |
| pierce | `LEDGER` | `breach_crack` | The first machine hit takes the strike and the bolt keeps flying, once. `spent` gains pierce, so a second machine stops it. With W45-B1's `helix_drill` pattern `pierce`, the bit adds +1 pierce cleanly (`pattern.pierce + 1`). | pierce+bounce, +split, +pull, +heat |
| bounce | `ARC` | `shell_spring` | The first wall hit reflects the bolt about the surface normal with its remaining range, once. | bounce+pierce, +split, +pull, +heat |
| split | `BRASS` | `scrap_rip` | The first machine hit spawns two children at +/- 18 degrees (start) with half damage each, through `Bolts.child()`. | split+pierce, +bounce, +pull, +heat |
| pull | `SLATE` | `line_zip` | The first machine hit takes one inward knock toward the shooter, scaled by the pilot's heft against the machine's weight (`Grip.heft_of`, [flail.gd:159](../src/combat/flail.gd): lighter comes, heavier holds). | pull+pierce, +bounce, +split, +heat |
| heat | `COPPER` | `wear_sputter` | The machine glows for 2 s (start). A second heated hit on a glowing machine adds 15% damage (start), once per machine per 2 s. | heat+pierce, +bounce, +split, +pull |

Because `bolts.gd` renders every bolt as one MultiMesh instance with a single colour (`bolts.gd` `_process`), a bolt cannot draw multi-colour striped bands. Instead, a bolt carrying one or more bits takes the first present bit's `TABLE` colour in `ShotBits.NAMES` order (`pierce`, `bounce`, `split`, `pull`, `heat` — never `HAZARD`), gains a slight width scale (+15% for 2–3 bits) in `bolts.gd`, and fires each bit's distinct hit-event sound and impact cue from `ShotBits.tells()` (at most one bit sound per hit so audio does not stack).

The 10 `PAIRS` rows stay as written. The ones that need code attention because they gate on an event type are: `bounce+pull` (a wall glance pulls nothing), `bounce+heat` (a wall glance heats nothing), `split+pull` (only the first hit pulls, children do not) and `pierce+split` (children never split again but keep piercing, so split children inherit `spent` with `split` set and **minus `pierce`**).

### B4. Rollout, because this is a balance event

Switching the bits on changes every build at once. The shot-bit test already shows at least 30% of random six-part builds reach three bits, and parts that tag `kinetic`, `mass`, `chain`, `split`, `anchor` or `arc` carry one or two. A single switch would make nearly every run pierce and bounce overnight.

- **Live mask knob.** One tuning knob, `shot_bits_live`, a mask of the bits the game honours. Start with pierce and heat (no new bolts, no new queries). Bounce, then pull, then split follow in later units.
- **Ruling cu pairing.** Anything that eases play ships with a matching pressure, measured together (ruling cu). Pierce clears packs faster, so the pierce unit lands with its pressure measured in the same lab batch (the world 1 bands, `scripts/world1-bands.test.mjs`), not "later".
- **Re-baseline.** Difficulty is set from the median build (item ladder row), so the median build moves when the bits go live. The unit that enables a bit re-cuts the median reference and says so in its receipt.

## 7. C. Gameplay and ability-mutating items

Seven new items and one new pattern transformer. They touch a verb each, by name, as the cobalt rung should. Rarities map the ladder rows in DECISIONS: `uncommon` is a green field kit (a verb tweak) and `rare` is cobalt (changes a verb's look and play). `world` is 1 and up; none is pilot-locked unless it says so.

| Item | Maker | Rarity | Verb it touches | Rule (start) | What the player sees |
| --- | --- | --- | --- | --- | --- |
| Slag Pike (C1) | fleet_surplus | rare | weapon, bolt pilots | Every sixth volley fuses into one bolt: damage is the sum of the volley's bolts capped at x6, range x1.25, radius matched to its drawn width, and `pierce` enabled **within `MAX_SHOT_BITS := 3`** (if the pilot holds 3 non-pierce bits, `pierce` temporarily replaces the 3rd bit on the fused bolt only so no bolt ever holds 4 bits). Counter resets on fusing and on 3 s without firing. Renamed from "Slag Lance" to stay distinct from `Glass Lance` and `Lance Arc`. | Volley five lights the muzzle ring copper, volley six is one bright thick bolt in the pierce colour. Sound is `breach_crack`. |
| Halo Rig (C2) | highdraft_roosts | uncommon | weapon pattern | New transformer `halo`: `add arms 5`, `min arm_offset_deg 10`, `mul damage 0.55`, `mul rate 0.85`. Caps apply last, so with `cross_split` (arms +3) the volley clamps at `MAX_ARMS := 8` and `MAX_VOLLEY := 16`, outermost bolts trimmed first. | A ring of bolts around the aim line instead of a fan. It is a silhouette change, which is what Tech X does for Isaac. |
| Backwash (C3) | spillway_works | uncommon | movement (side effect only) | A dash or boost lays a ripple strip 4 m long behind the ball's path (committed footprint, damage 0.4 of a weapon hit, one strike per machine per dash). Dash distance, speed and cooldown are untouched. | A flat strip in the pilot's colour trails the dash. It pays the kite: enemies chasing the ball cross it. |
| Barbed Reel (C4) | redjaw | rare | grapple, reel-in impacts | A reel-in impact (the `harpoon_smashed` event) also hits the nearest other machine within 6 m once at 0.7 damage through `_chain`, with `chain_jumps` 1. The jump cannot re-trigger the item. | A short arc from the struck machine to the next, in the pilot's colour. |
| Faultline Cap (C5) | waking | rare | smash | A smash landing cracks an 8 m corridor ahead along the ball's heading (committed lane at 0.5 smash damage) and fires `Destructibles.on_blast(point, 2.5, "faultline_cap", 1)` at three points along the crack. Respects [HEFT-DESTRUCTIBLES.md](HEFT-DESTRUCTIBLES.md)'s hard +1 tier cap (no stacking to +2): it extends the slam's +1 heft reach down an 8 m corridor rather than breaking higher tiers. | A drawn line leaves the crater, the ground cracks along it and props along the line shatter at +1 tier. |
| Second Bell (C6) | mind_glass | uncommon | special | Hangs on both kit special release exits: the gauge release ([combat.gd:1899-1915](../src/combat/combat.gd)) and `_land_tap` when `slot == SPECIAL` ([combat.gd:1970-1982](../src/combat/combat.gd), reached via `_step_cast` at `:1948-1967`). Neither is reached by F-key Actives, ultimates (`ultimate.gd:923` emits `special_used`), Crater Slam (`combat.gd:3967`) or plant discharge (`combat.gd:3450`). On damaging specials, the pulse repeats once 1 s later at half strength (`source == "item_proc"`), drawn at commit. On non-damaging tap specials (`gather_plate`), the gather ring repeats once 1 s later at half radius. The repeat spends nothing, refills nothing, and cannot repeat. | The first footprint stays lit and a second pulse rings from it. |
| Long Leash (C7) | moss | uncommon | line skill | A line skill's `load_seconds` doubles (start 4 s to 8 s). The bite, cooldown and damage are unchanged. | The loaded line stays drawn twice as long. |

Notes on the table:

- **C1 versus Brimstone.** The Isaac verb is a charge you hold. Ours is a cadence you roll through, and it reads in the muzzle ring before the pike, so the player can aim the fused bolt. The sum cap is what keeps `cross_split` and a spiral from turning one fused bolt into a screen wipe.
- **C2 as data.** `halo` is a row in `Pattern.TRANSFORMERS`, so it composes with every other row by the existing add, mul, min order and the existing clamp. That is the cheapest way to change a silhouette.
- **C3 and ruling cu.** A strip behind the ball punishes nothing and costs the pilot nothing. It rewards the chased, which matches "hardness presses a ball that slows or stops, never one that keeps rolling and turning".
- **C4 and the weight rule.** The jump uses the lighter-comes rule only through the existing `_chain` hit, not a new pull. POLES-FLAILS owns the weight rule and this item only adds a second strike.
- **C5 and W45-C.** [HEFT-DESTRUCTIBLES.md](HEFT-DESTRUCTIBLES.md) owns `Destructibles.on_blast(at, radius, source, tier_bonus)` in `src/world/destructibles.gd` and rules "Nothing breaks more than one tier above the class; no stacking." Faultline Cap obeys that rule strictly: it passes `tier_bonus = 1` along its 8 m crack corridor (sampled as three committed radius-2.5 m circles), never +2. If W45-C has not landed yet, the call is a no-op and the crack lane still hits enemies.
- **C6 versus `echo_release`, tree `special_echo` and F-key Actives.** `item_effects.gd` already has `echo_release` as a chance effect, and `upgrade_tree.gd:69` already uses the knob name `special_echo` (`combat.gd:1911-1912`, `_tick_echo` at `:1994`). Second Bell uses its own effect id `second_bell` (no name clash), hooks both kit special release exits (`combat.gd:1899-1915` and `_land_tap` for `SPECIAL` at `:1970-1982`) so F-key Actives, ultimates, Crater Slam and plant discharge never trigger it, and stays deterministic and drawn. A pilot holding both the tree's `special_echo` and `second_bell` gets two bounded repeats; neither triggers the other. Whether to fold C6 into `echo_release` is open (section 9, call 9).
- **Ultimate.** No item touches the ultimate. It stays a tree choice.
- **New effects are closed-table rows.** Each rule is one id in the `EFFECTS` table of [item_effects.gd:24-32](../src/build/item_effects.gd) (`pike_fuse`, `dash_wake`, `reel_chain`, `slam_crack`, `second_bell`, `line_leash`) plus the one call site in its owning module. No script, no hook list.

### D. New evolutions (3 pairs, onto the under-served makers)

The four evolutions today serve Fleet Surplus (`breaker_drive`), Highdraft Roosts (`bladestorm_rotor`), Mind-glass (`storm_mast`) and Moss (`grounding_spike`). Spillway Works, Redjaw and Waking each have tricks and no evolution. These three close that and are the first evolved parts that change a verb rather than fold a number. Each follows the existing shape: an `EVOLUTIONS` pair, an `EVOLVED_FROM` trick, and an `EVOLVED` row that gives nothing while an ingredient is missing. All six ingredient parts are in `AlphaDefs.PARTS` (no Shift Board unlock is required), and `thermal_shock` is unlocked in `AlphaDefs.SYNERGIES` by W45-B1.

| Evolved | Pair | Grew out of | Maker | Rule (real verb change, not redundant tag bits) |
| --- | --- | --- | --- | --- |
| Grapeshot Press | `cross_split` + `pin_setter` | `shrapnel_bloom` | redjaw | Its ingredients already supply `pierce` and `split` by tag (`shot_bits.gd:44-45`); the evolution rewrites split geometry so split children fire in a tight forward cone (+/- 8 deg instead of +/- 18 deg) and carry a knockback punch (0.5 x smash knock), turning wide split scatter into forward bowling shrapnel. |
| Hoar Barrel | `frost_barb` + `rime_rounds` | `shatter_crew` | spillway_works | Machines have no frozen-body state (`codex_entries.gd:6-7`); shatter breaks ice slabs (`element_field.gd:257-275`) and `rime_rounds` already grants `pierce` (`parts.gd:178`). Hoar Barrel makes every piercing bolt drop a 2 m frost patch under its pierced machine and detonate any ice slab it crosses into a forward shard cone using `shatter_crew`'s shatter dial. |
| Fault Hammer | `echo_locator` + `brace_frame` | `thermal_shock` | waking | Uses two Waking-available `AlphaDefs.PARTS` rows (no `ring_wave` dependency). A slam landing sends a delayed seismic aftershock ring 0.45 s later (source `item_proc`, half damage, cannot echo again) that shatters ice slabs inside its ring and calls `Destructibles.on_blast(at, slam_radius, "fault_hammer", 1)` (respecting W45-C's +1 tier cap, never +2). |

Notes:

- The pairs share no ingredient with an existing evolution, so no part sits in two. All six ingredients live in `AlphaDefs.PARTS` (`cross_split`, `pin_setter`, `frost_barb`, `rime_rounds`, `echo_locator`, `brace_frame`).
- Evolved rows are outside the offer pool and have roll weight 0 ([parts.gd:381-385](../src/build/parts.gd)), so `offer_weights_test` is unaffected except by the ingredient parts' own existing weights.
- Unit U8 owns the combat hooks (`src/combat/`) for Grapeshot Press's tight knockback cone, Hoar Barrel's ice-slab pierce shatter, and Fault Hammer's delayed aftershock ring, alongside `synergies.gd` and `parts.gd`.

## 8. Interaction matrix and bounds

### Matrix

`yes` means the two compose by the rule in the cell, `cap` means a named bound applies, `no` means they do not interact.

| New mutation | `cross_split` / `spiral_wave` | `chain_arc` | `fan_spread` / `helix_drill` (W45-B1) | Six ability slots | Six F-key Actives (`active_defs.gd`) | Maker tricks | Shot bits | W45-C heft (`Destructibles.on_blast`) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Slag Pike (C1) | cap: sum cap x6 holds a 9-bolt cross to one pike | yes: chain runs on the fused bolt's hit | cap: pattern bolts fuse first; `helix_drill` pierce adds +1 | weapon | no (weapon press only) | `shrapnel_bloom`, `storm_lattice` fire on kills | cap: carries held bits with `pierce` inside `MAX_SHOT_BITS := 3` | no |
| Halo Rig (C2) | cap: `MAX_ARMS` 8, `MAX_VOLLEY` 16 | yes: each ring bolt can chain | yes: composes in `Pattern.TRANSFORMERS` under caps | weapon | yes: actives that read `pattern_level` ignore `halo` unless opted in | `pinwheel` ring stays separate | yes | no |
| Backwash (C3) | no | no | no | movement | no | `ballast_rig`, `hair_trigger` dash elements apply to dash only | no | no |
| Barbed Reel (C4) | no | yes: one chained hit | no | line, movement (grapple) | no | `tesla_pylon` arcs while hooked: neither triggers the other | no | no |
| Faultline Cap (C5) | no | no | no | smash | no (kit smash only; `quake_knock` has its own +1) | `storm_front`, `thermal_shock`, `live_wire` slam elements apply | no | yes: `on_blast(..., tier_bonus = 1)` along 8 m crack (no +2 stack) |
| Second Bell (C6) | no | no | no | special, jammed with special | **no** (hooks gauge release `:1899-1915` and `_land_tap` `SPECIAL` `:1970-1982`; actives, ultimates, Crater Slam and plant discharge never enter) | `live_wire` applies to first pass only (repeat is `item_proc`) | no | yes: kit blast special echoes at `tier_bonus = 1` (no +2) |
| Long Leash (C7) | no | no | no | line | no | none | no | no |
| Gutter Heart | no | no | no | smash | no | `glacier_hull` landings ring cold on drag | no | yes: slam keeps standard W45-C +1 |
| Rake Heart | yes: cross sweep returns as cross | yes (first pass; return pass is `item_proc`) | yes (via `active_weapon()` pattern lookup) | weapon | no | first pass wakes `shrapnel_bloom`; return pass is `item_proc` (no tricks) | first pass carries bits (`weapon`); return pass is `item_proc` (`bits = 0`) | no |
| Ink Heart, Double Entry | no | no | no | smash, line | no | `mind_glass` pieces count for `tesla_pylon`, `live_wire` | no | yes: `stamp_ink` keeps standard slam +1 |
| Walking Lane, Rush Wake | no | no | no | weapon, smash | no | `mind_glass` pieces count as above | no (`bolts: false`) | yes: `cannon_rush_wake` keeps standard slam +1 |
| Grapeshot Press | yes: arms split into tight forward knockback cone | yes | yes (`fan_spread` + `helix_drill` compose under caps) | weapon | no | `shrapnel_bloom` is its source | yes (rewrites `split` cone & knockback) | no |
| Hoar Barrel | no | no | yes (`helix_drill` adds +1 pierce across slabs) | weapon | no | `shatter_crew` is its source | yes (on piercing bolts) | no |
| Fault Hammer | no | no | no | smash | no | `thermal_shock` is its source (W45-B1) | no | yes: delayed ring calls `on_blast(..., 1)` (no +2 stack) |

### Anti-loop bounds

These are the bounds each unit's tests must prove, with a planted failing control each (section 10).

1. **Proc depth is 1.** Slag Pike's sixth volley is the player's own press (`source == "weapon"`), so it carries bits, chains, and wakes tricks once. Every follow-up mutation strike — Rake Heart's return pass, Backwash's wake ripple, Barbed Reel's chain, Second Bell's repeat pulse, Faultline Cap's crack, Fault Hammer's aftershock ring, Rush Wake's trailing lane, and Hoar Barrel's shard cone — fires with `source == "item_proc"` (`bits = 0`) and never starts another mutation, bit, or item proc. This is the same shape as Risk of Rain's proc-chain mask, built on the `item_proc` tag that already exists ([combat.gd:149-153](../src/combat/combat.gd)).
2. **Every repeat is single.** The return sweep, the second bell pulse, the walking lane link, the reel chain jump and the fault ring each happen once per cause. None re-arms itself and none refunds its own cost.
3. **Bolt count is bounded by data.** A split child consumes `split` through `spent`, so the family tree of one bolt is at most 3 bolts. `Bolts.MAX_LIVE := 64` retires the oldest past the cap ([bolts.gd:18](../src/combat/bolts.gd), [:92-96](../src/combat/bolts.gd)), `Pattern.MAX_VOLLEY := 16` trims the volley, and `MAX_ARMS := 8` trims the arms.
4. **No movement lockout.** No mutation changes velocity, brakes the ball, adds `plant`, or adds a cast. Pulls move enemies. The jam still shuts only `SILENCED` slots and never the ball ([ability_state.gd:84-91](../src/core/ability_state.gd)).
5. **No visual drift.** Every area is committed first and drawn from the same record it hits with, at `FORGIVENESS := 0.18`. A mutation that cannot be drawn does not ship.
6. **Pressure per heavy event.** Pull is per machine per bolt and limited to the first hit; a pierce-pull bolt pulls each pierced machine once and the first hardest (the pair row), which is `O(machines)` per bolt and not a loop.
7. **Cooldown floor.** No mutation lowers a cooldown, and none changes a charge count. `COOLDOWN_FLOOR := 0.4` and the refund caps ([ability_state.gd:44](../src/core/ability_state.gd), [:56-62](../src/core/ability_state.gd)) stay unaffected.

## 9. Rejected options and open calls

### Rejected

| Option | Why not |
| --- | --- |
| A relic for the `ultimate` slot | Trees already own all 24 ultimate-swap nodes, so a relic becomes a second source for one slot. `validate()` and `SUFFIX` have no ultimate form and the undo path only handles a same-row duplicate. The ultimate is a sibling choice at depth 3. |
| A script or effect language for mutations | TADR-008 declines a general framework ([shot_bits.gd:5-10](../src/build/shot_bits.gd), [ability_state.gd:68-69](../src/core/ability_state.gd)). A new behaviour is a closed-table row and a code change in the owning module. |
| Isaac's unbounded flag stack | Visual readability caps the shot at three bits, and the screen has a bolt cap ([bolts.gd:7-13](../src/combat/bolts.gd)). The unbounded stack is what the cap was written to refuse. |
| A hold-to-charge beam (Brimstone, Tech X as written) | It asks a ball that keeps rolling to hold still. Heavy pilots plant only for their Q variants by Andrew's call ([ability_state.gd:84-90](../src/core/ability_state.gd)). Ruling cu: hardness never stops a ball that keeps rolling. C1's cadence gives the same fantasy without the stop. |
| Relics or items that change movement distance, speed or boost length | Movement distance and speed belong to the pilot. The three movement cooldown relics stay cooldown-only. C3 is a side effect behind the ball, not a change to the dash. |
| Lunar Heresy curses (a slot removed or health traded for a verb) | Overpowered pays: a strong build is never punished. A swap relic adds a verb and takes none away. |
| Hades duo-boon gating by a hidden pair list | The one set rule a player learns is "parts of one maker" (synergies.gd header, pass D fold 2). A hidden pair list is what that fold removed. Evolutions stay visible pairs on the part card. |
| Randomly rolled mutations on abilities (Isaac chaos) | Item names, rules and tells are authored, one row each, so the player can learn and a tell can be drawn. The generator's rows stay stat folds. |
| Recursive procs (a proc that can proc) | The unbounded frame cost Risk of Rain's chain mask exists to stop. Depth 1 only (section 8). |
| Raising `MAX_LIVE`, `MAX_VOLLEY` or `MAX_ARMS` to fit a new pattern | Principle 4: stacking may multiply damage but never the number of things on screen. A new silhouette fits under the existing caps or does not ship. |
| A toast or caption when a bit is dropped, or a sentence on each tell | LEGIBILITY S6 and W3. The struck chip, the bit colour and the sound carry it. |
| Enabling all five bits in one unit | One balance blast with no attribution. Section 6 B4 turns them on in a mask, one pair at a time. |
| Pearl or gold versions of any of this | Ruling bn: cobalt is the top ordinary rung for the alpha. |
| Kit swaps for Sable, Rivet and Kest in this wave | They already have one World 1 swap each. A second pass can follow when the first three land and play. |
| A new bit (a sixth) | A new bit is a table row, a pair row against every other bit (five more rows) and a code change in combat. Not needed to do any of the above. |

### Open calls and assumptions Andrew can overturn

1. **Ultimate stays tree-owned, relic slots stay weapon, movement, special, smash and line.** Overturn only by ruling that a relic may own an ultimate swap, which needs a SUFFIX entry and a validate change.
2. **Two kit-swap relics per pilot, in weapon, smash and line.** Not movement or special, so they pair with the cooldown relics instead of replacing them.
3. **Evolved rows pass `"bits"` through to `PartDef`.** Expected, proved by the first test of the evolution unit. If not, the unit adds the key to the Evolved path.
4. **Bits are for bolt weapons only (Sable, Rivet, Tarn's claw) in this wave.** The cannon lane, the sticky charge and Tally's cards ignore bits. A later pass can map a bit to a lane or a charge (pierce to a lane that does not stop at the first machine, for example).
5. **Rarity mapping.** `uncommon` is the green kit and `rare` is cobalt, from the ladder row and the catalogue tags in [parts.gd](../src/build/parts.gd). The first item unit confirms the mapping in the rung table before it writes a row.
6. **Six F-key Actives (`active_defs.gd`) stay separate from kit-special mutations.** Second Bell hooks the gauge release (`combat.gd:1899-1915`) and `_land_tap` for `SPECIAL` (`combat.gd:1970-1982`) — so F-key Actives, ultimates, Crater Slam and plant discharge never trigger it — and `halo` applies to weapons unless an active opts in. Andrew can overturn if he wants Second Bell to echo F-key actives too.
7. **W45-C seam alignment.** [HEFT-DESTRUCTIBLES.md](HEFT-DESTRUCTIBLES.md) defines `Destructibles.on_blast(at, radius, source, tier_bonus)` and caps `tier_bonus` at `+1` with no stacking. Faultline Cap and Fault Hammer both call `on_blast(..., 1)` (corridor reach and delayed aftershock) rather than stacking to `+2`.
8. **All numbers are (start):** 0.4 s drag, 0.25 s return at 0.6, 3 s book, 9 m link jump, 2 s and 6 m walk, x6 fuse cap, 18 degree split (8 deg with Grapeshot Press), 2 s heat and 15%, 4 m wake strip, 8 m crack, 1 s bell at half, 0.45 s Fault Hammer aftershock.
9. **C6 against `echo_release`.** Keep Second Bell as its own deterministic row, or fold its rule into `echo_release` as a second mode. The page prefers the separate row (a drawn, learnable repeat) and flags the overlap.
10. **Held-order drop.** Kept as is. Reordering by power is rejected here and could return if the readout shows players losing a bit they wanted.

## 10. Implementation split and verification

Every unit is one thread, one writer, one pull request, with focused tests, `npm run sketch:fast -- --base <stage>` and one independent review (AGENTS rule 4). Units name the only files they may write. The Gate stacks them in order.

| Unit | Size | What | Permitted files |
| --- | --- | --- | --- |
| U1 shot-bit plumbing, pierce and heat | M | `Build.shot_bits()`, `"bolts"` row key, `bits` on the `_fire` record (`source == "weapon"` only), the live mask knob, pierce and heat on `Bolts`, the dropped-bit chip in the build readout | `src/build/build.gd`, `src/build/shot_bits.gd` (no semantic change, only a live-mask read), `src/combat/combat.gd`, `src/combat/bolts.gd`, `src/core/ability_state.gd` (the `bolts` key), the readout under `src/ui/`, `tests/shot_bits_live_test.gd` (new) |
| U2 bounce, pull, split | M | the remaining three bits, `spent` on the record (`pierce+split` inherits `spent` minus `pierce`), priority colour + width scale tell in `bolts.gd`, the pair-row gates | `src/combat/bolts.gd`, `src/combat/combat.gd`, `tests/shot_bits_live_test.gd` |
| U3 Tarn relics | S | Gutter Heart, Rake Heart, `rend_drag`, `claw_rake`, `active_weapon()` `pattern` lookup, `class_kit.gd` `WORDS` | `src/build/relics.gd` (Tarn block), `src/core/ability_state.gd` (Tarn block), `src/ui/class_kit.gd` (`WORDS`), ball smash table, `src/combat/combat.gd` (`active_weapon` + claw branch), relic tests |
| U4 Tally relics | S | Ink Heart, Double Entry, `stamp_ink`, `link_double`, widen `link_clips` id checks (`combat.gd:446,2810,2990`, `audio.gd:5078`), `class_kit.gd` `WORDS` | `src/build/relics.gd` (Tally block), `src/core/ability_state.gd` (Tally block), `src/ui/class_kit.gd` (`WORDS`), ball smash table, `src/combat/combat.gd`, `src/presentation/audio.gd` (line 5078), relic tests |
| U5 Cannon relics | S | Walking Lane (`pattern: cannon_lane`), Rush Wake, `cannon_lane_walk`, `cannon_rush_wake`, `class_kit.gd` `WORDS` | `src/build/relics.gd` (Cannon block), `src/core/ability_state.gd` (Cannon block), `src/ui/class_kit.gd` (`WORDS`), ball smash table, `src/combat/combat.gd` (cannon branch), relic tests |
| U6 weapon items | M | Slag Pike (`pike_fuse`) and Halo Rig (`halo`) | `src/build/items.gd`, `src/build/item_effects.gd`, `src/combat/pattern.gd`, `src/combat/combat.gd`, tests |
| U7 verb items | M | Backwash, Barbed Reel, Faultline Cap (`Destructibles.on_blast`), Second Bell (`second_bell` at gauge release `:1899-1915` and `_land_tap` `SPECIAL` `:1970-1982`), Long Leash | `src/build/items.gd`, `src/build/item_effects.gd`, `src/combat/combat.gd`, the ball's dash and smash seams, tests. Serial after U6 (same two files). |
| U8 evolutions | S-M | Grapeshot Press (tight forward knockback cone), Hoar Barrel (ice-slab pierce shatter + frost patch), Fault Hammer (delayed seismic ring + `on_blast`) | `src/build/synergies.gd`, `src/build/parts.gd` (`EVOLVED` rows), `src/combat/combat.gd`, `src/combat/bolts.gd`, `src/build/element_field.gd`, `tests/evolution_test.gd`, `tests/build_synergy_test.gd` |

U3, U4 and U5 share `relics.gd`, `ability_state.gd` and `class_kit.gd` but edit separate pilot blocks, so they can be written in parallel and stacked one after another (with U3 landing `active_weapon()` `pattern` resolution before U5). U1 comes before U2 and U6; U2 (with `split` in `shot_bits_live`) comes before U8 because Grapeshot Press rewrites the split cone. U8's Fault Hammer calls `Destructibles.on_blast(..., 1)` when W45-C is present (no-op otherwise).

### Tests, each with a planted failing control

| Check | Proves | Planted failure |
| --- | --- | --- |
| `relics_data_test`, `relics_per_world_test`, `relics_run_test` | the six new rows pass `Relics.validate()` (name at most 3 words, text at most 8, one pilot, icon suffix, `world: 1`), World 1 has 9 swaps, `claw_rake` and `cannon_lane_walk` fire via resolved `pattern`, each new row has a `class_kit.gd` `WORDS` entry | a relic with `slot: "ultimate"` is refused; a text of 9 words is refused; a weapon swap without `pattern` resolution fails to fire |
| `shot_bits_live_test` (new) | `Build.shot_bits()` equals `ShotBits.shot()` over the held masks; a `source == "weapon"` bolt carries it; a child copies it; `item_proc` (including tree `volley` / Kick Shot) carries 0; a `bolts: false` weapon gets 0 | a build holding four bits must report exactly one dropped bit, in held order; a planted `bolts.fire` that omits `bits` fails the carry check |
| the same test, per bit | pierce passes one machine, bounce reflects once, split makes exactly two children and a child never splits (while keeping pierce via `spent` minus `pierce`), pull moves a lighter machine (`Grip.heft_of`) and not a heavier one, heat adds 15% on the second hit only | a planted split that re-splits fails the 3-bolt family bound; a planted pierce that never spends fails the second-machine stop |
| `shot_bits_test` (existing) | the closed set, the table and the 10 pairs stay intact, no `==` on a set | the existing planted rows stay as controls |
| anti-loop tests in each unit | proc depth 1 across all eight follow-up strikes (Rake Heart return pass, Backwash wake ripple, Barbed Reel chain, Second Bell repeat — ringing once per pilot including Tally's `gather_plate` while excluding F-key actives, ultimates, Crater Slam and plant discharge — Faultline Cap crack, Fault Hammer aftershock ring, Rush Wake trailing lane, and Hoar Barrel shard cone each fire once as `item_proc` with `bits = 0` and never re-trigger) | a planted repeat that sets its own source to `weapon` loops and is caught by the one-per-cause counter; an F-key active or ultimate triggering Second Bell fails; a pilot whose kit special fails to ring Second Bell once (including Tally's `gather_plate`) fails |
| `evolution_test`, `build_synergy_test` | the three new pairs: both ingredients grant the evolved part once, one ingredient gives nothing, and each evolution changes its verb (Grapeshot cone+knockback, Hoar ice-slab pierce shatter, Fault Hammer delayed ring) | an evolution sharing an ingredient with another is refused; an evolved row with an unknown ingredient is refused |
| `offer_weights_test` | no offer weight changes for any existing part, new rows enter at the stated rarity, evolved weight stays 0 | a planted `rare` row at the weight of a common fails |
| `npm run sketch:lint` | the player strings of every new relic, item and tooltip pass W1, W2, W4, W6, W7 and S8 | a planted "unleash" line is caught by the W1 check |
| reviewer pass (LEGIBILITY section 13 by code) | S1 to S8 and W3, W5, W8 and W9 on every new string, carrier order held (shape, colour, icon, motion, sound before a word), one name per thing in [NAMES.md](NAMES.md) | n/a |

### Before and after still shots

Saved under `artifacts/local/` with the method named (scrapkeep-verify-game: source run, real keys, game version). Automated play does not establish feel (AGENTS rule 12).

- Pierce, heat and a multi-bit scaled bolt in flight, before (default bolt) and after.
- The build readout with a struck-through dropped bit.
- Slag Pike: volley five's copper muzzle ring, volley six's fused bolt.
- Gutter Heart: the disc at landing and 0.4 s after, a lighter machine at the centre and a heavier one in place.
- Rake Heart: the sweep and the mirrored return.
- Walking Lane: two chained lane footprints, and Rush Wake's laid lane, each with its committed footprint drawn before it strikes.
- The matrix's one worst case on screen: cross split, halo, three bits and a fused volley together, with the live bolt count read from `Bolts.peak_live` to prove the 64 cap holds.

Lab evidence (the world 1 bands, the median build re-cut) goes through the lab skill, one batch per enabled bit, and each unit's receipt names the model and effort that ran it.

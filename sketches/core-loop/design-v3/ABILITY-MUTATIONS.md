# Ability mutations: kit swaps, live shot bits and items that rewrite a verb

Status: design proposal for wave 45 unit W45-B2, written 21 Nov 2026 against `stage/alpha-w45` at `fc8507686`. Nothing here changes code. Numbers marked (start) are starting values until the lab ranks them. The follow-on code is split into units in section 9, each with its permitted files.

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
| An ability row is data: the rest of the game dispatches on a row's capabilities, never its id, so a variant is one row plus, when it plays differently, one entry in the owning dispatch table (combat's `_specials`, the ball's `SMASHES`). A row's `pattern` key lets a swapped weapon keep another weapon's pattern (`sticky_rain` uses `sticky_charge`'s). | [ability_state.gd:98-121](../src/core/ability_state.gd), [:136](../src/core/ability_state.gd) |
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
| `Pattern.TRANSFORMERS` is eight data rows: `cross_split`, `spiral_wave`, `chain_arc`, `damage_tier`, `rate_tier`, `range_tier`, `capacitor`, `overclock`. Caps are applied last: `MAX_VOLLEY := 16`, `MAX_ARMS := 8`, `MAX_ARM_OFFSET := 14`. `fan_spread` and `helix_drill` are pattern levels on items, not rows of this table. | [pattern.gd:19-27](../src/combat/pattern.gd), [:58-91](../src/combat/pattern.gd), [:137-142](../src/combat/pattern.gd), [items.gd:78-86](../src/build/items.gd) |
| `Synergies.EVOLUTIONS` has **4 pairs**: `breaker_drive` (`double_feed` + `hot_rivets`), `bladestorm_rotor` (`spiral_wave` + `loose_trigger`), `storm_mast` (`focus_lens` + `live_line`), `grounding_spike` (`arc_coil` + `drop_weight`). Evolved rows are all stat folds (punch, damage, fire rate, a spiral level). None changes what a verb does. | [synergies.gd:126-138](../src/build/synergies.gd), [parts.gd:386-398](../src/build/parts.gd) |
| 14 maker tricks, two distinct pieces of one maker wake one: `ballast_rig`, `shatter_crew`, `wrecking_ball`, `glacier_hull`, `shrapnel_bloom`, `storm_lattice`, `tesla_pylon`, `live_wire`, `pinwheel`, `hair_trigger`, `storm_front`, `thermal_shock`, `linked_spiral`, `lightning_rod`. | [synergies.gd:36-123](../src/build/synergies.gd) |
| Strikes that come from an item rather than the player's weapon carry the source `item_proc`, and seams treat them differently. This is the one tag a proc-chain guard can hang on. | [combat.gd:149-153](../src/combat/combat.gd), [:1231-1236](../src/combat/combat.gd), [:1792](../src/combat/combat.gd) |

The gap in one line: the slot machinery, the bit table and the evolution table all exist, and together they change no verb in World 1 for three of the six pilots.

"The six Actives" in the request is read here as the six ability slots (weapon, movement, special, smash, line, ultimate). See section 9, call 6.

## 3. What other games do, and what we take

Research first (ruling, 23 Oct): reference what other games actually do, give the reasoning and the rejected options.

### The Binding of Isaac: Rebirth

- **What it does.** Tears carry independent flags (piercing, spectral, homing, bouncing, splitting, status effects) that stack freely, and a few items replace the weapon outright: Brimstone turns tears into a charged beam, Tech X into a charged ring, Mom's Knife into a thrown blade. When two replacers meet, a small hand-authored table decides the result rather than a general rule. Difficulty follows the player (the item pool scales the rooms) so a runaway build is the point, not the bug.
- **Why it works.** Flags are orthogonal, so a player learns each once and every combination is free to read. Replacers change the silhouette of the verb, so the player sees which kind of run they are in within a second.
- **What we twist.** Scrapkeep already took half of this: five bits, a cap of three, a ten-row pair table ([shot_bits.gd:1-18](../src/build/shot_bits.gd) cites the comps note and refuses the unbounded stack). The Isaac stack has no cap and the screen fills. We keep the cap. For replacers we reject the hold-to-charge beam, because holding still is the one thing a rolling ball never does (rulings cu, cast times: a long cast is a card). Our replacer fires on a cadence while the ball keeps its speed: every sixth volley fuses (section 6, C1).

### Risk of Rain 2

- **What it does.** Each survivor owns four skill slots and alternate skills swap one slot for another verb. The Lunar Heresy items replace a slot with a fixed alternate. Items proc on hit with a proc coefficient per skill, and a proc-chain mask stops a proc from triggering the same class of proc again, which is what keeps stacked on-hit items from detonating the frame budget.
- **Why it works.** A swap is one slot, one pilot, one visible new verb, and the alternates are authored, never rolled. The chain mask is a bound written into the data, not a hope.
- **What we twist.** The relic rung is already our Heresy: one relic per slot, per pilot, `swap` to another row ([relics.gd:1-12](../src/build/relics.gd)). We keep the shape and fill it for the three pilots that only got cooldown scalars. We copy the chain mask in the form we already have: the `item_proc` source tag (section 7). We refuse the Lunar curse. A relic never removes a slot or costs health, because Overpowered pays (ruling, 17 Oct): strong builds are never punished.

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
| Gutter Heart | waking | Tarn, smash | `rend_slam` to `rend_drag` (`ab_tarn_smash`) | Rend slams drag bodies into the crater | The landing keeps the rend disc and damage. Bodies inside whose heft class is at or below the pilot's slide to the centre over 0.4 s (one inward knock; no ball motion). Heavier bodies take the hit and hold. This is the pole rule of POLES-FLAILS section 3 turned on the slam: weigh more and it comes to you, weigh less and you come to it. |
| Rake Heart | redjaw | Tarn, weapon | `claw_sweep` to `claw_rake` (`ab_tarn_weapon`, `pattern: claw_sweep`) | Each sweep rakes again on return | The sweep fires, then the same arc returns 0.25 s later at 0.6 damage, drawn mirrored. It keeps the `claw_sweep` pattern, so every Tarn tree node and transformer on the claw applies unchanged. |
| Ink Heart | mind_glass | Tally, smash | `stamp_slam` to `stamp_ink` (`ab_tally_smash`) | Stamped bodies refund pressure when settled | The stamp books every body in its disc for 3 s, drawn as a ledger tick on each. A card that settles a booked body refunds 1 pressure, once per body per stamp. Pressure still caps at its bank (3), so no loop. |
| Double Entry | fleet_surplus | Tally, line | `link_clips` to `link_double` (`ab_tally_line`) | Clips settle a second body | A cast that clips a body also clips the nearest other body within 6 m, a shorter link drawn from the first to the second. Both settle together. One extra link, never a chain. |
| Walking Lane | mind_glass | Cannon, weapon | `cannon_lane` to `cannon_lane_walk` (`ab_cannon_weapon`, `family: lane`) | Second call walks the lane further out | A lane called within 2 s of the last starts where the last ended, up to 6 m further along the aim, and a third does not extend: the walk resets after two links. Each lane is its own committed hazard through `_commit_cannon`. |
| Rush Wake | waking | Cannon, smash | `cannon_rush` to `cannon_rush_wake` (`ab_cannon_smash`, `family: rush`) | Rush landings leave a lane behind | On landing, a committed lane is laid back along the rush's travel line at half lane damage, with the lane's own telegraph delay. It never re-lays on its own strike. |

Notes on the table:

- **Names and voice.** "Heart" is the existing relic noun (`crater_heart`, `muzzle_heart`, `rain_heart`) and the three hearts here match it. "Double Entry", "Ink", "Walking" and "Wake" are bookkeeping and workshop words the Tally and Mind voice already uses (the ledger, the audit). Each name is at most three words and the text counts are 7, 6, 6, 5, 7 and 6.
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
- **Which volleys.** `Combat._fire` adds `"bits": ctx.build.shot_bits()` to its bolt record when `source == "weapon"`. A volley from a free-shot proc fired through the same function (a tree `volley`, the cannon's Kick Shot) is the weapon's own shot and carries the bits. A strike marked `item_proc` carries none, because `Bolts.fire` already defaults an absent key to 0.
- **Children.** `Bolts.child()` already copies the set. The new rule on top of it is the consumed set: a record carries `spent`, the bits already used up (split on its first hit, pull on its first hit, bounce on its first wall). A child inherits the set and `spent` together, so a split child never splits again and a bounced bolt never bounces twice.

### B2. Priority and the drop rule

The cap rule is unchanged: `ShotBits.shot()` keeps the earliest held part's bits and drops the rest, in held order, past `MAX_SHOT_BITS := 3` ([shot_bits.gd:108-122](../src/build/shot_bits.gd)). This spec keeps it and does not reorder by power, for two reasons. The earliest part is the one the player has had longest, so the rule is learnable without a screen. And re-ranking by power would make a late pickup silently swap a bit the player was relying on. What the player does get is a way to see it: the build readout draws each dropped bit as its chip struck through (carrier: shape and icon, no sentence), read from `dropped`. No toast and no "dropped" word (S6, W3).

### B3. Tells and the pair table

One row per bit already holds colour, sound and rule, and `ShotBits.tells(mask)` reads all three ([shot_bits.gd:29-40](../src/build/shot_bits.gd), [:126-131](../src/build/shot_bits.gd)). Live play reads that row and nothing else, so sight and sound cannot drift.

| Bit | Colour | Sound | Live rule on a bolt | Pair rows it joins |
| --- | --- | --- | --- | --- |
| pierce | `LEDGER` | `breach_crack` | The first body hit takes the strike and the bolt keeps flying, once. `spent` gains pierce, so a second body stops it. | pierce+bounce, +split, +pull, +heat |
| bounce | `ARC` | `shell_spring` | The first wall hit reflects the bolt about the surface normal with its remaining range, once. | bounce+pierce, +split, +pull, +heat |
| split | `BRASS` | `scrap_rip` | The first body hit spawns two children at +/- 18 degrees (start) with half damage each, through `Bolts.child()`. | split+pierce, +bounce, +pull, +heat |
| pull | `SLATE` | `line_zip` | The first body hit takes one inward knock toward the shooter, scaled by the pilot's heft class against the body's (heavier comes, lighter holds). | pull+pierce, +bounce, +split, +heat |
| heat | `COPPER` | `wear_sputter` | The body glows for 2 s (start). A second heated hit on a glowing body adds 15% damage (start), once per body per 2 s. | heat+pierce, +bounce, +split, +pull |

The tell on the bolt is its tint. A bolt with one bit takes that bit's colour; with two or three it alternates the colours along its streak in `TABLE` order, one band per bit, so a three-bit bolt reads as three bands and never a new colour. This stays inside the bolt colour rules (`Bolts.PRIORITY`, never `HAZARD`). Each bit's sound plays on its event (the pierce on the passed body, the spring on the bounce, the rip on the split, the zip on the pull, the sputter on the second heated hit), and a bolt with three bits plays at most one bit sound per hit so audio does not stack.

The 10 `PAIRS` rows stay as written. The ones that need code attention because they gate on an event type are: `bounce+pull` (a wall glance pulls nothing), `bounce+heat` (a wall glance heats nothing), `split+pull` (only the first hit pulls, children do not) and `pierce+split` (children keep piercing, so children inherit `spent` minus split).

### B4. Rollout, because this is a balance event

Switching the bits on changes every build at once. The shot-bit test already shows at least 30% of random six-part builds reach three bits, and parts that tag `kinetic`, `mass`, `chain`, `split`, `anchor` or `arc` carry one or two. A single switch would make nearly every run pierce and bounce overnight.

- **Live mask knob.** One tuning knob, `shot_bits_live`, a mask of the bits the game honours. Start with pierce and heat (no new bolts, no new queries). Bounce, then pull, then split follow in later units.
- **Ruling cu pairing.** Anything that eases play ships with a matching pressure, measured together (ruling cu). Pierce clears packs faster, so the pierce unit lands with its pressure measured in the same lab batch (the world 1 bands, `scripts/world1-bands.test.mjs`), not "later".
- **Re-baseline.** Difficulty is set from the median build (item ladder row), so the median build moves when the bits go live. The unit that enables a bit re-cuts the median reference and says so in its receipt.

## 7. C. Gameplay and ability-mutating items

Seven new items and one new pattern transformer. They touch a verb each, by name, as the cobalt rung should. Rarities map the ladder rows in DECISIONS: `uncommon` is a green field kit (a verb tweak) and `rare` is cobalt (changes a verb's look and play). `world` is 1 and up; none is pilot-locked unless it says so.

| Item | Maker | Rarity | Verb it touches | Rule (start) | What the player sees |
| --- | --- | --- | --- | --- | --- |
| Slag Lance (C1) | fleet_surplus | rare | weapon, bolt pilots | Every sixth volley fuses into one bolt: damage is the sum of the volley's bolts capped at x6, `pierce` set, range x1.25, radius matched to its drawn width. The counter resets on fusing and on 3 s without firing. A fused volley fires as `weapon` source, so it takes the bits the pilot holds. | Volley five lights the muzzle ring copper, volley six is one bright thick bolt in the pierce colour. Sound is `breach_crack`. |
| Halo Rig (C2) | highdraft_roosts | uncommon | weapon pattern | New transformer `halo`: `add arms 5`, `min arm_offset_deg 10`, `mul damage 0.55`, `mul rate 0.85`. Caps apply last, so with `cross_split` (arms +3) the volley clamps at `MAX_ARMS := 8` and `MAX_VOLLEY := 16`, outermost bolts trimmed first. | A ring of bolts around the aim line instead of a fan. It is a silhouette change, which is what Tech X does for Isaac. |
| Backwash (C3) | spillway_works | uncommon | movement (side effect only) | A dash or boost lays a ripple strip 4 m long behind the ball's path (committed footprint, damage 0.4 of a weapon hit, one strike per body per dash). Dash distance, speed and cooldown are untouched. | A flat strip in the pilot's colour trails the dash. It pays the kite: enemies chasing the ball cross it. |
| Barbed Reel (C4) | redjaw | rare | grapple, reel-in impacts | A reel-in impact (the `harpoon_smashed` event) also hits the nearest other body within 6 m once at 0.7 damage through `_chain`, with `chain_jumps` 1. The jump cannot re-trigger the item. | A short arc from the struck body to the next, in the pilot's colour. |
| Faultline Cap (C5) | waking | rare | smash | A smash landing cracks a line 8 m ahead along the dash heading: a committed lane at 0.5 smash damage. Slams and the crack count one heft tier higher against destructibles (see the C5 note). | A drawn line leaves the crater, the ground cracks along it. |
| Second Bell (C6) | mind_glass | uncommon | special | A special's pulse repeats once, 1 s later, at half strength, drawn at commit so both footprints show. The repeat spends nothing, refunds nothing, and cannot repeat. | The first footprint stays lit and a second pulse rings from it. |
| Long Leash (C7) | moss | uncommon | line skill | A line skill's `load_seconds` doubles (start 4 s to 8 s). The bite, cooldown and damage are unchanged. | The loaded line stays drawn twice as long. |

Notes on the table:

- **C1 versus Brimstone.** The Isaac verb is a charge you hold. Ours is a cadence you roll through, and it reads in the muzzle ring before the lance, so the player can aim the fused bolt. The sum cap is what keeps `cross_split` and a spiral from turning one fused bolt into a screen wipe.
- **C2 as data.** `halo` is a row in `Pattern.TRANSFORMERS`, so it composes with every other row by the existing add, mul, min order and the existing clamp. That is the cheapest way to change a silhouette.
- **C3 and ruling cu.** A strip behind the ball punishes nothing and costs the pilot nothing. It rewards the chased, which matches "hardness presses a ball that slows or stops, never one that keeps rolling and turning".
- **C4 and the weight rule.** The jump uses the lighter-comes rule only through the existing `_chain` hit, not a new pull. POLES-FLAILS owns the weight rule and this item only adds a second strike.
- **C5 and W45-C.** W45-C scales destructibles by heft (a slam or a blast is a heft tier). This item adds one integer, `slam_tier_bonus`, folded in the build sheet and read at the single call where a slam or blast hands its tier to a destructible. If W45-C has not landed when a unit runs, the read returns 0 and the item still works as the crack line.
- **C6 versus `echo_release`.** `item_effects.gd` already has `echo_release` as a chance effect. Second Bell is deterministic, always half strength and always drawn. Whether to fold it into `echo_release` is open (section 9, call 9).
- **Ultimate.** No item touches the ultimate. It stays a tree choice.
- **New effects are closed-table rows.** Each rule is one id in the `EFFECTS` table of [item_effects.gd:24-32](../src/build/item_effects.gd) (`lance_fuse`, `dash_wake`, `reel_chain`, `slam_crack`, `special_echo`, `line_leash`) plus the one call site in its owning module. No script, no hook list.

### D. New evolutions (3 pairs, onto the under-served makers)

The four evolutions today serve Fleet Surplus (`breaker_drive`), Highdraft Roosts (`bladestorm_rotor`), Mind-glass (`storm_mast`) and Moss (`grounding_spike`). Spillway Works, Redjaw and Waking each have tricks and no evolution. These three close that and are the first evolved parts that change a verb rather than fold a number. Each follows the existing shape: an `EVOLUTIONS` pair, an `EVOLVED_FROM` trick, and an `EVOLVED` row that gives nothing while an ingredient is missing.

| Evolved | Pair | Grew out of | Maker | Rule |
| --- | --- | --- | --- | --- |
| Grapeshot Press | `cross_split` + `pin_setter` | `shrapnel_bloom` | redjaw | Explicit `"bits": ["pierce", "split"]`. Each cross arm pierces its first body and splits there once, and the children keep piercing (the `pierce+split` pair row). |
| Hoar Barrel | `frost_barb` + `rime_rounds` | `shatter_crew` | spillway_works | Explicit `"bits": ["pierce"]`. A bolt that pierces a frozen body shatters it, using the shatter dial the trick already sets. |
| Fault Hammer | `echo_locator` + `ring_wave` | `thermal_shock` | waking | A slam landing sends a second ring one beat later (source `item_proc`, so it cannot echo again) and counts one heft tier higher against destructibles. |

Notes:

- The pairs share no ingredient with an existing evolution, so no part sits in two. The ingredient parts exist today (redjaw and waking and spillway lists in [parts.gd](../src/build/parts.gd) and [items.gd](../src/build/items.gd)) and each unit's first test confirms each is obtainable in World 1.
- Evolved rows are outside the offer pool and have roll weight 0 ([parts.gd:381-385](../src/build/parts.gd)), so `offer_weights_test` is unaffected except by the ingredient parts' own existing weights.
- That an `EVOLVED` row passes `"bits"` through `PartDef.from_row` is expected from [parts.gd:484-485](../src/build/parts.gd) and [part_def.gd:173](../src/build/part_def.gd) and is proved by the unit's first test (section 9, call 3).

## 8. Interaction matrix and bounds

### Matrix

`yes` means the two compose by the rule in the cell, `cap` means a named bound applies, `no` means they do not interact.

| New mutation | `cross_split` / `spiral_wave` | `chain_arc` | `fan_spread` / `helix_drill` | Six slots | Maker tricks | Shot bits | W45-C heft |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Slag Lance (C1) | cap: the sum cap x6 holds a 9-bolt cross to one lance | no: chain is a hit rule on the fused bolt, unchanged | cap: the pattern's bolts fuse first | weapon | `shrapnel_bloom`, `storm_lattice` fire on the lance's kills | the lance carries the held bits, pierce is always set | no |
| Halo Rig (C2) | cap: `MAX_ARMS` 8, `MAX_VOLLEY` 16 | yes: each ring bolt can chain | yes: it is another pattern level | weapon | `pinwheel` ring stays separate (its own blades) | yes | no |
| Backwash (C3) | no | no | no | movement | `ballast_rig`, `hair_trigger` dash elements apply to the dash, the strip adds no element | no | no |
| Barbed Reel (C4) | no | yes: it is one chained hit | no | line, movement (reel is the grapple) | `tesla_pylon` arcs while hooked: both fire, neither triggers the other | no | no |
| Faultline Cap (C5) | no | no | no | smash | `storm_front`, `thermal_shock`, `live_wire` slam elements apply to the crater and the crack | no | yes: +1 tier on slam and crack |
| Second Bell (C6) | no | no | no | special, jammed with the special | `live_wire` element applies to the repeat once | no | yes: a blast special counts its tier |
| Long Leash (C7) | no | no | no | line | none | no | no |
| Gutter Heart | no | no | no | smash | `glacier_hull` landings ring cold on the drag | no | no |
| Rake Heart | yes: a cross sweep returns as a cross | yes | yes | weapon | `shrapnel_bloom` on kills in either pass | yes: the return pass carries the bits | no |
| Ink Heart, Double Entry | no | no | no | smash, line | `mind_glass` pieces count for `tesla_pylon` and `live_wire` | no | no |
| Walking Lane, Rush Wake | no | no | no | weapon, smash | `mind_glass` pieces count as above | no (the lane fires no bolts, section 6 B1) | no |
| Grapeshot Press | yes: arms pierce and split | yes | yes | weapon | `shrapnel_bloom` is its source | yes (explicit) | no |
| Hoar Barrel | no | no | no | weapon | `shatter_crew` is its source | yes (explicit pierce) | no |
| Fault Hammer | no | no | no | smash | `thermal_shock` is its source | no | yes |

### Anti-loop bounds

These are the bounds each unit's tests must prove, with a planted failing control each (section 10).

1. **Proc depth is 1.** A strike whose source is `item_proc` or a mutation (the lance, the return pass, the wake ripple, the reel chain, the second bell pulse, the fault ring, the wake lane) never starts another mutation or an item proc. This is the same shape as Risk of Rain's proc-chain mask, built on the `item_proc` tag that already exists ([combat.gd:149-153](../src/combat/combat.gd)).
2. **Every repeat is single.** The return sweep, the second bell pulse, the walking lane link, the reel chain jump and the fault ring each happen once per cause. None re-arms itself and none refunds its own cost.
3. **Bolt count is bounded by data.** A split child consumes `split` through `spent`, so the family tree of one bolt is at most 3 bolts. `Bolts.MAX_LIVE := 64` retires the oldest past the cap ([bolts.gd:18](../src/combat/bolts.gd), [:92-96](../src/combat/bolts.gd)), `Pattern.MAX_VOLLEY := 16` trims the volley, and `MAX_ARMS := 8` trims the arms.
4. **No movement lockout.** No mutation changes velocity, brakes the ball, adds `plant`, or adds a cast. Pulls move enemies. The jam still shuts only `SILENCED` slots and never the ball ([ability_state.gd:84-91](../src/core/ability_state.gd)).
5. **No visual drift.** Every area is committed first and drawn from the same record it hits with, at `FORGIVENESS := 0.18`. A mutation that cannot be drawn does not ship.
6. **Pressure per heavy event.** Pull is per body per bolt and limited to the first hit; a pierce-pull bolt pulls each pierced body once and the first hardest (the pair row), which is `O(bodies)` per bolt and not a loop.
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
| A toast or caption when a bit is dropped, or a sentence on each tell | LEGIBILITY S6 and W3. The struck chip, the band colours and the sound carry it. |
| Enabling all five bits in one unit | One balance blast with no attribution. Section 6 B4 turns them on in a mask, one pair at a time. |
| Pearl or gold versions of any of this | Ruling bn: cobalt is the top ordinary rung for the alpha. |
| Kit swaps for Sable, Rivet and Kest in this wave | They already have one World 1 swap each. A second pass can follow when the first three land and play. |
| A new bit (a sixth) | A new bit is a table row, a pair row against every other bit (five more rows) and a code change in combat. Not needed to do any of the above. |

### Open calls and assumptions Andrew can overturn

1. **Ultimate stays tree-owned, relic slots stay weapon, movement, special, smash and line.** Overturn only by ruling that a relic may own an ultimate swap, which needs a SUFFIX entry and a validate change.
2. **Two kit-swap relics per pilot, in weapon, smash and line.** Not movement or special, so they pair with the cooldown relics instead of replacing them.
3. **Evolved rows pass `"bits"` through to `PartDef`.** Expected, proved by the first test of the evolution unit. If not, the unit adds the key to the Evolved path.
4. **Bits are for bolt weapons only (Sable, Rivet, Tarn's claw) in this wave.** The cannon lane, the sticky charge and Tally's cards ignore bits. A later pass can map a bit to a lane or a charge (pierce to a lane that does not stop at the first body, for example).
5. **Rarity mapping.** `uncommon` is the green kit and `rare` is cobalt, from the ladder row and the catalogue tags in [parts.gd](../src/build/parts.gd). The first item unit confirms the mapping in the rung table before it writes a row.
6. **"The six Actives" is read as the six ability slots.** If the request meant a different set, the matrix columns change and the rules do not.
7. **W45-C interface.** This page assumes one read where a slam or a blast gives a destructible its tier. If W45-C names the seam otherwise, C5 and Fault Hammer follow its name.
8. **All numbers are (start):** 0.4 s drag, 0.25 s return at 0.6, 3 s book, 6 m link, 2 s and 6 m walk, x6 fuse cap, 18 degree split, 2 s heat and 15%, 4 m wake strip, 8 m crack, 1 s bell at half.
9. **C6 against `echo_release`.** Keep Second Bell as its own deterministic row, or fold its rule into `echo_release` as a second mode. The page prefers the separate row (a drawn, learnable repeat) and flags the overlap.
10. **Held-order drop.** Kept as is. Reordering by power is rejected here and could return if the readout shows players losing a bit they wanted.

## 10. Implementation split and verification

Every unit is one thread, one writer, one pull request, with focused tests, `npm run sketch:fast -- --base <stage>` and one independent review (AGENTS rule 4). Units name the only files they may write. The Gate stacks them in order.

| Unit | Size | What | Permitted files |
| --- | --- | --- | --- |
| U1 shot-bit plumbing, pierce and heat | M | `Build.shot_bits()`, `"bolts"` row key, `bits` on the `_fire` record, the live mask knob, pierce and heat on `Bolts`, the dropped-bit chip in the build readout | `src/build/build.gd`, `src/build/shot_bits.gd` (no semantic change, only a live-mask read), `src/combat/combat.gd`, `src/combat/bolts.gd`, `src/core/ability_state.gd` (the `bolts` key), the readout under `src/ui/`, `tests/shot_bits_live_test.gd` (new) |
| U2 bounce, pull, split | M | the remaining three bits, `spent` on the record, band tint for two and three bits, the pair-row gates | `src/combat/bolts.gd`, `src/combat/combat.gd`, `src/presentation/` (the tint only), `tests/shot_bits_live_test.gd` |
| U3 Tarn relics | S | Gutter Heart, Rake Heart, `rend_drag`, `claw_rake` | `src/build/relics.gd` (two rows in the World 1 block), `src/core/ability_state.gd` (Tarn marked block), the ball smash table, `src/combat/combat.gd` (claw branch), relic tests |
| U4 Tally relics | S | Ink Heart, Double Entry, `stamp_ink`, `link_double` | same files, Tally blocks |
| U5 Cannon relics | S | Walking Lane, Rush Wake, `cannon_lane_walk`, `cannon_rush_wake` | same files, cannon blocks |
| U6 weapon items | M | Slag Lance (`lance_fuse`) and Halo Rig (`halo`) | `src/build/items.gd`, `src/build/item_effects.gd`, `src/combat/pattern.gd`, `src/combat/combat.gd`, tests |
| U7 verb items | M | Backwash, Barbed Reel, Faultline Cap, Second Bell, Long Leash | `src/build/items.gd`, `src/build/item_effects.gd`, `src/combat/combat.gd`, the ball's dash and smash seams, tests. Serial after U6 (same two files). |
| U8 evolutions | S | Grapeshot Press, Hoar Barrel, Fault Hammer | `src/build/synergies.gd`, `src/build/parts.gd` (the `EVOLVED` rows), `tests/evolution_test.gd`, `tests/build_synergy_test.gd` |

U3, U4 and U5 share `relics.gd` and `ability_state.gd` but edit separate blocks (each pilot already owns a marked block, [ability_state.gd:122-123](../src/core/ability_state.gd)), so they can be written in parallel and stacked one after another. U1 comes before U2 and U6 and before U8, which reads the bits. U8's Fault Hammer needs W45-C's tier read or the stub from call 7.

### Tests, each with a planted failing control

| Check | Proves | Planted failure |
| --- | --- | --- |
| `relics_data_test`, `relics_per_world_test`, `relics_run_test` | the six new rows pass `Relics.validate()` (name at most 3 words, text at most 8, one pilot, icon suffix, `world: 1`), World 1 has 9 swaps, each of Tarn, Tally and the cannon has a swap in each new slot | a relic with `slot: "ultimate"` is refused; a text of 9 words is refused; a swap row with an icon of the wrong suffix is refused |
| `shot_bits_live_test` (new) | `Build.shot_bits()` equals `ShotBits.shot()` over the held masks; a fired bolt carries it; a child copies it; an `item_proc` strike carries 0; a `bolts: false` weapon gets 0 | a build holding four bits must report exactly one dropped bit, in held order; a planted `bolts.fire` that omits `bits` fails the carry check |
| the same test, per bit | pierce passes one body, bounce reflects once, split makes exactly two children and a child never splits, pull moves a lighter body and not a heavier one, heat adds 15% on the second hit only | a planted split that re-splits fails the 3-bolt family bound; a planted pierce that never spends fails the second-body stop |
| `shot_bits_test` (existing) | the closed set, the table and the 10 pairs stay intact, no `==` on a set | the existing planted rows stay as controls |
| anti-loop tests in each unit | proc depth 1 (the return pass, the wake ripple, the reel chain, the bell repeat and the fault ring each fire once and never re-trigger) | a planted repeat that sets its own source to `weapon` loops and is caught by the one-per-cause counter |
| `evolution_test`, `build_synergy_test` | the three new pairs: both ingredients grant the evolved part once, one ingredient gives nothing, an `EVOLVED` row with a bit reaches `PartDef.bits` | an evolution sharing an ingredient with another is refused; an evolved row with an unknown ingredient is refused |
| `offer_weights_test` | no offer weight changes for any existing part, new rows enter at the stated rarity, evolved weight stays 0 | a planted `rare` row at the weight of a common fails |
| `npm run sketch:lint` | the player strings of every new relic, item and tooltip pass W1, W2, W4, W6, W7 and S8 | a planted "unleash" line is caught by the W1 check |
| reviewer pass (LEGIBILITY section 13 by code) | S1 to S8 and W3, W5, W8 and W9 on every new string, carrier order held (shape, colour, icon, motion, sound before a word), one name per thing in [NAMES.md](NAMES.md) | n/a |

### Before and after still shots

Saved under `artifacts/local/` with the method named (scrapkeep-verify-game: source run, real keys, game version). Automated play does not establish feel (AGENTS rule 12).

- Pierce, heat and a three-band bolt in flight, before (single tint) and after.
- The build readout with a struck-through dropped bit.
- Slag Lance: volley five's copper muzzle ring, volley six's fused bolt.
- Gutter Heart: the disc at landing and 0.4 s after, a light body at the centre and a heavy one in place.
- Rake Heart: the sweep and the mirrored return.
- Walking Lane: two chained lane footprints, and Rush Wake's laid lane, each with its committed footprint drawn before it strikes.
- The matrix's one worst case on screen: cross split, halo, three bits and a fused volley together, with the live bolt count read from `Bolts.peak_live` to prove the 64 cap holds.

Lab evidence (the world 1 bands, the median build re-cut) goes through the lab skill, one batch per enabled bit, and each unit's receipt names the model and effort that ran it.

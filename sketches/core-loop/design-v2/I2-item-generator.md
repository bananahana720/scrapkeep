# I2. A procedural item generator for core-loop v2

Extends the part system, not a new pipeline. Every generated item is a `PartDef`
Resource (`src/build/part_def.gd`) with a handful of new typed fields. It goes through
the same catalogue, offer pools, gates and synergy checks that `parts.gd` and
`synergies.gd` already run. Trigger resolution sits inside the ability pipeline TADR-008
already owns (P4 commit, P5 apply): a trigger is read at the commitment that already
exists (a shot's `AttackLedger` entry, a smash's contact resolution, a charge release),
never in a signal handler or a second pass.

## 1. Trigger vocabulary and proc rule

A closed enum, `Trigger.KIND` in a new `src/build/triggers.gd`:

`on_hit, on_kill, on_smash, on_rebound, on_vault, on_charge_release, on_cloak_break, on_land, on_speed_tier_up, on_pickup, on_damage_taken, timed`

`on_pickup` covers scrap pickup (`lightning_rod` already implies it: "every piece of
scrap you pick up sparks an arc"). `on_speed_tier_up` fires when planar speed crosses a
tuning threshold (RoR2-style tiers, distinct from the heft-class growth stinger). No
open enum: a ninth trigger is a code review, per TADR-003.

**Proc coefficient.** Each trigger source carries a `base_proc` in its commitment
context: 1.0 for discrete player-chosen actions (smash, rebound, vault, charge_release,
cloak_break, land — they already happened, so they always fire), and a per-weapon value
for `on_hit`/`on_kill` (0.5–1.0, mirrors RoR2's 0.6–1.0 range from R1, keyed on the
weapon, not the item). An item's `proc_coeff` (default 1.0) multiplies `base_proc`; the
roll is the commitment's single deterministic draw (TADR-009 line 138's rule extended to
items). `timed` items ignore proc and fire on an internal tick counter instead.

**Chain termination.** An effect resolved as a trigger's consumer may not post a trigger
of the *same kind* within the commitment still resolving. The encounter keeps a
`resolving: Dictionary[Trigger.KIND, bool]` scoped to one P4→P5 pass, set true on entry
and cleared at P6 publish (mirrors TADR-009's rule that an effect never re-enters the
pass that produced it). A second-order effect that must chain (Domino Wire, below) is a
bounded loop with an explicit `chain_depth` cap of 1, checked before the recursive proc
roll — never open recursion. Same shape as `Bolts.MAX_LIVE = 64`: a hard cap on a source
that could otherwise be unbounded.

## 2. The generator

`base × affix × element × trigger`, each a lookup, not a formula with hidden constants:

- **base** — the family archetype and its stat range, the same six families as today
  (`weapon, pattern, mobility, defense/stat, utility, charge`), writing into
  `part_def.gd`'s existing `punch`/`mods`/`patterns`/`magnet` fields. Nothing new is
  added to `build_sheet.gd`.
- **affix** — the existing tier scaling, unchanged: tier 1 (common) +10–15%, tier 2
  (uncommon) +25%, tier 3 (rare) +50%, rare_plus bespoke. A generated item's `tier`
  sets its affix band exactly as `parts.gd`'s hand-authored rows do. Percentage stats
  (crush threshold, plating chip, cooldown) use the affix as a hyperbolic input, never a
  raw add past a cap.
- **element** — `TADR-009`'s three elements (`frost, arc, kinetic`) plus `"none"`. A
  fourth element (heat, for lava) is an open Bible question — flagged, not built here.
- **trigger** — one `Trigger.KIND`, its `proc_coeff`, and a `stack_rule` (below).

**Rarity weights**, reused from the existing `SOURCE_RARITIES`/`gate_rarities` bands:
common 60, uncommon 27, rare 10, rare_plus 3 (RoR2's ~75/20/4/1, widened so uncommon
offers stay present at low bonus-core counts). Weights decrement per stage pool as
items are drawn, so a run doesn't see triplicate commons (R1 rule 1).

**Stacking curves**, one of three, declared per item as `stack_rule`:
- `linear` — flat adds or multiplies per copy (punch, mods, magnet). What `parts.gd`
  already does.
- `hyperbolic` — `f(x) = 1 - 1/(1 + a*x)` for anything that could hit 100% (crush
  threshold, chip resistance, cooldown reduction). Never reaches the wall (R1 rule 2).
- `capped` — a hard integer or percentage ceiling reached by copy N, then further
  copies no-op (charges, proc-based procs, chain depth). Matches `Backup Magazine`'s
  +1-charge-per-stack-to-a-cap pattern from R1.

**Naming.** `{modifier} {noun}`: `noun` from the base family (Rounds, Coil, Plating,
Barb…), `modifier` from the element or, if none, the trigger (Frost-, Arc-, Kinetic-,
Rebound-, Vault-, Charged-). Rare_plus swaps the noun to "Core" or "Heart", matching
`sunforged_core`/`rime_heart` already in the catalogue. A template lookup, not free
text — every generated name is inspectable like a hand-authored row.

**Icon category** is the base family verbatim (`weapon→damage`, `pattern→transform`,
`mobility→mobility`, `stat→defense`, `charge→charge`, plus a new `utility` family for
non-combat effects). V2 icons key off this the same way gate toppers key off rarity.

**Description**, ≤8 words, templated as `"{verb}, {effect}"` and hard-truncated at
word 8 with an ellipsis if a template overflows — the catalogue test asserts this (§4).
Existing rows are already this shape ("Hit harder" / "+4 punch, +12% weapon damage" is
5 words); the template is the same discipline, generated instead of hand-written.

## 3. The 60+ item pool

61 items across six families, with the four required sub-groups explicit: charge (8),
momentum/bowling — tagged `bwl` regardless of family (8), pattern transformers (6, 3
existing + 3 new), and happy accidents (5). `stack` abbreviates the stacking curve
(`lin`/`hyp`/`cap`); `cap` is the ceiling for `hyp`/`cap` rules.

### Charge-stockpile (8)

| id | rarity | trigger | effect | stack | cap | icon |
|---|---|---|---|---|---|---|
| cap_relay | uncommon | passive | +1 max_charges, special | cap | 3 | charge |
| vault_battery | rare | passive | +1 max_charges, vault kick | cap | 2 | charge |
| sprint_cell | uncommon | passive | +1 max_charges, sprint | cap | 3 | charge |
| cloak_flask | rare | passive | +1 max_charges, cloak | cap | 2 | charge |
| quick_spool | common | timed | special cooldown −8%/stack | hyp | 40% | charge |
| overcharge_coil | rare_plus | on_charge_release | +40% release dmg, 15% refund 1 charge | cap | 1/rel | charge |
| reserve_tank | uncommon | passive | +1 max_charges, all specials | cap | 2 | charge |
| flywheel | common | on_speed_tier_up | +1 temp charge, current ability, 6s | cap | 1 | charge |

### Momentum / bowling (8)

| id | rarity | trigger | effect | stack | cap | icon |
|---|---|---|---|---|---|---|
| pin_setter | uncommon | on_smash | knocked enemies deal +50% pin dmg | lin | 3 | damage |
| spring_hull | common | on_rebound | +15% rebound impulse | lin | 5 | defense |
| long_lane | rare | on_vault | vault kick ×1.9, +10m carry | lin | — | mobility |
| gutter_guard | uncommon | on_rebound | rebound grants +1 air jump | cap | 2 | mobility |
| ten_pin | rare_plus | on_smash | knocked pins chain to 3 more | cap | 3 | damage |
| ballast_drum | common | passive | +40 mass, no speed loss | lin | 5 | defense |
| strike_pocket | rare | on_rebound | 3rd rebound in 4s crits ×2 | cap | 1/win | damage |
| re_rack | uncommon | on_land | landing near a pin relaunches it | cap | 1/land | utility |

### Weapon-pattern transformers (6)

| id | rarity | trigger | effect | stack | cap | icon |
|---|---|---|---|---|---|---|
| cross_split | uncommon | passive | shots split 4 ways (existing) | — | — | transform |
| spiral_wave | uncommon | passive | shots corkscrew outward (existing) | — | — | transform |
| chain_arc | uncommon | passive | a hit jumps to a neighbour (existing) | — | — | transform |
| fan_spread | rare | passive | shots fan into a 5-round cone | — | 3 lvl | transform |
| ring_wave | rare | passive | impacts emit an expanding pulse ring | — | 3 lvl | transform |
| helix_drill | rare_plus | passive | shots corkscrew through 2 enemies in line | — | 3 lvl | transform |

### Happy accidents (5)

Bounded exploits: each one is fun *because* it is rare and capped, not because it is
unlimited. Anomalies the fuzzer finds beyond these five go to `HAPPY-ACCIDENTS.md` (§4).

| id | rarity | trigger | effect | stack | cap | icon |
|---|---|---|---|---|---|---|
| scrap_geyser | rare | on_pickup | 4% chance a pickup bursts nearby pins | cap | 1/pick | utility |
| echo_charge | rare_plus | on_charge_release | 10% chance: free echo of the release, one tier down | cap | 1 | charge |
| feedback_loop | rare | on_kill | a kill during cloak extends it 0.4s | hyp | 3s | utility |
| momentum_thief | uncommon | on_damage_taken | a chip hit steals 5% as +speed, 1.5s | cap | 25% | mobility |
| domino_wire | rare_plus | on_smash | a pin hitting a pin has 20% chance to chain once more | cap | depth 1 | damage |

### Damage (10)

| id | rarity | trigger | effect | stack | cap | icon |
|---|---|---|---|---|---|---|
| hairline_fracture | common | on_hit | +6% crit chance, next hit same target | lin | 30% | damage |
| barrage_spring | uncommon | on_kill | next shot within 1s is free | cap | 1/kill | damage |
| warhead_slug | rare | on_smash | smash deals +35% to plating | lin | 3 | damage |
| static_burr | common | on_hit | 10% chance: apply arc | cap | — | damage |
| frost_barb | common | on_hit | 10% chance: apply frost | cap | — | damage |
| overpressure | uncommon | timed | every 8s, next hit +60% | cap | 1 | damage |
| clean_break | rare | on_kill | killing blow chips nearby plating 10% | cap | 1/kill | damage |
| tracer_round | common | on_hit | +8% weapon range per stack | lin | 5 | damage |
| impact_driver | uncommon | on_rebound | rebound impact deals weapon damage | lin | 3 | damage |
| last_word | rare_plus | on_damage_taken | below 25% HP, next hit +100%, once/life | cap | 1 | damage |

### Mobility (8)

| id | rarity | trigger | effect | stack | cap | icon |
|---|---|---|---|---|---|---|
| light_frame | common | passive | +6% cruise speed | lin | 5 | mobility |
| glide_vane | uncommon | passive | +20% glide duration (caster) | lin | 3 | mobility |
| grapple_coil | common | passive | +20% grapple range | lin | 4 | mobility |
| tumbler_bearing | uncommon | on_land | jump-apex landing grants a free double-jump | cap | 1/land | mobility |
| slipstream | rare | on_speed_tier_up | +15% turn rate at top tier | lin | — | mobility |
| anchor_spring | uncommon | passive | vault kick cooldown −20% (engineer) | lin | 3 | mobility |
| jet_vent | rare | on_cloak_break | cloak break grants a burst dash (caster) | cap | 1/brk | mobility |
| low_rider | common | passive | +5% cruise speed, +5% mass | lin | 5 | mobility |

### Defense (8)

| id | rarity | trigger | effect | stack | cap | icon |
|---|---|---|---|---|---|---|
| rivet_seam | common | passive | +15 max HP | lin | 6 | defense |
| shock_liner | uncommon | on_damage_taken | 8% of damage taken returns as arc | cap | — | defense |
| crush_guard | rare | passive | would-crush threshold −10% | hyp | 30% | defense |
| deflect_plate | common | on_damage_taken | 5% chance: negate a below-plating hit | cap | 3 | defense |
| brace_frame | uncommon | on_land | fall >6m grants 1s of +20% plating | cap | 1/win | defense |
| scrap_armor | common | passive | +1 max HP per 50 held mass | lin | 40 | defense |
| rebound_skin | rare | on_rebound | 1s immunity to the rebounded enemy type | cap | 1/win | defense |
| warden_ward | rare_plus | on_damage_taken | first lethal-adjacent hit/stage floors HP at 20% | cap | 1/stg | defense |

### Utility (8)

| id | rarity | trigger | effect | stack | cap | icon |
|---|---|---|---|---|---|---|
| magnet_coil | common | passive | scrap magnet reach +30% | lin | 4 | utility |
| cache_key | uncommon | on_kill | 6% chance: kill drops bonus scrap | cap | — | utility |
| beacon_lamp | common | passive | Warden marker visible through terrain | — | — | utility |
| fast_hands | common | passive | fabricator prices −8% | lin | 3 | utility |
| echo_locator | uncommon | timed | every 12s, ping reveals nearest event | cap | 1 | utility |
| synergy_lens | rare | passive | hint cards reveal one tag earlier | — | — | utility |
| salvage_drone | rare | on_kill | 4% chance: a drone auto-collects scrap 4s | cap | 1/4s | utility |
| par_chip | rare_plus | passive | stage timer shows a ghost split vs. best | — | — | utility |

## 4. Standardization

**Invariants**, as new `@export` fields on `part_def.gd` (`trigger := ""`,
`proc_coeff := 1.0`, `stack_rule := "linear"`, `stack_cap := 0.0`, `icon_category :=
""`), each checked by an extended `build_catalogue_test.gd`:

- `trigger` is `""` (passive) or a member of `Trigger.KIND`; no free strings.
- `stack_rule` is one of `linear/hyperbolic/capped`; `capped`/`hyperbolic` rows carry a
  nonzero `stack_cap`.
- No `mods`, `punch`, `magnet`, `kill_scrap`, `proc_coeff` or `stack_cap` value is NaN
  or infinite (`is_finite()` on every numeric field).
- `text` is ≤8 words (`text.split(" ").size() <= 8`).
- `icon_category` is a known family key, so V2's icon set never gets an orphan.
- No trigger row calls a behaviour that posts its own trigger kind (static check: grep
  each `elements`/`patterns` payload for a self-referential trigger id) — the chain-depth
  rule enforced at authoring time, not just at runtime.
- The existing rules stand: only `common` may be `percentage_only()`, every gate pair
  has one `hits_harder()` part, rarity follows source.

**`item_fuzz` bot spec**, `sketches/core-loop/tests/item_fuzz_test.gd`, the same
`SceneTree`/`Game`/`Intent.Scripted` harness as `build_catalogue_test.gd`:

- 200 seeded runs (the plan's stated bar), each drafting a random legal build of 6–14
  held parts from the full pool through the same `Parts.roll`/`roll_gate` calls the game
  uses, then driven headless for 90 s at 90 Hz against a scripted enemy line that
  guarantees every trigger fires at least once (a smash target, a rebound wall, a vault
  face, a pickup line, a charge-hold window).
- Checked per tick: no NaN/non-finite velocity or position on the ball or any bolt; live
  bolt count ≤ `Bolts.MAX_LIVE`; every `stack_cap` respected; frame time under budget
  (reuses `tools/perf_probe.gd`); no trigger fires twice per commitment for the same
  kind (the `resolving` flag never leaks past P6); no stall (same pattern as
  `diag/core-loop-hang`).
- **Anomaly = any invariant violation, or any effect that clearly exceeds its declared
  cap's intended headroom** (a `capped` stat sampled above `stack_cap + epsilon`, a kill
  count or speed value more than 3× the seed's median for that build size). Each anomaly
  appends one line to `HAPPY-ACCIDENTS.md`: seed, build (part ids in draft order), tick
  of onset, the specific reading and its cap, and a one-line description in the same
  voice as `synergies.gd`'s `found` strings. Andrew reads the file and marks each line
  `KEEP` or `KILL`; `KEEP` promotes the combination to a named or unnamed synergy row,
  `KILL` becomes a bug card. This is Gungeon's and Brotato's exploit-tolerant pattern
  from R1 (rule 10): document, don't silently patch.

## 5. Player legibility — how you learn what to chase

- **Reward-gate icons.** Gates already show name, verb and a synergy star line
  (`reward_gates.gd`). Add the trigger and element as two small glyphs beside the
  topper shape — trigger glyph from V2's icon set, element glyph from the existing
  frost/arc/kinetic palette — so a gate reads at a glance: family shape, rarity topper,
  trigger glyph, element glyph. No new text.
- **Pickups.** A dropped item's beacon color is its element (existing palette), its
  shape is its family icon; a pulsing ring means it completes a synergy, matching the
  gate's star-line convention so the two systems teach each other.
- **Run timer and difficulty clock.** Shown Risk-of-Rain style: a small always-visible
  clock plus a "difficulty" tick mark advancing on a schedule tied to `stage_defs`, read
  as a filling bar, not a number — consistent with the RR-01-style iconography entry 7
  already asks for. This bar plus the beacon HP band is the whole growth readout, no new
  panel.
- **Opt-in challenge modifiers**, selected at run start, separable extra per the plan's
  light-play-lane scope:
  - **Scrapless** — start with zero parts and no scrap pickup; the run is armor-off,
    matching "as little gear as possible."
  - **Par timer** — a ghost split against the player's best Warden-break time
    (`par_chip`'s HUD, item 60 above, made a standing option instead of a drop), for
    "if there's a time component to it."
  Both log their own run tag in `user://runs.ndjson` so the balance report can separate
  modifier runs from normal ones without polluting the curve.

---

**Summary.** A closed 12-trigger vocabulary with a proc-coefficient rule and a
same-pass re-entry guard that terminates chains by construction, not by luck. The
generator is `base × affix × element × trigger`, reusing the catalogue's existing tier
scaling and rarity bands rather than inventing new numbers, with templated names,
icons and ≤8-word descriptions the catalogue test can assert mechanically. 61 items
cover damage, mobility, defense, utility, 8 charge-stockpile, 8 bowling/momentum, 6
pattern transformers and 5 designed happy accidents. Standardization extends
`part_def.gd` with typed trigger/stack fields, an extended catalogue test, and a
200-seed `item_fuzz` bot that logs anomalies to `HAPPY-ACCIDENTS.md` for Andrew to
keep or kill. Growth reads through gate/pickup glyphs, a RoR-style timer/difficulty
bar, and two opt-in modifiers (Scrapless, par timer) that answer his self-challenge ask
directly.

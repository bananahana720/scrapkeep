# Progression map, core-loop v2

One of the four primer boards (plan `synchronous-weaving-crystal.md`, "Pacing"). It answers playtest entry 7's two questions, "how do I get more powerful" and "what am I searching for", across three horizons, and sets the rules that keep the tuned difficulty intact while the game grows. Sources: `DESIGN-V2.md` (§2, §5, §7, §12 to §14), `DEMO-SPEC.md`, `I2-item-generator.md`, `VISUAL-LANGUAGE.md` §5 and §7, `SOUND-STORY.md` §3 and §5, and what persists today (`src/core/run_state.gd`, `codex.gd`, `run_log.gd`). Numbers from those files are cited; numbers introduced here are starting values for the balance report, never tuning.

**The one sentence.** Get heavy, hit harder, and take the thing the clock is trying to stop you taking. Everything that persists between runs is an option, a piece of knowledge, a look or a pressure. Never a stat.

| Horizon | What is earned | Earned by | Persists as |
| --- | --- | --- | --- |
| 1. In-run | heft, parts, charges, cores, the top shelf | rolling, breaking, choosing | nothing (a run is rebuilt) |
| 2. Character mastery | sidegrades: alternate specials, smash flavours, shell kits, loadout presets | per-pilot play milestones | options on the class screen |
| 3. Account and meta | codex, Moss's memory, wider shop, Pressure levels, modifiers | discovery, wins, self-challenge | knowledge, cosmetics, pressure |

## 1. In-run: the searching loop

**The loop, in one breath.** Roll scrap into mass. Mass and parts are heft (`run_state.gd:13-15`: `1 + mass/450 + 0.2 × parts`, classes I to V at 1.0, 1.5, 2.2, 3.2, 4.6). Heft is punch. Punch that beats plating lands in full; below it, 20% and a clank (DEMO-SPEC, Plating). So the first thing you search for is *whatever is tinted slate*: slate means "not yet", amber means "now". Break the Warden (the only MUST) and its core opens the gates. Every event won and vault broken is a bonus core, and cores set the gate tier (0: common or uncommon; 1: uncommon or rare; 2+: rare or rare_plus, `run_state.gd:16-17`). Parts add heft and triggers, triggers add synergies, and Moss's shelf lets you buy on purpose instead of rolling. The difficulty clock is the counter-pressure: it never stops you, it changes who arrives.

```
 stage 1                    | Moss |  stage 2                   | Moss |  stage 3                     | Moss | arena
 drop ─ scrap ─ fab ─ event ─ WARDEN ─ gates ─ bay ─ launch ─ ... ─ WARDEN ─ gates ─ bay ─ launch ─ ... ─ WARDEN ─ gates ─ bay ─ Brindle
 heft I ──────── II ─────────────────────────── II/III ──────────────────────────── III ────────────────────────── III/IV ────── V?
 clock ▁▁▂▂▃▃ (tick) ▃▃▄▄ (tick, clamp +2)  paused  ▁▁▂▂ ...        paused        ▁▁▂▂▃▃ ...          paused     (no clock)
 cores  ◇ event   ◇ vault      → gate tier   reset  ◇ ...                reset ◇ ...                     reset
```

The heft line is DEMO-SPEC's post-tuning intent (a skipper leaves stage 3 near heft 3, DEMO-SPEC line 37). Inference: 6 parts and 450 mass is exactly class IV (3.2), so IV is the "did everything" mark for stage 3 and V belongs to the arena or to Pressure runs.

### What "stronger" means, ladder by ladder

| Ladder | Grows by | Reads as | Sound (SOUND-STORY §3) | What it unlocks in play |
| --- | --- | --- | --- | --- |
| **Heft class** (I to V) | scrap mass, parts | `res_heft` dial: needle, class ticks, a clunk on a new class | the A-D-A climb, priority 3 | fodder that bounced you now rolls up at ≥ 0.95 speed (DEMO-SPEC, Growth moments); hook tethers snap above their heft rating (DESIGN-V2 §10.2); Moss's top shelf (§12) |
| **Punch vs plating** | heft × force for rams, stomps, slams; gun damage after parts | amber or slate tint on every plated target, read from the same `punch_now()` | clank and `strike_deflected` below plating | the Warden, the plated brute, the vault, Brindle's hull (120) |
| **Parts** (61-item pool, 12 triggers) | gates, fabricators, events, vaults, the shelf | gate = family shape + rarity topper + `trg_` glyph + `el_` glyph, no text (DESIGN-V2 §7) | one to three ladder notes by rarity, rare_plus the level motif head | triggers, elements, tags; +0.2 heft each |
| **Charges** | `cap_relay`, `sprint_cell`, `reserve_tank` and kin; Moss's charge upgrade | 6 px pips under the slot (VISUAL-LANGUAGE §7); pips climb the class motif one note each | a hat, a thump or an arpeggio note per pip | the same cooldown, used twice; timing still matters |
| **Cores** | Warden (required), events, vaults | `res_core` pip row beside the objective | `core_socket` | the gate tier; reset each stage (`enter_stage`) |
| **Synergies** (9 named today in `synergies.gd`, plus Found) | tag pairs across parts | `key_tab` hint cards; a pulsing pickup means "completes one" | the bebop fanfare | behaviour changes, never a percentage |

### What you are searching for, ranked

The HUD already ranks it (DEMO-SPEC, Engagement tiers), so the answer is on screen without a word:

1. **MUST: the Warden.** `obj_warden` on the objective line, amber when you can hurt it. Slate means you are searching for heft, and the fall line is where the scrap is.
2. **SHOULD: cores.** `obj_event` and `obj_vault` near the line. One core turns the next gates from common to rare; two is the ceiling. This is the second question's real answer: *two cores per stage*.
3. **COULD: the hint cards.** A card with one ingredient lit and a clue for the other ("Chain Arc + something that splits") is a goal you set yourself. A pulsing pickup or a starred gate offer says "this one".
4. **The locked hook.** Moss's top shelf shows the heft class it needs as the pressure dial with a notch (DESIGN-V2 §12). The growth goal, made literal.

### The difficulty clock

`res_difficulty` is a filling notched bar under the run clock (I2 §5). Ticks follow a schedule tied to `stage_defs` (threat 1.0 / 1.25 / 2.1), the time tier is clamped at +2 and announced with `threat_rose` (DEMO-SPEC, Director honesty). Each tick past the Warden break adds reinforcement weight and one Fleet brass layer (DESIGN-V2 §10.5, §11). The clock pauses in Moss's bay; the par timer does not (§12).

That is the Risk of Rain pressure, and it is why the loop has a decision in it: every core is off the line, and off the line costs ticks. The clock never opens or closes anything (TADR-010: time scales threat, never gates progression). It decides whether a bola thrower is waiting at the vault.

### Challenge modifiers, in-run

Two at the demo, chosen on the class screen and tagged in `runs.ndjson` (I2 §5): **Scrapless** (no parts, no scrap pickup: heft stays 1.0, so plating is the run) and the **par timer** (a ghost split against your best Warden break per stage). Neither changes enemy numbers; they change what the player brings.

### How horizon 1 keeps momentum sacred

Every growth event is a drive-through: gates, fabricator hoops, magnet pickups, and the bay banks speed and slingshots it back (§12). The only stop is the one the player chooses. Growth moments are sounds and a needle, never a panel. The clock adds enemies, not walls.

## 2. Character mastery across runs

**What is earned.** Sidegrades, per pilot: an alternate F special, an alternate smash flavour, a shell kit (a Blender accretion variant, cosmetic), and loadout presets. A variant is the same slot, cooldown budget and gauge grammar with a different shape. Nothing here raises a number.

**How it is earned.** Play milestones read from the synergy hooks the class row already carries (DESIGN-V2 §2). The counters exist for items; mastery reads the same events. Each is a per-run threshold a competent run hits once or twice, found by playing the class the way it wants to be played.

| Pilot | Milestone (id) | Read from | Unlocks | The sidegrade's shape |
| --- | --- | --- | --- | --- |
| Sable | **Vault chain**: 3 vault kicks within 6 s (`sable_vault_chain`) | `on_vault_kick` | alt smash **Anchor slam** | the slam plants a 4 s mount point instead of highlighting faces: fewer options shown, one made |
| Sable | **Full discharge**: a Warden hit by a full-gauge detonation (`sable_full_gauge`) | `on_pylon_discharge` | alt special **Delayed pylon** | plant, then a 1.5 s fuse discharge that scales with banked speed; the trade is timing for radius |
| Sable | **Beachhead**: mounted while a pack of 5+ dies (`sable_beachhead`) | `on_mount_planted`, kills | shell kit **Pylon plates** | cosmetic |
| Rivet | **Can't be held**: 12 crowd-control hits ignored in one run (`rivet_cc_ignored`) | `on_cc_ignored` | alt smash **Long skid** | a longer, narrower slide that refunds sprint per metre instead of per hit |
| Rivet | **Full blast**: a full-gauge blast hitting 6+ (`rivet_full_blast`) | `on_blast_release` | alt special **Overdrive lance** | a lane (`thr_lane` grammar) instead of a burst: reach for radius |
| Rivet | **The line**: sprint from the stage 1 drop to the Warden ring without a stop (`rivet_the_line`) | `on_sprint_start`, ring entry | shell kit **Rail fins** | cosmetic |
| Kest | **From cloak**: 8 cloak crits in one run (`kest_cloak_crits`) | `on_cloak_crit` | alt smash **Cluster slam** | one bigger mini-charge instead of three: burst for spread |
| Kest | **Triple catch**: a detonation line catching 3 charges (`kest_triple_catch`) | `on_chain_detonation` | alt special **Detonation ring** | a ring (12 m) instead of a line: no aim, no length |
| Kest | **Taught by falling**: a rocket jump within 1 s of landing a 20 m+ drop (`kest_taught_by_falling`) | `on_rocket_jump`, fall height | shell kit **Roost vanes** | cosmetic, and codex fragment 6 (§6 below) |

Nine milestones, three per pilot, one per unlock kind. Thresholds are starting values: a milestone found in more than 80% of runs or fewer than 10% gets retuned, the same band logic as synergies (DEMO-SPEC, Balance report).

**How it reads.**

- **Mid-run.** A priority-2 toast in the class colour, five words at most ("Sable: vault chain"), and the class motif played whole on the beat (SOUND-STORY §2: the whole tune is the payoff). A new event row, `mastery_earned`, economy group, class shape from the class row. It is a notice, not a power.
- **Summary.** The milestone track as three pips in the class shape (ring, chevron, starburst) under the pilot's emblem, filled in the class colour, and the unlock revealed beside it with its new `ab_` icon. The reveal is the only place a new option is announced.
- **Class select.** The same pips under each `cls_` emblem, and the loadout row: F, Ctrl and kit, each showing the chosen variant's icon. An unearned variant is a slate silhouette with the milestone's pips beside it, so the goal reads without a sentence. A variant icon carries a small parts-tag notch so the HUD slot says "variant" at 24 px.

**Pacing.** A first run with a pilot usually earns one milestone (the one closest to how the class already plays). All three land in the first five runs with that pilot for a player who goes looking; all nine in ten to fifteen runs. Roughly one unlock per hour. Ignoring them costs nothing.

**How it keeps momentum sacred.** Milestones are things you do while rolling, never a detour. The toast takes one of the two toast slots (VISUAL-LANGUAGE §7). Unlocks apply at the summary, so no run changes shape halfway. A player who never touches the class screen plays exactly the tuned kit.

## 3. Account and meta

**The spine is the codex.** Already the demo's only meta-progression (`codex.gd`, DEMO-SPEC), it stays the spine because it is knowledge: `build` hint cards, `world` fragments (SOUND-STORY §5's ten, never resolved), `enemy` interactions, reserved `npc` and `coop`. Completion per category is a percentage on the Tab page. Everything else here hangs off it or off the run log.

| Meta piece | What it is | Earned by | Widens, never raises |
| --- | --- | --- | --- |
| **Codex** | hint cards, fragments, found list | discovery in play | goals (cards), story (fragments), tactics (enemy) |
| **Moss's memory** | callback hooks the vision keeper writes lines for | playing; see below | recognition |
| **Workshop upgrades** | Moss's bay changes | codex completion and wins | choice at the shelf |
| **Pressure** | ascension-style heat, as valves in the bay | a win at the level below | difficulty, on purpose |
| **Modifiers** | Scrapless, par timer, later ones | free from run 1 | how you challenge yourself |
| **New pilots and kits** | later | later | roster |

**Workshop upgrades at Moss's.** Each is a change to the bay, never to prices, caps or numbers:

| Upgrade | Unlocked by | Effect |
| --- | --- | --- |
| **Wider shelf** | first win | the shelf shows 4 parts, not 3 |
| **Tagged hooks** | `build` codex ≥ 50% | Moss marks a shelf part that is a known synergy ingredient with the same star line gates use |
| **Class hook** | any pilot's three milestones | one shelf slot always offers that pilot's class-specific item family |
| **Second reroll** | 10 runs finished (won or lost, not abandoned) | a second reroll per visit, at the rising price |
| **The valves** | first win | the Pressure valves appear on the bay's exit wall |

None changes what the shelf costs or how heavy the ball gets. Prices and the charge cap stay W4's tuning.

**Pressure (ascension-style heat).** For self-challengers, the ladder is the difficulty bar itself: each Pressure level pre-fills one of `res_difficulty`'s sawtooth notches before the run starts, so the bar reads "starts hotter" without a number. Levels open through pressure valves on the bay's exit wall (form mirrors function: the contraption grammar's valve you smash open on the way out, DESIGN-V2 §9). It is a choice at the launch pad, never a stop.

| Level | Name | Adds | Opened by |
| --- | --- | --- | --- |
| 1 | **Fast clock** | difficulty ticks 25% sooner | a win at level 0 |
| 2 | **Early crews** | Fleet reinforcements arrive one tick earlier | a win at 1 |
| 3 | **Thick plate** | Warden and brute plating +15% | a win at 2 |
| 4 | **Heavier hook** | Moss's top shelf needs one band higher | a win at 3 |
| 5 | **No breather** | the regen delay doubles | a win at 4 |

Levels stack. Rewards are a codex line per level, a shell trim per pilot at level 5 and the run-log tag; never a part, a stat or a pool change, so the balance report drops Pressure runs from the tuning curve. Level 3 is the only one that touches enemy numbers, by a named percentage, so the base tuning stays where it is.

**What makes the next run feel new.**

1. **The seed you bring.** A pilot variant changes the class's shape: Kest with a ring is a different problem than Kest with a line.
2. **The hint you took.** One undiscovered card with a lit ingredient is a run plan. Only `synergy_lens` (a rare part) reveals a tag early; nothing meta does.
3. **Who remembers you.** Moss's lines (below), and the Mind's hands: the stage 3 Warden reads last run's rebound-to-vault ratio for this pilot and opens braced against it, bounded and telegraphed (DESIGN-V2 §10). The one enemy that learns across runs, and it learns one fact.
4. **The pressure you chose.** A pre-filled notch changes the first minute.
5. **The world.** Event mix and terrain events stay stage data; Pressure and the codex never touch them.

**How Moss remembers the player.** Moss "remembers what each pilot neglects" (BIBLE.md:384). The hooks are facts in the profile save (§8), each naming the fact and the moment; the vision keeper writes the words under §12's rules (at most 12 words, away from the reticle, never blocking the exit).

| Hook id | Fact | Fires when |
| --- | --- | --- |
| `moss_first_visit` | `visits == 0` | the first time the ball enters the bay |
| `moss_last_death` | last run's outcome and stage (`last_outcome`, `last_death_stage`) | first visit of a run after a loss ("Caps got you. Slam them.") |
| `moss_refused_before` | `refusals` across runs | the top-shelf loop opens for a returning player (the loop's variation index reads this) |
| `moss_relented_before` | `relents` across runs | the hook unlocks for a player who has unlocked it before |
| `moss_sold_back` | the part families sold most across runs (`sold_families`) | the shelf is stocked, biased one slot toward a family the player keeps selling ("You keep selling plating. Fine.") |
| `moss_pilot_neglects` | per pilot, the ability used least last run (from the run log) | first visit with that pilot; the Bible's "remembers what each pilot neglects" |
| `moss_fragment_carried` | a `world` fragment discovered this run | any visit; he does not want it in his shop (fragment 8, "Leave it buried. M.") |
| `moss_pressure` | the selected Pressure level | the valves' state on the exit wall |

The story-thread map owns the beats; this board owns the facts they read.

## 4. Anti-grind and anti-power-creep rules

1. **Nothing persistent adds a stat.** Persistence carries options, knowledge, cosmetics and pressure. BIBLE line 463: a permanent unlock "persists without accumulating permanent combat-stat advantage".
2. **Every unlock is a play milestone with a per-run threshold a competent run can hit.** Cumulative counts across runs are allowed only for the second reroll (10 runs) and never for a kit variant. No milestone reads elapsed time.
3. **Time never gates progression** (TADR-010, BIBLE line 538). The clock scales threat and nothing else, and Pressure only moves the clock.
4. **The heft curve is tuned in one place.** `run_state.gd`'s constants and `stage_defs`. No meta feature reads or writes them. The top shelf lock reads the class, never a modified threshold, except Pressure 4 raising the band by one.
5. **A sidegrade shares its slot's cooldown budget and gauge grammar.** It changes shape (line, ring, lane, burst), not budget. The bot completes full runs with every variant before it ships, and the balance report bands the variant against the base kit.
6. **Moss's upgrades widen the shelf.** They never lower a price, raise the charge cap or change sell-back.
7. **Pressure adds pressure.** Its rewards are codex lines, trims and a tag. Pressure runs are excluded from the tuning curve by their tag, so they can never drag the base numbers.
8. **The codex pays once per entry per run** (`codex.gd` `_run_seen`). No meta feature reads the treasure burst.
9. **Modifiers and Pressure are tagged in `runs.ndjson`** so the balance report separates them from normal runs (I2 §5). Tuning never bends to a modifier.
10. **No daily, streak, login or currency.** Scrap resets with the run. The only account-level number is the codex completion percentage, and it buys nothing but Tagged hooks.

## 5. Pacing sketch

| | Runs | Horizon 1 | Horizon 2 | Horizon 3 |
| --- | --- | --- | --- | --- |
| **First hour** | 2 to 4 (inference: a demo run is 12 to 20 min; not measured this session) | run 1 dies to a slate Warden and learns "heft first"; run 2 finds a core and sees rare gates; the locked hook is met and refused | one milestone lands by accident (the class's natural one); the summary reveals the first variant | 3 to 6 codex entries, one fragment; Moss's first-visit line; Wider shelf on the first win, if it comes |
| **First ten runs** | 10 | all three pilots tried; class IV reached once; the top shelf bought once; Scrapless tried by a self-challenger | 4 to 6 of nine milestones; each pilot has a loadout choice | `build` cards half found, the valves open, Pressure 1 or 2 for a challenger; Moss knows what you sell back; Second reroll at run 10 |
| **Fifty runs** | 50 | the heft ladder is a known route; par-timer ghosts per stage | all nine milestones; loadout presets per pilot; the variant that suits the player is the one they use | the codex near 80% except the fragments' ambiguity; Pressure 5 trims for the persistent; Moss's line pool exhausted, which is the signal to write more |

The shape is Isaac's and Risk of Rain's: the first hour is the in-run loop alone, ten runs add options, fifty is knowledge and pressure. Nothing in the fifty-run column is stronger than the first-hour column. It is wider.

## 6. Callbacks (§13)

Each passes the three tests: gameplay sense alone, discovered not announced, inside the principles.

1. **"Too heavy for you."** Moss's top-shelf lock (DESIGN-V2 §12). Already specified; listed so the running list is complete. Rides the heft class.
2. **Strike, spare, turkey.** Bowling scoring as `build` codex entries: **Strike**, a pin chain that kills three; **Spare**, a rebound that kills the enemy you missed; **Turkey**, three strikes in 4 s (the same window as `strike_pocket`'s third rebound). Rides the pin rule (§3) and `ten_pin`. Test 1: three pin chains in a row is a fair, readable feat without the name. Test 2: the codex names it after it happens. Test 3: pins are momentum.
3. **"Inventory does not wake."** Fragment 9's line as a `world` codex entry, earned by breaking a Warden before the first difficulty tick of that stage. Rides the clock and the par timer. Test 1: a speed feat, shown by the par ghost. Test 2: found by being fast, never announced. Test 3: it rewards leaving, never stopping.
4. **"Everything that flies was taught by something that fell."** Fragment 6 is Kest's `kest_taught_by_falling` milestone entry: a rocket jump within 1 s of landing a 20 m drop, the skylight route (DESIGN-V2 §8, Kest drops through a skylight and rocket-jumps back). Test 1: the glide-drop-jump is Kest's best route anyway. Test 2: the fragment appears in the codex after the jump. Test 3: it is a momentum move.
5. **The valves.** Pressure as pressure valves on Moss's exit wall, opened with a smash on the way out (the contraption grammar, §9: "pressure valves the player smashes to open a route"). The heat ladder and the steam grammar are one thing, and the notched bar reads the result. Test 1: a valve you can smash, with a gauge. Test 2: the wall is only visible in the bay. Test 3: it is on the launch, never a stop.

Log each in DESIGN-NOTES as "Callback:" when built; the vision keeper adds them to SOUND-STORY's running list.

## 7. Demo must-have versus later

**The early-access demo (DESIGN-V2 §14) must have:**

- Horizon 1 complete: heft and classes, the pool, charges, cores and gate tiers, Moss's shelf, reroll, charge upgrades, sell-back, the top-shelf lock and loop, the clock, Scrapless and par timer (all already in §14.4 and §7).
- The nine milestone counters, the `mastery_earned` row, the summary's pips, and **one sidegrade per pilot: the alternate smash flavour** (the shared slot with the smallest surface; W3 owns the flavour code).
- The codex as it is, plus `user://profile.json` (§8).
- Three Moss hooks: `moss_first_visit`, `moss_last_death`, `moss_refused_before`.
- Callbacks 1 to 4.

**Later:** alternate specials, shell kits (Blender) and loadout presets; workshop upgrades beyond Wider shelf; Pressure and the valves (callback 5); the Mind's hands learning across runs; the remaining Moss hooks; new pilots; the `npc` and `coop` categories.

## 8. Persistence

Today: `user://codex.json` (`discovered`, `found`, `found_categories`; `codex.gd:261-268`), plus the append-only `codex-log.ndjson` and `runs.ndjson`. Nothing else persists. The codex file stays as it is.

**New: `user://profile.json`**, versioned. Anything rebuildable from `runs.ndjson` plus `codex.json` is a cache, so a corrupt profile rebuilds instead of losing unlocks. Storage failures never throw (`codex.gd`'s pattern: keep working in memory, note `last_error`).

```
{
  "version": 1,
  "created": <unix>,
  "runs": {"played": 0, "won": 0, "by_class": {"sable": {"played": 0, "won": 0}, ...}},
  "best": {"run_time": null, "warden_break_ticks": {"1": null, "2": null, "3": null}, "heft": 1.0},
  "milestones": {"sable_vault_chain": {"best": 0, "done": false}, ...},   // nine ids
  "unlocks": ["sable_anchor_slam", ...],
  "loadouts": {"sable": {"special": "base", "smash": "base", "kit": "base"}, ...},
  "pressure": {"open": 0, "selected": 0},
  "modifiers_used": {"scrapless": 0, "par": 0},
  "moss": {"visits": 0, "refusals": 0, "relents": 0, "last_outcome": "", "last_death_stage": 0,
           "sold_families": {"defense": 0, ...}, "neglected": {"sable": "", ...}},
  "last_pattern": {"sable": {"rebounds": 0, "vaults": 0}, ...}   // the Mind's one fact
}
```

Versioning: an integer `version`; a loader migrates forward one step at a time and keeps unknown fields. Unlocks and `pressure.open` are the only fields that are not derivable, so they are written on the event, not at run end. Test seams: the same `storage_dir` swap `game.gd:127` uses for tests.

## 9. Questions for Andrew

1. **Where do mastery unlocks apply?** Default: at the summary, as options for the next run. The alternative, applying a just-earned variant at the next Moss visit, rewards mid-run but changes a run's shape halfway.
2. **Is Pressure gated by wins, or open from the first run?** Default: each valve opens after a win at the level below (the Hades shape), with Scrapless and par timer ungated from run 1. The alternative opens all five valves at the first win.
3. **Full kit at run start, or the Bible's unlock-in-world-one?** BIBLE line 400 has the main skill and ultimate unlocking through play in world one; DESIGN-V2 §2 gives all four keys from the drop. Default: the full kit for the sketch (the bar always reads LMB, RMB, F, Ctrl), and the post-v2 Bible card decides production. The alternative makes F a mid-stage-1 unlock.

## Vision delta

- **Event rows.** `mastery_earned` (economy group, class colour and shape from the class row, sound: the class motif whole, priority 2, hud "{class}: {milestone}"). `pressure_opened` (UI group, sound: a valve hiss then the `threat_up` tick, priority 1, no hud words). Codex entries for Strike, Spare, Turkey (`build`), "Inventory does not wake" (`world`), fragment 6 as Kest's milestone (`world`), and one line per Pressure level (`world`).
- **Visual motifs.** Milestone pips in the class shape under the `cls_` emblem (summary and class select). A parts-tag notch on a variant's `ab_` icon. Slate silhouettes for unearned variants. Pre-filled sawtooth notches on `res_difficulty` for Pressure. Pressure valves on the bay's exit wall with a gauge each. Moss's shelf star line on a known ingredient (Tagged hooks).
- **Names and wording.** The nine milestone names, six variant names and three kit names in §2's table; the five workshop upgrades and five Pressure level names in §3; the Moss hook ids in §3 (the lines are the vision keeper's).
- **Timings the player feels.** The milestone toast holds 1.6 s (priority 2) and the motif lands on the beat. Unlocks reveal at the summary, never mid-run. Pressure 1 moves ticks 25% sooner, 2 moves the first Fleet pack one tick earlier, 5 doubles the 5 s regen delay. The Mind's Warden opens braced against last run's pattern, telegraphed like any brace.

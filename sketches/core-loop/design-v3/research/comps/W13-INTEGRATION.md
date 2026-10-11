# CS-01 into wave 13: what the plan does with each borrow

Integration memo for the coordinator, 10 October 2026. Base `3c281ed` (the KF1 merge, with the CS-01 pack merged at `c2315c3`). Nothing here is applied. Every proposal below is a paste-ready block the coordinator applies after Andrew's veto window; no design source was edited.

Path conventions. Paths starting `src/`, `tools/`, `tests/`, `assets/` and `design-v3/` are under `sketches/core-loop/`, as in `K-UNITS.md:3`. `comps/` means `sketches/core-loop/design-v3/research/comps/`. `K-UNITS.md` and `P-UNITS.md` are the gitignored briefs at `artifacts/local/alpha/push/w13/design/` in the candidate checkout. `decisions.tsv:449c` to `:452c` are rows on the candidate branch after this memo's base (this base's `docs/decisions.tsv` ends at line 448). The journey pages under `design-v3/park/journeys/` are also on the candidate only (merged per `decisions.tsv:452c`).

## 1. In one paragraph

The pack changes three things in wave 13. First, the park gains one baked stage graph that turns its authored tables into measured space: a new unit, KB8, bakes it beside KB3's outputs, and spawn, pocket, home-arrival and bot-progress checks read it (row 1). Second, each stage's three activities plus one hidden pocket get placement rules by detour, checked on that graph and written into the KD stage units' acceptance (row 5). Third, the difficulty clock's cap becomes a named design constant inside KE6, which already carries the cap raise (row 3, `K-UNITS.md:267-279`). Four smaller lines land on units that have not started: a stacking and composition line and a grant-condition line for the P-C pilot units (rows 7, 8, 14), and a telegraph timing probe for the K-F Warden mechanism units (row 11). The pack does not change the authored-park model (`adr/TADR-011-park-terrain-and-warden-kinds.md:50`): the graph checks authored spawns, landmarks and activities and never moves them. It does not make the holdout the objective, does not add a credit director or music parameters before their prerequisites merge, and builds nothing for the scrap-bot crew, which stays Andrew's call (`comps/README.md:68`; `TRACKING.md:2329`). It changes no brief of a writer that is running now (section 4).

## 2. Disposition table

| Row | Borrow in six words | Scrapkeep today | Wave 13 disposition | The one measurable |
| --- | --- | --- | --- | --- |
| 1 | One baked graph, every placer reads | Authored spawn, landmark and a coarse `routes` list (`design-v3/PARK.md:53`, `:194`); bake writes heights, holes, surface, no graph (`PARK.md:238-247`) | now in KB8 (new unit, K-B wave) | Spawn's path distance to the beacon in the farthest quarter of open nodes, on every stage file |
| 2 | Credits spend spawns, dial sets income | Interval plus cap, `HARD_CAP` 24 (`src/world/director.gd:90`, `:173-179`) | next wave as KE9 (credit director, after KE6) | Credits spent within 5% of the income integral over 30 stepped minutes, 20 seeds (`comps/ror2/director-and-difficulty.md:129`) |
| 3 | One capped dial; time never gates | 45 s tiers capped at 2, spike +2 (`director.gd:83-85`, `:160-165`) | now in KE6 (cap as a named design constant) | Dial never exceeds cap plus spike, never falls, steps at most once per 45 s, over 30 stepped minutes |
| 4 | Holdout objective with boss budget | Opt-in relay holdout, 18 s in a 24 m ring (`src/world/hold_relay.gd:8-11`); the Warden posture fight is the objective (`PARK.md:414`) | rejected because the Warden posture fight is the stage objective and the clock never toughens a boss (`director.gd:7-8`) | None in wave 13 (record only, section 3d) |
| 5 | Pockets placed by detour, seen first | Three authored `activity_rows` per stage, no placement rule (`PARK.md:196`) | now in KD1 to KD6 (acceptance line; rule tested by KB8's `park_pockets_test`) | Every pocket door inside the distance rules and `sight_ok`, on every stage file |
| 6 | Small pocket library, readable on entry | No library; homes and activities are authored rows (`PARK.md:144-159`, `:196`) | parked until a stage needs more optional content than its four pockets | Idle entry takes no damage in the first 2 s in 95% of 50 runs (`comps/isaac/rooms.md:101`) |
| 7 | Named stacking families and chain control | `STACK_RULES` linear, hyperbolic, capped; `proc_coeff`; chain depth 1 (`src/build/part_def.gd:56-58`; `src/build/triggers.gd:23`) | now in PC-SABLE to PC-CANNON (acceptance line) | Stack sweep 1 to 20 copies: ceilings hold, steps shrink, zero chains deeper than 1 |
| 8 | Compose by tags, decay seen parts | Tag-pair synergies and per-stage offer decay exist (`src/build/synergies.gd:42`; `src/build/parts.gd:429-433`, `:465`) | now in PC-SABLE to PC-CANNON (tag composition only; bits and three-part sets parked until Q-P19 closes) | Zero bespoke pair code in the unit's diff: every new interaction is a `synergies.gd` row |
| 9 | Persistent scrap-bot crew with roles | One SPIL-9, two sockets (`BIBLE.md:568-570`) | Andrew's call | None until his decision |
| 10 | Slot interrupts, attack speed, sprint cancel | Stock and recharge built (`src/core/ability_state.gd:178-200`, scout extract) | parked until a playtest shows a missing interrupt | A logged cast that should have interrupted and did not |
| 11 | Long charges, one hitbox, bounded feedback | Committed telegraph is the hit geometry (`src/combat/telegraph.gd:6-22`); pack warns 1.0 to 1.1 s (`src/boss/hazard.gd:19`; `src/combat/mag_trapper.gd:33`) | now in KF2 to KF4 (timing probe) with a LEGIBILITY.md section 2 amendment | Cue within one physics tick of charge start, zero damage outside the window, 20 runs per attack class (`comps/ror2/characters-and-feel.md:94`) |
| 12 | Music follows run parameters, phrase-quantized | One `pressure` scalar gates layers (`src/presentation/music_engine.gd:511-521`); stage rows (`src/presentation/music_rows.gd:6-19`) | next wave as KE10 (run-parameter feed, after KE8) | Zero mid-phrase layer changes except flagged danger over a 5 minute trace (`comps/ror2/progression-and-music.md:106`) |
| 13 | Catalogs, one damage door, pooling | 27 validated tables in `content_registry.gd` (scout extract); six `take_damage` sites (scout extract) | parked until the native build's HF-01 conventions pass | 1,000 scripted hits through one function in the declared order (`comps/ror2/architecture.md:93`) |
| 14 | Achievements teach conditions, not grind | Grant rows on bus facts; lifetime counts such as 1000 kills (`src/core/achievements.gd:50-53`, `:89-90`) | now in PC-SABLE, PC-RIVET, PC-TARN, PC-TALLY (grant-condition line) | Zero new grant rows with a lifetime `count` above 10 |
| 15 | Trade odds remember recent trades | One-wager bet crate, seeded (`src/world/bet_crate.gd:3-14`) | parked until the four pockets pass on all six stages and TADR-010's no-durable-fact rule is revisited (`adr/TADR-010-open-stages-and-event-director.md:47`) | Safe family gone after a risk trade in 100% of simulated runs (`comps/isaac/pacing-and-trades.md:97`) |
| 16 | Measured category budgets against forge bands | Class caps in `tools/asset_budgets.json` override the toml bands (`tools/asset-forge/packs/core-loop.toml:9-11`, scout extract) | parked until the PD units report per-character sums (forge owner's call) | Zero promoted assets over their category cap, every category non-empty (`comps/ror2/production-budgets.md:137`) |
| 17 | Middleware roles checklist, OFL fonts | Three bundled OFL fonts for the browser proof (`docs/project/ASSETS.md:12`, scout extract) | parked until the native build starts | Every native font and library has an admission record (`comps/ror2/provenance.md:44`) |

Counts: now 7 (rows 1, 3, 5, 7, 8, 11, 14), next wave 2 (rows 2, 12), parked 6 (rows 6, 10, 13, 15, 16, 17), rejected 1 (row 4), Andrew's call 1 (row 9).

## 3. Proposals, paste-ready

### 3a. Row 1, the stage graph as the single spatial truth

**Target: `design-v3/PARK.md`, a new section 2.11 after 2.10 (line 233).**

```markdown
### 2.11 The stage graph

The bake has a second step. `tools/park_graph.gd` reads the park file and the bake's `ground.bin`, `holes.bin` and `under.bin` and writes `assets/park/<map_id>/graph.bin` (nodes, edges, flags and two distance fields, zstd) and `graph.json` (schema, map, the park file's and `bake.json`'s sha256, node and edge counts). The graph is the stage's one measured space. The park file stays the authored truth: the graph checks the spawn, the landmark and the activities and never moves them.

| Part | Rule (start) |
| --- | --- |
| Node | One per 8 m on the 2 m grid (every fourth cell), at the ground height, or on a hole cell at the `under.bin` floor |
| Edge | Joins 8-neighbours both ways when the climb is at most 4 m over 8 m; any drop is a one-way edge down |
| `open` | No roof above the node: the sight test's open cell (8) |
| `line` | Within 8 m of the shortest graph path from `spawn.at` through the `waymarks` in order to `landmark.beacon` (the same 8 m corridor as event rule 2, section 5) |
| `guarded` | Inside a row whose `society` is `hohokam` or `ancestral_puebloan` (the guardrail in 2.10) |
| `warden` | Inside the engage ring, `reach_m` round `landmark.beacon` |
| `door_ok` | `open`, not `line`, not `guarded`, not `warden` |
| `sight_ok` | A clear ray from 2 m above the node to a `line` node within 240 m |
| `d_landmark` | Path metres to `landmark.beacon` |
| `d_spawn` | Path metres from `spawn.at` |

Readers: the spawn and pocket checks (2.12), `director.gd`'s home arrivals (a home is ahead when its site's `d_landmark` is smaller than the ball's), the traversal tool's `progress_m`, and `tools/park_plot.py`, which draws the `line` nodes under the journey polylines. Two rules hold on every stage: every route in `routes` is a connected path in the graph through its `via` rows, so the authored graph and the measured one agree; and the spawn's `d_landmark` lies in the farthest quarter of `open` nodes. The spawn-to-beacon path over the graph's longest shortest path is reported per stage (start target 0.6), not gated.
```

**Target: `K-UNITS.md`, a new block after KB7 (line 124), in the K-B wave.**

```markdown
### KB8 Stage graph

- **GOAL.** One baked graph per park file gives every system the same measured space: path distance to the landmark and from the spawn, and the flags of PARK.md section 2.11.
- **SCOPE.** `tools/park_graph.gd` (new), `src/world/park/park_graph.gd` (new: loads `graph.bin`; `nearest(at)`, `path_m(a, b)`, `flags(node)`, `d_landmark(at)`, `d_spawn(at)`), `assets/park/park_test/graph.bin` and `graph.json`, `tests/park_graph_test.gd`, `tests/park_pockets_test.gd`.
- **CONTEXT.** PARK.md sections 2.8, 2.9, 2.11 and 2.12 (new), 3 (bake outputs, PARK.md:238-247), 5 rule 2 (the 8 m corridor, PARK.md:310) and 8 (the sight and density tests, PARK.md:478); `design-v3/research/comps/pocket-placement.md` (the spec the pocket rules scale); `comps/pocket-placement.md:58` (copy no flag bits or raycast constants).
- **ACCEPTANCE.**
  - Two runs on `park_test` give identical bytes; `park_graph_test` goes red when the park file or `bake.json` changes without a rerun.
  - Every route in the fixture's `routes` is connected in the graph through its `via` rows; a planted wall across `main` turns the test red.
  - The fixture spawn's `d_landmark` lies in the farthest quarter of `open` nodes; a planted spawn 100 m from the beacon turns the test red.
  - `park_pockets_test` holds every PARK.md 2.12 rule on the fixture and goes red on three planted rows: a door 100 m from the spawn, a door on a `line` node, a hidden pocket whose site lists one route.
  - The report prints nodes, edges, bytes, the spawn-to-beacon share of the longest path, and per pocket its `d_spawn`, `d_landmark`, detour and `sight_ok`.
- **VERIFY.** Base checks; `"$GODOT_BIN" --headless --path sketches/core-loop --script res://tools/park_graph.gd -- --map=park_test` twice, then `cmp` on the outputs; `npm run sketch:smoke -- --sketch core-loop --test 'park_graph_test' --test 'park_pockets_test'` (2 files).
- **TIMEBOX.** 4 h.
- **FORBIDDEN.** Building the graph for any of the six stage maps (their KD units run the tool); editing `tools/park_bake.gd`, `src/world/terrain.gd` or `src/world/director.gd`; deriving or moving a spawn, landmark or activity position.
- **Depends on.** KB2 and KB3 (both merged, `decisions.tsv:449c`). **Shares files with.** None. Readers adopt it in their own units: KD1 to KD6 (run the tool and both tests), KE6 (ahead by `d_landmark`), KB7 (`progress_m`).
```

**Target: `K-UNITS.md` KE6 ACCEPTANCE (line 272), one added bullet.**

```markdown
  - When the stage has `graph.bin`, a home is ahead when its site's `d_landmark` is smaller than the ball's and its graph path from the ball is 60 to 250 m; without a graph, straight distance as today.
```

**Target: `K-UNITS.md` KB7 ACCEPTANCE (line 117), one added bullet.**

```markdown
  - When `assets/park/<map_id>/graph.bin` exists, the sampler reports `progress_m`, the drop in `d_landmark` per second, beside `flow_share`.
```

Check: KB8's VERIFY above; on each stage, the KD acceptance line in 3b.

### 3b. Row 5, pockets by detour on each stage's activities

**Target: `design-v3/PARK.md`, a new section 2.12 after 2.11.**

```markdown
### 2.12 Pockets

Every stage carries four pockets: its three `activity_rows` and one hidden pocket. One activity sits on the line, an `enemy_camp` or `surge_run`, usually a waymark. The other two sit off it: one reward (`cracked_cache`) and one risk (`ambush_altar` or `hauler_bounty`). The hidden pocket is a `contraption_rows` row that opens a sealed space, a `valve` or a `cracked_wall`, with a visible tell, and its site row's `routes` lists three or more route ids. Detour is the price: the farther a pocket pulls you off the line, the more it holds, and a player who skips every pocket loses only the detour.

The rules scale the comps pocket spec (`research/comps/pocket-placement.md:30-42`) by four, the park's size against a small stage (section 1). Every distance is a path distance on the stage graph (2.11), from the door node, the graph node nearest the activity's `at`.

| Rule | Comps start | Park (start) |
| --- | --- | --- |
| Door to spawn | at least 60 m | at least 240 m |
| Door to `landmark.beacon` | at least 80 m | at least 320 m |
| Door to door | at least 50 m | at least 200 m |
| Sightline | a `line` node within 60 m | `sight_ok`: a `line` node within 240 m |
| Clear ring | 10 m round each door | 40 m round each door: no home site, no event `site` footprint, no `contraption_rows` hazard |
| Off the line | guaranteed pockets not on the shortest route | reward and risk doors are not `line` nodes |
| Detour | price grows with detour | `d_spawn(door) + d_landmark(door) - d_spawn(beacon)` is 150 to 600 m for the reward and risk pockets, about 10 to 30 s at the 20 m/s mean the stage lines assume; the reward carries the larger detour |
| Count | 3 to 5, plus one per stage, cap 8 | four on every stage in wave 13 |

The on-line activity keeps only the clear ring and the sightline. A door that fails a rule moves within its site row first; the band tables of section 8 do not move to make a pocket pass (PARK.md:476).
```

**Target: `K-UNITS.md` KD1 to KD6 ACCEPTANCE (the list at line 213), one added bullet.**

```markdown
  - `tools/park_graph.gd` run on the stage; `park_graph_test` and `park_pockets_test` green on its file: the spawn in the farthest quarter, every route connected in the graph, the four pockets inside PARK.md 2.12's distances, every pocket door `sight_ok`. VERIFY adds both tests (5 files).
```

Stage pre-check, straight-line arithmetic over the drafts (path distance is never shorter than the straight line, so these minimums already hold on the graph). Stage 1: `rim_cache` is 906 m from the spawn and 412 m from the beacon, `bench_altar` 1,209 m and 365 m, the two 568 m apart (`design-v3/park/stages/1-park_dam.md:290-292`, `:376-378`). Stage 2: `bend_cache` 835 m and 566 m, `bench_bounty` 1,169 m and 390 m, 640 m apart (`2-park_flume.md:279`, `:34`, `:360-361`). Unchecked until KB8 runs: the sightline, the detour band, and each hidden pocket. Stage 1's candidate is `gallery_valve`, which already "opens a cache pocket" (`1-park_dam.md:176`). Two likely misses for the KD units. Stage 2's `bench_bounty` is reached "only by marker; no line crosses the bench" (`design-v3/park/journeys/world-1-spillway-works.md:475`; `:508`), so `sight_ok` may fail. Stage 2 has no `ambush_altar` (`2-park_flume.md:359-361`); under 2.12 its `hauler_bounty` is the risk pocket.

### 3c. Rows 2 and 3, the difficulty dial and the credit director

The dial already exists. `effective_tier()` is the clock tier, one step per 45 s, capped at `MAX_TIME_TIERS` 2, plus `SPIKE_TIERS` 2 after a Warden break (`director.gd:83-85`, `:160-165`). It raises the cap and shortens the interval (`director.gd:173-179`), gates event rows through `clock_tier` (`PARK.md:324`), and never touches enemy health (`director.gd:7-8`, `:168-170`). KE6 already raises the cap to 4 on park stages if Andrew keeps veto item 16 (`K-UNITS.md:267-279`; `PARK.md:592`). Two corrections the coordinator should carry. The comps pack files the cap under Q-P24 (`comps/README.md:38`), but Q-P24 is "World terrain and consequence mechanics" (`BACKLOG.md:3132`); the open item is TADR-010's unnumbered "whether a threat clock exists, its shape" (`adr/TADR-010-open-stages-and-event-director.md:63`). And `director.gd:9` still says "The clock's tier is clamped at +2", which KE6 makes false on park stages.

**Target: `design-v3/PARK.md` section 5, replace the "Triggers" paragraph's first sentence (line 324) with this paragraph.**

```markdown
**The dial.** `clock_tier` reads the director's `effective_tier()`: the clock tier, one step every 45 s up to `MAX_TIME_TIERS` (2 on the alpha table, 4 on park stages with veto item 16), plus 2 after a Warden break (`director.gd:83-85`, `160-165`). The cap is a design constant chosen with the stages, not a tuning knob: it changes only with a dated decisions row. The dial raises how many enemies come and how soon (`cap()`, `interval()`) and which event rows may fire. It never raises enemy health, a price or a Warden's numbers (`director.gd:7-8`; TADR-010:45).
```

**Target: `K-UNITS.md` KE6, SCOPE gains the comment fix and ACCEPTANCE gains one bullet (lines 270 and 272).**

```markdown
- **SCOPE.** ... plus the honesty comment at `director.gd:9`, which states the cap by constant name, not by number.
  - Over 30 stepped minutes on `--table=park`, 20 seeds: `effective_tier()` never exceeds `MAX_TIME_TIERS + SPIKE_TIERS`, never falls within a stage, and steps at most once per 45 s; `hp_scale()` equals the stage threat at every step.
```

**Target: `K-UNITS.md`, a new block after KE8 (line 301), marked next wave.**

```markdown
### KE9 Credit director (next wave)

- **GOAL.** On `--table=park`, arrivals are paid from a credit balance the dial refills, so density is a rate; the alpha table keeps today's interval and cap.
- **SCOPE.** `src/world/director.gd` (a `credit` mode beside `interval`), `src/world/director_cards.gd` (new: one card per pack with `cost`, `weight`, `stage_cap`; elite as a cost multiplier), `tests/director_credit_test.gd`, `tools/bot_run.gd` (a `--director=interval|credit` flag only).
- **CONTEXT.** `comps/ror2/director-and-difficulty.md` (shape only; its constants are not copied, `:123`); `director.gd:86-115`, `:172-179`, `:287-296` (elite repeat); `posture_bands_test` and the open pin (`decisions.tsv:451c`).
- **ACCEPTANCE.**
  - Income per second is `I0 * (1 + K * effective_tier())`; `I0` and `K` are calibrated so tiers 0 and 2 match today's mean arrivals per minute on stage 1 within 10%.
  - Credits spent stay within 5% of the income integral over 30 stepped minutes, 20 seeds.
  - Never more than `HARD_CAP` 24 alive; health still from the stage threat only.
  - `posture_bands_test` and `alpha_posture_bands_test` green and unchanged.
  - The lab spawner arm (section 6) reported, both modes.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'director_*_test' --test 'world_director_test' --test 'posture_bands_test' --test 'alpha_posture_bands_test'` (expected 6 files with `director_credit_test`).
- **TIMEBOX.** 4 h.
- **FORBIDDEN.** Changing the alpha table's director; any price or health scaling by the dial.
- **Depends on.** KE6 merged and the posture_bands pin decided. **Shares files with.** `director.gd` (after KE6).
```

### 3d. Row 4, the holdout read against the Warden posture fight

**Target: `design-v3/PARK.md` section 7, a closing paragraph after the Resist bullet (line 422).**

```markdown
**What the comps holdout gives the Warden.** Two of its relationships already live here, and the rest stay out. Charge by presence is the relay: roll into a 24 m ring and it charges for 18 s, pausing, never resetting, when you leave (`hold_relay.gd:8-11`), and it is opt-in, so skipping it never holds the exit (`event_director.gd:10-15`). The dial's reach into the fight is the post-break spike, which adds packs and never toughens anything (`director.gd:7-10`). Three things stay out. A holdout as the stage objective: the Warden posture fight is the objective, and a ring you must stand in fights "never stop the ball" (section 5 rule 2). A boss budget by the dial: posture bands are tuned per kind and pinned by test (LEGIBILITY section 4; `tests/posture_bands_test.gd`). Shrine stacks that multiply the reward: time and risk may not price a cache (TADR-010:45). A stay-or-leave choice after the relay charges is a candidate relay field for a later wave.
```

### 3e. Rows 7 and 8, stacking families and composition for the pilot kits

**Target: `P-UNITS.md` section 2, the common rules list for all six PC units (after line 236), one added bullet.**

```markdown
- **Stacking and composition (comps rows 7 and 8).** Every part, relic or tree node the unit adds names a `stack_rule` from `PartDef.STACK_RULES` (`src/build/part_def.gd:56`); anything that could reach 100% is `hyperbolic` or `capped`, never uncapped linear and never exponential. A proc it adds carries `proc_coeff` 1 on a direct heavy hit and 0.2 to 0.35 on a child effect (start). No proc re-enters its own trigger (`upgrade_tree.gd` `_proc_loop`, `:344`), and chains stay within `Triggers.MAX_CHAIN_DEPTH` 1 (`src/build/triggers.gd:23`). New pairs interact through part tags and `synergies.gd` rows, never through bespoke pair code. The unit's own test gains a stack sweep: 1 to 20 copies of each new stacking part, every `hyperbolic` value under its ceiling with steps that never grow, zero chains deeper than 1.
```

Not in wave 13: the per-hit proc-type mask (only one chaining part ships, `src/build/item_effects.gd:562-577`, scout extract), the bit layer, and the three-part transformation. Stacking is Q-P19's question (`adr/TADR-008-ability-contract.md:24`; `BACKLOG.md:3062`).

### 3f. Row 11, the telegraph grammar against LEGIBILITY.md

Present in LEGIBILITY.md: the threat row (hazard floor with fill progress, wind-up pose, warn sound; `design-v3/LEGIBILITY.md:52`), per-kind wind-up cues (`LEGIBILITY.md:120-127`), the hazard colour law (`LEGIBILITY.md:21`), and holds only after a dodgeable telegraph (`LEGIBILITY.md:133`). In code, not in LEGIBILITY: the 1.0 s warn floor (`hazard.gd:19`), the committed geometry rule (`telegraph.gd:6-10`), the shake caps of 1.2 and 0.6 (`src/movement/chase_camera.gd:27-29`) and the hitstop clamp (`src/presentation/juice.gd:355`). Missing from both: a timing probe. Not adopted: scaling charges by attack speed, because no attack-speed stat exists (scout grep, one pattern); and melee-only hitstop, which would change feel and goes to his sitting.

**Target: `design-v3/LEGIBILITY.md` section 2, a paragraph after the "One rule per meaning" paragraph.**

```markdown
**Telegraph timing.** An enemy attack warns for at least 1.0 s (`src/boss/hazard.gd:19`); pack kinds stay at 1.0 to 1.1 s, and a charge longer than 3 s belongs to a Warden or a miniboss. The warn sound, the wind-up pose and the floor fill start on the same tick, and damage comes only from the committed telegraph, only inside its live window (`src/combat/telegraph.gd:6-10`). Feedback is bounded: camera shake never exceeds the active camera row's `shake_cap` (1.2, and 0.6 in a Warden fight, `chase_camera.gd:27-29`), and hitstop stays inside its row's clamp (`juice.gd:355`). `tests/telegraph_timing_test.gd` holds each line.
```

**Target: `K-UNITS.md` KF2 to KF4 ACCEPTANCE (line 338), one added bullet.**

```markdown
  - `tests/telegraph_timing_test.gd` (KF2 creates it with the six pack kinds; KF3 and KF4 add rows after KF2 merges): over 20 runs per attack, the cue starts within one physics tick of the charge, the charge length is within one tick of its row, zero damage lands outside the live window, and 30 hits in 3 s keep shake under the camera row's cap.
```

### 3g. Row 12, music parameters against the journeys and `music_rows.gd`

The journeys tie music to place and to events: calm keys on the shelf, the full groove on `first_drop`, a one-bar dip at the Eye, the B section on the canyon floor, the Warden's pedal at the vents, the pivot to 129 at the fight (`world-1-spillway-works.md:477-484`; `1-park_dam.md:217-237`). KE8 adds those as `CUES` (`K-UNITS.md:292-301`). The engine has one continuous input, `set_pressure` (`music_engine.gd:511-521`). Comps row 12 fills the space between cues. The stage graph supplies the objective-distance parameter for free.

**Target: `K-UNITS.md`, a new block after KE9, marked next wave.**

```markdown
### KE10 Run parameters for the score (next wave)

- **GOAL.** Between the stage's cues, the score follows three run parameters sampled every 0.25 s, and every layer change waits for a phrase except flagged danger.
- **SCOPE.** `src/presentation/music_engine.gd` (a parameter sampler and phrase quantizer), `src/presentation/audio.gd` (the feed), `tests/music_params_test.gd`.
- **CONTEXT.** BIBLE.md:755 ("Resolve arrangement changes at phrase boundaries when play allows. Danger must never wait for a beat."); `comps/ror2/progression-and-music.md:49-56`, `:106`; the journey pages' music rows; KE8's `CUES`; B3's `set_ultimate_lift`.
- **ACCEPTANCE.**
  - `threat` = proximity 0.75 plus look 0.25 of live enemies, feeding today's `set_pressure`.
  - `approach` = 1 minus `d_landmark` over the spawn's `d_landmark` (stage graph), opening the landmark hum layer toward the Warden.
  - `health` below 0.3 strips to drums and bass until healed (start).
  - Over a 5 minute recorded trace: zero values out of range, zero mid-phrase layer changes except rows flagged `danger`, busiest layers released within one phrase of a Warden break.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'music_params_test' --test 'music_rows_test' --test 'presentation_music_test'` (3 files).
- **TIMEBOX.** 3 h. **FORBIDDEN.** New music assets; changing a cue KE8 owns.
- **Depends on.** KE8, B3 and KB8 merged.
```

### 3h. Row 14, achievements as a teaching surface against CUSTOMIZE.md's grants

CUSTOMIZE.md section 8 gives each pilot three grants. Five of them are lifetime counts: 20 Cable Runs, 50 Line Drive punches, 50 machines dragged, 50 ledger clips, 100 clips settled (`design-v3/CUSTOMIZE.md:345`, `:353`, `:371`, `:379`, `:380`). The rest are conditions met in one moment, such as "Land one Foundry Cutter on six machines" (`CUSTOMIZE.md:355`). The comps rule is to show the condition and never a grind count (`comps/ror2/progression-and-music.md:99`). A per-run count already has a route: kit code marks a discovery, as Rivet's 30 ignored hits in one run do (`CUSTOMIZE.md:354`). Existing lifetime rows (`kills_100`, `kills_1000`, `ach_d7_paw`, `ach_d7_seashell`, `achievements.gd:50-53`, `:89-90`) stay until their cosmetics get new rows, because every non-starter cosmetic must be one row's reward (`CUSTOMIZE.md:96`).

**Target: `design-v3/CUSTOMIZE.md` section 3, "Grant rows", a third numbered change.**

```markdown
3. **A new grant names a condition, not a grind.** A row added from wave 13 on is met in one run or one moment: a discovery the kit detects, a `count` of 10 or less, or a run-summary condition. A lifetime count above 10 is refused by `validate` for new ids; the rows that predate the rule are listed by id in `GRANDFATHERED` until their cosmetics are re-granted.
```

**Target: `CUSTOMIZE.md` section 8, the five count rows reworded (each becomes a discovery the PC unit detects).**

| Row | Was | Becomes (start) |
| --- | --- | --- |
| `ach_sable_cable_runs` | Land 20 Cable Runs across your runs | Land three Cable Runs in one run |
| `ach_rivet_line_true` | Land 50 Line Drive punches | Land ten Line Drive punches in one stage |
| `ach_tarn_dragged` | Drag 50 machines into your claws | Drag ten machines into your claws in one stage |
| `ach_tally_punch_tape` | Fire the ledger clip 50 times | Fire the ledger clip ten times in one stage |
| `ach_tally_eyeshade` | Settle 100 clips with Plate Return | Settle twenty clips with Plate Return in one run |

**Target: `P-UNITS.md` PC-SABLE, PC-RIVET, PC-TARN and PC-TALLY ACCEPTANCE, one added line each.**

```markdown
  - Its count grants follow CUSTOMIZE section 3 change 3: each is a discovery the kit detects within one run or stage, its codex row declared, and `grant_grammar_test` green.
```

Parked from row 14: the logbook page over `codex.gd` entries and the schema 4 `seen` list, and run tallies. No unit owns either (`P-UNITS.md` and `K-UNITS.md` by grep, scout extract).

## 4. Collisions with in-flight work

| Running work | Does a proposal change its brief? | Line to send on hand-back |
| --- | --- | --- |
| Skill-bar step 2: B2 HUD, B3 ultimate, B4 bot adapter, B6 discovery (`P-UNITS.md:122-213`; `docs/decisions.tsv:445`) | No. KE10 waits for B3's `set_ultimate_lift`; the P-C lines in 3e and 3h start after P-B closes (`P-UNITS.md:240-250`) | None |
| The six pilot mechas, PD-SABLE to PD-CANNON (`P-UNITS.md:331-437`) | No. The row 16 budget deltas stay with the forge owner until the per-character sums report | None |
| The journey pages, merged on the candidate with open follow-ups: new panel briefs and the gaps in each section 7 (`decisions.tsv:452c`) | Only their next edit, not their beats. Row 1 gives `tools/park_plot.py` the `line` nodes; row 5 gives each activity a class; row 12 later reads their music rows | "Tag each activity in section 6 as on the line or a pocket, name its first sighting by park row id, and leave every distance to KB8's pocket test; no beat changes." |

Units that change but are not running, so their briefs are amended before dispatch, not messaged: KB7, KE6, KD1 to KD6, KF2 to KF4, PC-SABLE to PC-CANNON. KD1 to KD6 also depend on Andrew's journey approval (`K-UNITS.md:222`). The posture_bands pin stays open (`decisions.tsv:451c`); no wave 13 proposal moves a posture band.

## 5. Veto list for Andrew

Calls this memo makes under the creative charge. Each is a default.

1. The stage graph joins wave 13 as KB8, ahead of the stage greyboxes; the park file stays the authored truth and the graph only checks it.
2. Spawns stay authored. The graph checks that each spawn sits in the farthest quarter from the Warden and never moves it.
3. Pocket distances are the comps starts times four for a park four times the size: 240 m from the spawn, 320 m from the beacon, 200 m apart, sightline 240 m, a 40 m clear ring.
4. Every stage has four pockets: one activity on the line, a reward and a risk off it, and one hidden pocket opened by a contraption with a tell. No growth per stage in wave 13.
5. Stage 2's hauler bounty counts as its risk pocket, so stage 2 needs no ambush altar.
6. The difficulty cap is a named design constant (2 on the alpha table, 4 on parks) and changes only with a dated decision.
7. The credit director waits for KE6 and goes next wave behind a lab arm; the 24-enemy hard cap stays.
8. The holdout is not the objective, and the Warden gets no boss budget from the dial.
9. Stacking stays at three families with chain depth 1; no exponential family and no proc mask until a second chaining part ships.
10. Hitstop stays as it is; melee-only hitstop waits for your sitting.
11. Five pilot count grants become one-run conditions (the table in 3h); old lifetime grants stay until their cosmetics move.
12. Music parameters wait for the cue table and the graph, next wave.

Andrew's own open decision, not made here: the scrap-bot crew against the Bible's one companion (`BIBLE.md:566-575`). Nothing is built in wave 13 either way.

## 6. Lab arms

The project's Jev lab (`.agents/skills/scrapkeep-lab/SKILL.md`) runs the ball lab and two stage labs, `cable-bench` and `spillway-drop` (`scripts/lab/metrics/index.mjs:81-90`), and its Jev arm is parked as a player (`SKILL.md:60`). None of it reads a park stage. The three arms therefore run on the core-loop headless tools with scripted bots: `tools/bot_run.gd` with `tools/balance_report.gd`, `tools/traversal_line.gd`, and the new `tools/park_graph.gd`.

| Arm | Where it runs | Measure | Pass line |
| --- | --- | --- | --- |
| Spawner: today's interval director against the credit director with the capped dial | `tools/bot_run.gd --table=park --director=interval` and `--director=credit` (KE9 adds the flag), stage 1, six pilots, 20 seeds each; `balance_report.gd` reads both | Time to first pressure (first second with 4 or more enemies within 60 m of the ball); peak enemies alive; credits against the income integral | Credit arm: peak at most 24 on every seed; median time to first pressure within 20% of the interval arm; credits within 5% of the integral; posture bands unchanged |
| Pocket: the 2.12 rules against uniform placement | `tools/park_graph.gd --pockets=rules` and `--pockets=uniform` over the six stage files, 1,000 seeds that jitter each door among its site row's `door_ok` nodes; `traversal_line.gd` supplies the pilot lines | Share of pocket doors with a clear ray from some pilot line tick within 240 m; re-roll rate | Rules arm: every door seen from at least one pilot line on 95% of seeds; zero distance violations; re-roll rate at most 20% (`comps/pocket-placement.md:62`) |
| Companion: a persistent, repairable crew against stage-bound summons | Not mapped | Damage share and losses per stage (`comps/README.md:76`) | Parked with row 9 until Andrew decides |

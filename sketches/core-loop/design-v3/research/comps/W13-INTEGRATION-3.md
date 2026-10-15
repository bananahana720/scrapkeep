# CS-01 to CS-03 adopted: the wave 13 build plan for every comps borrow

Integration memo for the coordinator, 11 October 2026, the third in the series after `W13-INTEGRATION.md` (CS-01, Risk of Rain 2 and The Binding of Isaac, "the first memo") and `W13-INTEGRATION-2.md` (CS-02 Gunfire Reborn and CS-03 Roboquest, "memo 2"). Base `4701b10`. It re-dispositions every proposal the per-note scouts drew from the four pack notes and the two cross-pack notes under Andrew's rule of 11 October, and turns each adopted borrow into a unit block, a paste block for an existing unit, or a scheduled line. Nothing here is applied: the coordinator dispatches the units and applies the paste blocks; no design source, brief, budget file or forge pack was edited.

Path conventions are memo 2's (its line 5). Paths starting `src/`, `tools/`, `tests/`, `assets/` and `design-v3/` are under `sketches/core-loop/`, except `tools/asset-forge/`, which is at the repository root, and `scripts/`, which is the repository's own. `comps/` means `sketches/core-loop/design-v3/research/comps/`. `K-UNITS.md` and `P-UNITS.md` are the gitignored briefs at `artifacts/local/alpha/push/w13/design/` in the candidate checkout. `decisions.tsv:473c` to `:487c` are rows on the candidate after this base (this base's `docs/decisions.tsv` ends at line 472). Names from the four games are evidence labels only; nothing from them (code, text, layout, art) enters the repo (`docs/project/ASSETS.md:23`). Every number the notes measured is a start value the unit's lab line tests, never a copied constant.

## 1. The rule and what changed

The first two memos read the packs as advisory and parked 20 and rejected 7 of their 73 borrow rows. Andrew's rule (`decisions.tsv:473c`) reverses the default: a borrow is adopted and scheduled unless (a) a named Bible or ADR line conflicts with it, quoted with its path and line, (b) a hard dependency must land first, named, which makes it next push, or (c) only Andrew can decide it: a download of third-party assets, a Bible amendment, or the crew. "Not tuned yet", "authored today", "no card exists", "would bypass the storyboard gate" and "comps start values" are no longer reasons to park; the notes' lab measures become each unit's acceptance. Three owner rulings from the same day shape the plan: free CC0 and CC-BY base meshes may seed enemy units once provenance is recorded per TADR-003, which moves PD-PROV into this push (`decisions.tsv:474c`); the adopted borrows are built in this push, Gunfire Reborn and Roboquest systems first, on a new systems lane S (`:475c`); and the alpha keeps one SPIL-9, with the scrap-bot crew after the alpha merge and its Bible amendment by ADR (`:476c`). Since the base, the three world journeys were approved as written (`:481c`), so the greyboxes no longer wait on a storyboard.

Two terms are used throughout. **This push**: the borrow rides a unit already in the wave 13 plan, or it is a new unit that can start now, with a Shares line for any file an in-flight unit holds. **Next push**: a named unit must land first; it is still scheduled, and section 8 places it in a wave. Section 5 holds only ADR-blocked rows; a row blocked only by a Bible line is an owner item in section 6, with amendment text and a default.

| Pack | Earlier memo | Earlier parked | Earlier rejected | Scout proposals | This push | Next push | Blocked | Owner | Done |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Gunfire Reborn (CS-02) | memo 2 | 7 | 3 | 52 | 8 | 37 | 0 | 3 | 4 |
| Roboquest (CS-03) | memo 2 | 7 | 3 | 54 | 19 | 27 | 0 | 4 | 4 |
| Risk of Rain 2 (CS-01) | first memo | 4 | 1 | 82 | 16 | 45 | 2 | 3 | 16 |
| The Binding of Isaac (CS-01) | first memo | 2 | 0 | 27 | 1 | 19 | 1 | 0 | 6 |
| Pocket placement (cross-pack) | none | | | 15 | 0 | 11 | 0 | 0 | 4 |
| Maps compared (cross-pack) | none | | | 3 | 0 | 1 | 0 | 0 | 2 |
| **Total** | | **20** | **7** | **233** | **44** | **140** | **3** | **10** | **36** |

The earlier memos counted README borrow rows; this memo counts the scouts' proposals, finer grained, so the columns compare outcomes, not rows. Of 233 proposals, 184 are adopted and scheduled (44 this push, 140 next push), 36 are already in code or in a merged or in-flight brief, 10 wait on Andrew under rule (c) and 3 are blocked by an ADR line. The new work is 58 units on lane S (section 3), PD-PROV promoted into this push, and paste blocks for 18 existing units (KF2 to KF4, KE1, KE4, KE6, KE8, KE9, KE10, KD1 to KD6, PC-POOL, PD-INT, PE-INT), the PC, PD and PE common rules, both dispatch tables and the forge pack (section 4).

Where each earlier parked or rejected row went:

| Earlier row | Was | Now |
| --- | --- | --- |
| memo 2 row 18; 29a (world pool) | parked | SQ14 pocket draw; SQ12 library |
| memo 2 row 20a, one major event per world | rejected | KE1 line, this push (paste 4b) |
| memo 2 row 20b, pocket hazards off on clear | parked | SQ5 |
| memo 2 row 20c, health and damage on tier curves | rejected | SG11, on the opt-in run tier only; tier 0 keeps health from the stage threat |
| memo 2 row 21, burden parts paid by count | parked | SG4, SG5 |
| memo 2 row 23, marks, fusion, named pools | parked | SG1, SG2, SG3 (fusions use today's three elements; a new element still waits for Q-P13) |
| memo 2 row 24a, three levels, higher replaces | rejected | SG15, as a `capped` stack of 3, not a fourth rule |
| memo 2 row 24c, forced-or-skip late offer | parked | SG8 |
| memo 2 row 25a, elite affixes | parked | SG6 |
| memo 2 row 26, forge budget point | parked | SQ18 (conditional on the C5b sums) |
| memo 2 row 27, closable sockets | parked | SQ13, SQ15 |
| memo 2 row 29a, secret tint | parked | SQ16 |
| memo 2 row 30b, scattered-mark objective | parked | SQ5, an optional objective kind that never gates the exit (Q-P38 stays open) |
| memo 2 row 31a, fast wind-up bands | rejected | SQ1 band classes, every kind still at or above the 0.4 s floor |
| memo 2 row 31e, one stagger window | parked | SQ3, pack kinds only; the Warden keeps its 4.0 s posture break |
| memo 2 row 31f, elite flat stat tier | rejected | SG6's tier-1 row |
| memo 2 row 32a, chassis families | parked | SQ4; family bands report in SQ18 |
| memo 2 row 33a, speed bank, refunds, uptime | parked | SQ9, SQ6, SQ7; the 60 fps capture is a hands item (section 6) |
| memo 2 row 34, two-layer build, envelopes, weighted offers | parked | SG3, SQ10, SQ11, SQ19 |
| memo 2 row 35b, 4,096 textures by exception | rejected | SQ17's exception field; no character texture over 2,048 without it |
| first memo row 4, holdout with boss budget | rejected | SR9, SR10 and KE9's miniboss credit line |
| first memo row 6, pocket library | parked | SQ12 |
| first memo row 10, interrupts, attack speed, sprint cancel | parked | SR3 |
| first memo row 13, catalogs, one damage door, pooling | parked | SR1, SR2 (catalogs are done, `src/core/content_registry.gd:28`) |
| first memo row 15, trade odds remember | parked | SI1 |
| first memo row 16, measured category budgets | parked | SQ17 |
| first memo row 17, admission record for fonts and libraries | parked | PD-PROV's extended fields (paste 4e), this push |

## 2. Adoption table

One row per scout proposal, merged where two notes propose one system (every merged id is named in the first cell). Dispositions: `this push` (rides a unit already in the wave 13 plan, or a new unit that can start now with a Shares line for any in-flight file), `next push` (a named unit must land first; section 8 places it), `blocked` (an ADR line, quoted in section 5), `owner` (Andrew's call, both branches in section 6), `done` (in code, or in a brief that is merged or in flight). Wave letters are section 8's. The fifteen pocket-placement proposals and the three maps-compared proposals each duplicate a pack note's system, so every one of them is merged into a row below and named in its first cell; section 1 still counts them under their own note. Note cites are `comps/<note>:<line>`; a `Lab measure` heading's paragraph sits two lines below it.

### Gunfire Reborn (CS-02)

| Ids | What, with the note's numbers | Disposition | Lands in | Wave | Lab measure and pass | Dependency |
| --- | --- | --- | --- | --- | --- | --- |
| gunfire/elements-and-fusion:arc-mark-all-sources | Arc marks a target with a timed status that raises damage from every source (note: shock +10% for 5 s, start), drawn on the committed telegraph geometry; generalizes the plate exposure that boosts contact strikes only (`src/combat/combat.gd:240-245`, `:573`) | next push | SG1 | F | Dummy hit by arc, then by contact, projectile, area and companion: each rises by the declared fraction while marked and returns on expiry; mark shape equals committed geometry; no extra hit | SR1 (one damage door, so "every source" is true), PC-CANNON |
| gunfire/elements-and-fusion:fusion-grid-resolve-once; gunfire/elements-and-fusion:elite-boss-immunity-stated; gunfire/heroes-and-ascensions:one-damage-table-all-layers | A second status on a marked enemy fuses once, same in either order, as rows of the TADR-009 table (`src/build/elements.gd:3-15`); control fusions state elite and boss immunity; sustained fusions hit elites for at most 10%; one multiplier table (note: 150 / 100 / 75 percent) read by every protection layer | next push | SG2 | G | Fusion pairing test (`comps/gunfire/elements-and-fusion.md:85`): both orders identical; preview at least 12 frames before damage and equal to the damage area; elite dummy takes no control effect and at most 10% of the normal dummy's sustained damage; every layer reads the one table | SG1, SG7 |
| gunfire/elements-and-fusion:named-pools-and-resistance-cap; gunfire/scrolls-and-synergies:two-layer-build-labels; gunfire/scrolls-and-synergies:family-cap-shown; gunfire/weapons-and-inscriptions:milestone-slot-growth; gunfire/weapons-and-inscriptions:class-tradeoff-line | Build screen names each bonus's pool (additive or multiplying) and the resistance cap (value open; the note's +90% is another game's); labels each part weapon-local or player-global with the stats a global part reads; shows a family's cap; shows the depth-by-world table (depth 2 in world one, 3 and 4 later, `BIBLE.md:432`, `:538`); one trade-off line per pilot class | next push | SG3 | B | Readout test: every shown pool equals the simulated result; resistance never above its cap; 100 percent of parts tagged local or global; every class card shows one trade-off line inside `ui_word_budget_test`'s budget | B2, B6 (the card and tree card files) |
| gunfire/scrolls-and-synergies:burden-parts | A rare burden part is a pure stated downside, offered only in a visible optional pocket; hot-wired parts may be held more than one at a time from world 2 (today one held, `src/build/parts.gd:187-196`, `:288-302`) | next push | SG4 | B | Burden sweep step 1 (`comps/gunfire/scrolls-and-synergies.md:86`): 0 to 10 burdens; each burden shows a cost icon and at most three words in the hot-wired row shape; 5 burdens survive a fixed scripted encounter at least as often as 0 | KD8 (pocket pay names the part) |
| gunfire/scrolls-and-synergies:burden-count-payout | A payout part reads the burden count through the ceiling curve `1 - 1/(1 + a*x)` (`comps/README.md:55`), cap shown on the part and the build screen | next push | SG5 | C | Burden sweep step 2: payout below its cap at every count, step from n to n+1 never grows, net power at 10 burdens at most 3x the zero-burden build | SG4 |
| gunfire/enemies-and-bosses:affix-named-on-enemy; gunfire/enemies-and-bosses:act-scaled-constants; roboquest/enemies-and-telegraphs:elite-flat-stat-tier | An elite carries one added behaviour plus one stat change and its name lists both; the stat steps in three published values per world (note shape: -40/-50/-60 percent defence, 10/20/30 percent shield; Scrapkeep sets its own), never health from the dial; a flat elite stat tier exists only on the opt-in run tier | next push | SG6 | G | 50 solo spawns per affix per world step: telegraph lead at least 0.4 s; exactly 1 behaviour and 1 stat per name; 3 published values per constant, monotone, at or under the cap; each affixed row still passes the no-reskins test (`src/combat/roster.gd:12-15`) | KE6, KE9 |
| gunfire/enemies-and-bosses:boss-phase-one-new-read | Each Warden gate adds exactly one new mechanic or ends one plating state; the gates are the existing posture events (`engaged`, `stagger`, `chunk_1` to `chunk_3`, `broken`) | this push | KF2 to KF4 (paste 4a) | A | Per kind, stepped bot run over 20 seeds: each gate activates exactly 1 new mechanic; posture band unchanged (grown median 25 to 45 s) | KF1 (merged) |
| gunfire/enemies-and-bosses:threat-rating-per-enemy | One coarse integer threat number per enemy, read as the director card cost | this push | KE9 card `cost` (`K-UNITS.md:346`) | F | KE9's credit and posture checks | KE6 |
| gunfire/enemies-and-bosses:telegraph-marker-vocabulary | Marker by meaning (circle for area, line for lunge, text for a delayed devour), the same geometry as the damage shape, applied to every pack kind | next push | SQ1 | C | 50 solo spawns per pack kind: one marker class per attack; overlap at least 95 percent | KF2 report (SQ1 writes its own `telegraph_timing_pack_test.gd`, `decisions.tsv:486c`) |
| gunfire/enemies-and-bosses:telegraph-lead-and-overlap-lab-measure; roboquest/enemies-and-telegraphs:telegraph-shape-matches-damage | Lead from telegraph start to damage at least the reaction floor (target 0.4 s), telegraph and damage areas overlap at least 95 percent, zero archetypes outside (`comps/gunfire/enemies-and-bosses.md:89`) | this push | KF2 to KF4 overlap line (paste 4a); pack kinds in SQ1 | A | 50 spawns per archetype: lead at least 0.4 s, overlap at least 95 percent | KF1 (merged) |
| gunfire/enemies-and-bosses:three-defence-bars | Armour, shield and health read as three bars with one rule each (armour breaks at zero and does not regenerate; shield regenerates after a delay) | this push | SG7 | A | Each defence state shows exactly one bar class, each class one regen rule, zero shared colours | None |
| gunfire/enemies-and-bosses:elite-in-pocket-clears-pocket | An elite sits in an optional pocket; killing it clears the pocket's remaining enemies | next push | SQ5 (elite arena kind) | F | 20 seeds per stage: zero pocket enemies alive 1 s after the elite dies; elite arrivals per stage at most 3 | KD8, KE6 |
| gunfire/heroes-and-ascensions:identity-weighted-pools; roboquest/classes-and-perks:class-weighted-offers; roboquest/classes-and-perks:neutral-repeat-shelf | Each pilot draws from a pool weighted to its own kit (declared share 60 to 80%) plus a neutral fallback shelf of flat small parts (sources 6% to 12%) with a repeat cap | next push | SQ19 | F | 200 draws per pilot, greedy and random bot (`comps/roboquest/classes-and-perks.md:82`, `comps/gunfire/heroes-and-ascensions.md:87`): weighted share in 60 to 80%; top-10 overlap between any two pilots under 50%; each pilot's two dominant offer buckets differ from every other pilot's pair; movement share at most 15%; neutral repeat cap held; each pilot wins at least 3 of seeds 1 to 4 | PC-POOL |
| gunfire/heroes-and-ascensions:movement-out-of-pool; roboquest/classes-and-perks:movement-in-kit-not-pool | The five shared mobility parts (`grip_tread`, `live_line`, `vent_baffle`, `spring_shims`, `drop_weight`, `src/build/parts.gd:52-74`) become class parts or non-movement mods | next push | PC-POOL (paste 4c, scheduled) | E | `parts_pool_movement_test`: zero shared parts with a movement mod in 200 offer draws per pilot (5 of 18 today) | PC-PACK |
| gunfire/heroes-and-ascensions:three-level-replace | Parts pick in three levels, a higher level replacing the lower | next push | SG15 | G | Offer draws with level state: no offer of a part at level 3; each pilot wins at least 3 of seeds 1 to 4 | SQ19 (same file) |
| gunfire/heroes-and-ascensions:forced-or-skip-late-offer | A late-world offer the player takes or skips, never rerolled, at safe grounded moments on depth-4 offers | next push | SG8 | D | 200 draws per pilot: skip always available and free; no offer reappears after a skip within the run | PC-SABLE to PC-CANNON (depth-4 nodes) |
| gunfire/heroes-and-ascensions:run-start-pick-of-three | At run start the player takes one of three drawn small options, one reroll, from the pilot's own list | this push | SG9 | A | 200 run starts per pilot: time to first input unchanged within noise; no option raises a movement knob; each of 3 options taken at least once | None (B5 merged) |
| gunfire/run-pacing-and-economy:price-ladder-by-stage | One reference item's shelf price non-decreasing across a region's stages and jumping at each region boundary (price to income 0.5 to 2.0, 3 regions, 20 seeds, `comps/gunfire/run-pacing-and-economy.md:104`) | owner | Section 6 item 4 (the numbers); SG16 measures today's prices now | B | SG16's price-to-income report | Andrew: prices are open (`BIBLE.md:513`; `adr/TADR-010-open-stages-and-event-director.md:63`) |
| gunfire/run-pacing-and-economy:opt-in-tier-pays-more; gunfire/scrolls-and-synergies:enhanced-variant-keeps-slot | A player-chosen harder run tier, unlocked by a win, raises threat and pay together, shown before the choice; on it a part may come as an enhanced variant (same slot and rarity, bigger bonus or smaller downside, one version held) | next push | SG10 | G | Park table at tier 0 and tier 1, 20 seeds each: tier 1 raises both threat and pay on every seed; pay gain under its cap; tier 0 numbers unchanged | KE9, SG4 |
| gunfire/run-pacing-and-economy:separate-hp-damage-dials; gunfire/stage-anatomy:difficulty-adds-to-same-map; roboquest/enemies-and-telegraphs:three-axis-scaling; ror2/director-and-difficulty:boss-scaling-by-dial | Enemy health and enemy damage on two named capped dials with a per-world step, aggression as its own axis, route unchanged across tiers; active only on the opt-in tier, so tier 0 keeps `hp_scale()` equal to the stage threat (`src/world/director.gd:168-170`); Warden scaling by the dial (note shape `1 + D/2.5` health, `1 + D/30` damage) also opt-in only | next push | SG11 | H | Each axis swept alone: moves only its own quantity, never above its cap; hp and damage curves independent (one change leaves the other bit-identical); route and pocket list identical across tiers; tier 0 equals today | SG10, KE6 |
| gunfire/run-pacing-and-economy:meta-options-tree; roboquest/stage-anatomy:secret-reward-unlocks-later | A between-run tree of small non-power head starts (an extra reroll, a pre-shown shelf, a pocket key); a hidden pocket may hold a permanent option unlock. Each node opens on a one-run accomplishment, not a meta currency, because `BIBLE.md:513` bars "replacement collection thresholds" and "invented prices"; the currency form is section 6 item 4 | next push | SG12 | B | Five simulated runs: no node row carries a price, cost or stat key that changes combat power; level equals nodes opened; the profile round-trips; no stat field differs from a fresh profile | B6, KD8 |
| gunfire/run-pacing-and-economy:meta-start-cogs-discount-nodes | Permanent starting cogs (100 to 500), double-cog chance, 5 to 25% shop discount | owner | Section 6 item 5 | | | Bible amendment (`BIBLE.md:475`, `:586`); default keep |
| gunfire/run-pacing-and-economy:reset-run-currency | Run currency resets at run end | done | `src/core/run_state.gd:159` (`cogs = 0`) | | Two runs: cogs 0 at every run start over 20 seeds | None |
| gunfire/run-pacing-and-economy:optional-graded-challenge-pocket; gunfire/stage-anatomy:four-kind-arena-ladder; roboquest/stage-anatomy:pocket-kind-content-bundles; pocket-placement:content-bundle-per-pocket-kind; pocket-placement:pocket-grammar-ladder | Pocket kinds as a ladder: movement test (a course, no enemies), arena, elite arena, objective under a limit (about 60 s); each kind a fixed bundle (arena: spawners, then heal and chest on clear); the reward tier shown on the stand before commit; never gating the exit | next push | SQ5 | F | Reward tier rises across the four kinds on every stage file; shown rarity equals paid rarity over 20 seeds; zero main-route gating; the exit opens with every pocket skipped | KD8, KE1, KE6 |
| gunfire/run-pacing-and-economy:trade-chest-health-or-cogs; ror2/events-and-objectives:stake-shrines | A trade chest pays a part for a fixed visible share of health (25/50/75%) or a cogs price shown in HUD units; a blood shrine (health for scrap or a part roll, 0.5 scrap per health, start) and a healing ward (bonus cores, radius grows); the gold-priced shrines are not adopted | next push | SI2 | D | 20 seeds, each tier taken once: cost shown equals cost charged in 100% of takes; payout tier monotone with cost; no option can kill (stated health floor); `bet_crate.gd` unchanged; one purchase per shrine per stage | KD8 |
| gunfire/scrolls-and-synergies:one-list-many-doors; ror2/items-and-stacking:visible-tier-weights | One part list behind every source (find, shop, pocket), and every offer shows what it can contain and its weights; tier weights in one data row (RoR2 reference 0.8 / 0.2 / 0.01) | next push | SG13 | B | 10,000 draws per table: observed frequencies within tolerance of the shown weights; every shown weight read from the row the roll reads; source id lists are subsets of one pool | KD8, B2 |
| gunfire/stage-anatomy:slot-and-pool; pocket-placement:slot-and-pool-draw; roboquest/stage-anatomy:world-interior-pool; gunfire/stage-anatomy:pocket-slot-lab-scenario; isaac/rooms:pocket-library | Fixed authored pocket slots per stage draw each pocket from an authored pool (start: 3 slots on stage 1, plus one per stage, cap 8; 24 interiors per world, 8 per kind); library rows carry kind, footprint, entrances, difficulty 1/5/10, weight (default 1, rare 0.1, never 0), tell | next push | SQ12 (library), SQ14 (draw) | D, F | 1,000 seeded stages: 8 or more distinct pocket sets per template; every interior drawn at least once; pocket count 3 to 8 on at least 95% of seeds; p90/p10 detour ratio at least 2 | KD1 to KD6, KD8, KB8, SQ13 |
| gunfire/stage-anatomy:visible-trigger-caused-opening | Optional rooms show a visible trigger opened by a caused action | done | `design-v3/PARK.md:256` (valve or cracked_wall with a tell) | | `park_pockets_test` | None |
| gunfire/stage-anatomy:pay-tier-by-detour-and-kind | Pay follows the detour: larger-detour off-line pocket `rare`, on-line `common` | done | KD8 (in flight) | | `activities_pay_test`, `park_pockets_test` | None |
| gunfire/stage-anatomy:major-event-allowance | The biggest set pieces are a per-world allowance (default one) a stage modifier or the high tier lifts; minor events keep ebbing and flowing (`BIBLE.md:519`) | this push | KE1 (paste 4b) | D | Seeded stage runs per tier: one major event per world by default, lifted on the high tier; minor events still fire; overlap caps hold | KD1 greybox (KE1's own) |
| gunfire/stage-anatomy:hazards-off-on-clear | A pocket arena's own traps switch off for good when cleared; the crew-repair use waits for the crew | next push | SQ5 | F | Zero hazard damage in a pocket after its clear in 100% of seeded runs; each authored arena carries at least one hazard that switched off | KD1 to KD6, KE1 |
| gunfire/weapons-and-inscriptions:paired-part-partner-shown | A paired part shows its missing partner | done | `src/build/parts.gd:374-382` | | Pair margin folds into SG14 | None |
| gunfire/weapons-and-inscriptions:bot-as-pair-partner | A crew bot may be the pair partner; the one SPIL-9 is the only partner today | next push | SR16 | after alpha | Pair margin 15% to 40% with a companion partner | Crew ruling (`decisions.tsv:476c`) |
| gunfire/weapons-and-inscriptions:fixed-price-upgrade-with-cap | A scrap upgrade at a fixed visible price per step with a hard cap (note: 50 to 600 copper per level, 2 per visit; not copied) | owner | Section 6 item 4 (the numbers); SG16 measures today's prices now | B | SG16's price-to-income report | Andrew: prices are open (`BIBLE.md:513`) |
| gunfire/weapons-and-inscriptions:slot-growth-sweep-arm | Per milestone: slot count and best legal set DPS on a fixed dummy, pair met and missing (`comps/gunfire/weapons-and-inscriptions.md:93`) | next push | SG14 | E | (a) slots never decrease and reach their maximum at the last milestone; (b) paired beats unpaired by 15% to 40%; (c) last best set within 6x of the first | PC-PACK, SR4 |
| gunfire/production-budgets:headless-budget-audit; roboquest/production-budgets:headless-budget-audit; ror2/production-budgets:headless-budget-audit; roboquest/production-budgets:texture-ceiling-and-exception; ror2/production-budgets:foe-bones-40 | One headless audit loads every promoted asset and prints triangles, bones, clips, longest clip and texture side by category, median and p90 beside the three-game table, a per-whole-character sum column, a texture exception field above 2,048, and a foe bone check at 40; fails on an empty category | this push | SQ17 | A | Zero assets over their category cap; every category non-empty with a printed nonzero count; median and p90 printed (`comps/ror2/production-budgets.md:137`) | None (reads `assets/asset_budgets.json`, edits nothing) |
| gunfire/production-budgets:per-pilot-sum-c5b; roboquest/production-budgets:per-pilot-sum-in-pd-report | Each PD pilot reports base shell, each heft layer, pilot body, total tris and draws at classes I, III and V; worst case by the measured neutral shell plus layer and pilot caps 6,476 + 4 x 1,500 + 4,600 = 17,076 tris (`W13-INTEGRATION-2.md:63`; the shell cap itself is 11,000) | this push | PD C5b (paste 4d); PD-INT fallback line | A | Six pilots, three classes, inspect status pass with nonzero counts; a class V total over 16,000 tris stops the forge delta | PD fix round 2 (in flight) |
| gunfire/production-budgets:hero-bones-low-target; ror2/production-budgets:hero-band-80-bones; gunfire/production-budgets:enemy-class-bands; ror2/production-budgets:foe-class-widen; gunfire/production-budgets:texture-and-weapon-class; ror2/production-budgets:pickup-class; ror2/production-budgets:pickup-bones-8; roboquest/production-budgets:second-budget-point-delta4 | The forge pack proposal of memo 2 section 3f made live after the sums: hero band from measured class V sums with an 80-bone ceiling (pilots keep the 25-bone rig); bosses get a bone cap above ordinary enemies; a held-item class above prop (Gunfire weapon median 420, p90 3,753) and a pickup class 70 to 2,200 tris, 8 bones; enemy class cap moves only when a member exceeds 1,100 | next push | SQ18 (conditional) | C | Audit rows per class non-empty; zero assets over the new caps; no class edited without a measured member | SQ17, C5b sums reported, SQ4 |
| gunfire/production-budgets:clip-length-cap; ror2/production-budgets:gameplay-clip-3p5s; ror2/production-budgets:clip-count-50 | Gameplay clips capped at about 3.5 s with a named boss exception (Gunfire boss p90 5.20 s); at most 50 clips per hero | next push | SQ17 clip column, run as a PE-INT acceptance line (paste 4d) | E | Zero non-boss clips over 3.5 s; boss exceptions listed by name; every hero at or under 50 clips; counts nonzero | PE-0 to PE-CANNON (P-UNITS wave P-E) |

### Roboquest (CS-03)

| Ids | What, with the note's numbers | Disposition | Lands in | Wave | Lab measure and pass | Dependency |
| --- | --- | --- | --- | --- | --- | --- |
| roboquest/classes-and-perks:perk-pairs-tree-children | Pick one, unlock two: every nonterminal node has two children | done | `BIBLE.md:65`, `src/core/upgrade_tree.gd`; SQ19 runs the endpoint check | F | Every pilot reaches a depth-four endpoint with both bots (`comps/roboquest/classes-and-perks.md:82` (d)) | None |
| roboquest/classes-and-perks:cooldown-refund-from-combat; roboquest/movement-and-feel:combat-cooldown-refunds | Hits landed and damage taken shorten the mobility or Shift cooldown by 1 to 2 s on 8 to 15 s cooldowns, per-pilot cap, shown on the cooldown chip | this push | SQ6 | A | Per pilot, scripted hits: each refund 1 to 2 s; no effective Shift cooldown under half its base; no mobility at 100% uptime; posture bands unchanged | None (`ability_state.gd:320` already refunds) |
| roboquest/classes-and-perks:baseline-asymmetry-ratios | Each pilot's baseline stated as a ratio to the others (for example one at double another's health, the lighter growing more slowly), tuned in the lab | next push | SQ8 | E | 200 bot runs: ratios inside the declared tolerance; every pilot wins at least 3 of seeds 1 to 4; band tests unchanged | PC-PACK |
| roboquest/classes-and-perks:drone-partner-as-crew-role; roboquest/stage-anatomy:trade-pocket-workbench; ror2/companions:scrap-bot-crew; ror2/companions:crew-growth; ror2/companions:crew-repair-revive; ror2/progression-and-music:crew-voice-stems | The scrap-bot crew: up to three persistent bots (guard, repair, harvest) as driver lists with their own motifs, a pocket workbench, growth from the run's tally with a per-role allow-list and two-fork trees (no 2^n curve), repair for scrap, a downed bot as a later rescue, a stem per acting bot | next push | SR16 | after alpha | Crew of three through three stage loads, owner killed in stage two (`comps/ror2/companions.md:157`): bots exist after each load; stalled within 1 s; repair spends exactly the declared scrap; zero bark mismatches in 100 events | Alpha merge and the Bible section 6 amendment by ADR (`decisions.tsv:476c`) |
| roboquest/enemies-and-telegraphs:four-field-telegraph-record | Every enemy attack has one record: pre-shoot, recovery, cooldown, radius; Roboquest bands as starts (burst 0.25 to 0.5 s, max 0.75 s, `comps/roboquest/enemies-and-telegraphs.md:59`; projectile 0.75 s, ray 1 to 2.5 s, recovery 0.75 s), checked against a 0.4 s floor | this push | KF2 to KF4 (paste 4a); pack kinds in SQ1 | A | 50 runs per attack on a stationary dummy (`comps/roboquest/enemies-and-telegraphs.md:110`): pre-shoot at least 0.4 s; overlap at least 95 percent | KF1 (merged) |
| roboquest/enemies-and-telegraphs:fast-windup-bands-by-class; roboquest/enemies-and-telegraphs:single-recovery-rule | Short wind-up classes (area burst 0.25 to 0.5 s, projectile 0.75 s, ray 1 to 2.5 s) as a declared per-kind choice above the floor; one lab-tuned recovery for ordinary attacks (Roboquest median 0.75 s), Warden attacks on an exception list | next push | SQ1 | C | Each pack kind inside its class band or logged; none under 0.4 s; recovery inside the stated band; each exception listed | KF2 report |
| roboquest/enemies-and-telegraphs:simultaneous-attacker-cap | A cap on enemies in WARN or LIVE at once, Warden exempt; trigger start more than 6 (memo 2's assumption, `W13-INTEGRATION-2.md:303`, not the note's) | next push | SQ2 | G | 20 seeded encounters at the top threat step: the count never exceeds the cap, zero violations | KE9 (peak report) |
| roboquest/enemies-and-telegraphs:universal-stagger-window | One interrupt window for ordinary pack kinds (Roboquest 1.25 s, impact resistance as the dial); the Warden keeps `STAGGER_SECONDS` 4.0 (`src/combat/boss_posture.gd:17`); a stagger never stalls the ball | this push | SQ3 | A | Every knock over the interrupt speed (`src/combat/counter.gd:151`) interrupts; window equal across pack kinds within one tick; zero ball stalls | None (KF1b merged) |
| roboquest/enemies-and-telegraphs:respawn-avoid-last-kind; roboquest/enemy-design-grammar:respawn-avoids-last-type | Arrivals less likely to repeat the kind just killed; the pack-id repeat ban exists (`src/world/director.gd:293`), the kind weight does not | next push | KE9 (paste 4b) | F | 20 seeds x 30 stepped minutes: repeat-kind rate below the no-rule baseline on every seed | KE6 |
| roboquest/enemies-and-telegraphs:free-base-meshes-for-enemy-chassis; roboquest/enemy-design-grammar:cc0-base-meshes; roboquest/production-budgets:free-base-mesh-shortlist | Start the first forge enemy family from a CC0 base (Quaternius first), reshaped, with a provenance sidecar | owner | Section 6 item 1 | | One base reshaped under the 1,100-tri enemy cap; blind silhouette at least 18 of 20; sidecar complete | Andrew's yes per download |
| roboquest/enemy-design-grammar:chassis-class-column; roboquest/enemy-design-grammar:threat-feature-is-warning; roboquest/movement-and-feel:player-to-enemy-speed-ratio | Roster rows gain a chassis class, movement class and one threat feature that is also the warning; a speed table states each pilot's cruise against the median enemy speed (source near 2.35x) and lists kinds faster than 1.2x cruise | this push | SQ4 | A | 20 stills at game camera, three reviewers: at least 18 of 20 named for class and threat feature; column on 19 of 19 rows; every kind above 1.2x cruise listed with its telegraph row | None |
| roboquest/enemy-design-grammar:one-signature-per-boss | One signature mechanic per Warden and miniboss that changes its arena or rules; time to kill across Wardens within a lab-set spread (start +/-25 percent of the median) | this push | KF2 to KF4 and KE4 (paste 4a, 4b) | A | Exactly one named signature per kind; bot time-to-kill spread inside the band | KF1 (merged) |
| roboquest/enemy-design-grammar:family-budget-bands; roboquest/enemy-design-grammar:proportion-ratios; roboquest/enemy-design-grammar:forge-recipe; roboquest/production-budgets:per-family-bands | Report bands per chassis family (bones median 16 pod and airborne, 24 labourer, 37 small walker, 46 heavy, 54 ground walker), proportion ratios as lab-config starts, and a from-scratch forge recipe (base, chassis, one lens as threat feature, band); never an edit to the 1,100-tri enemy cap | next push | SQ18 (recipe, bands); SQ20 (the first from-scratch family, its lab run) | C, D | Every enemy kind inside its lab-config band; zero edits to the enemy class cap; one from-scratch family within band and 18 of 20 blind stills | SQ17, SQ4 |
| roboquest/enemy-design-grammar:base-provenance-sidecar; roboquest/production-budgets:provenance-recipe | One sidecar per fetched base: source URL and title, license name and version with the saved line, download URL, access date, file list with sizes and SHA-256, creator and attribution, commercial-use statement, pre-ship re-check | this push | PD-PROV (paste 4e, promoted) | B | A planted asset with no recipe and no provenance fails; a planted download missing its hash fails; every current asset passes | None |
| roboquest/enemy-design-grammar:anchors-fix-class-spawner-picks | A home names a chassis class, the director picks the member | this push | KE6 (paste 4b) | E | `director.gd` maps every home's kind to a class (no park file edit); every spawn from a home matches it in 100 percent of seeded runs | SQ4 (class field) |
| roboquest/movement-and-feel:speed-bank-spend-window | The shared roll starts at 1.2 to 1.3x cruise and decays to cruise; a jump inside the last 25% of the decay keeps at least 90% of the burst, outside it does not; tuned per pilot so traces differ in shape | next push | SQ9 | D | Scripted roll, slide and jump per pilot: burst ratio 1.2 to 1.3; window rule holds; traces differ in shape, not only scale (`comps/roboquest/movement-and-feel.md:81` capture method stays owed) | B3, PC-SABLE, PC-RIVET (`player_ball.gd`) |
| roboquest/movement-and-feel:buff-uptime-band | Every timed movement or speed buff states its uptime (duration over cooldown, start rule named) inside 25% to 75%; Rivet's 3 s x1.6 Overdrive Blast checked first | this push | SQ7; PC common line (paste 4c) | A | Uptime per pilot buff from the ability table: none outside 25% to 75%; each row names its cooldown start rule | None |
| roboquest/movement-and-feel:shared-floor-distinct-mobility-slot | Shared roll, jump, harpoon, slam; each pilot's own Shift | done | `design-v3/PILOTS.md:11-18`; `tests/char_movement_test.gd` | | Existing test | None |
| roboquest/stage-anatomy:closable-entrance-sockets; pocket-placement:closable-entrance-sockets | Each authored zone has 2 to 4 openings; a builder closes unused ones with a filler landform off the shortest route; a pocket anchor keeps exactly one | next push | SQ15 | C | 1,000 seeds per arm: pocket count 3 to 8; re-roll under 10% and at most half the fixed rate; full-visit ratio at most 3.0; on at least 95% of seeds (`comps/roboquest/stage-anatomy.md:125`) | SQ13, KC0 (merged) |
| roboquest/stage-anatomy:secret-map-tint | An amber edge marker for a discovered hidden pocket door inside the 240 m `sight_ok` range, reusing the HUD pointers (`src/ui/edge_markers.gd:8-12`) | next push | SQ16 | B | All six stages: marker absent outside 240 m or without `sight_ok`, present inside both; none for an undiscovered door | KB8 |
| roboquest/stage-anatomy:full-visit-ratio; maps-compared/full-visit-ratio | Shortest tour from spawn through all four pocket doors to the beacon over the spawn-to-beacon path, start at most 3.0 | done | KB8 report (in flight); gated per stage by KD1 to KD6 (paste 4f) | | KB8 report column | None |
| roboquest/stage-anatomy:elite-cap-per-stage | Elite arrivals capped at 3 per stage, lifted only by a stage modifier (today no cap, `src/world/director.gd:99-101`) | this push | KE6 (paste 4b) | E | 20 seeds x 30 stepped minutes on `--table=park`: no seed over 3 without a modifier | KE1 (KE6's own) |
| roboquest/stage-anatomy:scattered-mark-objective | 3 to 4 marks at least 80 m apart in the far half, any order, an optional objective kind that never gates the exit (`comps/roboquest/stage-anatomy.md:109`) | next push | SQ5 | F | 1,000 seeded stages: 3 to 4 marks on every stage that draws the kind, each pair at least 80 m apart by path and every mark in the far half by path distance; the exit opens with zero marks taken in 100% | KE1. No Bible or ADR line bars it: TADR-010 expects one ("A timed objective, if Q-P38 selects one, counts ticks and is an objective", `adr/TADR-010-open-stages-and-event-director.md:45`); Q-P38 (`:63`) stays open for what an exit requires |
| roboquest/stage-anatomy:difficulty-fills-same-map | Difficulty scales level, modifiers and elites without changing the route | done | `design-v3/PARK.md:363`; KE6 | | | None |
| roboquest/weapons-and-affixes:two-layer-build; roboquest/weapons-and-affixes:tier-count-top-mechanic | A weapon-local attachment layer on each pilot's one weapon beside the player-global tree; attachment tier sets count 0 to 3 and the top tier always adds a second fire mode, shown before equipping; swaps rebuild, never stack (`BIBLE.md:552`) | next push | SQ11 | E | 1,000 weapons per category on a fixed dummy: a global perk changes DPS by a similar share on every category, within 15% of one another; removing an attachment returns DPS to baseline exactly; no tier outside its count range | PC-PACK, B2 |
| roboquest/weapons-and-affixes:category-envelope | Each pilot weapon as an envelope of shown numbers (clip, reload, spread, range): reload within 1.2x across the six weapons, clip and spread medians each spanning at least 3x | this push | SQ10 | A | Envelope table from `src/combat/weapons.gd:32-45`: reload within 1.2x; clip and spread each span at least 3x | None |
| roboquest/weapons-and-affixes:source-weighted-status | A status from a source built for it builds at least 2x as fast as from an incidental source (observed 0.7 against 0.3 and 0.35) | this push | PC common stacking line (paste 4c) | C | Build-up timing, built-for against incidental: at least 2x | None |
| roboquest/weapons-and-affixes:flat-tier-price-step | Reroll and level-up of an attachment cost one flat scrap step per tier with a hard cap | owner | Section 6 item 4 (the numbers); SG16 measures today's prices now | B | SG16's price-to-income report | Andrew: prices are open (`BIBLE.md:513`) |

### Risk of Rain 2 (CS-01)

| Ids | What, with the note's numbers | Disposition | Lands in | Wave | Lab measure and pass | Dependency |
| --- | --- | --- | --- | --- | --- | --- |
| ror2/architecture:catalogs-content-packs | Name-to-resource catalogs | done | `src/core/content_registry.gd:28` | | | None |
| ror2/architecture:master-body-split | Persistent run owner, disposable body | done | `adr/TADR-002-runtime-model.md`; `src/core/profile.gd` | | 100 respawns in SR1's lab test | None |
| ror2/architecture:priority-gated-states; ror2/characters-and-feel:skill-slot-interrupt-priority | Named states with an interrupt priority; a new state wins only above the current minimum; skills gain a priority, a sprint-cancel flag and duration = base / attack speed | next push | SR3 | E | 1,000 randomized orderings: 0 weaker interrupts accepted, 0 stronger refused, at most 1 state change per tick; duration equals base over attack speed at 0.5, 1 and 2 within one tick | B3, PC-PACK (`ability_state.gd`) |
| ror2/architecture:one-damage-door; ror2/architecture:one-door-lab-test | Every hit through one function in a declared order (armour, plates, caps, crit, health, execute, then events), hooks capped per event; today six `take_damage` sites (`src/combat/enemy.gd:378`, `warden.gd:788`, `plated_brute.gd:243`, `drill_crew.gd:159`, `src/boss/boss.gd:1127`, `src/boss/boss_target.gd:163`) and a bypass (`src/combat/wear_trail.gd:8`) | next push | SR1 | E | 1,000 scripted hits with every hook on: order matches on all 1,000; no hook runs before damage; 100 kill-and-respawn cycles leave the run owner unchanged (`comps/ror2/architecture.md:93`) | PC-PACK, KF2 to KF4, B3, B6 (`combat.gd`, `warden_<kind>.gd`) |
| ror2/architecture:server-authority-networking | Server-owned damage and spawns | blocked | Section 5 | | | `adr/TADR-005-networking-scope.md:23` |
| ror2/architecture:effect-projectile-pooling | One node pool per prefab with a free list | next push | SR2 | F | 10 minute spawn-heavy run: peak live nodes flat after warm-up; frame time not worse than unpooled; no state leaks | KB6, SR1 |
| ror2/architecture:saves-unlocks | Profile holds unlocks | done | `src/core/profile.gd`, `src/core/achievements.gd` | | | None |
| ror2/architecture:logbook-registry-pass | Codex read over the registry | done | `src/core/codex.gd` | | | None |
| ror2/characters-and-feel:telegraph-timing-probe | Cue, charge, window, damage timestamps at attack speeds 0.5, 1, 2, 20 runs | done | KF2 to KF4 (`K-UNITS.md:413`) | | | None |
| ror2/characters-and-feel:shake-cap-stress; ror2/characters-and-feel:melee-hitstop-never-holds-player | A global per-frame shake cap under stacked hits; hitstop only on the attacker's own melee, at most 60 ms (`SPINE_CAP_MS`, `src/presentation/juice.gd:25`), never freezing the player, never on a roll | this push | SR5 | A | 30-hit stress: peak shake under the cap every frame; zero player-movement freezes from hitstop; none on ball roll | None |
| ror2/characters-and-feel:damage-number-shared-colour-merge | Numbers and hit effects colour from one source; numbers merge in a short window | next push | SR6 | B | Zero number and effect colour mismatches across every type and team; visible numbers under a declared cap at 20 hits per second | B2 |
| ror2/characters-and-feel:one-move-verb-per-character | Each pilot keeps its own movement verb | done | P-UNITS movement rule (`P-UNITS.md:238`); PC-POOL | | | None |
| ror2/companions:driver-list-data; ror2/companions:leash-stalled; ror2/companions:chirp-state-bus | The SPIL-9's modules as ordered driver rows (first passing row runs); a leash with a stalled state at the last safe spot and a delayed return near the leader; chirp, gesture and animation read one state with a per-trigger cooldown | this push | SR7 | C | Reordering two rows changes which fires with no code edit in 100 of 100 ticks; stalled within 1 s of owner loss, clears on respawn; zero mismatches in 100 events; no new combat key or health economy (`BIBLE.md:570`) | None |
| ror2/companions:devices-caps | Devices: a per-kind capacity cap (note: 2, 2, 3, 4), timed refill, recall by the leash, removal on destruction | next push | SR8 | F | Deployed count never above the cap; refill and recall times match the lab values | SR7 |
| ror2/director-and-difficulty:credit-paced-spawning; ror2/stage-anatomy:monster-credit-pair | Credit director: income `I0 * (1 + K * dial)`, cards with cost, weight, stage cap | next push | KE9 (scheduled, wave F) | F | Credits spent within 5% of the income integral over 30 stepped minutes, 20 seeds; never more than 24 alive (`comps/ror2/director-and-difficulty.md:129`) | KE6 |
| ror2/director-and-difficulty:capped-stepped-dial | One capped stepped dial as a named constant | this push | KE6 brief (`K-UNITS.md:314`) | E | KE6's clock-tier line | KE1 |
| ror2/director-and-difficulty:per-stage-dial-multiplier; ror2/director-and-difficulty:elite-refund; ror2/events-and-objectives:boss-credit-miniboss; ror2/events-and-objectives:squad-and-scripted-packs; ror2/stage-anatomy:enemy-home-turf; pocket-placement:interactable-exclusion | KE9 lines: a geometric per-stage factor on the dial (start value from the lab, readable-capped; the note's constants are not copied, `comps/ror2/director-and-difficulty.md:123`); an elite's price refunds on death; the relay miniboss budget `max(override, floor(c * sqrt(D)))`; authored activity packs bypass credits; home-region card weights; no spend inside a door ring | next push | KE9 (paste 4b) | F | Dial monotone in stage and time under its cap; refund equals price; miniboss credit monotone and sqrt-shaped; authored packs consume no credit; at least 70% of each kind's arrivals in its home region (start); zero spends inside a ring over 20 seeds | KE6 |
| ror2/director-and-difficulty:elite-cost-multiplier | Elites as a card cost multiplier | this push | KE9 brief (`K-UNITS.md:346`) | F | KE9's credit checks | KE6 |
| ror2/director-and-difficulty:spawn-distance-bands | Arrivals pick from named distance bands and never land inside a minimum radius of the ball | this push | KE6 (paste 4b) | E | Zero arrivals inside the minimum radius over 30 stepped minutes, 20 seeds | KE1 |
| ror2/director-and-difficulty:dial-priced-shops-gold-xp | Prices, gold and XP scaled by the time-driven dial | blocked | Section 5 | | | `adr/TADR-010-open-stages-and-event-director.md:45` |
| ror2/director-and-difficulty:team-level-curve | An XP level curve with per-level stat growth and an ambient level | owner | Section 6 item 6 | | | Bible amendment (`BIBLE.md:432`, `:538`); default keep |
| ror2/events-and-objectives:relay-charge-rule; ror2/events-and-objectives:convergence-relay-part | The opt-in hold relay (18 s, 24 m, `src/world/hold_relay.gd:8-10`) becomes data: rate `(N_in/N_living)^s / T`, a discharge field (default 0, today's pause), a ring following charge with a floor; a part that divides the radius by 2 x count and raises charge speed 30% per count, cap three | next push | SR9 | E | 100 seeded runs, 1 to 4 occupants: charge time equals `T/share^s` within 1%; default keeps today's relay; ring never under its floor; part counts 1 to 3 within 1%, count 4 equals 3 | KE1 |
| ror2/events-and-objectives:relay-risk-stack | Opt-in stacks before charging multiply the relay's pack and miniboss credit by `(1 + k)` and add one part roll each; no stake of currency | next push | SR10 | G | k = 0 to 4 over 100 seeds: credit equals base x (1 + k) and rewards 1 + k; posture bands unchanged; no price changes | SR9, KE9, KD8 |
| ror2/events-and-objectives:round-arena-pocket; isaac/pacing-and-trades:ambush-ladder | A round-based arena pocket (each round adds exactly one new thing, credits per round `(base + step x (round-1)) x D` with D capped, a safe zone announced before the next round, one pay per round); ambush pockets with 3 scripted waves of 1 to 5, exits open on clear, never on the main route | next push | SQ5 | F | Credits per round within 1%; one new element per round; pay events equal rounds; zero main-route placements; exit opens on clear in 100% | KD8, KE1, KE6 |
| ror2/events-and-objectives:bonus-portal-chance | After an objective a rare side door whose odds fall with each already spawned (`0.375/(n+1)` shape), 0 to 30 m from the finish point | next push | SQ14 | F | 1,000 seeded stages: spawn probability at count n equals `p0/(n+1)` within sampling error; every portal in band and `sight_ok`; zero exits gated | SQ12, SQ13 |
| ror2/events-and-objectives:relay-music-and-signposting | The relay's state drives the boss-status cue, the approach term, an in-ring filter and the ring flash, refreshed at 4 Hz, layers on phrase boundaries except danger (`BIBLE.md:755`) | next push | KE8 and KE10 (paste 4b) | F | 5 minute trace: zero mid-phrase layer changes except danger; cues within one bar; flash within one tick of entry | KE8, KE10, SR9 |
| ror2/events-and-objectives:stay-or-leave-clock | Staying costs a rising clock, never an objective penalty | done | `src/world/director.gd:83-85`; `adr/TADR-010-open-stages-and-event-director.md:45` | | | None |
| ror2/items-and-stacking:three-families-and-proc-coefficients | Linear, hyperbolic, capped; `proc_coeff` 1 direct, 0.2 to 0.35 child | done | `src/build/part_def.gd:56`; `P-UNITS.md:237` | | | None |
| ror2/items-and-stacking:capped-spike-family; ror2/items-and-stacking:full-inventory-stack-sweep; isaac/items-and-synergies:build-sweep-lab-measure | A fourth rare family, `spike`, always capped at 8x base, at most one per tier; a whole-pool stack sweep 1 to 20 copies with time to kill; 10,000 random 6-part builds through the pool rules | this push | SR4 | B | (a) every ceiling stat at stack 20 under its cap with shrinking steps; (b) no spike above 8x; (c) at least 30% of builds reach 3 or more tags, zero unspecified pairs, repeats at most once per 10,000 draws (`comps/isaac/items-and-synergies.md:89`) | None |
| ror2/items-and-stacking:per-hit-chain-mask | One bit per proc type per hit, so no type repeats in one chain | next push | SR11 | E | Five distinct sources in one hit: each fires at most once, zero same-type repeats | PC-PACK (the second chaining part ships in a PC unit) |
| ror2/items-and-stacking:scrap-tier-economy | Scrap typed by item tier and a fixed trade-up ratio | owner | Section 6 item 4 (the numbers); SG16 measures today's prices now | B | SG16's price-to-income report | Changes what scrap is (`BIBLE.md:65`, `:513`) |
| ror2/items-and-stacking:power-earns-layer-not-number; ror2/progression-and-music:release-after-clear | Power earns an added music layer, never rising master volume; after a stage clear the busiest layers release within one phrase | next push | KE10 (paste 4b) | F | Layers rise in steps over a 1 to 20 power sweep with peak level under its ceiling; release within one phrase of a clear (`BIBLE.md:755`) | KE10 |
| ror2/progression-and-music:run-parameter-score; ror2/progression-and-music:phrase-quantizer | Threat, approach and armour parameters sampled four times per bar; changes wait for a phrase except danger | next push | KE10 (scheduled, wave F) | F | Zero values out of range and zero mid-phrase changes over 5 minutes (`comps/ror2/progression-and-music.md:106`) | KE8, B3, KB8 |
| ror2/progression-and-music:unlocks-as-lessons | Grants teach one-run conditions, no new lifetime count above 10 | this push | PC-SABLE, PC-RIVET, PC-TARN, PC-TALLY grant lines (`P-UNITS.md:289`) | C | `grant_grammar_test` | None |
| ror2/progression-and-music:logbook-page; ror2/progression-and-music:run-tallies | A read-only logbook page over codex entries with status and the `seen` list as the only prompt; run tallies (stages cleared, time, kills, deaths, Wardens seen) | this push | SR12 | C | Every registered entry resolves to a status and opening clears its marker; a scripted run's tallies equal its run log | None |
| ror2/run-flow:six-beat-stage-rhythm | Six named beats (arrive, loot, find, hold, fight, leave), each with one owning module, logged with time and seed | next push | SR13 | E | 50 seeded bot runs (`comps/ror2/run-flow.md:82`): every run reaches the exit with no beat skipped; a seed replay reproduces beat timings to the frame | KB8, KE1 |
| ror2/run-flow:weighted-destination-at-exit | A weighted draw of the next world | owner | Section 6 item 7 | | | Bible amendment (`BIBLE.md:580`); default keep |
| ror2/run-flow:difficulty-recalc-at-stage-load | The dial's stage-indexed term recomputes once at stage load under its cap; the in-stage clock tier keeps stepping | this push | KE6 (paste 4b) | E | One stage-term recalc per load, the stage term constant within a stage, 20 seeds | KE1 |
| ror2/run-flow:seeded-fast-restart | Exit to the next stage's first control frame under the quick-restart target; a seed replays identically | next push | SR14 | F | Latency under the target the coordinator names from the register; same seed, same beat timings | KB4, KD1, SR13 |
| ror2/stage-anatomy:one-graph-many-readers; ror2/stage-anatomy:far-quarter-spawn-by-path; ror2/stage-anatomy:objective-and-pocket-flags-baked; maps-compared/spawn-far-by-path | The baked graph, far-quarter spawn by path, `door_ok`, `line`, `sight_ok` flags | done | KB8 (in flight) | | `park_graph_test`, `park_pockets_test` | None |
| ror2/stage-anatomy:baked-objective-eligibility; ror2/stage-anatomy:objective-first-then-spawn; isaac/floor-generation:pocket-placer-lab-measure | A `beacon_ok` flag (a flat open disc from the Warden engage ring, not RoR2's 15 m / 7 m / 20 rays); the check order beacon then spawn; a reward-to-objective median ratio at least 1.5; `full_visit_ratio` reported by SR15 and gated per stage by KD1 to KD6 | next push | SR15; KD1 to KD6 (paste 4f) | B, C | Beacon node passes on all six files and a planted ledge beacon fails; ratio at least 1.5 and `full_visit_ratio` at most 3.0, each gated by its stage's KD unit | KB8 |
| ror2/stage-anatomy:pocket-door-rules; ror2/stage-anatomy:door-visible-from-main-route | Door distances and `sight_ok` | done | `design-v3/PARK.md:254-271`; KB8 | | | None |
| ror2/stage-anatomy:detour-priced-pay | Detour sets pay | done | KD8 (in flight) | | | None |
| ror2/stage-anatomy:pocket-credit-pool-card-draw; pocket-placement:pocket-credit-pool-and-refund; ror2/stage-anatomy:interactable-spend-after-pockets; ror2/stage-anatomy:200-seed-stage-lab-measure; maps-compared/stage-size-and-pocket-footprint | A pocket credit pool (start 150 against 400 interactable credits) priced by reward, footprint and detour, with a refund and the next anchor on a failed placement; interactable scatter after pockets outside door rings; 200-seed and size sweeps (352 to 611 m a side; a pocket about 1% of the floor) | next push | SQ14 | F | 200 seeds per template: zero credit lost; 3 to 5 pockets plus one on at least 95%; zero interactables in rings; spawn-to-objective share at least 0.6 on 95%; size sweep re-roll under 10% | SQ12, SQ13 |
| ror2/production-budgets:prop-floor-40; ror2/production-budgets:texture-floor-128 | Lower floors | done | `assets/asset_budgets.json` classes carry ceilings only | | | None |

### The Binding of Isaac (CS-01)

| Ids | What, with the note's numbers | Disposition | Lands in | Wave | Lab measure and pass | Dependency |
| --- | --- | --- | --- | --- | --- | --- |
| isaac/floor-generation:graph-anchors; pocket-placement:zone-graph-anchors | Landform zones joined by one-move crossings; degree-1 zones ranked by path distance as pocket anchors | next push | SQ13 | B | 1,000 seeded jitters: guaranteed pockets at the two costliest anchors off the shortest route on 95%; re-roll at most 20% | KB8 |
| isaac/floor-generation:guaranteed-pockets-off-route; isaac/floor-generation:hidden-pocket-three-zones; isaac/floor-generation:seen-before-entered; isaac/pacing-and-trades:hidden-pocket; pocket-placement:door-rules; pocket-placement:detour-price-and-guaranteed-pair; pocket-placement:hidden-pocket; pocket-placement:objective-and-spawn-by-path-distance | Guaranteed pockets off route, a hidden pocket bordering three routes with a tell, every door seen first, objective then spawn by path | done | `design-v3/PARK.md:254-271`; KB8, KD8; SQ13 adds the three-zone check | C | `park_pockets_test`; SQ13: every hidden pocket borders at least 3 zones (`comps/isaac/floor-generation.md:107` (c)) | None |
| isaac/floor-generation:chance-pockets-and-growth; pocket-placement:chance-pockets; pocket-placement:pocket-count-growth; isaac/floor-generation:large-pockets-first; pocket-placement:large-pockets-first | Chance pockets at 25% per leftover anchor; count 3 to 5 on the first stage, plus one per stage, cap 8; large pockets tried first and only where they cut no route | next push | SQ14 | F | 1,000 seeds: counts match the table; chance rate 25% within +/-3 points; zero routes cut; re-roll at most 20% | SQ12, SQ13 |
| isaac/floor-generation:stage-pocket-modifier; isaac/pacing-and-trades:stage-modifier; pocket-placement:stage-modifier | At most one stage modifier per stage, shown before it starts, scaling pocket count or visibility or restricting anchors to the farthest few; never touches handling | next push | SI3 | G | Shown pre-stage in 100%; counts within cap; specials only in the farthest-N anchors; handling identical over 600 ticks; modifier off is byte-identical | KE7, SQ14 |
| isaac/items-and-synergies:tag-composition-no-bespoke-pairs | Every new pair is a `synergies.gd` row | done | PC common line (`P-UNITS.md:237`) | | | None |
| isaac/items-and-synergies:behavior-bits-or-composition; isaac/items-and-synergies:readable-bit-cap | A closed set of shot bits (pierce, bounce, split, pull, heat), each part 0 to 2, OR-composed, children copy the set, one table maps bit to colour, sound and rule; at most 3 bits per shot or a tell for every bit past two | next push | SI4 | F | 10,000 6-part builds: zero unspecified pairs; at least 30% reach 3 bits; max bits at most 3; worst build inside the frame budget | PC-PACK |
| isaac/items-and-synergies:stat-cache-on-pickup | Parts declare the stat categories they touch; the cache recomputes only those on pickup and respec | next push | SI5 | F | 1,000 random builds: cached stats equal full recompute; zero recomputes per tick outside pickups and respec | PC-PACK |
| isaac/items-and-synergies:pool-decay-multi-source | Flat weights with decay; parts in two or three sources | done | `src/build/parts.gd:429-433`, `:465` | | | None |
| isaac/items-and-synergies:set-of-three-transformation | Three distinct parts of one set give an optional rule change shown on the mech; losing one undoes it, the discovery stays (`BIBLE.md:564`) | next push | SI6 | G | A reported completion share in the sweep; respec removes the effect and keeps the discovery; no set required to clear a route | SI4, SI5 |
| isaac/pacing-and-trades:two-trade-families; isaac/pacing-and-trades:trade-odds-recency; isaac/pacing-and-trades:curse-pocket; isaac/pacing-and-trades:sacrifice-pocket; isaac/pacing-and-trades:odds-codex | A risk trade family (strong part for a shown run resource) closes the safe family for the run; refusing raises safe odds; trade odds x0.5 two stages after a trade and x0.25 right after; curse pockets 1 in 7 per stage with a lower-weight pool (0.2 floor); a sacrifice pocket 1 in 7 with a bump at full health; every applied modifier listed on the results screen | next push | SI1 | D | 10,000 runs of 8 stages, always-risk and never (`comps/isaac/pacing-and-trades.md:97`): mean 1.5 to 3 trade pockets; back-to-back at most 30%; closure 100%; refusing raises safe odds at least 1.2x in 80%; idle entry takes no damage in the first 2 s in 95% of 50 runs; a skip-all policy adds zero main-route time (`:97` (e)) | KD8, KD1 to KD6 |
| isaac/pacing-and-trades:gauntlet-clock | A stage clock that closes a door | blocked | Section 5 | | | `adr/TADR-010-open-stages-and-event-director.md:45` |
| isaac/rooms:readable-on-entry; isaac/rooms:density-and-difficulty-dial | From the entry spot every hazard, enemy start and one safe path are visible; no hazard inside the entry radius (start: the 40 m clear ring, `design-v3/PARK.md:266`); density 60 to 70% terrain, 20 to 30% enemies, 5 to 10% pickups; difficulty 1/5/10 rising by health sum first | next push | SQ12 | D | 50 idle and 50 dodger entries per pocket (`comps/isaac/rooms.md:101`): idle takes no damage in 2 s in 95%; dodger clears at least 80% of difficulty 1 and fewer than 80% of difficulty 10 | KD1 to KD6, KD8 |
## 3. New unit blocks

Every block inherits `K-UNITS.md`'s shared rules (`K-UNITS.md:5-16`): own worktree and branch, a verifier and one fix round, tests red first, the REPORT on the PASS to INCONCLUSIVE scale with its evidence level, and the forbidden-for-all list. "Base checks" means `K-UNITS.md:9-13`: `npm run sketch:lint` exits 0, the fence check lists only SCOPE files, and each `npm run sketch:smoke -- --sketch core-loop --test '<name>'` run prints `-> PASS` for the stated file count (an empty selection exits 2, `scripts/sketch-smoke.mjs:178`). The writer is `scrapkeep-writer` (Sonnet) unless a block says Opus (`P-UNITS.md:20`). A new test states its own expected check count and fails on any other (`P-UNITS.md:46`). No block moves a posture band, a traversal band or a budget class except through its own dated re-pin (`P-UNITS.md:22`), and none edits `docs/decisions.tsv` (`P-UNITS.md:23`). Units are lane S (systems from the comps) unless the wave map puts them in polish.

### 3.1 Gunfire Reborn systems

**The two-layer build, named on the build screen.** Gunfire splits weapon-local inscriptions from player-global scrolls; Scrapkeep's form is the layer label on every part plus the screen that shows pools, caps and depth (SG3), and the weapon-local layer itself, which lands with Roboquest's attachments (SQ11).

### SG3 Build screen readouts

- **GOAL.** The build screen shows, for every bonus, whether it stacks additively or multiplies and its cap; labels each part weapon-local or player-global and lists the stats a global part reads; shows each stacking family's cap, the tree's depth-by-world table, one trade-off line per pilot class and a cooldown chip flash on a refund.
- **SCOPE.** `src/ui/build_readout.gd` (new: pools, caps, layer labels), `src/ui/class_card.gd` (the trade-off line), `src/ui/class_kit.gd` (one line in each of the six `WORDS` blocks), `src/ui/tree_card.gd` (the depth-by-world table), `src/ui/ability_bar.gd` (the chip flash on `cooldown_refunded`), `src/build/part_def.gd` (fields `layer` and `reads`), `tests/ui_build_readout_test.gd` (new).
- **CONTEXT.** B2's rewrite of these UI files (`P-UNITS.md:126`) and B6's tree card reader (`P-UNITS.md:206`); `BIBLE.md:432`, `:538` (depth 2 in world one, 3 and 4 later); `BIBLE.md:448` (5.4 Attunement wants a readable explanation); `src/build/parts.gd:374-382` (the hint card pattern); `comps/gunfire/elements-and-fusion.md` (named pools; its +90% resistance cap is another game's number, so the cap value is the lab's); SQ6's `cooldown_refunded` row.
- **ACCEPTANCE.**
  - For every bonus on the screen the displayed pool and total equal the simulated result in a scripted build; resistance never shows above its declared cap.
  - 100 percent of part rows carry `layer` `local` or `global`; every global part names the stats it reads.
  - A family at its cap shows the cap on the card (each part's `stack_cap` read through `Stacking.value`, `src/build/part_def.gd:128-141`; `STACK_RULES` at `:56` holds only the rule names).
  - The tree card shows depth 2 for world one and depths 3 and 4 for later worlds, read from the tree data, not typed.
  - Each of the six class cards shows exactly one trade-off line; `ui_word_budget_test` still holds the fight case at 25 words or fewer (`P-UNITS.md:135`).
  - The ability chip flashes once per `cooldown_refunded` event.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'ui_build_readout_test' --test 'ui_class_card_test' --test 'ui_word_budget_test' --test 'hud_icon_distinct_test' --test 'ui_skill_bar_test'` (5 files).
- **TIMEBOX.** 3 h.
- **FORBIDDEN.** New meaning colours; new HUD words beyond one line per card; any number change in a part row.
- **Depends on.** B2 and B6 merged. **Shares files with.** `class_card.gd`, `class_kit.gd`, `tree_card.gd`, `ability_bar.gd` with B2 and B6 (merge after them; the six PC units merge after SG3); `part_def.gd` with SR4 (merge after it), SG15, SI4, SI5.

**Burden scrolls as pure stated downsides, offered only in visible optional pockets.**

### SG4 Burden parts

- **GOAL.** Rare burden parts, each a pure stated downside, are offered only as the named pay of a visible optional pocket, and from world 2 a pilot may hold more than one hot-wired part.
- **SCOPE.** `src/build/parts.gd` (burden rows in `HOTWIRED`, `:187-196`; the one-held rule at `:288-302` becomes one in world one and the per-world cap from world 2; `offer_pool` never returns a burden), `src/core/alpha_defs.gd` (the burden ids in the parts list only), `tests/burden_parts_test.gd` (new), `src/world/activities.gd` (one line, `:387`: the named-part rule reads `Parts.rows().has(named) or Parts.is_burden(named)`; ruling 2026-10-11 w13-systems round 3), `src/build/build.gd` (`:612-616`: `hotwire_offer` takes `ctx.run.world` and `_hotwire_spent` re-arms per world; same ruling), `tests/hotwire_offer_flow_test.gd` (a world-2 second offer check; same ruling).
- **CONTEXT.** `parts.gd:187-196` (two hot-wired rows: `riveted_shell`, `spark_tread`), `:288-302` (the one-held rule), `:399-415` (`offer_pool`); `src/world/activities.gd:378-382` (a named part wins over the roll, so a pocket row's `pay.named` offers the burden); KD8 (`K-UNITS.md:255-269`); `comps/gunfire/scrolls-and-synergies.md:86`; `design-v3/research/build-systems/BUILD-SYSTEMS.md:76`.
- **ACCEPTANCE.**
  - Each burden row shows a cost icon and at most three words in the hot-wired row shape (`parts.gd:190-191`).
  - `offer_pool` for all six pilots returns zero burden rows; a park row's `pay.named` naming a burden pays it.
  - World one holds at most one hot-wired part, as today; from world 2 more than one.
  - Burden sweep step 1: a dummy build holds 0 to 10 burdens against a fixed target; the test prints damage per second and damage taken per count, and 5 burdens survive a fixed scripted encounter at least as often as 0.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'burden_parts_test' --test 'hotwire_offer_flow_test' --test 'hotwire_shell_offer_test' --test 'ui_hotwire_screen_test' --test 'activities_pay_test'` (5 files).
- **TIMEBOX.** 3 h.
- **FORBIDDEN.** A burden in a shop shelf or a tree offer; editing `activities.gd` beyond the named-part line at `:387` (ruling 2026-10-11 w13-systems round 3).
- **Depends on.** KD8 merged. **Shares files with.** `parts.gd` with PC-POOL, SQ19, SG15, SR9 (they merge after SG4); `alpha_defs.gd` with PC-PACK and KD7 (merge before PC-PACK).

### SG5 Burden payout and sweep

- **GOAL.** One payout part reads the count of burdens held and pays through the ceiling curve, with its cap shown.
- **SCOPE.** `src/build/parts.gd` (one payout row, `stack_rule` `hyperbolic`), `src/build/item_effects.gd` (one effect that reads the burden count), `tests/burden_sweep_test.gd` (new).
- **CONTEXT.** `comps/README.md:55` (row 7, the ceiling `1 - 1/(1 + a*x)`); `comps/gunfire/scrolls-and-synergies.md:86` (the sweep); `src/build/part_def.gd:56`.
- **ACCEPTANCE.**
  - Burden sweep step 2, 0 to 10 burdens: the payout total stays below its declared cap at every count and the step from n to n+1 never grows.
  - Net build power at 10 burdens is at most 3x the zero-burden build.
  - The cap prints on the part card and in SG3's readout.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'burden_sweep_test' --test 'burden_parts_test'` (2 files).
- **TIMEBOX.** 2 h.
- **FORBIDDEN.** An uncapped or linear payout.
- **Depends on.** SG4. **Shares files with.** `parts.gd` (after SG4); `item_effects.gd` (none in flight).

**One element that marks a target so every source hits harder, drawn on the telegraph geometry.**

### SG1 Arc mark

- **GOAL.** An arc hit marks its target for a timed window in which damage from every source rises by one declared fraction, drawn on the committed geometry.
- **SCOPE.** `src/combat/damage_door.gd` (SR1's file: one mark step in the declared order), `src/combat/combat.gd` (the arc source sets the mark as its own entry kind in the shared `_exposed` table at `:241-245`, read by the damage door for every source; plate entries keep the `CONTACT_KINDS` filter at `:573`), `tests/arc_mark_test.gd` (new).
- **CONTEXT.** `combat.gd:240-245`, `:573` (today the plate boosts contact strikes only); `src/build/elements.gd:15` (`ELEMENTS` frost, arc, kinetic); `BIBLE.md:493` (geometry resolved once); `comps/gunfire/elements-and-fusion.md` (shock +10% for 5 s, a start value).
- **ACCEPTANCE.**
  - Dummy marked by arc, then hit by contact, projectile, area and companion: each source's damage rises by the same declared fraction while marked and returns to base on expiry.
  - The mark's drawn shape equals the committed geometry in every frame; no extra hit is granted.
  - The plate's existing exposure keeps its numbers and its reach (`MindAttacks.BRACE_MULT`, `combat.gd:241`): a plate-exposed dummy hit by a projectile or an area takes base damage, so Tally's kit, which the PC units own (`P-UNITS.md:236`), does not change.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'arc_mark_test' --test 'damage_door_test' --test 'posture_bands_test' --test 'alpha_posture_bands_test'` (4 files).
- **TIMEBOX.** 3 h.
- **FORBIDDEN.** A second exposure table; a new element; health scaling.
- **Depends on.** SR1, PC-CANNON. **Shares files with.** `combat.gd` (after PC-PACK and SR1); `damage_door.gd` (after SR1).

### SG2 Fusion rows and one layer table

- **GOAL.** A second status on a marked enemy fuses once into one effect, the same in either order, as a row of the element table, and every protection layer reads one multiplier table.
- **SCOPE.** `src/build/elements.gd` (fusion rows; a `LAYER_MULT` table), `src/build/element_field.gd` (one behaviour per fusion row), `tests/fusion_pairing_test.gd` (new).
- **CONTEXT.** `elements.gd:3-15` (the TADR-009 table, default-deny; `element_field.gd` owns the behaviours, `:6`); `BIBLE.md:493`; `comps/gunfire/elements-and-fusion.md:85`; SG7's defence classes; `comps/gunfire/heroes-and-ascensions.md` (the note's 150 / 100 / 75 percent table as shape).
- **ACCEPTANCE.**
  - Fusion pairing test: each pair of statuses applied in both orders to one dummy gives the identical effect type, area and damage.
  - The committed preview exists at least 12 frames before damage and equals the damage area.
  - An elite dummy takes no control effect and at most 10% of the normal dummy's sustained damage; the immunity text on the card equals the data row.
  - Every protection layer in SG7 reads its multiplier from `LAYER_MULT`; no layer has a private multiplier.
  - Fusions use today's elements only (`elements.gd:15`); a new element waits for Q-P13.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'fusion_pairing_test' --test 'arc_mark_test' --test 'defence_bars_test'` (3 files).
- **TIMEBOX.** 3 h.
- **FORBIDDEN.** A pair resolved twice; a hidden immunity roll.
- **Depends on.** SG1, SG7. **Shares files with.** None.

### SG7 Defence bars

- **GOAL.** Armour, shield and health read as three bar classes with one rule each, so a bar's look predicts how to attack it.
- **SCOPE.** `design-v3/LEGIBILITY.md` (a defence-bar row set in section 2), `src/core/defence_bars.gd` (new: three classes, one regen rule each, one existing palette row each), `tests/defence_bars_test.gd` (new).
- **CONTEXT.** `BIBLE.md:489` (a committed attack means what it shows) and `:769` (combat meanings stay consistent across regions); `src/core/palette.gd`; the Warden plating states of KF2 to KF4 (`K-UNITS.md:402-419`), which read this table.
- **ACCEPTANCE.**
  - Armour breaks at zero and does not regenerate; shield regenerates after a declared delay; health is health.
  - Each defence state maps to exactly one bar class, each class to one regen rule, and no two classes share a colour; colours come from existing `palette.gd` rows.
  - A blind frame read at 150 m names the class of each bar in a fixture (the K-F distance, `K-UNITS.md:427`).
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'defence_bars_test'` (1 file).
- **TIMEBOX.** 2 h.
- **FORBIDDEN.** A new meaning colour; drawing code in `src/ui/hud.gd` (B2's).
- **Depends on.** Nothing. **Shares files with.** None.

**Picks in three levels, and ascension-style depth.**

### SG15 Three-level parts

- **GOAL.** A part is picked in three levels and a higher level replaces the lower, expressed in the existing stacking vocabulary so the build rebuilds from current selections.
- **SCOPE.** `src/build/parts.gd` (a `levels` field: three authored levels as a `capped` stack with cap 3 and per-level numbers), `src/build/part_def.gd` (the field), `tests/part_levels_test.gd` (new).
- **CONTEXT.** `part_def.gd:56` (`STACK_RULES`); `BIBLE.md:552` (rebuild from current selections, no accidental bonuses); the first memo's row 7 (`W13-INTEGRATION.md:24`), which this keeps: levels are capped stacks, not a fourth rule.
- **ACCEPTANCE.**
  - No offer shows a part already at level 3; level n's numbers replace level n-1's, never add.
  - Each pilot still wins at least 3 of seeds 1 to 4.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'part_levels_test' --test 'offer_weights_test' --test 'build_parts_test' --test 'bot_six_pilots_test'` (4 files).
- **TIMEBOX.** 2 h.
- **FORBIDDEN.** A new stack rule.
- **Depends on.** SQ19. **Shares files with.** `parts.gd` (after SQ19); `part_def.gd` (after SR4, SG3).

### SG8 Late forced-or-skip offer

- **GOAL.** A late-world depth-4 offer can be one pick the player takes or skips, never rerolled, at a safe grounded moment.
- **SCOPE.** `src/core/upgrade_tree.gd` (a `take_or_skip` offer kind on depth-4 nodes), `src/ui/tree_card.gd` (the skip prompt), `tests/late_offer_test.gd` (new).
- **CONTEXT.** `BIBLE.md:538` (offers at safe grounded moments; the fourth pick by the final boss); `BIBLE.md:432`; `P-UNITS.md:120` (`upgrade_tree.gd` shared with B3, PC-RIVET, PC-TALLY).
- **ACCEPTANCE.**
  - 200 draws per pilot: skip is always available and free; no offer reappears after a skip within the run; take and win rates printed.
  - A run still reaches its fourth pick by the final boss.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'late_offer_test' --test 'tree_safe_picks_test' --test 'tree_data_test' --test 'bot_six_pilots_test'` (4 files).
- **TIMEBOX.** 2 h.
- **FORBIDDEN.** A reroll on this kind; any offer opened by elapsed time.
- **Depends on.** PC-SABLE to PC-CANNON merged. **Shares files with.** `upgrade_tree.gd` (after B3, PC-RIVET, PC-TALLY); `tree_card.gd` (after B2, B6, SG3).

### SG9 Run-start pick of three

- **GOAL.** At run start the player takes one of three small options drawn from the pilot's own list, with one reroll, without slowing the restart.
- **SCOPE.** `src/core/start_picks.gd` (new: per-pilot lists, three drawn from the run seed, one reroll), `src/ui/start_pick_card.gd` (new), `src/core/run_state.gd` (the run's pick; cleared on a new run beside `cogs = 0`, `:159`), `tests/start_pick_test.gd` (new).
- **CONTEXT.** `BIBLE.md:65` (the alpha's one tree per pilot); `BIBLE.md:462` ("rather than rerolled" covers fixed secret bonuses only); `BIBLE.md:582` (a replay keeps stable offers and seed decisions); `BIBLE.md:475` (no permanent stat boosts).
- **ACCEPTANCE.**
  - 200 run starts per pilot: time to first input unchanged within noise against a no-pick baseline; each of the three options taken at least once.
  - No option changes a movement knob; no option persists past the run.
  - A zone replay from its entrance save shows the same three options.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'start_pick_test' --test 'profile_store_test' --test 'bot_six_pilots_test'` (3 files).
- **TIMEBOX.** 2.5 h.
- **FORBIDDEN.** A stat that survives the run; a page that pauses longer than one input.
- **Depends on.** Nothing (B5 merged). **Shares files with.** `run_state.gd` with SR12 and SI1 (they merge after SG9).

**Uptime arithmetic for buffs in the 25 to 75 percent band** comes from the Roboquest movement note, so its block is SQ7 below.

**Run pacing and economy.** Prices stay with Andrew (section 6 item 4); what lands is the tier, the dials, the between-run options, visible odds and the sweep.

### SG10 Opt-in run tier

- **GOAL.** A player who has won once may choose a harder run tier that raises threat and pay together, shown before the choice; tier 0 is today.
- **SCOPE.** `src/core/run_tier.gd` (new: tiers 0 and 1, unlocked by a win, chosen on SG9's start card), `src/world/director_cards.gd` (KE9's file: tier 1 weights and pay rows), `src/core/profile.gd` (the unlock flag only), `src/build/parts.gd` (enhanced variant rows read only on tier 1), `tests/run_tier_test.gd` (new).
- **CONTEXT.** `BIBLE.md:475` (first victory in three to five attempts), `:463` (a permanent unlock is an option); `adr/TADR-010-open-stages-and-event-director.md:45` (the tier is the player's choice, not elapsed time); the honesty comment at `src/world/director.gd:7-8` (a code comment, amended by SG11, not a Bible line).
- **ACCEPTANCE.**
  - Park table at tier 0 and tier 1, 20 seeds each: tier 1 raises both threat (cap, interval, event rows) and pay (bonus cores, rare-part share) on every seed; the pay gain stays under its cap; tier 0 output is bit-identical to today.
  - The tier's threat and pay show on the start card before the choice.
  - An enhanced variant shares its part's id, slot and rarity, has a bigger bonus or a smaller downside, and a build holds one version only.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'run_tier_test' --test 'director_credit_test' --test 'profile_store_test' --test 'posture_bands_test' --test 'alpha_posture_bands_test'` (5 files).
- **TIMEBOX.** 3 h.
- **FORBIDDEN.** Any change at tier 0; a tier unlocked by time played.
- **Depends on.** KE9, SG4, SG9. **Shares files with.** `director_cards.gd` (after KE9); `parts.gd` (after SQ19, SG15); `profile.gd` (after SR12, SG12).

### SG11 Capped health and damage dials

- **GOAL.** On the opt-in tier, enemy health, enemy damage and aggression move on three named capped dials with a per-world step; tier 0 keeps health from the stage threat only.
- **SCOPE.** `src/world/director.gd` (`hp_scale()` at `:168-170` and a new `damage_scale()`, each capped and read only when `RunTier.tier() >= 1`; the honesty comment at `:7-8` names the tier rule), `src/core/stage_defs.gd` (per-world base step), `src/combat/counter.gd` (the rest timer reads the aggression dial), `tests/run_tier_dials_test.gd` (new).
- **CONTEXT.** `director.gd:7-8`, `:168-170`; `BIBLE.md:517` (encounters) and the readable-capped principle (`docs/decisions.tsv` design principles); `comps/ror2/director-and-difficulty.md` (Warden `1 + D/2.5` health and `1 + D/30` damage, shape only); `src/combat/counter.gd:144` (the rest gate).
- **ACCEPTANCE.**
  - Each dial swept alone moves only its own quantity and never exceeds its named cap; changing one leaves the others bit-identical.
  - The next world's first stage starts above the last world's last stage on tier 1.
  - Route and pocket lists are identical across tiers (`park_routes_test` green on each tier).
  - Tier 0: `hp_scale()` equals the stage threat at every step and `damage_scale()` is 1.0.
  - The Warden scales only on tier 1 and only if it reads `hp_scale()` today; otherwise the REPORT names the file a Warden unit must change.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'run_tier_dials_test' --test 'director_*_test' --test 'world_director_test' --test 'posture_bands_test' --test 'alpha_posture_bands_test' --test 'park_routes_test'` (expected 9 files: the new test, the four `director_*_test` files after KE9, `world_director_test`, the two band tests, `park_routes_test`).
- **TIMEBOX.** 3 h.
- **FORBIDDEN.** Any change at tier 0; a dial without a cap.
- **Depends on.** SG10, KE6, KE9. **Shares files with.** `director.gd` (after KE6, KE9); `counter.gd` (after SQ3, SQ1, SR3, SQ2).

### SG12 Between-run options

- **GOAL.** Between runs, small non-power head starts (an extra reroll, a pre-shown shelf, a pocket key) open on one-run accomplishments, so any short session can move the bar without a currency.
- **SCOPE.** `src/core/meta_options.gd` (new: node rows), `src/core/achievements.gd` (one grant per node), `src/core/profile.gd` (opened nodes), `src/ui/meta_page.gd` (new), `tests/meta_options_test.gd` (new).
- **CONTEXT.** `BIBLE.md:463`, `:475`, `:586` (options persist, combat power does not); `BIBLE.md:513` (no replacement collection thresholds or invented prices, which is why nodes are not bought); `P-UNITS.md:198` (B5 forbids price, cost or stat keys on a row); `src/core/profile.gd:14-23`.
- **ACCEPTANCE.**
  - Five simulated runs: every node row is an option, discovery or pocket key; none carries a price, cost or stat key; level equals nodes opened.
  - Each node opens on a one-run condition with any `count` at 10 or below (`grant_grammar_test`).
  - A hidden pocket's discovery can open a node; no stat field differs from a fresh profile.
  - The profile round-trips; if a new key needs a schema bump, the unit adds `_migrate_4` and its test (`profile.gd:17`).
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'meta_options_test' --test 'profile_store_test' --test 'grant_grammar_test' --test 'profile_purity_test'` (4 files).
- **TIMEBOX.** 3 h.
- **FORBIDDEN.** A meta currency; starting cogs or discounts.
- **Depends on.** B6, KD8. **Shares files with.** `achievements.gd` with the six PC units (rows outside their pre-seeded blocks, `P-UNITS.md:232`); `profile.gd` with SR12 (SG12 merges first, in wave B; SR12 follows in C).

**Shop prices measured before anyone sets them.** Exact costs stay Andrew's (`BIBLE.md:513`, owner item 4), but measuring today's prices against income decides nothing, so it runs now.

### SG16 Shop price-to-income report

- **GOAL.** A report-only shop model logs one reference item's price and the bot's scrap income per stage across the three worlds, so owner item 4 decides on measured ratios.
- **SCOPE.** `tools/shop_model.gd` (new: reads `PAY_SCRAP`, `src/world/activities.gd:28`, and `COG_PRICES`, `src/build/fabricators.gd:24`; writes a report under `artifacts/local/`), `tests/shop_model_report_test.gd` (new).
- **CONTEXT.** `comps/gunfire/run-pacing-and-economy.md:104` (the lab measure: 3 regions, 20 seeds, price to income 0.5 to 2.0 as a target); `BIBLE.md:513` (costs remain open, no invented prices); `adr/TADR-010-open-stages-and-event-director.md:63`; `tests/shop_economy_test.gd`.
- **ACCEPTANCE.**
  - 3 worlds, 20 seeds, a fixed-skill bot: per stage the report prints the reference item's price, the scrap income and their ratio, and flags every stage outside 0.5 to 2.0 and every price that falls inside a world or does not rise at a world boundary.
  - Reports only: zero price constants change; `shop_economy_test` green and unchanged.
  - The test fails on a planted empty income log (a nonzero row count is required).
- **VERIFY.** Base checks; `"$GODOT_BIN" --headless --path sketches/core-loop --script res://tools/shop_model.gd -- --seeds=1-20` (60 stage rows); `npm run sketch:smoke -- --sketch core-loop --test 'shop_model_report_test' --test 'shop_economy_test'` (2 files).
- **TIMEBOX.** 2 h.
- **FORBIDDEN.** Editing `activities.gd`, `fabricators.gd` or any price; proposing a number as adopted (a proposal goes to owner item 4).
- **Depends on.** Nothing. **Shares files with.** None.

### SG13 Visible offer odds

- **GOAL.** Every part source draws from one list, and every offer shows what it can contain and its weights, read from the row the roll reads.
- **SCOPE.** `src/build/item_gen.gd` (tier weights in one data row), `src/build/shop.gd` (an odds field in the shelf record), `src/world/activities.gd` (a stand shows its `pay.rarities` before commit), `src/ui/odds_readout.gd` (new), `tests/visible_odds_test.gd` (new).
- **CONTEXT.** `src/build/shop.gd:12-13` ("Nothing here is rolled on entry that a player cannot see"); `activities.gd:27` (`PAY_RARITIES`), `:378-382`; KD8; `comps/ror2/items-and-stacking.md` (RoR2 weights 0.8 / 0.2 / 0.01 as a reference only).
- **ACCEPTANCE.**
  - 10,000 draws per table: observed tier frequencies within the stated tolerance of the shown weights.
  - Every shown weight comes from the same data row the roll reads; find, shop and pocket id lists are subsets of one pool.
  - A stand's shown rarity equals its paid rarity over 20 seeds.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'visible_odds_test' --test 'shop_economy_test' --test 'activities_pay_test' --test 'activities_test'` (4 files).
- **TIMEBOX.** 2.5 h.
- **FORBIDDEN.** Changing a weight or a price.
- **Depends on.** KD8, B2. **Shares files with.** `activities.gd` (after KD8; SI1, SQ5 after SG13).

### SG14 Slot growth sweep arm

- **GOAL.** A headless arm measures slot growth and pair margins per milestone on a fixed dummy.
- **SCOPE.** `tools/build_sweep.gd` (SR4's tool: an `--arm=slot_growth` arm), `tests/slot_growth_sweep_test.gd` (new).
- **CONTEXT.** `comps/gunfire/weapons-and-inscriptions.md:93`; `src/core/upgrade_tree.gd`; `src/build/synergies.gd`; `BIBLE.md:538`.
- **ACCEPTANCE.** (a) slot count never decreases with milestone and reaches its maximum at the last; (b) the best paired set beats the best unpaired set by 15% to 40% at every milestone with a pair available; (c) the last milestone's best set is within 6x of the first's.
- **VERIFY.** Base checks; `"$GODOT_BIN" --headless --path sketches/core-loop --script res://tools/build_sweep.gd -- --arm=slot_growth` (prints one row per milestone, nonzero); `npm run sketch:smoke -- --sketch core-loop --test 'slot_growth_sweep_test'` (1 file).
- **TIMEBOX.** 2 h.
- **FORBIDDEN.** Tuning a part to pass.
- **Depends on.** PC-PACK, SR4. **Shares files with.** `build_sweep.gd` (after SR4).

**Elites.**

### SG6 Elite affixes

- **GOAL.** An elite carries one added behaviour plus one stat change and its name lists both; the stat steps in three published values per world.
- **SCOPE.** `src/combat/elite_affixes.gd` (new), `src/world/director_cards.gd` (an `affix` field on elite cards; a flat elite stat row read only on tier 1), `src/combat/roster.gd` (the no-reskins comment restated for affixes, `:12-15`), `tests/elite_affix_test.gd` (new).
- **CONTEXT.** `src/world/director.gd:99-101`, `:288-292` (the elite arrival path); `roster.gd:12-15`; `BIBLE.md:517`; `K-UNITS.md:346`; `comps/gunfire/enemies-and-bosses.md` (shape: three published steps).
- **ACCEPTANCE.**
  - Every affix name maps to exactly one behaviour and one stat change; each affixed row still passes the no-reskins test.
  - Each constant has exactly three published values, one per world, monotone, at or under its cap; no value scales health from the dial.
  - 50 solo spawns per affix per world step: the added attack's telegraph lead is at least 0.4 s.
  - The flat elite stat row applies only when `RunTier.tier() >= 1`.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'elite_affix_test' --test 'roster_test' --test 'enemy_roster_test' --test 'director_credit_test' --test 'posture_bands_test'` (5 files).
- **TIMEBOX.** 3 h.
- **FORBIDDEN.** An affix that is only a colour or a number.
- **Depends on.** KE6, KE9; the flat-tier line merges after SG10. **Shares files with.** `director_cards.gd` (after KE9, SG10); `roster.gd` (after SQ4).

### 3.2 Roboquest systems

**Telegraph grammar in seconds, as dials per archetype.** Wind-up, size and damage stay three separate dials (`src/combat/telegraph.gd:6-10`), checked against the 0.4 s reaction floor, with the Roboquest pre-shoot, burst, beam, recovery and cooldown numbers as start values.

### SQ1 Pack-kind telegraph record

- **GOAL.** Every pack-kind attack has one record (pre-shoot, recovery, cooldown, radius, marker class, band class), measured against the reaction floor and its damage area.
- **SCOPE.** `src/combat/telegraph_record.gd` (new), `src/combat/counter.gd` (ordinary attacks read `recovery` from the record; `warn_seconds` default at `:46`), `tests/telegraph_timing_pack_test.gd` (new: pack-kind rows; the Warden kinds keep their own `telegraph_timing_<kind>_test` files, `decisions.tsv:486c`), `tests/pack_telegraph_record_test.gd` (new), `design-v3/LEGIBILITY.md` (the marker classes and band classes beside the line memo 2 fixed at `:58`), `src/combat/chaser.gd` (`RECOVER` reads `TelegraphRecord.RECOVERY`), `src/combat/lobber.gd` and `src/combat/swarm.gd` (a standing recovery tail of the shared value after each attack, so the exception set is Warden-only; ruling 2026-10-11 w13-systems round 3).
- **CONTEXT.** `comps/roboquest/enemies-and-telegraphs.md:110`; `comps/gunfire/enemies-and-bosses.md:89`; pack warns today: bola thrower 0.5 (`src/combat/bola_thrower.gd:34`), chaser 0.6 (`src/combat/chaser.gd:12`), mind hand 1.4 (`src/combat/mind_hand.gd:26`); `src/boss/hazard.gd:19`; Warden cycle (`src/combat/warden.gd:51-52`).
- **ACCEPTANCE.**
  - 50 solo spawns per pack kind: lead from telegraph start to damage at least 0.4 s; telegraph and damage areas overlap at least 95 percent; zero kinds outside.
  - Each attack uses one marker class (circle for area, line for lunge, text for a delayed hit) drawn from the committed geometry.
  - Each kind's warn sits in its class band (area burst 0.25 to 0.5 s, projectile 0.75 s, ray 1 to 2.5 s, start) or its record logs a reason; none under 0.4 s.
  - Ordinary attacks read one recovery value (start 0.75 s); Warden attacks are on a listed exception set; the report prints each kind's recovery before and after.
  - LEGIBILITY section 2's list equals the report on every kind.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'telegraph_timing_pack_test' --test 'pack_telegraph_record_test' --test 'enemy_counters_test' --test 'posture_bands_test' --test 'alpha_posture_bands_test'` (5 files).
- **TIMEBOX.** 4 h.
- **FORBIDDEN.** Raising or lowering a warn to fit a band without a logged reason; editing `warden.gd`.
- **Depends on.** The KF2, KF3 and KF4 REPORTs (each Warden kind's four-field rows, for the exception list); no KF merge, since the three kinds and SQ1 write separate test files (`decisions.tsv:486c`). **Shares files with.** `counter.gd` (after SQ3); `LEGIBILITY.md` (after SG7).

### SQ3 Pack stagger window

- **GOAL.** Ordinary pack kinds share one interrupt window, with impact resistance as the per-kind dial; the Warden keeps its posture break.
- **SCOPE.** `src/combat/counter.gd` (a `STAGGER_WINDOW` constant, start 1.25 s; per-kind `impact_resist`), `tests/pack_stagger_test.gd` (new).
- **CONTEXT.** `counter.gd:151` (the knock-speed interrupt); `src/combat/boss_posture.gd:17` (`STAGGER_SECONDS` 4.0); `comps/roboquest/enemies-and-telegraphs.md` (1.25 s, a start value).
- **ACCEPTANCE.**
  - Every logged knock over the interrupt speed interrupts; the window is equal across pack kinds within one physics tick.
  - The ball's speed never drops because a target staggers (zero stalls in the scripted run).
  - The Warden's posture break is untouched; `posture_bands_test` and `alpha_posture_bands_test` green and unchanged.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'pack_stagger_test' --test 'enemy_counters_test' --test 'enemy_reactions_test' --test 'posture_bands_test' --test 'alpha_posture_bands_test'` (5 files).
- **TIMEBOX.** 2 h.
- **FORBIDDEN.** `boss_posture.gd`; any Warden file.
- **Depends on.** Nothing (KF1b merged). **Shares files with.** `counter.gd` (first; SQ1, SR3, SQ2, SG11 merge after).

### SQ2 Attacker budget

- **GOAL.** A cap on enemies in WARN or LIVE at once, asked where a counter decides to attack, with the Warden exempt.
- **SCOPE.** `src/combat/attack_budget.gd` (new), `src/combat/counter.gd` (the ask before `_warn`), `tests/attack_budget_test.gd` (new).
- **CONTEXT.** `counter.gd:144`; memo 2's KE9 line (`W13-INTEGRATION-2.md:151`); `comps/roboquest/enemies-and-telegraphs.md:110`; the budget size is not decoded in the source (`comps/roboquest/enemies-and-telegraphs.md:22`), so the cap comes from KE9's peak report.
- **ACCEPTANCE.** 20 seeded encounters at the park table's highest tier: the count of simultaneous attackers never exceeds the cap, zero violations; the Warden and its posture fight are exempt; the cap value cites KE9's report.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'attack_budget_test' --test 'enemy_counters_test' --test 'posture_bands_test'` (3 files).
- **TIMEBOX.** 2 h.
- **FORBIDDEN.** Changing `HARD_CAP` 24 (`src/world/director.gd:90`).
- **Depends on.** KE9. **Shares files with.** `counter.gd` (after SR3).

**Enemy families by chassis, with one read each, and production bands.**

### SQ4 Roster chassis column

- **GOAL.** Every roster row names its chassis class, movement class and one threat feature that is also its warning, and a speed table states each pilot's cruise against the enemies' speeds.
- **SCOPE.** `src/combat/roster.gd` (fields `chassis`, `move_class`, `threat_feature` on each row), `tests/roster_chassis_test.gd` (new), `tests/roster_speed_ratio_test.gd` (new).
- **CONTEXT.** `roster.gd:10-15` (one row per kind; the no-reskins rule); `src/combat/threat_grammar.gd`; `comps/roboquest/enemy-design-grammar.md:113` (the blind still test); `comps/roboquest/movement-and-feel.md` (cruise near 2.35x the median enemy speed, a ratio to test).
- **ACCEPTANCE.**
  - The three fields exist on 19 of 19 rows; a row with a blank threat feature fails.
  - 20 stills at game camera distance, three reviewers (the verifier records picks before opening the key): at least 18 of 20 named correctly for class and threat feature; zero stills with the threat feature hidden.
  - The speed table prints min, median, p90 and max enemy speed against each pilot's cruise and boost, states the declared ratio, and lists every kind above 1.2x a pilot's cruise with its telegraph row.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'roster_chassis_test' --test 'roster_speed_ratio_test' --test 'roster_test' --test 'enemy_roster_test'` (4 files); the 20 stills through the look harness on card 1 (`P-UNITS.md:40`).
- **TIMEBOX.** 3 h.
- **FORBIDDEN.** Changing a kind's mechanic, speed or numbers.
- **Depends on.** Nothing. **Shares files with.** `roster.gd` (KF0 merged; SG6 after).

### SQ18 Forge and budget retune (conditional)

- **GOAL.** After every pilot's summed triangles report, the forge pack's bands and the budget classes follow measured Scrapkeep members, with family bands reported and a from-scratch enemy recipe written.
- **SCOPE.** `tools/asset-forge/packs/core-loop.toml` (memo 2 section 3f's block made live keys), `assets/asset_budgets.json` (classes `held_item` and `pickup`; a boss bone cap; an 80-bone hero ceiling; a report-only `families` key), `tools/asset-forge/kinds/model/brief.enemy.md` (new: the recipe), `scripts/budget-audit.test.mjs` (SQ17's test, new cases).
- **CONTEXT.** `W13-INTEGRATION-2.md:204-220` (the proposal); `assets/asset_budgets.json:3-8` (enemy 1,100 tris set by its members), `:39-50`; `K-UNITS.md:161` (KC0 was the json's sole editor; it has merged, so this unit takes the role with a dated note); `comps/roboquest/enemy-design-grammar.md` (bones median 16 pod and airborne, 24 labourer, 37 small walker, 46 heavy, 54 ground walker); `comps/gunfire/production-budgets.md` (weapon median 420, p90 3,753 tris); `comps/ror2/production-budgets.md` (pickup 70 to 2,200 tris, 8 bones).
- **ACCEPTANCE.**
  - Applies only when all six C5b sums are in a REPORT; if any class V sum exceeds 16,000 tris (`asset_budgets.json:43`) the unit stops and reports.
  - The hero band comes from the measured class V sums; pilots keep the 25-bone rig under the 80-bone ceiling.
  - `held_item` and `pickup` each have at least one member before a cap is set, and each cap equals its largest member (the json's own rule); the enemy cap moves only if a member exceeds 1,100.
  - Family bands print per chassis (from SQ4's column) and edit no cap.
  - The recipe names base, chassis, one lens as threat feature, band and rig size; it is validated by re-describing one existing enemy (the plated brute); SQ20 forges the first from-scratch family as its lab run.
- **VERIFY.** `node sketches/core-loop/tools/budget_audit.mjs` (every category nonzero); `node --test scripts/budget-audit.test.mjs` (states its case count); `npm run sketch:smoke -- --sketch core-loop --test 'asset_registry_test'` (1 file); lint; fence.
- **TIMEBOX.** 3 h.
- **FORBIDDEN.** Any download; an enemy cap change without a member over 1,100.
- **Depends on.** SQ17, SQ4, the six C5b sums. **Shares files with.** `asset_budgets.json` (KC0 merged); `budget-audit.test.mjs` (after SQ17).

### SQ20 First from-scratch enemy family

- **GOAL.** One new enemy family is forged from SQ18's recipe under the 1,100-tri enemy cap and passes the note's band and blind-still read, so the recipe has its lab run.
- **SCOPE.** The forge's model kind (`tools/asset-forge/kinds/model/`) run with `brief.enemy.md`; the family's promoted model files at the paths the unit lists in its REPORT before the first write; `artifacts/local/` for stills and the report. **Writer.** Opus (it must locate the promote paths).
- **CONTEXT.** `comps/roboquest/enemy-design-grammar.md:113` (the lab measure); SQ18's recipe and family bands; SQ4's `chassis` column; `assets/asset_budgets.json:3-8` (enemy 1,100 tris); owner item 1 (a CC0 base only if Andrew approves a named batch; otherwise from scratch).
- **ACCEPTANCE.**
  - Bones and triangles inside the band for its chassis class from SQ18's lab config; triangles at or under 1,100; the REPORT records bones, triangles, authored clips and threat-feature visibility.
  - 20 stills at game camera distance, three readers with picks recorded before the key opens: at least 18 of 20 name the chassis class and the threat feature; zero stills with the threat feature hidden.
  - `budget_audit.mjs` lists the family inside every enemy cap.
- **VERIFY.** `node sketches/core-loop/tools/budget_audit.mjs` (every category nonzero); `npm run sketch:smoke -- --sketch core-loop --test 'asset_registry_test'` (1 file); the 20 stills through the look harness on card 1 and the uat runner (receipt path in REPORT); lint; fence.
- **TIMEBOX.** 4 h.
- **FORBIDDEN.** Any download; a roster row or any gameplay use of the family; an enemy cap change.
- **Depends on.** SQ18, SQ4. **Shares files with.** None (new files only; the registry refold is the coordinator's at merge).

**The stage anatomy and the pocket library with its draw.** The draw answers Q-P23 for pockets only, as "seeded authored encounter assembly", one of the two candidates the Bible keeps open (`BIBLE.md:580`; `adr/TADR-010-open-stages-and-event-director.md:63`); stage layout stays assembled from the run-level layout stream before entry, never by the director (`adr/TADR-010-open-stages-and-event-director.md:43`).

### SQ13 Zone anchors

- **GOAL.** The stage graph also bakes landform zones joined by one-move crossings and ranks degree-1 zones as pocket anchors by path distance.
- **SCOPE.** `tools/park_graph.gd` (a zone pass), `src/world/park/park_graph.gd` (`zones()`, `anchors()`), `tests/park_zones_test.gd` (new).
- **CONTEXT.** KB8 (`K-UNITS.md:127-143`); `comps/pocket-placement.md:62`; `comps/isaac/floor-generation.md:107`.
- **ACCEPTANCE.** Two bakes byte-identical; over 1,000 seeded jitters of each door among its `door_ok` nodes, the guaranteed pockets sit at the two costliest anchors off the shortest route on at least 95% of seeds; every hidden pocket borders at least 3 zones (`comps/isaac/floor-generation.md:107` (c)); re-roll rate at most 20%.
- **VERIFY.** Base checks; the tool twice on `park_test` and `cmp`; `npm run sketch:smoke -- --sketch core-loop --test 'park_zones_test' --test 'park_graph_test' --test 'park_pockets_test'` (3 files).
- **TIMEBOX.** 3 h.
- **FORBIDDEN.** Moving any authored position.
- **Depends on.** KB8. **Shares files with.** `park_graph.gd` and `src/world/park/park_graph.gd` (after KB8, SR15; SQ15, SQ14 after).

### SQ15 Closable sockets

- **GOAL.** Each zone has 2 to 4 openings and a stage builder closes unused ones with a filler landform off the shortest route, a pocket anchor keeping exactly one.
- **SCOPE.** `src/world/park/sockets.gd` (new), `tools/park_sockets.gd` (the `--sockets` laboratory, isolated from graph freshness by the coordinator's 2026-10-12 ruling), `tests/park_sockets_test.gd` (new).
- **CONTEXT.** KC0's `greybox:` placement (`K-UNITS.md:155`); `design-v3/PARK.md:138`, `:350`; `comps/roboquest/stage-anatomy.md:125`.
- **ACCEPTANCE.** 1,000 seeded stages per arm, fixed entrances against closable sockets: on at least 95% of socket seeds, pocket count 3 to 8, no guaranteed pocket on the shortest route, re-roll under 10% and at most half the fixed rate, full-visit ratio at most 3.0; every filler sits off the shortest route.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'park_sockets_test' --test 'park_zones_test'` (2 files); `tools/park_sockets.gd -- --sockets=1000`, 1,000 seeds per arm.
- **TIMEBOX.** 3 h.
- **FORBIDDEN.** Editing a stage's park file.
- **Depends on.** SQ13, KC0. **Shares files with.** None; `tools/park_sockets.gd` preloads the socket laboratory without changing the graph baker.

### SQ12 Pocket library

- **GOAL.** Authored pocket interiors live in one library with kind, footprint, entrances, difficulty, weight, density and tell, each readable on entry.
- **SCOPE.** `src/world/park/pocket_library.gd` (new), `src/world/park/pockets/w1/*.json` (new: world one's 24 interiors, 8 per kind arena, trade, secret, starting from the approved journeys' pockets), `tests/pocket_library_test.gd` (new), `tests/pocket_entry_test.gd` (new).
- **CONTEXT.** `comps/isaac/rooms.md:101`; `design-v3/PARK.md:254-271`, `:266` (the 40 m clear ring as the start entry radius); `src/world/activities.gd:27-46`.
- **ACCEPTANCE.**
  - Every row has kind, footprint (small, medium, large), marked entrances, difficulty 1, 5 or 10, weight (default 1, rare 0.1, never 0), density shares (60 to 70% terrain, 20 to 30% enemies, 5 to 10% pickups, start), a tell and an entry radius.
  - 50 idle and 50 scripted-dodger entries per pocket: idle takes no damage in the first 2 s in at least 95%; the dodger clears at least 80% of difficulty-1 pockets and fewer than 80% of difficulty-10 ones; every pocket shows one safe path of the minimum width from its entry spot.
  - Health sum rises by difficulty at least as fast as count.
  - Worlds 2 and 3's pools follow as two resumes of this unit after their stages' dressed passes.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'pocket_library_test' --test 'pocket_entry_test' --test 'park_pockets_test'` (3 files).
- **TIMEBOX.** 6 h.
- **FORBIDDEN.** Editing a stage's park file.
- **Depends on.** KD1 to KD6 greyboxes, KD8, KB8. **Shares files with.** None.

### SQ14 Pocket draw

- **GOAL.** Fixed pocket slots per stage draw from the authored library through a pocket credit pool, so variety comes from library breadth while every drawn set keeps PARK.md 2.12's rules.
- **SCOPE.** `src/world/park/pocket_draw.gd` (new: slots 3 on stage 1, plus one per stage, cap 8; weight draw from the layout stream; credit pool 150 with refund and the next anchor on a failed placement; chance pockets at 25% per leftover anchor; large pockets first; interactable scatter outside door rings; candidate bonus side-door sites drawn at assembly from the layout stream), `tools/park_graph.gd` (a `--pockets=draw` arm and a size sweep), `src/world/director.gd` (after an objective the director only opens one of the pre-drawn candidate doors, odds `p0/(n+1)`, from the director stream; it never places one), `tests/pocket_draw_test.gd` (new).
- **CONTEXT.** `comps/pocket-placement.md:62`; `comps/ror2/stage-anatomy.md:121`; `comps/gunfire/stage-anatomy.md:114`; `comps/maps-compared.md` (352 to 611 m a side; a pocket about 1% of the floor); `adr/TADR-010-open-stages-and-event-director.md:43`.
- **ACCEPTANCE.**
  - 1,000 seeded stages: at least 8 distinct pocket sets per template; every interior drawn at least once; pocket count 3 to 8 on at least 95%; p90 over p10 detour ratio at least 2.
  - 200 seeds per template: zero credit lost after a failed placement; 3 to 5 pockets plus one hidden on at least 95%; spawn-to-objective share at least 0.6 on 95%; zero interactables in door rings.
  - Chance rate 25% within +/-3 points; zero routes cut by a large pocket.
  - Bonus door: probability at count n equals `p0/(n+1)` within sampling error; every candidate site is fixed at assembly before stage entry (`adr/TADR-010-open-stages-and-event-director.md:43`) and the director only opens one; every door inside its 0 to 30 m band and `sight_ok`; zero exits gated.
  - Every drawn set passes `park_pockets_test`'s rules.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'pocket_draw_test' --test 'park_pockets_test' --test 'park_zones_test' --test 'world_director_test'` (4 files); the draw arm at 1,000 seeds.
- **TIMEBOX.** 5 h.
- **FORBIDDEN.** The director choosing layout; editing a park file.
- **Depends on.** SQ12, SQ13. **Shares files with.** `park_graph.gd` (after SQ13, SQ15); `director.gd` (after KE6, KE9).

### SQ16 Hidden-pocket edge tint

- **GOAL.** A discovered hidden pocket door inside 240 m with `sight_ok` shows an amber edge marker.
- **SCOPE.** `src/ui/edge_markers.gd` (one marker kind), `tests/ui_edge_marker_pocket_test.gd` (new).
- **CONTEXT.** `edge_markers.gd:8-12`; `design-v3/PARK.md:265`; memo 2's reading (`W13-INTEGRATION-2.md:43`).
- **ACCEPTANCE.** On all six stages the marker is absent outside 240 m or without `sight_ok`, present inside both, and never shown for an undiscovered door.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'ui_edge_marker_pocket_test'` (1 file).
- **TIMEBOX.** 1.5 h.
- **FORBIDDEN.** A map; a 60 m range.
- **Depends on.** KB8. **Shares files with.** None.

### SQ5 Pocket kinds ladder

- **GOAL.** Pockets come in a ladder of kinds with fixed bundles and a shown reward tier: movement course, arena, elite arena, objective under a limit, round arena and ambush, plus an optional scattered-mark objective that never gates the exit.
- **SCOPE.** `src/world/activities.gd` (RULES rows `movement_course`, `arena`, `elite_arena`, `objective_limit`, `round_arena`, `scattered_marks`; the ambush wave script; heal and chest on clear; a pocket's own hazards off on clear; the stand's tier shown before commit), `src/world/events/pocket_fog.gd` (new: the round arena's fog and safe zone as an event row), `tests/pocket_kinds_test.gd` (new).
- **CONTEXT.** `activities.gd:13-46`; KD8 (`K-UNITS.md:255-269`, which forbade a `surge_run` rule as "a design unit of its own"; this is that unit); `design-v3/PARK.md:256`, `:266`; `BIBLE.md:519`; `comps/gunfire/stage-anatomy.md`, `comps/ror2/events-and-objectives.md`, `comps/isaac/pacing-and-trades.md:97`.
- **ACCEPTANCE.**
  - The reward tier rises across movement course, arena, elite arena and objective on every stage file; the shown tier equals the paid tier over 20 seeds.
  - The elite arena: zero pocket enemies alive 1 s after the elite dies; elite arrivals per stage at most 3.
  - Round arena: credits per round `(base + step x (round - 1)) x D` within 1%, D capped; each round adds exactly one new element; pay events equal the round count; the safe zone is announced at least the family lead before the next round; no damage outside the committed fog geometry.
  - Ambush: 3 waves of 1 to 5; the exit opens on clear in 100%; zero main-route placements.
  - Zero hazard damage in a pocket after its clear in 100% of seeded runs; each authored arena carries at least one hazard that switched off.
  - The objective kind is a timed pickup that counts ticks (`adr/TADR-010-open-stages-and-event-director.md:45`); the movement course has no gate; the exit opens with every pocket skipped.
  - Scattered marks (`comps/roboquest/stage-anatomy.md:109`), over 1,000 seeded stages that draw the kind: 3 to 4 marks, each pair at least 80 m apart by path, every mark in the far half by path distance, found in any order; the exit opens with zero marks taken in 100%. The kind is optional and pays like any pocket; what an exit requires stays Q-P38 (`adr/TADR-010-open-stages-and-event-director.md:63`).
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'pocket_kinds_test' --test 'activities_test' --test 'activities_camp_test' --test 'activities_pay_test' --test 'bot_explorer_activities_test'` (5 files).
- **TIMEBOX.** 5 h.
- **FORBIDDEN.** Changing `PAY_SCRAP`; a pocket that holds the exit.
- **Depends on.** KD8, KE1, KE6. **Shares files with.** `activities.gd` (after KD8, SG13, SI1).

**Weapons and affixes.**

### SQ10 Pilot weapon envelope report

- **GOAL.** Each pilot weapon is stated as an envelope of shown numbers, with the spreads the note measured as the target.
- **SCOPE.** `tests/weapon_envelope_test.gd` (new), `design-v3/PILOTS.md` (an envelope column).
- **CONTEXT.** `src/combat/weapons.gd:32-45` (damage, rate, range, speed, bolt radius per weapon); `design-v3/PILOTS.md:11-18`; `P-UNITS.md:236` (PC units own kit numbers).
- **ACCEPTANCE.** The table maps clip to weapon charges, reload to recharge and spread to bolt radius and aim cone, for all six weapons; it prints whether reload medians sit within 1.2x and clip and spread medians each span at least 3x; it reports now and gates from PC-PACK, whose units own the numbers.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'weapon_envelope_test'` (1 file).
- **TIMEBOX.** 1.5 h.
- **FORBIDDEN.** Editing `weapons.gd`.
- **Depends on.** Nothing. **Shares files with.** `PILOTS.md` (after SQ7).

### SQ11 Weapon-local attachment layer

- **GOAL.** Each pilot's one weapon takes attachments as a weapon-local layer beside the player-global tree; an attachment's tier sets its count and the top tier adds a second fire mode, shown before equipping.
- **SCOPE.** `src/build/attachments.gd` (new), `src/combat/weapons.gd` (reads attachment mods), `src/ui/build_readout.gd` (SG3's file: tier and second mode), `tests/attachment_layer_test.gd` (new).
- **CONTEXT.** `BIBLE.md:552` (rebuild from current selections); `BIBLE.md:432` (Path, Relic and Parts); `src/build/parts.gd:399-415`; `comps/roboquest/weapons-and-affixes.md:95`.
- **ACCEPTANCE.**
  - 1,000 sampled weapons per category on a fixed dummy: a representative global perk changes DPS by a similar share on every category, within 15% of one another.
  - Removing an attachment returns DPS to baseline exactly.
  - No tier outside its count range (0 to 3); the top tier always carries its second mode and shows it before equipping.
  - Each pilot still wins at least 3 of seeds 1 to 4.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'attachment_layer_test' --test 'bot_six_pilots_test' --test 'posture_bands_test'` (3 files).
- **TIMEBOX.** 4 h. **Writer.** Opus.
- **FORBIDDEN.** A price; a colour ladder for tiers.
- **Depends on.** PC-PACK, SG3. **Shares files with.** `weapons.gd` (after PC-PACK); `build_readout.gd` (after SG3).

**Classes and perks.**

### SQ19 Weighted offers

- **GOAL.** Each pilot's offers lean to its own kit by a declared share, with a neutral shelf that never stalls a build.
- **SCOPE.** `src/build/parts.gd` (`offer_pool` at `:400`: class-weighted share; neutral rows with a repeat cap), `tests/offer_weights_test.gd` (new).
- **CONTEXT.** `parts.gd:399-415`; `comps/roboquest/classes-and-perks.md:82`; `comps/gunfire/heroes-and-ascensions.md:87`; `BIBLE.md:65`.
- **ACCEPTANCE.** 200 draws per pilot with a greedy and a random bot: weighted share inside 60 to 80% for every pilot; top-10 most-offered overlap between any two pilots under 50%; each pilot's two dominant offer buckets (weapon, skill, defence, movement) differ from every other pilot's pair (`comps/gunfire/heroes-and-ascensions.md:87`); every pilot's tree reaches an endpoint in each slot by the last milestone with both bots (`comps/roboquest/classes-and-perks.md:82` (d)); movement share at most 15%; no neutral part over its repeat cap; a draw with no weighted part still shows a neutral choice; each pilot wins at least 3 of seeds 1 to 4.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'offer_weights_test' --test 'parts_pool_movement_test' --test 'bot_six_pilots_test'` (3 files).
- **TIMEBOX.** 2.5 h.
- **FORBIDDEN.** Another class's mod in an offer.
- **Depends on.** PC-POOL. **Shares files with.** `parts.gd` (after PC-POOL, SG4; SG15 after).

### SQ6 Combat cooldown refunds

- **GOAL.** Hits landed and damage taken shorten a pilot's mobility or Shift cooldown by a capped amount, so fighting feeds movement.
- **SCOPE.** `src/core/ability_state.gd` (a `REFUNDS` table through `refund()` at `:320`), `src/core/event_kinds.gd` (one row `cooldown_refunded`), `tests/cooldown_refund_test.gd` (new).
- **CONTEXT.** `ability_state.gd:318-321` (the skid refund); `src/build/items.gd:106` (a kill refunds a weapon charge); `comps/roboquest/movement-and-feel.md` (1 to 2 s on 8 to 15 s cooldowns, start).
- **ACCEPTANCE.** Per pilot with scripted hits and damage: each refund 1 to 2 s; no pilot's effective Shift cooldown under half its base; a per-stage refund cap holds; no mobility at 100% uptime; posture bands unchanged.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'cooldown_refund_test' --test 'ability_swap_pressure_test' --test 'spine_event_kinds_test' --test 'posture_bands_test' --test 'alpha_posture_bands_test'` (5 files).
- **TIMEBOX.** 2.5 h.
- **FORBIDDEN.** A pilot's base cooldown.
- **Depends on.** Nothing (B1 merged). **Shares files with.** `ability_state.gd` with B3 (merge after B3; the six PC units merge after SQ6); `src/core/event_kinds.gd` with B3, KF2 and KE1 (order B3, SQ6, KF2, KE1, after KC0's merged `K-UNITS.md:161` order; SQ6 and KF2 add disjoint rows, so if KF2, already in flight, is ready first it merges first and SQ6 rebases).

### SQ7 Uptime table

- **GOAL.** Every timed movement or speed buff states its uptime, and the band 25% to 75% is checked.
- **SCOPE.** `tests/pilot_uptime_test.gd` (new: reads the buff rows in `ability_state.gd`), `design-v3/PILOTS.md` (an uptime column and each row's cooldown start rule).
- **CONTEXT.** `design-v3/PILOTS.md:11-18`; `comps/roboquest/movement-and-feel.md` (25% to 75%); Rivet's 3 s x1.6 Overdrive Blast first (`design-v3/PILOTS.md:14`).
- **ACCEPTANCE.** Every buff row prints duration over cooldown and names whether the cooldown starts at activation or at expiry; today's rows are reported; from PC-PACK the test gates every row inside 25% to 75%.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'pilot_uptime_test'` (1 file).
- **TIMEBOX.** 1.5 h.
- **FORBIDDEN.** Editing a kit number.
- **Depends on.** Nothing. **Shares files with.** `PILOTS.md` (SQ10, SQ8 after).

### SQ8 Baseline ratios

- **GOAL.** Each pilot's baseline is stated as ratios to the others, so the characters differ in baseline as well as movement and tree.
- **SCOPE.** `design-v3/PILOTS.md` (declared ratios), `src/core/class_def.gd` (baseline health and growth rows only), `tests/pilot_baseline_ratio_test.gd` (new).
- **CONTEXT.** `PILOTS.md:11-18`; `docs/playtests/PLAYTEST-LOG.md:128`; `comps/roboquest/classes-and-perks.md`.
- **ACCEPTANCE.** 200 bot runs: ratios within the declared tolerance; every pilot wins at least 3 of seeds 1 to 4; posture band tests unchanged or re-pinned with a dated header.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'pilot_baseline_ratio_test' --test 'bot_six_pilots_test' --test 'posture_bands_test' --test 'alpha_posture_bands_test' --test 'alpha_posture_bands_w23_test'` (5 files, solo).
- **TIMEBOX.** 2.5 h.
- **FORBIDDEN.** `pack_scale` (PC-PACK's).
- **Depends on.** PC-PACK. **Shares files with.** `class_def.gd` (after the six PC units).

**Movement capture method.** The note owes a 60 fps capture of the source (`comps/roboquest/movement-and-feel.md:81`); that recording is Andrew's hands item at the end of section 6. SQ9 builds from the start values and its traces become the Scrapkeep side of that comparison.

### SQ9 Speed bank

- **GOAL.** The shared roll banks speed: it starts above cruise, decays to it, and a jump late in the decay keeps the burst.
- **SCOPE.** `src/movement/player_ball.gd` (the bank and the spend window), `src/movement/tuning.gd` (per-pilot bank rows), `tests/speed_bank_test.gd` (new).
- **CONTEXT.** `comps/roboquest/movement-and-feel.md` (1.2 to 1.3x; last 25%; at least 90%); `design-v3/PILOTS.md:11-18`; `P-UNITS.md:120` (`player_ball.gd` shared with B3, PC-SABLE, PC-RIVET).
- **ACCEPTANCE.** Scripted roll, slide and jump from a fixed start for each pilot: burst-to-cruise inside 1.2 to 1.3; a jump inside the last 25% of the decay keeps at least 90% of the burst and one outside does not; the six traces differ in shape, not only scale; `char_movement_test` green; traversal on the alpha table for six pilots at 8 seeds stays inside its bands.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'speed_bank_test' --test 'char_movement_test' --test 'bot_six_pilots_test'` (3 files); `tools/traversal_line.gd` per pilot as `K-UNITS.md:240` runs it.
- **TIMEBOX.** 3 h.
- **FORBIDDEN.** A pilot's Shift; a traversal band.
- **Depends on.** B3, PC-SABLE, PC-RIVET. **Shares files with.** `player_ball.gd` (after them); `src/movement/tuning.gd` (B7 wrote it and has merged, `P-UNITS.md:219`; SQ9 merges after any PC unit that lists it; section 8's merge order).

**Production budgets, all three packs.**

### SQ17 Budget audit

- **GOAL.** One headless audit measures every promoted asset by category against its caps and prints the comparison table, so forge bands move on Scrapkeep's own numbers.
- **SCOPE.** `scripts/asset-inspect.mjs` (bones, clip count and longest clip per asset; today it counts animations only, `:463`), `sketches/core-loop/tools/budget_audit.mjs` (new), `scripts/budget-audit.test.mjs` (new).
- **CONTEXT.** `assets/asset_budgets.json:3-8`, `:39-50`; `comps/ror2/production-budgets.md:137`; `comps/gunfire/production-budgets.md:169`; `comps/roboquest/production-budgets.md:169`; `tools/asset-forge/packs/core-loop.toml:9-11` (the json's classes override the toml bands).
- **ACCEPTANCE.**
  - Prints per category the asset count (nonzero, or the run fails), median and p90 of triangles, bones, clips, longest clip and texture side, beside the three-game reference rows.
  - A per-whole-character column sums shell, heft layers and pilot body.
  - Zero assets over their category cap; a texture above 2,048 passes only with an exception field; enemy bones at or under 40.
  - Edits no budget file.
- **VERIFY.** `node sketches/core-loop/tools/budget_audit.mjs` (exit 0, every category nonzero); `node --test scripts/budget-audit.test.mjs` (states its case count, including a planted empty category that fails); lint; fence.
- **TIMEBOX.** 3 h.
- **FORBIDDEN.** Editing `asset_budgets.json` or the forge pack.
- **Depends on.** Nothing. **Shares files with.** `asset-inspect.mjs` (none in flight; PD units call it).

### 3.3 RoR2 and Isaac systems

**Credit director with the capped dial behind a lab arm.** KE9 is already defined (`K-UNITS.md:343-358`); section 4 schedules it and adds its lines. **Baked graph flags.** KB8 is in flight, so its next checks are a new unit.

### SR15 Graph checks, round two

- **GOAL.** The stage graph also checks that the beacon sits on an objective-fit node, checks beacon before spawn, and reports the reward-to-objective ratio and the full-visit ratio; the KD stage units gate both ratios on their own files (paste 4f).
- **SCOPE.** `tools/park_graph.gd` (a `beacon_ok` flag: a flat open disc whose radius derives from the Warden engage ring), `tests/park_graph_test.gd`, `tests/park_pockets_test.gd`.
- **CONTEXT.** KB8 (`K-UNITS.md:127-143`); `comps/ror2/stage-anatomy.md:112` (copy no RoR2 constants); `comps/isaac/floor-generation.md:107` (the 1.5 reward-to-objective ratio); `W13-INTEGRATION-2.md:44`.
- **ACCEPTANCE.** The fixture beacon passes `beacon_ok` and a planted ledge beacon turns the test red; beacon is checked before spawn and a failure names which rule failed first; the report prints the median spawn-to-reward over spawn-to-objective ratio (target at least 1.5) and `full_visit_ratio` (target at most 3.0), reported, not gated, as KB8 left it (`K-UNITS.md:138`); a planted fixture row that breaks either target is printed as out of target.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'park_graph_test' --test 'park_pockets_test'` (2 files).
- **TIMEBOX.** 2 h.
- **FORBIDDEN.** Moving a beacon or spawn.
- **Depends on.** KB8. **Shares files with.** `park_graph.gd` and both tests (after KB8; merges before the KD greyboxes so their runs print the two ratios).

**Stacking families, proc coefficient and chain mask.**

### SR4 Stack sweep and the spike family

- **GOAL.** A whole-pool sweep proves every stacking family stays readable, and a rare capped spike family exists for the big-jump feel.
- **SCOPE.** `src/build/part_def.gd` (`STACK_RULES` gains `spike`, capped at 8x base, at most one per tier, `:56`), `tools/build_sweep.gd` (new: a stack arm, 1 to 20 copies per family with time to kill; a composition arm, 10,000 random 6-part builds), `tests/stack_sweep_test.gd` (new).
- **CONTEXT.** `part_def.gd:56`, `:128-141`; `src/build/triggers.gd:23`; `comps/ror2/items-and-stacking.md:96`; `comps/isaac/items-and-synergies.md:89`; the first memo's default 9 ("no exponential family", `W13-INTEGRATION.md:311`), which this replaces with a capped one.
- **ACCEPTANCE.** (a) every ceiling-family stat at stack 20 sits under its cap and rises with shrinking steps; (b) no spike above 8x base, at most one spike part per tier; (c) the composition arm: at least 30% of builds reach 3 or more tags, zero unspecified pairs against an explicit independent-pairs table (an undeclared pair counts as unspecified), within-run repeats reported per 10,000 draws against a target of 1 and not gated (ruling 2026-10-11 w13-systems round 3: the stacking families want copies, so the Isaac no-repeat rule is report-only here); time to kill printed per row.
- **VERIFY.** Base checks; `"$GODOT_BIN" --headless --path sketches/core-loop --script res://tools/build_sweep.gd -- --arm=stack` and `--arm=compose` (nonzero rows); `npm run sketch:smoke -- --sketch core-loop --test 'stack_sweep_test' --test 'build_parts_test' --test 'synergy_slice_test'` (3 files).
- **TIMEBOX.** 3 h.
- **FORBIDDEN.** An uncapped spike.
- **Depends on.** Nothing. **Shares files with.** `part_def.gd` (SG3, SG15, SI4, SI5 after).

### SR11 Chain mask

- **GOAL.** One bit per proc type per hit stops any type repeating in one chain while distinct sources still combine.
- **SCOPE.** `src/build/triggers.gd` (`MAX_CHAIN_DEPTH` 1 at `:23` becomes a per-hit proc-type mask), `tests/chain_mask_test.gd` (new).
- **CONTEXT.** `triggers.gd:23`; `src/build/item_effects.gd` (the one chaining part today); `W13-INTEGRATION.md:200`.
- **ACCEPTANCE.** Five distinct sources in one hit: each fires at most once; zero same-type repeats; today's single-chain behaviour unchanged.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'chain_mask_test' --test 'combat_resolve_part_test' --test 'stack_sweep_test'` (3 files).
- **TIMEBOX.** 2 h.
- **FORBIDDEN.** A chain deeper than its mask allows.
- **Depends on.** PC-PACK. **Shares files with.** None.

**Seen-weight pool decay and three-of-a-set transformations.** Decay exists (`src/build/parts.gd:429-433`, `:465`); the bits, cache and sets land here.

### SI4 Shot bits

- **GOAL.** Each part adds zero to two behaviour bits from a closed set, a shot carries the OR of its parts' bits, and one table maps each bit to its colour, sound and rule.
- **SCOPE.** `src/build/shot_bits.gd` (new: pierce, bounce, split, pull, heat), `src/build/part_def.gd` (a `bits` field), `src/combat/bolts.gd` (children copy the set), `tests/shot_bits_test.gd` (new).
- **CONTEXT.** `comps/isaac/items-and-synergies.md:89`; `adr/TADR-008-ability-contract.md:24` (no general framework or scripting language: a closed table only); `BIBLE.md:552`.
- **ACCEPTANCE.** 10,000 6-part builds: zero unspecified bit pairs; at least 30% reach 3 bits; at most 3 bits per shot, or every bit past two has a tell; the worst build inside the frame budget; set operations only, never equality on the set.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'shot_bits_test' --test 'stack_sweep_test'` (2 files).
- **TIMEBOX.** 3 h.
- **FORBIDDEN.** Copying a bit list or width from the source.
- **Depends on.** PC-PACK. **Shares files with.** `part_def.gd` (after SR4, SG3); `bolts.gd` (SR2 after).

### SI5 Stat cache

- **GOAL.** Parts declare which stat categories they touch, and the cache recomputes only those on pickup and respec.
- **SCOPE.** `src/build/stat_cache.gd` (new), `src/build/part_def.gd` (a `touches` field), `tests/stat_cache_test.gd` (new).
- **CONTEXT.** `BIBLE.md:564` (respec removes the derived bonus); `comps/isaac/items-and-synergies.md`.
- **ACCEPTANCE.** 1,000 random builds: cached stats equal a full recompute; zero recomputes per tick outside pickups and respec.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'stat_cache_test' --test 'build_parts_test'` (2 files).
- **TIMEBOX.** 2 h.
- **FORBIDDEN.** Changing a stat value.
- **Depends on.** PC-PACK. **Shares files with.** `part_def.gd` (after SI4).

### SI6 Three-part sets

- **GOAL.** Three distinct parts of one set give an optional rule change shown on the mech; losing one removes it and keeps the discovery.
- **SCOPE.** `src/build/part_sets.gd` (new), `src/presentation/set_tell.gd` (new: the on-mech tell), `tests/part_sets_test.gd` (new).
- **CONTEXT.** `BIBLE.md:552` (optional transformations), `:564`, `:688`; `src/build/synergies.gd:42`.
- **ACCEPTANCE.** The sweep reports the share of builds completing a set; respec removes the effect and keeps the discovery; duplicates never count; no set is needed to clear a route.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'part_sets_test' --test 'shot_bits_test' --test 'stat_cache_test'` (3 files).
- **TIMEBOX.** 3 h.
- **FORBIDDEN.** A mandatory set.
- **Depends on.** SI4, SI5. **Shares files with.** None.

**Floor generation and room rules where the park's authored tables can host them.** The anchors, library and draw are SQ13, SQ12 and SQ14 (Roboquest's stage note measured the same system); Isaac's trades and stage modifiers land here.

### SI1 Trade pockets

- **GOAL.** Trade pockets come in a risk family and a safe family with opposing memory, recency-weighted odds, curse and sacrifice kinds, and every applied modifier on the results screen.
- **SCOPE.** `src/world/trade_pockets.gd` (new: families, recency x0.5 and x0.25, curse 1 in 7 with a 0.2-floor pool, sacrifice 1 in 7 with a full-health bump), `src/world/activities.gd` (RULES rows `trade_risk`, `trade_safe`, `curse`, `sacrifice`; the family an authored trade site shows is rolled at stage entry from the layout stream), `src/core/run_state.gd` (run-scoped trade memory), `src/ui/results_odds.gd` (new), `tests/trade_pockets_test.gd` (new).
- **CONTEXT.** `comps/isaac/pacing-and-trades.md:97`; `src/world/bet_crate.gd:3-14`; `adr/TADR-010-open-stages-and-event-director.md:47` (no director fact is durable; this memory is run state, ending with the run).
- **ACCEPTANCE.** 10,000 simulated runs of 8 stages, policies always-risk and never: mean trade pockets per run 1.5 to 3; back-to-back stages in at most 30% of runs; the safe family gone after a risk trade in 100%; refusing raises safe odds at least 1.2x in at least 80%; a price shows before entry on every trade pocket; idle entry takes no damage in the first 2 s in 95% of 50 runs; every seen pocket lists its modifiers on the results screen; a skip-all policy adds zero main-route time (`comps/isaac/pacing-and-trades.md:97` (e)).
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'trade_pockets_test' --test 'activities_test' --test 'activities_pay_test'` (3 files).
- **TIMEBOX.** 4 h.
- **FORBIDDEN.** A permanent loss of a main resource; a price in scrap.
- **Depends on.** KD8, KD1 to KD6 greyboxes. **Shares files with.** `activities.gd` (after KD8, SG13); `run_state.gd` (after SG9, SR12).

### SI2 Stake devices

- **GOAL.** A trade chest, a blood shrine and a healing ward each state what is paid and what is won before commitment, with no scrap price.
- **SCOPE.** `src/world/stake_devices.gd` (new), `src/world/interact.gd` (their streams, as `bet_crate.gd` uses), `tests/stake_devices_test.gd` (new).
- **CONTEXT.** `src/world/bet_crate.gd:3-14` (one wager per stage, replayed on restart); `src/core/run_state.gd:24-27` (scrap as armour); `BIBLE.md:513` (the rising-price shrines are not adopted).
- **ACCEPTANCE.** Over 20 seeds, each tier taken once: cost shown equals cost charged in 100%; payout tier monotone with cost (25%, 50%, 75% of health, or a cogs price from `COG_PRICES`); no option can kill (a stated health floor); one purchase per device per stage; a stage restart replays the same result; `bet_crate.gd` unchanged.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'stake_devices_test' --test 'shop_economy_test'` (2 files).
- **TIMEBOX.** 3 h.
- **FORBIDDEN.** A new price constant; a rising price.
- **Depends on.** KD8. **Shares files with.** `interact.gd` (none in flight).

### SI3 Stage modifiers

- **GOAL.** At most one modifier per stage, shown before it starts, may scale pocket count or visibility or restrict anchors to the farthest few, never touching handling.
- **SCOPE.** `src/world/events/stage_modifier.gd` (new, KE7's weather-module pattern), `src/world/park/pocket_draw.gd` (SQ14's file: count scale and farthest-N anchors), `tests/stage_modifier_test.gd` (new).
- **CONTEXT.** KE7 (`K-UNITS.md:321-330`); `adr/TADR-010-open-stages-and-event-director.md:47` (a stage-start parameter, never a durable field); `comps/isaac/floor-generation.md:107`.
- **ACCEPTANCE.** Shown pre-stage in 100%; at most one per stage; counts within cap; specials only in the farthest-N anchors; handling identical over 600 stepped ticks; modifier off is byte-identical.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'stage_modifier_test' --test 'pocket_draw_test' --test 'park_weather_test'` (3 files).
- **TIMEBOX.** 2.5 h.
- **FORBIDDEN.** Physics or input changes.
- **Depends on.** KE7, SQ14. **Shares files with.** `pocket_draw.gd` (after SQ14).

**Architecture, feel and the relay.**

### SR1 One damage door

- **GOAL.** Every hit enters one function that applies armour, plates, caps, crit, health and execute in a declared order, then emits its events, with a capped hook list per event.
- **SCOPE.** `src/combat/damage_door.gd` (new), `src/combat/combat.gd` (`strike()` at `:476` calls it), `src/combat/enemy.gd` (`:378`), `src/combat/plated_brute.gd` (`:243`), `src/combat/drill_crew.gd` (`:159`), `src/combat/warden.gd` (`:788`), `src/boss/boss.gd` (`:1127`), `src/boss/boss_target.gd` (`:163`), `src/combat/wear_trail.gd` (`:8`, the bypass), `tests/damage_door_test.gd` (new).
- **CONTEXT.** The six `take_damage` sites above; `adr/TADR-002-runtime-model.md` (scoped signals, no hidden mutation chains); `comps/ror2/architecture.md:93`.
- **ACCEPTANCE.** 1,000 scripted hits with every hook enabled: call order matches the declared sequence on all 1,000; no hook runs before damage applies; hooks per event at or under the declared cap; 100 kill-and-respawn cycles leave the run owner's inventory and companion unchanged; full smoke green; posture bands unchanged.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'damage_door_test' --test 'posture_bands_test' --test 'alpha_posture_bands_test' --test 'bot_six_pilots_test'` (4 files); full smoke (602 test files today plus the lane's new ones, import and boot).
- **TIMEBOX.** 5 h. **Writer.** Opus. **Review.** Hard tier: it touches every damage path.
- **FORBIDDEN.** Changing any damage number.
- **Depends on.** PC-PACK, KF2, KF3, KF4, B3, B6. **Shares files with.** `combat.gd` (after B3, B6, the six PC units, SR7); `warden.gd` (KF1 merged; KF2 to KF4 use its hook); `enemy.gd` (after PC-TARN, which may not edit it).

### SR2 Effect pool

- **GOAL.** Projectiles and effects come from one pool per prefab, growable, with an opt-out.
- **SCOPE.** `src/presentation/node_pool.gd` (new), `src/combat/bolts.gd`, `tests/node_pool_test.gd` (new).
- **CONTEXT.** KB6's baseline (`K-UNITS.md:97`); `comps/ror2/architecture.md`.
- **ACCEPTANCE.** A 10 minute spawn-heavy run: peak live node count flat after warm-up; frame time no worse than unpooled; no pooled node carries state between uses.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'node_pool_test'` (1 file); the perf command (`P-UNITS.md:41`) on base and candidate, p99 ratio at most 1.0.
- **TIMEBOX.** 3 h.
- **FORBIDDEN.** Changing a projectile's behaviour.
- **Depends on.** KB6, SR1. **Shares files with.** `bolts.gd` (after SI4).

### SR3 Interrupt priority

- **GOAL.** Ability rows and enemy states carry one interrupt priority, a sprint-cancel flag and a duration scaled by attack speed.
- **SCOPE.** `src/core/ability_state.gd` (fields `priority`, `cancels_sprint`; duration over attack speed), `src/combat/counter.gd` (state priority), `tests/interrupt_priority_test.gd` (new).
- **CONTEXT.** `ability_state.gd:178-200` (stock and recharge); `adr/TADR-008-ability-contract.md:24` (one integer per row, no framework); `comps/ror2/characters-and-feel.md`.
- **ACCEPTANCE.** 1,000 randomized orderings: zero weaker interrupts accepted, zero stronger refused, at most one state change per tick; duration equals base over attack speed at 0.5, 1 and 2 within one tick; sprint cancels on flagged activations.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'interrupt_priority_test' --test 'ability_swap_pressure_test' --test 'enemy_counters_test' --test 'bot_six_pilots_test'` (4 files).
- **TIMEBOX.** 3 h.
- **FORBIDDEN.** Tags, attribute sets or a scripting language.
- **Depends on.** B3, PC-PACK. **Shares files with.** `ability_state.gd` (after SQ6, B3, the six PC units); `counter.gd` (after SQ1).

### SR5 Juice budget

- **GOAL.** Stacked hits cannot shake past a cap, and hitstop belongs to the attacker's own melee only.
- **SCOPE.** `src/presentation/juice.gd` (a per-frame shake cap beside `shake_scale`, `:73`; hitstop gated to the attacker's melee, never the ball's motion or a roll, under `SPINE_CAP_MS` 60, `:25`, `:644`), `tests/juice_budget_test.gd` (new).
- **CONTEXT.** `juice.gd:25`, `:73`, `:184`, `:360`, `:644`; `src/movement/chase_camera.gd:25-27` (per-row `shake_cap`); `BIBLE.md:782`; the first memo's default 10 (`W13-INTEGRATION.md:313`), replaced.
- **ACCEPTANCE.** 30-hit stress: peak shake under the cap on every frame; zero player-movement freezes from hitstop; zero hitstop on a roll; the comfort scale still scales both.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'juice_budget_test' --test 'presentation_juice_test' --test 'presentation_hitstop_test'` (3 files).
- **TIMEBOX.** 2 h.
- **FORBIDDEN.** Removing the comfort row.
- **Depends on.** Nothing. **Shares files with.** None.

### SR6 Damage numbers

- **GOAL.** Damage numbers and hit effects take one colour per damage type and team, and numbers merge in a short window.
- **SCOPE.** `src/presentation/damage_numbers.gd` (new), `src/ui/hud.gd` (one layer), `src/presentation/juice.gd` (the number is raised from the hit record that draws its burst; the crit rule and the burst and edge-flash tints read `DamageNumbers`; ruling 2026-10-11 w13-systems round 3, a brief defect), `tests/damage_numbers_test.gd` (new).
- **CONTEXT.** `src/presentation/juice.gd`; `BIBLE.md:782`; B2 (`P-UNITS.md:122-142`).
- **ACCEPTANCE.** Zero number and effect colour mismatches across every type and team pair; at 20 hits per second the visible numbers stay under a declared cap.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'damage_numbers_test' --test 'ui_word_budget_test'` (2 files).
- **TIMEBOX.** 2 h.
- **FORBIDDEN.** A new meaning colour; the hit-taken flash keeps the `player_hit` row colour for every team (a distinct monster or world hit colour is an owner call; ruling 2026-10-11 w13-systems round 3).
- **Depends on.** B2. **Shares files with.** `hud.gd` (after B2).

### SR9 Relay charge rule

- **GOAL.** The opt-in hold relay charges by a data rule with a discharge field and a ring that follows charge, and a part trades a tighter ring for a faster charge.
- **SCOPE.** `src/world/hold_relay.gd` (`:8-11` become a data row: T, s, discharge, radius floor, follower), `src/build/parts.gd` (one convergence row, `capped` at three), `tests/relay_charge_test.gd` (new).
- **CONTEXT.** `hold_relay.gd:5-11` (18 s, 24 m, pauses, never resets); `src/world/event_director.gd` (KE1's); `comps/ror2/events-and-objectives.md:116`.
- **ACCEPTANCE.** 100 seeded runs with 1 to 4 simulated occupants: charge time equals `T/share^s` within 1%; with discharge above 0 an empty ring drains to 0; default discharge 0 keeps today's relay tests green; the ring never falls under its floor; the part at counts 1 to 3 gives radius `base/(2 x count)` and charge `T/(1 + 0.3 x count)` within 1%, and count 4 equals count 3.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'relay_charge_test' --test 'holds_priority_test' --test 'world_director_test'` (3 files).
- **TIMEBOX.** 3 h.
- **FORBIDDEN.** Making the relay the stage objective.
- **Depends on.** KE1. **Shares files with.** `parts.gd` (after PC-POOL).

### SR10 Relay risk stack

- **GOAL.** Before charging, the player may add stakes that multiply the relay's fight and its pay together, with no currency staked.
- **SCOPE.** `src/world/hold_relay.gd` (the stake choice), `src/world/director_cards.gd` (pack and miniboss credit times `1 + k`), `tests/relay_stack_test.gd` (new).
- **CONTEXT.** `adr/TADR-010-open-stages-and-event-director.md:45`; `BIBLE.md:513`; KE9 (`K-UNITS.md:343-358`); KD8.
- **ACCEPTANCE.** For k = 0 to 4 over 100 seeds: credit equals base x (1 + k) and rewards equal 1 + k; posture band tests unchanged; no price changes.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'relay_stack_test' --test 'relay_charge_test' --test 'director_credit_test' --test 'posture_bands_test'` (4 files).
- **TIMEBOX.** 2.5 h.
- **FORBIDDEN.** A scrap or core stake.
- **Depends on.** SR9, KE9, KD8. **Shares files with.** `director_cards.gd` (after KE9; SG10, SG6 after).

**Run flow and progression-and-music.** KE10 is defined (`K-UNITS.md:360-372`); section 4 schedules it and adds the lines.

### SR12 Logbook and run tallies

- **GOAL.** A read-only logbook page shows every codex entry's status, and run tallies feed the profile.
- **SCOPE.** `src/ui/logbook_page.gd` (new), `src/core/codex.gd` (a status per entry; the `seen` list is the only prompt, `:36-44`, `:142-150`), `src/core/profile.gd` (tally keys), `src/core/run_state.gd` (run tallies), `tests/logbook_test.gd` (new).
- **CONTEXT.** `BIBLE.md:527`, `:576-586` (582: a quit before zone completion replays the entrance; 584: reloading cannot duplicate completed rewards; 586: permanent discoveries survive defeat; citation corrected 2026-10-11 at the SR12 merge); `src/core/achievements.gd:50-53`; B5's schema 4 `seen` list (`P-UNITS.md:191`).
- **ACCEPTANCE.** Every registered entry resolves to a status and opening one clears its marker; a scripted full run's tallies (stages cleared, time, kills, deaths, Wardens seen) equal its run log; the profile round-trips.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'logbook_test' --test 'codex_coverage_test' --test 'profile_store_test'` (3 files).
- **TIMEBOX.** 3 h.
- **FORBIDDEN.** A new grant row.
- **Depends on.** Nothing. **Shares files with.** `profile.gd` (after SG12; SG10 after); `run_state.gd` (after SG9).

### SR13 Stage beats report

- **GOAL.** A stage's six beats (arrive, loot, find, hold, fight, leave) each have one owning module and a logged time per seed.
- **SCOPE.** `src/core/stage_beats.gd` (new), `tools/bot_run.gd` (a beats column), `tools/balance_report.gd`, `tests/stage_beats_test.gd` (new).
- **CONTEXT.** `BIBLE.md:471`; `comps/ror2/run-flow.md:82`; `src/core/objectives.gd`.
- **ACCEPTANCE.** 50 seeded bot runs on `--table=park`: every run reaches the exit with no beat skipped; a run restarted from its seed reproduces its beat timings to the frame.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'stage_beats_test' --test 'bot_run_end_test'` (2 files).
- **TIMEBOX.** 3 h.
- **FORBIDDEN.** A beat that gates the exit.
- **Depends on.** KB8, KE1. **Shares files with.** `bot_run.gd` (KE9 after).

### SR14 Restart latency probe

- **GOAL.** The time from an exit to the next stage's first control frame is measured against the quick-restart target, and a seed replays identically.
- **SCOPE.** `tests/restart_latency_test.gd` (new).
- **CONTEXT.** `BIBLE.md:582`; `src/core/run_state.gd` (`run_seed`); KB4 (`K-UNITS.md:65-82`).
- **ACCEPTANCE.** Over the 50 runs of SR13: latency under the target the coordinator names from the decisions register before dispatch; the same seed gives the same beat timings.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'restart_latency_test'` (1 file).
- **TIMEBOX.** 1.5 h.
- **FORBIDDEN.** Changing the load path.
- **Depends on.** KB4, KD1, SR13. **Shares files with.** None.

**Companions under the ruling.** SR7 and SR8 fit the one SPIL-9 and land now; the crew is SR16, after the alpha.

### SR7 SPIL-9 drivers, leash and chirp

- **GOAL.** The SPIL-9's modules run from ordered driver rows, it waits at a safe spot when it has no leader, and its chirp, gesture and animation read one state.
- **SCOPE.** `src/core/companion.gd` (a `DRIVERS` table per module and `pick(state)`; the leash and stalled state), `src/presentation/companion_body.gd` (reads the state), `src/presentation/audio.gd` (the chirp reads the same state with a per-trigger cooldown), `src/combat/combat.gd` (the module act reads `Companion.pick()`), `tests/companion_drivers_test.gd` (new).
- **CONTEXT.** `companion.gd:1-12` (one hover chassis, two sockets, never revives); `companion_body.gd:8` (the `escape_acted` chirp); `BIBLE.md:570`, `:572`; `comps/ror2/companions.md:157`.
- **ACCEPTANCE.** Reordering two rows changes which fires with no code edit in 100 of 100 sampled ticks; the stalled state engages within 1 s of owner loss and clears on respawn; zero animation, chirp and motif mismatches in 100 sampled events, at most one chirp per trigger in its cooldown; no new combat key, health economy or second companion.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'companion_*_test'` (expected 11 files: the 10 `companion_*_test` files today and the new one).
- **TIMEBOX.** 3 h.
- **FORBIDDEN.** A crew bot; a revive.
- **Depends on.** Nothing. **Shares files with.** `combat.gd` (after B3, B6; the six PC units after SR7); `audio.gd` (PC-KEST, PC-TARN after).

### SR8 Device caps

- **GOAL.** Quick autonomous devices get a per-kind capacity, a timed refill, recall by the leash and removal on destruction.
- **SCOPE.** `src/core/devices.gd` (new table), the deployable scripts the unit finds under `src/` and lists in its REPORT before editing, `tests/device_caps_test.gd` (new). **Writer.** Opus (it must locate the code).
- **CONTEXT.** `BIBLE.md:568` (capacity, lifetime, recall and persistence open; the prototype's conductor limits are not rules); `comps/ror2/companions.md` (2, 2, 3, 4 per kind as shape).
- **ACCEPTANCE.** Deployed count never above its cap; refill and recall times match the lab rows; a destroyed device leaves the count.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'device_caps_test'` plus every existing test the REPORT lists for the touched scripts (count stated).
- **TIMEBOX.** 3 h.
- **FORBIDDEN.** A roster of devices that acts like a crew.
- **Depends on.** SR7. **Shares files with.** Stated in the REPORT before the first edit.

### SR16 Scrap-bot crew (after the alpha)

- **GOAL.** Up to three persistent scrap bots with roles, motifs, growth, repair and a pocket workbench, as TADR-011 describes.
- **SCOPE.** `src/core/crew.gd` (new), `src/core/crew_roles.gd` (new), `src/world/activities.gd` (the trade pocket's workbench), `src/presentation/music_engine.gd` (one stem per acting bot), `tests/crew_test.gd` (new).
- **CONTEXT.** `adr/TADR-011-scrap-bot-crew.md:3` ("This is not authorization to build"); `decisions.tsv:476c` (after the alpha merge, when the alpha Bible section 6 is amended by ADR); `comps/ror2/companions.md:157`.
- **ACCEPTANCE.** A crew of three through three stage loads with the owner killed in stage two: every bot exists after each load; stalled within 1 s; a repair spends exactly the declared scrap and restores level; zero bark mismatches in 100 events; growth per bot under a readable cap, never 2^n; a downed bot past a stage boundary becomes a rescue objective; a repair never revives the pilot.
- **VERIFY.** Base checks; `npm run sketch:smoke -- --sketch core-loop --test 'crew_test' --test 'companion_*_test'` (12 files).
- **TIMEBOX.** 6 h. **Writer.** Opus.
- **FORBIDDEN.** Starting before the ADR lands.
- **Depends on.** Alpha merge, the ADR amending BIBLE section 6, SR7. **Shares files with.** Set at dispatch.
## 4. Paste blocks for existing units

Each block names its target and the anchor line it goes after. Lines already in a brief stay; these add to them. Memo 2's blocks 3a to 3e were applied on the candidate; its 3f and 3g were not, and 4d and 4e below supersede them.

### 4a. KF2 to KF4: one new read per gate, the four-field record, one signature

**Target: `K-UNITS.md` KF2 to KF4 (`:402-419`), ACCEPTANCE, after the bullet that begins `` - `tests/telegraph_timing_test.gd`, the kind's own attacks ``, which each kind now runs as its own `tests/telegraph_timing_<kind>_test.gd` (`decisions.tsv:486c` superseded the shared file; the lines below land in each kind's file).** KF2 is in wave A, KF3 and KF4 in wave B; KF1 has merged.

```markdown
- **One new read per gate (comps: gunfire/enemies-and-bosses).** Each posture gate (`engaged`, `stagger`, `chunk_1` to `chunk_3`, `broken`) adds exactly one new mechanic or ends one plating state. A stepped bot run over 20 seeds logs which, per gate; no gate adds two and no gate adds none. The plating states read SG7's defence-bar classes once SG7 has merged; before that they keep the kind sheet's look.
- **Lead and overlap (comps: gunfire/enemies-and-bosses:89, roboquest/enemies-and-telegraphs:110).** Over 50 runs per attack: lead from telegraph start to damage at least 0.4 s, and the drawn telegraph and the damage area overlap at least 95 percent. Zero attacks outside either line.
- **Four-field record.** Each attack's row names pre-shoot (its charge length), recovery, cooldown and radius. Recovery and cooldown stay reported, not gated; SQ1 later gates the pack kinds and lists the Warden attacks as exceptions.
- **One signature (comps: roboquest/enemy-design-grammar).** The kind sheet names exactly one signature mechanic that changes the arena or a rule (the mounting's mechanism counts). The REPORT prints the grown bot's time to kill beside each merged kind's; a spread wider than plus or minus 25 percent of the median (start) is reported to the coordinator, not tuned here, since the posture band owns the numbers.
```

No Shares line: SQ1 writes its own `tests/telegraph_timing_pack_test.gd` and reads the KF REPORTs, so the three kinds still merge in any order.

### 4b. The K-E lines

**Target: `K-UNITS.md` KE1 (`:275-289`), ACCEPTANCE, after the bullet that begins `- The route graph connects`.** KE1 is wave D.

```markdown
- **Major-event allowance (comps: gunfire/stage-anatomy).** A row flagged `major` counts against a per-world allowance, default one per world, held in one `major_allowance` field that only a stage modifier (SI3) or the opt-in run tier (SG10) may raise. Minor rows keep their ebb and flow (BIBLE.md:519). Seeded stage runs: one major event per world at the default; the overlap caps hold; minor events still fire.
```

**Target: `K-UNITS.md` KE2 to KE5 (`:291-302`), ACCEPTANCE, append (KE4 only).**

```markdown
- **KE4 only, one signature per miniboss (comps: roboquest/enemy-design-grammar).** Each miniboss kind names exactly one signature mechanic that changes its arena or a rule, and its stepped run shows it.
```

**Target: `K-UNITS.md` KE6 (`:304-319`), ACCEPTANCE. Replace the bullet that begins `- The same run reports elite arrivals per stage` with the first line below, and append the other three.** KE6 is wave E.

```markdown
- **Elite cap (comps: roboquest/stage-anatomy:110).** On `--table=park`, elite arrivals are capped at 3 per stage, lifted only by a stage modifier. Over 20 seeds x 30 stepped minutes, no seed exceeds 3 without a modifier; the alpha table is bit-identical to today.
- **Distance bands (comps: ror2/director-and-difficulty).** Arrivals pick from named distance bands (near, mid, far; start values from the lab) and never land inside a minimum radius of the ball. Zero arrivals inside the radius over 30 stepped minutes, 20 seeds.
- **Recalc at stage load (comps: ror2/run-flow).** The stage-indexed term of the dial recomputes once at stage load, under its cap, and holds for the stage; the in-stage clock tier keeps stepping as the tier lines above state. 20 seeds: one stage-term recalc per load, and the stage term never changes within a stage.
- **Homes name a chassis class (comps: roboquest/enemy-design-grammar).** `director.gd` maps each home's kind to a chassis class from SQ4's `chassis` column (no park file edit; the home rows stay the KD units'), and the director picks the member from that class. Every spawn from a home matches its class in 100 percent of seeded runs.
```

**Same target, Depends on, append:** `SQ4 merged (the chassis column).`

**Target: `K-UNITS.md` KE8 (`:332-341`), ACCEPTANCE, append.** KE8 is wave E.

```markdown
- **Relay cues (comps: ror2/events-and-objectives:116).** The hold relay's state drives the boss-status cue and the ring flash: the cue lands within one bar of the state change, the flash within one tick of ring entry.
```

**Target: `K-UNITS.md` KE9 (`:343-358`). Replace `(next wave)` in the heading with `(wave F)`. Append to ACCEPTANCE.**

```markdown
- **Per-stage factor.** The dial carries a geometric per-stage factor (start value from the lab; the note's constants are not copied, `comps/ror2/director-and-difficulty.md:123`) under a named cap; the dial is monotone in stage and in time and never exceeds the cap.
- **Elite refund.** An elite's cost returns to the balance when it dies; refund equals price on every seed.
- **Relay miniboss budget (first memo row 4).** The relay miniboss credit is `max(override, floor(c * sqrt(D)))`: monotone and sqrt-shaped across the dial.
- **Authored packs bypass.** Authored activity packs (KD8's camps, SQ5's pocket waves) consume no credit.
- **Home turf.** Each card carries a home-region weight; at least 70 percent of each kind's arrivals land in its home region (start), 20 seeds.
- **Door rings.** Zero spends inside a door ring over 20 seeds.
- **Repeat kind.** Arrivals weight down the kind just killed, beside the pack-id ban (`src/world/director.gd:293`); the repeat-kind rate sits below the no-rule baseline on every seed.
```

**Same target, FORBIDDEN, replace with:** `Changing the alpha table's director; any price scaling by the dial; health scaling by the dial (SG11 adds the opt-in tier's dials later, in its own unit).`

**Target: `K-UNITS.md` KE10 (`:360-372`). Replace `(next wave)` in the heading with `(wave F)`. Append to ACCEPTANCE.**

```markdown
- **Power earns a layer (comps: ror2/items-and-stacking, ror2/progression-and-music).** Over a 1 to 20 power sweep, layers rise in steps and the peak level stays under its ceiling; master volume never rises with power.
- **Release after clear.** The busiest layers release within one phrase of a stage clear, as after a Warden break.
- **Relay terms.** While the hold relay runs, `approach` reads the ring instead of the landmark and an in-ring filter opens, sampled at 4 Hz (start); zero mid-phrase layer changes except rows flagged `danger` (BIBLE.md:755).
```

**Target: `K-UNITS.md` dependency graph (`:446-465`), append inside the fence after its last line.**

```
KE6 ─> KE9 ─> KE10 (KE10 also after KE8, B3, KB8)
SQ4 ─> KE6 (chassis column)
KB8 ─> SR15 ─> KDn greybox
```

**Target: `K-UNITS.md` dispatch table (`:467-481`), append a row after wave 9, then a sentence after the table.**

```markdown
| 10 | KE9, KE10 | KE9 after KE6; KE10 after KE8, B3 and KB8 |

Lane S (W13-INTEGRATION-3.md section 8) shares the machine with this table: at most 8 K units and 8 S units run at once, and every new brief runs smoke with `SMOKE_SLOTS=6` (`decisions.tsv:487c`).
```

### 4c. P lane: the PC common lines and PC-POOL

**Target: `P-UNITS.md` PC common rules (`:230-238`), after the bullet that begins `- **Movement stays with the pilot`.** The six PC units are wave C.

```markdown
- **Status, uptime and spikes (comps: roboquest/weapons-and-affixes, roboquest/movement-and-feel, ror2/items-and-stacking).** A status the unit adds builds at least 2x as fast from a source built for it as from an incidental one (the note measured 0.7 against 0.3 and 0.35, start), shown by a build-up timing in the unit's own test. Every timed movement or speed buff the unit adds states its uptime (duration over cooldown) inside 25 to 75 percent and names whether its cooldown starts at activation or at expiry; `pilot_uptime_test` (SQ7) gates it. A `spike` part (SR4's family) is at most one per tier and capped at 8x base. Each class card gets its one trade-off line from SG3, which merges first.
```

**Target: `P-UNITS.md` PC-POOL (`:336-347`). Replace `(next wave)` in the heading with `(wave 6, beside PE-INT)`. Replace the DEPENDS ON line.**

```markdown
- **DEPENDS ON.** PC-PACK merged. Andrew's answer on the Bible's Mobility row no longer gates this unit: under either branch, shared parts change what a verb does and the pilot owns how it moves (W13-INTEGRATION-3.md section 6 item 2). SQ19 merges after it on `parts.gd`.
```

**Target: `P-UNITS.md` dispatch table (`:630-643`), the wave 6 row: replace `PE-INT (1)` with `PE-INT, PC-POOL (2)`.**

### 4d. The per-pilot sum, its fallback, the clip line and the forge block

**Target: `P-UNITS.md` PD common rules, after the bullet that begins `- **C5, budgets.**`.** This is memo 2's 3f text, made live for the PD fix round in flight.

```markdown
- **C5b, per-pilot sum (comps: gunfire/production-budgets, roboquest/production-budgets).** The REPORT carries one table per pilot at classes I, III and V: base shell, each heft layer present, pilot body, and the totals of tris and draws, read from Common VERIFY step (2)'s inspect calls and the pilot row in `assets/asset_budgets.json` (`:45-50`). Report only: no cap or class changes. A class V total over 16,000 tris (`:43`) is reported as a stop for SQ18.
```

**Target: `P-UNITS.md` PD-INT, ACCEPTANCE, append.**

```markdown
- **C5b fallback.** For any pilot whose PD unit merged before C5b existed, PD-INT runs the same inspect calls on the merged GLBs and adds that pilot's C5b table, so all six sums exist before SQ18 starts.
```

**Target: `P-UNITS.md` PE-INT, ACCEPTANCE, append.** The clip cap is a deferral: it reports from SQ17 in wave A and gates only here.

```markdown
- **Clip lengths and counts (comps: gunfire/production-budgets, ror2/production-budgets).** SQ17's audit over all six heroes: zero non-boss gameplay clips over 3.5 s (start), boss exceptions listed by name, every hero at or under 50 clips, every count nonzero.
```

**Target: `P-UNITS.md` PE common rules (`:473-483`), after the bullet that begins `- Eleven new clips per pilot`.** The PE units that author the clips (PE-TARN and PE-CANNON in wave C, the other four in wave D) learn the cap before PE-INT gates it.

```markdown
- **Clip target (comps: gunfire/production-budgets, ror2/production-budgets).** Report and target, not a gate here: the REPORT lists each new gameplay clip's length and the pilot's clip count; a non-boss gameplay clip over 3.5 s (start) or a count over 50 is named with its reason. PE-INT gates both at the wave close.
```

**Target: `tools/asset-forge/packs/core-loop.toml`, before the line `# Real-world size sanity per category: longest bounding-box edge in metres, [low, high].`.** Insert memo 2's comment block (`W13-INTEGRATION-2.md:204-220`) as written, with its first line replaced by:

```toml
# PROPOSED (comps rows 26 and 35), applied as live keys by SQ18 (W13-INTEGRATION-3.md section 3) under the condition below.
```

### 4e. PD-PROV, promoted to this push

**Target: `P-UNITS.md`, a new block after PD-INT (before `## 4. Wave P-E: clips`).** It replaces memo 2's 3g. Grounds: TADR-003 requires it ("Retain source-asset provenance and import settings", `adr/TADR-003-content-pipeline.md:35`), and the owner ruling on free base meshes puts it ahead of the first fetch (`decisions.tsv:474c`).

```markdown
### PD-PROV: provenance fields and their check (wave B)

- **GOAL.** Every shipped model, texture, font and library has either a tracked recipe or a complete provenance record, and the registry test fails one that has neither.
- **Writer.** Sonnet.
- **SCOPE.** `docs/project/ASSETS.md` (line 17 only), `tests/asset_registry_test.gd` (a provenance check), `tests/asset_provenance_test.gd` (new, planted rows), `tools/provenance_schema.json` (new: the sidecar fields).
- **CONTEXT.** `adr/TADR-003-content-pipeline.md:35`; `docs/project/ASSETS.md:12` (the three bundled OFL fonts), `:17` (today's fields), `:23` (the study posture and Andrew's private archive exception: the test never reads that archive); the CC0 sky row as the one downloaded example (`assets/registry.json:3001-3009`); `comps/roboquest/enemy-design-grammar.md`, the provenance paragraph under "Base mesh sources"; the first memo's row 17 (`comps/ror2/provenance.md:44`).
- **ACCEPTANCE.**
  - `ASSETS.md:17` and the schema name one sidecar per fetched file with: source URL and title, licence name and version with a saved copy of the licence line, download URL, access date, file list with sizes and SHA-256, creator and attribution text, a commercial-use statement, and a re-check date before a build ships.
  - Fonts and locked libraries carry the same admission record; the three OFL fonts pass with their package LICENSE as the saved line.
  - The registry test fails a planted asset with no recipe and no provenance, and a planted download missing its hash; every current asset passes unchanged.
- **VERIFY.** compile; lint; smoke(`asset_registry_test`, `asset_provenance_test`): 2 files; fence.
- **TIMEBOX.** 2 hours.
- **FORBIDDEN.** Fetching any file; editing a budget class.
- **DEPENDS ON.** Nothing. Must merge before any external base is fetched.
- **SHARES.** `asset_registry_test.gd` with PD-TARN and PD-CANNON (merge after their fix round 2).
```

### 4f. KD1 to KD6: the two graph ratios as each stage's own gate

**Target: `K-UNITS.md` KD1 to KD6 (`:219-243`), ACCEPTANCE, after the bullet that begins `` - `tools/park_graph.gd` run on the stage ``.** SR15 prints both ratios; each stage unit owns its pass or fail. The six drafts still carry open detour and sightline conflicts (`decisions.tsv:471`, `:480c`), so a stage that misses a target reports it to the coordinator in the same fix round as those.

```markdown
- **Graph ratios (comps: isaac/floor-generation.md:107, roboquest/stage-anatomy:125).** On the stage's own graph: the median spawn-to-reward over spawn-to-objective path ratio is at least 1.5 and `full_visit_ratio` is at most 3.0 (both start values, printed by SR15's report). A miss names the pocket or route that causes it.
```
## 5. Blocked rows

Three proposals conflict with an accepted ADR. Each stays out until the ADR changes; none has a workaround that keeps the borrow's point.

| Proposal | What it wanted | Blocking line |
| --- | --- | --- |
| ror2/architecture:server-authority-networking | Server-owned damage and spawns | `adr/TADR-005-networking-scope.md:23`: "Recommend **offline solo play with no networking subsystem**." and "Do not add accounts, lobbies, replication, server deployment or speculative rollback/lockstep infrastructure." The single-authority part of the borrow is already true (TADR-002's one local simulation authority) and SR1 gives it one damage door. |
| ror2/director-and-difficulty:dial-priced-shops-gold-xp | Prices, gold and XP scaled by the time-driven dial | `adr/TADR-010-open-stages-and-event-director.md:45`: "It may not open or close an exit, advance a tree, price an upgrade or cache, or otherwise gate progression". `BIBLE.md:538` says the same for trees ("Elapsed time never advances a tree, opens an exit or prices an offer"). The pressure half lands in KE9; the price half is also owner item 4. |
| isaac/pacing-and-trades:gauntlet-clock | A stage clock that closes a door | `adr/TADR-010-open-stages-and-event-director.md:45`, the same sentence ("may not open or close an exit"). The scout cited `:47`, which is the durable-fact rule; `:45` is the line that blocks. A timed objective that counts ticks stays open under Q-P38; SQ5's objective kinds never gate the exit. |

## 6. Owner items

Seven calls are yours. Each has both branches and a default; "none of these" is always an answer, and it keeps the default.

1. **Free base meshes: the first download.** You ruled yes to CC0 and CC-BY bases with provenance (`decisions.tsv:474c`), Quaternius first. What is still yours under rule (c) is each download.
   - Yes: after PD-PROV merges (wave B), a scout names one batch (source, licence, files, sizes) and you approve it; the first forge enemy family starts from it under the 1,100-tri cap, with a blind silhouette read of at least 18 of 20 and a complete sidecar.
   - No: every enemy is built from scratch as today, and SQ18's from-scratch recipe is the route; SQ20 forges its first family.
   - Default: no download until you approve a named batch. Nothing waits on it; SQ18's recipe and SQ20's family run either way.
2. **The Bible's Mobility row.** `BIBLE.md:535` ends "class versus item stays open". Memo 2's amendment, replacing that sentence: "Movement that changes how a pilot moves belongs to that pilot: its own tree, its Shift and parts bound to it. Shared parts may change what a verb does, never how far or fast the ball moves. Optional transformative items keep the exception in Movement, camera and active aim."
   - Adopt: the Bible says what PC-POOL and SQ19 build.
   - Keep the line open: PC-POOL and SQ19 still land, as one pilot-first reading of an open line, and a later item could move the ball.
   - Default: adopt.
3. **The scrap-bot crew.** Ruled (`decisions.tsv:476c`): one SPIL-9 for the alpha; the crew after the alpha merge, once an ADR amends the Bible's section 6. SR16 holds the crew rows (persistent bots, workbench, growth, repair, bot as pair partner, crew stems).
   - As ruled: SR7 and SR8 build what fits the one SPIL-9 now; SR16 starts after the alpha merge and the ADR.
   - Earlier: the ADR is written now and SR16 joins wave G; this needs your Bible amendment first.
   - Default: as ruled.
4. **Prices and the scrap economy.** `BIBLE.md:513` keeps every cost open and bars "invented prices"; TADR-010 lists "every cache and scrap price" as open (`adr/TADR-010-open-stages-and-event-director.md:63`). Four proposals wait here: a shelf price ladder that rises by stage and jumps at each world, a fixed visible price per upgrade step with a hard cap, a flat scrap step per attachment tier, and scrap typed by item tier with a trade-up ratio (which also changes what scrap is, `BIBLE.md:65`). SG12's currency form (between-run options bought with a meta currency) is here too.
   The measurement is not yours to wait on: SG16 (wave B) runs the note's lab line now, report only (price to income 0.5 to 2.0 across 3 worlds, 20 seeds, `comps/gunfire/run-pacing-and-economy.md:104`), on today's `PAY_SCRAP` and `COG_PRICES`, and proposes numbers where a ratio falls outside. What stays yours is approving numbers.
   - Approve: the numbers SG16 proposes become one ladder and the four borrows land with them.
   - Keep open: prices stay as today (`PAY_SCRAP` 180, `COG_PRICES` provisional); SG12 opens nodes by accomplishment, SI2 charges health or the existing cogs prices.
   - Default: keep today's prices until you approve a proposal from SG16's report.
5. **Permanent starting cogs and shop discounts.** Proposed: 100 to 500 starting cogs, a double-cog chance, 5 to 25 percent discounts as between-run nodes. `BIBLE.md:475`: "combat power is rebuilt each run without permanent stat boosts"; `:586`: "The next run rebuilds equipment power".
   - Amend: the Bible allows a small permanent economy head start, and SG12 adds the nodes.
   - Keep: SG12 ships options, discoveries and pocket keys only.
   - Default: keep.
6. **An XP level curve.** Proposed: levels with per-level stat growth and an ambient level that rises with time. `BIBLE.md:432` makes the tree the progression and `:538` bars elapsed time from advancing it.
   - Amend: a level curve beside the tree; the ambient part still could not advance with time.
   - Keep: growth stays the tree's four picks.
   - Default: keep.
7. **A weighted draw of the next world.** `BIBLE.md:580`: "there is no random world offer."
   - Amend: the exit offers a weighted next world.
   - Keep: the fixed three-world order.
   - Default: keep.

**Note, not a call: Q-P38.** The scattered-mark objective is adopted as an optional SQ5 kind that never gates the exit (section 2). No Bible or ADR line bars it, and TADR-010 expects such an objective (`adr/TADR-010-open-stages-and-event-director.md:45`). What an exit requires stays Q-P38 (`:63`).

**Your hands, not a decision.** A 60 fps capture of Roboquest's movement on your machine (`comps/roboquest/movement-and-feel.md:81`) gives SQ9's speed bank its source side. SQ9 builds from the start values without it; the capture turns its traces into a comparison.

**Calls this memo makes under the creative charge.** Each is a default you can strike.

- Difficulty dials (enemy health, enemy damage, aggression) and the Warden's scaling live only on the opt-in run tier; tier 0 is today's game (SG10, SG11).
- Between-run options open on one-run accomplishments, never on a currency (SG12).
- The pocket draw answers Q-P23 for pockets only, as seeded authored assembly from the layout stream; stage layout stays authored (SQ14).
- Elite arrivals are capped at 3 per stage on the park table (KE6), where memo 2 only counted them.
- A rare capped spike family (at most 8x base, one per tier) replaces the first memo's "no exponential family" (SR4).
- Hitstop belongs to the attacker's melee only, never the ball's motion or a roll (SR5).
- The clip cap of 3.5 s reports from wave A and gates only at PE-INT.

## 7. Lab arms

Every arm is report-first in its own unit and gates from the unit's merge; the pass lines are the unit ACCEPTANCE lines in section 3 or 4. Grouped by the tool that runs them.

**Headless Godot lab** (`"$GODOT_BIN" --headless --path sketches/core-loop`, the `scrapkeep-lab` skill; each through `npm run sketch:smoke` or a `tools/` script):

| Arm | Unit | Measure |
| --- | --- | --- |
| Stack and composition sweep | SR4 (`tools/build_sweep.gd --arm=stack`, `--arm=compose`) | 1 to 20 copies per family; 10,000 random 6-part builds; time to kill per row |
| Slot growth | SG14 (`build_sweep.gd --arm=slot_growth`) | Slots per milestone; paired over unpaired margin |
| Burden sweep | SG4, SG5 | 0 to 10 burdens: survival, payout under cap |
| Fusion pairing | SG2 | Both orders identical; preview lead; elite share |
| Arc mark | SG1 | Per-source rise while marked |
| Defence bars | SG7 | One class per state, one regen rule per class |
| Telegraph record | KF2 to KF4, SQ1 | Lead at least 0.4 s; overlap at least 95 percent; four fields |
| Pack stagger | SQ3 | Interrupt window equal across kinds; zero stalls |
| Interrupt priority | SR3 | 1,000 orderings; duration over attack speed |
| Damage door order | SR1 | 1,000 hits; hook order and caps |
| Chain mask | SR11 | Five sources, zero repeats |
| Shot bits, stat cache, sets | SI4, SI5, SI6 | 10,000 builds; cache equals recompute; set share |
| Juice budget | SR5 | 30-hit stress shake cap; zero movement freezes |
| Effect pool | SR2 | Live node count; p99 frame ratio at most 1.0 |
| Speed bank, refunds, uptime | SQ9, SQ6, SQ7 | Burst ratio 1.2 to 1.3; refund 1 to 2 s; uptime 25 to 75 percent |
| Weapon envelope, attachments | SQ10, SQ11 | Envelope spreads; perk share within 15 percent |
| Offer weights, levels, late offer, start pick | SQ19, SG15, SG8, SG9 | 200 draws or starts per pilot |
| Visible odds | SG13 | 10,000 draws per table against shown weights |
| Zones, pocket draw | SQ13, SQ14 (`tools/park_graph.gd`) | 1,000 seeded jitters or stages |
| Closable sockets | SQ15 (`tools/park_sockets.gd -- --sockets=1000`) | 1,000 seeded stages per arm |
| Graph checks | SR15; KD1 to KD6 (paste 4f) | `beacon_ok`; reward-to-objective ratio and full-visit ratio, reported by SR15 and gated per stage by its KD unit |
| Shop price to income | SG16 (`tools/shop_model.gd`) | 3 worlds, 20 seeds; price, income and ratio per stage, report only |
| Pocket library entry | SQ12 | Idle and dodger entries per pocket |
| Pocket kinds, trades, stakes, modifiers | SQ5, SI1, SI2, SI3 | Round credit curve; trade memory over 10,000 runs; cost shown equals charged |
| Relay charge and stack | SR9, SR10 | `T/share^s`; credit `base x (1 + k)` |
| SPIL-9 drivers, devices | SR7, SR8 | Row reorder; stalled within 1 s; caps |
| Music | KE8, KE10 | 5 minute trace; layer steps over a power sweep |
| Budget audit | SQ17, SQ18, SQ20 (`node sketches/core-loop/tools/budget_audit.mjs`, not Godot) | Per-category medians and p90 beside the three reference games; SQ20's family inside its chassis band |

**Bot driver** (`tools/bot_run.gd` and `tools/balance_report.gd`, `--table=park` unless named):

| Arm | Unit | Measure |
| --- | --- | --- |
| Credit director | KE9 (`--director=interval|credit`) | Income integral within 5 percent; attacker peak; home turf; repeat kind |
| Homes, elites, distance bands | KE6 | Elite cap 3; zero arrivals inside the radius; one stage-term recalc per load |
| Attacker budget | SQ2 | Simultaneous attackers never over the cap |
| Run tier and dials | SG10, SG11, SG6 | Tier 0 and tier 1 over 20 seeds; each dial alone; affix telegraph lead |
| Stage beats and restart | SR13, SR14 | 50 runs, six beats; latency under target; seed replays |
| Gate reads and signatures | KF2 to KF4, KE4 | One new mechanic per gate; time-to-kill spread |
| Six pilots still win | Every unit that lists `bot_six_pilots_test` | Each pilot at least 3 of seeds 1 to 4 |
| Baseline ratios | SQ8 | 200 runs, ratios within tolerance |

**uat runner** (headless Chromium on localhost; it cannot drive the native Godot build, so it covers the browser review pages built from `tools/look_capture.gd` frames):

| Arm | Unit | Measure |
| --- | --- | --- |
| Blind chassis stills | SQ4 | 20 stills, three readers, picks recorded before the key opens: at least 18 of 20 |
| Defence-bar read at 150 m | SG7 | Each bar's class named in a fixture frame |
| From-scratch family stills | SQ20 | 20 stills, three readers: at least 18 of 20 name chassis class and threat feature |
| Base-mesh silhouette | Owner item 1, if approved | At least 18 of 20 against the reshaped base |

Each uat run writes a receipt directory; the unit's REPORT names its path, and a flow it did not exercise is a stated gap. A blind read by a model is not Andrew's read; the look pages still go to his Chrome at each wave close.

**Unit tests and reports** (the tables above list harness arms only; these lab measures run in the unit's own test or REPORT):

| Measure | Unit | Where it runs |
| --- | --- | --- |
| Readout equals simulation; caps shown | SG3 | `ui_build_readout_test` |
| Five simulated runs, no price or stat key | SG12 | `meta_options_test` |
| Visible numbers under the cap at 20 hits per second | SR6 | `damage_numbers_test` |
| Run tallies equal the run log | SR12 | `logbook_test` |
| Pocket marker on all six stages | SQ16 | `ui_edge_marker_pocket_test` |
| One major event per world at the default | KE1 (paste 4b) | `park_events_test` |
| Shared parts never change how the ball moves | PC-POOL | `parts_pool_movement_test` |
| Status build-up at least 2x from a built source | The six PC units (paste 4c) | each unit's own test |
| Per-pilot triangle and draw sums at classes I, III and V | PD fix round 2, PD-INT (C5b, paste 4d) | the REPORT's inspect table |
| Provenance record complete; planted rows fail | PD-PROV (paste 4e) | `asset_provenance_test`, `asset_registry_test` |
| Clip lengths and counts, report and target | PE units (paste 4d) | the REPORT; PE-INT gates |

## 8. Wave map

Four lanes. P is `P-UNITS.md`'s pilot lane, K is `K-UNITS.md`'s park lane, S is this memo's systems lane, and polish is small S units (presentation or a probe) that run beside the S lane's eight. A wave starts when the merges it names have landed. The S lane starts at most 8 units per wave; the P and K lanes keep their own tables' caps (`P-UNITS.md:630-643`, `K-UNITS.md:467-481`); every new unit brief runs smoke with `SMOKE_SLOTS=6` (`decisions.tsv:487c`). Gunfire Reborn and Roboquest units go first in every S wave they can (`decisions.tsv:475c`).

| Wave | Starts when | P lane | K lane | S lane | Polish |
| --- | --- | --- | --- | --- | --- |
| A | now | B2, B3, B4, B6 and the PD fix round 2 in flight (with C5b, paste 4d) | KB8, KD8 in flight; then K-UNITS wave 3 (KB4, KC1 to KC7) and KF2 (with paste 4a) as slots free | SG7, SG9, SQ3, SQ4, SQ6, SQ7, SQ10, SQ17 | SR5 |
| B | B2, B3, B6, KB8, KD8 and the PD fix round 2 merged | PE-0, PD-INT (with the C5b fallback) | KB5, KC8, KF3, KF4, KB7 | SG3, SG4, SG12, SG13, SQ13, PD-PROV, SR4, SR15 | SQ16, SR6, SG16 |
| C | P-B closed; KB4, KB7, KB8, KD8, KC0 merged; SQ1 also needs the KF2 to KF4 REPORTs | PC-SABLE, PC-RIVET, PC-KEST, PC-TARN, PC-TALLY, PC-CANNON (with paste 4c), PE-TARN, PE-CANNON (with the PE clip target, paste 4d) | KB6, KD1 to KD6 greybox (SR15 merged first; paste 4f), KC10 | SG5, SQ1, SQ15, SQ18 (if the six C5b sums allow), SR7, SR12 | |
| D | wave C's PC units merged; KD1 greybox merged; SQ12 and SI1 also need KD2 to KD6 greybox merged | PC-PACK, PE-SABLE, PE-RIVET, PE-KEST, PE-TALLY (with the PE clip target) | KE1 (with paste 4b), KC9 | SG8, SQ9, SQ12, SQ20, SI1, SI2 | |
| E | PC-PACK and KE1 merged; PE-INT also needs all PE merged | PE-INT (with the clip line), PC-POOL | KE2 to KE8 (KE4, KE6, KE8 with paste 4b) | SG14, SQ8, SQ11, SR1, SR3, SR9, SR11, SR13 | |
| F | KE6, SR1, PC-POOL, SQ12 merged | | KE9, KE10 (paste 4b), KD1 to KD6 dressed, KF8 | SG1, SQ5, SQ14, SQ19, SI4, SI5, SR2, SR8 | SR14 |
| G | KE9, SR9, SG1, SQ14, SQ19, SI4, SI5 merged | | | SG2, SG6, SG10, SG15, SQ2, SR10, SI3, SI6 | |
| H | SG10 merged | | KD7 (coordinator) | SG11 | |
| After the alpha | The alpha merge and the ADR amending the Bible's section 6 | | | SR16 | |

**Merge order on files more than one S unit touches.**

| File | Order |
| --- | --- |
| `src/combat/counter.gd` | SQ3, SQ1, SR3, SQ2, SG11 |
| `src/world/activities.gd` | KD8, SG13, SI1, SQ5 (SR16 after the alpha) |
| `src/build/parts.gd` | SG4, SG5, the PC units, PC-POOL, SR9, SQ19, SG15, SG10 |
| `src/build/part_def.gd` | SR4, SG3, SG15, SI4, SI5 |
| `src/combat/combat.gd` | B3, B6, SR7, the PC units, SR1, SG1 |
| `src/world/director.gd` | KE6, KE9, SQ14, SG11 |
| `src/world/director_cards.gd` | KE9, SR10, SG10, SG6 |
| `tools/park_graph.gd` | KB8, SR15, SQ13, SQ14 |
| `src/core/profile.gd` | SG12, SR12, SG10 |
| `src/core/run_state.gd` | SG9, SR12, SI1 |
| `src/core/ability_state.gd` | B3, SQ6, the PC units, SR3 |
| `src/core/event_kinds.gd` | B3, SQ6, KF2, KE1 (SQ6 and KF2 add disjoint rows; whichever is ready first merges first) |
| `src/movement/tuning.gd` | the PC units that list it, SQ9 |
| `design-v3/PILOTS.md` | SQ7, SQ10, SQ8 |

**Wave closes.** The coordinator runs the full smoke, the gate and an export at each S wave close, as the P and K tables do at theirs, and the alpha export grows with each close (`decisions.tsv:475c`). The fun gate still applies: no lab arm in this memo certifies feel, and each wave's look and play go to Andrew before the next wave's heavy units start.

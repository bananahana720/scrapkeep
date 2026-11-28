# TADR-014. A layer order for the sketch's source directories

Status: **Proposed (checked by lint on the branch `entropy/gate`).** The directories of `sketches/core-loop/src` stand in nine layers, bottom first: `core`, `movement`, `build`, `combat`, `boss`, `world`, `presentation`, `ui`, and one top layer that holds `game.gd`, `boot`, `dev` and `experimental`. A script may load a script in its own layer or a lower one. Lint rule L20 fails a new load of a script in a higher layer, and the list of loads that point up today may only shrink. Written during the structure sweep Andrew asked for on 27 November 2026 ([STRUCTURE-SWEEP.md](../project-guide/handoff/STRUCTURE-SWEEP.md)), which approved proposing an order (ruling `es` in [DECISIONS.md](../project-guide/handoff/DECISIONS.md)). It reaches `main` when the Gate lands that branch; Andrew can overturn it.

Date: 28 November 2026. Applies to the light play lane only (`sketches/core-loop/src`). It sits on top of [TADR-012](TADR-012-script-dependency-loops.md), which forbids new dependency loops, and does not change [TADR-002](TADR-002-runtime-model.md), which owns the module boundaries of the native game.

Paths below are under `sketches/core-loop/` unless they start with `adr/` or `scripts/`.

## The order

| Layer | Directories | What belongs there |
| --- | --- | --- |
| 1 | `core` | The facts and the state every part of the game shares: the event bus, the run, the profile and saves, the stage and world tables, the pilots' records. |
| 2 | `movement` | The ball: its body, its input, its camera, its tuning and its mobility augments. |
| 3 | `build` | What the ball carries and buys during a run: scrap, parts, items, relics, panels, consumables and their synergies. |
| 4 | `combat` | The pilots' weapons, the enemies and their telegraphs, damage and drops. |
| 5 | `boss` | The three world bosses, their arenas and their weak points. |
| 6 | `world` | The stage: terrain, parks, hazards, stage events, activities, pockets and the camp. |
| 7 | `presentation` | What the player sees and hears of the run: effects, scenery, models, sound and music. |
| 8 | `ui` | What the player reads and presses: the HUD, screens and menus. |
| 9 | `game.gd`, `boot`, `dev`, `experimental` | What starts the game, and what only a launch flag mounts. |

In one sentence: shared facts at the bottom, then the ball, then the run's systems from what the ball carries up to the stage that holds them, then what the player sees and hears, then what the player reads and presses, and the entry points on top.

The four directories of layer 9 share it because the graph says they are peers: `game.gd` loads `dev/dev_console.gd`, `dev/dev_session.gd` loads `game.gd`, and no script below loads any of them. The rule allows any load between them. Scripts under `tools/` and `tests/` are above every layer: they may load any script under `src/`, and the rule does not read them. A script under `src/` may not load one under `tools/` (lint rule L7), and none loads one under `tests/`.

## Context

**The directories were not layers.** Measured on commit `6336b493e` with the graph lint rule L16 builds, `src/` holds 638 scripts with 3,060 dependencies between them. Each cell counts the pairs of files where a file in the row's directory depends on a file in the column's:

| from \ to | core | movement | build | combat | boss | world | presentation | ui | top layer |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| core | | 2 | 7 | 6 | 7 | 8 | 5 | 1 | |
| movement | 20 | | | 3 | | | | | |
| build | 35 | 3 | | 12 | | 5 | 6 | 5 | |
| combat | 171 | 29 | 20 | | 9 | 8 | 58 | 3 | |
| boss | 31 | 5 | 1 | 14 | | 1 | 17 | 3 | |
| world | 132 | 6 | 14 | 30 | 5 | | 57 | 16 | |
| presentation | 188 | 16 | 18 | 68 | 15 | 30 | | 22 | |
| ui | 194 | 10 | 24 | 5 | | 10 | 25 | | |
| top layer | 54 | 17 | 8 | 6 | 1 | 7 | 26 | 20 | 3 |

No order puts every pair downhill. Anyone can print the table again, with the upward pairs of any order and the fewest over every order of its layers: `node scripts/sketch-lint.mjs --sketch core-loop --layers core,movement,build,combat,boss,world,presentation,ui,boot+dev+experimental+game.gd` (layers bottom first, a comma between layers, `+` between the directories of one layer; with no order it prints the one L20 holds).

**Nothing stopped a new upward load.** About a dozen rows of the sweep's task pool each invert one load, and the next feature could put any of them back.

## Options

Each order below was counted on the same graph. The top layer stays on top in all of them, since it loads every other layer and nothing loads it.

| Order, bottom first | Upward pairs | Files that carry most of them | Disposition |
| --- | --- | --- | --- |
| `core` < `movement` < `build` < `combat` < `boss` < `world` < `presentation` < `ui` | 261 in 116 files | `world/camp_hub.gd` 15, `core/stage_beats.gd` 9, `world/activities.gd` 9, `core/run_state.gd` 8, `combat/enemy.gd` 7, `core/flow.gd` 7 | **Chosen.** It is the order the project's pages already describe, and the fewest of every order that keeps what the player sees and presses on top |
| `core` < `movement` < `build` < `combat` < `presentation` < `ui` < `boss` < `world` | 223 in 100 files, the fewest of all 40,320 orders of the eight directories | `presentation/sound_twins.gd` 17, `core/stage_beats.gd` 9, `core/run_state.gd` 8, `combat/enemy.gd` 7, `core/flow.gd` 7 | Rejected. It buys 38 fewer entries by calling the wrong direction the offence: the drawing code and the HUD could not load the stage or the boss (55 pairs listed), while the stage and the boss could load drawing code freely, the very loads the sweep wants out (LEAD-123). Nobody can say in a sentence why the boss sits above the menus |
| The chosen order with `presentation` and `ui` in one layer | 239 in 104 files | as the chosen order | Rejected. The graph says the two are close to peers (22 pairs one way, 25 the other), but 13 of the 22 loads from `presentation` are of six `ui` files that hold fonts, colour tokens, screen regions, the busy flag, settings and icons (`ui_fonts.gd`, `ui_tokens.gd`, `screen_regions.gd`, `screen_busy.gd`, `settings_store.gd`, `icons.gd`), which a later unit can move down or hand in. One layer would let effects and the HUD tangle both ways for good to save 22 entries |
| The chosen order with `build`, `combat`, `boss` and `world` in one layer | 226 in 103 files | as the chosen order | Rejected. It drops every check between the four directories that held 111 of the 169 files of the largest dependency loop when L16 landed |
| `movement` < `build` < `core` < `combat` < ... (the best order on the older commit `20200ba2a`) | 307 in 136 files | `world/camp_hub.gd` 15, `movement/player_ball.gd` 11 | Rejected. Lifting `core` above `build` would excuse `run_state.gd`'s loads of build's catalogues, but 55 loads of `core` from `movement` and `build` would then point up |
| No order: keep removing loops file by file under L16 alone | | | Rejected. L16 cannot see a new load that points the wrong way without closing a loop, so the inversions the sweep cuts can come back |

The pages read for the chosen order: the directory map and the mount order in [ARCHITECTURE.md](../sketches/core-loop/ARCHITECTURE.md), [src/build/SEAMS.md](../sketches/core-loop/src/build/SEAMS.md), whose offer records and element results are written for presentation and the HUD to read, [src/combat/README.md](../sketches/core-loop/src/combat/README.md), and the sweep page's entry, which puts `core` at the bottom and the things a player sees and presses at the top. Inside that frame the graph fixes the rest: `build` sits under `combat` (12 pairs up against 20 down), `combat` under `boss` (9 against 14) and `boss` under `world` (1 against 5); every other arrangement of those four costs more.

**The two large known inversions** are the same in every order that keeps `core` at the bottom. `core/run_state.gd` loads eight scripts above it: build's catalogues `parts.gd`, `relics.gd`, `panels.gd`, `consumables.gd` and `fabricators.gd`, `combat/roster.gd`, and `world/trade_pockets.gd` and `world/pockets/pocket_draw.gd` (row CORE-06 of the sweep's task pool, which counted 23 on an older commit). `core/flow.gd` loads seven: `movement/tuning.gd`, `boss/arena.gd`, `boss/boss.gd`, `world/event_director.gd`, `world/park/park_map.gd`, `world/victory_lap.gd` and `ui/start_pick_card.gd` (CORE-07). Both stay on the list; inverting them is high-risk work of its own.

## Decision

1. **What counts as a load.** The graph of TADR-012: file A depends on file B when A holds a quoted string whose whole text is `res://src/<path of B>` ending in `.gd`, or uses, outside strings and comments, the name B declares on an unindented `class_name` line. Text in a triple-quoted string or after a `#` is skipped. A file's directory is the first folder under `src/`; `src/game.gd` is its own.
2. **The order** is the table above. It lives in `LAYERS` in `scripts/sketch-lint.mjs`, which this record owns; a change to one changes the other in the same pull request, and a test in `scripts/sketch-lint.test.mjs` fails while the table and `LAYERS` disagree.
3. **The rule.** L20 reports every pair of files where a file under `src/` depends on a file in a higher layer, at the line of the first load. A pair on the `L20` list in `scripts/sketch-lint.baseline.json` passes. A pair on the list that no longer points up fails until its entry is removed. A script in a directory of `src/` that no layer names fails until the directory is placed here and in `LAYERS`, and the list cannot excuse it. A directory `LAYERS` names that holds no script fails the same way. An empty read of `src/` fails.
4. **The list** holds one entry per upward pair, `<from file> -> <to file>`, sorted. It is written by `node scripts/sketch-lint.mjs --sketch core-loop --write-baseline` (also `npm run sketch:lint -- --write-baseline`) and never by hand. It held 261 entries on commit `6336b493e`; the list itself holds the current count.
5. **The list only shrinks, entry by entry.** With `--base`, an entry that is not on the base copy of the list fails, even when another entry left in the same change, unless a file it names was renamed in the same range, in which case it counts as the entry under the old name. An offence may also move with a file split inside one directory: a new entry passes when an entry gone from the base differs from it only in the name of one file in the same directory, and each gone entry excuses one new entry.

## How an offence leaves the list

A unit that cuts an upward load deletes its entry by running the write command again. The fixes the sweep has used, cheapest first:

- **Hand a value or a callable in.** The higher script that already owns the lower one passes the fact or the function at setup, as `flow.setup(ctx, beacon, Build.Panels.draw)` does, and the lower script stops loading it.
- **Move a pure data file down.** A table or a set of constants that loads nothing above its new home moves to the lowest layer that uses it, as unit C5 moved `flash_guard.gd` and `speed_tier.gd` into `core`.
- **Move a fact to its owner.** When a lower script loads a higher one for one value, the value moves into a script of the lower layer that owns it, and the higher script reads it from there.

## Consequences

- A new load of a higher layer's script fails `npm run sketch:lint`, which `npm run sketch:fast` and the pre-push hook also run. The message names both files, both layers, this record and the three ways out.
- Moving a game-wide fact such as `core/flash_guard.gd` back into `presentation` fails: each of the scripts in `build`, `combat`, `boss` and `world` that loads it becomes a new upward pair. A lower layer that starts loading any presentation script for one fact fails the same way.
- A new directory under `src/` cannot land until it is placed in a layer.
- The rule adds about 2 ms to the lint on the Mac Studio, since it reads the graph L16 has already built.

**What the rule does not see.**

- A path built at run time, such as `"res://src/combat/warden_%s.gd"` in `combat/warden.gd`, a script a scene or resource file names, and a `preload("uid://…")`. None of these is in the graph.
- A call through `ctx` or a signal on `GameEvents`. These cross layers at run time without a load, which is how the layers are meant to talk upward.
- A fact copied as a literal into a higher layer instead of loaded from its owner. The rule keeps loads downhill; it cannot tell that two numbers are one fact.
- A second load between two files whose pair is already on the list, and any load inside one layer or between the directories of layer 9.
- A file that only higher layers load can move up a layer, since that creates no upward pair.

## Later qualification and reconsideration

- When the list is short enough to read, replace it with the pairs that remain and a reason for each.
- When `presentation` and `ui` stop loading each other's leaf files, look again at whether they are one layer.
- Lifting a directory or splitting one (for example the camp scripts `world/camp_*.gd` into a camp directory above `ui`, which would take `camp_hub.gd`'s 15 pairs off the list, since only `game.gd` loads it) changes this record and `LAYERS` together.

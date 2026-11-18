# World 1 promise cards

This folder holds the work left on world 1 after Andrew's requests of 17 November 2026, as fifteen promise cards, `W1-131.md` to `W1-145.md`. A thread that has read only `AGENTS.md` can take a card from here. Ruling ec lets a Codex thread on the Astra model own cards W1-131 to W1-144; W1-145 is the Gate's. The review that admits a pull request to the stage is the Gate's Claude reviewer (decision A12 below).

## What a promise card is

A card is one sentence a player should be able to say after playing, in Andrew's words, with one number that today's game fails. The number is a row of `scripts/world1-bands.rows.json` at `status: "report"` with `enforced_from` naming the card. That file is the table `npm run sketch:world1-bands` prints, which the project calls the done read, so the done read prints the number from the first day and gates on it once the card closes. Each card has one owner and lettered subtasks that cross whatever crafts the sentence needs.

Each subtask has a kind, and the kind sets how it can close ([picture-proof.md](../../.agents/skills/scrapkeep-verify/references/picture-proof.md) part c):

- `game` changes a game file. It cannot close as built while its owned game files equal the base.
- `measure` adds a headless measure or tool. It closes when its plant is caught and round 0 is on record.
- `board` closes with one frozen board.
- `model` closes with a model receipt and its plant caught.
- `finding` closes with the file and line that own a fault and a check that fails on it.

A subtask ends in one of five ways, written with the receipt verdicts of `project-guide/handoff/COMMS.md`: built (PASS); built in part (PASS+NOTES, naming the next lever); already true (a `game` subtask only: round 0 meets the floor with its plant caught, agreed by the level 2 reviewer); blocked (BLOCKED, naming the missing input); not built (FAIL: every round was flat or worse and reverted, the round record is pushed, the row stays red at `report`, and the Gate cuts a new subtask or a decision card the same day).

Sizes are BACKLOG's: S and M are one thread's unit, and L is too big for one thread, which is why every card is cut into S and M subtasks. "The card check" in a card means `node scripts/proof/cards.mjs check` (built by W1-132d); until it is stacked the Gate checks the same things by hand at review.

One pull request per subtask is the default. A card may mark subtasks that share one measure and one wave as one unit with one pull request ("unit U1" in the Wave, PR column).

`GAPS.tsv` lists every gap found in the 17 November audit with a stable id. Each id is carried by exactly one card's Carries field, by one decision below, or (R1 only) by the Gate's wave 0 step.

`<stage>` below is the open stage `project-guide/handoff/STATE.md` names (`stage/alpha-w44` on 17 November 2026), and a branch takes that wave's prefix (`w44/` on that date).

## From opening a card to handing it over

Every command runs from the repo root on the Mac after `export PATH=/opt/homebrew/bin:$PATH GODOT_BIN="$HOME/Applications/Godot_4.7.2.app/Contents/MacOS/Godot"` (`project-guide/handoff/DEVICES.md:18`). A step marked **[W1-13Nx]** uses a tool that subtask builds; the line after it says what to do until the tool is stacked.

1. **Read** `AGENTS.md`, this page, your card and the picture-proof page. Print your measure row: `node -e "const r=require('./scripts/world1-bands.rows.json').rows.find(r=>r.id==='<row id>');console.log(JSON.stringify(r,null,2))"`. **[W1-132d]** `node scripts/proof/cards.mjs show W1-1NN` prints the card, the row and the files other cards own in the same wave. Until then, the first-wave table below is the fence.
2. **Take the next subtask** in your card's order. Make a worktree from the stage head and check its base: `git fetch origin && git worktree add ../sk-W1-1NNx -b w44/W1-1NNx origin/<stage>`, then `git -C ../sk-W1-1NNx rev-parse HEAD` must equal `git rev-parse origin/<stage>`.
3. **Claim** on the wave board that `project-guide/handoff/STATE.md` names (issue 1106 for wave 44): `gh issue comment 1106 --body "CLAIM W1-1NNx <end state>. Branch w44/W1-1NNx from <stage> <sha>. Files: <the subtask's files>. Thread: <tool and model>."`
4. **Board first**, if your subtask names one. Make it as picture-proof (a) says, push it to `proof/W1-1NN`, and post `NEEDS: andrew` with the pick page the Gate publishes. Build a subtask that needs no board while you wait. **[W1-131a, W1-132f]** Until both are stacked, no board can be made on the Mac.
5. **Round 0.** **[W1-132c]** `node scripts/proof/rounds.mjs start --card W1-1NN --sub x` runs the producer, the plant and every guard on the base and records round 0. Until then: run the producer and the plant by hand and write round 0 (head, measure, guards, plant caught) as a table in your draft pull request's body. **[W1-132e]** `node scripts/proof/receipt.mjs --row <id> --test <name> --plant <name> --out <dir>` is the producer for most rows. Until then: `node scripts/sketch-smoke.mjs --sketch core-loop --test <name>`, copy its `RECEIPT` line, and run it again with `PLANT=<name>` set.
6. **Build rounds.** Each round is one commit to a file your subtask owns, then the measure again. **[W1-132c]** `node scripts/proof/rounds.mjs round --card W1-1NN --sub x` judges it kept, flat, worse or void and reverts a flat or worse round. Until then: judge it by the rule in picture-proof (c), revert with `git revert --no-edit HEAD`, and add the row to your table.
7. **Pictures.** **[W1-131a]** `node scripts/gate/display-run.mjs --offscreen <script> -- <args>` draws frames with no window on screen. Until it is stacked, nothing opens a game window on the Mac: work on headless numbers, keep your pull request a draft, and take the close pictures when the lane exists.
8. **Focused tests and the fast lane**: `node scripts/sketch-smoke.mjs --sketch core-loop --test <name>` for each test your subtask names, then `npm run sketch:fast -- --base origin/<stage>` (rule 4). Rerun a red alone before you call it red.
9. **Close.** **[W1-132c]** `node scripts/proof/rounds.mjs close --card W1-1NN --sub x` writes the close word, builds the sheet, pushes `proof/W1-1NN` and prints the receipt, which opens `VERDICT <PASS|PASS+NOTES|FAIL|BLOCKED> head <sha>`. Until then, write the same receipt by hand.
10. **Hand over**: `gh pr create --draft --base <stage> --head w44/W1-1NNx --body-file <receipt file>`, then one board comment, `Ready to stack <pull request link> head <sha>`. The Gate reviews (below) and you get one fix round.
11. **After the last subtask** the Gate runs the level 2 review and moves the card's row from `report` to `gate`.

## Order and waves

| Wave | Starts | What | Why |
| --- | --- | --- | --- |
| 0 | now, the Gate alone | G0 below, in two parts | Part 1 (the cards, rows and rulings) must exist before a claim. Part 2 (every open draft stacked or parked) must be done before a card fences a file a draft touches. |
| 1 | after G0 part 1 | W1-131a; W1-132a to f; W1-133a to e and g; W1-134a; W1-135a, b; W1-137a; W1-141a; W1-143a; W1-144a | The proof tools unblock every picture and close. Enemies at speed is what Andrew asked for most, and its rounds are headless. Every other promise records its round 0 now, headless. No file here is touched by an open draft. |
| 2 | W1-131a and W1-132a to c stacked; G0 part 2 done | W1-131b; W1-132g to i; W1-133f, h; W1-134b to e; W1-136; W1-137b, c; W1-138; W1-139; W1-140; W1-141b to c3; W1-143b; W1-144b | Everything that needs real frames, a frozen board, or a file an open draft held. W1-141 owns the park geometry files this wave. |
| 3 | W1-141c1, c2 and c3 and the full W1-133 card stacked | W1-135c, d; W1-141d, e; W1-142 | The works and the heights need the rebuilt places and the new enemy leads. |
| 4 | W1-142 and W1-141 stacked | W1-137d; W1-145 | Collision fixes touch the geometry last; the read on every pilot and the packed build closes the tree. |

**G0, the Gate's wave 0 step** (carries gap R1), in two parts.

Part 1 is one docs and data pull request on the stage, by the Gate. Wave 1 may start when it is stacked:

- these cards, `GAPS.tsv` and the picture-proof page; one BACKLOG section with one row per card; the promise rows in `scripts/world1-bands.rows.json` at `report`, with the line in `scripts/world1-bands.test.mjs` that today requires every receipt row to be `gate` widened to allow `report`;
- ruling ec (Codex Astra threads may own promise cards; the Gate's Claude reviewer is the independent review) and ruling ed (Brindle keeps pressing while reeling, Andrew's "Yes, keep pressing" of 17 November); one clause in `AGENTS.md` rule 11 naming ruling ec; one row for this folder in `project-guide/handoff/START-HERE.md`.

Part 2 is the Gate settling what is open. Wave 2 waits on it:

- every open draft stacked or parked with its reason on the board: 1116, 1119, 1120, 1122, 1123, 1124 to 1139, 1140 (on `w44/hazards-hit-everyone`) and 1141. The cards name the drafts they wait on;
- `project-guide/handoff/STATE.md` names the promise cards on the wave board, and the Codex worktrees left on disk go on the deletion list for Andrew (his message C8 asked for the session to be wrapped up).

Proof: `npm run check:docs` green, `node --test scripts/world1-bands.test.mjs` green, and `npm run sketch:world1-bands` lists each promise row as `report until W1-1NN`.

## The first wave

No file appears twice, and no file here is touched by an open draft pull request (checked against `git diff --name-only origin/stage/alpha-w44...origin/<branch>` for every open draft on 17 November).

| Thread | Subtasks | Files it may edit | Needs before it can close |
| --- | --- | --- | --- |
| 1 | W1-131a | `scripts/gate/display-run.mjs`, `scripts/gate/window-watch.mjs` (new), `scripts/gate/display-run.test.mjs` (new), `sketches/core-loop/tools/offscreen_window.gd` (new), `sketches/core-loop/tools/offscreen_probe.gd` (new) | nothing |
| 2 | W1-132a to f, in order | `sketches/core-loop/tools/look_subjects.gd`, `sketches/core-loop/tools/look_harness.gd`, `sketches/core-loop/tools/stations/shared_route.json`, `sketches/core-loop/tests/look_stations_test.gd`, `sketches/core-loop/tools/still_compare.gd`, `sketches/core-loop/tests/still_compare_test.gd`, `sketches/core-loop/tools/look_noise.json`, `scripts/proof/` (all new), `sketches/core-loop/tools/board_compose.gd`, `sketches/core-loop/tests/board_compose_test.gd` | W1-131a, for the harness's off-screen call in a, b's noise table and f's first frame |
| 3 | W1-133a to e, g | `sketches/core-loop/tools/matchup_lab.gd` and `.md`, `tools/stations/W1-133.json` (new), `tests/matchup_lab_test.gd`; in `sketches/core-loop/src/combat/`: `lobber.gd`, `plated_brute.gd`, `boom_tender.gd`, `hooker.gd`, `dispatcher.gd`, `foreman.gd`, `jolt_layer.gd`, `ramp_flipper.gd`, `winch_drone.gd`, `elite_affixes.gd`; `sketches/core-loop/src/core/park_defs.gd` (`ELITE_SPILLWAY` only); the tests W1-133 names for b to e and g | W1-132a, e; W1-131a for close pictures |
| 4 | W1-134a | `sketches/core-loop/tools/arrival_census.gd`, `sketches/core-loop/tests/arrival_census_test.gd` (both new) | W1-132e |
| 5 | W1-135a, b | `sketches/core-loop/tools/hook_sites.gd`, `tests/hook_sites_test.gd`, `tools/stations/W1-135.json` (all new), `sketches/core-loop/src/movement/harpoon.gd`, `sketches/core-loop/src/movement/augments.gd`, `tests/hook_swing_exit_test.gd` (new) | W1-132a, e |
| 6 | W1-137a | `sketches/core-loop/tools/qa/collision_sweep.gd`, `sketches/core-loop/tools/qa/undrawn_places.gd` (new), `sketches/core-loop/tests/invisible_walls_test.gd` | W1-132e; W1-131a for the sweep's own run, which needs a renderer |
| 7 | W1-141a | `sketches/core-loop/assets/park/park_dam/regions.json`, `assets/park/park_flume/regions.json`, `src/boss/arena_regions.json`, `src/world/park/regions.gd`, `tests/park_regions_test.gd` (all new) | W1-132e |
| 8 | W1-143a | `sketches/core-loop/tools/prim_census.gd`, `tools/prim_census_run.gd`, `tools/prim_census_pin.tsv`, `scripts/gate/stand-ins-receipt.mjs`, `sketches/core-loop/tests/prim_census_test.gd` | nothing |
| 9 | W1-144a | no game files; one new probe named in its claim | W1-131a, for the drawn reading |

Threads 3 to 7 name a tool of thread 2 in the last column. Each starts at once on its own producer and its test, and cannot close until that tool is stacked. Until `shared_route.json` exists, threads 3 and 5 take their route points straight from `sketches/core-loop/assets/park/park_dam/lines.json` and the flume's, and move their stations onto the shared file when W1-132a lands.

W1-133f and W1-132h moved out of this wave: `src/core/challenge_dials.gd` is touched by pull request 1123, `tests/chaser_lead_test.gd` by 1128, and `scripts/gate/model-receipts.mjs` by 1123, 1135 and 1140.

## Decisions for Andrew

Each has a default, so no subtask stops on one. Carries names the gap ids each decision holds.

| # | Question | Recommended default | Acts in | Carries |
| --- | --- | --- | --- | --- |
| A1 | Your nine Godot numbers against the game: which do we adopt? | Rest lens 80 to 90 and dash kick plus 8 to 12: a matched trial of 65, 72 and 80 at rest, plus 7 and plus 10 on a dash, then your pick with our recommendation. Arm 4.5 to 6 m, shoulder offset, warnings of 0.4 to 0.8 s: keep the game's, with the reason in W1-133. Floors under 50%: keep the pale sand (Arizona sandstone) and make every meaning outshine it. Bursts 0.15 to 0.3 s and a white flash of 0.03 to 0.05 s: adopt as a trial inside the flash comfort tests. SSIL: a trial on High only | W1-133h, W1-138c, d | D1.1 to D1.9 |
| A2 | Sharp shapes for static danger, or only for live warnings? | Sharp on anything that hurts on contact, never on decoration | W1-141e, W1-142b | D2 |
| A3 | The crossing chaser (off, `challenge_dials.gd:151`): on for world 1? | On, if W1-133f shows it adds straight-pass threat without raising a weaving ball's hull loss | W1-133f | D3 |
| A4 | Does a paid lever cost scrap or cogs, and may a paid device add risk? | Scrap (your word, "scrap-activated"), overturning the board's assumption of cogs; yes, and the risk falls only on a slow or stopped ball | W1-142a, b | D4 |
| A5 | Do crews need pathfinding round terrain? | No navigation mesh: crews enter by mouths, and one held against terrain for 2 s goes back in and comes out again | W1-134b, d | D5 |
| A6 | How much does the chaser lead your line? | As much as W1-133f's measure allows while a ball that turns within 0.6 s of the warning is never caught | W1-133f | D6 |
| A7 | If no off-screen method works on the Mac, where do pictures come from? | The Linux PC's headless gamescope lane through the Gate | W1-131a | none |
| A8 | Who picks the one agreed look for a subject? | You mark a pick page; unmarked after 48 hours, the top-tier reviewer picks blind, logged as an assumption you can overturn | every board subtask | none |
| A9 | Warden escalation was deferred to phase 2: bring it into world 1 now? | Now, because you said the bosses are a pushover | W1-139c | none |
| A10 | The Mac has no Blender, and every crew model and clip is a Blender recipe. Install Blender 5.2.2, the version the cloud setup pins (`project-guide/handoff/DEVICES.md:46`), into `~/Applications`? | Yes. Until you answer, a model or clip build runs in a cloud session through the Gate | W1-136e, W1-143b, any model rebuild | none |
| A11 | Brindle's follow-up ring and hook turn are announced by sound only (BACKLOG W1-105, W1-106, held for your ruling). May the eyes get the warning the ears get? | Yes. The attack commits at the same moment; only when you can see it coming changes | W1-139e | none |
| A12 | Who gives the review that admits a Codex thread's pull request? You asked for Astra agents to review at both levels (C7), and the 17 November audit found pull requests reviewed only by the model family that wrote them | Both. Astra reviewers give the thread its own review and feedback at both levels, and the verdict that admits to the stage is the Gate's Claude reviewer at its pinned tier (AGENTS.md rules 4 and 11). This is the coordinator's assumption, not your words | every pull request | none |
| A13 | What model and effort does a Codex thread run at? You said to consider Sol 6.2 at high or xhigh (C3); AGENTS.md rule 11 says nothing runs above high | Astra at high for subtasks with judgement (game, board, finding), Sol 6.2 at high for fully specified measure subtasks; xhigh only if you say so, since it overturns rule 11. The receipt names the model and effort | every claim | none |

## The cost of one round on the Mac

One round is a headless measure, a drawn pair and the fast lane. `npm run sketch:fast` takes 6 to 8 minutes (`DEVICES.md:22`). The headless measure takes about 5 to 15 minutes for a lab or bot read over 8 seeds, and the drawn pair about 2 to 5 minutes for a card's stations on two presets (**guess** at both, to be replaced by the first real rounds). So a round is about 15 to 30 minutes, and a subtask of five rounds about two hours of Mac time. Drawn runs wait behind the one-at-a-time lock W1-131a adds: nine threads share one display lane, so a thread runs its headless measure while its drawn pair waits.

## How the Gate reviews

Two levels, both by the Gate's Claude reviewer, both read-only; the Gate writes each answer to a file with `node scripts/proof/rounds.mjs review` (**[W1-132c]**; until then, as a pull request comment that opens with the VERDICT line).

- **Level 1, per pull request**: `scrapkeep-reviewer-medium`. It reads the diff against the subtask's proof, the round record, the blind pairs before their key, and each ruling the card cites, and names a ruling for every kept change.
- **Level 2, per promise**, after its last subtask: `scrapkeep-reviewer` at high. It reads the row across all subtasks together, the guards of the promises already stacked and the boards against the frames, and it alone agrees an "already true" close.

A thread may run its own sub-agents, Astra reviewers included, for blind picks during rounds and for review and feedback at both levels (Andrew's C7). That is the thread's own check; the Gate's review is the one that admits (decision A12).

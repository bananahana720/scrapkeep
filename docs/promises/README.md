# World 1 promise cards

> **Status on `main` (rulings `ef`, `ep`, `eq`):** These 15 cards (`W1-131`..`W1-145`) were authored during Wave 44 (`stage/alpha-w44`, `#1106`). Under `ruling ef`, all 12 promise rows remain `report` in `scripts/world1-bands.rows.json` (not sitting-gating); under `rulings ej/ep/eq`, development runs flat on `main` with admitting reviews on fresh **Gemini 4 Neon at high** sessions (`AGENTS.md` rule 11; GPT-6.2 Astra/Sol evidence does not admit). **Landed on `main`:** `W1-131a/b` (`display-run.mjs`, `window-watch.mjs`, `offscreen_{window,probe}.gd`), `W1-134a` (`arrival_census.gd`), `W1-135a` (`hook_sites.gd`), `W1-137a` (`undrawn_places.gd`), `W1-139d/f/g` (`BrindleReel.tla`), `W1-141a` (`regions.gd`, `regions.json`), and `W1-143a/b` (`prim_census*`, `stand-ins-receipt.mjs`). **Unbuilt:** `W1-132a–f` (`scripts/proof/{cards,rounds,receipt}.mjs`, `shared_route.json`, `board_compose.gd`, `look_noise.json`), so 9 producer entries in `scripts/world1-bands.rows.json` still point to missing `scripts/proof/receipt.mjs`.

This folder holds the work left on world 1 after Andrew's requests of 17 November 2026, as fifteen promise cards, `W1-131.md` to `W1-145.md`. A thread that has read only `AGENTS.md` can take a card from here. Ruling ec lets a Codex thread on the Astra model own cards W1-131 to W1-144; W1-145 is the Gate's. Since ruling `ej`, the admitting review runs on a fresh Gemini 4 Neon session at high (`AGENTS.md` rules 4 and 11). A subtask a player sees or plays also carries a GPT-6.2 Sol QA verdict in its READY post (ruling ee in `project-guide/handoff/DECISIONS.md`).

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

`<base>` below is the open branch `project-guide/handoff/STATE.md` names (`main` under ruling `ep`; historically `stage/alpha-w44` on 17 November 2026).

## From opening a card to handing it over

Every command runs from the repo root on the Mac after `export PATH=/opt/homebrew/bin:$PATH GODOT_BIN="$HOME/Applications/Godot_4.7.2.app/Contents/MacOS/Godot"` (`project-guide/handoff/DEVICES.md` "The Mac Studio" -> Shell). A step marked **[W1-13Nx]** uses a tool that subtask builds; the line after it says what to do until the tool is stacked.

1. **Read** `AGENTS.md`, this page, your card and the picture-proof page. Print your measure row: `node -e "const r=require('./scripts/world1-bands.rows.json').rows.find(r=>r.id==='<row id>');console.log(JSON.stringify(r,null,2))"`. **[W1-132d]** (`scripts/proof/cards.mjs`, unbuilt) — use the first-wave table below as the file fence.
2. **Take the next subtask** in your card's order. Make a worktree from `origin/main` (or current open base) and check its base: `git fetch origin && git worktree add ../sk-W1-1NNx -b <branch> origin/<base>`, then `git -C ../sk-W1-1NNx rev-parse HEAD` must equal `git rev-parse origin/<base>`.
3. **Log / claim** per coordinator workflow (historically posted on legacy wave board #1106).
4. **Board first**, if your subtask names one. Make it as picture-proof (a) says, push it to `proof/W1-1NN`, and post `NEEDS: andrew` with the pick page the Gate publishes. Build a subtask that needs no board while you wait. **[W1-132f]** Until built, use existing off-screen renders (`display-run.mjs --offscreen`).
5. **Round 0.** **[W1-132c, W1-132e]** (`scripts/proof/{rounds,receipt}.mjs`, unbuilt): run the producer and plant by hand (`node scripts/sketch-smoke.mjs --sketch core-loop --test <name>`, copy its `RECEIPT` line, and rerun with `PLANT=<name>`) and write round 0 (`head`, `measure`, `guards`, `plant caught`) as a table in your draft pull request body.
6. **Build rounds.** Each round is one commit to a file your subtask owns, then the measure again. Until `rounds.mjs` is built, judge by picture-proof (c), revert flat/worse rounds with `git revert --no-edit HEAD`, and add the row to your table.
7. **Pictures.** `node scripts/gate/display-run.mjs --offscreen <script> -- <args>` (`W1-131a`, landed) draws frames with no window on screen and refuses an unqualified script (picture-proof (d) says how a tool qualifies).
8. **Focused tests and the fast lane**: `node scripts/sketch-smoke.mjs --sketch core-loop --test <name>` for each test your subtask names, then `npm run sketch:fast -- --base origin/<base>` (rule 4). Rerun a red alone before calling it red.
9. **Sol QA**, for a subtask that changes or measures what a player sees or plays (ruling ee): start a GPT-6.2 Sol agent from your thread with the card's done-when, the before and after pictures and the round table; it judges the after state against the card and rulings ct, cu, cv and cx. Its verdict, model and effort and the pictures it judged go in your receipt. A tool or records subtask skips this step. Sol's verdict is QA evidence, not admission.
10. **Close.** Until `scripts/proof/rounds.mjs` is built, write the receipt table by hand in the PR body opening `VERDICT <PASS|PASS+NOTES|FAIL|BLOCKED> head <sha>`.
11. **Hand over**: `gh pr create --draft --base <base> --head <branch> --body-file <receipt file>`, then report to the coordinator for independent Gemini 4 Neon High review.
12. **After the last subtask** the Gate runs final verification and updates `scripts/world1-bands.rows.json` if promoted from `report` to `gate`.

## Order and waves

| Wave | Starts | What | Why |
| --- | --- | --- | --- |
| 0 | now, the Gate alone | G0 below, in two parts | Part 1 (the cards, rows and rulings) must exist before a claim. Part 2 (every open draft stacked or parked) must be done before a card fences a file a draft touches. |
| 1 | after G0 part 1 | W1-131a; W1-132a to f; W1-133a to e and g; W1-134a; W1-135a, b; W1-137a; W1-141a; W1-143a; W1-144a | The proof tools unblock every picture and close. W1-133 starts headless rounds here. Every PR that owes the warning-edge pictures stays draft until W1-132g is stacked in wave 2 and the guard passes. Every other promise records its round 0 now, headless. No file here is touched by an open draft. |
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
| 1 | W1-131a | `scripts/gate/display-run.mjs`, `scripts/gate/window-watch.mjs` (new), `scripts/gate/display-run.test.mjs` (new), `scripts/gate/look-receipts.test.mjs`, `sketches/core-loop/tools/offscreen_window.gd` (new), `sketches/core-loop/tools/offscreen_probe.gd` (new) | nothing |
| 2 | W1-132a to f, in order | `sketches/core-loop/tools/look_subjects.gd`, `sketches/core-loop/tools/look_harness.gd`, `sketches/core-loop/tools/stations/shared_route.json`, `sketches/core-loop/tests/look_stations_test.gd`, `sketches/core-loop/tools/still_compare.gd`, `sketches/core-loop/tests/still_compare_test.gd`, `sketches/core-loop/tools/look_noise.json`, `scripts/proof/` (all new), `sketches/core-loop/tools/board_compose.gd`, `sketches/core-loop/tests/board_compose_test.gd` | W1-131a, for the harness's off-screen call in a, b's noise table and f's first frame |
| 3 | W1-133a to e, g | `sketches/core-loop/tools/matchup_lab.gd` and `.md`, `tools/stations/W1-133.json` (new), `tests/matchup_lab_test.gd`; in `sketches/core-loop/src/combat/`: `lobber.gd`, `plated_brute.gd`, `boom_tender.gd`, `hooker.gd`, `dispatcher.gd`, `foreman.gd`, `jolt_layer.gd`, `ramp_flipper.gd`, `winch_drone.gd`, `elite_affixes.gd`; `sketches/core-loop/src/core/park_defs.gd` (`ELITE_SPILLWAY` only); the tests W1-133 names for b to e and g | W1-132a, e; W1-131a for close pictures. PRs owing the warning-edge guard stay draft until wave 2 supplies W1-132g and the guard passes |
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
| A3 | The crossing chaser (off, `challenge_dials.gd` `_load_cli`): on for world 1? | On, if W1-133f shows it adds straight-pass threat without raising a weaving ball's hull loss | W1-133f | D3 |
| A4 | Does a paid lever cost scrap or cogs, and may a paid device add risk? | Scrap (your word, "scrap-activated"), overturning the board's assumption of cogs; yes, and the risk falls only on a slow or stopped ball | W1-142a, b | D4 |
| A5 | Do crews need pathfinding round terrain? | No navigation mesh: crews enter by mouths, and one held against terrain for 2 s goes back in and comes out again | W1-134b, d | D5 |
| A6 | How much does the chaser lead your line? | As much as W1-133f's measure allows while a ball that turns within 0.6 s of the warning is never caught | W1-133f | D6 |
| A7 | If no off-screen method works on the Mac, where do pictures come from? | The Linux PC's headless gamescope lane through the Gate | W1-131a | none |
| A8 | Who picks the one agreed look for a subject? | You mark a pick page; unmarked after 48 hours, the top-tier reviewer picks blind, logged as an assumption you can overturn | every board subtask | none |
| A9 | Warden escalation was deferred to phase 2: bring it into world 1 now? | Now, because you said the bosses are a pushover | W1-139c | none |
| A10 | The Mac has no Blender, and every crew model and clip is a Blender recipe. Install Blender 5.2.2, the version the cloud setup pins (`project-guide/handoff/DEVICES.md` "The cloud box"), into `~/Applications`? | Yes. Until you answer, a model or clip build runs in a cloud session through the Gate | W1-136e, W1-143b, any model rebuild | none |
| A11 | Brindle's follow-up ring and hook turn are announced by sound only (BACKLOG W1-105, W1-106, held for your ruling). May the eyes get the warning the ears get? | Yes. The attack commits at the same moment; only when you can see it coming changes | W1-139e | none |
| A12 | Who gives the review that admits a Codex thread's pull request? You asked for Astra agents to review at both levels (C7), and the 17 November audit found pull requests reviewed only by the model family that wrote them | Both. Astra reviewers give feedback at both levels, and the verdict that admits is a fresh **Gemini 4 Neon** session at high effort (`AGENTS.md` rules 4 and 11, updated from Claude reviewer by ruling `ej`) | every pull request | none |
| A13 | What model and effort does a Codex thread run at? You said to consider Sol 6.2 at high or xhigh (C3); AGENTS.md rule 11 says nothing runs above high | Astra at high for subtasks with judgement (game, board, finding), Sol 6.2 at high for fully specified measure subtasks; xhigh only if you say so, since it overturns rule 11. The receipt names the model and effort | every claim | none |

## The cost of one round on the Mac

One round is a headless measure, a drawn pair and the fast lane. `npm run sketch:fast` takes 6 to 8 minutes (`DEVICES.md` "Timings"). The headless measure takes about 5 to 15 minutes for a lab or bot read over 8 seeds, and the drawn pair about 2 to 5 minutes for a card's stations on two presets (**guess** at both, to be replaced by the first real rounds). So a round is about 15 to 30 minutes, and a subtask of five rounds about two hours of Mac time. Drawn runs wait behind the one-at-a-time lock `display-run.mjs` (`W1-131a`) uses.

## How the Gate reviews

Two levels, both read-only on a fresh **Gemini 4 Neon** session at high effort (`AGENTS.md` rules 4 and 11; fallback `.agents/agents/scrapkeep-reviewer*` / `.claude/agents/scrapkeep-reviewer*` under ruling `ej`), posted as a pull request review/comment opening with `VERDICT`:

- **Level 1, per pull request**: reads the diff against the subtask's proof, the round record, any blind pairs before their key, and each ruling the card cites, and names a ruling for every kept change.
- **Level 2, per promise**, after its last subtask: reads the row across all subtasks together, the guards of promises already landed, and boards against frames, and agrees any "already true" close.

A thread may run its own Astra sub-agents for blind picks during rounds and feedback at both levels (Andrew's C7). That is the thread's own check; Gemini 4 Neon High is the admitting review (`AGENTS.md` rule 11).

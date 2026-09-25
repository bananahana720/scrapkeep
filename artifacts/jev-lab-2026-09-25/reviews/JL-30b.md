# JL-30b-A1 review (Opus 5.5, routine; verbatim)

## Verdict: FAIL, with one narrow blocking finding

Evidence level: I inspected the candidate files, the design contract and the cited primary evidence directly. I did this at the ref `wt/JL-30b` = e696482f2c0c4f1ff8b0c0aca29dd4ec1ff2b3d6, read from `/home/andrew/Projects/scrapkeep/.git/refs/heads/wt/JL-30b`. I ran no commands. Everything else in the candidate meets the contract. The fix is a table edit, and after it this would be PASS+NOTES.

Runtime: the host prompt names claude-opus-5-5 (Opus 5.5). A model cannot verify its own identity. `CLAUDE_EFFORT` is unavailable because I have no shell or environment access.

## Findings

**B1 (blocking): the RML origin map no longer covers every RML id.**
- Where: `.agents/skills/scrapkeep-lab/references/lessons.md:171-217`.
- Violated requirement: DESIGN §3 and §4b check 7, "every RML id appears in the Scrapkeep origin map".
- The map covers RML-01 to RML-43 and is keyed to JL-30a at 85d16a5 (line 171).
- The JL-30a ledger now defines three more ids: RML-44, RML-45 and RML-46 (`/home/andrew/Projects/scrapkeep-wt-JL-30a/.agents/skills/reactive-model-loop/references/lessons.md:228-241`). Its changelog (line 250) also revises RML-02, 05, 22, 27, 28, 41 and 43. RML-41 was split, so RML-41 now means "record tree state" and RML-46 is the clean re-run method.
- Coordinator EV-0557 records these revisions (`/home/andrew/Projects/scrapkeep-wt-JL-coord/TRACKING.md:858`). The JL-30a ref file still reads 85d16a5, so the revision looks uncommitted (inference).
- Line 171 of the candidate says this table "changes in the same commit" if review renumbers the ids, and it has not changed.
- Fix:
  - Add RML-44 → SKL-15, EV-0550, `reviews/JL-26.md:18-23`.
  - Add RML-45 → SKL-12, `reviews/JL-21.md:34`.
  - Add RML-46 → SKL-13, EV-0546.
  - Re-point RML-41 to `reviews/JL-21.md:21` and EV-0536.
  - Re-read the rows for the other revised ids.
  - Add a changelog row.

**N1 (non-blocking, accuracy): the RML-04 "correction" is wrong.**
- Where: `lessons.md:178` says "`tools/jev-player/decide.mjs:24-25` (inventory said 25-26)".
- In `decide.mjs`, line 24 is `CONFIDENCE_FLOOR`, line 25 is the "Bump when…" comment and line 26 is `GATE_VERSION`. The inventory's 25-26 was right.
- RML-06's `:20-23` (line 180) is also off by one: the floor constant is at 24.

**N2 (non-blocking, staleness).**
- `references/port-a-stage.md:10` says Spillway Drop is "in review at EV-0553". On the coordinator tree, JL-27 A1 and A2 passed review, then a new ruling said a Spillway trial ends at death, as a new epoch (EV-0555, `JL-coord/TRACKING.md:856`), and JL-27-A3 is in progress.
- The port procedure (`port-a-stage.md:14-29`) has no step for "end the trial at death". Nothing else is stated as current in a way that is now wrong:
  - `scenarios-and-arms.md:35` correctly says JL-21b is not merged.
  - `records-gates-pins.md:40` matches the merged JL-25 pins.
  - JL-26 is shown as merged at 42fd4ce.
- The EV-0556 finding that the executor's `_goal()` ignores the state rule is also not captured. Add both through the §8 "new lesson" row at integration.

**N3 (non-blocking, usability): the skill does not say where to read current state.**
- Nothing names where to look for live pins, the current epoch or current per-stage rulings.
- `plan-session/SKILL.md:12` says "the current epoch state" but not where it lives.
- Suggest one line in `SKILL.md` §1: pins under `artifacts/jev-lab-2026-09-25/pins/`, epoch records under `EPOCHS_ROOT`, rulings in the latest TRACKING rows for the card. Keep the SKL-26 exception for question-text authors.

**N4 (non-blocking, merge order).**
- On this branch, `SKILL.md:93`, `README.md:40`, `AGENTS.md:6`, `AI-WORKFLOW.md:44` and `CONTRIBUTING.md:38` name `npm run check:skills` (not yet in `package.json`) and `reactive-model-loop` (not yet present).
- The receipt `artifacts/local/tasks/JL-30b/sim-check.txt:7,11` shows the missing script. [receipt]
- Merge JL-30b after JL-30a and JL-30c.

**N5 (non-blocking, format).**
- The `SKILL.md` §8 table (`:84-91`) and the "Read … before" lines (`:22,34,43,57`) carry no "(design choice)" tag.
- The changelog row "Origin map" (`lessons.md:224`) is not one of the §4a change types.
- `SKILL.md` §8 routes an alias move to `scrapkeep-reviewer`. DESIGN §4a says coordinator plus `scrapkeep-reviewer-medium`. This is stricter, so harmless.

**N6 (packet correction).** The candidate base does include EV-0553 (`wt-JL-30b/TRACKING.md:854`). It predates EV-0554 onward.

## Criteria

**1. Accuracy: passes apart from B1 and N1.**
- I checked these SKL lessons against the cited lines: 01, 02, 03, 04, 06, 07, 08, 09, 10, 11, 13, 14, 15, 16, 18, 21, 22, 23, 24, 26, 27, 28, 29, 30. Every citation supports its lesson. Examples:
  - SKL-09: `reviews/JL-21.md:15` plus EV-0550 (120/120) and EV-0553 (119 and 118 of 120).
  - SKL-10: `gate.mjs:40-46`, `JL-25.md:11`, EV-0551.
  - SKL-11: `JL-25.md:9`, 14 of 20 in both runs.
  - SKL-18: `JL-21.md:19`, `gate.mjs:53-55`, `JL-26.md:72`.
  - SKL-23: EV-0553, "Rule for later packets".
  - SKL-24: `plan.md:203`; EV-0493 (16 calls); EV-0521.
  - SKL-28: `plan.md:67-70`, `harness.mjs:33-35`, EV-0542 (exit 6 after 12 calls).
  - SKL-29: `JL-26.md:25`, EV-0550 (seeds 2000-2019).
  - SKL-30: `JL-17.md:13`, EV-0546 (0.71-1.00).
- Each "established" lesson has two sources or a recorded ruling or owner decision. SKL-02 is the thinnest: one run plus its review, which is within the ledger's own definition at `lessons.md:7`.
- The four corrected facts are stated correctly:
  - Rule 2 is a coordinator ruling, and the writers had applied JL-21b as instructed (EV-0547, EV-0550): `lessons.md:86`, `SKILL.md:46`, `scenarios-and-arms.md:33`.
  - The preference-Noul result is 0 of 6 orders, top-rated in 18 of 18 calls, lead 0.10-0.14 (`RESULTS.md:14,18`): `lessons.md:146`.
  - Kinematic exit 1 means "differs": `SKILL.md:61`, `records-gates-pins.md:20`.
  - Batches launch from the writer's own worktree: `SKILL.md:74`, `determinism.md:41`.
- Origin-map rows checked against source: RML-01 (`prior-art:40`), 05 (`JL-15.md:22`), 06 ("unconfirmed" note correct), 09 (`prior-art:33`), 11 (`JL-19.md:36`), 12 (`JL-18.md:56`), 13 (`JL-18.md:18`), 14 (`JL-18.md:16`), 15 (`JL-15.md:14`, `JL-18.md:14`), 19 (`JL-19.md:21`), 29 (`JL-19.md:28`), 30 (`JL-19.md:63`), 40 (`prior-art:18`). RML-04 is wrong (N1).

**2. Usability: passes.**
- `SKILL.md:17` separates `scrapkeep lab run` (`harness.mjs` driving `fake-godot`) from real `godot-launch.mjs`. This matches `harness.mjs:1071` and `play.mjs:814-823`.
- The launcher flags match the `godot-launch.mjs:143` usage.
- The pin and subject flags match `gate.mjs:70-72`.
- The exit codes match `status.mjs:6-11`.
- `npm test` and `npm run sketch:smoke` exist (`package.json:15,26`).
- The `--call-cap 0` caveat matches `harness.mjs:672-675`.
- The add-scenario steps match `scenarios.gd` (`IDS:21`, `make:55`, `_jittered:139`) and the only Node registry, `fake-godot.mjs:96`.
- Minor gap: the skill never says `scrapkeep` is a wrapper for `node scripts/play.mjs`.

**3. Boundaries: passes.**
- The verify edit is exactly one row (`scrapkeep-verify/SKILL.md:26`) and one sentence (`:31`); I compared it with the JL-coord copy.
- The `scrapkeep-task` step 4 sentence (`:17`) is verbatim DESIGN §7.
- `plan-session:12` matches.
- `AGENTS.md:6` is one line.
- `AI-WORKFLOW.md` changes lines 3, 17 and 44, plus two table rows at 14-15 (slightly more than §7 listed) and "five" at 50.
- `CONTRIBUTING.md:38` adds one row.
- The README matches §5 and uses a fenced template, and `check:scope` shows no `_template/` directory. Receipt `check-scope.txt:9-24` lists 15 paths, all inside the lease. [receipt]
- `.claude/skills/scrapkeep-lab/SKILL.md` reads the same body. It appears as one path in `check:scope`, which is consistent with a symlink, but I cannot stat it.

**4. Staleness:** see N2 and N3.

**5. Format: passes.**
- The body is 96 lines (`SKILL.md:5-100`); receipt `sim-check.txt:6` agrees. [receipt]
- The frontmatter is DESIGN §2 verbatim.
- All 30 ledger entries follow the §4c shape. The origin-map table and the changelog columns follow §4c and §4d.
- The rule lines are tagged, with the N5 exceptions.

Command receipts (from the coordinator, not re-run by me): `check:docs`, `check:project` and `check:drift` exit 0; the local sim-check exits 1 with 5 findings, all explained by N4 or pre-existing `models/*.md` references. [receipts at `artifacts/local/tasks/JL-30b/`]

Key paths:
- `/home/andrew/Projects/scrapkeep-wt-JL-30b/.agents/skills/scrapkeep-lab/references/lessons.md`
- `/home/andrew/Projects/scrapkeep-wt-JL-30a/.agents/skills/reactive-model-loop/references/lessons.md`
- `/home/andrew/Projects/scrapkeep-wt-JL-30b/.agents/skills/scrapkeep-lab/references/port-a-stage.md`
- `/home/andrew/Projects/scrapkeep-wt-JL-coord/TRACKING.md` (lines 855-858)

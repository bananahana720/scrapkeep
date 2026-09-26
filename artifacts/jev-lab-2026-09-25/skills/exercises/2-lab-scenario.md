# JL-30 exercise 2: scrapkeep-lab, new scenario, arms, gate, port plan (scrapkeep-writer, Opus 5.5; verbatim)

Exercise branch `wt/JL-30x` at 7007f2f is not merged; it ran at base 131f6d9, before JL-21b, so the scripted stomp loop it observed is expected.

# JL-30 DoD 3 skill exercise (scrapkeep-lab): handback

**Verdict: PASS+NOTES, evidence level 4.** I ran real headless Godot batches, tests and the gate, and each result below comes from command output. The skill was enough to finish all four steps. It left two real gaps. It gives no way to place dummies per scenario, and it doesn't warn that the existing state test hardcodes the scenario count.

**Identity.**
- Worktree: `/home/andrew/Projects/scrapkeep-wt-JL-30x`.
- Branch: `wt/JL-30x`.
- Base verified at 131f6d9a2304cfec6511402d1cb060be05904a19.
- Head: 7007f2f79cc363c9e06641cea702975e63817e14, tree clean.
- Runtime: `env | grep CLAUDE_EFFORT` returned `CLAUDE_EFFORT=high`. No model variable is set, so the model is unverified at runtime. It is Opus 5.5 by the system prompt only, which is self-description.

## Step 1: `pillar-sprint` scenario
- **Spawn:** (40, 30), south of the steep kicker, with 3 m seeded jitter via `_jittered()`.
- **Objective:** a `waypoint` at (106, 40), radius 8 m. That is 58 m past pillar E.
- **Success:** `p["reached"]`.
- **Time limit:** 30 s, commented as initial and not calibrated.
- **Route:** the straight line clears every pillar by at least 8.7 m. Pillar radius 2.2 plus ball 1.0 plus jitter 3.0 needs 6.2 m.
- **Dummies:** ball-lab had no per-scenario dummy hook; all six come from `field.gd:84-87` for every scenario. I added an optional `dummies` key (default `[]`, which keeps the lab's six). `Scenarios.place()` now keeps only the named dummies at their spots and frees the rest. `pillar-sprint` runs with two, at (67, 52) and (92, 22), 16 to 18 m off the line.
- **Test (`jev_state_test.gd`):**
  - Id count 7 to 8 and jitter count 4 to 5.
  - A predicate case for `pillar-sprint`.
  - A new `[dummies]` check on every placed lab. It passes for 6 on the other scenarios and 2 on `pillar-sprint`.
- **Fake Godot:** skipped. Step 3 of the reference makes it conditional, and adding a `base` entry would also change the fake `soak` stream (`fake-godot.mjs:142-146`).
- **Changed paths:** `sketches/ball-lab/src/jev/scenarios.gd` and `sketches/ball-lab/tests/jev_state_test.gd`.

## Step 2: batches (kinematic, 5 trials each, `--seed 3`, from this worktree after commit)
I used seed 3 (trial seeds 3000 to 3004) to stay clear of the 1000 range the lab cards used and JL-28's pre-registered 2000 range. Both records show `dirty false` at head 7007f2f.

| Arm | Success | Wilson 95% | Snapshots offering 2+ options | Choices |
| --- | --- | --- | --- | --- |
| scripted (`20260926T001315Z-batch-pillar-sprint-scripted-537321cd`) | 0 of 5, all timeouts | [0, 0.434] | 150 of 155 (0.968) | stomp 142, push 11, kicker 1, ram 1 |
| random (`20260926T001352Z-batch-pillar-sprint-random-c12b93aa`) | 5 of 5 | [0.566, 1] | 82 of 87 (0.943) | push 38, stomp 38, evade 10, kicker 1 |

- Random minus scripted is 1.0, Newcombe 95% CI [0.386, 1.0]. With n = 5 this is exploratory.
- **Reading (inference):** scripted fails because of the SKL-14 stomp loop, not the scenario. It made 26 to 28 stomps per trial. The two dummies chase without end, knocked dummies stay in the threat list, and JL-21b is not in the base (`jev_state.gd` has no knocked filter).
- Automated; not a feel verdict.

## Step 3: gate
`node scripts/play.mjs gate 20260926T001315Z-batch-pillar-sprint-scripted-537321cd --against ball-lab-scripted-dummy-knock-kinematic` exited **2**. The gate printed "scenario pillar-sprint against the pin's dummy-knock".

Interpretation: exit 2 is a usage error, not a result. The batch is not like for like with the pin because the scenario differs (records-gates-pins.md:21, `gate.mjs:67`), so nothing was compared. I predicted exit 2 before running it.

## Step 4: port plan for a stage whose enemies have HP and a boss
**Copies unchanged:**
- `jev_io.gd` and the fixtures, byte for byte, with a drift test (SKL-06).
- The whole Node side: harness, protocol, `decide.mjs` preconditions, arms, record, gate, verdict cache.
- The launcher via `--sketch` and `stageFor()`, with one new `STAGES` entry and a stage metrics file.
- ball-lab's end-tick rule and intent timing in `jev_run.gd`.
- `seed_override := -1`, the only edit to gameplay code.

**Rebuilt under `sketches/<stage>/src/jev/`:**
- `jev_state.gd`: threats from the stage's own nodes, `self.hp`, and offers gated on reachable geometry.
- `scenarios.gd`: seeded jitter, initial limits labelled uncalibrated, and a boss scenario with its own success predicate.
- Telemetry wired to the stage's hit, death and boss-phase signals.
- `geo.gd` if the stage has no layout file.
- The executor, so stomp and ram hit the threat the state reports (SKL-31).
- Work on a lab branch cut from the proto head, and confirm the proto head does not move.

**Rulings needed before the first batch:**
1. Threat rule. Stage-threat-rule 2 fits HP foes. Rule separately whether the boss leaves the list during invulnerable or phase-change windows.
2. Whether a trial ends at player death (SKL-32). Also whether a boss kill ends it early.
3. How HP appears in the state. The threat block has no per-threat `hp` (PROTOCOL.md:170). Adding one, or a `boss` flag, is a new protocol string (SKL-01) and a new epoch.
4. Whether `retreat_regen` is offered. The stage has player HP, and the scripted ladder has a `low-health` rung.
5. The target-choice policy the executor follows: nearest, weakest or boss.
6. Reserved seeds.
7. The lease on the Node-side files.

## Commands and exit codes
- `git rev-parse HEAD` and `git branch --show-current`: exit 0, base and branch matched.
- Headless `jev_state_test.gd`: first run exit 1 (my own type-inference parse error in the new check, since fixed), rerun exit 0.
- `npm run sketch:smoke`: exit 0, all 10 ball-lab steps pass.
- `npm test`: exit 0, 710 of 710 pass.
- `git commit`: exit 0, 7007f2f.
- `npm run check:scope -- 131f6d9 7007f2f`: exit 0, scope `sketch`.
- `godot-launch.mjs pillar-sprint --arm scripted -n 5 --seed 3 --mode kinematic`: exit 0.
- Same with `--arm random`: exit 0.
- The gate: exit 2.

Receipts are in `/home/andrew/Projects/scrapkeep-wt-JL-30x/artifacts/local/tasks/JL-30x/` (gitignored): the logs plus `mix.mjs`, which computes the option share.

## Where the skill fell short
1. **Missing: per-scenario dummies.** `references/scenarios-and-arms.md:7` covers spawn, objective, limit and predicate. It says nothing about dummy placement, even though every ball-lab scenario shares the six fixed dummies. I had to add a hook.
2. **Wrong by omission: the existing test.** `references/scenarios-and-arms.md:10` says to add a test. It doesn't say that `jev_state_test.gd` hardcodes `ids.size() == 7` (line 405), `jittered == 4` (line 454) and a per-id `cases` table. A new id breaks that test until all three are edited.
3. **Missing: fake `soak` coupling.** `references/scenarios-and-arms.md:9` doesn't warn that fake `soak` cycles every `base` entry, so adding a fake scenario changes `soak`.
4. **Unclear: seeds.** `references/scenarios-and-arms.md:11` gives the example `--seed 1`, which lands on the 1000 range that line 15 says the lab cards already used. The skill never states the seed-times-1000 trial-seed stride (I read it from the pin's `trial_seed_stride`), and it doesn't say which seed an exploratory batch should use.
5. **Unclear: multi-option share.** `SKILL.md:53` and `references/scenarios-and-arms.md:12` don't define it: before or after the precondition gate. They also don't say that `arm_calls` and `forced` in the launcher output already give it.
6. **Missing: what to expect from scripted.** `references/scenarios-and-arms.md:35` says JL-21b is unmerged but not what follows. Any new dummy scenario will show scripted below random, and that should not be read as a scenario defect.
7. **Unclear: where "post hoc" labels go.** `references/scenarios-and-arms.md:13` says "the result file itself" but not which file when there is no card evidence directory. It also cites `reviews/JL-21.md:17`, which I could not read for this exercise.
8. **Missing: the update table has no row for a new scenario.** `SKILL.md:89-96` covers new mechanics and new stages only.
9. **Missing: HP foes and bosses.** The port material (`references/port-a-stage.md:16-17`, `references/scenarios-and-arms.md:27-31`) doesn't cover bosses, invulnerable phases or per-threat HP. It also doesn't mention that the protocol lacks a threat `hp` field.

## Deviations
- I wrote scratch logs to the session scratchpad and one log to `/tmp/claude-1000/`, both outside the worktree. I copied them into the worktree receipts directory above and deleted the `/tmp/claude-1000` file.
- I added no fake-godot entry.
- I ran no rigid batches, as the packet asked.
- No Jev calls were made.
- `check:scope` names Andrew's play as the next step; that is not applicable to this exercise.

## Follow-ups
- Whether to keep the `dummies` hook if this ever becomes real work.
- Re-run `pillar-sprint` scripted after JL-21b lands.
- Calibrate the 30 s limit with 20 trials per mode.

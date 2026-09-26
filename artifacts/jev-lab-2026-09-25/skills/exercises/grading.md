# JL-30 DoD 3 exercise grading (scrapkeep-reviewer-medium, Opus 5.5; verbatim)

Coordinator response: F2 (the exercise 1 agent could read the stub source; a setup flaw by the coordinator) is being closed by a blind re-run, exercise 1b, with the decider behind an opaque base64 module, new planted flaws, and a sealed answer key kept outside the agent's directory. F1 and F6 went to JL-30d.

## JL-30 DoD 3 grading: overall PASS+NOTES (evidence level 3)

I read the artifacts, code and records directly and ran no commands, because this role has no shell. Every exit code and test count below comes from the agents' own receipts and is labelled **[receipt]**.

### Findings

**F1 (Ex1). The 0.1 noise-line floor was copied from the skill's example. It decided one cell but not the verdict.**
- **Where it came from:** the pre-registration uses `max(0.1, 3 × pooled within-order SD)` (`ex1-work/preregistration.md:47`). That is the skill's example formula, verbatim (`reactive-model-loop/references/controls.md:40`, `references/lessons.md:75`). The skill calls the formula "an example of the shape, not a validated constant", but it hands over the 0.1 with no rule for picking a floor.
- **What it decided:** the in-run pooled SD was 0.0078 (`run1-analysis.json:5-6`), so every cell's line sat on the floor. That floor decided C1: the minimum margin was 0.0584, about 7.5 SD. The agent disclosed this in the body (`1-portable-drone.md:69`) and listed it as skill gap 2 (`:140`).
- **Where the headline overstates:** the Outcome bullet "Dominance (C1): margin fails in 4 of 6 orders" (`:10`) omits that caveat.
- **What does not depend on the floor:**
  - The overall NOT TRUSTED verdict. C2 fails on the agent's own 0.10 lethal line; the skill gives no number there (`controls.md:16`). C3 fails on fallbacks.
  - The position flag. The range of 0.170 exceeds both 0.1 and 3×SD = 0.023.
- **Against the pass criterion:** "no number copied from the skill's examples as a threshold" is missed in letter and met in substance.
- **Skill fix:** controls.md:40 should drop the constant or require a stated reason for any floor.

**F2 (Ex1). Reading the stub source is disclosed and acceptable for the process criteria. It means the exercise does not show that the skill leads a blind agent to hidden bias.**
- **Disclosure:** the agent recorded before the run that it had seen the last-position adjustment and the options[0] fallback (`preregistration.md:94`).
- **Why the leak happened:** the design meant this to be the leak control (`DESIGN.md:190`), but `decider.mjs` sat readable in the agent's own scratch dir. That is a setup flaw, not agent misconduct.
- **Why the process criteria still stand:** the skill independently mandates every order with repeats, measured in-run position effects (`SKILL.md:39`, RML-12) and live-only pass checks (`SKILL.md:42`). RML-12's evidence even cites a last-position boost (`lessons.md:70`). The measured numbers come from real calls: pad mean 0.437 / 0.435 / 0.601 by position, and 15 of 15 fallbacks equal to options[0] (`run1-analysis.json:382-403, 411-416`).
- **What the leak did shape:** at least one reading. R-fb's "whether fallbacks equal options[0]" (`preregistration.md:63`) is specific to what the code shows.
- **To demonstrate blind discovery:** rerun with the decider behind an opaque process boundary.

**F3 (Ex1, minor, unresolved).** The handoff lists `src-prereg` as lines 1-112 (`1-portable-drone.md:182`), but the file has 97 lines. Its sha256 in `work/provenance-after.txt:6` does match the reported `5e6d45cd…4040`. I cannot hash the current file, so whether it is unchanged is unverified.

**F4 (Ex2). The gate claim has no retained receipt.**
- The receipts dir holds `state`, `smoke`, `npmtest`, `scripted` and `random` logs plus `mix.mjs`. There is no gate log.
- The claimed exit 2 is consistent with the code:
  - `scenario` is in `LIKE_FOR_LIKE` (`scripts/lab/gate.mjs:67`);
  - the mismatch throws `UsageError` (`gate.mjs:609-616`), which maps to `EXIT.usage` (`gate.mjs:720-722`);
  - the pin's scenario is `dummy-knock` (`pins/ball-lab-scripted-dummy-knock-kinematic/run.json:44`).
- The exit itself is **[receipt]**/inference.

**F5 (Ex2). "Run record validates" holds by inspection only.**
- The gate's usage error fires before `assessRun` (`gate.mjs:604-627`), so no validator ever read the records.
- Both `run.json` files look sound: `schema` is `scrapkeep-run/1`, head is 7007f2f, `dirty: false`, sources `matched: true`, and `jev.calls` is 0 with a null model (`runs/…537321cd/run.json:2-41`; the random record shows the same).
- **Zero Jev calls: confirmed** from both records.

**F6 (Ex2). The design's "Node registry" item was skipped, and the skill allows that.**
- The skill makes the fake-godot entry conditional (`scrapkeep-lab/references/scenarios-and-arms.md:9`). The agent gave its reason (`2-lab-scenario.md:27`).
- The real launcher ran the scenario anyway (`scripted.log:1-8`).
- The design's pass column and the skill disagree here; this is not an agent defect.

**F7 (Ex2). A disclosed change beyond adding a scenario.**
- The agent added a `dummies` key to every scenario dict (`scenarios.gd:150-151`) and changed `place()` to free unnamed dummies (`scenarios.gd:170-177`).
- The default `[]` returns early, so existing scenarios are unchanged. `state.log:4-18` shows 6 dummies on every other scenario **[receipt]**.
- The branch is unmerged, so nothing propagates.

**F8 (Ex2). The port plan is consistent with JL-26 and JL-27, with omissions only.**
- **Consistent:**
  - `jev_io` copied verbatim with a drift test (`reviews/JL-26.md:63-67`, `JL-27.md:99`);
  - reuse of `STAGES` and `stageFor` (`JL-26.md:100`);
  - `seed_override` as the only gameplay edit (`JL-26.md:55`, `JL-27.md:75`);
  - the same end-tick rule (`JL-26.md:70`);
  - stage-threat-rule 2 for HP foes (`JL-26.md:18-23`);
  - death-ends-trial raised as a ruling (`JL-27.md:17-35`);
  - reserved seeds (`JL-26.md:25`).
- **Omitted:**
  - seed-0 aliasing (`JL-26.md:44`, `JL-27.md:52-56`);
  - deaths recorded as `timeout` or with no `end` field (`JL-26.md:40-42`, `JL-27.md:67`);
  - the sketch-repo provenance gap (`JL-26.md:46`);
  - stage metrics missing from the dashboard (`JL-26.md:50`);
  - dead-ball snapshots pooled into metrics (`JL-27.md:25-31`), only partly covered by ruling 2.
- Nothing contradicts either review.

**F9 (Ex3). The "reads the new lab row" half of the design criterion was not exercised.**
- The explorer says it read frontmatter only (`3-routing.md:5`). It still cites `plan-session/SKILL.md:12`, which is body text, so that claim is slightly inaccurate.
- Its B routing rests on scrapkeep-lab's description disclaimer, not on scrapkeep-verify's lab row (`scrapkeep-verify/SKILL.md:26`).

### Per-exercise verdicts

**Exercise 1 (reactive-model-loop, drone stub): PASS+NOTES**

| Criterion | Result | Evidence |
| --- | --- | --- |
| Position effect flagged against an in-run noise line | Met | R-pos range 0.170 against a line of 0.1; SD 0.0078 reported (`run1-analysis.json:379-381`) |
| Fallbacks counted as not from the decider | Met | Pass rule requires `source == "model"` (`preregistration.md:51-53`); R-fb reading; fallbacks never cached (`cache.mjs:31`) |
| Pass rule stated before the run | Met, on the agent's own records | Pinned hashes and change record marked "before any live call" (`preregistration.md:74-94`); the runner refuses a live run on a hash mismatch (`runner.mjs:58-63`) |
| Resolved model in the cache key | Met | `cache.mjs:15,19`; replay rejects a missing or different model or a two-model cache (`cache.mjs:40-44`) |
| No copied threshold | Missed in letter only | F1 |

- **Skill use:** real. The pre-registration follows the skill template's headings exactly (`references/preregistration.md:36-88`), and the report cites RML ids and sections (`1-portable-drone.md:133-134`).
- **Leak:** F2.

**Exercise 2 (scrapkeep-lab): PASS+NOTES**
- **Scenario added correctly:** `IDS`, the `make()` branch, jitter and a limit labelled uncalibrated (`scenarios.gd:21-22, 98-104`).
- **Run records sound by inspection:** F5.
- **Zero Jev calls:** confirmed.
- **Gate exit read as the skill defines it:** exit 2 as "usage error, not a result" matches `records-gates-pins.md:21`. The "differs, not worse" reading for exit 1 was not reachable without cutting a pin, which the task forbade.
- **Evidence location:** under `artifacts/local/tasks/JL-30x/`, except the missing gate log (F4).
- **Port plan:** consistent with the reviews (F8).
- **Skill use:** real. It cites skill line numbers and SKL ids, and lists nine concrete skill gaps (`2-lab-scenario.md:85-94`).

**Exercise 3 (routing): PASS+NOTES**
- B, C, D and E route to scrapkeep-verify, scrapkeep-lab, reactive-model-loop and scrapkeep-task.
- **The A tie is real:**
  - scrapkeep-lab's description names "start an instrument epoch" (`scrapkeep-lab/SKILL.md:3`);
  - plan-session's names "Plan the next Scrapkeep scope" (`plan-session/SKILL.md:3`);
  - the agent leaned to plan-session using step 1 (`plan-session/SKILL.md:12`), which is the intended entry point.
- **Open item:** F9.

### Overall: PASS+NOTES

All three agents completed a representative task, and none of the notes breaks DoD 3. Before the coordinator closes the card:
- **Accept or close:** F9, by re-asking prompt B with the verify body open.
- **Accept or close:** F2. Ex1 shows the process, not blind discovery.
- **Fix in the skill:** the F1 floor in `controls.md:40`.
- **Fix in the skill:** ex2's gaps: per-scenario dummies, the hardcoded test counts, the seed stride, and HP/boss protocol fields.
- **Fix in the design:** its pass column and `scenarios-and-arms.md:9` disagree on the Node registry (F6).

### Runtime
- **Model:** the system prompt names Opus 5.5 (`claude-opus-5-5`). That is harness self-description, not runtime evidence.
- **Effort:** `CLAUDE_EFFORT` is unavailable to me (no shell).

### Key paths
- /home/andrew/Projects/scrapkeep-wt-JL-coord/.agents/skills/reactive-model-loop/references/controls.md
- /home/andrew/Projects/scrapkeep-wt-JL-coord/artifacts/jev-lab-2026-09-25/skills/exercises/ex1-work/preregistration.md
- /home/andrew/Projects/scrapkeep-wt-JL-30x/sketches/ball-lab/src/jev/scenarios.gd
- /home/andrew/Projects/scrapkeep-wt-JL-30x/scripts/lab/gate.mjs
- /home/andrew/Projects/scrapkeep-wt-JL-30x/artifacts/local/tasks/JL-30x/

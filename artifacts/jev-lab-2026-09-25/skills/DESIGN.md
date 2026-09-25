# JL-30 skill suite design (pstack-architect, Fable 5.1; verbatim)

Coordinator acceptance (2026-09-25): accepted as written. Two skills (`reactive-model-loop`, portable; `scrapkeep-lab`, project), `check-skills.mjs` wired into `check:docs`, lesson ledgers with status and changelog, a skills README with the creation rules, small edits to the three existing skills and to AGENTS.md, AI-WORKFLOW.md and CONTRIBUTING. Built by three writers in separate worktrees; the portable skill lands first so the project skill can map every RML id to its origin. The design note that `verify.py` may flag the two new skills is left for Andrew (outside the repository).

# JL-30 skill suite design

Read-only; nothing written. Coordinator worktree observed at `wt/JL-coord` head `fc65ebb` (command receipt below). Runtime: system prompt states Fable 5.1 (`claude-fable-5-1`); `CLAUDE_EFFORT=high` read from the environment this session.

## Outcome

Two new skills plus small cross-links, not three. Inventory 3 (coordination) does not become a skill: its lessons are either evidence-discipline rules that belong in the portable skill's evaluation reference (computed-vs-measured, result-triggered edits, dirty-tree evidence, review-tier pattern) or board mechanics that ORCHESTRATOR and CONTRIBUTING already own (hash drift, `board-commit.sh`, writer caps). AGENTS.md line 6 makes ORCHESTRATOR canonical for coordination, so a fourth skill would compete with it.

The split the evidence supports:

| Skill | Kind | One-line trigger |
| --- | --- | --- |
| `reactive-model-loop` | portable, new | Use when a fast model (Jev or similar) makes reaction-based decisions inside a running system and you must design, control, evaluate, cache, cost or trust that decision path. Not for finding where a model could help (`jevify`) or for the TypeSafe API itself (`typesafe-ai`). |
| `scrapkeep-lab` | project, new | Use to run, extend, gate or port the headless Godot lab: a scenario, an arm, a batch, a pin, a gate result, an instrument epoch, or a new stage lab. Defers verification rows to `scrapkeep-verify` and admission to `scrapkeep-task`. |
| `plan-session`, `scrapkeep-task`, `scrapkeep-verify` | existing, edited | one or two sentences each, below |

Why not fold the lab into `scrapkeep-verify`: verify owns "which commands qualify this artifact class" (SKILL.md table, `.agents/skills/scrapkeep-verify/SKILL.md:17-23`); the lab skill owns *producing* lab evidence and reading its meaning (a kinematic exit 1 is "differs", not "worse"; inventory-2 §4, reviews/JL-25.md:9). Verify gets one new row that points at the lab skill; the lab skill never restates a verify row.

Why not a third "pre-registered experiment" skill: pre-registration is portable method (inventory-1 §2, jl18c/PREREGISTRATION.md:202-210) and lives in `reactive-model-loop/references/preregistration.md` with a template; `scrapkeep-lab` cites `tools/jev-player/experiments/jl18c/` as the worked example. Same trigger family, one owner, no split.

## 1. File tree

```
.agents/skills/
  README.md                          # rules for creating a skill (section 4), the template
  reactive-model-loop/
    SKILL.md                         # ≤120 body lines
    references/
      instrument.md                  # instrument identity, gates, floors, framing, position
      controls.md                    # dominance/lethal/wording controls, noise lines, permutations
      corpus.md                      # blind corpus rules, labeller isolation, text-only baseline
      preregistration.md             # template + phase A/B procedure + hash pinning
      runtime.md                     # cache key, replay, redaction, fallbacks, caps, epochs, cost fields
      cadence.md                     # blocking lockstep vs realtime hold-last-intent tradeoff
      lessons.md                     # ledger RML-01.. with status, origin (no repo names), changelog
  scrapkeep-lab/
    SKILL.md                         # ≤120 body lines
    references/
      protocol.md                    # pointer to PROTOCOL.md + the rules that bit (own-key lookup, tmp+rename)
      determinism.md                 # kinematic vs rigid, gates per mode, sensitivity test
      scenarios-and-arms.md          # add a scenario, add an arm, threat rule per stage, jitter, time limits
      records-gates-pins.md          # scrapkeep-run/1, 5-way exit, epochs, pins, anchor subject
      port-a-stage.md                # what copies byte-identical, what is rebuilt, the ruling to make
      lessons.md                     # ledger SKL-01.. citing EV/review paths; maps every RML id to its origin
.claude/skills/
  reactive-model-loop -> ../../.agents/skills/reactive-model-loop
  scrapkeep-lab       -> ../../.agents/skills/scrapkeep-lab
scripts/check-skills.mjs             # staleness check (section 3b)
tests/check-skills.test.js
package.json                         # "check:skills": "node scripts/check-skills.mjs"
```

Body pattern copies the existing three: first paragraph "Resolve this skill directory through symlinks, then `git -C <dir> rev-parse --show-toplevel`…" (`.agents/skills/scrapkeep-task/SKILL.md:8`), root-relative paths, a `## Host adapter` section. No `${CLAUDE_SKILL_DIR}` in either body: Codex reads the same file (AGENTS.md:6, AI-WORKFLOW.md:3) and the pstack rule resolves references relative to SKILL.md, so `references/x.md` links work on both hosts. The pstack `architect` skill uses the same `references/` layout (`/home/andrew/.config/pstack/plugin/skills/architect/references/`).

## 2. Frontmatter and section outlines

### `reactive-model-loop/SKILL.md`

```yaml
---
name: reactive-model-loop
description: "Design, control, evaluate, cache and cost a fast model that makes reaction-based decisions inside a running system (a game tick, a triage step, a router). Use when adding or changing such a decision path, judging whether its result is evidence, or reviewing one. Not for choosing where a model could help (jevify) or for the TypeSafe API (typesafe-ai)."
---
```

Sections (each ≤10 lines; rules cite lesson ids, bodies live in references):

1. **What the model decides and what code decides.** Coarse intent from the model; deterministic code owns execution, safety and preconditions (prior-art cross-project pattern; inventory-2 §3 speed-gate F4: a gate on present state for a future-reachable target is a category error). Decomposition checklist: smallest orthogonal set of Choice/Noul questions; ask whether a menu Choice should be per-option Nouls (prior-art idea 1; RML: Nouls remove position bias but need a margin rule, inventory-1 §1 JL-18c e-cell).
2. **Instrument identity and epochs.** Identity = hash of every input that changes behaviour, resolved model not alias (inventory-1 §1 N5/JL-18b; prior-art: four of six repos pin `jev-latest`). Manual version constants under-version (GATE_VERSION, reviews/JL-03.md N2-N3). Retain pre-floor raw output (inventory-1 §1 CONFIDENCE_FLOOR). → `references/instrument.md`.
3. **Controls before trust.** Dominance, lethal, wording-swap, every order, live never cached, pass rule with a noise line derived in-run (`max(0.1, 3× pooled SD)`), same-choice rule blind to magnitude, control must assert answer source is the live decider (inventory-1 §1 and §3 finding 4). → `references/controls.md`.
4. **Corpus and blindness.** Separate labeller with a forbidden list; provenance per case; burned cases; text-only baseline scanner plus hand check; blindness is relative to a boundary and rechecked per use (inventory-1 §2; inventory-3 §1 JL-04-A2). → `references/corpus.md`.
5. **Pre-register, run once, disclose.** Hash-pinned inputs, runner refuses on mismatch, fixed readings table, exploratory findings labelled, retraction append-only, V/U/R claim tags (inventory-1 §2; inventory-3 §1 cherry-picking JL-23-A2, §7). → `references/preregistration.md`.
6. **Runtime.** Cache key, replay makes zero calls and treats an absent model field as mismatch, redaction before clip/hash/key with adversarial-format tests, fallbacks never cached and always labelled (prior-art lukaske `FALLBACK`), call caps counted before send, all-error run never overwrites a passed epoch (inventory-1 §3). → `references/runtime.md`.
7. **Cost and latency accounting.** Never sum `input_tokens`/`cache_*` fields; absent is `null` not 0; dedupe by request id; latency cites the retained artifact it is computed from; a persisted dollar cap is the strongest control seen (prior-art olivier-motium, ASSERTED from the research note). → `references/runtime.md`.
8. **Cadence: blocking vs realtime.** Lockstep blocking gives reproducible traces and evidence-grade replay; hold-last-intent streaming gives feel at ~8-10 Hz and no reproducibility (prior-art disagreement section; PROTOCOL.md:98-107). Rule: evidence runs block; demos stream and are labelled "demo, not evidence" (JL-31 DoD 2 applies this). → `references/cadence.md`.
9. **Reporting.** Measured vs computed vs simulated; state what you did not read; name model and effort from evidence.
10. **Lessons and updates.** Pointer to `references/lessons.md`, the status enum, and the update table (section 3a).

Numbers appear only as labelled examples ("in one lab: position range 0.09-0.35 against 0.03-0.06 same-position noise"), never with a repo, card or path.

### `scrapkeep-lab/SKILL.md`

```yaml
---
name: scrapkeep-lab
description: "Run, extend, gate or port Scrapkeep's headless Godot lab: add a scenario or arm, run a batch through the harness, cut or compare a pin, read a gate exit, start an instrument epoch, or bring the lab to a new stage. Use for lab, harness, scenario, arm, pin, gate or epoch work; verification rows stay in scrapkeep-verify and admission in scrapkeep-task."
---
```

Sections:

1. **Map.** `tools/jev-player/{decide,preflight,score}.mjs`, `protocol/PROTOCOL.md`, `questions/`, `controls/`; `scripts/lab/{harness,godot-launch,arms,gate,record,program,verdict-cache}.mjs`; `sketches/ball-lab/src/jev/*.gd`; `scripts/play.mjs` verbs (`scrapkeep lab run|program|verdicts`, `gate <run> --against <pin>`); evidence under `artifacts/jev-lab-2026-09-25/{live,pins,reviews,experiments}` and disposable under `artifacts/local/`. Read `reactive-model-loop` for the instrument rules; this skill applies them.
2. **Protocol.** One writer per file, tmp+rename, D=90/k=26 with k<D, block with `OS.delay_msec` never `tree.paused`, `trace_hash` over `events.ndjson` only, closed schemas with own-string-key lookup, fixtures byte-copied with a drift test, outcome precedence total order (inventory-2 §1). → `references/protocol.md`.
3. **Determinism per mode.** Kinematic exact; rigid stochastic (~1 in 20 flips, can flip the outcome); gates split by mode; rigid gate as shipped compares no rate (open, JL-25 F1/F2); sensitivity test perturbs k and one intent (inventory-2 §2). → `references/determinism.md`.
4. **Scenarios and arms.** Paired jitter per trial; time limit rule and its censoring defect; scripted ladder needs memory/termination; threat rule per stage ("stage-threat-rule 2", EV-0550: a foe leaves state only when the game removes it); calibrate constants from physics probes, not gameplay trials (inventory-2 §3, coordinator correction 2). → `references/scenarios-and-arms.md`.
5. **Records, gates, pins, epochs.** `scrapkeep-run/1`, `O_EXCL` owner file, 5-way exit enum, exit 1 means "differs" in kinematic, pin `subject` block, `andrew-anchor` exemption, dirty flag covers declared paths only, clean-head hash re-run as the cheap dirty-tree proof (inventory-2 §4). → `references/records-gates-pins.md`.
6. **Port to a stage.** Copy `jev_io.gd` byte-identical; rebuild `jev_state.gd`, `scenarios.gd`, telemetry wiring, `geo.gd` if needed; reuse `STAGES`/`stageFor` and `--sketch`; decide the threat rule before the first batch; lab branch off the proto head, proto unchanged before and after (inventory-2 §5; inventory-3 §4). → `references/port-a-stage.md`.
7. **Evidence rules.** No Jev call on the gate path; live batches carry a cap; `score.mjs` needs `--dry-run` before probing (EV-0493 incident); retained evidence copied at admission after a secret and home-path scan (inventory-3 §3).
8. **Lessons and updates.** `references/lessons.md`, SKL ids, and the RML origin map.

## 3. Portability boundary

Portable skill contains: concepts, rules, procedures, templates, the tradeoff in section 8, lesson ids with status and an `origin` field written as a description ("a 216-call pre-registered run, six designs, three repeats per order"). It contains no repository path, no `EV-`/`JL-`/`Q-` id, no sketch, stage, engine or physics-backend name, no npm script, no person name beyond none. `check-skills.mjs` enforces a forbidden-token list on that directory (section 4b).

Scrapkeep skill contains: every path, command, id, number that is a project fact, and `references/lessons.md` with a table `RML-nn → EV/review citation` so every portable lesson has a cited origin inside this repository (DoD 1's citation requirement met without polluting the portable copy). Promotion = copy the `reactive-model-loop` directory; the origin map stays behind.

Grey items and where they go:

| Item | Home | Reason |
| --- | --- | --- |
| Blocking lockstep design (D/k, delay_msec) | Scrapkeep, with the *pattern* in portable `cadence.md` | Jolt and Godot specifics |
| Own-string-key validator bug | Both: rule in portable `runtime.md` (any Node validator on untrusted keys), instance in Scrapkeep `protocol.md` | Portable bug class, project fix |
| Ledger double-count (`ledger.py`) | Neither skill; one line in Scrapkeep `lessons.md` as an external caveat on board token figures | Fix lives outside the repo (EV-0498) |
| Jev 1.13 stated limits ("reads literally, weak at math…") | Portable `instrument.md`, status provisional, origin "public use-case list, unaudited" | Third-party claim |
| Prior-art cadence disagreement | Portable `cadence.md` as a tradeoff, not a lesson | No measurement in this program of the realtime side |

## 4. Anti-debt mechanics

### (a) Update procedure, keyed to change type

| Change | Section that changes | Also touch | Reviewer |
| --- | --- | --- | --- |
| New mechanic in a stage | `scrapkeep-lab` §4 (threat rule, options), `references/scenarios-and-arms.md`; if it changes what options the model sees → new epoch per §5 | `jev_state.gd` header, `GATE_VERSION` | scrapkeep-reviewer-medium; scrapkeep-reviewer if the epoch changes |
| New stage | `references/port-a-stage.md` checklist gains the stage row; §1 map gains its paths | CONTRIBUTING lab rows, `STAGES` | scrapkeep-reviewer-medium |
| Protocol change (`PROTOCOL.md`) | `references/protocol.md`; fixtures and both validators | `scrapkeep-lab` §2; portable `cadence.md` only if the pattern changes | scrapkeep-reviewer (both validators re-derive from spec) |
| Instrument or question-set change | `scrapkeep-lab` §5 epoch entry; `reactive-model-loop` unchanged unless the *method* changed | new epoch must re-pass controls and blind corpus before any pin | scrapkeep-reviewer, blind to the question text (packet forbids TRACKING per EV-0525) |
| New model version or alias move | `scrapkeep-lab` §5 (resolved model recorded, new epoch); portable `instrument.md` if pinning rules change | `resolved_models` in epoch record | coordinator + scrapkeep-reviewer-medium |
| New result that overturns a lesson | `lessons.md` in the owning skill: status → retracted, `overturned_by` filled, text kept; the rule line in SKILL.md that cited it is edited in the same commit | changelog row | scrapkeep-reviewer (consequential; matches the review-tier pattern in inventory-3 §1) |
| New lesson (not overturning) | append to `lessons.md` as provisional with evidence; promote to established only after a second independent run or review cites it | changelog row | scrapkeep-reviewer-medium |

The coordinator alone commits the skills (AGENTS.md: coordinator is the sole canonical writer); writers deliver skill edits in their worktree like any file.

### (b) Mechanical staleness check: `scripts/check-skills.mjs`

Contract:

- Input: every `.agents/skills/*/SKILL.md` and `.agents/skills/*/references/*.md`; `package.json`; `TRACKING.md`; `BACKLOG.md`; the filesystem.
- Checks, each a named finding with file:line:
  1. Frontmatter: `name` equals the directory name; `description` present, ≤ 1024 chars, starts with a verb or "Use".
  2. Link: `.claude/skills/<name>` exists, is a symlink, resolves to `.agents/skills/<name>` (same rule AI-WORKFLOW.md:42 says `verify.py` checks for the three).
  3. Paths: every backtick token that looks like a repo path (`^[a-z0-9_.-]+/` or `.mjs|.gd|.md|.json` suffix) resolves from the repo root; a path with `<...>` placeholders is skipped; glob tokens are skipped.
  4. npm scripts: every `npm run <name>` and `npm test` exists in `package.json` scripts.
  5. CLI verbs: `scrapkeep lab <verb>` and `scrapkeep <verb>` checked against the verb lists exported from `scripts/play.mjs` (`verbs` at play.mjs:889 and the lab usage string at :838); if not exported, the check greps the usage strings and reports "verb list not exported" as a warning rather than inventing a list.
  6. Ids: every `EV-\d{4}` exists as a row in TRACKING (same regex the lab-dash test uses, `tests/lab-dash.test.js:537`); every `JL-\d+[a-z]?`, `Q-[EP]\d{2}` exists as a BACKLOG anchor.
  7. Lessons ledger: ids unique across both ledgers, prefix `RML-` in the portable skill and `SKL-` in the project skill; `status ∈ {established, provisional, retracted}`; `evidence` non-empty; a retracted lesson has `overturned_by`; every RML id appears in the Scrapkeep origin map; every lesson id cited in a SKILL.md exists.
  8. Portability: `.agents/skills/reactive-model-loop/**` contains none of a forbidden list (`scrapkeep`, `Scrapkeep`, `Godot`, `Jolt`, `ball-lab`, `cable-bench`, `spillway`, `EV-`, `JL-`, `Q-E`, `Q-P`, `artifacts/`, `tools/`, `scripts/`, `npm run`, `Andrew`); the list lives at the top of the script.
  9. Size: SKILL.md body over 150 lines is a warning; over 250 is a failure.
- Exit: 0 clean, 1 findings, 2 usage or unreadable input. Output: one line per finding, then a count; `--json` prints the findings array.
- Wiring: `check-docs.mjs` `main()` (check-docs.mjs:715) runs it as a stage so `npm run check:docs` covers it, which `check:scope` already prints for documentation and agent-configuration scopes (check-scope.mjs:38,77,99); a separate `npm run check:skills` for direct use; `tests/check-skills.test.js` with fixture skill directories exercising a dead path, a dead EV, a forbidden token and a retracted lesson without `overturned_by`, run by `npm test`.
- Limits it states: existence only, not correctness; a rename that keeps the old path alive as a stub is not caught; a lesson whose evidence file exists but no longer supports it is a review job.

### (c) Lesson format

One bullet per lesson in `references/lessons.md`:

```
- **RML-07** · status: established · since: 2026-09-25 · origin: one lab, 216-call pre-registered run
  Position-effect direction is not a stable prior; measure it in the run being judged.
  Evidence: a last-position boost in one run, a first-position depression in the next, same day.
  Overturned by: —
```

Project ledger identical with `SKL-` ids and `Evidence:` holding `EV-nnnn`, `artifacts/jev-lab-2026-09-25/reviews/JL-nn.md:line`. The origin map is a table `| RML id | SKL id or citation |`. A SKILL.md rule line ends with `(RML-07)` so the check can cross-reference; a rule with no lesson id is a design choice, not a lesson, and says so.

### (d) Changelog

`## Changelog` at the end of each `lessons.md`, append-only, one row per change: `| date | change type (from the table in 4a) | ids touched | evidence or commit | reviewer |`. No separate CHANGELOG file; the check verifies the section exists and that the newest row's date is not before a retracted lesson's `overturned_by` date.

## 5. Creating skills later: `.agents/skills/README.md`

Rules:

- **Skill vs section.** A new skill needs all three: a trigger a fresh agent would search for that no existing description covers; at least two references of its own; a distinct owner or reviewer tier. Otherwise it is a section or a reference in the closest skill. A per-stage lab is a row in `port-a-stage.md`, not a skill.
- **Naming.** `scrapkeep-<noun>` for project skills; a plain noun phrase, no project token, for portable ones. Directory name equals frontmatter `name`.
- **Trigger wording.** One or two sentences: the artifacts it acts on, the verbs, then "Use for/when …", then what it defers to by skill name. Test it with three prompts (one in, one near-miss, one belonging to another skill) before commit.
- **Where.** Body under `.agents/skills/<name>/SKILL.md`; details under `references/`; `ln -s ../../.agents/skills/<name> .claude/skills/<name>`; register in `docs/project/AI-WORKFLOW.md` (its lines 3 and 15 currently say "three canonical skills" and must change with JL-30 anyway) and AGENTS.md line 6.
- **Template** (in the README, fenced): frontmatter; the resolve-through-symlinks paragraph; `## Procedure` numbered; `## Host adapter`; `## Lessons and updates` pointing at `references/lessons.md` with the status enum; body ≤120 lines.
- **Check.** `npm run check:skills` clean before the coordinator commits.

Not a `_template/` directory under `.agents/skills`: a loader would list it as a skill.

## 6. Exercise plan for DoD 3

| Skill | Task given to a fresh agent | Tier | Pass | Leak control |
| --- | --- | --- | --- | --- |
| `reactive-model-loop` | In a scratch directory with a stub decider (a local function returning probabilities, written by the coordinator with a hidden last-position boost of about 0.2 and a 5% "fallback" answer rate), design and run a dominance control with every permutation and three repeats, pre-register the pass rule, report; then write the cache key and replay rule for it. | `pstack:pstack-worker` (Opus) | Report flags the position effect against an in-run noise line; counts the fallback answers as not-from-decider; pass rule stated before the run; cache key names resolved model; no number copied from the skill's examples as a threshold. | Stub bias is not in the brief; the brief is the skill path and the scratch path only; the agent cannot read this repo (scratch outside it). |
| `scrapkeep-lab` | Add a scenario `<name>` to ball-lab, run scripted and random arms kinematic n=5 through the harness, cut nothing, then run `gate` against `ball-lab-suite` and interpret the exit. | `scrapkeep-writer` (Opus; inventory-3 §5 moved process-running cards off Sonnet) | Scenario in `scenarios.gd` and the Node registry; run record validates; zero Jev calls (cap 0 in the brief); exit interpreted as "differs" not "worse"; evidence under `artifacts/local/tasks/`. Optional second task: a port plan for a named stage that lists what copies byte-identical, what is rebuilt, and the threat-rule decision, checked against reviews/JL-26.md §2. | Brief names the skill and the card only; the inventories and reviews directory are forbidden reads in the packet; reviewer compares against JL-21/JL-26 review lists the agent never saw. |
| existing three (cross-links) | Trigger test: three prompts ("plan the next lab epoch", "verify this lab tooling diff", "add a stage lab") to a fresh `scrapkeep-explorer`; it names which skill it would load and why. | Sonnet | Each prompt routes to the intended skill; the second lands on `scrapkeep-verify` and reads the new lab row. | No skill named in the prompts. |

Reviewer for each exercise: `scrapkeep-reviewer-medium`, holding the pass column and the transcript; coordinator keeps transcripts under `artifacts/local/tasks/JL-30/exercises/`.

## 7. Existing-skill edits (one or two sentences each)

- `plan-session` step 1: "For lab or Jev scope, read `scrapkeep-lab/references/lessons.md` and the current epoch state before proposing work."
- `scrapkeep-task` step 4 (packet): "A lab card names the epoch and pin it runs against, its call cap, and forbids the writer reading the blind corpus, its provenance and TRACKING when it authors question text (EV-0525)."
- `scrapkeep-verify` table: new row "Lab tooling or sketch lab code — `npm test`, `npm run sketch:smoke` when a sketch changes, and the gate against the named pin; the exit's meaning and the pin rules are in `scrapkeep-lab`." Plus one sentence in the closing paragraph: "Automated lab play is not a feel verdict."
- AGENTS.md line 6 and AI-WORKFLOW.md lines 3, 15, 42: five skills, two links, `check:skills`.
- CONTRIBUTING: one command row for `npm run check:skills`.

## 8. Risks

- **A wrong lesson encoded.** Mitigation is the status field with provisional as the default for any lesson from one run (the 0.15 line, the 71% baseline, the Noul margin are all n=1 per inventory-1's own flags), the overturn row in the update table, and the retract-by-append rule. Residual: a lesson can be established and still wrong; only a new result moves it.
- **Skills nobody loads.** Body cap (150 warn/250 fail) in the check; every rule line points at a reference instead of carrying detail; description written as a trigger, tested with three prompts.
- **Trigger collision.** `reactive-model-loop` sits next to `jevify` (opportunity audit) and `typesafe-ai` (API and patterns) in this host's skill list; its description excludes both by name. `scrapkeep-lab` overlaps `scrapkeep-verify` on the word "gate"; the lab description says verification rows stay in verify.
- **Host drift.** Both hosts read `.agents/skills`; no `${CLAUDE_SKILL_DIR}` in bodies; symlink check in `check-skills`; Codex `$scrapkeep-lab` naming follows AI-WORKFLOW.md:15. `verify.py` at pstack still checks for exactly three skills per AI-WORKFLOW.md:42 (ASSERTED from that doc, not run); it may report the two new ones as unexpected until Andrew updates it, which the card's boundary excludes.
- **The cadence tradeoff read as "prior art is right".** The realtime side was never measured here; `cadence.md` presents it as a design choice with the determinism cost stated, and JL-31's "demo, not evidence" label is the applied rule.
- **Coordinator-correction facts.** The Noul result (failed the 0.2 margin in 0 of 6 orders while top-rated 18/18) and the JL-27 rule change (a coordinator ruling, not a writer error) must be written as corrected; inventory-2 §5 and open question 1 are wrong on both.

## Evidence

Files read this session (all under `/home/andrew/Projects/scrapkeep-wt-JL-coord/` unless noted): `BACKLOG.md:6123-6147` (JL-30), `TRACKING.md:853` (EV-0552), `artifacts/jev-lab-2026-09-25/skills/{inventory-1-decider,inventory-2-game-lab,inventory-3-coordination,prior-art-jev-games}.md` in full, `.agents/skills/{plan-session,scrapkeep-task,scrapkeep-verify}/SKILL.md`, `ORCHESTRATOR.md` headings, `CONTRIBUTING.md` command rows, `scripts/check-docs.mjs:1-60,715`, `scripts/check-scope.mjs:38,77,99`, `scripts/play.mjs:778,838,889`, `scripts/lab/harness.mjs:1-40`, `scripts/lab/gate.mjs:1-30`, `tools/jev-player/preflight.mjs:1-25`, `artifacts/jev-lab-2026-09-25/experiments/jl18c/PREREGISTRATION.md` headings and lines 202-210, `artifacts/jev-lab-2026-09-25/pins/ball-lab-suite/pin.json`, `tests/lab-dash.test.js:530-549`, `docs/project/AI-WORKFLOW.md:3,15,42,48`, `package.json:15-28`; `/home/andrew/.config/pstack/plugin/skills/{blast-radius,tdd,technical-writing,architect}/SKILL.md` and `architect/references/`.

Commands (exit 0 unless noted): `grep -n "### JL-30" -A 60 BACKLOG.md`; `grep -n "EV-0552" TRACKING.md`; `find … -printf` over the skills and inventory dirs; `cat` of the three SKILL.md; `grep -n "^#" ORCHESTRATOR.md`; `grep '"check:…' package.json`; `ls` of scripts, scripts/lab, tools/jev-player, artifacts tree, sketches; `sed -n 1,60p scripts/check-docs.mjs`; `grep -n "EV-\|cited" tests/lab-dash.test.js`; `printf CLAUDE_EFFORT` → `high`; `git rev-parse --short HEAD` → `fc65ebb`; `git branch --show-current` → `wt/JL-coord`. Two outputs were persisted to files by the harness for size (ORCHESTRATOR/CONTRIBUTING dump, CONTRIBUTING lab rows); I re-queried the parts I needed.

Not read: the reviews under `artifacts/jev-lab-2026-09-25/reviews/`, `PROTOCOL.md`, `decide.mjs`, the session transcript; every lesson citation above is carried from the inventories, so a writer implementing the ledgers must open each cited file and confirm the line before committing it (that is the check's limit in 4b too). The `verify.py` three-skill claim and the prior-art cost-control claims are ASSERTED (unverified).

No writes; no branch or SHA to report for a write.

Verdict: PASS+NOTES, evidence level 2 (design grounded in cited inventories and file inspection; nothing executed beyond lookups). Notes: the rigid-gate rate comparison and the RML→citation map need JL-28 and the ledger writer respectively; both are named as open in the design rather than resolved.

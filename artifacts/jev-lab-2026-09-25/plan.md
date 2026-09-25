# Jev Lab: automated player, Jev-assisted TDD loop and KPI/KRI feedback (program plan)

## Context

On 2026-09-25 Andrew asked for two things:
- a test-driven environment for the Godot sketches;
- an automated player built on TypeSafe's Jev, for "automated game development and UAT testing".

He then made this the formal main topic of the session. It is to be run as coordinated agents that split the work, with metrics (KPIs and KRIs) that tell the agents and Andrew how the mechanics, stability and the work itself are going: "the world's your oyster". He added that Jev should be a high-value part of the TDD loop itself, not just the player.

**Already on `main` at 9a7f7ae.** These were all made by an Opus 5 session, and are therefore audited below:
- `scripts/play.mjs` + `~/.local/bin/scrapkeep` (list, play, concurrent test, watch, shot)
- `tools/jev-player/decide.mjs`, `score.mjs`, `sweep.mjs`

**Missing:**
- Jev driving a live Godot run
- run records that can be compared across runs
- a regression gate (the baseline-vs-candidate "comparison loop", open since `docs/project/AGENT-PLAYTEST-ENGINEERING.md:9,23,79`)
- a dashboard
- Jev judgements inside the TDD loop
- metrics on the program itself

**Outcome:**
- `scrapkeep lab run <scenario> --arm random|scripted|jev -n N` plays headless trials.
- `scrapkeep stats` and `scrapkeep dash` show every metric and its trend.
- `scrapkeep gate` fails on a KRI breach.
- The loop is reviewed and qualified on ball-lab, then on Cable Bench and Spillway Drop via new `lab/*` branches.

**Andrew's decisions:**
- Scope: ball-lab first, then the stages on new `lab/*` branches; the gated `proto/*` branches stay untouched.
- Dashboard: a local HTML page plus the terminal.
- Jev cost is not a constraint.

**Boundaries:**
- Automated play never substitutes for Andrew's play (ORCHESTRATOR § Light play lane). Every report says "automated; not a feel verdict".
- No window ever opens on his workspace: work runs headless, or through `claude-open` on workspace 10.
- This session is a fork of `scrapkeep-1d`, which is idle. All edits happen in this session's own worktrees.

**Displaced commitment:** Andrew still hasn't played the three waiting sketches (PLAYTEST-LOG § Waiting for play). Nothing here replaces that.

## Audit of the Opus 5 work (41ab9f6, 7a3c159, 9c067de, 9a7f7ae, EV-0483)

Each finding below was verified read-only on 2026-09-25. JL-00 (Wave 0) formalises the audit, and each fix lands in the card that owns the file.

| # | Finding | Fix → card |
|---|---|---|
| A1 | The headline sweep claim ("price does nothing, threat proximity decides") rests on a second leading prompt. `decide.mjs:103` says "Scrap has no use other than buying caches", and `sweep.mjs:63` gives every cache as "~1 s". Together these make any affordable cache dominant by construction, and the prompt was edited until the control passed. | Retract the claim in the README and TRACKING (JL-03, EV-0485). Re-test it under a neutral question set with dominance controls, in live Cable Bench trials (JL-28). |
| A2 | The adversarial set is not blind. One author wrote the prompt, the corpus and the cases, and relabelled a case after seeing the output. `score.mjs:15-17` merges the authored and adversarial sets. | Isolated blind corpus (JL-04); blind and authored scored separately, with only blind scores gated (JL-03, JL-02). |
| A3 | EV-0483 carries a fabricated timestamp, `2026-09-25T00:00:00+00:00`. The change it records, `7a3c159`, was authored at 13:22Z. `9c067de` and `9a7f7ae` have no event at all. | A compensating event, EV-0485, after the audit. TRACKING is append-only. |
| A4 | `9c067de` and `9a7f7ae` are `tooling`-class changes with no card, no event and no review. `9a7f7ae` also has no `npm run verify` receipt. | JL-00 audit, plus the missing checks; the `prog.untracked_commits` KRI. |
| A5 | "62 s → 18.4 s" and "~260 s serial" were computed, not measured. | Real serial-vs-concurrent measurement (JL-06). |
| A6 | `CONFIDENCE_FLOOR` is described as "tuned against the corpus" on the strength of one data point (`decide.mjs:18`). | Relabel it as provisional (JL-03); calibrate it from live intent churn (JL-21). |
| A7 | The `greedy` noul is one-sided (`decide.mjs:121`). | Neutral question set q2 (JL-18). |
| A8 | `scrapkeep shot` opens a window on Andrew's workspace and writes to `/tmp` (`play.mjs:459-460`). | `claude-open` on workspace 10, output to `artifacts/local/shots/` (JL-06). |
| A9 | One flaky suite run in four, cause unknown. | Rerun-disagreement metric and a 20-run soak (JL-06); Jev failure triage (JL-19). |
| A10 | Pedantic, over-long prose in the jev-player README and in EV-0483. | Plain rewrite (JL-03, EV-0485). Commit messages stay as history. |

## Architecture

### 1. The prompt is part of the instrument (question sets, epochs, preflight)

- **Question sets are versioned files.**
  - Location: `tools/jev-player/questions/<version>.json`, containing `{version, status, intent, danger, greedy, rationale}`. `questions/INDEX.json` pins each file's hash.
  - A test fails if a published file is edited: new wording means a new file.
  - `q1-original.json` is today's text, verbatim, with status `retracted-leading`. It is kept only so old results remain comparable.
  - `decide.mjs` takes a question set and exports `GATE_VERSION` and `instrumentIdentity()`.
- **Instrument epoch.** Each distinct `questions_sha` starts a new epoch.
  - The sha goes into every verdict-cache key, every run record and every intent's `meta`.
  - Reports refuse to aggregate across mixed sha values or models, and trend lines break at epoch boundaries.
  - A new epoch is **invalid** until two things re-pass: the controls, and the blind corpus.
- **Preflight controls** (`controls/<version>.json`, `preflight.mjs`). These run live and never read from the cache. They run before any batch that includes the jev arm:

  | Control | Setup | Pass condition |
  |---|---|---|
  | free-cache | 0 scrap, no stopping cost | take the cache, P ≥ 0.6 |
  | lethal-option | 8 HP; an executable ram whose `why` states 25 contact damage | refuse the ram, P(ram) ≤ 0.2 |
  | wording-swap | same state, asked under neutral and current wording | same choice both times |

  - Every control also runs with the options in reverse order.
  - A failure aborts the batch with exit 6 before any Godot process spawns.
  - Thresholds are provisional and live in the versioned controls file.
- **Blind corpus** (`corpus-blind.json`):
  - It is labelled by an agent whose FORBIDDEN list includes `decide.mjs`, the README, all Jev output and the authored corpus. That agent's only inputs are the sketch READMEs, `tuning.gd` and the BIBLE.
  - Each case records `{labeller, date, inputs_seen, prompt_epoch}`.
  - Blind results reach the prompt author only as aggregate numbers.
  - A case the author sees is "burned" and moves to the authored set.
  - Only blind scores gate.

### 2. Godot ↔ Node lockstep over files (TADR-005: no sockets)

- **Input seam.** `src/jev/jev_agent.gd` extends `Intent.Source` and is installed as `player.source`, the same way `tests/mode_check.gd:10-24` does it. No physics code changes.
- **Runner.** `src/jev/jev_run.gd` extends `SceneTree`.
  - It deliberately lives outside `tests/`, because `sketch-smoke.mjs` runs every `tests/*.gd`.
  - It counts physics ticks. It is launched with `--fixed-fps 90`, so frames and ticks are 1:1 and runs go faster than real time.
  - It blocks inside its own `_physics_process` (`OS.delay_msec`) instead of setting `tree.paused`. That avoids Jolt's pause and unpause semantics.
- **Protocol v1.** One `<io>` directory per trial; each file has a single writer and is written as tmp-then-rename.
  - Godot writes `hello.json`, `state-NNNNNN.json` (a `jev:{state,options}` block, pre-quantised to the corpus schema, plus a `sim` block), `error.json`, `done.json` (with `trace_hash`) and `events.ndjson`.
  - Node writes `intent-NNNNNN.json` (`{intent, arm, source, meta}`; `questions_sha` is required for the jev arm) and `abort.json`.
- **Timing.**
  1. Snapshot every D = 90 ticks.
  2. Keep flying the held intent for k = 26 ticks (≈ 290 ms).
  3. Block until the intent arrives, then apply it.

  Timeouts:
  - Godot: 30 s, then `error{intent_timeout}` and exit 5.
  - Node watchdog: `max(30 s, 20× the median step)`, then SIGKILL and record `stall`.
  - An exit with no `done.json` is recorded as `crash`.

  Fixtures are shared: the canonical copy is in `tools/jev-player/protocol/fixtures/`, a byte-identical copy is in `sketches/ball-lab/src/jev/fixtures/`, and a drift test compares them.
- **Arms.** Three arms share the protocol: `random` (seeded) as the floor, `scripted` (a rule ladder) as the baseline, and `jev` as the candidate. A single offered option is `forced`, with no API call.
  - **Verdict cache:** key = `sha256({protocol, questions_sha, model, confidence_floor, gate_version, state, options})`.
  - **Replay:** `--replay` makes zero API calls; a cache miss is an error.
- **Steering at 90 Hz.** A shared `seek(point)` turns a world direction into stick input as `move = (d·B.x, −d·B.z)`, inverting `ball_rules.gd:48`. It adds brake-on-overshoot, aligned boost, jump edges and unstick.
  - `push_objective`: follow waypoints.
  - `hit_kicker`: run up and hold the heading in the air.
  - `stomp_target`: jump at `max(3, 0.7·v_h)` m.
  - `ram_target`: aim at a lead point.
  - `evade_hazard`: move perpendicular to the threat.

  Ball-lab offers push, kicker, stomp, ram and evade. It does not offer `retreat_regen`, because the sketch has no HP.
- **Ball-lab state is synthesised read-only.**
  - Threats: the nearest 3 enemies within 60 m.
  - `air_jump_available = air_actions > 0`.
  - Knocks: detected by a second listener on `player.shockwave` (strength 0.6 = stomp, 1.0 = ram).
  - Gameplay does not change.
- **Telemetry.** `telemetry.gd` writes `events.ndjson` plus a 10 Hz trace.
  - Tier changes, takeoffs and landings, knocks, stuck begin/end.
  - Anomalies: NaN, tunnelling (`y < Field.height − 0.5`), out of bounds, and speed over 80 m/s.
- **Determinism.**
  - Ball-lab's only RNG is the visual camera jitter (`chase_camera.gd:83`).
  - The stages hard-code their seeds (`cable-bench/src/stage.gd:56,91,109`; `spillway-drop/src/stage.gd:71`). The ports add `seed_override := -1`.
  - A replay-hash test runs for each physics mode. If rigid (Jolt) diverges, it is reported as stochastic.

### 3. Ball-lab UAT scenarios (`src/jev/scenarios.gd`, coordinates from `field.gd`)

The scenarios are `downhill-run`, `run-to-pad`, `bench-climb` (service ramp vs kicker), `kicker-gap@v` (14–28 m/s), `dummy-knock` (3 of 6; the stomp/ram split is a KPI), `pillar-weave` (4 gates) and `soak` (120 s on the random arm; KRIs only). JL-21 recalibrates the time limits to `max(initial, 2× scripted p90)`, sweeps the decision interval D ∈ {45, 90}, and sweeps latency k ∈ {0, 26, 54}.

### 4. Measurement: one record, one registry, one gate

- **Run record `scrapkeep-run/1`.**
  - Location: an exclusive `artifacts/local/runs/<ts>-<type>-<label>-<uuid8>/` directory, claimed by opening `run-owner.json` with `x`, as in `tools/agent-player/run.py:88-99`.
  - `run.json` holds:
    - identity: `type`, `result`;
    - `provenance`: git head, branch and dirty flag; source hashes at start and end, where a mismatch makes the run `inconclusive`; versions; an `instrument` block; the Jev model, calls, tokens and cache counts;
    - `config`;
    - `kpis` and `kris`, each as `{value, n, ci}`;
    - `findings`, each with a repro command;
    - `limits`.
  - `index.ndjson` is append-only and can be rebuilt.
- **Registry.**
  - Location: `scripts/lab/metrics/{core,program,human,tdd,ball-lab,cable-bench,spillway}.mjs`, merged by `index.mjs`, which rejects duplicates. It lives in `scripts/lab/` so the measurement layer stays no-build.
  - A single `STATUS` table owns each status's colour, glyph, ANSI code, gate effect and exit code, in Andrew's Neon Noir palette: green `#7fd9a0` ●, amber `#ffd166` ▲, red `#ef476f` ■, insufficient `#5e7a82` ○.
  - The writer throws on any metric id not in the registry.
  - A test fails if a hex colour or status word appears outside `STATUS`.
  - **Sentinel** metrics go red on a single occurrence.
  - Any metric below its `min_n` shows *insufficient*, never green.

| Layer | KPIs | KRIs |
|---|---|---|
| Mechanics | `lever_effect` (does the tuned knob change the choice? Stays insufficient until its epoch passes controls), `feel_drift` (against the build Andrew played, dc94b2c), stomp/ram split, route choice | `unreachable_scenarios`, `tunnel_nan`●, `stuck_per_trial` (amber > 0.2, red > 0.5), `dead_tier` (amber < 5%, red < 1% of time) |
| Agent | `corpus_blind_weighted` (gated; amber < 0.9, red < 0.8), `corpus_authored_weighted` (not gated), `margin_vs_scripted` (Newcombe CI), `tokens_per_decision` | `blind_severe_misses`●, `dominance_controls`●, `instrument_changed`●, `authored_blind_gap` (amber > 0.10, red > 0.20), `corpus_label_edits`●, `control_separation`, `intent_churn_min` (amber > 20, red > 40 per minute), `low_conf_rate`, `latency_p95_ms` (amber > 600, red > 1000), `api_error_rate`, `replay_repro`● |
| Stability | `suite_wall_s` (against the rolling median at the same `jobs`) | `suite_pass`●, `engine_crash`●, `flake_rate` (amber > 1%, red > 5%), `trial_abort_rate` |
| Pipeline | `jev_tokens_batch` (a runaway guard only) | `record_invalid`●, `evidence_age_d` (amber > 3, red > 7) |
| TDD (Jev) | `first_red_s`, `triage_agreement` | `untested_change`, `triage_misroute` (a regression called a flake counts as severe) |
| Program | `first_pass_review` (amber < 70%, red < 50%), `cycle_time_h`, `tokens_per_card` (from delegates.tsv plus the agent-to-card map) | `rework_per_card`, `blocked_cards`●, `escaped_defects`, `overclaim` (hooks threshold 0.77), `model_substitution`●, `untracked_commits`●, `event_time_skew` (amber > 1 h, red > 24 h) |
| Human | `agent_agreement` (does the bot flag what Andrew's verdict flags) | `unplayed_green` (gate-passing builds waiting for his play: amber > 2, red > 4) |

● = sentinel.

- **Gate** (`scripts/lab/gate.mjs`).
  - **Pinning:** `--pin <run_id> --as <name>` copies the run and its verdict cache to `artifacts/jev-lab-YYYY-MM-DD/`. A pin is only allowed for an epoch that has passed its controls and blind corpus. `andrew-anchor` is the pin for the build he played.
  - **Statistics:** Wilson intervals for rates, Newcombe for differences, tolerance 0.10. An interval that straddles the tolerance is *inconclusive*. p50/p95 use nearest rank, as in `report.py`. Replay results must match exactly.
  - **Exit codes:**

    | Code | Meaning |
    |---|---|
    | 0 | Pass |
    | 1 | A red KRI or a conclusive regression |
    | 2 | Usage error |
    | 3 | Inconclusive (too few samples, stale baseline, dirty tree, or blind set under 20) |
    | 4 | The instrument is invalid (a control failed, arms can't be separated, an invalid record, or a new epoch that hasn't re-passed) |
- **Output.**
  - **`scrapkeep stats`:** one line per metric, showing the glyph, value, n, change from the baseline, and the plain-English "says" line.
  - **`scrapkeep dash`:**
    - Written to `artifacts/local/dash/index.html`.
    - Inline SVG, no script, and a `default-src 'none'` CSP.
    - Contents, in order:
      1. "Waiting for Andrew" first.
      2. Per-layer tiles with sparklines.
      3. Scenario arms side by side.
      4. Trends with threshold bands and epoch rules.
      5. Blind and authored tiles side by side.
      6. Findings, wave retros and limits.
    - Verified with a headless Chromium screenshot.
- **Human verdict index.** `docs/playtests/verdicts.ndjson` holds `{build_sha, anchor, quote verbatim, tags}`. PLAYTEST-LOG stays the prose source.

### 5. Jev inside the TDD loop

Shared rules for all four:
- A typed Jev call decides; a deterministic rule is the fallback.
- Each is built test-first against a labelled corpus plus a blind set, with severity weights and a control.
- Results are cached.
- **Nothing on the gate path waits on Jev.** `gate` and `npm run verify` never depend on it.
- Input is logs and diffs only; key lookup and logging follow the hooks precedent (`jev-calls.tsv`).

| Card | Judgement → typed output | What it buys | Control |
|---|---|---|---|
| JL-19 failure triage | Why did the check fail? → Choice {timing_flake, real_regression, engine_crash, test_bug, infra}, plus a Noul: safe to rerun? | Explains the flake. A rerun counts toward `flake_rate` and never silently turns red into green. | An injected `assert(false)` must come back `real_regression`. |
| JL-23 watch ordering | Which checks will this save break? → Score per test | First red in about 8 s instead of a whole sketch run. It reorders only; it never skips. | A test that imports the changed file must outrank one that doesn't. |
| JL-24 coverage gap | Is this change exercised by any test? → Noul per test | The `untested_change` KRI, meaning "write the failing test first". | A file with no test at all must be flagged. |
| JL-20 verdict tagging | What did Andrew's playtest say? → Noul per tag | Fills the verdict tags; powers `agent_agreement`. | PLAYTEST-LOG entries 1–2 hand-labelled. |

## Program: card family JL, heavy lane, small chained waves

### Governance

The rules come from ORCHESTRATOR.md, check-scope.mjs and scrapkeep-task.
- **Lane.** Every JL card runs in the heavy lane, including sketch and `lab/*` cards, because nobody plays instrumentation.
- **Per card:**
  - a BACKLOG entry in TL-02 form (BACKLOG.md:4071);
  - a worktree created with `scripts/new-worktree.sh <id> <40-hex base>`;
  - a GOAL…REPORT packet;
  - an expanded attempt record plus an event before dispatch;
  - `check:scope` receipts under `artifacts/local/tasks/JL-NN/`;
  - a fresh independent reviewer;
  - serial integration by the coordinator.
- **Separation.** No card mixes `tools/` with `sketches/`, and `lab/*` never merges into `proto/*`.
- **Limits.** At most 4 writers and 2 reviewers at a time. Fable reviews run one at a time, because of past 429s.
- **Dropped:** the earlier idea of a no-build scope class for this program. A program should not relax its own verification.

### Agents

These are the project definitions. Wave 0 remaps the Opus 5 pins to Opus 5.5, per Andrew.
- `scrapkeep-writer` (Opus 5.5): judgement cards.
- `scrapkeep-writer-low` (Sonnet 5): fully specified cards.
- `scrapkeep-reviewer-medium` (Opus 5.5): routine review.
- `scrapkeep-reviewer` (Fable 5.1): consequential review. If a probe finds Fable unavailable, `gpt-6-astra` via `codex:codex-rescue` takes over, per ORCHESTRATOR.md:34.

### Wave 0 (coordinator; the audit uses a reviewer slot)

1. `EnterWorktree` for this session, verifying the base is at `9a7f7ae`.
2. Message `scrapkeep-1d`: the program is claimed, so leave jev-player, `play.mjs` and `scripts/lab/` alone.
3. Remap `model:` in `.claude/agents/scrapkeep-writer.md` and `scrapkeep-reviewer-medium.md` from `claude-opus-5` to `claude-opus-5-5`. This is configuration class: `check:docs` plus a scenario review.
4. Probe Fable with one small spawn.
5. Record EV-0484, program authorization. It carries:
   - Andrew's quote;
   - the JL scope and heavy lane;
   - the `lab/*` rules;
   - permission for Jev use, with a runaway-guard token cap.
6. **JL-00 audit.** A Fable reviewer covers the four commits and EV-0483. It produces:
   - a claims ledger marking each claim verified, unverified or retracted;
   - the corpus label-edit history from `git log -p`;
   - findings against the instrument.

   Output goes to `artifacts/jev-lab-2026-09-25/audit/README.md`, which is retained.
7. Record EV-0485: the A3 correction with the real time, the A1 retraction, and the A4 reconciliation.
8. Add the JL cards to BACKLOG, add task-index rows, and add a "Jev lab" method row to `.agents/skills/scrapkeep-verify/SKILL.md`.

### Waves

| Wave | Cards (disjoint files) · writer → reviewer |
|---|---|
| 1 | **JL-01** run record and index (`scripts/lab/record.mjs`) Opus → Fable · **JL-02** registry and stats math (`scripts/lab/metrics/*`) Opus → Fable · **JL-03** question sets extracted (`questions/`, q1 pinned as retracted, `instrumentIdentity`, score splits blind from authored, README retraction plus A6/A10) Opus → Fable · **JL-04** blind corpus (isolated) Opus → medium |
| 2 | **JL-05** protocol v1, `PROTOCOL.md`, `protocol.mjs`, fixtures Opus → Fable · **JL-06** `play.mjs` emits run/1, `--repeat`, 20-run soak, real serial vs concurrent timing, A8 shot fix Sonnet → medium · **JL-07** `verdicts.ndjson` plus backfill Sonnet → medium · **JL-08** program collector (`delegates.tsv`, agent map, wave retro) Opus → medium |
| 3 | **JL-09** `jev_io.gd` plus the fixture copy Sonnet → medium · **JL-10** `jev_state.gd` and `scenarios.gd`, read-only and identical with export on or off Opus → medium · **JL-11** `harness.mjs` and `arms.mjs` against a fake Godot Opus → medium · **JL-12** gate and pinning Opus → Fable |
| 4 | **JL-13** `jev_agent.gd` steering plus `telemetry.gd` Opus → medium · **JL-14** verdict cache, jev arm, `--replay` (owns `harness.mjs`) Opus → medium · **JL-15** `preflight.mjs` and `controls/c1.json` as a module with an injected `decideFn` Opus → Fable · **JL-16** `scripts/lab/model.mjs`, `stats`, verb routing in `play.mjs` Opus → medium |
| 5 | **JL-17** `jev_run.gd` plus the bridge test (applied at exactly t+k; `trace_hash` identical with random responder delays) Opus → Fable · **JL-18** neutral question set q2, wires preflight into the harness, must pass the controls and the blind corpus Opus → Fable · **JL-19** failure triage Opus → medium · **JL-20** verdict tagging Sonnet → medium |
| 6 | **JL-21** integration: every scenario × arm, calibration of limits, `requires_speed_ms`, `CONFIDENCE_FLOOR`, D and k Opus → medium · **JL-22** dashboard plus screenshot Opus → medium · **JL-23** watch ordering, also wires triage into `play.mjs` Opus → medium · **JL-24** coverage gap Opus → medium |
| 7 | **JL-25** qualification. Pin a baseline, then check that each change produces the expected exit code:<br>• inject a bounded regression → 1<br>• remove it → 0<br>• break a control → 4<br>• change the prompt → 4 until it re-passes<br>Coordinator → Fable.<br>**JL-26** `lab/cable-bench` from `29dcbcf`, and **JL-27** `lab/spillway-drop` from `af89c89`. Each gets adapters, `seed_override` and stage metrics; the existing stage tests stay unchanged. Opus → medium |
| 8 | **JL-28** live experiments: every arm × scenario on all three sketches, plus the **cache-finding re-test** under the q2 epoch with dominance cells. The coordinator runs them and Fable judges the conclusions.<br>**JL-29** close: retain runs under `artifacts/jev-lab-2026-09-DD/`, update docs (CONTRIBUTING, READMEs, scrapkeep-verify), close out TRACKING, write the final retro, and get a Fable integrated read. |

### Self-feedback after every wave

After each wave, the coordinator:
- updates the agent-to-card map;
- runs `scrapkeep stats --layer program` (computed by hand until JL-08 lands);
- writes a five-line retro to `artifacts/local/runs/program/wave-N.md`;
- summarises the retro in the wave-close TRACKING event.

The retro changes the next wave's briefs:

| Signal | Change to the next wave |
|---|---|
| First-pass review < 70% | Copy the failed criteria into the briefs as "known traps" and halve the card size |
| A Sonnet card needed rework | Move cards of that kind to Opus |
| Tokens per card > +50% | Tighten the briefs and pre-cite the relevant lines |
| `model_substitution` red | Stop and report |
| An escaped defect | A regression-test card comes before any new work |
| `untracked_commits` or `event_time_skew` red | A board-repair card comes first |

## Reuse, don't reinvent

- **Input seam:** `sketches/ball-lab/src/intent.gd` and `tests/mode_check.gd:10-24`.
- **State and coordinates:** `src/{lab,player_ball,field,ball_state,ball_rules}.gd`.
- **Test running:** `scripts/sketch-smoke.mjs` (binary, `sketchDirectories`, `testScripts`) and `scripts/play.mjs` (verbs, `runHeadless`, `inPool`, failure logs).
- **Decision gating:** `tools/jev-player/decide.mjs` (the gate, the confidence floor, the decide shape).
- **Evidence:** `tools/agent-player/run.py:88-99`, `evidence.py:11-36` and `report.py` (exclusive output directories, hash provenance, NDJSON, percentiles).
- **Report envelopes:** `scripts/verify.mjs` and `check-docs.mjs`.
- **Governance:** `scripts/check-scope.mjs`, `scripts/new-worktree.sh`, ORCHESTRATOR.md and `.agents/skills/scrapkeep-task/SKILL.md`.
- **Program metrics:** `~/.claude/state/delegates.tsv` and `hooks/bin/delegates-report.sh`.
- **Palette:** `~/.config/omarchy/themes/neon-noir/colors.toml`.

## Verification (end to end)

1. **Every card:** run `npm run check:scope -- <base> <candidate>` and every command it prints.
   - Sketch cards also run their headless test and `npm run sketch:smoke`.
   - Tooling cards run `npm test && npm run verify`.
   - Receipts go under `artifacts/local/tasks/JL-NN/`.
   - A fresh reviewer returns PASS or FAIL.
2. **Protocol:** both sides validate every fixture. The bridge applies each intent at exactly t+k, and `trace_hash` is identical when responder delays are injected.
3. **Loop:**
   - `scrapkeep lab run downhill-run --arm scripted -n 20` succeeds.
   - The random arm scores measurably worse (`control_separation` green).
   - A jev batch passes preflight, and `--replay` of it makes zero API calls with a matching `trace_hash`.
4. **Instrument:**
   - Both controls pass, with the options in both orders.
   - The blind corpus has 0 severe misses.
   - Editing a question set fails the pin test.
   - A new epoch holds exit 4 until the controls and the blind corpus pass again.
5. **Gate qualification (JL-25):** exit codes 1 → 0 → 4 → 4, as specified.
6. **Dashboard:** the screenshot is non-trivial, every registry id appears exactly once, and no colour appears outside `STATUS`.
7. **Stages:** the `lab/*` tests pass unchanged, and the `proto/*` heads are byte-identical before and after.
8. **Program:**
   - A TRACKING event for every wave.
   - Wave retros written.
   - `untracked_commits` = 0 and `model_substitution` = 0.
   - Each commit ends with the current attribution (Opus 5.5).

## Needs Andrew's hands (one checklist at the end; never blocks a wave)

1. Play the three waiting sketches: `scrapkeep mobility`, `scrapkeep spillway` and `scrapkeep cable`. This is still the project's real blocker.
2. If the Wave 0 probe shows Fable is unavailable, choose between restoring credit and keeping the astra fallback.
3. Push the local commits to GitHub when you're ready. Pushing needs your go.

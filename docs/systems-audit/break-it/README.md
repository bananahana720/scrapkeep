# Systems Audit Pass F — Break It (World 1)

Adversarial break-it audit for World 1 graded against [`BUG-BAR.md`](../../../sketches/core-loop/BUG-BAR.md) and BIBLE section 6 persistence promises (reload never duplicates a reward, refills a spent death save, or resurrects a dead run).

## 1. Automated break-it harness (`aa5c74047`)

Two new headless artifacts run alongside [`break_run.gd`](../../../sketches/core-loop/tools/sysaudit/break_run.gd):

- Probe: [`sketches/core-loop/tools/sysaudit/break_it_probe.gd`](../../../sketches/core-loop/tools/sysaudit/break_it_probe.gd)
- Regression test: [`sketches/core-loop/tests/sysaudit_break_it_test.gd`](../../../sketches/core-loop/tests/sysaudit_break_it_test.gd)

### Live suite results (`seed=2881`, `suite=all`)

| Suite | Adversarial Scenario | Measured Result (`aa5c74047`) | Verdict |
| --- | --- | --- | --- |
| `spam` | 180 physics ticks of simultaneous random button presses, stick spins, and 8 mid-action pause/unpause toggles | `peak_speed=58.3 m/s`, `state=stage`, `0` NaN/OOB/speed/currency faults, unpaused & responsive | **PASS** |
| `save_resume` | Mid-run earnings (`135` cogs, `heavy_bearings` part, `death_save_spent=true`, `50%` hull) saved at cleared stage, process torn down, resumed via `flow.resume_run()`, then killed with fatal damage | Resumed cleanly into Stage 2 with exact `135` cogs, `1` part, `death_save_spent=true` (never refilled); death cleared `saved_run()` (`terminal_cleared=true`) | **PASS** |
| `stack` | 12 rolled parts + active trade curse + `StageModifier` (`far_haul`) + `12%` low hull across 90 ticks, followed by fatal damage | `cursed=true`, `0` invariant faults, fatal hit kills cleanly (`fatal_ok=true`, never unkillable) | **PASS** |
| `sequence` | Unseal beacon -> open reward gates -> double-cross gate 0 + 5x rapid pause menu open/close | Gates closed immediately on first claim (`gate_parts_gained=1`, `cogs_delta=0`), `0` pause softlocks | **PASS** |

`sysaudit_break_it_test.gd` pins all four suites in CI (`18 / 18` checks PASS, `0` script errors).

## 2. Issue & severity ledger (`BUG-BAR.md`)

| Row | Issue | Repro | Severity | Fix / Owner | Verified |
| --- | --- | --- | --- | --- | --- |
| `SA-F1` | Quit/crash after clearing a stage before entering the next replayed the cleared stage | `break_run.gd --break=quit` seeds `2882`, `2883` | Blocker (closed) | PR 790 (`flow.gd` cleared-stage checkpoint); pinned by `sysaudit_break_it_test.gd` `save_resume` | **Yes** (`continue` advances to Stage 2 with exact cogs/parts and `death_save_spent=true`) |
| `SA-F2` | `play_watch.gd` logged Sable's mounted pylon as `hung` | Seed `2880` | Minor (closed) | `play_watch.gd` excludes mounted pylon; pinned by `tests/play_watch_test.gd` | **Yes** |
| `SA-F3` | Single `stuck` row fighting a plated brute in the flume | Seed `2877` | Minor (watch) | Red-team sweep watch; becomes a finding on repeat in two sweeps or 3x on one stage | Watch |
| `SA-F4` | Quitting during a rendered comic launch swipe untested headless | Rendered build quit during launch swipe | Coverage gap | PC rendered lane (formal run-flow / launch-swipe model checked by `scrapkeep-verify-formal`) | Pending PC rendered check |
| `SA-F5` | Quitting while gates are still open replays cleared stage from entrance by design (prevents double loot) | Seed `2884 --quit-in=gates:3` | Minor (deferred) | Post-sitting follow-up if players quit at open gates | By design (no double loot) |

**Blocker / Major breaks open on `aa5c74047`:** `0`.

## 3. Sprint-close gate note

Per [`BACKLOG.md`](../../../BACKLOG.md#sa-f), [`ORCHESTRATOR.md`](../../../ORCHESTRATOR.md) owns the tiered gate. Any newly discovered high/blocker break or dominant infinite-resource strategy from `break_it_probe.gd` or `sysaudit_break_it_test.gd` reopens the sprint until pinned by a regression test.

## 4. Replay commands

```bash
HOME="$PWD/artifacts/local/home-sysaudit" "$GODOT_BIN" --headless --fixed-fps 90 \
  --path sketches/core-loop -s res://tools/sysaudit/break_it_probe.gd -- \
  --seed=2881 --suite=all \
  --out="$PWD/artifacts/local/sysaudit/break-it-2881.json"

HOME="$PWD/artifacts/local/home-sysaudit" "$GODOT_BIN" --headless --fixed-fps 90 \
  --path sketches/core-loop -s res://tests/sysaudit_break_it_test.gd
```

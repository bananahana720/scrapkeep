# Repository audit, 12 September 2026

Read-only state audit at main `30d6b72`. Historical evidence for card AR-08 (BACKLOG.md#ar-08); it grants no task completion or authorization.

- `checks.log`: output of `npm run verify`, `check:docs`, `check:project`, `check:scope` (usage error, needs args), `npm test`. All pass; 211 tests.
- `git-hygiene.sh`: rerunnable snapshot of branch/worktree/weight state. Run `bash git-hygiene.sh`.

## Findings

Execution board: zero tasks in progress; AR-01..07 done; HF 5/14 done; HF-03b ready, undispatched; 49 questions open. No proposal awaiting Andrew.

Stale records contradicting current state:
- TRACKING.md:502-504 checkpoint says AR-01/02 in progress (all done per :187-193).
- TRACKING.md:15 names a gone coordinator session (EV-0093); :327 cites ORCHESTRATOR rev 2 (file is rev 3).
- docs/project/README.md:5 and BACKLOG.md:3 "Updated 6 September"; omit HF-03a/04a/05, AR wave, event archive. BACKLOG.md:32 "Proposed first sprint".
- ORCHESTRATOR.md:3,150 describe Sprint 0 as current and HF authorization as awaiting review.
- adr/README.md:43 says per-system pages not produced; docs/tech/sections has five.
- docs/RUNTIME-BLUEPRINT.md and docs/PLANNING-PREP-SWARM.md lack historical banners and carry live-sounding stale claims (:3-12, :32).
- docs/project/HOUSEKEEPING.md:40, ASSETS.md:15 link frozen docs/project/BACKLOG.md as live.

Disk and worktrees:
- 9 worktrees, all integrated (7 AR branches merged; HF-04a/HF-05 single files byte-identical in main). .claude/worktrees 1.4 GB, two external wt dirs 174 MB each.
- AR-01/02 used .claude/worktrees instead of the scripted ../scrapkeep-wt-<id> path.
- artifacts/visual-iterations/{game,world}-v1.js unreferenced, against artifacts/README.md:5. Root artifacts 07-mobile-upgrade.png, browser-regression.png, stress-scene.png, balance-log.txt unreferenced by owning docs. 30+ docs/bible/production/*.json unreferenced. 10 artifact record dirs lack README.

Tooling gaps:
- `npm run check:godot` named (CONTRIBUTING.md:40, check-scope.mjs:43) but absent.
- npm test shells to git in three suites; native-smoke.test.js writes tests/fixtures/native-smoke/derived/.
- verify.mjs hashes neither native/ nor tools/; native:smoke not a stage.
- agent-playtest.mjs falls back to system python3 (bundled interpreter absent).
- sprint-close.mjs has no npm alias; test:balance == probe:balance, no assertions.
- Engine pin 4.7.2 in native-smoke.mjs:21 only; project.godot tags 4.7.

Code: ownership split in src/orchard clean; zero TODO; no orphan modules; render/UI modules untested except via browser runners.

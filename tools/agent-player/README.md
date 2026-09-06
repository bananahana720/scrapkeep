# Native orchard player

Run a bounded game playtest in an independent Linux desktop:

```sh
npm run playtest:agent -- --trials 3 --max-seconds 300
```

The command builds a private production copy, serves it on a temporary loopback port, opens `/orchard.html` in the dedicated `playtest` desktop, handles visible menus, and plays with native keyboard/mouse input. It closes its desktop and server when finished. Andrew can keep using the host mouse and keyboard. The `game` and `studio` workspaces remain available for interactive work.

This requires the installed [desktop controller](/home/andrew/.local/share/codex-native-input/agent-desktop/README.md), nested Hyprland, Chromium, grim, and Python with NumPy and Pillow. The launcher uses Codex's bundled Python when present; `CODEX_PLAYER_PYTHON` selects another existing interpreter. It imports the installed input controller, not a copied implementation. No API key or paid service is used.

## Commands

```sh
# Short native play, reward handling if reached, pause and resume.
npm run playtest:agent -- --smoke-seconds 12 --pause-check --max-seconds 70

# Exercise ordinary defeat and restart by deliberately making no attacks.
npm run playtest:agent -- --profile passive --restart-check --max-seconds 120

# Prefer different available rewards; choices use exact visible button names.
npm run playtest:agent -- --rewards brace-package,shear-package,ground-loop,echo

# Independent concurrent player, when there is a concrete need.
npm run playtest:agent -- --workspace playtest-second --trials 1

# Controller-free failure, flow and evidence checks.
npm run test:agent
```

`--output` chooses a new or empty evidence directory. The default is `artifacts/local/agent-playtests/<timestamp>-<workspace>-<unique-id>/`. Each invocation records its configuration and reserves its output directory exclusively, so concurrent agents cannot overwrite each other’s evidence. `--max-seconds` limits a trial; bounded capture, menu reads and cleanup can extend wall time slightly. Startup/build have separate timeouts. Between completed trials, the player uses the actual **Start a fresh run** control, unless an explicit restart probe already opened the next run. A new terminal outcome requires a positive observation of play within the current trial. It never stages a result through game QA hooks.

**Stop:** press **Super+Ctrl+Shift+F12**, run `codex-desktop stop`, or interrupt the command with Ctrl-C. The shared emergency stop applies to all managed agent desktops. Resume managed controls with `codex-desktop resume`. A stop is recorded as a stopped run, never a win or loss.

The player claims a lease before touching its workspace and holds the operation lock through input release. Another owner is refused. The historical disposable player bypasses this ownership contract and must not be used in a managed workspace. These desktops share the Unix account, filesystem and session services; they provide independent input and focus, not VM isolation.

## Evidence and interpretation

The [6 September qualification](../../artifacts/agent-player-2026-09-06/README.md) records passed control/flow checks, earlier unattended clears and the latest visual timeouts. The runner is operational; reliable full clears remain unfinished.

- `report.md` summarizes outcomes, requested checks, action counts and measured pipeline timings. `report.json` records exact source/controller/build SHA-256 values, runtime versions, desktop identity and configuration. A source change during execution fails acceptance.
- Each `trial-NNN/` contains `result.json`, semantic UI observations, `events.ndjson`, periodic screenshots and terminal/check captures. Native intent records contain held keys/buttons and look velocity; semantic records contain the selected control and action. Helper taps are separate from combat intent counts.
- A pass means the configured trial reached an accepted outcome and all requested checks passed. **Loss is a valid terminal outcome**, not proof that the player is good. A smoke pass establishes a bounded control path, not a full clear.
- Combat uses rendered pixels. Menus use exposed accessibility roles, names and capabilities. No DOM evaluation, hidden simulation state, QA fixture, health edit, or deterministic seed is used.
- Action logs support inspection and comparable reruns; they are not a deterministic replay or video. Fresh-frame age and input-tick intervals are local pipeline measurements, not model API or complete display latency. Policy active time is not the game's displayed completion time.

The visual policy is a repeatable test strategy: warm eye tracking, spacing, strafing and timed abilities. Lost-target recovery corrects upward framing, scans vertically and uses brief lateral/backward movement with yaw held steady. Its approximate 1.5-second disengagement survives a transient detection; stale frames still release all input. The passive policy exercises failure. Neither is a validated novice, ordinary, or expert human profile. The detector can miss occluded faces or merge them with machine bodies, and scenery can contain the same decorative face. There is no obstacle map; completed and timed-out runs are retained separately. Default Ground Loop and Echo rewards auto-equip. Ambiguous equipment checkboxes are not guessed; arbitrary equipment editing remains outside this runner.

The dialog cue is qualified for the controller's 1280×900 viewport and current orchard UI. It releases gameplay input before a semantic state read; pixels alone never establish victory or defeat. Unknown/ambiguous UI, missing or stale frames, focus loss, emergency stop and controller failure end the trial with a failure reason. Authority expires after 500 ms without a fresh frame; the input loop releases before waiting for capture cleanup.

## Maintained boundaries

| Module | Responsibility |
| --- | --- |
| `desktop.py` | Installed controller adapter, lease, exact child identity, lifecycle, semantic actions and screenshots |
| `observer.py`, `vision.py` | Independent screenshot processing, menu stop cue and worker-face detection |
| `policy.py`, `combat.py` | Persistent combat clock, bounded intentions, input cadence and release paths |
| `flow.py` | Positive screen-state classification and unique visible menu choices |
| `run.py` | Private build/server, trials, outcome checks and cleanup |
| `evidence.py`, `report.py` | Bounded image writing, action records, provenance and readable results |

Keep the ordinary game unchanged while comparing player strategies. Run `npm run test:agent` and the project's `npm run verify` after a completed runner change. Native checks are explicit and require the local desktop; `npm run verify` alone does not establish them. Retain only needed evidence under the [artifact policy](../../artifacts/README.md). The [engineering plan](../../docs/project/AGENT-PLAYTEST-ENGINEERING.md) owns remaining work.

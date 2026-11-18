# W1-144a refresh for Gate review

PR #1152 merged stage c9d55d7c7f41910b9ae9e4f3bd6023f610779fc2 at 78009daa1647139856ed180148e3bbd393cadf23. The final head, 35fe9cc23b8dbb457b1d8a5ec59db2db6ea45aa4, corrects the Mac capture instructions in the probe header. The merge brings in #1129, #1133 and #1139. The PR changes one JavaScript file against this stage.

| Check on the final head | Result |
| --- | --- |
| Probe input suite from the parent directory | 18 expected outcomes, including independent 50 ms time series faults at the two handovers and invalid clock and shutdown evidence |
| Existing frame-time Node suite | 20 passed |
| Mac launcher rejection control | Both entry points refused an unknown or changed tool before starting Godot |
| Real headless event controls with the stage sketch imported into the PR worktree | Control and planted ride each exited 0. The two 50 ms sleeps consumed 55.017 and 55.015 ms. The captured call durations describe forced transitions during a headless test. |
| Archived drawn shutdown logs read by the refreshed probe | Both logs failed as expected on four renderer lines. These inputs came from the November 17 runs. |
| Rivet warm-hitch guard | Passed with Fin.L and Fin.R skipped |
| Fast check against origin/stage/alpha-w44 | Passed. Selected zero Godot tests for this JavaScript diff. |

The original control fixtures and replay steps are in the parent evidence directory. The Rivet and fast receipts record the checked head. All game launches in this refresh used scratch homes and the headless engine. The card's warm drawn timing, live drawn plant, current-stage renderer teardown and cause-specific stage checks remain open. The registered off-screen tool on this stage is the dam image probe. The W1-144 handover tool still needs qualification.

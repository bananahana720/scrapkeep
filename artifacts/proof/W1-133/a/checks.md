# Headless checks for W1-133a

Producer `2df78cdb1` on stage base `1d5d77fc6`. Godot 4.7.2.stable.official.ed1daf0bf, headless, with isolated scratch homes. The only later change on `a73195d62` gives the test receipt a unique filename without reading the clock. The four changed files contain the lab, its test and documentation, and the five station definitions.

7 named tests passed, with 0 skipped and 0 missing verdicts. The changed matchup regression passed again at the final head. The per-PR fast check at `a73195d62` passed in 103 seconds.

| Focused check | Result |
| --- | --- |
| import | PASS (1.8 s) |
| body_run_warning_test.gd | PASS (8.2 s) |
| attack_budget_test.gd | PASS (119.1 s) |
| chaser_speed_test.gd | PASS (45.8 s) |
| lobber_cover_test.gd | PASS (19.3 s) |
| matchup_lab_test.gd | PASS (229.4 s) |
| pocket_entry_test.gd | PASS (366.9 s) |
| telegraph_timing_pack_test.gd | PASS (262.9 s) |

The test runner recorded two untracked Godot import sidecars for existing tests in its dirty-path list. They are outside the four-file pull request. The macOS workers also printed the headless renderer shutdown messages documented in `project-guide/handoff/DEVICES.md`.

The focused and fast JSON files preserve the command receipts with host paths shortened. Each includes a SHA256 for its original file.

A separate staged winch pack ran all six one-seed passes. The winch drone registered two threats and the stopped rider lost 40 hull on each nominal speed. Straight and weaving riders lost zero hull. The staged fallback pack is excluded from the shipped pack totals.

The `warden-fairness`, `novice-deaths` and `difficulty` rows were read without `--sitting` and reported `not run` at sitting cadence.

Independent producer source review by GPT-6.2 Astra at high effort passed at `a73195d62` and verified the baseline at its original head. The Gate’s Claude admission review is pending.

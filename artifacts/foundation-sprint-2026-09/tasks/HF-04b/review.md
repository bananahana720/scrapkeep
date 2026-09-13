# HF-04b-A1 independent review

Reviewer: fresh scrapkeep-reviewer (claude-fable-5-1, effort high pinned by agent definition; CLAUDE_EFFORT not exposed to the read-only agent). Reviewed identity: worktree /home/andrew/Projects/scrapkeep-wt-HF-04b, branch wt/HF-04b, head 691a878ebc176e99a2fb64c3d44437a5242b4d7c, base d98803c555bedcd3d68e5d82efafb1a2d0bcf31b. Verbatim report follows.

---

**Verdict: PASS+NOTES.** Evidence level 3 (citations walked line by line against the admitted sources) for DoD 1–3 and checks 2–4; level 2 for headings, marker text and owner naming; level 4 wherever noted below (hashes, git-log pins, scope/docs/project exit codes, single-file diff).

**Blocking findings.** None.

**DoD, item by item.**

1. Four patterns named with a "Do not use it for" column, `HF-04b-runtime-patterns.md:25-28`; time/tick ownership and event ordering, lines 30-43. Each HF-04a citation in those rows resolves: C-TICK `HF-04a-runtime-lifecycle.md:34`, P0-P6 `:61-67`, `h` `:22`, F-classes `:44-51`, line 57 partial-results rule, O1-O4 `:87-90`, latching `:92`, paused delivery `:53`, interpolation `:79`, steps `:108-113`, overload `:98-102`. Met.
2. Inline sketches replaced by X1-X4 (lines 49-54) with the required file allocation: `encounter_coordinator.gd` for X1/X2, `session_owner.gd`+`input_adapter.gd`+`menu_probe.gd` for X3, `intruder.gd` with phase B for X4. Source commit stated once for all seven (line 13, line 47) rather than per row; acceptable. Three non-proof statements verbatim at line 56. Exact marker text at lines 80 and 85. Reconciliation table lines 62-74 plus sketch walk at line 141. S0-04 trigger recorded satisfied, no native execution, line 76. Met.
3. Owner per pattern in the catalogue column (lines 25-28) and the owner summary (lines 147-150), using HF-03a's module names (`HF-03a-module-map.md:31-37`) and record names from that table. Met.

**Citation sampling (all four examples, level 3).** Every cited line resolved: `proof_runner.gd:59,60` (X1), `:72-74` (X4), `:88,125` (X2), `:102-104,120,125,126` (X3); `encounter_coordinator.gd:18-19,30-36,39-43,46-54,57-62`; `encounter_state.gd:10-15`; `input_adapter.gd:27-33,36-39,42-46`; `session_owner.gd:18-24,26-29,34,41-44`; `menu_probe.gd:6-7,10-11`; `intruder.gd:14-17,24-28,31-33,36-42`; run receipt lines 1,3-18 and fault receipt lines 1,4-18 (`B FAIL` at 7, `E FAIL` at 16, `failures 2`/`exit_code 1` at 17, `direct exit=1` at 18); twelve PASS lines counted in the run receipt. Reconciliation rows cite `HF-04a:22,36,53,61-67,79,87-89,92,94,102,108-113,119-121,195`, `HF-03a:56` and M01 — all resolve to the stated content. Sources block: TADR-002 `:24-34` and TADR-001 `:23,27` match; `native/project.godot:11-16` has the six `=2` keys; `native-smoke.mjs:264-286,297-312,314-333` match; `docs/tech/native-toolchain.md` and the BACKLOG anchors (`HF-03b:272`, `HF-07a:468`, `HF-07b:499`, `Q-E01:2628`, `Q-E03:2642`, `Q-P16:3006`) exist.

**Check 4 (no proof default substituted).** Rows at lines 64-67 explicitly decline the 60 Hz placeholder, the deferred cancel drain, bare pause and the `_in_phase` guard; line 43 and line 169 route `h` to Q-E03. The sketch (lines 84-139) follows HF-04a steps 1-6 in order with O4 last and uses only HF-03a commands plus disclosed placeholders (line 82). Sketch is fully typed, no `:=`, no `class_name`/autoload choice (line 171).

**Check 5 (boundary).** Line 5, 76 and 195 disclaim execution. Single changed file and clean tracked tree rest on `verification.json:8-10` (level 4). No text in the section redefines an HF-04a or HF-03a rule; it only cites them.

**Check 6 (check_patterns.py coverage).** `check_patterns.py` checks headings (169-170), file presence and sha256 (173-181), git-log single-commit pin for the seven scripts (183-188), 83 exact-substring line citations (42-126, 191-197), exactly one fence with the marker as first line and in preceding prose (199-221), regex-typed `var`/`func`/`for`/params (222-238), owner rows (240-244), the three non-proof sentences (246-247), trigger phrases (256-257). Its printed `limits` string (277) is accurate. The 163/0 result is a coordinator receipt (`patterns.log:1`, `patterns-report.json:9-12`; level 4).

**Accepted notes (none violates the DoD).**

- `HF-04b-runtime-patterns.md:82` says the ctx7 receipt documents "loop-variable" types. Searching the ctx7 receipt for `for \w+\s*:`, "loop variable" or "iterator" returned nothing (empty result). The typed `for` form is instead evidenced by the admitted scripts that ran under the error-level keys (`encounter_coordinator.gd:47`, `input_adapter.gd:29`, `proof_runner.gd:43,130`). Recommend re-attributing that one clause; line 9's own list of what the receipt covers is correct.
- Line 67: "X1 and X4 support rejection of out-of-phase callers." Only X4's assertion (`proof_runner.gd:72`) exercises `advance_external`; X1 (`:59-60`) cites lines 30-36 as source only. Overstates X1.
- Line 52, "changed nothing until the owner's next step," is a source reading (`encounter_coordinator.gd:18-19`), not something `check` line 88 asserts, under a column headed "Behavior the assertions establish."
- Line 191 says the script checks "every cited … receipt line"; `CITED_LINES` omits fault lines 4-5 and 10-14, which lines 51 and 53 cite as passing. I confirmed those manually (`S0-04-int-proof-fault.txt:4-5,10-15` all PASS).
- `check_patterns.py:240-244` passes an owner row if any module name appears anywhere in it, including the "Do not use it for" column; the manual read above is what establishes the owner column.
- Line 27 lists "CollisionQueries contact observations" among result-signal producers; HF-03a:33 has CollisionQueries publish only on Encounter's request and HF-04a:49 has it retain observations. Not a contradiction, but loose (inference).

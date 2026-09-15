# FR-01 assignment A1

GOAL: Complete FR-01 revision 1 against the exact card below: apply the nine HF-10 required fixes RF-1 to RF-9 to the six admitted foundation sections (plus the HF-07a CSV) in place, with every retained paper check for a touched section still exiting 0 and no question answered.

SCOPE: /home/andrew/Projects/scrapkeep-wt-FR-01, branch wt/FR-01, verified base 395bc3ff5583a460bba21095fffcda7faf514555, exclusive lease FR-01-L1, attempt FR-01-A1. Writer scrapkeep-writer (claude-opus-5 high pinned by its agent definition; report the runtime CLAUDE_EFFORT value). Permitted files: docs/tech/sections/HF-04b-runtime-patterns.md; docs/tech/sections/HF-06a-schema-inventory.md; docs/tech/sections/HF-06b-persistence-projection.md; docs/tech/sections/HF-07a-save-envelope.md; docs/tech/sections/HF-07a-save-envelope.csv; docs/tech/sections/HF-07b-commit-boundaries.md; docs/tech/sections/HF-08-save-recovery.md; artifacts/local/tasks/FR-01/ (ignored, receipts). Retained check scripts under artifacts/foundation-sprint-2026-09/tasks/<id>/attempt-1/ are NOT in your lease: where a fix changes a line a script pins, record the needed pin change in your handoff as a proposed edit with the exact old and new expected value, and the coordinator applies it at admission. If a pin change is unavoidable for the check to exit 0, you may stage it under artifacts/local/tasks/FR-01/pins/<id>/<script>.py as a copy and run that copy; never edit the retained file.

CONTEXT: Sprint Repair-and-handoff-2026-09-15, authorized by Andrew at TRACKING EV-0186 and widened at EV-0188. Read AGENTS.md, docs/project/README.md, CONTRIBUTING.md, ORCHESTRATOR.md (Handoff and review), .agents/skills/scrapkeep-task/SKILL.md and .agents/skills/scrapkeep-verify/SKILL.md, then every exact card source below. Current source claims come from inspection of the bytes at your base; cite them by path and line. Question state at this base: Q-P14, Q-P15, Q-E09, Q-P16 and Q-E05 are proposed (engineering-half protocols only) and Q-P39 is open; no section may treat any of them as settled. Keep comments to a non-obvious why; no narrating comments, no commented-out code, no lint suppressions. The nine required fixes are stated verbatim with path and line at artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md lines 54 to 70 (RF-1 at :54, RF-2 :56, RF-3 :58, RF-4 :60, RF-5 :62, RF-6 :64, RF-7 :66, RF-8 :68, RF-9 :70) and its matrix rows at :127, :146, :149-150, :154, :156, :163-164, :169-171 name the cells each fix clears. Known gotchas recorded on the board: the HF-04b retained check_patterns.py rewrites its retained report in place, so run it from a copy under artifacts/local/tasks/FR-01/ with --out outside the retained directory and confirm the retained directory is byte-identical afterwards (git status must stay clean for artifacts/foundation-sprint-2026-09/); the HF-04a run_checks.py derives its candidate from the passed root's HEAD; the HF-05 check_contract.py writes paper-check.json beside itself. RF-8 has two readings (attempt ordinal versus stated overwrite exemption); the card allows either, and whichever you choose must keep AC-2 from firing on an ordinary retry and must state which reading you took in HF-08's Procedure performed. A later card, FR-02 (BACKLOG.md#fr-02), will add a run-start transition and split run.start out of run.checkpoint; do not anticipate it, and do not add or remove any envelope key beyond the three container rows RF-4 names. scripts/check-docs.mjs scans only .md files, so the CSV parity is yours to check by script.

ACCEPTANCE: Every item in the exact card below. Produce the complete corrected sections, not a description of the fixes.

VERIFY: In the worktree: npm run check:scope -- 395bc3ff5583a460bba21095fffcda7faf514555 <candidate> --no-build; npm run check:docs; npm run check:project; then each retained paper check for a touched section rerun from a copy of its retained script with --out under artifacts/local/tasks/FR-01/<id>/ (HF-04b check_patterns.py, HF-06a check_matrix.py, HF-06b check_projection.py, HF-07a check_envelope.py, HF-07b check_boundaries.py, HF-08 check_recovery.py, plus any sibling script in those attempt-1 directories). Record every exit code and count. The coordinator independently reruns and retains receipts under artifacts/repair-handoff-2026-09-15/tasks/FR-01/.

TIMEBOX: Checkpoint within 15 active minutes and at handoff with actual paths, artifacts and blockers. Initial target 60 minutes for M; reassess from evidence; never claim elapsed time as progress.

FORBIDDEN: No edits to TRACKING.md, ORCHESTRATOR.md or BACKLOG.md; no edits under artifacts/foundation-sprint-2026-09/; no builds, no native or browser execution, no dependency, asset or runtime changes, no publication, no invented product answers, no push, no rebase, no touching main. A registered non-blocking question keeps every candidate answer open. If a source contradiction prevents the exact DoD, stop affected work and submit an amendment request in the form of docs/project/sprint-0/amendment-request.md under artifacts/local/tasks/FR-01/; do not silently weaken a contract.

REPORT: Commit only permitted files on your branch and leave the tracked worktree clean. Report candidate SHA, base, changed paths, sha256 of each changed section, DoD coverage item by item (RF-1 to RF-9 each with the exact lines changed), the HF-10 matrix cells cleared with their PASS justification, commands run with exit codes, receipt paths, proposed retained-pin edits if any, CLAUDE_EFFORT value, deviations and follow-ups, and state explicitly that you have stopped.

## Exact card

### FR-01: Apply the HF-10 required fixes to the foundation sections

**Card revision:** 1 · **Owner:** Coordinator · **Size:** M · **Lane:** foundation-repair

**Source and inputs:**

- [HF-10 foundation review](artifacts/foundation-sprint-2026-09/HF-10-foundation-review.md), required fixes RF-1 to RF-9 with their exact path and line, and its notes N-01 onward
- The admitted sections `docs/tech/sections/HF-04b-runtime-patterns.md`, `HF-06a-schema-inventory.md`, `HF-06b-persistence-projection.md`, `HF-07a-save-envelope.md` and `.csv`, `HF-07b-commit-boundaries.md`, `HF-08-save-recovery.md` at the closure commit
- `docs/tech/sections/HF-03a-module-map.md` lines 31, 32, 49 and `HF-03b-dependency-graph.md` line 185 (the names RF-1 and RF-6 must align to)
- The retained paper checks under `artifacts/foundation-sprint-2026-09/tasks/<id>/attempt-1/` for each section touched

**Dependencies:** [HF-10](#hf-10). **Blocking questions:** None. **Registered non-blocking questions:** [Q-P16](#q-p16), [Q-E09](#q-e09). No fix may answer a question or assume a proposed protocol.

**Files touched:** `docs/tech/sections/HF-04b-runtime-patterns.md`; `docs/tech/sections/HF-06a-schema-inventory.md`; `docs/tech/sections/HF-06b-persistence-projection.md`; `docs/tech/sections/HF-07a-save-envelope.md`; `docs/tech/sections/HF-07a-save-envelope.csv`; `docs/tech/sections/HF-07b-commit-boundaries.md`; `docs/tech/sections/HF-08-save-recovery.md`; `artifacts/local/tasks/FR-01/`.

**Definition of done:**

1. RF-1: the HF-04b sketch uses an Encounter command HF-03a line 32 lists, or the call is removed; no other sketch line changes.
2. RF-2 and RF-3: the HF-06a line 58 question list and the HF-06b line 10 and line 81 claims state exactly what the matrices carry.
3. RF-4 and RF-5: HF-07a gives `run.checkpoint.build`, `run.checkpoint.equipment` and `run.checkpoint.companion` container rows in both the Markdown and the CSV, and links its own CSV in a "Machine-readable copy" block in the HF-06b form.
4. RF-6 and RF-7: HF-07b names Persistence as the stager at C1.1, and assigns C4's T9 commit to a named transition (folding presentation into Transition A or adding a stated exception), with the four-stage invariants re-argued for that path.
5. RF-8 and RF-9: HF-08 makes the candidate-path rule and FC-03 retry consistent with P1 and P2 (an attempt ordinal or a stated overwrite exemption), and R5 routes FC-13 with no candidate, FC-14 as a load failure and `incompatible_content` to named user-visible states.
6. Every retained paper check for a touched section still exits 0 from its retained copy with `--out` outside the retained directory, updated only where a fix changes a cited line, and the HF-10 matrix cells those fixes clear are listed with their new PASS justification in the handoff.
7. Card revisions of the touched sections are not changed; each section's Procedure performed records the revision-in-place with the RF identifiers and the closure event.

**Verification and evidence:** `npm run check:scope -- <base> <candidate> --no-build`, `npm run check:docs`, `npm run check:project`, and the seven retained paper checks rerun from their retained copies; the reviewer re-walks C4 and V3 by hand under the corrected rules. No build.

**Boundary:** Documentation-only. This card applies only the nine required fixes; every HF-10 note stays a note for a later revision, no question is answered, no envelope key is added or removed, and no card definition or dependency changes.

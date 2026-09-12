# AR-08 assignment A1

GOAL: Complete AR-08 revision 1 against the full exact card below: reconcile the eight named coordination records with the admitted state at base d98803c555bedcd3d68e5d82efafb1a2d0bcf31b (five of fourteen foundation cards done: HF-01, HF-02, HF-03a, HF-04a, HF-05; AR-01 to AR-07 done; event archive EV-0001 to EV-0057 in docs/project/tracking/EVENTS-0001-0057.md).

SCOPE: /home/andrew/Projects/scrapkeep-wt-AR-08, branch wt/AR-08, verified base d98803c555bedcd3d68e5d82efafb1a2d0bcf31b, exclusive lease AR-08-L1, attempt AR-08-A1. Writer scrapkeep-writer-low (claude-fable-5-1 low). Permitted files: docs/project/README.md; BACKLOG.md (edition line and the prose under "Proposed first sprint" only); ORCHESTRATOR.md (revision header and closing paragraph only); adr/README.md (one sentence); docs/RUNTIME-BLUEPRINT.md; docs/PLANNING-PREP-SWARM.md; docs/project/HOUSEKEEPING.md; docs/project/ASSETS.md; artifacts/local/tasks/AR-08/.

CONTEXT: Full foundation authorization TRACKING EV-0078 (documentation-only, no approval pauses) applies. Read AGENTS.md, docs/project/README.md, CONTRIBUTING.md, ORCHESTRATOR.md (Handoff and review), both project task/verify skills under .agents/skills, and every exact card source below. Current source claims come from inspection. All dependency sections are the admitted bytes at this base; cite them by path and line. Already admitted S0 proofs and retained receipts are historical evidence, never new execution. Required section headings come from docs/tech/sections/README.md (Sources, Contract, Scenarios, Unresolved questions, Re-verification triggers, Procedure performed, Evidence limits). Known gotchas: HF-05 section line 8 cites TADR-004 where TADR-003:41 is correct, do not propagate it; scripts/check-docs.mjs scans only .md files and resolves relative links against the containing file.

ACCEPTANCE: Every item in the exact card below, the required section headings, exact source identities, scenario receipts and limitations. Do not merely restate the DoD; produce the complete usable contract.

VERIFY: In the worktree: npm run check:scope -- d98803c555bedcd3d68e5d82efafb1a2d0bcf31b <candidate> --no-build; npm run check:docs; npm run check:project; plus the card-specific paper checks. Save executable paper checks under artifacts/local/tasks/AR-08/ (ignored) that accept an explicit repository root and write receipts next to themselves; never write into artifacts/foundation-sprint-2026-09/. The coordinator independently reruns and retains receipts.

TIMEBOX: Checkpoint within 15 active minutes and at handoff with actual paths, artifacts and blockers. Initial target 60 minutes for M, 30 for S; reassess from evidence; never claim elapsed time as progress.

FORBIDDEN: No edits to TRACKING.md, ORCHESTRATOR.md or BACKLOG.md unless listed in permitted files; no builds, no native or browser execution, no dependency, asset or runtime changes, no publication, no invented product answers, no push, no rebase, no touching main. If a source contradiction prevents the exact DoD, stop affected work and submit an amendment request in the form of docs/project/sprint-0/amendment-request.md under artifacts/local/tasks/AR-08/; do not silently weaken the contract.

REPORT: Commit only permitted output files on your branch and leave the tracked worktree clean. Report candidate SHA, base, changed paths, sha256 of each output, DoD coverage item by item, commands run with exit codes, receipt paths, CLAUDE_EFFORT value, deviations and follow-ups, and state explicitly that you have stopped.

Card-specific notes: the admitted state to cite is TRACKING.md task index rows and events EV-0099 to EV-0125; the historical-banner form is docs/FIRST-BUILD-CONTRACT.md line 3. Every heading and anchor another file links to stays unchanged. The ORCHESTRATOR Roles paragraph is out of scope even though it still says xhigh.

## Exact card

### AR-08: Reconcile stale coordination records with the admitted state

**Card revision:** 1 · **Owner:** Coordinator · **Size:** S · **Lane:** audit-repair

**Source and inputs:**

- [Repository audit of 12 September 2026](artifacts/audit-2026-09-12/README.md), its `checks.log` and `git-hygiene.sh`
- `TRACKING.md` task state index and events EV-0099 to EV-0125 (the admitted state the records must match)
- `docs/FIRST-BUILD-CONTRACT.md` line 3 (the historical-banner form to copy)

**Dependencies:** None. **Blocking questions:** None.

**Files touched:** `docs/project/README.md`; `BACKLOG.md` (edition line and the prose under "Proposed first sprint" only); `ORCHESTRATOR.md` (revision header and closing paragraph only); `adr/README.md` (one sentence); `docs/RUNTIME-BLUEPRINT.md`; `docs/PLANNING-PREP-SWARM.md`; `docs/project/HOUSEKEEPING.md`; `docs/project/ASSETS.md`.

**Definition of done:**

1. The dated status paragraph in `docs/project/README.md` states the admitted state at the card's base: five of fourteen foundation cards done with HF-03a, HF-04a and HF-05 named and linked, the AR-01 to AR-07 wave admitted, and the event archive in place. It links `TRACKING.md` for live counts instead of restating them.
2. The `BACKLOG.md` edition line carries the card's date, and the prose under "Proposed first sprint" says the fourteen-card set was authorized at EV-0078. The heading text stays unchanged so existing anchors hold.
3. The `ORCHESTRATOR.md` revision header no longer presents Operational Sprint 0 as the current authorization, and its closing paragraph no longer says foundation authorization is awaiting review; both defer to the TRACKING authorization row.
4. `adr/README.md` no longer says the per-system pages have not been produced; it links `docs/tech/sections/README.md`.
5. `docs/RUNTIME-BLUEPRINT.md` and `docs/PLANNING-PREP-SWARM.md` open with a historical banner in the form of `docs/FIRST-BUILD-CONTRACT.md` line 3, naming what superseded them (TADR-002 for the blueprint's ownership table; the HOUSEKEEPING remote record and the historical planning protocol for the swarm record's line 32 claims).
6. `docs/project/HOUSEKEEPING.md` line 40 and `docs/project/ASSETS.md` line 15 point their backlog and T04 references at the root `BACKLOG.md` or `docs/project/SOURCE-DISPOSITIONS.md` instead of the frozen `docs/project/BACKLOG.md`.
7. Every heading and anchor another file links to is unchanged. `npm run check:docs` and `npm run check:project` exit 0.

**Verification and evidence:** `npm run check:docs` and `npm run check:project` on the candidate; no build. The reviewer reads each changed paragraph against the TRACKING rows and events it cites and confirms no claim exceeds an admitted state.

**Boundary:** Documentation-only. This card does **not** edit `TRACKING.md` (the coordinator corrects board records through events), does not change any card definition, dependency, ADR status or question, deletes no artifact, and leaves the unreferenced artifact files and `artifacts/visual-iterations/*.js` snapshots named in the audit for a separate disposition.
